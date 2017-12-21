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
          if !handler[:excludeChans].map(&:downcase).include?(m.channel.to_s.downcase) && !handler[:excludeNicks].map(&:downcase).include?(m.user.to_s.downcase)
            #output = class_from_string(handler[:class])::parse(link)
            output = class_from_string(handler[:class]).instance_method( :parse ).bind( self ).call(link)
            if !output.nil?
              botlog "[URLHandler = #{handler[:class]}] [URL = #{link}]", m

              if(output =~ /dailymail.co.uk\s*$/ && handler[:class] == "URLHandlers::TitleBot" && m.channel.to_s.downcase =~ /^(#newzbin)$/)
                output = "#{m.user} is a dirty cunt and pasted a Daily Mail link, shame on him"
              end

              if m.bot.botconfig[:URLDB_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.channel.to_s.downcase == "#testing12"
                entries = @config[:DB][:TitleBot]
                postCount = entries.where(:URL => link).where('"Date" < (NOW() + interval \'-5 seconds\')').count
                if postCount > 0
                  firstPost = entries.order(Sequel.asc(:Date)).limit(1).where(:URL => link).first
                  #output << "  (Link has been posted #{postCount} time#{postCount>1 ? 's' : ''} before, originally by #{firstPost[:Nick][0]+"\x03".b+"01"+"\x0f".b+firstPost[:Nick][1...999]} on #{firstPost[:Date].to_date})"
                  output << "  (Posted #{postCount>1 ? postCount.to_s + ' times' : 'once'} before, #{postCount>1 ? 'originally ' : ''}by #{firstPost[:Nick][0]+ "\u200b" + firstPost[:Nick][1..-1]} on #{firstPost[:Date].to_date})"
                end
              end

              m.reply output
              break
            end
          end
        end
      end
    end    
  end
end