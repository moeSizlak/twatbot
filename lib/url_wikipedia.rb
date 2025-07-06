require 'httpx'
#require 'json'
#require_relative 'url_title.rb'

module URLHandlers  
  module WikipediaURL

    def help
      return "\x02  <Wikipedia ARTICLE URL>\x0f - Get summary of Wikipedia article"
    end

    def parse(url)
      # (?:(?:Talk|User|User_talk|Wikipedia|Wikipedia_talk|File|File_talk|MediaWiki|MediaWiki_talk|Template|Template_talk|Help|Help_talk|Category|Category_talk|Portal|Portal_talk|Book|Book_talk|Draft|Draft_talk|Education_Program|Education_Program_talk|TimedText|TimedText_talk|Module|Module_talk|Gadget|Gadget_talk|Gadget_definition|Gadget_definition_talk|Special|Media):)?
      if(url =~ /(?:https?:\/\/([^\/\.]*\.)*wikipedia\.org\/wiki\/(?:[^\/]*\/)*([^\/\s]+)(\/[^\/]*)?$)/i) 
        article = $2     
        language = $1
        puts "WIKI_URL: Article = \"#{article}\", Language=\"#{language}\""
        y = HTTPX.plugin(:follow_redirects).get("https://#{language}wikipedia.org/api/rest_v1/page/summary/#{article}").json

        if y && y && y.key?("extract") && y["extract"].length > 0
          myreply = "\x02[WIKIPEDIA]\x0f: #{(y["extract"][0..436]).gsub(/[\r\n]+/," ")}"
          return myreply
        else
          return nil #"ZOMG ERROR!"
        end

      end
      return nil
    end
  end
end