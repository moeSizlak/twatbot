require "open-uri"
require "nokogiri"
require "typhoeus"
require "json"
require 'htmlentities'
require 'twitter_oauth2'

module URLHandlers
  module Twitter

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

      puts "token_response=#{token_response}"


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

      #request = Typhoeus::Request.new("https://api.twitter.com/2/tweets", options)
      request = Typhoeus::Request.new("https://api.twitter.com/1.1/statuses/show.json?id=#{tweet_ids}&tweet_mode=extended", options)
      response = request.run

      puts "response=#{response}"

      return response
    end

    def parse(url)
      url = getEffectiveUrl(url) rescue nil

      if(!url.nil? && url =~ /^https?:\/\/(?:[^\/]*\.)*twitter.com\/(?:[^\/]*\/)*\w+\/status(?:es)?\/(\d+)/)
        tweet = $1
        response = tweet_lookup(tweet)
        r = JSON.parse(response.body)
        #puts response.code, JSON.pretty_generate(r)

        myreply = ""

        puts "BODY=#{response.body}"


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
      url = getEffectiveUrl(url) rescue nil

      if(!url.nil? && url =~ /^https?:\/\/(?:[^\/]*\.)*twitter.com\/(?:[^\/]*\/)*\w+\/status(?:es)?\/(\d+)/)
        tweet = $1
        response = tweet_lookup(tweet)
        r = JSON.parse(response.body)
        #puts response.code, JSON.pretty_generate(r)

        myreply = ""

        puts "BODY=#{response.body}"

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


  end
end