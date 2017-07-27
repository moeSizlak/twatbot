require 'unirest'
require 'cgi'
require 'nokogiri' 
#require 'json'
require_relative 'url_title.rb'

module URLHandlers  
  class Dumpert
    def self.parse(url)
      if(url =~ /(https?:\/\/([^\/\.]*\.)*dumpert\.nl\S+)/i)      
        title = TitleBot::getTitle(url)
        if !title.nil?          
          title = '' + Nokogiri::HTML.parse(title.force_encoding('utf-8').gsub(/\s{2,}/, ' ')).text        
          search = Unirest::get("https://translate.googleapis.com/translate_a/single?client=gtx&sl=nl&tl=en&dt=t&q=" + CGI.escape(title.gsub(/^\s*dumpert\.nl\s*-\s*/, '')))
          
          if search.body
            search = search.body[0][0][0] rescue nil
            #puts "ZZZZ\n#{search[0][0][0]}"
            #search.gsub!(/,+/, ',')
            #search.gsub!(/\[,/, '[')
            #search = JSON.parse(search.body)
            
            #if search.size > 0 && search[0].size > 0 && search[0][0].size > 0
            if !search.nil? && search.length > 0
              title = title + 
              "\x03".b + "04" + "  [" + search + "]" + "\x0f".b
              
              return title
            end
          end        
        end
      end
      return nil
    end
  end
end