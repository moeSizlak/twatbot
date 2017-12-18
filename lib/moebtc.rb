module Plugins  
  class MoeBTC
    include Cinch::Plugin
    set :react_on, :message
    
    match /^\.moe/i, use_prefix: false, method: :moebtc
    match /^\.(btc|motherfucker)\s*$/i, use_prefix: false, method: :getBTCRates
    
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
      
      #myreply1 = "\x03".b + "04" + "Bitstamp" + "\x0f".b + " | Buy: $" + bsp
      #myreply2 = "\x03".b + "04" + "Coinbase" + "\x0f".b + " | Buy: $" + cbp
      #myreply3 = "\x03".b + "04" + "BCH     " + "\x0f".b + " | Buy: $" + mcp
      #m.reply myreply1
      #m.reply myreply2
      #m.reply myreply3

      m.reply "\x03".b + "04" + "GEM:"   + "\x0f".b + " $" + g2.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(g2.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "BS:" + "\x0f".b + " $" + bsp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(bsp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "CB:" + "\x0f".b + " $" + cbp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "BCH:"      + "\x0f".b + " $" + mcp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(mcp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "LTC:"      + "\x0f".b + " $" + cblp.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cblp.to_s.gsub(/^[^.]*(.*)$/, '\1')) + " | " +
              "\x03".b + "04" + "ETH:"      + "\x0f".b + " $" + cbep.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(cbep.to_s.gsub(/^[^.]*(.*)$/, '\1')) #+ " | " +
            #  "\x03".b + "04" + "XRP:"      + "\x0f".b + " $" + xrp2.to_s.gsub(/^([^.]*).*$/,'\1').reverse.scan(/\d{3}|.+/).join(",").reverse.concat(xrp2.to_s.gsub(/^[^.]*(.*)$/, '\1'))
    
    
    end
    
  end  
end
