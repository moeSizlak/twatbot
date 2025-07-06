require 'httpx'
require 'time'
require_relative 'url_title.rb'

module URLHandlers
  module Imgur

    def help
      return "\x02  <Imgur URL>\x0f - Get title and info about Imgur image/gallery."
    end


    def parse(url)  
      if url =~ /https?:\/\/(?:[^\/.]+\.)*imgur.com(\/.+)$/ 
        path = $1
        path.gsub!(/\/$/, "")
        
        type = "";
        if path =~ /^\/a\//
          type = "album"
          path.gsub!(/^\/a\//,"")
        elsif path =~ /^\/(gallery|g)\//
          type = "gallery"
          path.gsub!(/^\/(gallery|g)\//,"")
        else    
          type = "image"
          path.gsub!(/^\//, "")
        end
        
        if path =~ /^([a-zA-Z0-9]+)/
          path = $1
          
          album = nil
          gallery = nil
          image = nil
          
          if type == "gallery"
            gallery = HTTPX.plugin(:follow_redirects).with(headers: { "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/gallery/#{path}.json").json
            
            if gallery && gallery.key?("success") && gallery["success"] == true && gallery.key?("data")
              if gallery["data"].key?("is_album") && gallery["data"]["is_album"] == true
                album = HTTPX.plugin(:follow_redirects).with(headers: { "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/album/#{path}.json").json
                if !album || !album.key?("success") || !album["success"] == true || !album.key?("data")
                  album = nil
                end
              else
                image = HTTPX.plugin(:follow_redirects).with(headers: { "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/image/#{path}.json").json
                if !image || !image.key?("success") || !image["success"] == true || !image.key?("data")
                  image = nil
                end
              end
            else
              gallery = nil
            end
            
          elsif type == "album"
            album = HTTPX.plugin(:follow_redirects).with(headers: { "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/album/#{path}.json").json
            
            if album && album.key?("success") && album["success"] == true && album.key?("data")
              if album["data"].key?("in_gallery") && album["data"]["in_gallery"] == true
                gallery = HTTPX.plugin(:follow_redirects).with(headers: { "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/gallery/#{path}.json").json
                if !gallery || !gallery.key?("success") || !gallery["success"] == true || !gallery.key?("data")
                  gallery = nil
                end
              end
            else
              album = nil
            end
            
          elsif type == "image"
            image = HTTPX.plugin(:follow_redirects).with(headers: { "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/image/#{path}.json").json
            if image && image.key?("success") && image["success"] == true && image.key?("data")
              if image["data"].key?("in_gallery") && image["data"]["in_gallery"] == true
                gallery = HTTPX.plugin(:follow_redirects).with(headers: { "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/gallery/#{path}.json").json
                if !gallery || !gallery.key?("success") || !gallery["success"] == true || !gallery.key?("data")
                  gallery = nil
                end
              end
            else
              image = nil
            end            
          end
          #####################
          
          if(!gallery.nil?)
            if gallery["data"].key?("ups") && !gallery["data"]["ups"].nil?
              g_ups = gallery["data"]["ups"]
            else
              g_ups = 0
            end
            
            if gallery["data"].key?("downs") && !gallery["data"]["downs"].nil?
              g_downs = gallery["data"]["downs"]
            else
              g_downs = 0
            end
              
            if gallery["data"].key?("title") && !gallery["data"]["title"].nil? && gallery["data"]["title"].length > 0
              g_title = gallery["data"]["title"]
            end
            
            if gallery["data"].key?("topic") && !gallery["data"]["topic"].nil? && gallery["data"]["topic"].length > 0
              g_topic = gallery["data"]["topic"]
            end    
            
            if gallery["data"].key?("section") && !gallery["data"]["section"].nil? && gallery["data"]["section"].length > 0
              g_section = gallery["data"]["section"]
            end 
          end
            
          if !image.nil?
            search = image
          elsif !album.nil?
            search = album
          end
          
          
          if !search.nil?
          
            if search["data"].key?("views") && !search["data"]["views"].nil?
              views = search["data"]["views"]
            else
              views = 0
            end
            
            if search["data"].key?("title") && !search["data"]["title"].nil? && search["data"]["title"].length > 0
              title = search["data"]["title"]
            end   
            
            if search["data"].key?("section") && !search["data"]["section"].nil? && search["data"]["section"].length > 0
              section = search["data"]["section"]
            end 
            
            if search["data"].key?("topic") && !search["data"]["topic"].nil? && search["data"]["topic"].length > 0
              topic = search["data"]["topic"]
            end 
          
            color_yt = "03"     
            color_name = "04"
            color_rating = "07"
            color_url = "03"
          
            myreply = "\x02" + "[Imgur] \x0f"
            
            if g_title
              mytitle = g_title.strip.gsub(/[[:space:]]+/m, ' ')
            elsif title
              mytitle = title.strip.gsub(/[[:space:]]+/m, ' ')
            else
              mytitle = getTitle(gallery ? "http://imgur.com/gallery/#{path}" : (album ? "http://imgur.com/a/#{path}" : "http://imgur.com/#{path}")).to_s
            end
            
            if mytitle && mytitle.length > 0 && mytitle !~ /Imgur: The most awesome images on the Internet/ && mytitle !~ /Imgur: The magic of the Internet/
              myreply += mytitle
            else
              myreply += "[Untitled]"
            end
            
            myreply += " " 
            
            if search["data"].key?("nsfw") && !search["data"]["nsfw"].nil? && search["data"]["nsfw"] == true
              myreply += "\x03" + color_name + "[NSFW] \x0f"
            end
            
            myreply += "\x03" + color_rating
            
            if search["data"].key?("images_count")
              myreply += "[Album"
              
              if !search["data"]["images_count"].nil?
                myreply += " w/ " + search["data"]["images_count"].to_s   + " images"
              end
              
              myreply += "] "
            end
            
            if search["data"].key?("datetime") && !search["data"]["datetime"].nil?
              myreply += "[" + Time.at(search["data"]["datetime"]).strftime("%Y-%m-%d") + "] "
            end
            
            myreply += "[" + views.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " views] "
            
            if gallery && (g_ups > 0 || g_downs > 0)
              myreply += "[+" + g_ups.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "/-" + g_downs.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "] "
            end
            
            if search["data"].key?("type") && !search["data"]["type"].nil? && search["data"]["type"].length > 0
              myreply += "[" + search["data"]["type"] + "] "
            end
            
            if search["data"].key?("animated") && !search["data"]["animated"].nil? && search["data"]["animated"] == true
              myreply += "[Animated] "
            end
            
            if g_topic
              myreply += "[Topic: #{g_topic}] "
            elsif topic
              myreply += "[Topic: #{topic}] "
            end
              
            if g_section
              myreply += "[Section: #{g_section}] "
            elsif section
              myreply += "[Section: #{section}] "
            end
            
            myreply += "\x0f"
            
            return myreply
          
          end # if !search.nil          
        end # if path =~ /^([a-zA-Z0-9]+)/
      end

      return nil
    end    
  end
end