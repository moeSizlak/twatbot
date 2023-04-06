require 'uri'

module Plugins  
  class URL
    include Cinch::Plugin
    set :react_on, :channel
    
    listen_to :channel, method: :url_listen
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    
    def initialize(*args)
      super
      @config = bot.botconfig
      @handlers = @config[:URL_SUB_PLUGINS]
      @handlers.each do |x| 
        self.class.send(:include, class_from_string(x[:class]))
      end   
    end


    def help(m)
      msg = "\x02\x0304URL's:\x0f"

      @handlers.each do |handler|
        if !handler[:excludeChans].map(&:downcase).include?(m.channel.to_s.downcase)
          msg << "\n" + class_from_string(handler[:class]).instance_method( :help ).bind( self ).call()
        end
      end

      m.user.notice msg
    end
    

    def url_listen(m)
       return if m.message =~ /sodom...sein|kS4XgIzYSBw|Zs6IuQPdIUA|cnmi\.nsopw\....\/Search...ender|thoma...itchell-mu...ot2|bit\.ly\/3GjWtbc|attrition\.org|hQAC2pPVu88|fTWEwjk-LfQ|3BEbqKLE7FJYJg5A7/

      URI.extract(m.message, ["http", "https"]) do |link|
        @handlers.each do |handler|
          if !handler[:excludeChans].map(&:downcase).include?(m.channel.to_s.downcase) && !handler[:excludeNicks].map(&:downcase).include?(m.user.to_s.downcase)

            output = class_from_string(handler[:class]).instance_method( :parse ).bind( self ).call(link)
            if !output.nil?
              botlog "[URLHandler = #{handler[:class]}] [URL = #{link}]", m


              ## Special circumstances:
              if(output =~ /dailymail.co.uk\s*$/ && handler[:class] == "URLHandlers::TitleBot" && m.channel.to_s.downcase =~ /^(#newzbin)$/)
                output = "#{m.user} is a dirty cunt and pasted a Daily Mail link, shame on him"
              end

              if(output =~ /login/i && handler[:class] == "URLHandlers::TitleBot" && m.channel.to_s.downcase =~ /^(#jokers)$/)
                return
              end


              # Add URL to database, if configured:
              if m.bot.botconfig[:URLDB_DATA].map{|x| x[:chan].downcase}.include?(m.channel.to_s.downcase)
                entries = @config[:DB][m.bot.botconfig[:URLDB_DATA].select{|x| x[:chan] =~ /^#{m.channel}$/i}[0][:table]]

                postCount = entries.where(:URL => link).where('"Date" < (NOW() + interval \'-35 seconds\')').count
                if postCount > 0
                  firstPost = entries.order(Sequel.asc(:Date)).limit(1).where(:URL => link).first
                  # don't highlight people's nicknames
                  username = firstPost[:Nick].sub(/(.)/, "\\1\x0f")
                  if postCount > 1
                    times = "#{postCount} times"
                    originally_ = "originally "
                  else
                    times = "once"
                  end
                  output << "  (Posted #{times} before, #{originally_}by #{username} on #{firstPost[:Date].to_date})"
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