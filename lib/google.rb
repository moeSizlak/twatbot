require 'cgi'
require 'unirest'
require 'time'
require 'nokogiri'
require 'open-uri'
#require 'htmlentities'

module Plugins
  class Google
    include Cinch::Plugin

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!g(?:oogle)?(\d*)\s+(\S.*$)/, use_prefix: false, method: :get_google

    def initialize(*args)
      super
      @config = bot.botconfig
    end
    

    def help(m)
      m.user.notice  "\x02".b + "\x03".b + "04" + "GOOGLE:\n" + "\x0f".b +
      "\x02".b + "  !google <search_terms>" + "\x0f".b + " - Perform google search and return 1st hit.\n"
      "\x02".b + "  !g <search_terms>" + "\x0f".b + "      - Perform google search and return 1st hit.\n"
      "\x02".b + "  !google2 <search_terms>" + "\x0f".b + " - Perform google search and return 2nd hit.\n"
      "\x02".b + "  !g2 <search_terms>" + "\x0f".b + "      - Perform google search and return 2nd hit.\n"
      "\x02".b + "  !g3 <search_terms>" + "\x0f".b + "      - Perform google search and return 3rd hit, etc, etc...\n"
    end
    
    def get_google(m, n, q)

      if m.bot.botconfig[:GOOGLE_SEARCH_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      botlog "", m
      q.strip!

      if !n.nil? && n =~ /^\d+$/ && n.to_i > 0
        n = n.to_i
      else
        n = 1
      end



      ################
      myreply = nil
      begin
        if n == 1
          doc = open("https://www.google.com/search?q=#{CGI.escape(q)}&ie=UTF-8",
            "User-Agent" => "Ruby")
          gok = Nokogiri::HTML(doc, nil, Encoding::UTF_8.to_s)

       
          zreply = ""
          zreply << "\x03".b + "12" + "G" + "\x0f".b
          zreply << "\x03".b + "04" + "o" + "\x0f".b
          zreply << "\x03".b + "08" + "o" + "\x0f".b
          zreply << "\x03".b + "12" + "g" + "\x0f".b
          zreply << "\x03".b + "09" + "l" + "\x0f".b
          zreply << "\x03".b + "04" + "e" + "\x0f".b
          zreply << ": " #+ + "\x03".b + "04" + "[DIRECT] " + "\x0f".b

          currency1 = gok.css('#knowledge-currency__tgt-amount').first.content rescue nil
          currency2 = gok.css('#knowledge-currency__tgt-currency').first.content rescue nil
          if currency1 && currency2
            myreply = "#{zreply}#{currency1} #{currency2}"
            m.reply myreply
          end


          #calc1 = coder.decode gok.css('#cwles').first.content rescue nil
          calc2 = gok.css('#cwos').first.content rescue nil
          if calc2
            myreply = "#{zreply}#{calc2}"
            m.reply myreply
          end

          snippet = gok.css('.ILfuVd').first.content rescue nil
          if snippet
            myreply = "#{zreply}#{snippet}"
            m.reply myreply
          end

          huh1 = gok.css('.Z0LcW').first.content rescue nil
          if huh1
            myreply = "#{zreply}#{huh1}"
            m.reply myreply
          end

          date1 = gok.css('.gsrt.vk_bk.dDoNo').first.content rescue nil
          #date1 = gok.css('.whenis').map(&:text) rescue nil
          if date1
            myreply = "#{zreply}#{date1}"
            m.reply myreply
          end

          tx = gok.css('#tw-target-text[data-placeholder="Translation"]').first.content rescue nil
          if tx
            myreply = "#{zreply}#{tx}"
            m.reply myreply
          end

          

          mydef = ''
          #definition = gok.css('.Uekwlc.XpoqFe').each do |link|
          definition = gok.css('div[data-dobid="dfn"]') rescue nil
          if definition
            mydef << definition.enum_for(:each_with_index).map{|x,i| "#{(i+1).to_s}: " + x.css('span').first.content rescue '' }.join(', ')
          end

          if mydef != ''
            myreply = "#{zreply}#{mydef}"
            m.reply myreply
          end
        end

      rescue => exception
        puts $!.message
        puts exception.backtrace

      end


        return if myreply


      #################





      search = Unirest::get("https://www.googleapis.com/customsearch/v1?key=#{@config[:GOOGLE_SEARCH_APIKEY]}&cx=#{@config[:GOOGLE_SEARCH_ENGINE_ID]}&q=" + CGI.escape(q))

      if search && search.body && search.body.key?("searchInformation") && search.body["searchInformation"].key?("totalResults")
        
        if search.body["searchInformation"]["totalResults"].to_i == 0
          m.reply "No Results. [\"#{q}\"]"
          return
        elsif search.body["items"].count < n
          m.reply "ERROR: I can only see the top #{search.body["items"].count} results. [\"#{q}\"]"
          return
        end

        totalResults = search.body["searchInformation"]["totalResults"]
        totalResultsFormatted = totalResults.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse

        if search.body.key?("items") && search.body["items"].count >= n && search.body["items"][n-1].key?("link") && search.body["items"][n-1].key?("snippet")
          link = search.body["items"][n-1]["link"]
          snip = search.body["items"][n-1]["snippet"]

          myreply = ""
          myreply << "\x03".b + "12" + "G" + "\x0f".b
          myreply << "\x03".b + "04" + "o" + "\x0f".b
          myreply << "\x03".b + "08" + "o" + "\x0f".b
          myreply << "\x03".b + "12" + "g" + "\x0f".b
          myreply << "\x03".b + "09" + "l" + "\x0f".b
          myreply << "\x03".b + "04" + "e" + "\x0f".b
          myreply << ": [#{n} of #{totalResultsFormatted}] " + "\x03".b + "07" +  "#{link}" + "\x0f".b + " - #{snip.gsub(/[[:space:]\r\n]+/, ' ')}"[0..240]
          m.reply myreply
        else
          m.reply "ZOMG ERROR!"
          return
        end

  



      end                  
    end
  end
end
    
