require 'cgi'
require 'unirest'
require 'time'
require 'nokogiri'
#require 'open-uri'
#require 'htmlentities'

module Plugins
  class TwitterSearch
    include Cinch::Plugin

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!tsearch(\d*)\s+(\S.*$)/, use_prefix: false, method: :search_twitter

    def initialize(*args)
      super
      @config = bot.botconfig
    end
    

    def help(m)
      m.user.notice  "\x02\x0304TWITTER SEARCH:\n\x0f" +
      "\x02  !tsearch <search_terms>\x0f - Twitter search (top 3 most recent)\n"
      "\x02  !tsearch5 <search_terms>\x0f - Twitter search (top 5 most recent)\n"
    end
    
    def search_twitter(m, n, q)
      if m.bot.botconfig[:TWITTER_SEARCH_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      botlog "", m
      q.strip!

      if !n.nil? && n =~ /^\d+$/ && n.to_i > 0
        n = n.to_i
      else
        n = 3
      end
      n = 5 if n > 5

      doc = Nokogiri::HTML(URI.open("https://mobile.twitter.com/search?q=#{CGI.escape q}&src=typed_query&f=live"))
      
      tweets = doc.css("table.tweet")
      return if tweets.nil? or tweets.count == 0

      n = tweets.count if tweets.count < n

      my_reply = ""
      tweets[0...n].each do |tweet|

        tweet_text = tweet.css("div.tweet-text") rescue nil
        next if tweet_text.nil?

        # highlight hashtags and ats
        tweet_text.css("a.twitter-hashtag,a.twitter-atreply").each do |a|
          a.replace("§_START_HASHTAG_§#{a.text}§_END_HASHTAG_§")
        end

        # fix links
        tweet_text.css("a").each do |a|
          href = a["href"]
          expanded = a["data-expanded-url"]
          tco = a["data-tco-id"]

          if expanded && expanded !~ /^https?:\/\/(([^.\/\s]+\.)*twitter\.com|t\.co)\//
            a.replace expanded
          elsif href && href !~ /^https?:\/\/(([^.\/\s]+\.)*twitter\.com|t\.co)\//
             a.replace href
          elsif href =~ /https?:\/\/t.co\//
            a.replace href
          elsif tco
            a.replace "http://t.co/#{a["data-tco-id"]}"
          elsif href =~ /^http/
            a.replace href
          else
            a.replace a.content
          end

        end

        # remove html tags and line breaks
        tweet_text_out = tweet_text.inner_text.gsub(/[[:space:]]+/m, " ").strip

        # fix color codes that don't survive going through Nokogiri
        tweet_text_out.gsub!(/§_START_HASHTAG_§/, "\x0312")
        tweet_text_out.gsub!(/§_END_HASHTAG_§/, "\x0f\x02")

        username = tweet.css(".tweet-header .username").inner_text.strip
        fullname = tweet.css(".tweet-header .fullname").inner_text.strip
        timestamp = tweet.css(".tweet-header .timestamp").inner_text.gsub(/[[:space:]]+/m, " ").strip
        verified = tweet.css(".tweet-header .fullname a.badge img[alt='Verified Account']").inner_text.strip rescue nil

        my_reply << "\x0304#{username}\x0f#{nil.nil? ? '' : "\u2713"} (#{fullname}): \x02#{tweet_text_out}\x0f | \x0307#{timestamp}\x0f\n"


      end


      m.reply my_reply

    end
  end
end
    
