require 'cgi'
require 'unirest'
require 'time'
require 'sequel'
require 'nokogiri'
require 'open-uri'
require 'tzinfo'


class TVDB
  def initialize(api_key, username, user_key, id = nil)
    @api_key = api_key
    @username = username
    @user_key = user_key
    @id = id
    @show = nil
    @current_auth_token = nil
  end
  
  def getAuthToken
    login = Unirest::post('https://api.thetvdb.com/login', 
      headers:{ "Accept" => "application/json", "Content-Type" => "application/json" }, 
      parameters:{:apikey => @api_key, :username => @username, :userkey => @user_key}.to_json)
     
    @current_auth_token = login.body["token"] rescue nil
  end
  
  def show(id=nil)
    if id.nil? && @id.nil?
      return nil
    end
    
    if id == @id || id.nil?
      if !@show.nil?
        return @show
      else
        return doGetShow
      end
    else
      @id = id
      @show = nil
      return doGetShow
    end    
  end
  
  private
  
  def doGetShow
    return nil if @id.nil?
    getAuthToken if @current_auth_token.nil?

    myshow = Unirest::get("https://api.thetvdb.com/series/#{CGI.escape(@id)}", 
      headers:{ "Accept" => "application/json", "Authorization" => 'Bearer ' + @current_auth_token })
    
    if myshow.code == '401'
      getAuthToken
      myshow = Unirest::get("https://api.thetvdb.com/series/#{CGI.escape(@id)}", 
        headers:{ "Accept" => "application/json", "Authorization" => 'Bearer ' + @current_auth_token })
    end
    
    if myshow && myshow.body && myshow.body.key?("data")
      @show = myshow.body["data"].clone
    else
      @show = nil
    end
    
    return @show    
  end
  
end


