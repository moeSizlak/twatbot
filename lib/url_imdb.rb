require 'imdb'

module URLHandlers  
  class IMDB
    def self.parse(url)
      if(url =~ /https?:\/\/[^\/]*imdb.com.*\/title\/\D*(\d+)/i)
        id = $1
        
        i = Plugins::IMDB::getImdb('tt'+id)
        return unless i
        
        myreply = Plugins::IMDB::getImdbString(i)
        if myreply.length > 0
          return myreply[:title] + " " + myreply[:rating] + " - " + myreply[:synopsis]
        end
        return nil
        
        
=begin
        i = Imdb::Movie.new(id)
        
        if i.title
          myrating = i.mpaa_rating.to_s
          if myrating =~ /Rated\s+(\S+)/i
            myrating = "[" + $1 + "] "
            else
            myrating = ""
          end
          
          mygenres = i.genres
          if(!mygenres.nil? && mygenres.length > 0)
            mygenres = "[" + mygenres.join(", ") + "] "
            else
            mygenres = ""
          end  
          
          color_imdb = "03"     
          color_name = "04"
          color_rating = "07"
          color_url = "03"
          
          myreply =
          "\x03".b + color_name + i.title + " (" + i.year.to_s + ")" + "\x0f".b + 
          "\x03".b + color_rating + " [IMDB: " + i.rating.to_s + "/10] [" + i.votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes] " + 
          myrating + mygenres + "\x0f".b + 
          (i.plot)[0..255]
          
          return myreply
        end
=end
      end
      return nil
    end
    
  end
end