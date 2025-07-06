require 'httpx'

module Plugins  
  class MoeBTC
    include Cinch::Plugin


    @@coins_mutex = Mutex.new
    @@coinsymbols = nil
    @@coinsymbols_lastupdate = nil

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^\.moe/i, use_prefix: false, method: :moebtc
    match /^\.(btcx|motherfucker)\s*$/i, use_prefix: false, method: :getBTCRates
    #match lambda {|m| /^\.(?!btc)(#{m.bot.botconfig[:COINS].map{|x| Regexp.escape(x["symbol"])}.join('|')})\s*$/im}, use_prefix: false, method: :getCoin
    match /^\.(?!\.)(?!btcx)(.{2,})\s*$/im, use_prefix: false, method: :getCoin

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
      @@coins_mutex.synchronize do
        if (@@coinsymbols_lastupdate.nil? || (@@coinsymbols_lastupdate < (DateTime.now - (1.0))))
          mysyms = HTTPX.plugin(:follow_redirects).with(headers:{ "X-CMC_PRO_API_KEY" => @config[:COINMARKETCAP_API_KEY],   "Accept" => "application/json" }).get("https://pro-api.coinmarketcap.com/v1/cryptocurrency/map?sort=cmc_rank").json
          #puts mysyms["data"]

          if !mysyms.nil? && !mysyms.nil? && !mysyms["data"].nil?
              @@coinsymbols = mysyms["data"].reject { |y| y["name"].include?("okenized")}
              @@coinsymbols_lastupdate = DateTime.now
              #puts "SYM='#{@@coinsymbols.find{|x| x["symbol"].upcase == "TSLA"}}'"
          end
        end
      end
    end

    def getCoin(m,c)
      if m.bot.botconfig[:MOEBTC_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:MOEBTC_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      c.strip!

      updatecoins

      c1 = c
      c2 = c.upcase.split(/\s+/).intersection(@@coinsymbols.map{|x| x["symbol"].upcase})
      #puts "SYM2='#{@@coinsymbols.find{|x| x["symbol"].upcase == "TSLA"}}'"
      #puts "zzzzzz" + c2.inspect

      if c2.length == 0
        cc = @@coinsymbols.find{|x| x["name"].upcase == c.upcase}

        if cc.nil? && c.length >= 3
          cc = @@coinsymbols.find{|x| x["name"].upcase.include?(c.upcase)}
        end          

        if !cc.nil?
          c2 = [cc["symbol"]]
        end
      end

      if c2.length > 0 
        requested_coins = HTTPX.plugin(:follow_redirects).with(headers:{ "X-CMC_PRO_API_KEY" => @config[:COINMARKETCAP_API_KEY],   "Accept" => "application/json" }).get("https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=#{(c2+['BTC','ETH']).uniq.join(',')}&convert=USD").json

        return if requested_coins.nil? || requested_coins.nil? || requested_coins["data"].nil?
        requested_coins = requested_coins["data"]
        #puts "REQ=#{requested_coins}"

        b = requested_coins['BTC'] 
        e = requested_coins['ETH']

        c2.each do |x|    
          #c = requested_coins.find{|y| y["symbol"].upcase == x.upcase} 
          c = requested_coins[x.upcase]
          botlog "#{c["name"]} (#{c["symbol"]}) LU=#{@@coinsymbols_lastupdate}",m   
          next if c["name"].include?("okenized")

          p = ""
          if m.user.to_s.downcase =~ /pinch/i
             p = sprintf("%.8f", (c["quote"]["USD"]["price"].to_f  / e["quote"]["USD"]["price"].to_f)).sub(/\.?0*$/,'') + " ETH | " #rescue ""
          end

          m.reply "" +
          "\x02#{c["name"]} (#{c["symbol"]}):\x0f $#{('%.8f' % c["quote"]["USD"]["price"]).to_s.sub(/\.?0*$/,'')} | " + 
          (c["symbol"] != "BTC" ? "#{('%.8f' %  (c["quote"]["USD"]["price"].to_f / b["quote"]["USD"]["price"].to_f)).to_s.sub(/\.?0*$/,'')} BTC | #{('%.4f' %  (b["quote"]["USD"]["price"].to_f / c["quote"]["USD"]["price"].to_f)).to_s.sub(/\.?0*$/,'')} per BTC | " : "") + 
          p +
          "Rank: #{c["cmc_rank"]} | " +
          "(7d) \x0f"  + (!c["quote"]["USD"]["percent_change_7d"].nil?  && c["quote"]["USD"]["percent_change_7d"]  < 0 ? "\x0304" : "\x0303" + '+') + c["quote"]["USD"]["percent_change_7d"].to_f.round(2).to_s  + "%\x0f | " +
          "(24h) \x0f" + (!c["quote"]["USD"]["percent_change_24h"].nil? && c["quote"]["USD"]["percent_change_24h"] < 0 ? "\x0304" : "\x0303" + '+') + c["quote"]["USD"]["percent_change_24h"].to_f.round(2).to_s + "%\x0f | " +
          "(1h) \x0f"  + (!c["quote"]["USD"]["percent_change_1h"].nil?  && c["quote"]["USD"]["percent_change_1h"]  < 0 ? "\x0304" : "\x0303" + '+') + c["quote"]["USD"]["percent_change_1h"].to_f.round(2).to_s  + "%\x0f" +
          (m.channel.to_s.downcase == "#testing12" ? " [#{@@coinsymbols_lastupdate}]" : "")
        end
      end

    end

    
    def moebtc(m)
      if m.bot.botconfig[:MOEBTC_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:MOEBTC_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      botlog "", m
    
      x = rand
      myreply1 = "\x02Bitstamp\x0f | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      myreply2 = "\x02Coinbase\x0f | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      m.reply myreply1
      m.reply myreply2
    end
    
    
    def getBTCRates(m)
      if m.bot.botconfig[:MOEBTC_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:MOEBTC_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      bs = HTTPX.plugin(:follow_redirects).get("https://www.bitstamp.net/api/v2/ticker/btcusd/").json
      bsp = bs["last"] rescue ""      
      
      
      cb = HTTPX.plugin(:follow_redirects).get("https://api.coinbase.com/v2/prices/spot?currency=USD").json
      cbp = cb["data"]["amount"] rescue ""

      cbl = HTTPX.plugin(:follow_redirects).get("https://api.coinbase.com/v2/prices/LTC-USD/spot").json
      cblp = cbl["data"]["amount"] rescue ""

      cbe = HTTPX.plugin(:follow_redirects).get("https://api.coinbase.com/v2/prices/ETH-USD/spot").json
      cbep = cbe["data"]["amount"] rescue ""

      #mc = HTTPX.plugin(:follow_redirects).get("https://api.coinmarketcap.com/v1/ticker/bitcoin-cash/").json
      #mcp = mc[0]["price_usd"].gsub(/(\.\d\d)\d+/,'\1') rescue ""
      mc = HTTPX.plugin(:follow_redirects).get("https://www.bitstamp.net/api/v2/ticker/bchusd/").json
      mcp = mc["last"].gsub(/(\.\d\d)\d+/,'\1') rescue "" 

      xrp1 = HTTPX.plugin(:follow_redirects).get("https://www.bitstamp.net/api/v2/ticker/xrpusd/").json
      xrp2 = xrp1["last"].gsub(/(\.\d\d)\d+/,'\1') rescue "" 

      g1 = HTTPX.plugin(:follow_redirects).get("https://api.gemini.com/v1/pubticker/btcusd").json
      g2 = g1["last"] rescue "" 
      

      m.reply "\x02Gemini:\x0f $" + g2.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(g2.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x02BitStamp:\x0f $" + bsp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(bsp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x02Coinbase:\x0f $" + cbp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbp.to_s.gsub(/^[^.]*(.*)$/, '\1')) # + " | " +
              #"\x0304BCH:\x0f $" + mcp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(mcp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              #"\x0304LTC:\x0f $" + cblp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cblp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              #"\x0304ETH:\x0f $" + cbep.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbep.to_s.gsub(/^[^.]*(.*)$/, '\1'))  
    
    end
    
  end  
end
