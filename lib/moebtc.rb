module Plugins  
  class MoeBTC
    include Cinch::Plugin

    @@coins = nil
    @@coins_lastupdate = nil
    @@coins_mutex = Mutex.new

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^\.moe/i, use_prefix: false, method: :moebtc
    match /^\.(btcx|motherfucker)\s*$/i, use_prefix: false, method: :getBTCRates
    #match lambda {|m| /^\.(?!btc)(#{m.bot.botconfig[:COINS].map{|x| Regexp.escape(x["symbol"])}.join('|')})\s*$/im}, use_prefix: false, method: :getCoin
    match /^\.(?!btcx)(.{2,})\s*$/im, use_prefix: false, method: :getCoin

    #timer 0,  {:method => :updatecoins, :shots => 1}
    #timer 60, {:method => :updatecoins}  

    def initialize(*args)
      super
      @config = bot.botconfig
    end

    def help(m)
      if m.bot.botconfig[:MOEBTC_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      m.user.notice "\x02\x0304CRYPTO COINS:\n\x0f" + 
      "\x02  .btc\x0f - Get current prices of BTC on Coinbase, BitStamp, and Gemini.  Also show LTC & ETH price.\n" +  
      "\x02  .<[partial] coin_name or coin_abbreviation>\x0f - Get info about a cryptocurrency from coinmarketcap\n"
    end

    def updatecoins
      #mycoins = Unirest::get("https://api.coinmarketcap.com/v1/ticker/?limit=0") rescue nil
      mycoins = Unirest::get("https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest?start=1&limit=600&convert=USD", headers:{ "X-CMC_PRO_API_KEY" => @config[:COINMARKETCAP_API_KEY],   "Accept" => "application/json" }) rescue nil

      if !mycoins.nil? && !mycoins.body.nil? && !mycoins.body["data"].nil?
          @@coins = mycoins.body["data"]
          @@coins_lastupdate = DateTime.now
          #puts @@coins
      end
    end

    def getCoin(m,c)
      if m.bot.botconfig[:MOEBTC_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:MOEBTC_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      c.strip!

      @@coins_mutex.synchronize do
        updatecoins if (@@coins_lastupdate.nil? || (@@coins_lastupdate < (DateTime.now - (15/1440.0))))

        c1 = c
        c2 = c.upcase.split(/\s+/).intersection(@@coins.map{|x| x["symbol"].upcase})
        #puts c2.inspect

        if c2.length == 0
          cc = @@coins.find{|x| x["name"].upcase == c.upcase}

          if cc.nil? && c.length >= 3
            cc = @@coins.find{|x| x["name"].upcase.include?(c.upcase)}
          end          

          if !cc.nil?
            c2 = [cc["symbol"]]
          end
        end

        if c2.length > 0 
          b = @@coins.find{|x| x["symbol"].upcase == 'BTC'} 
          return if b.nil?

          c2.each do |x|    
            c = @@coins.find{|y| y["symbol"].upcase == x.upcase} 
            botlog "#{c["name"]} (#{c["symbol"]}) LU=#{@@coins_lastupdate}",m             

            p = ""
            if m.user.to_s.downcase =~ /pinch/i
               p = sprintf("%.8f", (c["quote"]["USD"]["price"].to_f  / @@coins.find{|x| x["symbol"].upcase == "ETH"}["quote"]["USD"]["price"].to_f)).sub(/\.?0*$/,'') + " ETH | " #rescue ""
            end

            m.reply "" +
            "\x0304#{c["name"]} (#{c["symbol"]}):\x0f $#{('%.8f' % c["quote"]["USD"]["price"]).to_s.sub(/\.?0*$/,'')} | #{('%.8f' %  (c["quote"]["USD"]["price"].to_f / b["quote"]["USD"]["price"].to_f)).to_s.sub(/\.?0*$/,'')} BTC | " + p +
            "Rank: #{c["cmc_rank"]} | " +
            "(7d) \x0f"  + (!c["quote"]["USD"]["percent_change_7d"].nil?  && c["quote"]["USD"]["percent_change_7d"]  < 0 ? "\x0304" : "\x0303" + '+') + c["quote"]["USD"]["percent_change_7d"].to_f.round(2).to_s  + "%\x0f | " +
            "(24h) \x0f" + (!c["quote"]["USD"]["percent_change_24h"].nil? && c["quote"]["USD"]["percent_change_24h"] < 0 ? "\x0304" : "\x0303" + '+') + c["quote"]["USD"]["percent_change_24h"].to_f.round(2).to_s + "%\x0f | " +
            "(1h) \x0f"  + (!c["quote"]["USD"]["percent_change_1h"].nil?  && c["quote"]["USD"]["percent_change_1h"]  < 0 ? "\x0304" : "\x0303" + '+') + c["quote"]["USD"]["percent_change_1h"].to_f.round(2).to_s  + "%\x0f" +
            (m.channel.to_s.downcase == "#testing12" ? " [#{@@coins_lastupdate}]" : "")
          end
        end
      end
    end

    
    def moebtc(m)
      if m.bot.botconfig[:MOEBTC_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:MOEBTC_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      botlog "", m
    
      x = rand
      myreply1 = "\x0304Bitstamp\x0f | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      myreply2 = "\x0304Coinbase\x0f | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      m.reply myreply1
      m.reply myreply2
    end
    
    
    def getBTCRates(m)
      if m.bot.botconfig[:MOEBTC_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:MOEBTC_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      bs = Unirest::get("https://www.bitstamp.net/api/v2/ticker/btcusd/") rescue nil
      bsp = bs.body["last"] rescue ""      
      
      
      cb = Unirest::get("https://api.coinbase.com/v2/prices/spot?currency=USD") rescue nil
      cbp = cb.body["data"]["amount"] rescue ""

      cbl = Unirest::get("https://api.coinbase.com/v2/prices/LTC-USD/spot") rescue nil
      cblp = cbl.body["data"]["amount"] rescue ""

      cbe = Unirest::get("https://api.coinbase.com/v2/prices/ETH-USD/spot") rescue nil
      cbep = cbe.body["data"]["amount"] rescue ""

      #mc = Unirest::get("https://api.coinmarketcap.com/v1/ticker/bitcoin-cash/")
      #mcp = mc.body[0]["price_usd"].gsub(/(\.\d\d)\d+/,'\1') rescue ""
      mc = Unirest::get("https://www.bitstamp.net/api/v2/ticker/bchusd/") rescue nil
      mcp = mc.body["last"].gsub(/(\.\d\d)\d+/,'\1') rescue "" 

      xrp1 = Unirest::get("https://www.bitstamp.net/api/v2/ticker/xrpusd/") rescue nil
      xrp2 = xrp1.body["last"].gsub(/(\.\d\d)\d+/,'\1') rescue "" 

      g1 = Unirest::get("https://api.gemini.com/v1/pubticker/btcusd") rescue nil
      g2 = g1.body["last"] rescue "" 
      

      m.reply "\x0304Gemini:\x0f $" + g2.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(g2.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x0304BitStamp:\x0f $" + bsp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(bsp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x0304Coinbase:\x0f $" + cbp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbp.to_s.gsub(/^[^.]*(.*)$/, '\1')) # + " | " +
              #"\x0304BCH:\x0f $" + mcp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(mcp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              #"\x0304LTC:\x0f $" + cblp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cblp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              #"\x0304ETH:\x0f $" + cbep.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbep.to_s.gsub(/^[^.]*(.*)$/, '\1'))  
    
    end
    
  end  
end
