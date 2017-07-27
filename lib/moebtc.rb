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
      bs = Unirest::get("https://www.bitstamp.net/api/v2/ticker/btcusd/")
      bsp = bs.body["last"] rescue nil      
      
      
      cb = Unirest::get("https://api.coinbase.com/v2/prices/spot?currency=USD")
      cbp = cb.body["data"]["amount"] rescue nil
      
      myreply1 = "\x03".b + "04" + "Bitstamp" + "\x0f".b + " | Buy: $" + bsp
      myreply2 = "\x03".b + "04" + "Coinbase" + "\x0f".b + " | Buy: $" + cbp
      m.reply myreply1
      m.reply myreply2
    
    
    end
    
  end  
end
