require 'imdb'

module Plugins
  class IMDB
    include Cinch::Plugin
    set :react_on, :message
    
    match /^[.!]imdb\s+(.*)$/i, use_prefix: false
    
    def execute(m, id)
      info "[USER = #{m.user.to_s}] [CHAN = #{m.channel.to_s}] [TIME = #{m.time.to_s}] #{m.message.to_s}"
      
      
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
      i = Imdb::Search.new(id)
      
      if i.movies && i.movies.size > 0
        myrating = i.movies[0].mpaa_rating.to_s
        if myrating =~ /Rated\s+(\S+)/i
          myrating = "[" + $1 + "] "
          else
          myrating = ""
        end
        
        mygenres = i.movies[0].genres
        if(!mygenres.nil? && mygenres.length > 0)
          mygenres = "[" + mygenres.join(", ") + "] "
          else
          mygenres = ""
        end
        
        myreply = 
        "\x03".b + color_name + i.movies[0].title + "\x0f".b + 
        "\x03".b + color_rating + " [IMDB: " + i.movies[0].rating.to_s + "/10] [" + i.movies[0].votes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + " votes] " + 
        myrating + mygenres + "\x0f".b + 
        "\x03".b + color_url + i.movies[0].url.gsub!(/\/combined/, "").gsub!(/akas\.imdb\.com/,"www.imdb.com") + "\x0f".b + 
        " - " + (i.movies[0].plot ? (i.movies[0].plot)[0..255] : "")
        
        m.reply myreply
        return
      end
      m.reply "No matching movies found.  [\"#{id}\"]"
    end
  end
end