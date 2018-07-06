require 'uri'

module Plugins  
  class CloudVision
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel, method: :cv_listen
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!analyze\s+(\S.*)$/, use_prefix: false, method: :cv_analyze
    
    def initialize(*args)
      super
      @config = bot.botconfig
    end


    def help(m)
      m.user.notice "\x02".b + "\x03".b + "04" + "CloudVision:\n" + "\x0f".b + 
      "\x02".b + "  <any image URL>" + "\x0f".b + " - Get Google Cloud Vision image analysis.\n" +
      "\x02".b + "  !analyze <urls>" + "\x0f".b + " - Get Google Cloud Vision image analysis.\n"
    end
    
    def cv_analyze(m)
      cv_listen(m,1)
    end


    def cv_listen(m, skipcheck=0)
      if skipcheck==0 && !@config[:CLOUD_VISION_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end 

      URI.extract(m.message, ["http", "https"]) do |url|

        botlog "[CloudVision = #{url}]",m
        
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
                     
            if !image.nil?
              search = image
            elsif !album.nil?
              search = album
            end
            
            if !search.nil?          
                            
              if search.body["data"].key?("images_count")

                if search.body["data"].key?("cover") && !search.body["data"]["cover"].nil? && search.body["data"]["cover"].length > 0
                  cover = search.body["data"]["cover"]
                  image = Unirest::get("https://api.imgur.com/3/image/#{cover}.json", headers:{ "Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] })
                  if !image.body || !image.body.key?("success") || image.body["success"] != true || !image.body.key?("data")
                    image = nil
                  end
                end

              end
              
              if !image.nil?
                if image.body["data"].key?("link") && !image.body["data"]["link"].nil? && image.body["data"]["link"].length > 0
                  imgurlink = image.body["data"]["link"]
                end
              end

            end
            
          end
        end
        ###########################
        
        
        imagefile = 0

        if 1==1 #!m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:imagedir].nil? && Dir.exists?(m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:imagedir])
        
          recvd = ""          

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


          if recvd.length > 0
            fm = FileMagic.mime
            ft = fm.buffer(recvd)
            if ft =~ /^((?:image\/)[^;]*)/
              mimetype = $1
              imagefile = 1             
            end        
          end

        end
        
        botlog "[CloudVision_IS_IMAGE (#{imagefile}) = #{tempurl}]",m

        

        if imagefile == 1
          dat = {"requests":[{"image":{"source":{"imageUri":tempurl}},"features":[{"type":"LABEL_DETECTION"},{"type":"WEB_DETECTION"},{"type":"SAFE_SEARCH_DETECTION"},{"type":"TEXT_DETECTION"}]}]}
          x = Unirest.post("https://vision.googleapis.com/v1/images:annotate?key=#{@config[:CLOUD_VISION_APIKEY]}", headers:{ "Content-Type" => "application/json" }, parameters: dat.to_json )



          if x && x.body && x.body.key?("responses") && x.body["responses"].length == 1
            myreply = ""
            myreply << "\x03".b + "04" 
            myreply << "[ANALYSIS] "
            myreply << "\x0f".b

            x = x.body["responses"][0]

            if x.key?("safeSearchAnnotation")
              myreply << "\x03".b + "04" + "[ADULT] "    + "\x0f".b if x["safeSearchAnnotation"].key?("adult")    && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["adult"])
              myreply << "\x03".b + "04" + "[RACY] "     + "\x0f".b if x["safeSearchAnnotation"].key?("racy")     && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["racy"])
              myreply << "\x03".b + "04" + "[SPOOF] "    + "\x0f".b if x["safeSearchAnnotation"].key?("spoof")    && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["spoof"])
              myreply << "\x03".b + "04" + "[MEDICAL] "  + "\x0f".b if x["safeSearchAnnotation"].key?("medical")  && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["medical"])
              myreply << "\x03".b + "04" + "[VIOLENCE] " + "\x0f".b if x["safeSearchAnnotation"].key?("violence") && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["violence"])         
            end

            if x.key?("webDetection") && x["webDetection"].key?("bestGuessLabels")
              myreply << "\"" + "\x02".b + x["webDetection"]["bestGuessLabels"].select{|z| z.key?("label") && z["label"].length > 0}[0..5].map{|z| z["label"]}.join(", ") + "\x0f".b + "\" "
            end

            yyz = []

            if x.key?("webDetection") && x["webDetection"].key?("webEntities")
              yyz += x["webDetection"]["webEntities"].select{|z| z.key?("description") && z["description"].length > 0}[0..5].map{|z| z["description"]} #.join(" ") + " "
            end

            if x.key?("labelAnnotations")
              yyz += x["labelAnnotations"].select{|z| z.key?("description") && z["description"].length > 0 && z["score"] > 0.85}[0..5].map{|z| z["description"]} #.join(" ") + " "
            end

            yyz = yyz.uniq{ |elem| elem.downcase }
            myreply << yyz.join(", ") + " "

            if x.key?("fullTextAnnotation") && x["fullTextAnnotation"].key?("text")
              myreply << "TEXT=\"" + x["fullTextAnnotation"]["text"][0..100].gsub(/[[:space:]\r\n]+/, ' ') + "\" "
            end

            


            m.reply myreply
          end
        end

      end
    end    
  end
end