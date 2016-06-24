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
require 'mysql2'
require 'filemagic'
require 'securerandom'
require 'time'
require 'mime/types'
# }}}

LIKE_METACHARACTER_REGEX = /([\\%_])/
LIKE_METACHARACTER_ESCAPE = '\\\\\1'


def like_sanitize(value)
  raise ArgumentError unless value.respond_to?(:gsub)
  value.gsub(LIKE_METACHARACTER_REGEX, LIKE_METACHARACTER_ESCAPE)
end

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

def dbsym(msg)
  return ":::::"+msg.to_s+":::::"
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
          if(mostrecent.url != feed[:old])
            newentries = []
            
            feedparsed.entries.slice(0..10).each do |entry|
              break if entry.url == feed[:old]
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
        #info "Setting #{feed[:name]}[:old] to \"#{mostrecent.title}\""
        feed[:old] = mostrecent.url
      end
    end
    
    def printnew(entry, feedname, chans)
      chans.each do |chan|
        #info "[USER = #{m.user.to_s}] [CHAN = #{chan}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
        Channel(chan).send "\x02".b + "[#{feedname}]" + "\x0f".b + " #{entry.title} - #{entry.url}"
      end
    end
    
  end
  
  class DickBot
    include Cinch::Plugin
    set :react_on, :message
    
    match /^!imitate\s+(\S.*)$/, use_prefix: false, method: :imitate
    match /(?:twatbot|dickbot):?(?:\s+(.*))?$/i, use_prefix: false
    
    def gentext(order, nicks, seed)
      debug = 1
      info "SEED='#{seed}'" unless debug != 1
      
      order = 2 unless order == 1
      prng = Random.new      
      con =  Mysql2::Client.new(:host => MyApp::Config::DICKBOT_SQL_SERVER, :username => MyApp::Config::DICKBOT_SQL_USER, :password => MyApp::Config::DICKBOT_SQL_PASSWORD, :database => MyApp::Config::DICKBOT_SQL_DATABASE)
      con.query("SET NAMES utf8")
      
      if !nicks || nicks == "" || nicks.length == 0
        nick_filter = ""
      else
        nick_filter = " and Nick in ("
        nicks.each do |nick|
          nick_filter << "'#{nick}',"
        end
        nick_filter.chomp!(",")
        nick_filter << ") "
      end      
      info ">>>>>" + nick_filter
         
         
      sentence = ""
      wordcount = 0
        
      if(!seed || seed == "" || seed =~ /^\s*$/)
        word1 = dbsym("START")
        word2 = ""

      else
        info "COMPUTE FROM SEED BACKWARDS TO START" unless debug != 1
        seed.gsub!(/^\s*(\S+).*$/,'\1')
        
        if order == 1
          word2 = seed.dup
          sentence = seed.dup
          word1 = ""
          while word1 != dbsym("START") && word2 != dbsym("START")
            q = "select Word1, count(*) as count from WORDS1 where Word2 = '#{con.escape(word2)}' #{nick_filter} group by Word1 order by count(*) desc;"
            info q unless debug != 1
            result = con.query(q)
            info "done" unless debug != 1
            count = 0
            result.each do |r|
              count += r['count']
            end
            rand = prng.rand(count)
            info "#{rand} / #{count}" unless debug != 1
            count = 0
            word2 = ""
            result.each do |r|
              count += r['count']
              if count > rand
                word2 = r['Word1']
                break
              end
            end
            
            if word2 != dbsym("START")
              sentence = word2 + " " + sentence
              wordcount += 1
            end
          end
          
          word1 = seed.dup
          word2 = ""
          sentence += " "
          
        elsif order == 2
          word2 = seed.dup
          sentence = seed.dup
          word1 = ""
        
          q = "select Word1, count(*) as count from WORDS1 where Word2 = '#{con.escape(word2)}' #{nick_filter} group by Word1 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          count = 0
          result.each do |r|
            count += r['count']
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word1 = ""
          result.each do |r|
            count += r['count']
            if count > rand
              word1 = r['Word1']
              break
            end
          end
          
          word1save = word1.dup
          word2save = word2.dup
            
          if word1 != dbsym("START")
            sentence = word1 + " " + word2
            wordcount += 1            
          end
          
          word3 = word2.dup
          word2 = word1.dup
          
        
          while word2 != dbsym("START") && word3 != dbsym("START")
            q = "select Word1, count(*) as count from WORDS2 where Word2 = '#{con.escape(word2)}' and Word3 = '#{con.escape(word3)}' #{nick_filter} group by Word1 order by count(*) desc;"
            info q unless debug != 1
            result = con.query(q)
            info "done" unless debug != 1
            
            word3 = word2.dup
            
            count = 0
            result.each do |r|
              count += r['count']
            end
            rand = prng.rand(count)
            info "#{rand} / #{count}" unless debug != 1
            count = 0
            word2 = ""
            result.each do |r|
              count += r['count']
              if count > rand
                word2 = r['Word1']
                break
              end
            end
            
            if word2 != dbsym("START")
              sentence = word2 + " " + sentence
              wordcount += 1
            end
          end
          
          word1 = word1save.dup
          word2 = word2save.dup
          sentence += " "
          
        end
      
        info "DONE: COMPUTE FROM SEED BACKWARDS TO START" unless debug != 1
      end
      

  
      if order == 1
        while word1 != dbsym("END")
          q = "select Word2, count(*) as count from WORDS1 where Word1 = '#{con.escape(word1)}' #{nick_filter} group by Word2 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          count = 0
          result.each do |r|
            count += r['count']
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word1 = ""
          result.each do |r|
            count += r['count']
            if count > rand
              word1 = r['Word2']
              break
            end
          end
          
          if word1 != dbsym("END")
            sentence += word1 + " " 
            wordcount += 1
          end
        end
        
      elsif order == 2
        if word1 != dbsym("END") && word2 == ""
          q = "select Word2, count(*) as count from WORDS1 where Word1 = '#{con.escape(word1)}' #{nick_filter} group by Word2 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          count = 0
          result.each do |r|
            count += r['count']
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word2 = ""
          result.each do |r|
            count += r['count']
            if count > rand
              word2 = r['Word2']
              break
            end
          end
          
          if word2 != dbsym("END")
            sentence += word2 + " " 
            wordcount += 1
          end
        end
      
        while word1 != dbsym("END") && word2 != dbsym("END")
          q = "select Word3, count(*) as count from WORDS2 where Word1 = '#{con.escape(word1)}' and Word2 = '#{con.escape(word2)}' #{nick_filter} group by Word3 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          
          word1 = word2.dup
          
          count = 0
          result.each do |r|
            count += r['count']
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word2 = ""
          result.each do |r|
            count += r['count']
            if count > rand
              word2 = r['Word3']
              break
            end
          end
          
          if word2 != dbsym("END")
            sentence += word2 + " " 
            wordcount += 1
          end
        end        
      end
      
      return sentence.gsub(/Draylor/i, "Graylor")
    
    end
    
    def imitate(m, a)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"  
      a.strip!
      a.gsub!(/  /, " ") while a =~ /  /
      a = a.split(" ")
      nicks = a[0].split(",")
      info nicks.to_s
      
      m.reply gentext(2, nicks, nil)
    end
    
    def execute(m, a)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"           
      m.reply gentext(2, nil, a)      
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
  
  
  class QuoteDB
    include Cinch::Plugin
    set :react_on, :message
    
    match /^!ratequote\s+(\S.*)$/, use_prefix: false, method: :ratequote
    match /^!addquote\s+(\S.*)$/, use_prefix: false, method: :addquote
    match /^!(?:find|search)?quote\s+(\S.*)$/, use_prefix: false, method: :quote
    
    def initialize(*args)
      super
      @lastquotes = Hash.new
    end
    
    def ratequote(m, a)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
      a.strip!
      
      if a =~ /^(\d+)\s+(\d+)$/
        id = $1
        score = $2.to_i
        
        if score >=0 && score <= 10
          con =  Mysql2::Client.new(:host => MyApp::Config::QUOTEDB_SQL_SERVER, :username => MyApp::Config::QUOTEDB_SQL_USER, :password => MyApp::Config::QUOTEDB_SQL_PASSWORD, :database => MyApp::Config::QUOTEDB_SQL_DATABASE)
          con.query("SET NAMES utf8")
          result = con.query("select count(*) as count from quotes where id='#{con.escape(id)}'")
          
          if result && result.first && result.first['count'].to_i > 0
            
            result = con.query("select count(*) as count from quote_scr where id='#{con.escape(id)}' and handle='#{con.escape(m.user.to_s)}'")
            score_updated = 0
            if result && result.first && result.first['count'].to_i != 0
              score_updated = 1
              con.query("delete from quote_scr where id='#{con.escape(id)}' and handle='#{con.escape(m.user.to_s)}'")
            end
            
            con.query("insert into quote_scr (handle, id, score) values ('#{con.escape(m.user.to_s)}', '#{con.escape(id)}', '#{score.to_s}')")
            result = con.query("select count(*) as count, AVG(score) as score from quote_scr where id='#{con.escape(id)}' group by id")
            
            if result && result.first
              m.reply "#{score_updated == 1 ? "Your rating has been changed to #{score.to_s}.  " : "" }New score for quote #{id.to_s} is #{result.first['score'].to_f.round(2).to_s}, based on #{result.first['count'].to_s} ratings."
            end
            
          else
            m.reply "No such quote id (#{id.to_s})"
          end
          
        else
          m.reply "Score must be an integer from 0 to 10."
        end
      
      else
        m.reply "Usage: !ratequote <quote_id> <0,1,2,3,4,5,6,7,8,9,10>"      
      end
      
      con.close if con
      
    end
    
    
    def quote(m, a)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
      a.strip!
      return unless a.length > 0
      
      lqkey = m.channel.to_s + "::" + m.user.to_s;
      if(@lastquotes.key?(lqkey) && @lastquotes[lqkey][:quote] == a && @lastquotes[lqkey][:time] >= (Time.now.getutc.to_i - 60))
        @lastquotes[lqkey][:offset] += 1
        @lastquotes[lqkey][:time] = Time.now.getutc.to_i
      else
        @lastquotes[lqkey] = Hash.new
        @lastquotes[lqkey][:quote] = a
        @lastquotes[lqkey][:offset] = 0
        @lastquotes[lqkey][:time] = Time.now.getutc.to_i
      end

      info @lastquotes[lqkey][:offset].to_s
      #info @lastquotes.key(lqkey) && @lastquotes[lqkey][:quote] == a && @lastquote[lqkey][:time] >= (Time.now.getutc.to_i - 60))

      con =  Mysql2::Client.new(:host => MyApp::Config::QUOTEDB_SQL_SERVER, :username => MyApp::Config::QUOTEDB_SQL_USER, :password => MyApp::Config::QUOTEDB_SQL_PASSWORD, :database => MyApp::Config::QUOTEDB_SQL_DATABASE)
      con.query("SET NAMES utf8")
      idclause = "  "
      if a =~ /^\d+$/
        idclause = " or a.id='#{a.to_s}' "
      end
      
      result = con.query("select a.*, b.score from quotes a left join (select id, AVG(score) as score from quote_scr group by id ) b on a.id=b.id where quote LIKE '%#{con.escape(like_sanitize(a))}%' #{idclause} order by timestamp desc limit 1 offset #{@lastquotes[lqkey][:offset]}")
           

      con.close if con

      
      if result && result.count > 0
        m.reply "\x03".b + "03" + "[ #{result.first['id']} / #{result.first['score'] ? result.first['score'].to_f.round(2).to_s : 'NO VOTES'} / #{result.first['nick']} @ #{Time.at(result.first['timestamp'].to_i).strftime("%-d %b %Y")} ]" + "\x0f".b + " #{result.first['quote']}"
      else
        m.reply "No matches."
        @lastquotes[lqkey][:offset] = -1
      end
      
    
    end
    
    
    def addquote(m, a)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"       
      a.strip!
      
      begin
        con =  Mysql2::Client.new(:host => MyApp::Config::QUOTEDB_SQL_SERVER, :username => MyApp::Config::QUOTEDB_SQL_USER, :password => MyApp::Config::QUOTEDB_SQL_PASSWORD, :database => MyApp::Config::QUOTEDB_SQL_DATABASE)
        con.query("SET NAMES utf8")
        con.query("INSERT INTO quotes(nick, host, quote, channel, timestamp) VALUES ('#{con.escape(m.user.to_s)}', '#{con.escape(m.user.mask.to_s)}', '#{con.escape(a)}', '#{con.escape(m.channel.to_s)}', '#{con.escape(m.time.to_i.to_s)}')")
        id = con.last_id
        
        rescue Mysql2::Error => e
        puts e.errno
        puts e.error
        info "[DEBUG] [QUOTEDB] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + e.errno.to_s + " " + e.error
        
        ensure
        con.close if con
      end
      
      m.reply "Added quote #{id.to_s}."
      
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
          #con = Mysql.new MyApp::Config::URLDB_SQL_SERVER, MyApp::Config::URLDB_SQL_USER, MyApp::Config::URLDB_SQL_PASSWORD, MyApp::Config::URLDB_SQL_DATABASE
          #con.query("SET NAMES utf8")
          #con.query("INSERT INTO TitleBot(Date, Nick, URL, Title, ImageFile) VALUES (NOW(), '#{con.escape_string(m.user.to_s)}', '#{con.escape_string(url)}', #{!mytitle.nil? ? "'" + con.escape_string(mytitle.force_encoding('utf-8')) + "'" : "''"}, #{imagefile.nil? ? "NULL" : "'" + con.escape_string(imagefile) + "'"})")
          
          con =  Mysql2::Client.new(:host => MyApp::Config::URLDB_SQL_SERVER, :username => MyApp::Config::URLDB_SQL_USER, :password => MyApp::Config::URLDB_SQL_PASSWORD, :database => MyApp::Config::URLDB_SQL_DATABASE)
          con.query("SET NAMES utf8")
          con.query("INSERT INTO TitleBot(Date, Nick, URL, Title, ImageFile) VALUES (NOW(), '#{con.escape(m.user.to_s)}', '#{con.escape(url)}', #{!mytitle.nil? ? "'" + con.escape(mytitle.force_encoding('utf-8')) + "'" : "''"}, #{imagefile.nil? ? "NULL" : "'" + con.escape(imagefile) + "'"})")
          
          
          rescue Mysql2::Error => e
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


a = Thread.new do
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

  puts "A"
  bot.loggers.level = :info
  bot.start
end

if MyApp::Config::DICKBOT_ENABLE == 1
  b = Thread.new do
    dickbot = Cinch::Bot.new do
      configure do |c|
        c.server = MyApp::Config::DICKBOT_IRC_SERVER
        c.port = MyApp::Config::DICKBOT_IRC_PORT
        c.channels = MyApp::Config::DICKBOT_IRC_CHANNELS
        c.user = MyApp::Config::DICKBOT_IRC_USER
        c.password = MyApp::Config::DICKBOT_IRC_PASSWORD
        c.ssl.use = MyApp::Config::DICKBOT_IRC_SSL
        c.nick = MyApp::Config::DICKBOT_IRC_NICK
        c.plugins.plugins = class_from_string_array(MyApp::Config::DICKBOT_IRC_PLUGINS)
      end    
    end
    
    puts "B"
    dickbot.loggers.level = :info
    dickbot.start
  end
end

a.join
b.join if MyApp::Config::DICKBOT_ENABLE == 1

