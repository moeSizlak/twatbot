require 'cgi'
require 'unirest'
require 'time'
require 'thread'
require 'csv'
require 'date'
require 'timezone_finder'

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

      if m.bot.botconfig[:WEATHER_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:WEATHER_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

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
            ac = newloc.body["results"][0]["address_components"].select{|x| !(x["types"] & ["country","administrative_area_level_1","administrative_area_level_2","colloquial_area","locality","neighborhood","sublocality","natural_feature","airport","park","point_of_interest"]).empty?}
            
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

            url3 = "https://api.climacell.co/v3/weather/realtime?apikey=#{@config[:CLIMACELL_API_KEY]}&lat=#{lat}&lon=#{lng}&unit_system=us&fields=temp,feels_like,dewpoint,wind_speed,wind_direction,wind_gust,sunrise,sunset,weather_code,surface_shortwave_radiation,baro_pressure,epa_health_concern,pollen_tree,pollen_weed,pollen_grass"
            url4 = "https://api.climacell.co/v3/weather/forecast/daily?apikey=#{@config[:CLIMACELL_API_KEY]}&lat=#{lat}&lon=#{lng}&unit_system=#{country == 'US' ? 'us' : 'si'}&fields=temp,feels_like,dewpoint,wind_speed,wind_direction,sunrise,sunset,weather_code,baro_pressure"
            
            url5 = "https://api.tomorrow.io/v4/timelines?apikey=#{@config[:TOMORROW_IO_API_KEY]}&timesteps=current,1d&location=#{lat},#{lng}&units=imperial&fields=temperature,temperatureApparent,dewPoint,windSpeed,windDirection,windGust,sunriseTime,sunsetTime,weatherCode,cloudCover"
          end

          puts "Using URL5 = #{url5}"
          weather3 = Unirest::get(url5)

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
      myreply =  "\x0304#{display_location}\x0f"
      myreply2 = "\x0304#{display_location}\x0f"
      myreply3 = "\x0304#{display_location}\x0f"

      if weather3.body && weather3.body.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'temperature')
        w = weather3.body
        #puts w

        temperature = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'temperature')
        weatherCode = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'weatherCode')
        temperatureApparent = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'temperatureApparent')
        dewPoint = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'dewPoint')
        windSpeed = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'windSpeed')
        windDirection = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'windDirection')
        windGust = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'windGust')
        sunriseTime = w.dig('data', 'timelines', 1, 'intervals', 0, 'values', 'sunriseTime')
        sunsetTime = w.dig('data', 'timelines', 1, 'intervals', 0, 'values', 'sunsetTime')
        cloudCover = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'cloudCover')


        weatherCodes = [
          {:weatherCode => 4201, :weatherDescription => "Heavy Rain", :weatherIcon => "\u{1F327} "},
          {:weatherCode => 4001, :weatherDescription => "Rain", :weatherIcon => "\u{1F327} "},
          {:weatherCode => 4200, :weatherDescription => "Light Rain", :weatherIcon => "\u{1F326} "},
          {:weatherCode => 6201, :weatherDescription => "Heavy Freezing Rain", :weatherIcon => "\u{1F327} "},
          {:weatherCode => 6001, :weatherDescription => "Freezing Rain", :weatherIcon => "\u{1F327} "},
          {:weatherCode => 6200, :weatherDescription => "Light Freezing Rain", :weatherIcon => "\u{1F327} "},
          {:weatherCode => 6000, :weatherDescription => "Freezing Drizzle", :weatherIcon => "\u{1F327} "},
          {:weatherCode => 4000, :weatherDescription => "Drizzle", :weatherIcon => "\u{1F326} "},
          {:weatherCode => 7101, :weatherDescription => "Heavy Ice Pellets", :weatherIcon => "\u{1F328} "},
          {:weatherCode => 7000, :weatherDescription => "Ice Pellets", :weatherIcon => "\u{1F328} "},
          {:weatherCode => 7102, :weatherDescription => "Light Ice Pellets", :weatherIcon => "\u{1F328} "},
          {:weatherCode => 5101, :weatherDescription => "Heavy Snow", :weatherIcon => "\u2744 "},
          {:weatherCode => 5000, :weatherDescription => "Snow", :weatherIcon => "\u2744 "},
          {:weatherCode => 5100, :weatherDescription => "Light Snow", :weatherIcon => "\u{1F328} "},
          {:weatherCode => 5001, :weatherDescription => "Flurries", :weatherIcon => "\u{1F328} "},
          {:weatherCode => 8000, :weatherDescription => "Thunderstorm", :weatherIcon => "\u26C8 "},
          {:weatherCode => 2100, :weatherDescription => "Light Fog", :weatherIcon => "\u{1F32B} "},
          {:weatherCode => 2000, :weatherDescription => "Fog", :weatherIcon => "\u{1F32B} "},
          {:weatherCode => 1001, :weatherDescription => "Cloudy", :weatherIcon => "\u2601 "},
          {:weatherCode => 1102, :weatherDescription => "Mostly Cloudy", :weatherIcon => "\u{1F325} "},
          {:weatherCode => 1101, :weatherDescription => "Partly Cloudy", :weatherIcon => "\u26C5 "},
          {:weatherCode => 1100, :weatherDescription => "Mostly Clear", :weatherIcon => "\u{1F324} "},
          {:weatherCode => 1000, :weatherDescription => "Clear", :weatherIcon => "\u2600 "},
          {:weatherCode => 3000, :weatherDescription => "Light Wind", :weatherIcon => " "},
          {:weatherCode => 3001, :weatherDescription => "Wind", :weatherIcon => " "},
          {:weatherCode => 3002, :weatherDescription => "Strong Wind", :weatherIcon => " "}
        ]

        if !weatherCode.nil?
          #myreply3 << " | \x02Conditions:\x0f "
          myreply3 << " | "
          condition = w.dig('data', 'timelines', 0, 'intervals', 0, 'values', 'weatherCode')
          condition = weatherCodes.find{|x| x[:weatherCode] == condition}
          myreply3 << "#{condition[:weatherIcon]} #{condition[:weatherDescription]}"
        end

        myreply3 << " \x0307#{temperature.round(0)}\x0f\u00B0F/\x0307#{f_to_c(temperature).round(0)}\x0f\u00B0C"

        if !temperatureApparent.nil? && (temperatureApparent - temperature).abs > 3
          myreply3 << " | \x02Feels Like:\x0f \x0307#{temperatureApparent.round(0)}\x0f\u00B0F/\x0307#{f_to_c(temperatureApparent).round(0)}\x0f\u00B0C"
        end

        myreply3 << " | \x02Dewpoint:\x0f #{dewPoint.round(0)}\u00B0F/#{f_to_c(dewPoint).round(0)}\u00B0C" unless dewPoint.nil?


        if !windSpeed.nil?
          myreply3 << " | \x02Wind:\x0f #{windSpeed.round(0)}mph"
          if !windGust.nil? && windGust.round(0) > (windSpeed.round(0) + 5)
            myreply3 << " (gusts #{windGust.round(0)})"
          end

          if !windDirection.nil?
            directions = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
            directions2 = ["\u2191","\u2197","\u2192","\u2198","\u2193","\u2199","\u2190","\u2196"]
            myreply3 << " #{directions2[(((windDirection+22.5+180)%360)/45).floor]} #{directions[(((windDirection+11.25)%360)/22.5).floor]} (#{windDirection.round(0)}\u00B0)"
          end
        end

        myreply3 << " | \x02Cloud Cover:\x0f #{cloudCover.round(0)}%" unless cloudCover.nil?

        if !sunriseTime.nil? 
          sunriseTime = DateTime.parse(sunriseTime)
          if !sunriseTime.nil?
            tz = Unirest::get("https://maps.googleapis.com/maps/api/timezone/json?location=#{lat},#{lng}&timestamp=#{sunriseTime.to_time.to_i}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}")
            if tz && tz.body.dig('rawOffset')
              sunriseTime = Time.at(sunriseTime.to_time.to_i + tz.body.dig('rawOffset').to_i + tz.body.dig('dstOffset').to_i ).utc.to_datetime
              myreply3 << " | \x02Sunrise:\x0f #{sunriseTime.strftime("%l:%M %P").strip} #{tz.body.dig('timeZoneName').split(" ").map{|x| x[0]}.join}"
            end
          end
        end

        if !sunsetTime.nil? 
          sunsetTime = DateTime.parse(sunsetTime)
          if !sunsetTime.nil?
            tz = Unirest::get("https://maps.googleapis.com/maps/api/timezone/json?location=#{lat},#{lng}&timestamp=#{sunsetTime.to_time.to_i}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}")
            if tz && tz.body.dig('rawOffset')
              sunsetTime = Time.at(sunsetTime.to_time.to_i + tz.body.dig('rawOffset').to_i + tz.body.dig('dstOffset').to_i ).utc.to_datetime
              myreply3 << " | \x02Sunset:\x0f #{sunsetTime.strftime("%l:%M %P").strip} #{tz.body.dig('timeZoneName').split(" ").map{|x| x[0]}.join}"
            end
          end
        end

        if !sunriseTime.nil? && !sunsetTime.nil?
          dayLength = sunsetTime.to_time.to_i - sunriseTime.to_time.to_i
          myreply3 << " | \x02Day Length:\x0f #{dayLength/(60*60)}:#{((dayLength % (60*60))/60).to_s.rjust(2, "0")}"
        end

       
        
        #tf = TimezoneFinder.create
        #mytz = tf.timezone_at(lng: lng.to_f, lat: lat.to_f)
        #puts mytz
        #sunrise = Time.parse(w.dig('sunrise', 'value')).new_offset(mytz) rescue nil
        #sunset = Time.parse(w.dig('sunset', 'value')).new_offset(mytz) rescue nil
        #myreply3 << " | \x02Sunrise:\x0f #{sunrise.strftime('%a %F %T %Z')}" unless sunrise.nil?
        #myreply3 << " | \x02Sunset:\x0f #{sunset.strftime('%a %F %T %Z')}" unless sunset.nil?

