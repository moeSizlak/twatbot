require 'nokogiri'
require 'httpx'
require 'cgi'
require 'json'


module Plugins
  class RottenTomatoes
    include Cinch::Plugin
    set :react_on, :message
    
    match /^[.!]rt(\d*)\s+(\S.*)$/i, use_prefix: false, method: :rt
    
    def self.scrapeRottenTomatoURL(url)
      puts "z1"
      if !url || url !~ /^http/
        return nil
      end

      
      tomatoURL = url.gsub(/^http:/, "https:")

      begin
        movie = Nokogiri::HTML(HTTPX.plugin(:follow_redirects).get(tomatoURL).body.to_s)
      rescue
        return nil
      end

      t = JSON.parse(movie.css('script#scoreDetails[@type="application/json"]').text)

      tomatoTitle = movie.css('title')[0].text.gsub(/(\s*-\s*)?\s*Rotten Tomatoes\s*$/,'')
      tomatoSynopsis = movie.css('p[data-qa="movie-info-synopsis"][slot="content"]  > text()').text.strip
      
      tomatoMeter = t["scoreboard"]["tomatometerScore"]["value"].to_s + '%' rescue '0%'
      tomatoAvgCriticRating = t["scoreboard"]["tomatometerScore"]["averageRating"].to_s + '/10' rescue '0/10'
      tomatoReviewCount = t["scoreboard"]["tomatometerScore"]["ratingCount"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'
      tomatoFreshCount = t["scoreboard"]["tomatometerScore"]["likedCount"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'
      tomatoRottenCount = t["scoreboard"]["tomatometerScore"]["notLikedCount"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'

      tomatoAudienceMeter = t["scoreboard"]["audienceScore"]["value"].to_s + '%' rescue '0%'
      tomatoAvgAudienceRating = t["scoreboard"]["audienceScore"]["averageRating"].to_s + '/5' rescue '0/5'
      tomatoAudienceVotes = t["scoreboard"]["audienceScore"]["ratingCount"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse rescue '0'

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
      search = Nokogiri::HTML(HTTPX.plugin(:follow_redirects).get(search_url).body.to_s)
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
