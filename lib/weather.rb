require 'cgi'
require 'unirest'
require 'time'
require 'thread'
require 'csv'
require 'date'

module Plugins
  class Weather
    include Cinch::Plugin

    @@apicalls_minute = []
    @@apicalls_day = []
    @@apicalls_mutex = Mutex.new

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!w($|\s+.*$)/, use_prefix: false, method: :get_weather
    
    def initialize(*args)
      super
      @config = bot.botconfig

      @WeatherLocationCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:weather_locations_cache]))
      @WeatherLocationCacheEntry.unrestrict_primary_key

      @LocationCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:location_cache]))
      @LocationCacheEntry.unrestrict_primary_key

      @airports = CSV.read(File.dirname(__FILE__) + "/airports_large.txt")

    end

    def help(m)
      m.user.notice  "\x02\x0304WEATHER:\n\x0f" +
      "\x02  !w <location>\x0f - Get weather for location. Uses Google geocoding & Weather Underground.\n" +
      "\x02  !w\x0f - Get weather (using the last location you queried weather for)."
    end
    
    def check_api_rate_limit(x=1)
      now = Time.now.to_i
      minute_ago = now - 60
      day_ago = now - (60*60*24)
      
      @@apicalls_minute = @@apicalls_minute.take_while { |x| x >= minute_ago }
      @@apicalls_day = @@apicalls_day.take_while { |x| x >= day_ago }
      
      if (@@apicalls_minute.size + x) <= @config[:WUNDERGROUND_API_RATE_LIMIT_MINUTE] && (@@apicalls_day.size + x) <= @config[:WUNDERGROUND_API_RATE_LIMIT_DAY]
        return true
      else
        return false
      end    
    end

    def f_to_c(f)
      (f - 32) * (5.0/9.0)
    end

    def c_to_f(c)
      (c * (9.0/5.0)) + 32
    end

    def k_to_c(k)
      k - 273.15
    end

    def k_to_f(k)
      c_to_f(k_to_c(k))
    end
    
    def get_weather(m, location)
      botlog "", m
      location.strip!
      #location = "amsterdam" if location =~ /^\s*ams\s*$/i  # Placate Daghdha....
      mylocation = location.dup
      weather = nil
      weather2 = nil
      weather3 = nil
      weather4 = nil
      forecast = nil
      pws = '1'

      c = @WeatherLocationCacheEntry[m.bot.irc.network.name.to_s.downcase, m.user.to_s.downcase]
      if location.length == 0        
        if c
          mylocation = c.location
          puts "Found cached location of \"#{c.location}\""
        else
          m.user.notice "You must first define your location with !w <location name>"
          puts "No cached location found for \"#{m.bot.irc.network.name.to_s.downcase}\", \"#{m.user.to_s.downcase}\""
          return
        end
      else
        if c
          c.location = mylocation
          c.save
        else
          @WeatherLocationCacheEntry.create(:network => m.bot.irc.network.name.to_s.downcase, :nick => m.user.to_s.downcase, :location => mylocation) 
        end
      end

      puts "mylocation=#{mylocation}"

      my_airport = @airports.find{|x| x[9].upcase == mylocation.upcase rescue nil}
      my_airport = @airports.find{|x| x[0].upcase == mylocation.upcase rescue nil} if !my_airport
      mylocation = my_airport[2] if my_airport


      lat = nil
      lng = nil
      fad = nil

      c = @LocationCacheEntry[mylocation]     
      if c
        lat = c.lat
        lng = c.long
        fad = c.display_name
        mycunt = c.country
        newloc = 1

        bot.botconfig[:DB][:location_cache].returning(:counter).where(:location => mylocation).update(:counter => Sequel.expr(1) + :counter)

        puts "Found cached lat/long of \"#{c.lat}\", \"#{c.long}\""
      else
        puts "Using URL1 = https://maps.googleapis.com/maps/api/geocode/json?address=#{CGI.escape(mylocation).gsub('+','%20')}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}"
        newloc = Unirest::get("https://maps.googleapis.com/maps/api/geocode/json?address=#{CGI.escape(mylocation).gsub('+','%20')}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}")
        
        if newloc && newloc.body && newloc.body.key?("results") && newloc.body["results"][0] && newloc.body["results"][0].key?("geometry") && newloc.body["results"][0]["geometry"].key?("location") && newloc.body["results"][0]["geometry"]["location"].key?("lat") && newloc.body["results"][0]["geometry"]["location"].key?("lng")
          lat  = newloc.body["results"][0]["geometry"]["location"]["lat"].to_s
          lng  = newloc.body["results"][0]["geometry"]["location"]["lng"].to_s

          if newloc && newloc.body && newloc.body.key?("results") && newloc.body["results"][0] && newloc.body["results"][0].key?("address_components") && newloc.body["results"][0]["address_components"].length > 0
            # Remove all of the following address components unconditionally
            ac = newloc.body["results"][0]["address_components"].select{|x| !(x["types"] & ["country","administrative_area_level_1","administrative_area_level_2","colloquial_area","locality","natural_feature","airport","park","point_of_interest"]).empty?}
            
            # Only remove administrative_area_level_2 if it is not the FIRST address component in the list:
            ac = ac.reject{|x| x["types"].include?("administrative_area_level_2")} unless ac[0]["types"].include?("administrative_area_level_2")

            sl = "long_name"
            sl = "short_name" if (ac.find{|x| x["types"].include?("country") rescue ""}["short_name"] rescue "error") == "US"
            fad = ac.collect{|x| x[sl]}.join(", ")
          end
          mycunt = newloc.body["results"][0]["address_components"].find{|x| x["types"].include?("country") rescue false}["short_name"] rescue "error"


          @LocationCacheEntry.create(:location => mylocation, :lat => lat, :long => lng, :display_name => fad, :country => mycunt, :counter => 1)
        else
          newloc = nil
        end
      end

      display_location = location
      country = 'XX'

      if !fad.nil? && fad.length > 0
        display_location = fad.dup
        puts "mycunt=#{mycunt}\nmyloc=#{display_location}"
        country = 'US' if mycunt == "US"
      end

      

      puts "Using Lat/Long of #{lat}/#{lng}" 
        
      @@apicalls_mutex.synchronize do
        if !check_api_rate_limit(3)
          errormsg = "ERROR: WeatherUnderground API rate limiting in effect, please wait 1 minute and try your request again. (API calls in last minute = #{@@apicalls_minute.size}, last day = #{@@apicalls_day.size}) [Error: API_LIMIT_A]"
          botlog errormsg, m
          m.user.notice errormsg
          return
        end
          
        loop do      
          if !check_api_rate_limit(1)
            errormsg = "ERROR: WeatherUnderground API rate limiting in effect, please wait 1 minute and try your request again. (API calls in last minute = #{@@apicalls_minute.size}, last day = #{@@apicalls_day.size}) [Error: API_LIMIT_B]"
            botlog errormsg, m
            m.user.notice errormsg
            return
          end

          if newloc.nil?
            errormsg = "Failed to get lat/long."
            botlog errormsg, m
            m.reply errormsg
            return
          else
            url = "https://api.darksky.net/forecast/#{@config[:DARK_SKY_SECRET_KEY]}/#{lat},#{lng}"
            url2 = "https://api.openweathermap.org/data/2.5/onecall?lat=#{lat}&lon=#{lng}&exclude=minutely,hourly&appid=#{@config[:OPEN_WEATHER_KEY]}"
            url3 = "https://api.climacell.co/v3/weather/realtime?apikey=#{@config[:CLIMACELL_API_KEY]}&lat=#{lat}&lon=#{lng}&unit_system=us&fields=temp,feels_like,humidity,wind_speed,wind_direction,wind_gust,sunrise,sunset,weather_code,surface_shortwave_radiation,baro_pressure,epa_health_concern,pollen_tree,pollen_weed,pollen_grass"
            url4 = "https://api.climacell.co/v3/weather/forecast/daily?apikey=#{@config[:CLIMACELL_API_KEY]}&lat=#{lat}&lon=#{lng}&unit_system=#{country == 'US' ? 'us' : 'si'}&fields=temp,feels_like,humidity,wind_speed,wind_direction,sunrise,sunset,weather_code,baro_pressure"
          end

          ##puts "Using URL2 = #{url2}"
          puts "Using URL3 = #{url3}"
          puts "Using URL4 = #{url4}"
          #weather = Unirest::get(url)
          ##weather2 = Unirest::get(url2)
          weather3 = Unirest::get(url3)
          weather4 = Unirest::get(url4)
          @@apicalls_day.unshift(Time.now.to_i)
          @@apicalls_minute.unshift(Time.now.to_i)   
          break       

        end

      end

      
      
      color_pipe = "01"     
      color_name = "04"
      color_title = "03"
      color_colons = "12"
      color_text = "07"

      puts "Country=\"#{country}\"" 
      myreply =  "\x02\x0304#{display_location}\x0f"
      myreply2 = "\x02\x0304#{display_location}\x0f"
      myreply3 = "\x02\x0304#{display_location}\x0f"

      if weather3.body && weather3.body.dig('temp', 'value')
        w = weather3.body

        if !w.dig('weather_code', 'value').nil?
          #myreply3 << " | \x02Conditions:\x0f "
          myreply3 << " | "
          condition = w.dig('weather_code', 'value')

          myreply3 << "\u{1F327} " if condition == "freezing_rain_heavy" 
          myreply3 << "\u{1F327} " if condition == "freezing_rain" 
          myreply3 << "\u{1F327} " if condition == "freezing_rain_light" 
          myreply3 << "\u{1F327} " if condition == "freezing_drizzle" 
          myreply3 << "\u{1F328} " if condition == "ice_pellets_heavy" 
          myreply3 << "\u{1F328} " if condition == "ice_pellets" 
          myreply3 << "\u{1F328} " if condition == "ice_pellets_light" 
          myreply3 << "\u2744 " if condition == "snow_heavy" 
          myreply3 << "\u2744 " if condition == "snow" 
          myreply3 << "\u{1F328} " if condition == "snow_light" 
          myreply3 << "\u{1F328} " if condition == "flurries" 
          myreply3 << "\u26C8 " if condition == "tstorm" 
          myreply3 << "\u{1F327} " if condition == "rain_heavy" 
          myreply3 << "\u{1F327} " if condition == "rain" 
          myreply3 << "\u{1F326} " if condition == "rain_light" 
          myreply3 << "\u{1F326} " if condition == "drizzle" 
          myreply3 << "\u{1F32B} " if condition == "fog_light" 
          myreply3 << "\u{1F32B} " if condition == "fog" 
          myreply3 << "\u2601 " if condition == "cloudy" # \ufe0f
          myreply3 << "\u{1F325} " if condition == "mostly_cloudy" 
          myreply3 << "\u26C5 " if condition == "partly_cloudy" 
          myreply3 << "\u{1F324} " if condition == "mostly_clear" 
          myreply3 << "\u263C " if condition == "clear" 

          myreply3 << condition.gsub(/_/, ' ').split.map(&:capitalize).join(' ')
        end

        myreply3 << " \x0307#{w.dig('temp', 'value').round(1)}\x0f\u00B0F/\x0307#{f_to_c(w.dig('temp', 'value')).round(1)}\x0f\u00B0C"

        if !w.dig('feels_like', 'value').nil? && (w.dig('feels_like', 'value') - w.dig('temp', 'value')).abs > 3
          myreply3 << " | \x02Feels Like:\x0f \x0307#{w.dig('feels_like', 'value').round(1)}\x0f\u00B0F/\x0307#{f_to_c(w.dig('feels_like', 'value')).round(1)}\x0f\u00B0C"
        end

        myreply3 << " | \x02Humidity:\x0f #{w.dig('humidity', 'value').round(0)}%" unless w.dig('humidity', 'value').nil?


        if !w.dig('wind_speed', 'value').nil?
          myreply3 << " | \x02Wind:\x0f #{w.dig('wind_speed', 'value').round(0)}#{w.dig('wind_speed','units')}"
          if !w.dig('wind_gust', 'value').nil? && w.dig('wind_gust', 'value').round(0) > (w.dig('wind_speed', 'value').round(0) + 5)
            myreply3 << " (gusts #{w.dig('wind_gust', 'value').round(0)})"
          end

          if !w.dig('wind_direction', 'value').nil?
            direction = w.dig('wind_direction', 'value')
            directions = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
            directions2 = ["\u2191","\u2197","\u2192","\u2198","\u2193","\u2199","\u2190","\u2196"]
            myreply3 << " #{directions2[(((direction+22.5+180)%360)/45).floor]} #{directions[(((direction+11.25)%360)/22.5).floor]} (#{direction}\u00B0)"
          end
        end

        myreply3 << " | \x02Baro:\x0f #{w.dig('baro_pressure', 'value').round(2)} #{w.dig('baro_pressure', 'units')}" unless w.dig('baro_pressure', 'value').nil?
        myreply3 << " | \x02Air Quality:\x0f #{w.dig('epa_health_concern', 'value')}" unless w.dig('epa_health_concern', 'value').nil?
        myreply3 << " | \x02Solar:\x0f #{w.dig('surface_shortwave_radiation', 'value')} #{w.dig('surface_shortwave_radiation', 'units')}" unless w.dig('surface_shortwave_radiation', 'value').nil?
        myreply3 << " | \x02Pollen:\x0f #{w.dig('pollen_weed', 'value')}/#{w.dig('pollen_tree', 'value')}/#{w.dig('pollen_grass', 'value')}" unless w.dig('pollen_grass', 'value').nil?
        
        
        
        if weather4.body && weather4.body.count >= 3 && weather4.body[0].dig('temp')
          w = weather4.body
          weather4.body[0...3].each do |d|
            myreply3 << " | \x02#{Date.parse(d.dig("observation_time","value")).strftime('%a')}:\x0f" unless d.dig("observation_time","value").nil?
            myreply3 << " " + d.dig("weather_code", "value").gsub(/_/, ' ').split.map(&:capitalize).join(' ') unless d.dig("weather_code", "value").nil?
            if !d.dig('temp').nil? && d.dig('temp').count >= 2
              mylow  = d.dig("temp").find{|x| x.key?('min') && x.dig('min','value')}
              myhigh = d.dig("temp").find{|x| x.key?('max') && x.dig('max','value')}
              if mylow && myhigh
                myreply3 << " \x0304#{myhigh.dig('max','value').round(0)}\x0f\u00b0#{myhigh.dig('max','units')}/\x0302#{mylow.dig('min','value').round(0)}\x0f\u00b0#{mylow.dig('min','units')}"
              end
            end
          end
        end

        m.reply myreply3
        else
        weather3 = nil
        myreply3 = nil
      end


