require 'sequel'
require 'csv'
require 'tempfile'
require 'unirest'


module Plugins  
  class CoronaVirus
    include Cinch::Plugin

    @@corona = nil
    @@corona_lastupdate = nil

    @@corona2 = nil
    @@corona2_lastupdate = nil

    @@corona_mutex = Mutex.new

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    #match lambda {|m| /^\.(?!btc)(#{m.bot.botconfig[:COINS].map{|x| Regexp.escape(x["symbol"])}.join('|')})\s*$/im}, use_prefix: false, method: :getCorona
    match /^\.corona(\s*|\s+[\S\s]+\S\s*)$/im, use_prefix: false, method: :getCorona

    #timer 0,  {:method => :updatecorona, :shots => 1}


    def initialize(*args)
      super

      @LocationCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:location_cache]))
      @LocationCacheEntry.unrestrict_primary_key

      @CountryCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:countries]))
      @CountryCacheEntry.unrestrict_primary_key


      @airports = CSV.read(File.dirname(__FILE__) + "/airports_large.txt")

      @config = bot.botconfig
    end

    def help(m)
      if m.bot.botconfig[:CORONA_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      m.user.notice "\x02".b + "\x03".b + "04" + "CORONAVIRUS:\n" + "\x0f".b + 
      "\x02".b + "  .corona <[partial] country name>" + "\x0f".b + " - Get stats on coronavirus infections (optionally, in a specific country)\n"
    end

    def updatecorona
      #mycorona = Unirest::get("https://api.coinmarketcap.com/v1/ticker/?limit=0") rescue nil
      mycorona2 = Unirest::get("https://services1.arcgis.com/0MSEUqKaxRlEPj5g/arcgis/rest/services/ncov_cases/FeatureServer/2/query?f=json&where=Confirmed%20%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Confirmed%20desc&resultOffset=0&resultRecordCount=200&cacheHint=true", headers:{"authority" => "services1.arcgis.com", "pragma" => "no-cache", "cache-control" => "no-cache", "user-agent" => "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Safari/537.36", "sec-fetch-dest" => "empty", "accept" => "*/*", "origin" => "https://gisanddata.maps.arcgis.com", "sec-fetch-site" => "same-site", "sec-fetch-mode" => "cors", "referer" => "https://gisanddata.maps.arcgis.com/apps/opsdashboard/index.html", "accept-language" => "en-US,en;q=0.9"}) rescue nil
      mycorona = Unirest::get("https://services1.arcgis.com/0MSEUqKaxRlEPj5g/arcgis/rest/services/ncov_cases/FeatureServer/1/query?f=json&where=Confirmed%20%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Confirmed%20desc%2CCountry_Region%20asc%2CProvince_State%20asc&resultOffset=0&resultRecordCount=250&cacheHint=true", headers:{"authority" => "services1.arcgis.com", "pragma" => "no-cache", "cache-control" => "no-cache", "user-agent" => "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Safari/537.36", "sec-fetch-dest" => "empty", "accept" => "*/*", "origin" => "https://gisanddata.maps.arcgis.com", "sec-fetch-site" => "same-site", "sec-fetch-mode" => "cors", "referer" => "https://gisanddata.maps.arcgis.com/apps/opsdashboard/index.html", "accept-language" => "en-US,en;q=0.9"}) rescue nil
      
      if !mycorona.nil? && !mycorona.body.nil? && !mycorona.body["features"].nil?
          @@corona = mycorona.body["features"]
          @@corona_lastupdate = DateTime.now
      end

      if !mycorona2.nil? && !mycorona2.body.nil? && !mycorona2.body["features"].nil?
          @@corona2 = mycorona2.body["features"]
          @@corona2_lastupdate = DateTime.now
      end

    end







    def getCorona(m,c)
      if m.bot.botconfig[:CORONA_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:CORONA_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      color_confirmed = "07"
      color_deaths = "07"
      color_recovered = "07"

      c.strip!
      puts "AAAAAAAA"
      @@corona_mutex.synchronize do
        puts "BBBBBBBBB"
        updatecorona if (@@corona_lastupdate.nil? || (@@corona_lastupdate < (DateTime.now - (15/1440.0))))
        puts "CCCCCCCCCC"
        if @@corona.nil?
          m.reply "API Unavailable" 
          #getCorona2(m, c)
          return
        end

        if c.nil? || c.length == 0
          confirmed = @@corona2.map{|x| x["attributes"]["Confirmed"]}.inject(0, :+)
          deaths = @@corona2.map{|x| x["attributes"]["Deaths"]}.inject(0, :+)
          recovered = @@corona2.map{|x| x["attributes"]["Recovered"]}.inject(0, :+)

          m.reply "" +
         "\x03".b + "04" + "CORONA!!!" + "\x0f".b + "\x03".b + color_confirmed + "  Confirmed:" + "\x0f".b + " #{confirmed.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} | "  + "\x03".b + color_deaths + "Deaths:" + "\x0f".b + " #{deaths.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*deaths.to_f/confirmed.to_f)} %) | " + "\x03".b + color_recovered + "Recovered:" + "\x0f".b + " #{recovered.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*recovered.to_f/confirmed.to_f)} %)" +
          (m.channel.to_s.downcase == "#testing12" ? " [#{@@corona2_lastupdate}]" : "")
          return

        else
        
          cc = nil
          cc = @@corona2.find{|x| (x["attributes"]["Country_Region"] || "").upcase == c.upcase}

          if cc.nil?
            cc = @@corona.find{|x| (x["attributes"]["Province_State"] || "").upcase == c.upcase}
            if cc.nil?
              mystate = @config[:DB][:states].where(Sequel.function(:upper, :code) => c.upcase).all
              if mystate && mystate.count == 1
                cc = @@corona.find{|x| (x["attributes"]["Province_State"] || "").upcase == mystate.first[:name].upcase}
              end
            end

            if !cc.nil?
              confirmed = @@corona.select{|x| (x["attributes"]["Province_State"] || "").upcase == cc["attributes"]["Province_State"].upcase}.map{|x| x["attributes"]["Confirmed"]}.inject(0, :+)
              deaths = @@corona.select{|x| (x["attributes"]["Province_State"] || "").upcase == cc["attributes"]["Province_State"].upcase}.map{|x| x["attributes"]["Deaths"]}.inject(0, :+)
              recovered = @@corona.select{|x| (x["attributes"]["Province_State"] || "").upcase == cc["attributes"]["Province_State"].upcase}.map{|x| x["attributes"]["Recovered"]}.inject(0, :+)

              m.reply "" +
              "\x03".b + "04" + "#{cc["attributes"]["Province_State"]}:" + "\x0f".b + "\x03".b + color_confirmed + "  Confirmed:" + "\x0f".b + " #{confirmed.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} | "  + "\x03".b + color_deaths + "Deaths:" + "\x0f".b + " #{deaths.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*deaths.to_f/confirmed.to_f)} %) | " + "\x03".b + color_recovered + "Recovered:" + "\x0f".b + " #{recovered.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*recovered.to_f/confirmed.to_f)} %)" +

              (m.channel.to_s.downcase == "#testing12" ? " [#{@@corona_lastupdate}]" : "")
            end

          end


          if cc.nil? # no exact match found in JHU DB, do geocoding lookup:
            puts "Did not find exact corona location match for '#{c.upcase}'."
            mylocation = c.dup

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

              puts "Found location lat/long/country/name in cache:  #{lat}/#{lng}/#{mycunt}/#{fad}"

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

            end # if c

            if newloc.nil?
              errormsg = "Failed to get lat/long."
              botlog errormsg, m
              m.reply errormsg
              return
            end

            puts "Searching corona country map for '#{mycunt}'"
            c = @CountryCacheEntry[mycunt]
            if c
              puts "Found JHU code of '#{c.jhu_code}'."
              cc = @@corona2.find{|x| (x["attributes"]["Country_Region"] || "").upcase == c.jhu_code.upcase}
              if cc.nil?
                errormsg = "Failed. (#{c.jhu_code.upcase})"
                botlog errormsg, m
                m.reply errormsg
                return
              end
            else
              errormsg = "Failed! (#{mycunt})"
              botlog errormsg, m
              m.reply errormsg
              return
            end

          end # if cc.nil?



          #c = cc["attributes"]
          #botlog "#{c["name"]} (#{c["symbol"]}) LU=#{@@corona_lastupdate}",m
          puts "cc=#{cc}"
          confirmed = @@corona2.select{|x| (x["attributes"]["Country_Region"] || "").upcase == cc["attributes"]["Country_Region"].upcase}.map{|x| x["attributes"]["Confirmed"]}.inject(0, :+)
          deaths = @@corona2.select{|x| (x["attributes"]["Country_Region"] || "").upcase == cc["attributes"]["Country_Region"].upcase}.map{|x| x["attributes"]["Deaths"]}.inject(0, :+)
          recovered = @@corona2.select{|x| (x["attributes"]["Country_Region"] || "").upcase == cc["attributes"]["Country_Region"].upcase}.map{|x| x["attributes"]["Recovered"]}.inject(0, :+)



          m.reply "" +
          "\x03".b + "04" + "#{cc["attributes"]["Country_Region"]}:" + "\x0f".b + "\x03".b + color_confirmed + "  Confirmed:" + "\x0f".b + " #{confirmed.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} | "  + "\x03".b + color_deaths + "Deaths:" + "\x0f".b + " #{deaths.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*deaths.to_f/confirmed.to_f)} %) | " + "\x03".b + color_recovered + "Recovered:" + "\x0f".b + " #{recovered.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*recovered.to_f/confirmed.to_f)} %)" +

          (m.channel.to_s.downcase == "#testing12" ? " [#{@@corona2_lastupdate}]" : "")

          return
        end
      end
    end





    
    
  end  
end
