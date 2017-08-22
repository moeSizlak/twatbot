require 'sequel'
require 'unirest'
require 'ethon'
require 'filemagic'
require 'securerandom'
require 'time'
require 'mime/types'
require 'uri'

module Plugins  
  class URLDB
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel, method: :urldb_listen
    
    def urldb_listen(m)
      if !m.bot.botconfig[:URLDB_CHANS].include?(m.channel.to_s) || m.bot.botconfig[:URLDB_EXCLUDE_USERS].include?(m.user.to_s)
        return
      end
      
      URI.extract(m.message, ["http", "https"]) do |url|
        botlog "[URLDB = #{url}]",m
        
        ##########################################################
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
              gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
              
              if gallery.body && gallery.body.key?("success") && gallery.body["success"] == true && gallery.body.key?("data")
                if gallery.body["data"].key?("is_album") && gallery.body["data"]["is_album"] == true
                  album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
                  if !album.body || !album.body.key?("success") || !album.body["success"] == true || !album.body.key?("data")
                    album = nil
                  end
                else
                  image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
                  if !image.body || !image.body.key?("success") || !image.body["success"] == true || !image.body.key?("data")
                    image = nil
                  end
                end
              else
                gallery = nil
              end
              
            elsif type == "album"
              album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
              
              if album.body && album.body.key?("success") && album.body["success"] == true && album.body.key?("data")
                if album.body["data"].key?("in_gallery") && album.body["data"]["in_gallery"] == true
                  gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
                  if !gallery.body || !gallery.body.key?("success") || !gallery.body["success"] == true || !gallery.body.key?("data")
                    gallery = nil
                  end
                end
              else
                album = nil
              end
              
            elsif type == "image"
              image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
              
              if image.body && image.body.key?("success") && image.body["success"] == true && image.body.key?("data")
                if image.body["data"].key?("in_gallery") && image.body["data"]["in_gallery"] == true
                  gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
                  if !gallery.body || !gallery.body.key?("success") || !gallery.body["success"] == true || !gallery.body.key?("data")
                    gallery = nil
                  end
                end
              else
                image = nil
              end            
            end
            
            if gallery && gallery.body["data"].key?("title") && !gallery.body["data"]["title"].nil? && gallery.body["data"]["title"].length > 0
              g_title = gallery.body["data"]["title"]
            end
            
            if !image.nil?
              search = image
            elsif !album.nil?
              search = album
            end
            
            if !search.nil?          
              if search.body["data"].key?("title") && !search.body["data"]["title"].nil? && search.body["data"]["title"].length > 0
                title = search.body["data"]["title"]
              end             

              if g_title
                mytitle = g_title
              elsif title
                mytitle = title
              else
                mytitle = URLHandlers::TitleBot::getTitle(gallery ? "http://imgur.com/gallery/#{path}" : (album ? "http://imgur.com/a/#{path}" : "http://imgur.com/#{path}")).to_s
              end
              
              if mytitle && mytitle.length > 0 && mytitle !~ /Imgur: The most awesome images on the Internet/
                imgurtitle = mytitle
              else
                imgurtitle = "[Untitled]"
              end
              
              if search.body["data"].key?("images_count")
                imgurtitle = "[ALBUM] " + imgurtitle
                if search.body["data"].key?("cover") && !search.body["data"]["cover"].nil? && search.body["data"]["cover"].length > 0
                  cover = search.body["data"]["cover"]
                  image = Unirest::get("https://api.imgur.com/3/image/#{cover}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
                  if !image.body || !image.body.key?("success") || image.body["success"] != true || !image.body.key?("data")
                    image = nil
                  end
                end
              end
              
              if !image.nil?
                if image.body["data"].key?("mp4") && !image.body["data"]["mp4"].nil? && image.body["data"]["mp4"].length > 0
                  imgurlink = image.body["data"]["mp4"]
                elsif image.body["data"].key?("link") && !image.body["data"]["link"].nil? && image.body["data"]["link"].length > 0
                  imgurlink = image.body["data"]["link"]
                end
              end

            end
            
          end
        end
        ###########################
        
        if imgurtitle && imgurtitle.length > 0
          mytitle = imgurtitle
        else
          mytitle = URLHandlers::TitleBot::getTitle(url)
        end
        
        imagefile = nil

        if Dir.exists?(m.bot.botconfig[:URLDB_IMAGEDIR])
          imagedir = m.bot.botconfig[:URLDB_IMAGEDIR]
          imagedir = imagedir + '/' unless imagedir =~ /\/$/
        
          recvd = ""
          
          if mytitle.nil? || mytitle.length == 0 || (imgurlink && imgurlink.length > 0)
            tempurl = url
            if imgurlink && imgurlink.length > 0
              tempurl = imgurlink
            end
          
            begin
              easy = Ethon::Easy.new url: tempurl, followlocation: true, ssl_verifypeer: false, headers: {
                'User-Agent' => 'foo'
              }
        
              easy.on_body do |chunk, easy|
              recvd << chunk             
              :abort if recvd.length > 1024
            end
            easy.perform
            rescue
              # EXCEPTION!
            end    
          end

          if recvd.length > 0
            fm = FileMagic.mime
            ft = fm.buffer(recvd)
            if ft =~ /^((?:image\/|video\/webm|[^;]*mp4)[^;]*)/
              mimetype = $1
              imagefile = Time.now.utc.strftime("%Y%m%d%H%M%S") + "-" + SecureRandom.uuid
        
              if  MIME::Types[mimetype].length > 0 && MIME::Types[mimetype].first.extensions.length > 0 && !MIME::Types[mimetype].first.extensions.first.nil? && MIME::Types[mimetype].first.extensions.first.length > 0
                imagefile = imagefile + "." + MIME::Types[mimetype].first.extensions.first
              else
                ext = tempurl.split(//).last(5).join
                if ext =~ /^\.([a-zA-Z0-9]{4})$/
                  ext = $1
                elsif ext =~ /^.\.([a-zA-Z0-9]{3})$/
                  ext = $1
                else
                  ext = ""
                end
        
                imagefile = imagefile + "." + ext
              end

              filesize = 0;
              File.open(imagedir + imagefile, "wb") do |saved_file|
                begin
                  easy = Ethon::Easy.new url: tempurl, followlocation: true, ssl_verifypeer: false, headers: {
                  'User-Agent' => 'foo'
                  }         
                    
                  easy.on_body do |chunk, easy|
                    saved_file.write(chunk) 
                    filesize += chunk.length;
                    :abort if filesize > 50000000   #~50 MB limit
                  end
                  
                  easy.perform
                rescue
                  # EXCEPTION!
                end                
              end
              
              if filesize == 0 || filesize >= 50000000
                File.delete(imagedir + imagefile)
                imagefile = nil
              end
              
            end        
          end
        end
        
        begin
          mytitle = '' if mytitle.nil?
          
          entries = m.bot.botconfig[:DB][:TitleBot]
          entries.insert(:Date => Sequel.function(:now), :Nick => m.user.to_s, :URL => url, :Title => mytitle.force_encoding('utf-8'), :ImageFile => imagefile)
            
          rescue Sequel::Error => e
          puts e.message
          botlog "[URLDB] [ERROR] #{e.message}", m
        end
        
        
      end
    end
    
  end
end