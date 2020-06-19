require 'cgi'
require 'unirest'
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


      search = Unirest::get("https://en.wikipedia.org/w/api.php?action=opensearch&search=#{CGI.escape(q)}&limit=1&namespace=0&format=json")

      if search && search.body && search.body.count >=4 && search.body[3].count > 0

        x = search.body[3][0].gsub(/^.*\/([^\/]*)$/, '\1')

        y = Unirest::get("https://en.wikipedia.org/api/rest_v1/page/summary/#{x}")

        if y && y.body && y.body.key?("extract") && y.body["extract"].length > 0     
          myreply = "\x0304[WIKIPEDIA]\x0f: #{(y.body["extract"][0..436]).gsub(/[\r\n]+/," ")}"
          m.reply myreply
        else
          m.reply "ZOMG ERROR!"
          return
        end
      end                  
    end
  end
end
    
