require 'feedjira'

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
        
        if !feed[:old].nil?
          feedparsed.entries.slice(0..10).reverse.each do |entry|
            if !feed[:old].include?(entry.url)
              botlog "Printing new RSS entry \"#{entry.title}\""
              printnew(entry, feed[:name], feed[:chans])
            end
          end 
        end 
        mostrecent10url = feedparsed.entries.slice(0..10).map{|x| x.url}
        #botlog "Setting #{feed[:name]}[:old] to \"#{mostrecent10url}\""
        feed[:old] = mostrecent10url
      end
    end
    
    def printnew(entry, feedname, chans)
      chans.each do |chan|
        Channel(chan).send "\x02".b + "[#{feedname}]" + "\x0f".b + " #{entry.title} - #{entry.url}"
      end
    end
    
  end
end
  