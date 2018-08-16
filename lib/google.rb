require 'cgi'
require 'unirest'
require 'time'

module Plugins
  class Google
    include Cinch::Plugin

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!g(?:oogle)?\s+(\S.*$)/, use_prefix: false, method: :get_google

    def initialize(*args)
      super
      @config = bot.botconfig
    end
    

    def help(m)
      m.user.notice  "\x02".b + "\x03".b + "04" + "GOOGLE:\n" + "\x0f".b +
      "\x02".b + "  !google <search_terms>" + "\x0f".b + " - Perform google search and return 1st hit.\n"
    end
    
    def get_google(m, q)

      if m.bot.botconfig[:GOOGLE_SEARCH_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      botlog "", m
      q.strip!


      search = Unirest::get("https://www.googleapis.com/customsearch/v1?key=#{@config[:GOOGLE_SEARCH_APIKEY]}&cx=#{@config[:GOOGLE_SEARCH_ENGINE_ID]}&q=" + CGI.escape(q))

      if search && search.body && search.body.key?("searchInformation") && search.body["searchInformation"].key?("totalResults")
        
        if search.body["searchInformation"]["totalResults"].to_i == 0
          m.reply "No Results [\"#{q}\"]"
          return
        end

        totalResults = search.body["searchInformation"]["totalResults"]
        totalResultsFormatted = totalResults.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse

        if search.body.key?("items") && search.body["items"].count > 0 && search.body["items"][0].key?("link") && search.body["items"][0].key?("snippet")
          link = search.body["items"][0]["link"]
          snip = search.body["items"][0]["snippet"]

          myreply = ""
          myreply << "\x03".b + "12" + "G" + "\x0f".b
          myreply << "\x03".b + "04" + "o" + "\x0f".b
          myreply << "\x03".b + "08" + "o" + "\x0f".b
          myreply << "\x03".b + "12" + "g" + "\x0f".b
          myreply << "\x03".b + "09" + "l" + "\x0f".b
          myreply << "\x03".b + "04" + "e" + "\x0f".b
          myreply << ": [1 of #{totalResultsFormatted}] " + "\x03".b + "07" +  "#{link}" + "\x0f".b + " - #{snip.gsub(/[[:space:]\r\n]+/, ' ')}"[0..240]
          m.reply myreply
        else
          m.reply "ZOMG ERROR!"
          return
        end
      end                  
    end
  end
end
    
