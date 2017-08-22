require 'uri'

module Plugins  
  class URL
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel, method: :url_listen
    
    def initialize(*args)
      super
      @config = bot.botconfig
      @handlers = @config[:URL_SUB_PLUGINS]
      @handlers.each do |x| 
        self.class.send(:include, class_from_string(x[:class]))
      end   
    end
    
    def url_listen(m)
      URI.extract(m.message, ["http", "https"]) do |link|
        @handlers.each do |handler|
          if !handler[:excludeChans].include?(m.channel.to_s) && !handler[:excludeNicks].include?(m.user.to_s)
            #output = class_from_string(handler[:class])::parse(link)
            output = class_from_string(handler[:class]).instance_method( :parse ).bind( self ).call(link)
            if !output.nil?
              botlog "[URLHandler = #{handler[:class]}] [URL = #{link}]", m
              m.reply output
              break
            end
          end
        end
      end
    end    
  end
end