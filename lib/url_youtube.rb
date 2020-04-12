require 'unirest'
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
        search = Unirest::get("https://www.googleapis.com/youtube/v3/videos?id=" + id + "&key=" + @config[:YOUTUBE_GOOGLE_SERVER_KEY] + "&part=snippet,contentDetails,statistics")
        #puts "https://www.googleapis.com/youtube/v3/videos?id=" + id + "&key=" + @config[:YOUTUBE_GOOGLE_SERVER_KEY] + "&part=snippet,contentDetails,statistics,status"
        if search.body && search.body.key?("items") && search.body["items"].size > 0
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

            if search.body["items"][0]["snippet"].key?("channelTitle")
              author = search.body["items"][0]["snippet"]["channelTitle"]
            end
          end
          
          if search.body["items"][0].key?("contentDetails") 
            if search.body["items"][0]["contentDetails"].key?("duration")
              duration = search.body["items"][0]["contentDetails"]["duration"]
              if duration.size > 0
                if Duration.load(duration).format("%tm").to_f >= 60
                  duration = Duration.load(duration).format("%h:%M:%S")
                else
                  duration = Duration.load(duration).format("%tm:%S")
                end
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
          
          color_yt = "03"     
          color_name = "04"
          color_rating = "07"
          color_url = "03"
          
          #myreply = "\x02You\x0304Tube\x0f: " +
          myreply =  "\x03" + color_yt + "[YouTube] \x0f" + 
          
          #(title.nil? ? "UNKOWN_TITLE" : title) +
          
          "\x03" + color_name + 
          (title.nil? ? "UNKOWN_TITLE" : title) + 
          "\x0f" +

          "\x03" + color_rating +
          (duration.nil? ? ""    : (" (" + duration    + ")")) +    
          (publishedAt.nil? ? "" : (" [" + (author.nil? ? "" : (author + " @ ")) + publishedAt + "]")) +
          " [" + viewCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " views] [\x0f" + 
          "\x0303+" + likeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse    + "\x0f" +
          "\x03" + color_rating + "/\x0f" +
          "\x0304-" + dislikeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "\x0f" +
          "\x03" + color_rating +"]\x0f"
          
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
