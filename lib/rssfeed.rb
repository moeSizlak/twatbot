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
        #info "[USER = #{m.user}] [CHAN = #{chan}] [TIME = #{m.time}] #{m.message}"
        Channel(chan).send "\x02".b + "[#{feedname}]" + "\x0f".b + " #{entry.title} - #{entry.url}"
      end
    end
    
  end
end
  