require 'uri'
require 'base64'
require 'httpx'

module Plugins  
  class CloudVision
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel, method: :cv_listen
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!analy[zs]e\s+(\S.*)$/, use_prefix: false, method: :cv_analyze
    
    def initialize(*args)
      super
      @config = bot.botconfig
    end


    def help(m)
      m.user.notice "\x02\x0304CloudVision:\n\x0f" + 
      "\x02  <any image URL>\x0f - Get Google Cloud Vision image analysis.\n" +
      "\x02  !analyze <urls>\x0f - Get Google Cloud Vision image analysis.\n"
    end
    
    def cv_analyze(m)
      cv_listen(m,1)
    end


    def cv_listen(m, skipcheck=0)
      if (skipcheck==0 && (!@config[:CLOUD_VISION_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.message =~ /^!analyze\s+/))
        return
      end 

      banned_labels = ['human hair color']

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
                     
            if !image.nil?
              search = image
            elsif !album.nil?
              search = album
            end
            
            if !search.nil?          
                            
              if search["data"].key?("images_count")

                if search["data"].key?("cover") && !search["data"]["cover"].nil? && search["data"]["cover"].length > 0
                  cover = search["data"]["cover"]
                  image = HTTPX.plugin(:follow_redirects).with(headers: {"Authorization" => "Client-ID " + m.bot.botconfig[:IMGUR_API_CLIENT_ID] }).get("https://api.imgur.com/3/image/#{cover}.json").json
                  if !image || !image.key?("success") || image["success"] != true || !image.key?("data")
                    image = nil
                  end
                end

              end
              
              if !image.nil?
                if image["data"].key?("link") && !image["data"]["link"].nil? && image["data"]["link"].length > 0
                  imgurlink = image["data"]["link"]
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
            http = HTTPX.plugin(:follow_redirects).plugin(:cookies).plugin(:follow_redirects).with(timeout: { request_timeout: 15 }).with(headers: {'User-Agent' => 'foo' })
            response = http.get(url)

        while chunk = response.read(16_384)
            recvd << chunk             
            response.close if recvd.length > 50000000
          end
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
          if skipcheck == 1
            dat = {"requests":[{"image":{"source":{"imageUri":tempurl}},"features":[{"type":"LABEL_DETECTION"},{"type":"WEB_DETECTION"},{"type":"SAFE_SEARCH_DETECTION"},{"type":"TEXT_DETECTION"}]}]}
          else
            dat = {"requests":[{"image":{"source":{"imageUri":tempurl}},"features":[{"type":"LABEL_DETECTION"},{"type":"WEB_DETECTION"}]}]}
          end

          x = HTTPX.plugin(:follow_redirects).with(headers: { "Content-Type" => "application/json" }).post("https://vision.googleapis.com/v1/images:annotate?key=#{@config[:CLOUD_VISION_APIKEY]}", json: dat ).json



          if x && x && x.key?("responses") && x["responses"].length == 1
            myreply_simple = ""
            myreply_simple << "\x0303" 
            myreply_simple << "[IMAGE] "
            myreply_simple << "\x0f"

            myreply = ""
            myreply << "\x0304" 
            myreply << "[ANALYSIS] "
            myreply << "\x0f"

            x = x["responses"][0]

            

            if x.key?("error") && x["error"].key?("code") && (x["error"]["code"] == 13 || x["error"]["code"] == 7 || (x["error"].key?("message") && x["error"]["message"] =~ /download the content/i))
              puts "ERROR #{x["error"]["code"]}!!!: FALLING BACK TO BASE64 IMAGE SENDING\n"
              if skipcheck == 1
                dat = {"requests":[{"image":{"content":Base64.encode64(recvd)},"features":[{"type":"LABEL_DETECTION"},{"type":"WEB_DETECTION"},{"type":"SAFE_SEARCH_DETECTION"},{"type":"TEXT_DETECTION"}]}]}
              else
                dat = {"requests":[{"image":{"content":Base64.encode64(recvd)},"features":[{"type":"LABEL_DETECTION"},{"type":"WEB_DETECTION"}]}]}
              end
              recvd = nil
              x = HTTPX.plugin(:follow_redirects).with(headers: { "Content-Type" => "application/json" }).post("https://vision.googleapis.com/v1/images:annotate?key=#{@config[:CLOUD_VISION_APIKEY]}", json: dat ).json
              if x && x && x.key?("responses") && x["responses"].length == 1
                x = x["responses"][0]
                if x.key?("error") && x["error"].key?("message")
                  myreply << x["error"]["message"]
                  m.reply myreply
                  return
                end
              end
            else
              if x.key?("error") && x["error"].key?("message")
                myreply << x["error"]["message"]
                m.reply myreply
                return
              end
            end

            if x.key?("safeSearchAnnotation")
              myreply << "\x0307[ADULT] \x0f" if x["safeSearchAnnotation"].key?("adult")    && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["adult"])
              myreply << "\x0307[RACY] \x0f" if x["safeSearchAnnotation"].key?("racy")     && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["racy"])
              myreply << "\x0307[SPOOF] \x0f" if x["safeSearchAnnotation"].key?("spoof")    && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["spoof"])
              myreply << "\x0307[MEDICAL] \x0f" if x["safeSearchAnnotation"].key?("medical")  && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["medical"])
              myreply << "\x0307[VIOLENCE] \x0f" if x["safeSearchAnnotation"].key?("violence") && ['POSSIBLE', 'LIKELY', 'VERY_LIKELY'].include?(x["safeSearchAnnotation"]["violence"])         
            end

            if x.key?("webDetection") && x["webDetection"].key?("bestGuessLabels")
              myreply << "\"\x02" + x["webDetection"]["bestGuessLabels"].select{|z| z.key?("label") && z["label"].length > 0}[0..5].map{|z| z["label"]}.join(", ") + "\x0f\" "
              myreply_simple << x["webDetection"]["bestGuessLabels"].select{|z| z.key?("label") && z["label"].length > 0}[0..5].map{|z| z["label"]}.join(", ") + " "
            end

            yyz = []
            yyz_simple = []

            if x.key?("webDetection") && x["webDetection"].key?("webEntities")
              yyz += x["webDetection"]["webEntities"].select{|z| z.key?("description") && z["description"].length > 0 && !banned_labels.include?(z["description"])}[0..5].map{|z| z["description"]} #.join(" ") + " "
            end

            if x.key?("labelAnnotations")
              yyz += x["labelAnnotations"].select{|z| z.key?("description") && z["description"].length > 0 && z["score"] > 0.85 && !banned_labels.include?(z["description"])}[0..5].map{|z| z["description"]} #.join(" ") + " "
              yyz_simple += x["labelAnnotations"].select{|z| z.key?("description") && z["description"].length > 0 && z["score"] > 0.85 && !banned_labels.include?(z["description"])}[0..5].map{|z| z["description"]} #.join(" ") + " "
            end

            yyz = yyz.uniq{ |elem| elem.downcase }
            myreply << "(" + yyz.join(", ") + ")"

            yyz_simple = yyz_simple.uniq{ |elem| elem.downcase }
            myreply_simple << "(" + yyz_simple.join(", ") + ")"

            if x.key?("fullTextAnnotation") && x["fullTextAnnotation"].key?("text")
              #myreply << "TEXT=\"" + x["fullTextAnnotation"]["text"][0..100].gsub(/[[:space:]\r\n]+/, ' ') + "\" "
              ##myreply << ", \x1d\"" + x["fullTextAnnotation"]["text"][0..150].gsub(/[[:space:]\r\n]+/, ' ') + "\" \x0f"
            end

            

            if skipcheck == 0
              m.reply myreply_simple
            else
              m.reply myreply
            end

          end
        end

      end
    end    
  end
end