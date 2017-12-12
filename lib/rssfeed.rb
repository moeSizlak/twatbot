require 'feedjira'

module Plugins
  class RSSFeed
    include Cinch::Plugin
    set :react_on, :channel
    
    timer 0,  {:method => :updatefeed, :shots => 1}
    timer 300, {:method => :updatefeed}  
    
    def initialize(*args)
      super
      @config = bot.botconfig
      @feeds = @config[:RSS_FEEDS]
    end
    
    def updatefeed
      @feeds.each do |feed|      
        feedparsed = Feedjira::Feed.fetch_and_parse(feed[:url])    
        
        if !feed[:old].nil?
          i = 0
          feedparsed.entries.slice(0..10).reverse.each do |entry|
            if !feed[:old].include?(entry.url) && (feed[:max].nil? || i < feed[:max])
              botlog "Printing new RSS entry \"#{entry.title}\" \"#{entry.url}\" =====OLD====>\"#{feed[:old]}\""
              printnew(entry, feed[:name], feed[:chans])
              i += 1
            end
          end
        else
          feed[:old] = []
        end 
        mostrecenturls = feedparsed.entries.map{|x| x.url}
        #botlog "Setting #{feed[:name]}[:old] to \"#{mostrecenturls}\""
        feed[:old] = feed[:old].concat(mostrecenturls).uniq.last(200)
      end
    end
    
    def printnew(entry, feedname, chans)
      chans.each do |chan|
        Channel(chan).send "\x02".b + "[#{feedname}]" + "\x0f".b + " #{entry.title} - #{entry.url}"
      end
    end
    
  end
end
  