require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'json'


module Plugins
  class RottenTomatoes
    include Cinch::Plugin
    set :react_on, :message
    
    match /^[.!]rt(\d*)\s+(\S.*)$/i, use_prefix: false, method: :rt
    
    def self.scrapeRottenTomatoURL(url)
      if !url || url !~ /^http/
        return nil
      end
      
      tomatoURL = url.gsub(/^http:/, "https:")
      
      begin
        movie = Nokogiri::HTML(open(tomatoURL))
      rescue
        return nil
      end
      tomatoTitle = movie.css('title')[0].text.gsub(/(\s*-\s*)?\s*Rotten Tomatoes\s*$/,'')
      tomatoSynopsis = movie.css('div.movie_synopsis  > text()').text.strip
      #tomatoMeter = movie.css('div#all-critics-numbers div.critic-score.meter a#tomato_meter_link span.meter-value').text
      tomatoMeter = movie.css('#tomato_meter_link > span.mop-ratings-wrap__percentage').text.strip rescue nil
      
      tomatoAvgCriticRating = ""
      tomatoReviewCount = 0
      tomatoFreshCount = 0
      tomatoRottenCount = 0
      
      score_data = ""
      movie.css('script').select{|x| x.text =~ /root\.RottenTomatoes\.context\.scoreInfo\s*=\s*(\{[^;]*);/m  && score_data = JSON.parse($1)} rescue nil
      #puts "score_data = \"#{score_data}\""

      if score_data 
        #puts "BBBB\n"
        tomatoMeter = score_data["tomatometerAllCritics"]["score"].to_s + '%' rescue '0%'
        tomatoAvgCriticRating = score_data["tomatometerAllCritics"]["avgScore"].to_s + '/10' rescue '0/10'
        tomatoReviewCount = score_data["tomatometerAllCritics"]["numberOfReviews"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'
        tomatoFreshCount = score_data["tomatometerAllCritics"]["freshCount"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'
        tomatoRottenCount = score_data["tomatometerAllCritics"]["rottenCount"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'

        if score_data.key?("audienceVerified") && score_data["audienceVerified"].key?("ratingCount")  && score_data["audienceVerified"]["ratingCount"] > 0
          a = "audienceVerified"
        else
          a = "audienceAll"
        end

        tomatoAudienceMeter = score_data[a]["score"].to_s + '%' rescue '0%'
        tomatoAvgAudienceRating = score_data[a]["averageRating"].to_s + '/5' rescue '0/5'
        tomatoAudienceVotes = score_data[a]["ratingCount"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'
        #puts "BBBB\n"
      end

      #puts "DDDDD\n"

      outy = { 
        :tomatoURL => tomatoURL, 
        :tomatoTitle => tomatoTitle, 
        :tomatoSynopsis => tomatoSynopsis, 
        :tomatoMeter => tomatoMeter,
        :tomatoReviewCount => tomatoReviewCount,
        :tomatoAvgCriticRating => tomatoAvgCriticRating, 
        :tomatoFreshCount => tomatoFreshCount, 
        :tomatoRottenCount => tomatoRottenCount,
        :tomatoAudienceMeter => tomatoAudienceMeter, 
        :tomatoAvgAudienceRating => tomatoAvgAudienceRating, 
        :tomatoAudienceVotes => tomatoAudienceVotes
      } 

      #puts "CCCC\nCCCCCCC\n"
      puts outy

      return outy
      
    end
    
    
    def self.getRottenTomatoString(tomato)
      color_imdb = "03"     
      color_name = "04"
      color_rating = "07"
      color_url = "03"      
      
      if !tomato || !tomato.key?(:tomatoTitle)
        return nil
      end
      
      myreply = {}
      myreply[:title] = "\x03" + color_name + tomato[:tomatoTitle] + "\x0f"
      myreply[:rating] = "\x03" + color_rating
      
      if tomato[:tomatoMeter] && tomato[:tomatoMeter] != ""
        myreply[:rating] << "[TomatoMeter: #{tomato[:tomatoMeter]} (+#{tomato[:tomatoFreshCount]}/-#{tomato[:tomatoRottenCount]}) Critics: #{tomato[:tomatoAvgCriticRating]}]"
      end
      
      if tomato[:tomatoAudienceMeter] && tomato[:tomatoAudienceMeter] != ""
      myreply[:rating] << " " unless myreply[:rating] !~ /\[/
        myreply[:rating] << "[TomatoAudience: #{tomato[:tomatoAudienceMeter]} liked it, #{tomato[:tomatoAvgAudienceRating]} with #{tomato[:tomatoAudienceVotes]} votes]"
      end
      
      myreply[:rating] << "\x0f"
      myreply[:url] = "\x03" + color_url + tomato[:tomatoURL] + "\x0f"
      myreply[:synopsis] = (tomato[:tomatoSynopsis] ? (tomato[:tomatoSynopsis])[0..245] : "")
      
      return myreply
    end
    
    
    
    def rt(m, hitno, id)
      botlog "", m      
      
      if m.bot.botconfig[:RT_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:RT_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end
      
      if hitno && hitno.size > 0 then hitno = Integer(hitno) - 1 else hitno = 0 end
      if hitno < 0 then hitno = 0 end
      
      id.gsub!(/\s+$/, "")
      id.gsub!(/\s+/, " ")
      id.gsub!(/[^ -~]/, "")
      
      search_url = "https://www.rottentomatoes.com/search/?search=" + CGI.escape(id)
      search = Nokogiri::HTML(open(search_url))
      begin
        tomatoURL = "https://www.rottentomatoes.com" + search.css('section#SummaryResults ul.results_ul li div.poster a')[hitno]["href"]
      rescue
        return
      end
      
      tomato = RottenTomatoes::scrapeRottenTomatoURL(tomatoURL)
      return unless tomato 
      
      myreply = RottenTomatoes::getRottenTomatoString(tomato)
      if !myreply.nil?
        thereply = myreply[:title] + " " + myreply[:rating] + " " + myreply[:url] + " - " + myreply[:synopsis]
        m.reply thereply
      end
      return

    end
  end
end
