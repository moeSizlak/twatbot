# TWATBOT (c) 2016 moeSizlak

# Requires {{{
require 'cgi'
require 'imdb'
require 'cinch'
require 'ethon'
require 'unirest'
require 'ruby-duration'
require 'feedjira'
require 'htmlentities'
require 'mysql'
require 'filemagic'
require 'securerandom'
require 'time'
require 'mime/types'
# }}}


def class_from_string(str)
  str.split('::').inject(Object) do |mod, class_name|
    mod.const_get(class_name)
  end
end

def class_from_string_array(arr)
  arr.each_with_index do |str, index|
    str.split('::').inject(Object) do |mod, class_name|
      arr[index] = mod.const_get(class_name)
    end
  end
end

module URLHandlers
  class Youtube
    def self.parse(url)      
      if(url =~ /.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|watch\?(?:(?!v=)[^&]+&)+v=)([^#\&\?\s]*).*/i)
        id = $1
        search = Unirest::get("https://www.googleapis.com/youtube/v3/videos?id=" + id + "&key=" + MyApp::Config::YOUTUBE_GOOGLE_SERVER_KEY + "&part=snippet,contentDetails,statistics,status")
        
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
          
          color_yt = "03"     
          color_name = "04"
          color_rating = "07"
          color_url = "03"
          
          myreply = "\x03".b + color_yt + "[YouTube] " + "\x0f".b + 
          "\x03".b + color_name + (title.nil? ? "UNKOWN_TITLE" : title) + "\x0f".b +
          "\x03".b + color_rating +
          (duration.nil? ? ""    : (" (" + duration    + ")")) +    
          (publishedAt.nil? ? "" : (" [" + publishedAt + "]")) +
          " ["         + viewCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + 
          " views] [+" + likeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + 
          "/-"         + dislikeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "]" +
          "\x0f".b
          
          return myreply
        end      
      end
      return nil
    end    
  end
  
  
  class Imgur
    def self.parse(url)  
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
            gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
            
            if gallery.body && gallery.body.key?("success") && gallery.body["success"] == true && gallery.body.key?("data")
              if gallery.body["data"].key?("is_album") && gallery.body["data"]["is_album"] == true
                album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
                if !album.body || !album.body.key?("success") || !album.body["success"] == true || !album.body.key?("data")
                  album = nil
                end
              else
                image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
                if !image.body || !image.body.key?("success") || !image.body["success"] == true || !image.body.key?("data")
                  image = nil
                end
              end
            else
              gallery = nil
            end
            
          elsif type == "album"
            album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
            
            if album.body && album.body.key?("success") && album.body["success"] == true && album.body.key?("data")
              if album.body["data"].key?("in_gallery") && album.body["data"]["in_gallery"] == true
                gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
                if !gallery.body || !gallery.body.key?("success") || !gallery.body["success"] == true || !gallery.body.key?("data")
                  gallery = nil
                end
              end
            else
              album = nil
            end
            
          elsif type == "image"
            image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
            
            if image.body && image.body.key?("success") && image.body["success"] == true && image.body.key?("data")
              if image.body["data"].key?("in_gallery") && image.body["data"]["in_gallery"] == true
                gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
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
              mytitle = TitleBot::getTitle(gallery ? "http://imgur.com/gallery/#{path}" : (album ? "http://imgur.com/a/#{path}" : "http://imgur.com/#{path}")).to_s
            end
            
            if mytitle && mytitle.length > 0 && mytitle !~ /Imgur: The most awesome images on the Internet/
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
  
  
  class IMDB
    def self.parse(url)
      if(url =~ /https?:\/\/[^\/]*imdb.com.*\/title\/\D*(\d+)/i)
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
          
          color_imdb = "03"     
          color_name = "04"
          color_rating = "07"
          color_url = "03"
          
          myreply =
          "\x03".b + color_name + i.title + " (" + i.year.to_s + ")" + "\x0f".b + 
          "\x03".b + color_rating + " [IMDB: " + i.rating.to_s + "/10] [" + i.votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes] " + 
          myrating + mygenres + "\x0f".b + 
          (i.plot)[0..255]
          
          return myreply
        end
      end
      return nil
    end
    
  end
  
  class Dumpert
    def self.parse(url)
      if(url =~ /(https?:\/\/([^\/\.]*\.)*dumpert\.nl\S+)/i)      
        title = TitleBot::getTitle(url)
        if !title.nil?          
          title = '' + Nokogiri::HTML.parse(title.force_encoding('utf-8').gsub(/\s{2,}/, ' ')).text        
          search = Unirest::get("https://translate.googleapis.com/translate_a/single?client=gtx&sl=nl&tl=en&dt=t&q=" + CGI.escape(title.gsub(/^\s*dumpert\.nl\s*-\s*/, '')))
          
          if search.body
            search = search.body
            search.gsub!(/,+/, ',')
            search.gsub!(/\[,/, '[')
            search = JSON.parse(search.body)
            
            if search.size > 0 && search[0].size > 0 && search[0][0].size > 0
              title = title + 
              "\x03".b + "04" + "  [" + search[0][0][0] + "]" + "\x0f".b
              
              return title
            end
          end        
        end
      end
      return nil
    end
  end
  
  class TitleBot
    def self.parse(url)
      title = TitleBot::getTitle(url);
      if !title.nil?
        url =~ /https?:\/\/([^\/]+)/
        host = $1
        return "[ " + title + " ] - " + host
      end
      
      return nil    
    end  
    
    def self.getTitle(url)
      coder = HTMLEntities.new
      recvd = String.new
      
      begin
        easy = Ethon::Easy.new url: url, followlocation: true, ssl_verifypeer: false, headers: {
          'User-Agent' => 'foo'
        }
        easy.on_body do |chunk, easy|
          recvd << chunk
          
          recvd =~ Regexp.new('<title[^>]*>\s*((?:(?!</title>).)*)\s*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found.strip!
            title_found.gsub!(/[\s\r\n]+/m, ' ')
            return Cinch::Helpers.sanitize coder.decode title_found.force_encoding('utf-8')
          end
          
          :abort if recvd.length > 131072 || title_found
        end
        easy.perform
        rescue
        # EXCEPTION!
      end
      
      return nil
    end
    
    
    
  end
  
  
  
end

module Plugins
  class RSSFeed
    include Cinch::Plugin
    set :react_on, :channel
    
    timer 0,  {:method => :updatefeed, :shots => 1}
    timer 300, {:method => :updatefeed}  
    
    def initialize(*args)
      super
      @feeds = MyApp::Config::RSS_FEEDS
    end
    
    def updatefeed
      @feeds.each do |feed|      
        feedparsed = Feedjira::Feed.fetch_and_parse(feed[:url])    
        mostrecent = feedparsed.entries.first
        
        if !feed[:old].nil?
          if(mostrecent.title != feed[:old])
            newentries = []
            
            feedparsed.entries.slice(0..10).each do |entry|
              break if entry.title == feed[:old]
              newentries.unshift entry
            end
            
            newentries.each do |newentry|
              info "Printing new RSS entry \"#{newentry.title}\""
              printnew(newentry, feed[:name], feed[:chans])
            end
          end
          else
          #printnew(mostrecent, feed[:name], feed[:chans])          
        end 
        info "Setting #{feed[:name]}[:old] to \"#{mostrecent.title}\""
        feed[:old] = mostrecent.title
      end
    end
    
    def printnew(entry, feedname, chans)
      chans.each do |chan|
        #info "[USER = #{m.user.to_s}] [CHAN = #{chan}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
        Channel(chan).send "\x02".b + "[#{feedname}]" + "\x0f".b + " #{entry.title} - #{entry.url}"
      end
    end
    
  end
  
  
  class URL
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel
    
    def initialize(*args)
      super
      @handlers = MyApp::Config::URL_SUB_PLUGINS
    end
    
    def listen(m)
      URI.extract(m.message, ["http", "https"]) do |link|
        @handlers.each do |handler|
          if !handler[:excludeChans].include?(m.channel.to_s) && !handler[:excludeNicks].include?(m.user.to_s)
            output = class_from_string(handler[:class])::parse(link)
            if !output.nil?
              info "[Handler = #{handler[:class]}] [URL = #{link}] [USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
              m.reply output
              break
            end
          end
        end
      end
    end
    
  end
  
  
  class URLDB
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel
    
    def listen(m)
      if !MyApp::Config::URLDB_CHANS.include?(m.channel.to_s) || MyApp::Config::URLDB_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end
      
      URI.extract(m.message, ["http", "https"]) do |url|
        info "[URL = #{url}] [USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
        
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
              gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
              
              if gallery.body && gallery.body.key?("success") && gallery.body["success"] == true && gallery.body.key?("data")
                if gallery.body["data"].key?("is_album") && gallery.body["data"]["is_album"] == true
                  album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
                  if !album.body || !album.body.key?("success") || !album.body["success"] == true || !album.body.key?("data")
                    album = nil
                  end
                else
                  image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
                  if !image.body || !image.body.key?("success") || !image.body["success"] == true || !image.body.key?("data")
                    image = nil
                  end
                end
              else
                gallery = nil
              end
              
            elsif type == "album"
              album = Unirest::get("https://api.imgur.com/3/album/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
              
              if album.body && album.body.key?("success") && album.body["success"] == true && album.body.key?("data")
                if album.body["data"].key?("in_gallery") && album.body["data"]["in_gallery"] == true
                  gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
                  if !gallery.body || !gallery.body.key?("success") || !gallery.body["success"] == true || !gallery.body.key?("data")
                    gallery = nil
                  end
                end
              else
                album = nil
              end
              
            elsif type == "image"
              image = Unirest::get("https://api.imgur.com/3/image/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
              
              if image.body && image.body.key?("success") && image.body["success"] == true && image.body.key?("data")
                if image.body["data"].key?("in_gallery") && image.body["data"]["in_gallery"] == true
                  gallery = Unirest::get("https://api.imgur.com/3/gallery/#{path}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
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
                  image = Unirest::get("https://api.imgur.com/3/image/#{cover}.json", headers:{ "Authorization" => "Client-ID " + MyApp::Config::IMGUR_API_CLIENT_ID })
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

        if Dir.exists?(MyApp::Config::URLDB_IMAGEDIR)
          imagedir = MyApp::Config::URLDB_IMAGEDIR
          imagedir = imagedir + '/' unless imagedir =~ /\/$/
        
          recvd = ""
          
          if mytitle.nil? || mytitle.length == 0 || (imgurlink && imgurlink.length > 0)
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
              
              if filesize == 0 || filesize >= 10000000
                File.delete(imagedir + imagefile)
                imagefile = nil
              end
              
            end        
          end
        end
        
        begin
          con = Mysql.new MyApp::Config::URLDB_SQL_SERVER, MyApp::Config::URLDB_SQL_USER, MyApp::Config::URLDB_SQL_PASSWORD, MyApp::Config::URLDB_SQL_DATABASE
          con.query("SET NAMES utf8")
          con.query("INSERT INTO TitleBot(Date, Nick, URL, Title, ImageFile) VALUES (NOW(), '#{con.escape_string(m.user.to_s)}', '#{con.escape_string(url)}', #{!mytitle.nil? ? "'" + con.escape_string(mytitle.force_encoding('utf-8')) + "'" : "''"}, #{imagefile.nil? ? "NULL" : "'" + con.escape_string(imagefile) + "'"})")
          
          rescue Mysql::Error => e
          puts e.errno
          puts e.error
          info "[DEBUG] [TITLEBOT] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + e.errno.to_s + " " + e.error
          
          ensure
          con.close if con
        end
        
        
      end
    end
    
  end
  
  
  class IMDB
    include Cinch::Plugin
    set :react_on, :message
    
    match /^[.!]imdb\s+(.*)$/i, use_prefix: false
    
    def execute(m, id)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
      
      
      if MyApp::Config::IMDB_EXCLUDE_CHANS.include?(m.channel.to_s) || MyApp::Config::IMDB_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end
      
      color_imdb = "03"     
      color_name = "04"
      color_rating = "07"
      color_url = "03"
      
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
        
        myreply = 
        "\x03".b + color_name + i.movies[0].title + "\x0f".b + 
        "\x03".b + color_rating + " [IMDB: " + i.movies[0].rating.to_s + "/10] [" + i.movies[0].votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes] " + 
        myrating + mygenres + "\x0f".b + 
        "\x03".b + color_url + i.movies[0].url.gsub!(/\/combined/, "").gsub!(/akas\.imdb\.com/,"www.imdb.com") + "\x0f".b + 
        " - " + (i.movies[0].plot)[0..255]
        
        m.reply myreply
        return
      end
      m.reply "No matching movies found.  [\"#{id}\"]"
    end
  end
  
  
  
  class TvMaze
    include Cinch::Plugin
    set :react_on, :message
    
    match /^@(\d*)\s*(\S.*)$/, use_prefix: false
    
    def execute(m, hitno, id)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
      
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
        end
        else
        myreply = "No matching shows found.  [" + (hitno != 0 ? "Searching for the #" + (hitno + 1).to_s + " search result for " : "") + "\"" + id.to_s + "\"]"
        m.reply myreply
      end
    end
    
    
  end
  
  class MoeBTC
    include Cinch::Plugin
    set :react_on, :message
    
    match /^\.moe/i, use_prefix: false
    
    def execute(m)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
    
      x = rand
      myreply = "\x03".b + "04" + "Bitstamp" + "\x0f".b + " | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      m.reply myreply
    end
  end
  
end

if !ARGV || ARGV.length != 1
  abort "ERROR: Usage: ruby #{$0} <CONFIG_FILE>"
  elsif !File.exist?(ARGV[0])
  abort "ERROR: Config file not found: #{ARGV[0]}"
  else
  require File.absolute_path(ARGV[0])
end


bot = Cinch::Bot.new do
  configure do |c|
    c.server = MyApp::Config::IRC_SERVER
    c.port = MyApp::Config::IRC_PORT
    c.channels = MyApp::Config::IRC_CHANNELS
    c.user = MyApp::Config::IRC_USER
    c.password = MyApp::Config::IRC_PASSWORD
    c.ssl.use = MyApp::Config::IRC_SSL
    c.nick = MyApp::Config::IRC_NICK
    c.plugins.plugins = class_from_string_array(MyApp::Config::IRC_PLUGINS)
  end  
  
end

bot.loggers.level = :info

bot.start

