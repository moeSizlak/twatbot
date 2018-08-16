require 'cgi'
require 'unirest'
require 'time'
require 'thread'
require 'csv'

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

      @airports = CSV.read(File.dirname(__FILE__) + "/airports_large.txt")

    end

    def help(m)
      m.user.notice  "\x02".b + "\x03".b + "04" + "WEATHER:\n" + "\x0f".b +
      "\x02".b + "  !w <location>" + "\x0f".b + " - Get weather for location. Uses Google geocoding & Weather Underground.\n" +
      "\x02".b + "  !w" + "\x0f".b + " - Get weather (using the last location you queried weather for)."
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
    
    def get_weather(m, location)
      botlog "", m
      location.strip!
      #location = "amsterdam" if location =~ /^\s*ams\s*$/i  # Placate Daghdha....
      mylocation = location.dup
      weather = nil
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

=begin
      newloc = Unirest::get("http://autocomplete.wunderground.com/aq?query=#{CGI.escape(mylocation).gsub('+','%20')}")
      if newloc && newloc.body && newloc.body.key?("RESULTS") && newloc.body["RESULTS"][0] && newloc.body["RESULTS"][0]["l"]
        newloc = newloc.body["RESULTS"][0]["l"]
      else
        newloc = nil
      end
=end

      puts "mylocation=#{mylocation}"

      my_airport = @airports.find{|x| x[9].upcase == mylocation.upcase rescue nil}
      my_airport = @airports.find{|x| x[0].upcase == mylocation.upcase rescue nil} if !my_airport
      mylocation = my_airport[2] if my_airport


      puts "Using URL1 = https://maps.googleapis.com/maps/api/geocode/json?address=#{CGI.escape(mylocation).gsub('+','%20')}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}"
      newloc = Unirest::get("https://maps.googleapis.com/maps/api/geocode/json?address=#{CGI.escape(mylocation).gsub('+','%20')}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}")
      lat = nil
      lng = nil
      if newloc && newloc.body && newloc.body.key?("results") && newloc.body["results"][0] && newloc.body["results"][0].key?("geometry") && newloc.body["results"][0]["geometry"].key?("location") && newloc.body["results"][0]["geometry"]["location"].key?("lat") && newloc.body["results"][0]["geometry"]["location"].key?("lng")
        lat  = newloc.body["results"][0]["geometry"]["location"]["lat"].to_s
        lng  = newloc.body["results"][0]["geometry"]["location"]["lng"].to_s
      else
        newloc = nil
      end

      puts "Using Lat/Long of #{lat}/#{lng}" #, fad3=#{fad3}, fad2=#{fad2}, fad1=#{fad1}, fad=#{fad}"
        
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
            url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/conditions/pws:#{pws}/q/#{CGI.escape(mylocation).gsub('+','%20')}.json"
          else
            #url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/conditions/pws:#{pws}#{newloc}.json"
            url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/conditions/pws:#{pws}/q/#{lat},#{lng}.json"
          end

          puts "Using URL2 = #{url}"
          weather = Unirest::get(url)
          @@apicalls_day.unshift(Time.now.to_i)
          @@apicalls_minute.unshift(Time.now.to_i)          
          
          if weather.body && weather.body.key?("response")
          
            if weather.body["response"].key?("error")
              errormsg = "ERROR: #{weather.body["response"]["error"]["type"]}: #{weather.body["response"]["error"]["description"]}"
              botlog errormsg, m
              m.user.notice errormsg
              return
            end  
            
            if weather.body["response"].key?("results")
              if weather.body["response"]["results"].size > 0 && weather.body["response"]["results"][0].key?("l") && weather.body["response"]["results"][0]["l"] =~ /^\/q\/(.*)$/
                mylocation = $1
              else
                errormsg = "Be more specific."
                botlog errormsg, m
                m.user.notice errormsg
                return
              end
            else
              break
            end           
          end
        end

      
    
        if !check_api_rate_limit(1)
          errormsg = "ERROR: WeatherUnderground API rate limiting in effect, please wait 1 minute and try your request again. (API calls in last minute = #{@@apicalls_minute.size}, last day = #{@@apicalls_day.size}) [Error: API_LIMIT_C]"
          botlog errormsg, m
          m.user.notice errormsg
          return
        end

        if newloc.nil?
          url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/forecast/pws:#{pws}/q/#{CGI.escape(mylocation).gsub('+','%20')}.json"
        else
          #url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/forecast/pws:#{pws}#{newloc}.json"
          url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/forecast/pws:#{pws}/q/#{lat},#{lng}.json"
        end

        puts "Using URL4 = #{url}"

        forecast = Unirest::get(url)
        @@apicalls_day.unshift(Time.now.to_i)
        @@apicalls_minute.unshift(Time.now.to_i)        
      end
      
      if forecast.body && forecast.body.key?("response") && !forecast.body["response"].key?("error") && !forecast.body["response"].key?("results") &&
      forecast.body.key?("forecast") && forecast.body["forecast"].key?("simpleforecast") && forecast.body["forecast"]["simpleforecast"].key?("forecastday") &&
      forecast.body["forecast"]["simpleforecast"]["forecastday"].size >= 3
        #puts "OK"
      else
        forecast = nil
      end

      #puts "\n\n"
      #puts forecast.body
      #puts "\n\n"
      
      if weather.body.key?("current_observation")
        
        display_location = location
        country = 'XX'

        olat = weather.body["current_observation"]["observation_location"]["latitude"] rescue nil
        olng = weather.body["current_observation"]["observation_location"]["longitude"] rescue nil
        fad = nil

        if olat && olng && olat.length > 0 && olng.length > 0
          puts "Using URL3 = https://maps.googleapis.com/maps/api/geocode/json?latlng=#{olat},#{olng}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}"
          newloc = Unirest::get("https://maps.googleapis.com/maps/api/geocode/json?latlng=#{olat},#{olng}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}")

          if newloc && newloc.body && newloc.body.key?("results") && newloc.body["results"][0] && newloc.body["results"][0].key?("address_components") && newloc.body["results"][0]["address_components"].length > 0
            # Remove all of the following address components unconditionally
            ac = newloc.body["results"][0]["address_components"].select{|x| !(x["types"] & ["country","administrative_area_level_1","administrative_area_level_2","colloquial_area","locality","natural_feature","airport","park","point_of_interest"]).empty?}
            
            # Only remove administrative_area_level_2 if it is not the FIRST address component in the list:
            ac = ac.reject{|x| x["types"].include?("administrative_area_level_2")} unless ac[0]["types"].include?("administrative_area_level_2")

            sl = "long_name"
            sl = "short_name" if (ac.find{|x| x["types"].include?("country") rescue ""}["short_name"] rescue "error") == "US"
            fad = ac.collect{|x| x[sl]}.join(", ")
          end
        end

        puts "FAD=\"#{fad}, OLAT=#{olat}, OLNG=#{olng}\""

        if !fad.nil? && fad.length > 0
          display_location = fad.dup
          mycunt = newloc.body["results"][0]["address_components"].find{|x| x["types"].include?("country") rescue false}["short_name"] rescue "error"
          puts "mycunt=#{mycunt}\nmyloc=#{display_location}"
          country = 'US' if mycunt == "US"
        elsif weather.body["current_observation"].key?("display_location") && weather.body["current_observation"]["display_location"].key?("full")
          display_location = weather.body["current_observation"]["display_location"]["full"]
          country = 'US' if weather.body["current_observation"]["display_location"]["country"] == 'US'
        elsif weather.body["current_observation"].key?("observation_location") && weather.body["current_observation"]["observation_location"].key?("full")
          display_location = weather.body["current_observation"]["observation_location"]["full"]    
          country = 'US' if weather.body["current_observation"]["observation_location"]["country"] == 'US'
        end
        
        color_pipe = "01"     
        color_name = "04"
        color_title = "03"
        color_colons = "12"
        color_text = "07"
        
        w = weather.body["current_observation"]

        #if forecast
        #  f = forecast.body["forecast"]["simpleforecast"]["forecastday"]
        #end
        if forecast
          #f = [forecast.body["forecast"]["txt_forecast"]["forecastday"][0]] + forecast.body["forecast"]["txt_forecast"]["forecastday"][1..9].select{|x| x.has_key?('title') && x['title'] !~ /Night/i}
        f = forecast.body["forecast"]["txt_forecast"]["forecastday"]
        end

        puts "Country=\"#{country}\""
 
        myreply = ""
        #myreply = "Conditions for: "
        myreply <<  "\x03".b + color_name 
        myreply << "#{display_location}"
        myreply << " [#{w["station_id"]}]" if w["station_id"]
        myreply << "\x0f".b
        myreply << (": " + "\x02".b + "#{w["weather"]}, #{w["temperature_string"].gsub(/^\s*(-?\d+)(?:\.\d+)?\s*F\s*\(\s*(-?\d+)(?:\.\d+)?\s*C.*$/, country == 'US' ? '\1F/\2C' : '\2C/\1F')}" + "\x0f".b) if w["temperature_string"] && w["weather"]
        if forecast
          #puts f

          fw = 'fcttext'
          fw = 'fcttext_metric' if country != 'US'
            
          i = 0
          #i = 1 if f[1]["title"] =~ /night/i
          myreply << ", " +  "\x03".b + color_name + 
            "#{f[i]["title"]}" + "\x0f".b + ": #{f[i][fw]}"

          i += 1
          myreply << " " + "\x03".b + color_name + 
            "#{f[i]["title"]}" + "\x0f".b + ": #{f[i][fw]}"

          if (f[0]["title"] + f[1]["title"]) =~ /night/i
            f = myreply << " " + "\x03".b + color_name + 
              "#{f[2]["title"]}" + "\x0f".b + ": #{f[2][fw]}"
          end
        end


