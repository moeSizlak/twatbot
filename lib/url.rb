require 'uri'

module Plugins  
  class URL
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel
    
    def initialize(*args)
      super
      @handlers = MyApp::Config::URL_SUB_PLUGINS
    end
    
    def listen(m)
      URI.extract(m.message, ["http", "https"]) do |link|
        @handlers.each do |handler|
          if !handler[:excludeChans].include?(m.channel.to_s) && !handler[:excludeNicks].include?(m.user.to_s)
            output = class_from_string(handler[:class])::parse(link)
            if !output.nil?
              info "[Handler = #{handler[:class]}] [URL = #{link}] [USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
              m.reply output
              break
            end
          end
        end
      end
    end    
  end
end