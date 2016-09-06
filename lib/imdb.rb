require 'imdb'

module Plugins
  class IMDB
    include Cinch::Plugin
    set :react_on, :message
    
    match /^[.!]imdb\s+(.*)$/i, use_prefix: false, method: :imdb
    
    def imdb(m, id)
      botlog "", m
      
      
      if MyApp::Config::IMDB_EXCLUDE_CHANS.include?(m.channel.to_s) || MyApp::Config::IMDB_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end
      
      color_imdb = "03"     
      color_name = "04"
      color_rating = "07"
      color_url = "03"
      
      id.gsub!(/\s+$/, "")
      id.gsub!(/\s+/, " ")
      id.gsub!(/[^ -~]/, "")
      
      if id =~ /^tt(\d+)$/
        i = Imdb::Movie.new($1)
      else
        i = Imdb::Search.new(id)
        if i.movies && i.movies.size > 0
          i = i.movies[0]
        end
      end
      
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
        
        myreply = 
        "\x03".b + color_name + i.title + "\x0f".b + 
        "\x03".b + color_rating + " [IMDB: " + i.rating.to_s + "/10] [" + i.votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes] " + 
        myrating + mygenres + "\x0f".b + 
        "\x03".b + color_url + i.url.gsub!(/\/combined/, "").gsub!(/akas\.imdb\.com/,"www.imdb.com") + "\x0f".b + 
        " - " + (i.plot ? (i.plot)[0..255] : "")
        
        m.reply myreply
        return
      end
      m.reply "No matching movies found.  [\"#{id}\"]"
    end
  end
end
