require 'cgi'
require 'unirest'
require 'time'

module Plugins
  class TvMaze
    include Cinch::Plugin
    set :react_on, :message
    
    match /^@(\d*)\s*(\S.*)$/, use_prefix: false, method: :tvmaze
    
    def tvmaze(m, hitno, id)
      botlog "", m
      
      if MyApp::Config::TVMAZE_EXCLUDE_CHANS.include?(m.channel.to_s) || MyApp::Config::TVMAZE_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end
      
      if hitno && hitno.size > 0 then hitno = Integer(hitno) - 1 else hitno = 0 end
      if hitno < 0 then hitno = 0 end
      
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
          
          imdbrating = nil
          if show.body.fetch("externals", nil) && show.body.fetch("externals").fetch("imdb", nil)
            imdblink = show.body.fetch("externals").fetch("imdb")
            i = Imdb::Search.new(imdblink)
      
            if i.movies && i.movies.size > 0
              imdbrating = i.movies[0].rating.to_s + "/10 (" + i.movies[0].votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes)"
            end
          end  
          
          if imdbrating 
            m.reply "\x03".b + color_name + show.body["name"] + "\x0f".b +
            " | " +"\x03".b + color_title + "IMDb" + "\x0f".b +  ":" +"\x03".b + color_text + " " + imdbrating + " http://www.imdb.com/title/#{imdblink}/" + "\x0f".b
          end
          
          
          
        end
        else
        myreply = "No matching shows found.  [" + (hitno != 0 ? "Searching for the #" + (hitno + 1).to_s + " search result for " : "") + "\"" + id.to_s + "\"]"
        m.reply myreply
      end
    end
    
    
  end
end