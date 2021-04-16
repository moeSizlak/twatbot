module Plugins  
  class Stocks
    include Cinch::Plugin

    @@stocks = nil
    @@stocks_lastupdate = nil
    @@stocks_mutex = Mutex.new

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    #match lambda {|m| /^\.(?!btc)(#{m.bot.botconfig[:COINS].map{|x| Regexp.escape(x["symbol"])}.join('|')})\s*$/im}, use_prefix: false, method: :getStock
    match /^\.(?!\.)(?!btcx)(.{2,})\s*$/im, use_prefix: false, method: :getStock

    def initialize(*args)
      super
      @config = bot.botconfig
      updatestocks
    end

    def help(m)
      if m.bot.botconfig[:STOCKS_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end

      m.user.notice "\x02\x0304STOCKS:\n\x0f" + 
      "\x02  .<[partial] stock symbol or stock name>\x0f - Get stock prices and data\n"
    end

    def updatestocks
      @@stocks_mutex.synchronize do
        return if !@@stocks_lastupdate.nil?

        mystocks = Unirest::get("https://api.gon.gs/v1/symbols/", headers:{"Accept" => "application/json" }) rescue nil

        if !mystocks.nil? && !mystocks.body.nil? && mystocks.body.length > 0
            puts "Loading stock symbols"
            @@stocks = mystocks.body
            @@stocks_lastupdate = DateTime.now
            #puts @@stocks
        end
      end

    end

    def getStock(m,c)
      if m.bot.botconfig[:STOCKS_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:STOCKS_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      symbol_blacklist = ['LTC','ETH','BTC']

      c.strip!
      
      c1 = c
      c2 = c.upcase.split(/\s+/).intersection(@@stocks.map{|x| x["symbol"]}-symbol_blacklist)

      #puts c2.inspect

      if c2.length == 0
        cc = @@stocks.find{|x| x["name"].upcase == c1.upcase}
      end

      if c2.length == 0 && cc.nil? && c1.length >= 4
        cc = @@stocks.find{|x| x["name"].upcase.include?(c1.upcase)}
      end

      if c2.length == 0 && !cc.nil?
        c2 = [cc["symbol"]]
      end


      if c2.length > 0 
        c2.each do |x|
          c = x

          cc = @@stocks.find{|x| x["symbol"].upcase == c.upcase}          

          next if cc.nil?
          cc = Unirest::get("https://api.gon.gs/v1/quote/#{cc["symbol"]}", headers:{"Accept" => "application/json" }) rescue nil
          if cc.nil? || cc.body.nil? || cc.body.length <= 0
            m.reply "Error loading stock data (symbol=#{cc["symbol"]})."
            next
          end


          c = cc.body[0]
          botlog "#{c["name"]} (#{c["symbol"]}) LU=#{@@stocks_lastupdate}",m

          changeColor = "03"
          

          if c["change"] < 0
            changeColor = "04" 
            changeSymbol = ""
          else
            changeColor = "03"
            changeSymbol = "+"
          end


          m.reply "" +
          "\x02#{c["symbol"]} (#{c["name"]}):\x0f Last: #{c["price"]} \x03#{changeColor}#{changeSymbol}#{c["change"]} \x0f\x03#{changeColor}#{changeSymbol}#{c["changesPercentage"]}%\x0f (Vol: #{c["volume"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse}) Day: (#{c["dayLow"]}-#{c["dayHigh"]}) Year: (#{c["yearLow"]}-#{c["yearHigh"]}) Cap: #{c["marketCap"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse}"
        end
      end
    end

    

    
    

    
  end  
end
