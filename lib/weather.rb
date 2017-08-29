require 'cgi'
require 'unirest'
require 'time'
require 'thread'

module Plugins
  class Weather
    include Cinch::Plugin

    @@apicalls_minute = []
    @@apicalls_day = []
    @@apicalls_mutex = Mutex.new

    set :react_on, :message
    
    match /^!w\s+(\S.*)$/, use_prefix: false, method: :get_weather
    
    def initialize(*args)
      super
      @config = bot.botconfig
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
      location = "78233" if location == "kl666"
      mylocation = location.dup
      weather = nil
      forecast = nil
      pws = '0'
        
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
          url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/conditions/pws:#{pws}/q/#{CGI.escape(mylocation).gsub('+','%20')}.json"
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
        url = "http://api.wunderground.com/api/#{CGI.escape(@config[:WUNDERGROUND_API_KEY]).gsub('+','%20')}/forecast/pws:#{pws}/q/#{CGI.escape(mylocation).gsub('+','%20')}.json"
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
      
      if weather.body.key?("current_observation")
        
        display_location = location
        country = 'XX'
        
        if weather.body["current_observation"].key?("display_location") && weather.body["current_observation"]["display_location"].key?("full")
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
        if forecast
          f = forecast.body["forecast"]["simpleforecast"]["forecastday"]
        end
           
        myreply = "Weather: "
        myreply << "\x03".b + color_name + "#{display_location}"
        myreply << " [#{w["station_id"]}]" if w["station_id"]
        myreply << "\x0f".b
        myreply << (" | " + "\x0f".b + "\x03".b + color_title + "Temp" + "\x0f".b + ":" +"\x03".b + color_text + " #{w["temperature_string"].gsub(/^\s*(-?\d+(?:\.\d+)?)\s*F\s*\(\s*(-?\d+(?:\.\d+)?)\s*C.*$/, country == 'US' ? '\1F/\2C' : '\2C/\1F')}, #{w["weather"]}" + "\x0f".b) if w["temperature_string"] && w["weather"]
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
                  
        m.user.notice myreply
             
      end      
    end
  end
end
    
