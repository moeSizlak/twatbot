require 'sequel'
require 'httpx'
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
      #if !m.bot.botconfig[:URLDB_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:URLDB_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
      if !m.bot.botconfig[:URLDB_DATA].map{|x| x[:chan].downcase}.include?(m.channel.to_s.downcase) || m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:exclude_users].map(&:downcase).include?(m.user.to_s.downcase)
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
              gallery = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/gallery/#{path}.json").json
              
              if gallery && gallery.key?("success") && gallery["success"] == true && gallery.key?("data")
                if gallery["data"].key?("is_album") && gallery["data"]["is_album"] == true
                  album = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/album/#{path}.json").json
                  if !album || !album.key?("success") || !album["success"] == true || !album.key?("data")
                    album = nil
                  end
                else
                  image = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/image/#{path}.json").json
                  if !image || !image.key?("success") || !image["success"] == true || !image.key?("data")
                    image = nil
                  end
                end
              else
                gallery = nil
              end
              
            elsif type == "album"
              album = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/album/#{path}.json").json
              
              if album && album.key?("success") && album["success"] == true && album.key?("data")
                if album["data"].key?("in_gallery") && album["data"]["in_gallery"] == true
                  gallery = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/gallery/#{path}.json").json
                  if !gallery || !gallery.key?("success") || !gallery["success"] == true || !gallery.key?("data")
                    gallery = nil
                  end
                end
              else
                album = nil
              end
              
            elsif type == "image"
              image = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/image/#{path}.json").json
              
              if image && image.key?("success") && image["success"] == true && image.key?("data")
                if image["data"].key?("in_gallery") && image["data"]["in_gallery"] == true
                  gallery = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/gallery/#{path}.json").json
                  if !gallery || !gallery.key?("success") || !gallery["success"] == true || !gallery.key?("data")
                    gallery = nil
                  end
                end
              else
                image = nil
              end            
            end
            
            if gallery && gallery["data"].key?("title") && !gallery["data"]["title"].nil? && gallery["data"]["title"].length > 0
              g_title = gallery["data"]["title"]
            end
            
            if !image.nil?
              search = image
            elsif !album.nil?
              search = album
            end
            
            if !search.nil?          
              if search["data"].key?("title") && !search["data"]["title"].nil? && search["data"]["title"].length > 0
                title = search["data"]["title"]
              end             

              if g_title
                mytitle = g_title
              elsif title
                mytitle = title
              else
                mytitle = URLHandlers::TitleBot::getTitle(gallery ? "http://imgur.com/gallery/#{path}" : (album ? "http://imgur.com/a/#{path}" : "http://imgur.com/#{path}")).to_s
              end
              
              if mytitle && mytitle.length > 0 && mytitle !~ /Imgur: The most awesome images on the Internet/ && mytitle !~ /Imgur: The magic of the Internet/
                imgurtitle = mytitle
              else
                imgurtitle = "[Untitled]"
              end
              
              if search["data"].key?("images_count")
                imgurtitle = "[ALBUM] " + imgurtitle
                if search["data"].key?("cover") && !search["data"]["cover"].nil? && search["data"]["cover"].length > 0
                  cover = search["data"]["cover"]
                  image = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/image/#{cover}.json").json
                  if !image || !image.key?("success") || image["success"] != true || !image.key?("data")
                    image = nil
                  end
                end
              end
              
              if !image.nil?
                if image["data"].key?("mp4") && !image["data"]["mp4"].nil? && image["data"]["mp4"].length > 0
                  imgurlink = image["data"]["mp4"]
                elsif image["data"].key?("link") && !image["data"]["link"].nil? && image["data"]["link"].length > 0
                  imgurlink = image["data"]["link"]
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

        #if Dir.exist?(m.bot.botconfig[:URLDB_IMAGEDIR])
        if !m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:imagedir].nil? && Dir.exist?(m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:imagedir])
          #imagedir = m.bot.botconfig[:URLDB_IMAGEDIR]
          imagedir = m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:imagedir]

          imagedir = imagedir + '/' unless imagedir =~ /\/$/
        
          recvd = ""
          
          if mytitle.nil? || mytitle.length == 0 || (imgurlink && imgurlink.length > 0)
            tempurl = url
            if imgurlink && imgurlink.length > 0
              tempurl = imgurlink
            end
          
            begin
              http = HTTPX.plugin(:follow_redirects).plugin(:cookies).plugin(:follow_redirects).with(timeout: { request_timeout: 15 }).with(headers: {
                'User-Agent' => (tempurl =~ /tiktok.com\// ? 'facebookexternalhit/1.1' : 'foo')
              })

              response = http.get(url)
        
              while chunk = response.body.read(16_384)
                recvd << chunk             
                response.close if recvd.length > 1024
              end

            rescue
              # EXCEPTION!
            end  
            response.close rescue nil 
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
                  http = HTTPX.plugin(:cookies).plugin(:follow_redirects).with(timeout: { request_timeout: 15 }).with(headers: {
                    'User-Agent' => (tempurl =~ /tiktok.com\// ? 'facebookexternalhit/1.1' : 'foo')
                  })

                  response = http.get(url)
            
                  while chunk = response.body.read(16_384)

                    saved_file.write(chunk) 
                    filesize += chunk.length;
                    response.close if recvd.length > 50000000   #~50 MB limit
                  end
                  
                rescue
                  # EXCEPTION!
                end   
                response.close rescue nil            
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

          if imagefile.nil? && imgurlink && imgurlink.length > 0
            imagefile = imgurlink
          end
          

          #entries = m.bot.botconfig[:DB][:TitleBot]
          entries = m.bot.botconfig[:DB][m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:table]]
          entries.insert(:Date => Sequel.function(:now), :Nick => m.user.to_s, :URL => url, :Title => mytitle.force_encoding('utf-8'), :ImageFile => imagefile)
            
          rescue Sequel::Error => e
          puts e.message
          botlog "[URLDB] [ERROR] #{e.message}", m
        end
        
        
      end
    end
    
  end
end