=begin        
        myreply = "Weather: "
        myreply << "\x03".b + color_name + "#{display_location}"
        myreply << " [#{w["station_id"]}]" if w["station_id"]
        myreply << "\x0f".b
        myreply << (" | " + "\x0f".b + "\x03".b + color_title + "Temp" + "\x0f".b + ":" +"\x03".b + color_text + " #{w["temperature_string"].gsub(/^\s*(-?\d+)(?:\.\d+)?\s*F\s*\(\s*(-?\d+)(?:\.\d+)?\s*C.*$/, country == 'US' ? '\1F/\2C' : '\2C/\1F')}, #{w["weather"]}" + "\x0f".b) if w["temperature_string"] && w["weather"]
        myreply << (" | " + "\x0f".b + "\x03".b + color_title + "Wind" + "\x0f".b + ":" +"\x03".b + color_text + " #{w["wind_string"]}" + "\x0f".b) if w["wind_string"]
        #myreply << (" | " + "\x0f".b + "\x03".b + color_title + "Weather" + "\x0f".b + ":" +"\x03".b + color_text + " #{w["weather"]}" + "\x0f".b) if w["weather"]
        myreply << (" | " + "\x0f".b + "\x03".b + color_title + "Precip today" + "\x0f".b + ":" +"\x03".b + color_text + " #{w["precip_today_string"]}" + "\x0f".b) if w["precip_today_string"]
        if forecast
          if country == 'US'
            unitA = 'fahrenheit'
            unitAx = 'F'
            unitB = 'celsius'
            unitBx = 'C'
          else
            unitA = 'celsius'
            unitAx = 'C'
            unitB = 'fahrenheit'
            unitBx = 'F'
          end
          (0..1).each do |i|
            myreply << (" | " + "\x0f".b + "\x03".b + color_title + ((i == 0) ? "Today" : ((i==1) ? "Tomorrow" : "#{f[i]["date"]["monthname_short"]} #{f[i]["date"]["day"]}")) + "\x0f".b + ":" +"\x03".b + color_text + " High: #{f[i]["high"][unitA]}#{unitAx}, Low: #{f[i]["low"][unitA]}#{unitAx}, #{f[i]["conditions"]}, #{f[i]["pop"]}% chance of precip" + "\x0f".b) if w["weather"]
          end
        end
=end


        
        #if m.channel.to_s.include?("#hdbits") || m.channel.to_s.downcase == "#newzbin" || m.channel.to_s.downcase == "#testing12"
          myreply2 =  "\x03".b + color_name + 
            "#{display_location}" + "\x0f".b + ": #{w["weather"]}, #{w["temperature_string"].gsub(/^\s*(-?\d+)(?:\.\d+)?\s*F\s*\(\s*(-?\d+)(?:\.\d+)?\s*C.*$/, '\1F/\2C')}"
          m.reply myreply2
        #end
        m.user.notice myreply

        puts myreply.gsub(/[^ -~]/,'')

             
      end      
    end
  end
end
    