=begin
      if weather2.body && weather2.body.key?("daily") && weather2.body.key?("current")
        #puts weather2.body.to_s
        f = weather2.body["daily"]
        w = weather2.body["current"]
        #puts f

        if country == 'US'
          myreply2 << ": \x02#{w["weather"][0]["description"].capitalize}, #{k_to_f(w["temp"]).round}F/#{k_to_c(w["temp"]).round}C, \x0f"
        else
          myreply2 << ": \x02#{w["weather"][0]["description"].capitalize}, #{k_to_c(w["temp"]).round}C/#{k_to_f(w["temp"]).round}F, \x0f"
        end

        extended_summary2 = ""        
        f[0..2].each_with_index do |day, i|
          d = Time.at(day["dt"]).to_date.strftime('%a')

          if country == 'US'           
            myreply2 << "\x02[#{d}]\x0f #{day["weather"][0]["description"].capitalize} (#{k_to_f(day["temp"]["day"]).round}/#{k_to_f(day["temp"]["night"]).round})F  "
          else            
            myreply2 << "\x02[#{d}]\x0f #{day["weather"][0]["description"].capitalize} (#{k_to_c(day["temp"]["day"]).round}/#{k_to_c(day["temp"]["night"]).round})C  "
          end            
        end
        puts extended_summary2     
        m.reply myreply2   

      else
        weather2 = nil
        myreply2 = nil
      end
