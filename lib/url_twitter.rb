require "httpx"
require "nokogiri"
require "json"
require 'htmlentities'
require 'twitter_oauth2'

module URLHandlers
  module Twitter
=begin
    def initialize(*args)
      super
      @config = bot.botconfig

      @TweetCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:tweets]))
      @TweetCacheEntry.unrestrict_primary_key
    end
=end

    def parse(url)
      #puts "yo"
      #url = getEffectiveUrl(url) rescue nil
      #puts "ho, u=#{url}"
      if(!url.nil? && url =~ /^https?:\/\/(?:[^\/]*\.)*(?:twitter|x).com\/(?:[^\/]*\/)*\w+\/status(?:es)?\/(\d+)/)
        tweet = $1
        #puts "t=#{tweet}"
        response = HTTPX.plugin(:follow_redirects).with(headers:{"x-rapidapi-host": "x66.p.rapidapi.com", "x-rapidapi-key": @config[:RAPIDAPI_KEY]}).get("https://x66.p.rapidapi.com/tweet/#{tweet}")
        r = JSON.parse(response.body)
        #puts response.code, JSON.pretty_generate(r)

        myreply = ""

        puts "BODY=#{response.body}"

        r1 = r.dig('data','threaded_conversation_with_injections_v2','instructions',0,'entries')
        r1 = r.dig('data','threaded_conversation_with_injections_v2','instructions',1,'entries') if r1.nil?

        result = r1.find{|x| x['entryId'] == "tweet-#{tweet}"}.dig('content','itemContent','tweet_results','result','tweet')
        result = r1.find{|x| x['entryId'] == "tweet-#{tweet}"}.dig('content','itemContent','tweet_results','result') if result.nil?

        if result.nil?
          puts "TWITTER FATAL ERROR, BODY=#{response.body}"
          return nil
        end

        result_type = result.dig("__typename")

        if result_type == "TweetTombstone"
          return "\x02[X]\x0f #{result.dig("tombstone","text","text")}"
        end

        author_name = result.dig("core", "user_results", "result", "legacy", "name")
        author_screen_name = result.dig("core", "user_results", "result", "legacy", "screen_name")
        author_blue_verified = result.dig("core", "user_results", "result", "is_blue_verified")

        text = result.dig("note_tweet","note_tweet_results","result","text").force_encoding('utf-8') rescue nil
        
        if !text.nil?
          highlights = ((result.dig("note_tweet","note_tweet_results","result","entity_set","hashtags") || []) + (result.dig("note_tweet","note_tweet_results","result","entity_set","user_mentions") || [])).sort_by{|k| k['indices'][0]}.reverse
          highlights.each do |k|
            text.force_encoding('utf-8').insert(k['indices'][1], "\x0f")
            text.force_encoding('utf-8').insert(k['indices'][0], "\x0307")
          end
          text = text[0..700]
        else
          text = result.dig("legacy","full_text").force_encoding('utf-8') if text.nil?
          highlights = ((result.dig("legacy", "entities", "hashtags") || []) + (result.dig("legacy", "entities", "user_mentions") || [])).sort_by{|k| k['indices'][0]}.reverse
          highlights.each do |k|
            text.force_encoding('utf-8').insert(k['indices'][1], "\x0f")
            text.force_encoding('utf-8').insert(k['indices'][0], "\x0307")
          end
        end


        text_urls = URI.extract(text, ["http", "https"]) do |url|
          text = text.gsub(/^#{url} /, '')
          text = text.gsub(' ' + url, '')
          text = text.gsub(url, '')
          text = text.strip
        end

        coder = HTMLEntities.new
        text = coder.decode text.force_encoding('utf-8')

        text = text.gsub(/\n/, " ")
        text = text.gsub(/\s+/, " ")

        retweets = result.dig("legacy", "retweet_count") || 0
        if(retweets > 1000000)
          retweets = "#{(retweets/1000000.0).floor(1).to_s.gsub(/\.0*$/, '')}M"
        elsif(retweets > 1000)
          retweets = "#{(retweets/1000.0).floor(1).to_s.gsub(/\.0*$/, '')}K"
        end

        likes = result.dig("legacy", "favorite_count") || 0
        if(likes > 1000000)
          likes = "#{(likes/1000000.0).floor(1).to_s.gsub(/\.0*$/, '')}M"
        elsif(likes > 1000)
          likes = "#{(likes/1000.0).floor(1).to_s.gsub(/\.0*$/, '')}K"
        end

        createdAt = result.dig("legacy", "created_at")
        timeAgo = nil

        if !createdAt.nil?
          now = Time.now
          createdAt = DateTime.parse(createdAt).to_time

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
        myreply << "\x02[X]\x0f (@" + "\x0311" + author_screen_name + "\x0f" +  (author_blue_verified == true ? "\x0302\u{2705}\x0f" : "") + ((1==0 && author_name != author_screen_name) ? " - " + author_name : "") + "): "
        #myreply << "\x02@" + author.dig("username") + "\x0f" +  (author.dig("verified") == true ? "\x0302\u{2705}\x0f" : "") + " (" + author.dig("name") + "): "
        #myreply << "\x02" + text + "\x0f" + " | "
        myreply << text  + " | "
        if !timeAgo.nil?
          myreply << timeAgo + " " 
        end
        myreply << "(#{retweets} \u{1f503} / #{likes} \u{2665})"



        return myreply
      end
      
      return nil

    end  
      

    def tweet_lookup(tweet_ids)
      client = TwitterOAuth2::Client.new(
        # NOTE: not OAuth 2.0 Client ID, but OAuth 1.0 Consumer Key (a.k.a API Key)
        identifier:     @config[:TWITTER_API_KEY],
        # NOTE: not OAuth 2.0 Client Secret, but OAuth 1.0 Consumer Secret (a.k.a API Key Secret)
        secret:         @config[:TWITTER_API_KEY_SECRET],
        # NOTE: Twitter has Client Credentials Grant specific token endpoint.
        token_endpoint: '/oauth2/token',
      )

      token_response = client.access_token!

      #puts "token_response=#{token_response}"


      options = {
        method: 'get',
        headers: {
          "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/114.0.5735.99 Mobile/15E148 Safari/604.1",
          "Authorization": "Bearer #{token_response}"
        }##,
        ##params: params = {
        ##  "ids": tweet_ids,
        ##  "expansions": "author_id", #,referenced_tweets.id",
        ##  "tweet.fields": "attachments,author_id,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang,public_metrics",
        ##  "user.fields": "id,name,username,verified" 
          # "media.fields": "url", 
          # "place.fields": "country_code",
          # "poll.fields": "options"
        ##}
      }

      response = HTTPX.plugin(:follow_redirects).with(headers:{
          "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/114.0.5735.99 Mobile/15E148 Safari/604.1",
          "Authorization": "Bearer #{token_response}"
        }).get("https://api.twitter.com/1.1/statuses/show.json?id=#{tweet_ids}&tweet_mode=extended")

      #puts "response=#{response}"

      return response
    end

    def tweet_lookup_v2(tweet_ids)
      #puts "ohi"
      client = TwitterOAuth2::Client.new(
        # NOTE: not OAuth 2.0 Client ID, but OAuth 1.0 Consumer Key (a.k.a API Key)
        identifier:     @config[:TWITTER_API_KEY],
        # NOTE: not OAuth 2.0 Client Secret, but OAuth 1.0 Consumer Secret (a.k.a API Key Secret)
        secret:         @config[:TWITTER_API_KEY_SECRET],
        # NOTE: Twitter has Client Credentials Grant specific token endpoint.
        token_endpoint: '/oauth2/token',
      )

      token_response = client.access_token!

      #puts "token_response=#{token_response}"


      options = {
        method: 'get',
        params: params = {
          "ids": tweet_ids,
          "expansions": "author_id", #,referenced_tweets.id",
          "tweet.fields": "attachments,author_id,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang,public_metrics",
          "user.fields": "id,name,username,verified" 
          # "media.fields": "url", 
          # "place.fields": "country_code",
          # "poll.fields": "options"
        }
      }

      response = HTTPX.plugin(:follow_redirects).with(headers: {
          "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/114.0.5735.99 Mobile/15E148 Safari/604.1",
          "Authorization": "Bearer #{token_response}"
        }).get("https://api.twitter.com/2/tweets")

      #puts "response=#{response}"

      return response
    end

    def parse_v11maybe(url)
      #url = getEffectiveUrl(url) rescue nil

      if(!url.nil? && url =~ /^https?:\/\/(?:[^\/]*\.)*twitter.com\/(?:[^\/]*\/)*\w+\/status(?:es)?\/(\d+)/)
        tweet = $1
        response = tweet_lookup(tweet)
        r = JSON.parse(response.body)
        puts response.code, JSON.pretty_generate(r)

        myreply = ""

        #puts "BODY=#{response.body}"


        author =  r.dig("user")
        text = r.dig("full_text").force_encoding('utf-8')

        highlights = ((r.dig("entities", "hashtags") || []) + (r.dig("entities", "user_mentions") || [])).sort_by{|k| k.dig("indices")[0]}.reverse
        highlights.each do |k|
          text.force_encoding('utf-8').insert(k.dig("indices")[1], "\x0f")
          text.force_encoding('utf-8').insert(k.dig("indices")[0], "\x0307")
        end

        coder = HTMLEntities.new
        text = coder.decode text.force_encoding('utf-8')

        text = text.gsub(/\n/, " ")
        text = text.gsub(/\s+/, " ")

        retweets = r.dig("retweet_count") || 0
        if(retweets > 1000000)
          retweets = "#{(retweets/1000000.0).floor(1).to_s.gsub(/\.0*$/, '')}M"
        elsif(retweets > 1000)
          retweets = "#{(retweets/1000.0).floor(1).to_s.gsub(/\.0*$/, '')}K"
        end

        likes = r.dig("favorite_count") || 0
        if(likes > 1000000)
          likes = "#{(likes/1000000.0).floor(1).to_s.gsub(/\.0*$/, '')}M"
        elsif(likes > 1000)
          likes = "#{(likes/1000.0).floor(1).to_s.gsub(/\.0*$/, '')}K"
        end

        createdAt = r.dig("created_at")
        timeAgo = nil

        if !createdAt.nil?
          now = Time.now
          createdAt = Time.parse(createdAt) #DateTime.iso8601(createdAt).to_time

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
        myreply << "\x02[Twitter]\x0f (@" + "\x0311" + author.dig("screen_name") + "\x0f" +  (author.dig("verified") == true ? "\x0302\u{2705}\x0f" : "") + " - " + author.dig("name") + "): "
        #myreply << "\x02@" + author.dig("username") + "\x0f" +  (author.dig("verified") == true ? "\x0302\u{2705}\x0f" : "") + " (" + author.dig("name") + "): "
        #myreply << "\x02" + text + "\x0f" + " | "
        myreply << text  + " | "
        if !timeAgo.nil?
          myreply << timeAgo + " " 
        end
        myreply << "(#{retweets} \u{1f503} / #{likes} \u{2665})"



        return myreply
      end
      
      return nil

    end


    def parsev2(url)
      #puts "yo"
      #url = getEffectiveUrl(url) rescue nil
      #puts "ho, u=#{url}"
      if(!url.nil? && url =~ /^https?:\/\/(?:[^\/]*\.)*twitter.com\/(?:[^\/]*\/)*\w+\/status(?:es)?\/(\d+)/)
        tweet = $1
        #puts "t=#{tweet}"
        response = tweet_lookup(tweet)
        r = JSON.parse(response.body)
        #puts response.code, JSON.pretty_generate(r)

        myreply = ""

        #puts "BODY=#{response.body}"

        r.dig("data").each do |t|
          author =  r.dig("includes", "users").find{|x| x[:id] == t[:author_id]}
          text = t.dig("text").force_encoding('utf-8')

          highlights = ((t.dig("entities", "hashtags") || []) + (t.dig("entities", "mentions") || [])).sort_by{|k| k['start']}.reverse
          highlights.each do |k|
            text.force_encoding('utf-8').insert(k['end'], "\x0f")
            text.force_encoding('utf-8').insert(k['start'], "\x0307")
          end

          coder = HTMLEntities.new
          text = coder.decode text.force_encoding('utf-8')

          text = text.gsub(/\n/, " ")
          text = text.gsub(/\s+/, " ")

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
          myreply << "\x02[Twitter]\x0f (@" + "\x0311" + author.dig("username") + "\x0f" +  (author.dig("verified") == true ? "\x0302\u{2705}\x0f" : "") + " - " + author.dig("name") + "): "
          #myreply << "\x02@" + author.dig("username") + "\x0f" +  (author.dig("verified") == true ? "\x0302\u{2705}\x0f" : "") + " (" + author.dig("name") + "): "
          #myreply << "\x02" + text + "\x0f" + " | "
          myreply << text  + " | "
          if !timeAgo.nil?
            myreply << timeAgo + " " 
          end
          myreply << "(#{retweets} \u{1f503} / #{likes} \u{2665})"

        end

        return myreply
      end
      
      return nil

    end


    def parse_nitters(url)
      tweetCacheEntry = Class.new(Sequel::Model(@config[:DB][:tweets]))
      tweetCacheEntry.unrestrict_primary_key

      #title = getTitleAndLocation(url)
      #url =  title[:effective_url] rescue nil

      #if(!url.nil? && url =~ /^(https?:\/\/(?:[^\/]*\.)*)(?:twitter|x).com\//)
      if(!url.nil? && url =~ /^https?:\/\/(?:[^\/]*\.)*(?:twitter|x).com\/(?:[^\/]*\/)*\w+\/status(?:es)?\/(\d+)/)
        tweet = $1

        c = tweetCacheEntry[tweet]
        if !c.nil?
          puts "Found tweet (#{tweet}) in cache."
          return "[ \x02" + c.tweet + "\x0f ] - twitter.com"
        end

        nitters = [
          'nitter.privacydev.net',
          'nitter.poast.org',
          'nitter.d420.de',
          'nitter.x86-64-unknown-linux-gnu.zip',
          'nitter.moomoo.me'
        ]

        nitters.each_with_index do |nitter, i|
          #url = url.gsub(/^(https?:\/\/)(?:[^\/]*\.)*(?:twitter|x).com\//, '\1nitter.poast.org/')
          urlnew = url.gsub(/^(https?:\/\/)(?:[^\/]*\.)*(?:twitter|x).com\//, '\1' + "#{nitter}/")

          puts "Trying nitter #{i}: #{nitter}.  URL = #{urlnew}"
          title = getTitleAndLocation(urlnew)
          puts "title=#{title}"

          title = nil if !title.nil? && !title[:title].nil? && title[:title].to_s =~ /^\s*Error\s*$/
          title = nil if !title.nil? && !title[:response_code].nil? && title[:response_code].to_s =~ /^[45]/

          #if !title.nil? && (!title[:title].nil? || !title[:description].nil?)
          if !title.nil? && !title[:title].nil?
            c = tweetCacheEntry.new
            c.id = tweet
            c.tweet = title[:title].gsub(/\s*\|\s*nitter.*$/, "")
            c.save

            #url =~ /https?:\/\/([^\/]+)/
            title[:effective_url] =~ /https?:\/\/([^\/]+)/
            host = $1
            #return "[ \x02" + title[:title] + "\x0f ] - " + host + (title[:description].nil? ? '' : ("\n[ \x02" + title[:description] + "\x0f ] - " + host))
            #return "[ \x02" + title[:title].gsub(/\s*\|\s*nitter(\.net)?\s*$/, "") + "\x0f ] - " + host.gsub(/nitter\.net/, "twitter.com")
            return "[ \x02" + title[:title].gsub(/\s*\|\s*nitter.*$/, "") + "\x0f ] - twitter.com"
          end
        end
      end
      
      return nil
    end

  end
end