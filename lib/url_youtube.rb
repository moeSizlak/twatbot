require 'httpx'
require 'time'
require 'ruby-duration'


module URLHandlers
  module Youtube

    def help
      return "\x02  <Youtube URL>\x0f - Get title and info about Youtube video."
    end


    def parse(url)      
      if(url =~ /.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|watch\?(?:(?!v=)[^&]+&)+v=)([^#\&\?\s]*).*/i)
        id = $1
        search = HTTPX.plugin(:follow_redirects).get("https://www.googleapis.com/youtube/v3/videos?id=" + id + "&key=" + @config[:YOUTUBE_GOOGLE_SERVER_KEY] + "&part=snippet,contentDetails,statistics").json
        #puts "https://www.googleapis.com/youtube/v3/videos?id=" + id + "&key=" + @config[:YOUTUBE_GOOGLE_SERVER_KEY] + "&part=snippet,contentDetails,statistics,status"

        if search && search.key?("items") && search["items"].size > 0
          if search["items"][0].key?("snippet") 
            if search["items"][0]["snippet"].key?("publishedAt")
              publishedAt = search["items"][0]["snippet"]["publishedAt"]
              if publishedAt.size > 0
                publishedAt = DateTime.iso8601(publishedAt).strftime("%Y-%m-%d")
              end
            end
            
            if search["items"][0]["snippet"].key?("title")
              title = search["items"][0]["snippet"]["title"]
              end
            
            if search["items"][0]["snippet"].key?("description")
              description = search["items"][0]["snippet"]["description"]
            end      

            if search["items"][0]["snippet"].key?("channelTitle")
              author = search["items"][0]["snippet"]["channelTitle"]
            end
          end
          
          if search["items"][0].key?("contentDetails") 
            if search["items"][0]["contentDetails"].key?("duration")
              duration = search["items"][0]["contentDetails"]["duration"]
              if duration.size > 0
                if Duration.load(duration).format("%tm").to_f >= 60
                  duration = Duration.load(duration).format("%hh %mm %ss")
                else
                  duration = Duration.load(duration).format("%tmm %ss")
                end
              end
            end  
          end

          duration2 = search["items"][0]["snippet"]["liveBroadcastContent"]
          if duration2.downcase == 'live'
            duration2 = "LIVE"
          elsif duration2.downcase == 'upcoming'
            duration2 = "UPCOMING"
          else
            duration2 = nil
          end
          
          if search["items"][0].key?("statistics") 
            if search["items"][0]["statistics"].key?("viewCount")
              viewCount = search["items"][0]["statistics"]["viewCount"]
            end  
            
            if search["items"][0]["statistics"].key?("likeCount")
              likeCount = search["items"][0]["statistics"]["likeCount"]
            end  
            
            if search["items"][0]["statistics"].key?("dislikeCount")
              dislikeCount = search["items"][0]["statistics"]["dislikeCount"]
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
          
          #myreply = "\x02You\x0304Tube\x0f: " +
          #myreply =  "\x03" + color_yt + "[YouTube] \x0f" + 
          #myreply =  "\x02[\x0300,04 \u25ba \x0f\x02YouTube] \x0f" + 
          myreply =  "[\x0304\u25ba\x0f] \x02" + 
          (title.nil? ? "UNKOWN_TITLE" : title) + "\x0f | \x0307" +
          (duration2.nil? ? (duration.nil? ? "" : duration + "\x0f | \x0307") : (duration2 == "LIVE" ? "\x0f\x0303LIVE\x0f": duration2) + "\x0f | \x0307") + 
          (author.nil? ? "" : "Channel: #{author}\x0f | \x0307") +
          viewCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " views\x0f | \x0307" +
          "\x0303+" + likeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "\x0f | \x0307" +
          (publishedAt.nil? ? "" : "Uploaded #{publishedAt}") + "\x0f"
          
          
          return myreply
      	else
      		#puts search.code 
      		#puts search.raw_body
        end      
      end
      return nil
    end    
  end
end
