require 'cgi'
require 'unirest'
require 'time'
require 'nokogiri'
require 'open-uri'
#require 'htmlentities'

module Plugins
  class Wolfram
    include Cinch::Plugin

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^(?:!(?:wa|wolfram)|\?)\s+(\S.*$)/, use_prefix: false, method: :get_wolfram

    def initialize(*args)
      super
      @config = bot.botconfig
    end
    

    def help(m)
      m.user.notice  "\x02\x0304WOLFRAM:\n\x0f" +
      "\x02  !wa <query_terms>\x0f - Perform Wolfram Alpha query\n"
    end
    
    def get_wolfram(m, q)

      if m.bot.botconfig[:WOLFRAM_SEARCH_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      botlog "", m
      q.strip!

      doc = Nokogiri::HTML(URI.open("http://api.wolframalpha.com/v2/query?input=#{CGI.escape(q)}&appid=#{@config[:WOLFRAM_APP_ID]}"))
      if doc.nil?
        m.reply "Failure connecting to API."
        return
      end

      puts doc.to_s
      

      pods = doc.css("pod")
      if pods.nil? || pods.count < 2
        m.reply "Failure! (A)"
        return
      end

      subpods = pods[1].css("subpod")
      if subpods.nil? || subpods.count < 1
        m.reply "Failure! (B)"
        return
      end

      if pods.count >= 3
        pod3_title = pods[2]["title"] rescue nil
        if ['Decimal form','Decimal approximation','Genealogical relation','Possible named relationship'].include?(pod3_title)
          pod3_plaintext = pods[2].css("subpod")[0].at_css("plaintext").text rescue nil
        end
      end


      title = pods[1]["title"] rescue nil
      answer = subpods[0].at_css("plaintext").text rescue nil

      if answer.nil?
        m.reply "Failure! (C)"
        return
      end


      m.reply "\x02#{title}:\x0f #{answer}" + (pod3_plaintext.nil? ? '' : " (\x02#{pod3_title}:\x0f #{pod3_plaintext})")


                 
    end
  end
end
    
