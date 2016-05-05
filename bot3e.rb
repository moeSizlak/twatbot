require './bot3econfig.rb'

require 'cgi'
require 'imdb'
require 'cinch'
require 'ethon'
require 'unirest'
require 'ruby-duration'
require 'feedjira'

module Plugins
class RSSFeed
    include Cinch::Plugin
    set :react_on, :channel

  if defined? @old
    timer 300, method: :updatefeed
  else
    timer 5, method: :updatefeed
  end
  
  
    def updatefeed
  #Channel('#testing12').send "AAA"
      feed = Feedjira::Feed.fetch_and_parse('http://feeds.feedburner.com/Torrentfreak')
      sub = feed.entries.first
      if defined? @old
        printnew sub unless sub.title == @old
    else
      printnew sub
      end
      @old = sub.title
    end

    def printnew(entry)
      Channel('#ezNAZI').send "\x02".b + "[TorrentFreak]" + "\x0f".b + " #{entry.title} - #{entry.url}"
    end
  
end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server = MyApp::Config::SERVER
    c.port = MyApp::Config::PORT
    c.channels = MyApp::Config::CHANNELS
    c.user = MyApp::Config::USER
    c.password = MyApp::Config::PASSWORD
    c.ssl.use = MyApp::Config::SSL
    c.nick = MyApp::Config::NICK
    c.plugins.plugins = [
      Plugins::RSSFeed,
    ]
  end
  
  
  on :message, Regexp.new('.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|watch\?(?:(?!v=)[^&]+&)+v=)([^#\&\?\s]*).*', Regexp::IGNORECASE) do |m|
    
    color_yt = "03"     
    color_name = "04"
    color_rating = "07"
    color_url = "03"
    
    info "[IN] [YOUTUBEURL] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + m.message.to_s
    m.message =~ Regexp.new('.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|watch\?(?:(?!v=)[^&]+&)+v=)([^#\&\?\s]*).*', Regexp::IGNORECASE)
    id = $1
    
    search = Unirest::get("https://www.googleapis.com/youtube/v3/videos?id=" + id + "&key=" + MyApp::Config::GOOGLE_SERVER_KEY + "&part=snippet,contentDetails,statistics,status")
    
    if m.channel.to_s != '#New_World_Order' &&  m.channel.to_s != '#EZTV' && search.body && search.body.key?("items") && search.body["items"].size > 0
      
      if search.body["items"][0].key?("snippet") 
        if search.body["items"][0]["snippet"].key?("publishedAt")
          publishedAt = search.body["items"][0]["snippet"]["publishedAt"]
          if publishedAt.size > 0
            publishedAt = DateTime.iso8601(publishedAt).strftime("%Y-%m-%d")
          end
        end
        
        if search.body["items"][0]["snippet"].key?("title")
          title = search.body["items"][0]["snippet"]["title"]
        end
        
        if search.body["items"][0]["snippet"].key?("description")
          description = search.body["items"][0]["snippet"]["description"]
        end      
      end
      
      if search.body["items"][0].key?("contentDetails") 
        if search.body["items"][0]["contentDetails"].key?("duration")
          duration = search.body["items"][0]["contentDetails"]["duration"]
          if duration.size > 0
            duration = Duration.load(duration).format("%tm:%S")
          end
        end  
      end
      
      if search.body["items"][0].key?("statistics") 
        if search.body["items"][0]["statistics"].key?("viewCount")
          viewCount = search.body["items"][0]["statistics"]["viewCount"]
        end  
        
        if search.body["items"][0]["statistics"].key?("likeCount")
          likeCount = search.body["items"][0]["statistics"]["likeCount"]
        end  
        
        if search.body["items"][0]["statistics"].key?("dislikeCount")
          dislikeCount = search.body["items"][0]["statistics"]["dislikeCount"]
        end  
      end
      
      if(viewCount.nil?)
        viewCount = 0
      end
      
      if(likeCount.nil?)
        likeCount = 0
      end
      
      if(dislikeCount.nil?)
        dislikeCount = 0
      end
      
      myreply = "\x03".b + color_yt + "[YouTube] " + "\x0f".b + 
      "\x03".b + color_name + (title.nil? ? "UNKOWN_TITLE" : title) + "\x0f".b +
      "\x03".b + color_rating +
      (duration.nil? ? ""    : (" (" + duration    + ")")) +    
      (publishedAt.nil? ? "" : (" [" + publishedAt + "]")) +
      " ["         + viewCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + 
      " views] [+" + likeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + 
      "/-"         + dislikeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "]" +
      "\x0f".b
      
      m.reply myreply
      
    end  
  end
  
  
  
  
  on :message, Regexp.new('https?://[^/]*imdb.com.*/title/\D*(\d+)', Regexp::IGNORECASE) do |m|
    
    color_imdb = "03"     
    color_name = "04"
    color_rating = "07"
    color_url = "03"
    
    info "[IN] [IMDBURL] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + m.message.to_s
    m.message =~ Regexp.new('https?://[^/]*imdb.com.*/title/\D*(\d+)', Regexp::IGNORECASE)
    id = $1
    i = Imdb::Movie.new(id)
    
    if i.title
      myrating = i.mpaa_rating.to_s
      if myrating =~ /Rated\s+(\S+)/i
        myrating = "[" + $1 + "] "
        else
        myrating = ""
      end
      
      mygenres = i.genres
      if(!mygenres.nil? && mygenres.length > 0)
        mygenres = "[" + mygenres.join(", ") + "] "
        else
        mygenres = ""
      end  
      
      myreply = #"\x03".b + color_imdb + "[IMDB] " + "\x0f".b + 
      "\x03".b + color_name + i.title + " (" + i.year.to_s + ")" + "\x0f".b + 
      "\x03".b + color_rating + " [IMDB: " + i.rating.to_s + "/10] [" + i.votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes] " + 
      myrating + mygenres + "\x0f".b + 
      (i.plot)[0..255]
      m.reply myreply
      
    end  
  end
  
  on :message, Regexp.new('^\.moe', Regexp::IGNORECASE) do |m|
    #  sleep 2 
    m.reply Cinch::Helpers.sanitize CGI.unescapeHTML "moeSizlak did actually profit several thousand dollars in US currency from sale of bitcoins which he acquired.  How much have you made?  Thought so.".force_encoding('utf-8')
  end
  
  on :message, Regexp.new('^[.!]imdb', Regexp::IGNORECASE) do |m|
    color_imdb = "03"     
    color_name = "04"
    color_rating = "07"
    color_url = "03"
    
    
    info "[IN] [IMDB] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + m.message.to_s
    m.message =~ Regexp.new('^[.!]imdb\s+(\S.*)\s*$', Regexp::IGNORECASE)
    id = $1
    id.gsub!(/\s+$/, "")
    id.gsub!(/\s+/, " ")
    id.gsub!(/[^ -~]/, "")
    i = Imdb::Search.new(id)
    
    if i.movies && i.movies.size > 0
      myrating = i.movies[0].mpaa_rating.to_s
      if myrating =~ /Rated\s+(\S+)/i
        myrating = "[" + $1 + "] "
        else
        myrating = ""
      end
      
      mygenres = i.movies[0].genres
      if(!mygenres.nil? && mygenres.length > 0)
        mygenres = "[" + mygenres.join(", ") + "] "
        else
        mygenres = ""
      end
      
      myreply = #"\x03".b + color_imdb + "[IMDB] " + "\x0f".b + 
      "\x03".b + color_name + i.movies[0].title + "\x0f".b + 
      "\x03".b + color_rating + " [IMDB: " + i.movies[0].rating.to_s + "/10] [" + i.movies[0].votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes] " + 
      myrating + mygenres + "\x0f".b + 
      "\x03".b + color_url + i.movies[0].url.gsub!(/\/combined/, "").gsub!(/akas\.imdb\.com/,"www.imdb.com") + "\x0f".b + 
      " - " + (i.movies[0].plot)[0..255]
      m.reply myreply
      
    end
  end
  
  on :message, Regexp.new('^@', Regexp::IGNORECASE) do |m|
    info "[IN] [TVMAZE] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + m.message.to_s
    m.message =~ Regexp.new('^@(\d*)\s*(\S.*)$', Regexp::IGNORECASE)
    hitno = $1
    if hitno && hitno.size > 0 then hitno = Integer(hitno) - 1 else hitno = 0 end
    if hitno < 0 then hitno = 0 end
    id = $2
    id.gsub!(/\s+$/, "")
    id.gsub!(/\s+/, " ")
    id.gsub!(/[^ -~]/, "")
    
    search = Unirest::get("http://api.tvmaze.com/search/shows?q=" + CGI.escape(id))
    
    if search.body && search.body.size > hitno  && search.body[hitno].key?("show") && search.body[hitno]["show"].key?("id")
      show = Unirest::get("http://api.tvmaze.com/shows/" + CGI.escape(search.body[hitno]["show"]["id"].to_s))
      
      if show.body && show.body.size>0
        
        if show.body.key?("_links") && show.body["_links"].key?("previousepisode") && show.body["_links"]["previousepisode"]["href"]
          lastep = Unirest::get(show.body["_links"]["previousepisode"]["href"])
        end
        
        if show.body["_links"] && show.body["_links"]["nextepisode"] && show.body["_links"]["nextepisode"]["href"]
          nextep = Unirest::get(show.body["_links"]["nextepisode"]["href"])
        end
        
        color_pipe = "01"     
        color_name = "04"
        color_title = "03"
        color_colons = "12"
        color_text = "07"
        
        if show.body.fetch("network", nil) && show.body.fetch("network").fetch("name", nil)
          network = show.body.fetch("network").fetch("name");
          elsif show.body.fetch("webChannel", nil) && show.body.fetch("webChannel").fetch("name", nil)
          network = show.body.fetch("webChannel").fetch("name");
          else
          network = ""
        end
        
        myreply = "\x03".b + color_name + show.body["name"] + "\x0f".b +
        
        " | " + "\x0f".b + "\x03".b + color_title + "Next Ep" + "\x0f".b +  ":" +"\x03".b + color_text + " " + (nextep && nextep.body && nextep.body.size > 0 ? nextep.body.fetch("season", "??").to_s + "x" + sprintf("%02d", nextep.body.fetch("number", -1).to_s) + " - " + nextep.body.fetch("name", "UNKNOWN_EPISODE_NAME").to_s + " (" + (nextep.body.fetch("airstamp", nil) ? DateTime.iso8601(nextep.body.fetch("airstamp")).strftime("%d/%b/%Y") : "UNKNOWN_DATE") + ")" : "N/A") + "\x0f".b +
        
        " | " + "\x0f".b + "\x03".b + color_title + "Last Ep" + "\x0f".b +  ":" +"\x03".b + color_text + " " + (lastep && lastep.body && lastep.body.size > 0 ? lastep.body.fetch("season", "??").to_s + "x" + sprintf("%02d", lastep.body.fetch("number", -1).to_s) + " - " + lastep.body.fetch("name", "UNKNOWN_EPISODE_NAME").to_s + " (" + (lastep.body.fetch("airstamp", nil) ? DateTime.iso8601(lastep.body.fetch("airstamp")).strftime("%d/%b/%Y") : "UNKNOWN_DATE") + ")" : "N/A") + "\x0f".b +
        
        " | " + "\x0f".b + "\x03".b + color_title + "Status" + "\x0f".b +  ":" +"\x03".b + color_text + " " + show.body.fetch("status", "UNKNOWN_SHOW_STATUS").to_s + "\x0f".b +
        
        " | " + "\x0f".b + "\x03".b + color_title + "Airs" + "\x0f".b +  ":" +"\x03".b + color_text + " " + (nextep && nextep.body && nextep.body.size > 0 && nextep.body.fetch("airstamp", nil) ? DateTime.iso8601(nextep.body.fetch("airstamp")).strftime("%A %I:%M %p (UTC%z)") : (lastep && lastep.body && lastep.body.size > 0 && lastep.body.fetch("airstamp", nil) ? DateTime.iso8601(lastep.body.fetch("airstamp")).strftime("%A %I:%M %p (UTC%z)") : "UNKOWN_AIRTIME")) + "\x0f".b +
        
        " | " + "\x0f".b + "\x03".b + color_title + "Network" + "\x0f".b +  ":" +"\x03".b + color_text + " " + network + "\x0f".b +
        
        " | " + "\x0f".b + "\x03".b + color_title + "Genre" + "\x0f".b +  ":" +"\x03".b + color_text + " " + (show.body.fetch("genres", nil) ? show.body.fetch("genres", Array.new).join(", ") : "") + "\x0f".b +
        
        " | " + "\x0f".b + "\x03".b + color_title + "URL" + "\x0f".b +  ":" +"\x03".b + color_text + " " + show.body.fetch("url", "UNKNOWN_URL").to_s + "\x0f".b
        
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
            
            myreply = myreply + 
            " | " + "\x0f".b + "\x03".b + color_title + "Countdown" + "\x0f".b +  ":" +"\x03".b + color_text + " " + negative + days.to_s + " days " + hours.to_s + "h " + minutes.to_s + "m " + seconds.to_s  + "s" + "\x0f".b
          end
        end
        
        m.reply myreply
        #info "[OUT] [TVMAZE] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + myreply.to_s
        #info myreply.inspect
      end
      else
      myreply = "No matching shows found.  [" + (hitno != 0 ? "Searching for the #" + (hitno + 1).to_s + " search result for " : "") + "\"" + id.to_s + "\"]"
      m.reply myreply
      info "[OUT] [TVMAZE] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + myreply.to_s
    end
    
  end
  
  
  
  on :message, Regexp.new('(https?://([^\/\.]*\.)*dumpert\.nl\S+)', Regexp::IGNORECASE) do |m, url|
    #next if m.user.nick == 'TurtleBot'
    
    info "[IN] [DUMPERTURL] ["+ url + "] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + m.message.to_s
    
    recvd = String.new
    
    easy = Ethon::Easy.new url: url, followlocation: true, headers: {
      'User-Agent' => 'foo'
    }
    easy.on_body do |chunk, easy|
      recvd << chunk
      
      recvd =~ Regexp.new('<title[^>]*>\s*(.*?)\s*</title>', Regexp::IGNORECASE | Regexp::MULTILINE)
      if title_found = $1
        
        thereply = '' + Nokogiri::HTML.parse(title_found.force_encoding('utf-8').gsub(/\s{2,}/, ' ')).text
        
        search = Unirest::get("https://translate.googleapis.com/translate_a/single?client=gtx&sl=nl&tl=en&dt=t&q=" + CGI.escape(thereply.gsub(/^\s*dumpert\.nl\s*-\s*/, '')))
        
        if search.body
          search = search.body
          search.gsub!(/,+/, ',')
          search.gsub!(/\[,/, '[')
          search = JSON.parse(search.body)
          
          if search.size > 0 && search[0].size > 0 && search[0][0].size > 0
            thereply = thereply + 
            #            "\x03".b + "04" + "  [DUMPERT] " + "\x0f".b + 
            "\x03".b + "04" + "  [" + search[0][0][0] + "]" + "\x0f".b
          end
        end
        
        
        
        info "[OUT] [DUMPERTURL] ["+ url + "] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + thereply
        m.reply thereply
      end
      
      :abort if recvd.length > 1024 * 1024 || title_found
    end
    easy.perform
  end
  
  
  
  
  on :message, Regexp.new('https?://[^\s/]+', Regexp::IGNORECASE) do |m|
    
    
    if (m.channel.to_s.upcase == "#EZNAZI" || m.channel.to_s.upcase == "#TESTING12") && 
      m.user.to_s.downcase !~ /anja|twatbot/ && 
      m.message !~ Regexp.new('.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|watch\?(?:(?!v=)[^&]+&)+v=)([^#\&\?\s]*).*', Regexp::IGNORECASE) &&
      m.message !~ Regexp.new('https?://[^/]*imdb.com.*/title/\D*(\d+)', Regexp::IGNORECASE) &&
      m.message !~ Regexp.new('https?://([^\/\.]*\.)*dumpert\.nl\S+', Regexp::IGNORECASE)    
      
      # m.message =~ Regexp.new('(https?://([^\s/]*)\S*)', Regexp::IGNORECASE)
      m.message.scan(Regexp.new('(https?://([^\s/]*)\S*)', Regexp::IGNORECASE)) do |url, host|
        #url = $1
        #host = $2
        
        info "[IN] [TITLEBOT] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + url
        
        recvd = String.new
        easy = Ethon::Easy.new url: url, followlocation: true, headers: {
          'User-Agent' => 'foo'
        }
        easy.on_body do |chunk, easy|
          recvd << chunk
          
          #info "[DEBUG] [TITLEBOT] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + recvd
          
          
          recvd =~ Regexp.new('<title[^>]*>\s*((?:(?!</title>).)*)\s*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found.strip!
            title_found.gsub!(/[\s\r\n]+/m, ' ')
            #title_found.gsub!(/[^ -~]/m, '')
            title_found = "[ " + title_found + " ] - " + host
            m.reply Cinch::Helpers.sanitize CGI.unescapeHTML title_found.force_encoding('utf-8')
          end
          
          :abort if recvd.length > 131072 || title_found
        end
        easy.perform
      end
    end
  end 
  
  
  
  
end

bot.loggers.level = :info

bot.start

