require 'imdb'
require 'nokogiri'
require 'open-uri'
require 'cgi'

module Plugins
  class IMDB
    include Cinch::Plugin
    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^[.!]imdb\s+(.*)$/i, use_prefix: false, method: :imdb

    def initialize(*args)
      super
      @@config = bot.botconfig
    end
    
    def help(m)
      if m.bot.botconfig[:IMDB_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end
      
      m.user.notice "\x02".b + "\x03".b + "04" + "IMDB:\n" + "\x0f".b + 
      "\x02".b + "  !imdb <movie_name>" + "\x0f".b + " - Get IMDB info about a movie (and RottenTomatoes as well).\n"
    end
    
    def self.getImdb(id)
      id.gsub!(/\s+$/, "")
      id.gsub!(/\s+/, " ")
      id.gsub!(/[^ -~]/, "")
      
      if id =~ /^tt(\d+)$/
        i = Imdb::Movie.new($1)
      else
        i = Imdb::Search.new(id)
        if i.movies && i.movies.size > 0
          i = i.movies[0]
        else
          i = nil
        end
      end
      
      if i && i.title
        puts "Successful IMDB lookup"
        omdb = Unirest::get('http://www.omdbapi.com/?tomatoes=true&i=tt' + CGI.escape(i.id) + "&apikey=#{IMDB.class_variable_get(:@@config)[:OMDB_API_KEY]}") rescue nil
        if !omdb || !omdb.body || !omdb.body.key?('Response') || omdb.body["Response"] !~ /true/i
          omdb = nil
        end     
        
        puts "OMDB lookup by ImdbId successful ===>" + (!(omdb.nil?)).to_s + "\n"
             
        tomato = nil
        if omdb && omdb.body.key?('tomatoURL') && omdb.body["tomatoURL"] =~ /^http/
          begin
            tomato = RottenTomatoes::getRottenTomatoString(RottenTomatoes::scrapeRottenTomatoURL(omdb.body["tomatoURL"]))
          rescue
          end
        end
      
        myrating = i.mpaa_rating.to_s
        if myrating && myrating.length > 0
          myrating = "[" + myrating + "]"
          else
          myrating = ""
        end
        if omdb && (!myrating || !myrating =~ /^\[/) && omdb.body.key?('Rated')
          myrating = "[" + omdb.body["Rated"] + "]"
          puts "Falling back to OMDB MPAA Rating"
        end

        puts "MPAA Rating: #{myrating}"
        
        mygenres = i.genres
        if(!mygenres.nil? && mygenres.length > 0)
          mygenres = "[" + mygenres.join(", ") + "]"
          else
          mygenres = ""
        end
        if omdb && (!mygenres || !mygenres =~ /^\[/) && omdb.body.key?('Genre')
          mygenres = "[" + omdb.body["Genre"] + "]"
          puts "Falling back to OMDB Genres"
        end
        
        iscore = i.rating.to_s
        ivotes = i.votes.to_s.gsub(/,/,'')
        puts "IMDB DATA: #{iscore}, #{ivotes}"
        ovotes = ''
        oscore = ''
        myvotes = ''
        myscore = ''
        if omdb && omdb.body.key?('imdbVotes')
          ovotes = omdb.body["imdbVotes"].gsub(/,/,'')
        end
        if omdb && omdb.body.key?('imdbRating')
         oscore = omdb.body["imdbRating"]
        end
        if ivotes && ivotes =~ /^\d+$/
          if ovotes && ovotes =~ /^\d+$/
            if ovotes.to_i > ivotes.to_i
              puts "Using OMDB score/votes"
              myvotes = ovotes
              myscore = oscore
            else
              puts "Using IMDB score/votes"
              myvotes = ivotes
              myscore = iscore
            end
          else
            puts "Using IMDB score/votes"
            myvotes = ivotes
            myscore = iscore
          end
        else
          if ovotes && ovotes =~ /^\d+$/
            puts "Using OMDB score/votes"
            myvotes = ovotes
            myscore = oscore
          else
            puts "Score/votes could not be obtained"
            myvotes = 0
            myscore = 0.0
          end
        end        
        myvotes = myvotes.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse
        myscore = myscore.to_s + "/10"
        
        if omdb && omdb.body.key?('Plot') && omdb.body["Plot"].length > 0 && omdb.body["Plot"] !~ /^\s*(unknown|N[\\\/A])/i
          puts "Using OMDB plot" # \"#{omdb.body["Plot"]}\", vs imdb \"#{i.plot}\""
          myplot = omdb.body["Plot"]
        else
          puts "Using IMDB plot" # \"#{omdb.body["Plot"]}\", vs imdb \"#{i.plot}\""
          myplot = i.plot
          if myplot.nil?
            myplot = ""
          end
          myplot.gsub!(/[\r\n].*/, "")
        end  
        
        return { :id => i.id, :title => i.title, :year => i.year, :url => 'http://www.imdb.com/title/tt' + CGI.escape(i.id) + '/', :plot => myplot, :tomato => tomato,
        :mpaa_rating => myrating, :genres => mygenres, :score => myscore, :votes => myvotes}
      end   
      return nil
    end
    
    
    
    def self.getImdbString(i)
      color_imdb = "03"     
      color_name = "04"
      color_rating = "07"
      color_url = "03"
      
      if !i || !i.key?(:title)
        return nil
      end
      
      myreply = {}
      
      myreply[:title] = "\x03".b + color_name + i[:title]
      if !i[:title].include?("(#{i[:year]})")
        myreply[:title] << " (" + i[:year].to_s + ")" 
      end
      myreply[:title] << "\x0f".b
      
      myreply[:rating] = "\x03".b + color_rating + "[IMDB: #{i[:score]} with #{i[:votes]} votes]"
      
      if(i.key?(:tomato) && i[:tomato])
        myreply[:rating] << "\x0f".b + " " + i[:tomato][:rating] + "\x03".b + color_rating
      end
      
      myreply[:rating] << " #{i[:mpaa_rating]} #{i[:genres]}" + "\x0f".b
      myreply[:url] = "\x03".b + color_url + i[:url] + "\x0f".b
      myreply[:synopsis] = (i[:plot] ? (i[:plot])[0..255] : "")
      
      return myreply    
    end
    
    
    
    def imdb(m, id)
      botlog "", m      
      
      if m.bot.botconfig[:IMDB_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:IMDB_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end   

      id.gsub!(/\s+$/, "")
      id.gsub!(/\s+/, " ")
      id.gsub!(/[^ -~]/, "")
      
      i = IMDB::getImdb(id)
      return unless i
      
      myreply = IMDB::getImdbString(i)
      if myreply.length > 0
        m.reply myreply[:title] + " " + myreply[:rating] + " " + myreply[:url] + " - " + myreply[:synopsis]
      end
      return
    end
    
    
  end
end