=begin        
        if weather4.body && weather4.body.count >= 3 && weather4.body[0].dig('temp')
          w = weather4.body
          weather4.body[0...3].each do |d|
            myreply3 << " | \x02#{Date.parse(d.dig("observation_time","value")).strftime('%a')}:\x0f" unless d.dig("observation_time","value").nil?
            myreply3 << " " + d.dig("weather_code", "value").gsub(/_/, ' ').split.map(&:capitalize).join(' ') unless d.dig("weather_code", "value").nil?
            if !d.dig('temp').nil? && d.dig('temp').count >= 2
              mylow  = d.dig("temp").find{|x| x.key?('min') && x.dig('min','value')}
              myhigh = d.dig("temp").find{|x| x.key?('max') && x.dig('max','value')}
              if mylow && myhigh
                myreply3 << " \x0304#{myhigh.dig('max','value').round(0)}\x0f\u00b0#{myhigh.dig('max','units')}/\x0312#{mylow.dig('min','value').round(0)}\x0f\u00b0#{mylow.dig('min','units')}"
              end
            end
          end
        end
=end
        m.reply myreply3
      else
        weather3 = nil
        myreply3 = nil
        m.reply "ERROR: Cant't get weather for location (#{mylocation}) [#{lat},#{lng}] due to Climacell API error."
      end

  
    end
  end
end
    
