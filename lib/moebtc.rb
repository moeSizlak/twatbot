module Plugins  
  class MoeBTC
    include Cinch::Plugin

    @@coins = nil
    @@coins_lastupdate = nil
    @@coins_mutex = Mutex.new

    set :react_on, :message
    
    match /^\.moe/i, use_prefix: false, method: :moebtc
    match /^\.(btc|motherfucker)\s*$/i, use_prefix: false, method: :getBTCRates
    #match lambda {|m| /^\.(?!btc)(#{m.bot.botconfig[:COINS].map{|x| Regexp.escape(x["symbol"])}.join('|')})\s*$/im}, use_prefix: false, method: :getCoin
    match /^\.(?!btc)(.{2,})\s*$/im, use_prefix: false, method: :getCoin

    #timer 0,  {:method => :updatecoins, :shots => 1}
    #timer 60, {:method => :updatecoins}  

    def initialize(*args)
      super
      @config = bot.botconfig
    end

    def updatecoins
      mycoins = Unirest::get("https://api.coinmarketcap.com/v1/ticker/?limit=0") rescue nil
      if !mycoins.nil? && !mycoins.body.nil?
          @@coins = mycoins.body
          @@coins_lastupdate = DateTime.now
      end
    end

    def getCoin(m,c)
      cc = nil
      @@coins_mutex.synchronize do
        updatecoins if (@@coins_lastupdate.nil? || (@@coins_lastupdate < (DateTime.now - (4/1440.0))))

        cc = @@coins.find{|x| x["symbol"].upcase == c.upcase}

        if cc.nil?
          cc = @@coins.find{|x| x["name"].upcase == c.upcase}
        end

        if cc.nil? && c.length >= 3
          cc = @@coins.find{|x| x["name"].upcase.include?(c.upcase)}
        end

      end

      return if cc.nil?

      c = cc
      botlog "#{c["name"]} (#{c["symbol"]}) LU=#{@@coins_lastupdate}",m

      p = ""
      if m.user.to_s.downcase =~ /pinch/i
         p = sprintf("%.8f", (c["price_btc"].to_f  / @@coins.find{|x| x["symbol"].upcase == "ETH"}["price_btc"].to_f)).sub(/\.?0*$/,'') + " ETH | " rescue ""

      end


      m.reply "" +
      "\x03".b + "04" + "#{c["name"]} (#{c["symbol"]}):" + "\x0f".b + " $#{c["price_usd"]} | #{c["price_btc"]} BTC | " + p +
      "Rank: #{c["rank"]} | " +
      "(7d) " + "\x0f".b  + (!c["percent_change_7d"].nil?  && c["percent_change_7d"][0]  == "-" ? "\x03".b + "04" : "\x03".b + "03" + '+') + c["percent_change_7d"].to_s  + "%" + "\x0f".b + " | " +
      "(24h) " + "\x0f".b + (!c["percent_change_24h"].nil? && c["percent_change_24h"][0] == "-" ? "\x03".b + "04" : "\x03".b + "03" + '+') + c["percent_change_24h"].to_s + "%" + "\x0f".b + " | " +
      "(1h) " + "\x0f".b  + (!c["percent_change_1h"].nil?  && c["percent_change_1h"][0]  == "-" ? "\x03".b + "04" : "\x03".b + "03" + '+') + c["percent_change_1h"].to_s  + "%" + "\x0f".b +
      (m.channel.to_s.downcase == "#testing12" ? " [#{@@coins_lastupdate}]" : "")

    end

    
    def moebtc(m)
      botlog "", m
    
      x = rand
      myreply1 = "\x03".b + "04" + "Bitstamp" + "\x0f".b + " | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      myreply2 = "\x03".b + "04" + "Coinbase" + "\x0f".b + " | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      m.reply myreply1
      m.reply myreply2
    end
    
    
    def getBTCRates(m)
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
      

      m.reply "\x03".b + "04" + "GEM:"   + "\x0f".b + " $" + g2.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(g2.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "BS:" + "\x0f".b + " $" + bsp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(bsp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "CB:" + "\x0f".b + " $" + cbp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "BCH:"      + "\x0f".b + " $" + mcp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(mcp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "LTC:"      + "\x0f".b + " $" + cblp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cblp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "ETH:"      + "\x0f".b + " $" + cbep.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbep.to_s.gsub(/^[^.]*(.*)$/, '\1'))  
    
    end
    
  end  
end
