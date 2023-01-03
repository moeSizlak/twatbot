require 'imdb'

module URLHandlers  
  module IMDB
    def help
      return "\x02  <IMDB URL>\x0f - Get title and info about IMDB movie or TV show."
    end

    def parse(url)
      if(url =~ /https?:\/\/[^\/]*imdb.com.*\/title\/\D*(\d+)/i)
        id = $1
        
        i = Plugins::IMDB::getImdb('tt'+id)
        return unless i
        
        myreply = Plugins::IMDB::getImdbString(i)
        if myreply.length > 0
          return myreply[:title] + " " + myreply[:rating] + " - " + myreply[:synopsis]
        end
        return nil
        
      end
      return nil
    end
    
  end
end