require "open-uri"
require "nokogiri"
require "typhoeus"
require "json"
require "htmlentities"
require "thread"
require 'digest'

module Plugins
  class TwitterFeed
    include Cinch::Plugin
    set :react_on, :channel

    @@params = params = {
      "expansions": "author_id,referenced_tweets.id",
      "tweet.fields": "attachments,author_id,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang,public_metrics",
      "user.fields": "id,name,username,verified"
      #{}"tweet_mode": "extended"
      # "media.fields": "url", 
      # "place.fields": "country_code",
      # "poll.fields": "options"
    }
    @@stream_url = "https://api.twitter.com/2/tweets/search/stream"
    @@rules_url = "https://api.twitter.com/2/tweets/search/stream/rules"

    @@rules = {}
    @@stream_thread_mutex = Mutex.new



    def initTwitterStream

      # GET CURRENT RULES
      options = {
        connecttimeout: 10,
        headers: {
          "User-Agent": "v2FilteredStreamRuby",
          "Authorization": "Bearer #{@config[:TWITTER_BEARER_TOKEN]}"
        }
      }
      response = Typhoeus.get(@@rules_url, options)
      raise "(#{Thread.current.object_id}) An error occurred while retrieving active rules from stream: #{response.body}" unless response.success?
      rules = JSON.parse(response.body)
      #botlog "(#{Thread.current.object_id}) CURRENT RULES = #{JSON.pretty_generate(rules)}"
      
      # DELETE ALL CURRENT RULES
      if !rules.nil? && !rules['data'].nil?
        ids = rules['data'].map { |rule| rule["id"] }
        payload = {
          delete: {
            ids: ids
          }
        }

        options = {
          connecttimeout: 10,
          headers: {
            "User-Agent": "v2FilteredStreamRuby",
            "Authorization": "Bearer #{@config[:TWITTER_BEARER_TOKEN]}",
            "Content-type": "application/json"
          },
          body: JSON.dump(payload)
        }

        response = Typhoeus.post(@@rules_url, options)
        raise "(#{Thread.current.object_id}) An error occurred while deleting rules: #{response.status_message}" unless response.success?
      end

      # SET RULES
      return if @@rules.empty?

      botlog "@@rules=\"#{@@rules.inspect}\" ===> #{@@rules.map{|x,y| {'value' => x, 'tag' => y[0][:md5]}}.inspect}"
      payload = {
        add: @@rules.map{|x,y| {'value' => x, 'tag' => y[0][:md5]}}
      }

      options = {
        connecttimeout: 10,
        headers: {
          "User-Agent": "v2FilteredStreamRuby",
          "Authorization": "Bearer #{@config[:TWITTER_BEARER_TOKEN]}",
          "Content-type": "application/json"
        },
        body: JSON.dump(payload)
      }

      response = Typhoeus.post(@@rules_url, options)
      raise "(#{Thread.current.object_id}) An error occurred while adding rules: #{response.status_message}" unless response.success?

      ######################

      options = {
        timeout: 0,
        connecttimeout: 10,
        method: 'get',
        headers: {
          "User-Agent": "v2FilteredStreamRuby",
          "Authorization": "Bearer #{@config[:TWITTER_BEARER_TOKEN]}"
        },
        params: @@params
      }

      lastchunk = 0
      lastchunk_mutex = Mutex.new
      reconnect_timeout = 0

      while true

        botlog "(#{Thread.current.object_id}) timeout='#{reconnect_timeout}', sleeping #{(2 ** reconnect_timeout) - 1} seconds"
        sleep (2 ** reconnect_timeout) - 1

        t1 = Thread.new do
          tweet = nil
          recvd = String.new
          request = Typhoeus::Request.new(@@stream_url, options)

          request.on_body do |chunk|

            lastchunk_mutex.synchronize do
              lastchunk = Time.now.to_i
            end


            if chunk !~ /^\s*$/ || recvd.length > 0
              recvd << chunk             

              begin
                tweet = JSON.parse(recvd)

                matching_tags = tweet.dig("matching_rules").map{|x| x['tag']}
                matching_rules = @@rules.select{|x,y| matching_tags.include?(y[0][:md5])}
                plugin_objects = []
                matching_rules.each{|x,y| y.each{|z| plugin_objects.push(z[:plugin])}}


                botlog "(#{Thread.current.object_id}) matching_tags=\"#{matching_tags.inspect}\""
                botlog "(#{Thread.current.object_id}) plugin_objects=\"#{plugin_objects.inspect}\""
                
                plugin_objects.each do |p|
                  ObjectSpace._id2ref(p).print_tweet(tweet)
                end

                reconnect_timeout = -1
                recvd = ""
              rescue => exception
                botlog "(#{Thread.current.object_id}) Chunk Exception, chunk=\"#{chunk}\""
                botlog exception.message
                botlog exception.backtrace
                #:abort
                #raise
              end
            end
            
          end

          request.on_complete do |response|
            if response.success?
              botlog("(#{Thread.current.object_id}) stream_connect::success")
            elsif response.timed_out?
              # aw hell no
              botlog("(#{Thread.current.object_id}) stream_connect::timeout")
            elsif response.code == 0
              # Could not get an http response, something's wrong.
              botlog("(#{Thread.current.object_id}) stream_connect::0:" + response.return_message)
            else
              # Received a non-successful http response.
              botlog("(#{Thread.current.object_id}) stream_connect::HTTP request failed: " + response.code.to_s)
            end
          end

          botlog "(#{Thread.current.object_id}) attempting to connect to stream"
          request.run
          botlog "(#{Thread.current.object_id}) run FINISHED!!!!"
        end

        t2 = Thread.new do
          timeout = 25
          log_alive = 200
          alive = 0

          sleep timeout
          diff = timeout
          
          while true
            lastchunk_mutex.synchronize do
              diff = Time.now.to_i - lastchunk
            end

            if diff > timeout
              botlog "Watchdog killing thread #{t1.object_id} due to long lastchunk"
              t1.kill
              sleep timeout
            else
              alive += 1
              if alive == log_alive
                alive = 0
                botlog "Stream Still Alive"
              end
              sleep timeout - diff
            end              
          end

        end

        begin
          t1.join
        rescue
          #meh
        end

        t2.kill
        botlog "(#{Thread.current.object_id}) thread JOINED!!!!!!!"
        reconnect_timeout += 1
        reconnect_timeout = 15 if reconnect_timeout > 15

      end # while true




    end


    #timer 10,  {:method => :initfeeds, :shots => 1}
    #timer 300, {:method => :updatefeed}  
    
    def initialize(*args)
      super
      @config = bot.botconfig
      @rules = @config[:TWITTER_FEEDS]

      @@stream_thread_mutex.synchronize do
        @rules.each do |r|
          myhash = Digest::MD5.hexdigest(r[:rule])
          r[:md5] = myhash

          if !@@rules.has_key?(r[:rule])
            @@rules[r[:rule]] = []
          end

          @@rules[r[:rule]] << {:plugin => self.object_id, :name => r[:name], :chans => r[:chans], :md5 => myhash}
        end
      end

      
      Thread.new do
        sleep 5
        result = @@stream_thread_mutex.try_lock
        return if !result

        while true
          botlog("(#{Thread.current.object_id}) initTwitterStream IS LAUNCHING")

          t = Thread.new do
            initTwitterStream
          end

          begin
            t.join
          rescue
            #meh
          end

          botlog "(#{Thread.current.object_id}) initTwitterStream IS DEAD"
          sleep 60
        end  

      end  

    end





    

    def print_tweet(r)
      myreply = ""

      botlog "(#{Thread.current.object_id}) tweet=#{JSON.pretty_generate(r)}"

      t = r.dig("data")
      t2 = nil
      text2 = nil
      reply = nil

      author =  r.dig("includes", "users").find{|x| x[:id] == t[:author_id]}
      text = t.dig("text")


      rt = t.dig("referenced_tweets")
      if rt 
        reply = !rt.find{|x| x["type"] == "replied_to"}.nil?

        rt = rt.find{|x| x["type"] == "retweeted"}     

        if rt
          rt = rt.dig("id")

          if rt 
            t2 = r.dig("includes", "tweets").find{|x| x["id"] == rt}
            text2 = t2.dig("text")
          end
        end
      end

      coder = HTMLEntities.new
      text = coder.decode text.force_encoding('utf-8')
      text = text.gsub(/\n/, " ")
      text = text.gsub(/\s+/, " ")

      hashtags = t.dig("entities", "hashtags")
      if !hashtags.nil?
        hashtags.each do |h|
          #text.gsub!(/(##{h.dig("tag")})(?=\b)/, "\x03" + "02" + "\\1" + "\x0f\x02")
          #text.gsub!(/(##{h.dig("tag")})(?=\b)/, "\x03" + "03" + "\\1" + "\x0f")
        end
      end

      mentions = t.dig("entities", "mentions")
      if !mentions.nil?
        mentions.each do |h|
          #text.gsub!(/(@#{h.dig("username")})(?=\b)/, "\x03" + "02" + "\\1" + "\x0f\x02")
          #text.gsub!(/(@#{h.dig("username")})(?=\b)/, "\x03" + "03" + "\\1" + "\x0f")
        end
      end

      if(text2)
        text2 = coder.decode text2.force_encoding('utf-8')
        text2 = text2.gsub(/\n/, " ")
        text2 = text2.gsub(/\s+/, " ")

        hashtags = t2.dig("entities", "hashtags")
        if !hashtags.nil?
          hashtags.each do |h|
            #text2.gsub!(/(##{h.dig("tag")})(?=\b)/, "\x03" + "02" + "\\1" + "\x0f\x02")
            #text2.gsub!(/(##{h.dig("tag")})(?=\b)/, "\x03" + "03" + "\\1" + "\x0f")
          end
        end

        mentions = t2.dig("entities", "mentions")
        if !mentions.nil?
          mentions.each do |h|
            #text2.gsub!(/(@#{h.dig("username")})(?=\b)/, "\x03" + "02" + "\\1" + "\x0f\x02")
            #text2.gsub!(/(@#{h.dig("username")})(?=\b)/, "\x03" + "03" + "\\1" + "\x0f")
          end
        end
      end

      retweets = t.dig("public_metrics", "retweet_count") || 0
      if(retweets > 1000000)
        retweets = "#{(retweets/1000000.0).floor(1).to_s.gsub(/\.0*$/, '')}M"
      elsif(retweets > 1000)
        retweets = "#{(retweets/1000.0).floor(1).to_s.gsub(/\.0*$/, '')}K"
      end

      likes = t.dig("public_metrics", "like_count") || 0
      if(likes > 1000000)
        likes = "#{(likes/1000000.0).floor(1).to_s.gsub(/\.0*$/, '')}M"
      elsif(likes > 1000)
        likes = "#{(likes/1000.0).floor(1).to_s.gsub(/\.0*$/, '')}K"
      end

      createdAt = t.dig("created_at")
      timeAgo = nil

      if !createdAt.nil?
        now = Time.now
        createdAt = DateTime.iso8601(createdAt).to_time

        diff = (now-createdAt).floor
        days = (diff/(60*60*24)).floor
        hours = ((diff-(days*60*60*24))/(60*60)).floor
        minutes = ((diff-(days*60*60*24)-(hours*60*60))/60).floor
        #seconds = (diff-(days*60*60*24)-(hours*60*60)-(minutes*60)).floor

        if(days == 0)
          if(hours == 0)
            timeAgo = minutes == 1 ? "1 minute ago" : "#{minutes} minutes ago"
          else
            timeAgo = hours == 1 ? "1 hour ago" : "#{hours} hours ago"
          end
        elsif(days < 7)
          timeAgo = days == 1 ? "1 day ago" : "#{days} days ago"
        else
          timeAgo = createdAt.strftime("%b %d %Y")
        end

      end

      #myreply <<  "\x0303" + "[Twitter] \x0f"
      #myreply << "\x0304" + "@" + author.dig("username") + (author.dig("verified") == true ? "\x0f\x0302\u{2705}\x0f\x0304" : "") + " (" + author.dig("name") + "):" + "\x0f "
      #myreply << "\x02[Twitter]\x0f (@" + "\x0311" + author.dig("username") + "\x0f" +  (author.dig("verified") == true ? "\x0302\u{2705}\x0f" : "") + " - " + author.dig("name") + "): "
      myreply << "\x02@" + author.dig("username") + "\x0f" + " (" + author.dig("name") + "): "

      if(text2)
        #myreply << "\x02" + text.gsub(/^(RT[^:]*:\s*).*$/, '\1') +  text2 + "\x0f" + " | "
        myreply << text.gsub(/^(RT[^:]*:\s*).*$/, '\1') +  text2 #+ " | "
      else
        #myreply << "\x02" + text + "\x0f" + " | "
        myreply << text #+ " | "
      end
      


      if !timeAgo.nil?
        #myreply << timeAgo + " " 
      end
      #myreply << "(#{retweets} \u{1f503} / #{likes} \u{2665})"



      matching_rules = r.dig("matching_rules").map{|x| x['tag']}

      chans = []
      @rules.filter{|x| (x[:include_replies] === true || !reply) && matching_rules.include?(x[:md5])}.each do |z|
        chans.concat(z[:chans].map{|x| x.downcase})
      end


      chans.uniq.each do |chan|
        Channel(chan).send myreply
      end

    end

    
  end
end
  