module Plugins
  class TvMaze
    include Cinch::Plugin
    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^(?:!yyz|@)(\d*)\s*(\S.*)$/, use_prefix: false, method: :tvmaze


    def initialize(*args)
      super
      @IMDBCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:imdb_cache_entries]))
      @IMDBCacheEntry.unrestrict_primary_key
    end

    def help(m)
      if m.bot.botconfig[:TVMAZE_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      m.user.notice "\x02".b + "\x03".b + "04" + "TV:\n" + "\x0f".b + 
      "\x02".b + "  @<show_name>" + "\x0f".b + " - Get info about show\n" +  
      "\x02".b + "  @2 <show_name>" + "\x0f".b + " - Get info about show, using 2nd search hit\n" +
      "\x02".b + "  @3 <show_name>" + "\x0f".b + " - Get info about show, using 3rd search hit, etc, etc...\n" 
      #"\x02".b + "  !tv <show_name>" + "\x0f".b + " - Get info about show\n" +  
      #"\x02".b + "  !tv2 <show_name>" + "\x0f".b + " - Get info about show, using 2nd search hit\n" +
      #"\x02".b + "  !tv3 <show_name>" + "\x0f".b + " - Get info about show, using 3rd search hit, etc, etc...\n"
    end
    
    def tvmaze(m, hitno, id)
      botlog "", m
      
      if m.bot.botconfig[:TVMAZE_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:TVMAZE_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end
      
      if hitno && hitno.size > 0 then hitno = Integer(hitno) - 1 else hitno = 0 end
      if hitno < 0 then hitno = 0 end
      
      id.gsub!(/\s+$/, "")
      id.gsub!(/\s+/, " ")
      id.gsub!(/[^ -~]/, "")
      id.gsub!(/^\s*saul\s*$/i, "better call saul")

      if hitno == 0 && id && id.length > 0 && m.channel.users.keys.map{|x| x.nick}.include?(id.split(/\W+|,|:|;/)[0])
        return
      end
      
      search = Unirest::get("http://api.tvmaze.com/search/shows?q=" + CGI.escape(id))
      showID = nil
      skipcheck = 0

      if !search.body || search.body.size <= hitno  || !search.body[hitno].key?("show") || !search.body[hitno]["show"].key?("id")
        search = Unirest::get("http://api.tvmaze.com/search/shows?q=" + CGI.escape(id.gsub(/\./, " ")))
      else
        skipcheck = 1
      end

      
      if skipcheck == 1 || (search.body && search.body.size > hitno  && search.body[hitno].key?("show") && search.body[hitno]["show"].key?("id"))
        showID = search.body[hitno]["show"]["id"]
        show = Unirest::get("http://api.tvmaze.com/shows/" + CGI.escape(showID.to_s))

        if show.body && show.body.size>0
          
          lastepLink = show.body.dig("_links", "previousepisode", "href")
          if lastepLink
            lastep = Unirest::get(lastepLink)
          end
          
          maxEpNumber = nil
          maxEp = nil

          nextepLink = show.body.dig("_links", "nextepisode", "href")
          if nextepLink
            nextep = Unirest::get(nextepLink)
            
            if (nextep && nextep.body && nextep.body.dig("season"))
              thisSeason = nextep.body.dig("season")
              eps = Unirest::get("http://api.tvmaze.com/shows/#{CGI.escape(show.body.fetch("id").to_s)}/episodes")
              if eps.body && eps.body.size>0
                maxEp = eps.body.select { |e| e.fetch("season", nil) && e.fetch("number", nil) && e.fetch("season") == thisSeason }.max { |a,b| a["number"] <=> b["number"]}
                maxEpNumber = maxEp["number"]
              end
            end
          end
          
          color_pipe = "01"     
          color_name = "04"
          color_title = "03"
          color_colons = "12"
          color_text = "07"
                    
          tz = TZInfo::Timezone.get('America/New_York')

          network = show.body.dig("network", "name")
          if network
            network = show.body.fetch("network").fetch("name");
            tz = TZInfo::Timezone.get(show.body.dig("network","country","timezone")) rescue TZInfo::Timezone.get('America/New_York')
            elsif show.body.dig("webChannel", "name")
            network = show.body.dig("webChannel", "name")
            tz = TZInfo::Timezone.get(show.body.dig("webChannel","country","timezone")) rescue TZInfo::Timezone.get('America/New_York')
            else
            network = ""
          end

          airstamp_next = nil
          airstamp_last = nil
          airstamp_next_utc = nil
          airstamp_last_utc = nil
          airstamp_next_local = nil
          airstamp_last_local = nil

          if (nextep && nextep.body && nextep.body.size > 0 && nextep.body.fetch("airstamp", nil))
            airstamp_next = DateTime.iso8601(nextep.body.fetch("airstamp", nil)) rescue nil
            airstamp_next_utc = airstamp_next.new_offset("+00:00") rescue nil
            airstamp_next_utc_time = Time.parse(airstamp_next_utc.to_s)
            airstamp_next_local = DateTime.parse(airstamp_next_utc_time.getlocal(tz.period_for_utc(airstamp_next_utc_time).utc_total_offset).to_s)
          end

          if (lastep && lastep.body && lastep.body.size > 0 && lastep.body.fetch("airstamp", nil))
            airstamp_last = DateTime.iso8601(lastep.body.fetch("airstamp", nil)) rescue nil
            airstamp_last_utc = airstamp_last.new_offset("+00:00") rescue nil
            airstamp_last_utc_time = Time.parse(airstamp_last_utc.to_s)
            airstamp_last_local = DateTime.parse(airstamp_last_utc_time.getlocal(tz.period_for_utc(airstamp_last_utc_time).utc_total_offset).to_s)
          end
          
          myreply = "\x03".b + color_name + show.body["name"].to_s + "\x0f".b +          
          " | " + "\x0f".b + "\x03".b + color_title + "Next" + "\x0f".b +  ":" +"\x03".b + color_text + " " + (nextep && nextep.body && nextep.body.size > 0 ? nextep.body.fetch("season", "??").to_s + "x" + sprintf("%02d", nextep.body.fetch("number", -1).to_s) + " - " + nextep.body.fetch("name", "UNKNOWN_EPISODE_NAME").to_s + " (" + (!airstamp_next_local.nil? ? airstamp_next_local.strftime("%d/%b/%Y") : "UNKNOWN_DATE") + ")" : "N/A") + "\x0f".b +          
          " | " + "\x0f".b + "\x03".b + color_title + "Prev" + "\x0f".b +  ":" +"\x03".b + color_text + " " + (lastep && lastep.body && lastep.body.size > 0 ? lastep.body.fetch("season", "??").to_s + "x" + sprintf("%02d", lastep.body.fetch("number", -1).to_s) + " - " + lastep.body.fetch("name", "UNKNOWN_EPISODE_NAME").to_s + " (" + (!airstamp_last_local.nil? ? airstamp_last_local.strftime("%d/%b/%Y") : "UNKNOWN_DATE") + ")" : "N/A") + "\x0f".b 
                  
          if(maxEpNumber)
            myreply << " | " + "\x0f".b + "\x03".b + color_title + "Final" + "\x0f".b +  ":" +"\x03".b + color_text + " " + nextep.body.fetch("season").to_s + "x" + sprintf("%02d", maxEpNumber.to_s) + "\x0f".b          
          end
          
          if show.body.fetch("status", nil)
            myreply <<
            " | " + 
            "\x03".b + color_text + show.body.fetch("status", "UNKNOWN_SHOW_STATUS").to_s + "\x0f".b
          end

          days = show.body.dig("schedule","days") || []
          if days.length  == 1
            days = days.join(", ")
          elsif days.length > 1
            days = days.map{|x| x[0..2]}.join(", ")
          else
            days = nil
          end


          if airstamp_next_local
            myreply <<
            " | " + 
            "\x03".b + color_text + airstamp_next_local.strftime(((days.nil?) ? "%A" : days) + " %I:%M %p (UTC%z)") + "\x0f".b
          #elsif airstamp_last_local
          #  myreply <<
          #  " | " + 
          #  "\x03".b + color_text + airstamp_last_local.strftime(((days.nil?) ? "%A" : days) + " %I:%M %p (UTC%z)") + "\x0f".b
          end 



          if network && network.length > 0
            myreply << 
            " | " + 
            "\x03".b + color_text + network + "\x0f".b
          end
          
          if show.body.fetch("genres", nil) && show.body.fetch("genres", Array.new).join(", ").length > 0
            myreply <<
            " | " + 
            "\x03".b + color_text + (show.body.fetch("genres", nil) ? show.body.fetch("genres", Array.new).join(", ") : "") + "\x0f".b
            
          elsif show.body.fetch("type", nil) && show.body.fetch("type", "").to_s.length > 0
            myreply <<
            " | " + 
            "\x03".b + color_text + show.body.fetch("type", "").to_s + "\x0f".b
          end

          if show.body.fetch("language", nil) && show.body.fetch("language", "").to_s.length > 0 && show.body.fetch("language", "").to_s !~ /English/i
            myreply <<
            " | " + 
            "\x03".b + color_text + show.body.fetch("language", "").to_s + "\x0f".b
          end
            
          if show.body.fetch("url", nil)
            myreply <<
            " | " + 
            "\x03".b + color_text + show.body.fetch("url", "UNKNOWN_URL").to_s + "\x0f".b
          end
          
          countdown = ""
          if (nextep && nextep.body && nextep.body.size > 0 && nextep.body.fetch("airstamp", nil))
            now = Time.now
            showtime = DateTime.iso8601(nextep.body.fetch("airstamp")).to_time
            negative = ""
            
            if showtime < now && nextep && nextep.body && nextep.body.size > 0 && !nextep.body.fetch("airstamp", nil).nil?
              tempx = now
              now = showtime
              showtime = tempx
              negative = "-"
            end
            
            if showtime >= now
              diff = (showtime-now).floor
              days = (diff/(60*60*24)).floor
              hours = ((diff-(days*60*60*24))/(60*60)).floor
              minutes = ((diff-(days*60*60*24)-(hours*60*60))/60).floor
              seconds = (diff-(days*60*60*24)-(hours*60*60)-(minutes*60)).floor
              
              countdown = " | " + "\x0f".b + "\x03".b + color_title + "Countdown" + "\x0f".b +  ":" +"\x03".b + color_text + " " + negative + days.to_s + " days " + hours.to_s + "h " + minutes.to_s + "m " + seconds.to_s  + "s" + "\x0f".b
            end
          end
          
          c = @IMDBCacheEntry[showID]
          if c
            puts 'FOUND IMDBCacheEntry'
            myreply <<
            " | " + 
            "\x03".b + color_text + c.imdburl + "\x0f".b +
            
            " | " + 
            "\x03".b + color_text + c.imdb_score.to_s + "/10 (" + c.imdb_votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes)" + "\x0f".b
            
            myreply << countdown
            m.reply myreply
          end
   

          imdbrating = nil
          imdblink = show.body.dig("externals", "imdb")
          tvdblink = show.body.dig("externals", "thetvdb")
          puts "imdblink=#{imdblink}\ntvdblink=#{tvdblink}"

          if imdblink.nil? && !tvdblink.nil?
            imdblink = TVDB.new(m.bot.botconfig[:TVDB_API_KEY], m.bot.botconfig[:TVDB_API_USERNAME], m.bot.botconfig[:TVDB_API_USERKEY], tvdblink.to_s).show["imdbId"] rescue nil
            puts "imdblink(from tvdb)=#{imdblink}"
          end
          
          if imdblink  
            i = IMDB::getImdb(imdblink)
            if i
              puts "FOUND imdb data"
              if c
                c.imdburl = 'http://www.imdb.com/title/' + imdblink
                c.imdb_score = i[:score].gsub(/\/.*$/,'')
                c.imdb_votes = i[:votes].gsub(/,/,'')
                c.name = show.body["name"]
                c.save
              else
                c = @IMDBCacheEntry.create(:tv_maze_id => showID, :imdburl => 'http://www.imdb.com/title/' + imdblink, :imdb_score => i[:score].gsub(/\/.*$/,''), :imdb_votes => i[:votes].gsub(/,/,''), :name => show.body["name"])
                
                myreply <<
                " | " + 
                "\x03".b + color_text + c.imdburl + "\x0f".b +
                
                " | " + 
                "\x03".b + color_text + c.imdb_score.to_s + "/10 (" + c.imdb_votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes)" + "\x0f".b
                
                c = nil
              end
            end
          end  
          
          if !c
            myreply << countdown
            m.reply myreply
          end
          
          
        end
        else
        myreply = "No matching shows found.  [" + (hitno != 0 ? "Searching for the #" + (hitno + 1).to_s + " search result for " : "") + "\"" + id.to_s + "\"]"
        m.reply myreply
      end
    end
   
  end
end
