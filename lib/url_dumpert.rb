require 'httpx'
require 'cgi'
require 'nokogiri' 
#require 'json'
require_relative 'url_title.rb'

module URLHandlers  
  module Dumpert

    def help
      return "\x02  <Dumpert URL>\x0f - Get title, info, and English translation of Dumpert video."
    end

    def parse(url)
      if(url =~ /(https?:\/\/([^\/\.]*\.)*dumpert\.nl\S+)/i)      
        title = getTitle(url)
        if !title.nil?          
          title = '' + Nokogiri::HTML.parse(title.force_encoding('utf-8').gsub(/\s{2,}/, ' ')).text        
          search = HTTPX.plugin(:follow_redirects).get("https://translate.googleapis.com/translate_a/single?client=gtx&sl=nl&tl=en&dt=t&q=" + CGI.escape(title.gsub(/^\s*dumpert\.nl\s*-\s*/, '')))
          
          if search
            search = search[0][0][0] rescue nil

            if !search.nil? && search.length > 0              
              return "\x02[Dumpert]\x0f #{title} :: \x0307#{search}\x0f"
            end
          end        
        end
      end
      return nil
    end
  end
end