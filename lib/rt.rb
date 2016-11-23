require 'nokogiri'
require 'open-uri'
require 'cgi'

module Plugins
  class RottenTomatoes
    include Cinch::Plugin
    set :react_on, :message
    
    match /^[.!]rt\s+(\w.*)$/i, use_prefix: false, method: :rt
    
    def rt(m, id)
      botlog "", m
      
      
      if MyApp::Config::RT_EXCLUDE_CHANS.include?(m.channel.to_s) || MyApp::Config::RT_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end
      
      color_imdb = "03"     
      color_name = "04"
      color_rating = "07"
      color_url = "03"
      
      id.gsub!(/\s+$/, "")
      id.gsub!(/\s+/, " ")
      id.gsub!(/[^ -~]/, "")
      
      search_url = "https://www.rottentomatoes.com/search/?search=" + CGI.escape(id)
      search = Nokogiri::HTML(open(search_url))
      begin
        movie_url = "https://www.rottentomatoes.com" + search.css('section#SummaryResults ul.results_ul li div.poster a')[0]["href"]
      rescue
        return
      end
      
      movie = Nokogiri::HTML(open(movie_url))
      title = movie.css('title')[0].text.gsub(/(\s*-\s*)?\s*Rotten Tomatoes\s*$/,'')
      synopsis = movie.css('div.movie_synopsis').text.strip
      tomato_meter = movie.css('div#all-critics-numbers div.critic-score.meter a#tomato_meter_link span.meter-value').text
      
      average_critic_rating = ""
      fresh_count = 0
      rotten_count = 0
      
      movie.css('div#all-critics-numbers div#scoreStats div').select {|x| x.text =~ /Average Rating:\s*([\d\.]+\/\d+)/m && average_critic_rating = $1}
      
      begin
        fresh_count = movie.css('div#all-critics-numbers div#scoreStats div').select {|x| x.text =~ /Fresh/}[0].css('span')[1].text
      rescue
        fresh_count = 0
      end
      
      begin
        rotten_count = movie.css('div#all-critics-numbers div#scoreStats div').select {|x| x.text =~ /Rotten/}[0].css('span')[1].text
      rescue
        rotten_count = 0
      end
      
      
      
      audience_meter = movie.css('div.audience-score.meter div.meter-value span').text
      
      average_audience_rating = ""
      audience_votes = 0
      
      movie.css('div.audience-info div').select {|x| x.text =~ /Average Rating:\s*([\d\.]+\/\d+)/m && average_audience_rating = $1}
      movie.css('div.audience-info div').select {|x| x.text =~ /User Ratings:\s*(\d[\d,]+)/m && audience_votes = $1}
      
      
     
        
      myreply = 
      "\x03".b + color_name + title + "\x0f".b + "\x03".b + color_rating
      
      if tomato_meter && tomato_meter != ""
        myreply << " [RT Tomatometer: #{tomato_meter} (+#{fresh_count}/-#{rotten_count}) Critics: #{average_critic_rating}]"
      end
      
      if audience_meter && audience_meter != ""
        myreply << " [AUDIENCE: #{audience_meter} liked it (#{average_audience_rating} with #{audience_votes} votes)]"
      end
      
      myreply << " \x0f".b + 
      "\x03".b + color_url + movie_url + "\x0f".b + 
      " - " + (synopsis ? (synopsis)[0..255] : "")
      
      m.reply myreply
      return

    end
  end
end
