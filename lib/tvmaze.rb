require 'cgi'
require 'httpx'
require 'time'
require 'sequel'
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
    login = HTTPX.plugin(:follow_redirects).with(headers: { "Accept" => "application/json", "Content-Type" => "application/json" }).post('https://api.thetvdb.com/login', json: {:apikey => @api_key, :username => @username, :userkey => @user_key})

    @current_auth_token = response.json["token"] rescue nil
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

    myshow = HTTPX.plugin(:follow_redirects).with(headers: { "Accept" => "application/json", "Authorization" => 'Bearer ' + @current_auth_token }).get("https://api.thetvdb.com/series/#{CGI.escape(@id)}")
    
    if myshow.status == '401'
      getAuthToken
      myshow = HTTPX.plugin(:follow_redirects).with(headers: { "Accept" => "application/json", "Authorization" => 'Bearer ' + @current_auth_token }).get("https://api.thetvdb.com/series/#{CGI.escape(@id)}")
    end
    
    if myshow.json.key?("data")
      @show = myshow.json["data"].clone
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
    match /^!addshow$/, use_prefix: false, method: :addshow
    match /^!delshow$/, use_prefix: false, method: :delshow


    def initialize(*args)
      super
      @IMDBCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:imdb_cache_entries]))
      @IMDBCacheEntry.unrestrict_primary_key

      @lastshows = Hash.new
    end

    def addshow(m)
      if m.user.host != 'bitlanticcity.com' && m.user.host != 'when.mttr.collides.with.antimttr.com'
        m.reply "UNAUTHORIZED."
        return
      end

      lqkey = m.channel.to_s + "::" + m.user.to_s;
      if(!@lastshows.key?(lqkey) || @lastshows[lqkey][:time] < (Time.now.getutc.to_i - 120))
        m.reply "You must search for the show you want to add first using @show_name.  You then must use !addshow within 2 minutes."
        return
      end

      id = @lastshows[lqkey][:id]
      
      c = bot.botconfig[:DB][:tv_groups].where(:show_id => id).count
      if c != 0
        m.reply "Show was already added."
        return
      end

      bot.botconfig[:DB][:tv_groups].insert(:id => lqkey.downcase, :show_id => id)
      m.reply "Added show \"#{bot.botconfig[:DB][:imdb_cache_entries].where(:tv_maze_id => id).first[:name]}\"."
    end

    def delshow(m)

    end

    def help(m)
      if m.bot.botconfig[:TVMAZE_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      m.user.notice "\x02\x0304TV:\n\x0f" + 
      "\x02  @<show_name>\x0f - Get info about show\n" +  
      "\x02  @2 <show_name>\x0f - Get info about show, using 2nd search hit\n" +
      "\x02  @3 <show_name>\x0f - Get info about show, using 3rd search hit, etc, etc...\n" 
      #"\x02  !tv <show_name>\x0f - Get info about show\n" +  
      #"\x02  !tv2 <show_name>\x0f - Get info about show, using 2nd search hit\n" +
      #"\x02  !tv3 <show_name>\x0f - Get info about show, using 3rd search hit, etc, etc...\n"
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
      id.gsub!(/^\s*thrones\s*$/i, "game of thrones")

      if hitno == 0 && id && id.length > 0 && m.channel.users.keys.map{|x| x.nick}.include?(id.split(/\W+|,|:|;/)[0])
        return
      end

      if id =~ /^nextgame$/i
        m.reply "Fuck soccer."
        return
      end

      if id =~ /^lastgame$/i
        m.reply "Not soon enough."
        return
      end

      
      search = HTTPX.plugin(:follow_redirects).get("http://api.tvmaze.com/search/shows?q=" + CGI.escape(id)).json
      showID = nil
      skipcheck = 0

      if !search || search.size <= hitno  || !search[hitno].key?("show") || !search[hitno]["show"].key?("id")
        search = HTTPX.plugin(:follow_redirects).get("http://api.tvmaze.com/search/shows?q=" + CGI.escape(id.gsub(/\./, " "))).json
      else
        skipcheck = 1
      end

      
      if skipcheck == 1 || (search && search.size > hitno  && search[hitno].key?("show") && search[hitno]["show"].key?("id"))
        showID = search[hitno]["show"]["id"]
        show = HTTPX.plugin(:follow_redirects).get("http://api.tvmaze.com/shows/" + CGI.escape(showID.to_s)).json

        if show && show.size>0

          lqkey = m.channel.to_s + "::" + m.user.to_s;
          @lastshows[lqkey] = Hash.new
          @lastshows[lqkey][:id] = show.dig("id")
          @lastshows[lqkey][:time] = Time.now.getutc.to_i

          
          lastepLink = show.dig("_links", "previousepisode", "href")
          if lastepLink
            lastep = HTTPX.plugin(:follow_redirects).get(lastepLink).json
          end
          
          maxEpNumber = nil
          maxEp = nil

          nextepLink = show.dig("_links", "nextepisode", "href")
          if nextepLink
            nextep = HTTPX.plugin(:follow_redirects).get(nextepLink).json
            
            if (nextep && nextep && nextep.dig("season"))
              thisSeason = nextep.dig("season")
              eps = HTTPX.plugin(:follow_redirects).get("http://api.tvmaze.com/shows/#{CGI.escape(show.fetch("id").to_s)}/episodes").json

              if eps && eps.size>0
                maxEp = eps.select { |e| e.fetch("season", nil) && e.fetch("number", nil) && e.fetch("season") == thisSeason }.max { |a,b| a["number"] <=> b["number"]}
                maxEpNumber = maxEp["number"] rescue nil 
              end
            end
          end
          
          color_pipe = "01"     
          color_name = "04"
          color_title = "03"
          color_colons = "12"
          color_text = "07"
                    
          tz = TZInfo::Timezone.get('America/New_York')

          network = show.dig("network", "name")
          if network
            network = show.fetch("network").fetch("name");
            tz = TZInfo::Timezone.get(show.dig("network","country","timezone")) rescue TZInfo::Timezone.get('America/New_York')
            elsif show.dig("webChannel", "name")
            network = show.dig("webChannel", "name")
            tz = TZInfo::Timezone.get(show.dig("webChannel","country","timezone")) rescue TZInfo::Timezone.get('America/New_York')
            else
            network = ""
          end

          airstamp_next = nil
          airstamp_last = nil
          airstamp_next_utc = nil
          airstamp_last_utc = nil
          airstamp_next_local = nil
          airstamp_last_local = nil

          if (nextep && nextep && nextep.size > 0 && nextep.fetch("airstamp", nil))
            airstamp_next = DateTime.iso8601(nextep.fetch("airstamp", nil)) rescue nil
            airstamp_next_utc = airstamp_next.new_offset("+00:00") rescue nil
            airstamp_next_utc_time = Time.parse(airstamp_next_utc.to_s)
            airstamp_next_local = DateTime.parse(airstamp_next_utc_time.getlocal(tz.period_for_utc(airstamp_next_utc_time).utc_total_offset).to_s)
          end

          if (lastep && lastep && lastep.size > 0 && lastep.fetch("airstamp", nil))
            airstamp_last = DateTime.iso8601(lastep.fetch("airstamp", nil)) rescue nil
            airstamp_last_utc = airstamp_last.new_offset("+00:00") rescue nil
            airstamp_last_utc_time = Time.parse(airstamp_last_utc.to_s)
            airstamp_last_local = DateTime.parse(airstamp_last_utc_time.getlocal(tz.period_for_utc(airstamp_last_utc_time).utc_total_offset).to_s)
          end
          
          myreply = "\x02" + show["name"].to_s + "\x0f" +        
          " | \x0f\x03" + color_title + "Next\x0f:\x03" + color_text + " " + (nextep && nextep && nextep.size > 0 ? nextep.fetch("season", "??").to_s + "x" + (nextep.fetch("number", -1).nil? ? 'Special' : sprintf("%02d", nextep.fetch("number", -1).to_s)) + " - " + nextep.fetch("name", "UNKNOWN_EPISODE_NAME").to_s + " (" + (!airstamp_next_local.nil? ? airstamp_next_local.strftime("%d/%b/%Y") : "UNKNOWN_DATE") + ")" : "N/A") + "\x0f" +          
          " | \x0f\x03" + color_title + "Prev\x0f:\x03" + color_text + " " + (lastep && lastep && lastep.size > 0 ? lastep.fetch("season", "??").to_s + "x" + (lastep.fetch("number", -1).nil? ? 'Special' : sprintf("%02d", lastep.fetch("number", -1).to_s)) + " - " + lastep.fetch("name", "UNKNOWN_EPISODE_NAME").to_s + " (" + (!airstamp_last_local.nil? ? airstamp_last_local.strftime("%d/%b/%Y") : "UNKNOWN_DATE") + ")" : "N/A") + "\x0f"
                  
          if(maxEpNumber)
            myreply << " | \x0f\x03" + color_title + "Final\x0f:\x03" + color_text + " " + nextep.fetch("season").to_s + "x" + sprintf("%02d", maxEpNumber.to_s) + "\x0f"
          end
          
          if show.fetch("status", nil)
            myreply <<
            " | " + 
            "\x03" + color_text + show.fetch("status", "UNKNOWN_SHOW_STATUS").to_s + "\x0f"
          end

          days = show.dig("schedule","days") || []
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
            "\x03" + color_text + airstamp_next_local.strftime(((days.nil?) ? "%A" : days) + " %I:%M %p (UTC%z)") + "\x0f"
          #elsif airstamp_last_local
          #  myreply <<
          #  " | " + 
          #  "\x03" + color_text + airstamp_last_local.strftime(((days.nil?) ? "%A" : days) + " %I:%M %p (UTC%z)") + "\x0f"
          end 



          if network && network.length > 0
            myreply << 
            " | " + 
            "\x03" + color_text + network + "\x0f"
          end
          
          if show.fetch("genres", nil) && show.fetch("genres", Array.new).join(", ").length > 0
            myreply <<
            " | " + 
            "\x03" + color_text + (show.fetch("genres", nil) ? show.fetch("genres", Array.new).join(", ") : "") + "\x0f"
            
          elsif show.fetch("type", nil) && show.fetch("type", "").to_s.length > 0
            myreply <<
            " | " + 
            "\x03" + color_text + show.fetch("type", "").to_s + "\x0f"
          end

          if show.fetch("language", nil) && show.fetch("language", "").to_s.length > 0 && show.fetch("language", "").to_s !~ /English/i
            myreply <<
            " | " + 
            "\x03" + color_text + show.fetch("language", "").to_s + "\x0f"
          end
            
          if show.fetch("url", nil)
            myreply <<
            " | " + 
            "\x03" + color_text + show.fetch("url", "UNKNOWN_URL").to_s + "\x0f"
          end
          
          countdown = ""
          if (nextep && nextep && nextep.size > 0 && nextep.fetch("airstamp", nil))
            now = Time.now
            showtime = DateTime.iso8601(nextep.fetch("airstamp")).to_time
            negative = ""
            
            if showtime < now && nextep && nextep && nextep.size > 0 && !nextep.fetch("airstamp", nil).nil?
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
              
              countdown = " | \x0f\x03" + color_title + "Countdown\x0f:\x03" + color_text + " " + negative + days.to_s + " days " + hours.to_s + "h " + minutes.to_s + "m " + seconds.to_s  + "s\x0f"
            end
          end
          
          display_later = 0
          c = @IMDBCacheEntry[showID]
          if c && !c.imdburl.nil? && c.imdb_votes > 0
            puts 'FOUND IMDBCacheEntry'
            myreply <<
            " | " + 
            "\x03" + color_text + c.imdburl + "\x0f" +
            
            " | " + 
            "\x03" + color_text + c.imdb_score.to_s + "/10 (" + c.imdb_votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes)\x0f"
            
            myreply << countdown
            m.reply myreply
          else
            display_later = 1
          end
   

          imdbrating = nil

          #if c && !c.imdburl.nil?
          #  imdblink = c.imdburl.gsub(/^.*\/title\//,'')
          #else
            imdblink = show.dig("externals", "imdb")
            tvdblink = show.dig("externals", "thetvdb")
            puts "imdblink=#{imdblink}\ntvdblink=#{tvdblink}"

            if imdblink.nil? && !tvdblink.nil?
              imdblink = TVDB.new(m.bot.botconfig[:TVDB_API_KEY], m.bot.botconfig[:TVDB_API_USERNAME], m.bot.botconfig[:TVDB_API_USERKEY], tvdblink.to_s).show["imdbId"] rescue nil
              puts "imdblink(from tvdb)=#{imdblink}"
            end
          #end

          puts "imdblink=#{imdblink}\ntvdblink=#{tvdblink}"
          
          #if imdblink  
            if imdblink  
              i = IMDB::getImdb(imdblink) rescue nil
            end

            imdblink = nil if i.nil?

            #ne = nextep["season"].to_s + "x" + sprintf("%02d", nextep["number"].to_s) rescue nil
            #if i
            #  puts "FOUND imdb data"
              if c
                c.name = show["name"]
                c.status = show.fetch("status", nil)
                c.network = network if network && network.length > 0
                #c.next_episode = airstamp_next_utc
                #c.next_episode_number = ne
                #c.tv_maze_last_update = Sequel::CURRENT_TIMESTAMP

                if imdblink
                  c.imdburl = 'http://www.imdb.com/title/' + imdblink
                  if i
                    c.imdb_score = i[:score].gsub(/\/.*$/,'')
                    c.imdb_votes = i[:votes].gsub(/,/,'')
                  end
                end
                
                c.save
              else
                c = @IMDBCacheEntry.new

                c.tv_maze_id = showID
                c.imdburl = (imdblink.nil? ? nil : 'http://www.imdb.com/title/' + imdblink)
                c.imdb_score = (i.nil? ? '0' : i[:score].gsub(/\/.*$/,''))
                c.imdb_votes = (i.nil? ? 0 : i[:votes].gsub(/,/,''))
                c.name = show["name"]
                c.status = show.fetch("status", nil)
                c.network = ((network && network.length > 0) ? network : nil)
                c.save

                ##create(:tv_maze_id => showID, :imdburl => (imdblink.nil? ? nil : 'http://www.imdb.com/title/' + imdblink), :imdb_score => (i.nil? ? '0' : i[:score].gsub(/\/.*$/,'')), :imdb_votes => (i.nil? ? 0 : i[:votes].gsub(/,/,'')), :name => show["name"], :status =>show.fetch("status", nil), :network => ((network && network.length > 0) ? network : nil))  #, :next_episode => airstamp_next_utc, :tv_maze_last_update => Sequel::CURRENT_TIMESTAMP, :next_episode_number => ne
                ##c = nil
              end
            #end
          #end  
          
          if display_later == 1

            if imdblink
              myreply <<
              " | " + 
              "\x03" + color_text + c.imdburl + "\x0f"
            end
              
            if i
              myreply <<
              " | " + 
              "\x03" + color_text + c.imdb_score.to_s + "/10 (" + c.imdb_votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes)\x0f"
            end


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
