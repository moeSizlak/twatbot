require "open-uri"
require "nokogiri"
require "typhoeus"
require "json"
require 'htmlentities'

module URLHandlers
  module Twitter

    def tweet_lookup(tweet_ids)
      options = {
        method: 'get',
        headers: {
          "User-Agent": "v2TweetLookupRuby",
          "Authorization": "Bearer #{@config[:TWITTER_BEARER_TOKEN]}"
        },
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

      request = Typhoeus::Request.new("https://api.twitter.com/2/tweets", options)
      response = request.run

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