=end

=begin
      
      if weather.body && weather.body.key?("daily") && weather.body["daily"].key?("summary") && weather.body["daily"].key?("data") && weather.body["daily"]["data"].size >= 3
        forecast = weather
        #puts "OK"
      else
        forecast = nil
      end


      if weather.body.key?("currently")
        
        
        
        w = weather.body["currently"]
        extended_summary = nil


        if forecast
          f = forecast.body["daily"]
          if forecast.body["daily"].key?("summary")
            extended_summary = forecast.body["daily"]["summary"]
            
            extended_summary.gsub!(/(\S+)\u00b0F/) {|f| f_to_c(f.to_f).round.to_s + "\u00b0C" } if country != 'US'
          end
        end

        

        puts "cccc=#{w["temperature"]}"


        myreply << (": \x02#{w["summary"]}, #{(" " + w["temperature"].to_f.round.to_s + " " + f_to_c(w["temperature"]).to_f.round.to_s).gsub(/^\s*(\S+)\s+(\S+)\s*$/, country == 'US' ? '\1F/\2C' : '\2C/\1F')}\x0f") if w["temperature"]

        if forecast
          myreply << ", " + extended_summary if extended_summary
        end



        m.reply myreply
        puts myreply.gsub(/[^ -~]/,'')

             
      end  
=end    
    end
  end
end
    
