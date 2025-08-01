require 'sequel'
require 'csv'
require 'httpx'
require 'nokogiri'


module Plugins  
  class CoronaVirus
    include Cinch::Plugin

    @@corona = nil
    @@corona_lastupdate = nil
    @@corona2 = nil
    @@corona2_lastupdate = nil

    @@corona_mutex = Mutex.new

    @@corona_countries = nil
    @@corona_states = nil
    @@corona_new_lastupdate = nil
    @@corona_new_mutex = Mutex.new

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    #match lambda {|m| /^\.(?!btc)(#{m.bot.botconfig[:COINS].map{|x| Regexp.escape(x["symbol"])}.join('|')})\s*$/im}, use_prefix: false, method: :getCorona
    match /^\.corona(\s*|\s+[\S\s]+\S\s*)$/im, use_prefix: false, method: :getCorona_new
    match /^\.corona2(\s*|\s+[\S\s]+\S\s*)$/im, use_prefix: false, method: :getCorona
    match /^\.coronatest$/im, use_prefix: false, method: :updatecorona_new

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

      m.user.notice "\x02\x0304CORONAVIRUS:\n\x0f"+ 
      "\x02  .corona <[partial] country name>\x0f - Get stats on coronavirus infections (optionally, in a specific country)\n"
    end

    def updatecorona
      mycorona2 = HTTPX.plugin(:follow_redirects).with(headers: {"authority" => "services1.arcgis.com", "pragma" => "no-cache", "cache-control" => "no-cache", "user-agent" => "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Safari/537.36", "sec-fetch-dest" => "empty", "accept" => "*/*", "origin" => "https://gisanddata.maps.arcgis.com", "sec-fetch-site" => "same-site", "sec-fetch-mode" => "cors", "referer" => "https://gisanddata.maps.arcgis.com/apps/opsdashboard/index.html", "accept-language" => "en-US,en;q=0.9"}).get("https://services1.arcgis.com/0MSEUqKaxRlEPj5g/arcgis/rest/services/ncov_cases/FeatureServer/2/query?f=json&where=Confirmed%20%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Confirmed%20desc&resultOffset=0&resultRecordCount=200&cacheHint=true").json
      mycorona = HTTPX.plugin(:follow_redirects).with(headers: {"authority" => "services1.arcgis.com", "pragma" => "no-cache", "cache-control" => "no-cache", "user-agent" => "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Safari/537.36", "sec-fetch-dest" => "empty", "accept" => "*/*", "origin" => "https://gisanddata.maps.arcgis.com", "sec-fetch-site" => "same-site", "sec-fetch-mode" => "cors", "referer" => "https://gisanddata.maps.arcgis.com/apps/opsdashboard/index.html", "accept-language" => "en-US,en;q=0.9"}).get("https://services1.arcgis.com/0MSEUqKaxRlEPj5g/arcgis/rest/services/ncov_cases/FeatureServer/1/query?f=json&where=Confirmed%20%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Confirmed%20desc%2CCountry_Region%20asc%2CProvince_State%20asc&resultOffset=0&resultRecordCount=250&cacheHint=true").json

      if !mycorona.nil? && !mycorona.nil? && !mycorona["features"].nil?
        @@corona = mycorona["features"]
        @@corona_lastupdate = DateTime.now
      end

      if !mycorona2.nil? && !mycorona2.nil? && !mycorona2["features"].nil?
        @@corona2 = mycorona2["features"]
        @@corona2_lastupdate = DateTime.now
      end

    end


    def updatecorona_new(m=nil)
      mycorona_countries = HTTPX.plugin(:follow_redirects).with(headers:{"authority" => "www.worldometers.info", "pragma" => "no-cache", "cache-control" => "no-cache", "user-agent" => "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Safari/537.36", "accept-language" => "en-US,en;q=0.9"}).get("https://www.worldometers.info/coronavirus/").body.to_s rescue nil
      mycorona_usa = HTTPX.plugin(:follow_redirects).with(headers: {"authority" => "www.worldometers.info", "pragma" => "no-cache", "cache-control" => "no-cache", "user-agent" => "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Safari/537.36", "accept-language" => "en-US,en;q=0.9"}).get("https://www.worldometers.info/coronavirus/country/us/").body.to_s  rescue nil
      

      if !mycorona_countries.nil?
        doc = Nokogiri::HTML(mycorona_countries)
        tab = doc.at("table#main_table_countries_today tbody")
        
        @@corona_countries = {}
        countries = tab.css("tr").select{|x| x['style'] !~ /display:\s*none/}.each do |row|
          cols = row.css("td")

          #puts cols[1].text.strip.to_s + "===" + cols[2].text.strip.to_s

          @@corona_countries[cols[1].text.strip.to_s] = {
            'cases' => cols[2].text.strip.to_s,
            'new_cases' => cols[3].text.strip.to_s,
            'deaths' => cols[4].text.strip.to_s,
            'new_deaths' => cols[5].text.strip.to_s,
            'recovered' => cols[6].text.strip.to_s,

            'active' => cols[8].text.strip.to_s,
            'serious' => cols[9].text.strip.to_s,
            'cases_per_mil' => cols[10].text.strip.to_s,
            'deaths_per_mil' => cols[11].text.strip.to_s,
            'tests' => cols[12].text.strip.to_s,
            'tests_per_mil' => cols[13].text.strip.to_s,
            'continent' => cols[14].text.strip.to_s
          }

        end
        #puts @@corona_countries.keys.to_s
        @@corona_new_lastupdate = DateTime.now
      end


      if !mycorona_usa.nil?
        doc = Nokogiri::HTML(mycorona_usa)
        tab = doc.at("table#usa_table_countries_today tbody")
        
        @@corona_states = {}
        states = tab.css("tr").select{|x| x['style'] !~ /display:\s*none/ && x['class'] !~ /total_row/ }.each do |row|
          cols = row.css("td")

          @@corona_states[cols[1].text.strip.to_s] = {
            'cases' => cols[2].text.strip.to_s,
            'new_cases' => cols[3].text.strip.to_s,
            'deaths' => cols[4].text.strip.to_s,
            'new_deaths' => cols[5].text.strip.to_s,
            'active' => cols[6].text.strip.to_s,
            'cases_per_mil' => cols[7].text.strip.to_s,
            'deaths_per_mil' => cols[8].text.strip.to_s,
            'tests' => cols[9].text.strip.to_s,
            'tests_per_mil' => cols[10].text.strip.to_s
          }

        end
        #puts @@corona_states.to_s
      end

    end




    def getCorona_new(m,c)
      if m.bot.botconfig[:CORONA_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:CORONA_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      color_confirmed = "07"
      color_deaths = "07"
      color_recovered = "07"

      c.strip!
      @@corona_new_mutex.synchronize do
        updatecorona_new if (@@corona_new_lastupdate.nil? || (@@corona_new_lastupdate < (DateTime.now - (15/1440.0))))

        if @@corona_countries.nil?
          m.reply "API Unavailable" 
          getCorona(m, c)
          return
        end

        if c.nil? || c.length == 0
          w = @@corona_countries["World"]
          #puts w.to_s
          #m.reply "\x0304ZOMG CORONA!!!\x0f  Confirmed: \x02\x0307#{w['cases']} (#{w['new_cases']})\x0f, deaths: \x02\x0304#{w['deaths']} (#{w['new_deaths']})\x0f, recovered: \x02\x0309#{w['recovered']}\x0f. Active cases: \x02\x0307#{w['active']}\x0f (\x02\x0304#{'%.2f' % (100 * w['serious'].gsub(/\D/,'').to_f/w['active'].gsub(/\D/,'').to_f)} %\x0f in serious condition.) Mortality: \x02\x0304#{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/w['cases'].gsub(/\D/,'').to_f)} %\x0f, case fatality rate: \x02\x0304#{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/(w['recovered'].gsub(/\D/,'').to_f + w['deaths'].gsub(/\D/,'').to_f))} %\x0f " #. Case rate: 94,629/24h, death rate: 6,973/24h. Last update: 4m ago."

          m.reply "\x02ZOMG CORONA!!!\x0f" +
          " | Confirmed: \x02\x0307#{w['cases']}" +
          #" (#{w['new_cases']})" +
          ((w['cases_per_mil'].nil? || w['cases_per_mil'].empty?) ? "" : " (#{w['cases_per_mil']}/1M)") + "\x0f"+ 
          " | Deaths: \x02\x0304#{w['deaths']} (#{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/w['cases'].gsub(/\D/,'').to_f)}%)" +
          #" (#{w['new_deaths']})" + 
          ((w['deaths_per_mil'].nil? || w['deaths_per_mil'].empty?) ? "" : " (#{w['deaths_per_mil']}/1M)") + "\x0f"+ 
          " | Recovered: \x02\x0309#{w['recovered']} (#{'%.2f' % (100 * w['recovered'].gsub(/\D/,'').to_f/w['cases'].gsub(/\D/,'').to_f)}%)\x0f"+ 
          #", Active cases: \x02\x0307#{w['active']}\x0f (\x02\x0304#{'%.2f' % (100 * w['serious'].gsub(/\D/,'').to_f/w['active'].gsub(/\D/,'').to_f)} %\x0f in serious condition)" +
          #", Mortality: \x02\x0304#{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/w['cases'].gsub(/\D/,'').to_f)} %\x0f"+ 
          #", case fatality rate: \x02\x0304#{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/(w['recovered'].gsub(/\D/,'').to_f + w['deaths'].gsub(/\D/,'').to_f))} %\x0f"+ 
          #{}", Tests: \x02\x0309#{w['tests']} (#{w['tests_per_mil']} /1M)\x0f"+ #. Case rate: 94,629/24h, death rate: 6,973/24h. Last update: 4m ago."
          ((w['tests'].nil? || w['tests'].empty?) ? "" : " | Tests: \x02\x0309#{w['tests']}" +  ((w['tests_per_mil'].nil? || w['tests_per_mil'].empty?) ? "" : " (#{w['tests_per_mil']}/1M)")   ) + "\x0f"

=begin
          m.reply "" + 
                                     "\x02ZOMG CORONA!!!\x0f" + 
          ", Confirmed: \x02\x0307#{w['cases']} (#{w['new_cases']}) (#{w['cases_per_mil']} /1M)\x0f" +
          ", deaths: \x02\x0304#{w['deaths']} (#{w['new_deaths']}) (#{w['deaths_per_mil']} /1M)\x0f" + 
          ", recovered: \x02\x0309#{w['recovered']}\x0f" + 
          ", Active cases: \x02\x0307#{w['active']}\x0f (\x02\x0304#{'%.2f' % (100 * w['serious'].gsub(/\D/,'').to_f/w['active'].gsub(/\D/,'').to_f)} %\x0f in serious condition)" +
          ", Mortality: \x02\x0304#{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/w['cases'].gsub(/\D/,'').to_f)} %\x0f" + 
          ", case fatality rate: \x02\x0304#{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/(w['recovered'].gsub(/\D/,'').to_f + w['deaths'].gsub(/\D/,'').to_f))} %\x0f" + 
          ", Tests: \x02\x0309#{w['tests']} (#{w['tests_per_mil']} /1M)\x0f" #+ #. Case rate: 94,629/24h, death rate: 6,973/24h. Last update: 4m ago."
=end
=begin
          m.reply "" + 
                                     "\x02ZOMG CORONA!!!\x0f"+ 
          ", Confirmed: #{w['cases']} (#{w['new_cases']}) (#{w['cases_per_mil']} /1M)" + 
          ", deaths: #{w['deaths']} (#{w['new_deaths']}) (#{w['deaths_per_mil']} /1M)" +
          ", recovered: #{w['recovered']}" +
          ", Active cases: #{w['active']} (#{'%.2f' % (100 * w['serious'].gsub(/\D/,'').to_f/w['active'].gsub(/\D/,'').to_f)} % in serious condition)" +
          ", Mortality: #{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/w['cases'].gsub(/\D/,'').to_f)} %" + 
          ", case fatality rate: #{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/(w['recovered'].gsub(/\D/,'').to_f + w['deaths'].gsub(/\D/,'').to_f))} %" +
          ", Tests: #{w['tests']} (#{w['tests_per_mil']} /1M)"  #+ #. Case rate: 94,629/24h, death rate: 6,973/24h. Last update: 4m ago."
=end
=begin
          m.reply "" + 
                                     "\x02ZOMG CORONA!!!\x0f"+ 
          ", \x0307Confirmed:\x0f #{w['cases']} (#{w['new_cases']}) (#{w['cases_per_mil']} /1M)" + 
          ", \x0307deaths:\x0f #{w['deaths']} (#{w['new_deaths']}) (#{w['deaths_per_mil']} /1M)" +
          ", \x0307recovered:\x0f #{w['recovered']}" +
          ", \x0307Active cases:\x0f #{w['active']} (#{'%.2f' % (100 * w['serious'].gsub(/\D/,'').to_f/w['active'].gsub(/\D/,'').to_f)} % in serious condition)" +
          ", \x0307Mortality:\x0f #{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/w['cases'].gsub(/\D/,'').to_f)} %" + 
          ", \x0307case fatality rate:\x0f #{'%.2f' % (100 * w['deaths'].gsub(/\D/,'').to_f/(w['recovered'].gsub(/\D/,'').to_f + w['deaths'].gsub(/\D/,'').to_f))} %" +
          ", \x0307Tests:\x0f #{w['tests']} (#{w['tests_per_mil']} /1M)"  #+ #. Case rate: 94,629/24h, death rate: 6,973/24h. Last update: 4m ago."
=end
          return
        else
        
          cc = nil
          cc = @@corona_countries.select{|k,v| k.upcase == c.upcase}.first

          ss = nil


          if cc.nil?
            cc = @@corona_states.select{|k,v| k.upcase == c.upcase}.first
            if cc.nil?
              mystate = @config[:DB][:states].where(Sequel.function(:upper, :code) => c.upcase).all
              if mystate && mystate.count == 1
                cc = @@corona_states.select{|k,v| k.upcase == mystate.first[:name].upcase}.first
              end
            end

            if !cc.nil?
              #m.reply "" +
              #"\x02#{cc[0]}:\x0f\x03"+ color_confirmed + "  Confirmed:\x0f #{confirmed.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} | \x03"+ color_deaths + "Deaths:\x0f #{deaths.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*deaths.to_f/confirmed.to_f)} %) | \x03"+ color_recovered + "Recovered:\x0f #{recovered.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*recovered.to_f/confirmed.to_f)} %)" +

              puts @@corona_states.select{|k,v| v['cases'].gsub(/\D/,'').to_i > cc[1]['cases'].gsub(/\D/,'').to_i}.count + 1

              m.reply "" + 
                                     "\x02#{cc[0]}\x0f"+ 
              ": US State Rank: \x02\x0304##{(@@corona_states.select{|k,v| v['cases'].gsub(/\D/,'').to_i > cc[1]['cases'].gsub(/\D/,'').to_i}.count.to_i) +1}\x0f"+ # of #{@@corona_countries.count - 1}\x0f"+ 
              " | Confirmed: \x02\x0307#{cc[1]['cases']}" +
              #" (#{cc[1]['new_cases']})" +
              ((cc[1]['cases_per_mil'].nil? || cc[1]['cases_per_mil'].empty?) ? "" : " (#{cc[1]['cases_per_mil']}/1M)") + "\x0f"+ 
              " | Deaths: \x02\x0304#{cc[1]['deaths']} (#{'%.2f' % (100 * cc[1]['deaths'].gsub(/\D/,'').to_f/cc[1]['cases'].gsub(/\D/,'').to_f)}%)" +
              #" (#{cc[1]['new_deaths']})" + 
              ((cc[1]['deaths_per_mil'].nil? || cc[1]['deaths_per_mil'].empty?) ? "" : " (#{cc[1]['deaths_per_mil']}/1M)") + "\x0f"+ 
              #" | Recovered: \x02\x0309#{cc[1]['recovered']} (#{'%.2f' % (100 * cc[1]['recovered'].gsub(/\D/,'').to_f/cc[1]['cases'].gsub(/\D/,'').to_f)}%)\x0f"+ 
              #", Active cases: \x02\x0307#{cc[1]['active']}\x0f (\x02\x0304#{'%.2f' % (100 * cc[1]['serious'].gsub(/\D/,'').to_f/cc[1]['active'].gsub(/\D/,'').to_f)} %\x0f in serious condition)" +
              #", Mortality: \x02\x0304#{'%.2f' % (100 * cc[1]['deaths'].gsub(/\D/,'').to_f/cc[1]['cases'].gsub(/\D/,'').to_f)} %\x0f"+ 
              #", case fatality rate: \x02\x0304#{'%.2f' % (100 * cc[1]['deaths'].gsub(/\D/,'').to_f/(cc[1]['recovered'].gsub(/\D/,'').to_f + cc[1]['deaths'].gsub(/\D/,'').to_f))} %\x0f"+ 
              #{}", Tests: \x02\x0309#{cc[1]['tests']} (#{cc[1]['tests_per_mil']} /1M)\x0f"+ #. Case rate: 94,629/24h, death rate: 6,973/24h. Last update: 4m ago."
              ((cc[1]['tests'].nil? || cc[1]['tests'].empty?) ? "" : " | Tests: \x02\x0309#{cc[1]['tests']}" +  ((cc[1]['tests_per_mil'].nil? || cc[1]['tests_per_mil'].empty?) ? "" : " (#{cc[1]['tests_per_mil']}/1M)")   ) + "\x0f"+ 

              (m.channel.to_s.downcase == "#testing12" ? " [#{@@corona_new_lastupdate}]" : "")

              cc = @@corona_countries.select{|k,v| k.upcase == 'US'}.first
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
              newloc = HTTPX.plugin(:follow_redirects).get("https://maps.googleapis.com/maps/api/geocode/json?address=#{CGI.escape(mylocation).gsub('+','%20')}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}").json
              
              if newloc && newloc && newloc.key?("results") && newloc["results"][0] && newloc["results"][0].key?("geometry") && newloc["results"][0]["geometry"].key?("location") && newloc["results"][0]["geometry"]["location"].key?("lat") && newloc["results"][0]["geometry"]["location"].key?("lng")
                lat  = newloc["results"][0]["geometry"]["location"]["lat"].to_s
                lng  = newloc["results"][0]["geometry"]["location"]["lng"].to_s

                if newloc && newloc && newloc.key?("results") && newloc["results"][0] && newloc["results"][0].key?("address_components") && newloc["results"][0]["address_components"].length > 0
                  # Remove all of the following address components unconditionally
                  ac = newloc["results"][0]["address_components"].select{|x| !(x["types"] & ["country","administrative_area_level_1","administrative_area_level_2","colloquial_area","locality","natural_feature","airport","park","point_of_interest"]).empty?}
                  
                  # Only remove administrative_area_level_2 if it is not the FIRST address component in the list:
                  ac = ac.reject{|x| x["types"].include?("administrative_area_level_2")} unless ac[0]["types"].include?("administrative_area_level_2")

                  sl = "long_name"
                  sl = "short_name" if (ac.find{|x| x["types"].include?("country") rescue ""}["short_name"] rescue "error") == "US"
                  fad = ac.collect{|x| x[sl]}.join(", ")
                end
                mycunt = newloc["results"][0]["address_components"].find{|x| x["types"].include?("country") rescue false}["short_name"] rescue "error"

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
              puts "Found WOM (world-o-meter) code of '#{c.wom_code}'."
              cc = @@corona_countries.select{|k,v| k.upcase == c.wom_code.upcase}.first
              if cc.nil?
                errormsg = "Failed. (#{c.name} => #{c.wom_code.upcase})"
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



          puts "cc=#{cc}"

          m.reply "" + 
                                     "\x02#{cc[0]}\x0f"+ 
          ": Rank: \x02\x0304##{@@corona_countries.select{|k,v| v['cases'].gsub(/\D/,'').to_f > cc[1]['cases'].gsub(/\D/,'').to_f}.count}\x0f"+ # of #{@@corona_countries.count - 1}\x0f"+ 
          " | Confirmed: \x02\x0307#{cc[1]['cases']}" +
          #" (#{cc[1]['new_cases']})" +
          ((cc[1]['cases_per_mil'].nil? || cc[1]['cases_per_mil'].empty?) ? "" : " (#{cc[1]['cases_per_mil']}/1M)") + "\x0f"+ 
          " | Deaths: \x02\x0304#{cc[1]['deaths']} (#{'%.2f' % (100 * cc[1]['deaths'].gsub(/\D/,'').to_f/cc[1]['cases'].gsub(/\D/,'').to_f)}%)" +
          #" (#{cc[1]['new_deaths']})" + 
          ((cc[1]['deaths_per_mil'].nil? || cc[1]['deaths_per_mil'].empty?) ? "" : " (#{cc[1]['deaths_per_mil']}/1M)") + "\x0f"+ 
          " | Recovered: \x02\x0309#{cc[1]['recovered']} (#{'%.2f' % (100 * cc[1]['recovered'].gsub(/\D/,'').to_f/cc[1]['cases'].gsub(/\D/,'').to_f)}%)\x0f"+ 
          #", Active cases: \x02\x0307#{cc[1]['active']}\x0f (\x02\x0304#{'%.2f' % (100 * cc[1]['serious'].gsub(/\D/,'').to_f/cc[1]['active'].gsub(/\D/,'').to_f)} %\x0f in serious condition)" +
          #", Mortality: \x02\x0304#{'%.2f' % (100 * cc[1]['deaths'].gsub(/\D/,'').to_f/cc[1]['cases'].gsub(/\D/,'').to_f)} %\x0f"+ 
          #", case fatality rate: \x02\x0304#{'%.2f' % (100 * cc[1]['deaths'].gsub(/\D/,'').to_f/(cc[1]['recovered'].gsub(/\D/,'').to_f + cc[1]['deaths'].gsub(/\D/,'').to_f))} %\x0f"+ 
          #{}", Tests: \x02\x0309#{cc[1]['tests']} (#{cc[1]['tests_per_mil']} /1M)\x0f"+ #. Case rate: 94,629/24h, death rate: 6,973/24h. Last update: 4m ago."
          ((cc[1]['tests'].nil? || cc[1]['tests'].empty?) ? "" : " | Tests: \x02\x0309#{cc[1]['tests']}" +  ((cc[1]['tests_per_mil'].nil? || cc[1]['tests_per_mil'].empty?) ? "" : " (#{cc[1]['tests_per_mil']}/1M)")   ) + "\x0f"+ 
          
          (m.channel.to_s.downcase == "#testing12" ? " [#{@@corona_new_lastupdate}]" : "")

          return
        end
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
      @@corona_mutex.synchronize do
        updatecorona if (@@corona_lastupdate.nil? || (@@corona_lastupdate < (DateTime.now - (15/1440.0))))
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
         "\x0304CORONA!!!\x0f\x03"+ color_confirmed + "  Confirmed:\x0f #{confirmed.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} | \x03"+ color_deaths + "Deaths:\x0f #{deaths.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*deaths.to_f/confirmed.to_f)} %) | \x03"+ color_recovered + "Recovered:\x0f #{recovered.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*recovered.to_f/confirmed.to_f)} %)" +
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
              "\x0304#{cc["attributes"]["Province_State"]}:\x0f\x03"+ color_confirmed + "  Confirmed:\x0f #{confirmed.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} | \x03"+ color_deaths + "Deaths:\x0f #{deaths.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*deaths.to_f/confirmed.to_f)} %) | \x03"+ color_recovered + "Recovered:\x0f #{recovered.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*recovered.to_f/confirmed.to_f)} %)" +

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
              newloc = HTTPX.plugin(:follow_redirects).get("https://maps.googleapis.com/maps/api/geocode/json?address=#{CGI.escape(mylocation).gsub('+','%20')}&key=#{@config[:YOUTUBE_GOOGLE_SERVER_KEY]}").json
              
              if newloc && newloc && newloc.key?("results") && newloc["results"][0] && newloc["results"][0].key?("geometry") && newloc["results"][0]["geometry"].key?("location") && newloc["results"][0]["geometry"]["location"].key?("lat") && newloc["results"][0]["geometry"]["location"].key?("lng")
                lat  = newloc["results"][0]["geometry"]["location"]["lat"].to_s
                lng  = newloc["results"][0]["geometry"]["location"]["lng"].to_s

                if newloc && newloc && newloc.key?("results") && newloc["results"][0] && newloc["results"][0].key?("address_components") && newloc["results"][0]["address_components"].length > 0
                  # Remove all of the following address components unconditionally
                  ac = newloc["results"][0]["address_components"].select{|x| !(x["types"] & ["country","administrative_area_level_1","administrative_area_level_2","colloquial_area","locality","natural_feature","airport","park","point_of_interest"]).empty?}
                  
                  # Only remove administrative_area_level_2 if it is not the FIRST address component in the list:
                  ac = ac.reject{|x| x["types"].include?("administrative_area_level_2")} unless ac[0]["types"].include?("administrative_area_level_2")

                  sl = "long_name"
                  sl = "short_name" if (ac.find{|x| x["types"].include?("country") rescue ""}["short_name"] rescue "error") == "US"
                  fad = ac.collect{|x| x[sl]}.join(", ")
                end
                mycunt = newloc["results"][0]["address_components"].find{|x| x["types"].include?("country") rescue false}["short_name"] rescue "error"


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
          "\x0304#{cc["attributes"]["Country_Region"]}:\x0f\x03"+ color_confirmed + "  Confirmed:\x0f #{confirmed.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} | \x03"+ color_deaths + "Deaths:\x0f #{deaths.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*deaths.to_f/confirmed.to_f)} %) | \x03"+ color_recovered + "Recovered:\x0f #{recovered.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} (#{'%.2f' % (100*recovered.to_f/confirmed.to_f)} %)" +

          (m.channel.to_s.downcase == "#testing12" ? " [#{@@corona2_lastupdate}]" : "")

          return
        end
      end
    end





    
    
  end  
end
