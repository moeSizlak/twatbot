require 'cgi'
require 'httpx'
require 'time'

module Plugins
  class Wikipedia
    include Cinch::Plugin

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!wiki(?:pedia)?\s+(\S.*$)/, use_prefix: false, method: :get_wikipedia

    def initialize(*args)
      super
      @config = bot.botconfig
    end
    

    def help(m)
      m.user.notice  "\x02\x0304WIKIPEDIA:\n\x0f" +
      "\x02  !wiki <search_terms>\x0f - Perform Wikipedia search and return 1st hit.\n"
    end
    
    def get_wikipedia(m, q)

      if m.bot.botconfig[:WIKIPEDIA_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      botlog "", m
      q.strip!


      search = HTTPX.plugin(:follow_redirects).get("https://en.wikipedia.org/w/api.php?action=opensearch&search=#{CGI.escape(q)}&limit=1&namespace=0&format=json").json

      if search && search.count >=4 && search[3].count > 0

        url = search[3][0]
        x = search[3][0].gsub(/^.*\/([^\/]*)$/, '\1')

        y = HTTPX.plugin(:follow_redirects).get("https://en.wikipedia.org/api/rest_v1/page/summary/#{x}").json

        if y && y && y.key?("extract") && y["extract"].length > 0     
          myreply = "\x02[WIKIPEDIA]\x0f: #{(y["extract"][0..(436-4-url.length)]).gsub(/[\r\n]+/," ")} :: \x0307#{url}\x0f"
          m.reply myreply
        else
          m.reply "ZOMG ERROR!"
          return
        end
      end                  
    end
  end
end
    
