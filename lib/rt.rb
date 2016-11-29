require 'nokogiri'
require 'open-uri'
require 'cgi'

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
      tomatoMeter = movie.css('div#all-critics-numbers div.critic-score.meter a#tomato_meter_link span.meter-value').text
      
      tomatoAvgCriticRating = ""
      tomatoFreshCount = 0
      tomatoRottenCount = 0
      
      movie.css('div#all-critics-numbers div#scoreStats div').select {|x| x.text =~ /Average Rating:\s*([\d\.]+\/\d+)/m && tomatoAvgCriticRating = $1}
      
      begin
        tomatoFreshCount = movie.css('div#all-critics-numbers div#scoreStats div').select {|x| x.text =~ /Fresh/ && x.text !~ /Rotten/}[0].text.gsub(/^[^\d]*(\d+).*$/m,'\1')
      rescue
        tomatoFreshCount = 0
      end
      
      begin
        tomatoRottenCount = movie.css('div#all-critics-numbers div#scoreStats div').select {|x| x.text =~ /Rotten/ && x.text !~ /Fresh/}[0].text.gsub(/^[^\d]*(\d+).*$/m,'\1')
      rescue
        tomatoRottenCount = 0
      end  
      
      tomatoAudienceMeter = movie.css('div.audience-score.meter div.meter-value span').text
      
      tomatoAvgAudienceRating = ""
      tomatoAudienceVotes = 0
      
      movie.css('div.audience-info div').select {|x| x.text =~ /Average Rating:\s*([\d\.]+\/\d+)/m && tomatoAvgAudienceRating = $1}
      movie.css('div.audience-info div').select {|x| x.text =~ /User Ratings:\s*(\d[\d,]+)/m && tomatoAudienceVotes = $1}
      
      return { 
        :tomatoURL => tomatoURL, 
        :tomatoTitle => tomatoTitle, 
        :tomatoSynopsis => tomatoSynopsis, 
        :tomatoMeter => tomatoMeter,
        :tomatoAvgCriticRating => tomatoAvgCriticRating, 
        :tomatoFreshCount => tomatoFreshCount, 
        :tomatoRottenCount => tomatoRottenCount,
        :tomatoAudienceMeter => tomatoAudienceMeter, 
        :tomatoAvgAudienceRating => tomatoAvgAudienceRating, 
        :tomatoAudienceVotes => tomatoAudienceVotes
      } 
      
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
      myreply[:title] = "\x03".b + color_name + tomato[:tomatoTitle] + "\x0f".b
      myreply[:rating] = "\x03".b + color_rating
      
      if tomato[:tomatoMeter] && tomato[:tomatoMeter] != ""
        myreply[:rating] << "[TomatoMeter: #{tomato[:tomatoMeter]} (+#{tomato[:tomatoFreshCount]}/-#{tomato[:tomatoRottenCount]}) Critics: #{tomato[:tomatoAvgCriticRating]}]"
      end
      
      if tomato[:tomatoAudienceMeter] && tomato[:tomatoAudienceMeter] != ""
      myreply[:rating] << " " unless myreply[:rating] !~ /\[/
        myreply[:rating] << "[TomatoAudience: #{tomato[:tomatoAudienceMeter]} liked it, #{tomato[:tomatoAvgAudienceRating]} with #{tomato[:tomatoAudienceVotes]} votes]"
      end
      
      myreply[:rating] << "\x0f".b
      myreply[:url] = "\x03".b + color_url + tomato[:tomatoURL] + "\x0f".b
      myreply[:synopsis] = (tomato[:tomatoSynopsis] ? (tomato[:tomatoSynopsis])[0..245] : "")
      
      return myreply
    end
    
    
    
    def rt(m, hitno, id)
      botlog "", m      
      
      if MyApp::Config::RT_EXCLUDE_CHANS.include?(m.channel.to_s) || MyApp::Config::RT_EXCLUDE_USERS.include?(m.user.to_s)
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
