require 'unirest'
require 'time'
require_relative 'url_title.rb'

module URLHandlers
  module Imgur
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
            gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] })
            
            if gallery.body && gallery.body.key?("success") && gallery.body["success"] == true && gallery.body.key?("data")
              if gallery.body["data"].key?("is_album") && gallery.body["data"]["is_album"] == true
                album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] })
                if !album.body || !album.body.key?("success") || !album.body["success"] == true || !album.body.key?("data")
                  album = nil
                end
              else
                image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] })
                if !image.body || !image.body.key?("success") || !image.body["success"] == true || !image.body.key?("data")
                  image = nil
                end
              end
            else
              gallery = nil
            end
            
          elsif type == "album"
            album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] })
            
            if album.body && album.body.key?("success") && album.body["success"] == true && album.body.key?("data")
              if album.body["data"].key?("in_gallery") && album.body["data"]["in_gallery"] == true
                gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] })
                if !gallery.body || !gallery.body.key?("success") || !gallery.body["success"] == true || !gallery.body.key?("data")
                  gallery = nil
                end
              end
            else
              album = nil
            end
            
          elsif type == "image"
            image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] })
            
            if image.body && image.body.key?("success") && image.body["success"] == true && image.body.key?("data")
              if image.body["data"].key?("in_gallery") && image.body["data"]["in_gallery"] == true
                gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + @config[:IMGUR_API_CLIENT_ID] })
                if !gallery.body || !gallery.body.key?("success") || !gallery.body["success"] == true || !gallery.body.key?("data")
                  gallery = nil
                end
              end
            else
              image = nil
            end            
          end
          #####################
          
          if(!gallery.nil?)
            if gallery.body["data"].key?("ups") && !gallery.body["data"]["ups"].nil?
              g_ups = gallery.body["data"]["ups"]
            else
              g_ups = 0
            end
            
            if gallery.body["data"].key?("downs") && !gallery.body["data"]["downs"].nil?
              g_downs = gallery.body["data"]["downs"]
            else
              g_downs = 0
            end
              
            if gallery.body["data"].key?("title") && !gallery.body["data"]["title"].nil? && gallery.body["data"]["title"].length > 0
              g_title = gallery.body["data"]["title"]
            end
            
            if gallery.body["data"].key?("topic") && !gallery.body["data"]["topic"].nil? && gallery.body["data"]["topic"].length > 0
              g_topic = gallery.body["data"]["topic"]
            end    
            
            if gallery.body["data"].key?("section") && !gallery.body["data"]["section"].nil? && gallery.body["data"]["section"].length > 0
              g_section = gallery.body["data"]["section"]
            end 
          end
            
          if !image.nil?
            search = image
          elsif !album.nil?
            search = album
          end
          
          
          if !search.nil?
          
            if search.body["data"].key?("views") && !search.body["data"]["views"].nil?
              views = search.body["data"]["views"]
            else
              views = 0
            end
            
            if search.body["data"].key?("title") && !search.body["data"]["title"].nil? && search.body["data"]["title"].length > 0
              title = search.body["data"]["title"]
            end   
            
            if search.body["data"].key?("section") && !search.body["data"]["section"].nil? && search.body["data"]["section"].length > 0
              section = search.body["data"]["section"]
            end 
            
            if search.body["data"].key?("topic") && !search.body["data"]["topic"].nil? && search.body["data"]["topic"].length > 0
              topic = search.body["data"]["topic"]
            end 
          
            color_yt = "03"     
            color_name = "04"
            color_rating = "07"
            color_url = "03"
          
            myreply = "\x03".b + color_yt + "[Imgur] " + "\x0f".b
            
            if g_title
              mytitle = g_title
            elsif title
              mytitle = title
            else
              mytitle = getTitle(gallery ? "http://imgur.com/gallery/#{path}" : (album ? "http://imgur.com/a/#{path}" : "http://imgur.com/#{path}")).to_s
            end
            
            if mytitle && mytitle.length > 0 && mytitle !~ /Imgur: The most awesome images on the Internet/ && mytitle !~ /Imgur: The magic of the Internet/
              myreply += mytitle
            else
              myreply += "[Untitled]"
            end
            
            myreply += " " 
            
            if search.body["data"].key?("nsfw") && !search.body["data"]["nsfw"].nil? && search.body["data"]["nsfw"] == true
              myreply += "\x03".b + color_name + "[NSFW] " + "\x0f".b
            end
            
            myreply += "\x03".b + color_rating
            
            if search.body["data"].key?("images_count")
              myreply += "[Album"
              
              if !search.body["data"]["images_count"].nil?
                myreply += " w/ " + search.body["data"]["images_count"].to_s   + " images"
              end
              
              myreply += "] "
            end
            
            if search.body["data"].key?("datetime") && !search.body["data"]["datetime"].nil?
              myreply += "[" + Time.at(search.body["data"]["datetime"]).strftime("%Y-%m-%d") + "] "
            end
            
            myreply += "[" + views.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " views] "
            
            if gallery && (g_ups > 0 || g_downs > 0)
              myreply += "[+" + g_ups.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "/-" + g_downs.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "] "
            end
            
            if search.body["data"].key?("type") && !search.body["data"]["type"].nil? && search.body["data"]["type"].length > 0
              myreply += "[" + search.body["data"]["type"] + "] "
            end
            
            if search.body["data"].key?("animated") && !search.body["data"]["animated"].nil? && search.body["data"]["animated"] == true
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
            
            myreply += "\x0f".b
            
            return myreply
          
          end # if !search.nil          
        end # if path =~ /^([a-zA-Z0-9]+)/
      end

      return nil
    end    
  end
end