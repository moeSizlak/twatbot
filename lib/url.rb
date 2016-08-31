require 'uri'

module Plugins  
  class URL
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel, method: :url_listen
    
    def initialize(*args)
      super
      @handlers = MyApp::Config::URL_SUB_PLUGINS
    end
    
    def url_listen(m)
      URI.extract(m.message, ["http", "https"]) do |link|
        @handlers.each do |handler|
          if !handler[:excludeChans].include?(m.channel.to_s) && !handler[:excludeNicks].include?(m.user.to_s)
            output = class_from_string(handler[:class])::parse(link)
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