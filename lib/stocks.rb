require 'httpx'
require 'finnhub_ruby'
require 'basic_yahoo_finance'

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
    match /^\.\.(?!\.)(?!btcx)(.{2,})\s*$/im, use_prefix: false, method: :getStock

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

        FinnhubRuby.configure do |config|
          config.api_key['api_key'] = @config[:FINHUB_API_KEY]
        end

        @@finnhub_client = FinnhubRuby::DefaultApi.new

        @@yahoofin = BasicYahooFinance::Query.new

        #mystocks = HTTPX.plugin(:follow_redirects).get("https://api.gon.gs/v2/symbols/", headers:{"Accept" => "application/json" }).json
        #puts "AAAAAAAAAAAAAAAAA #{mystocks}"
        mystocks = @@finnhub_client.stock_symbols('US')
        #mystocks = Alphavantage::Client.new(function: 'LISTING_STATUS').csv.drop(1).map{|x| {x[0] => x[1]}}.reduce Hash.new, :merge

        if !mystocks.nil? && !mystocks.nil? && mystocks.length > 0
            puts "Loading stock symbols"
            @@stocks = mystocks
            @@stocks_lastupdate = DateTime.now
            #puts @@stocks
        end
      end

    end

    def getStock(m,c)
      if m.bot.botconfig[:STOCKS_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:STOCKS_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      #symbol_blacklist = ['LTC','ETH','BTC','CHMA']
      symbol_blacklist =[]

      c.strip!
      
      c1 = c
      #c2 = c.upcase.split(/\s+/).intersection(@@stocks.map{|x| x["symbol"]}-symbol_blacklist)
      c2 = c.upcase.split(/\s+/)

      #puts c2.inspect
=begin
      if c2.length == 0
        cc = @@stocks.select{|x| x["description"].upcase == c1.upcase}
      end

      if c2.length == 0 && cc.length==0 && c1.length >= 4
        cc = @@stocks.select{|x| x["description"].upcase.include?(c1.upcase)}  #.sort_by { |x| x["description"].length }.first
      end

      if c2.length == 0 && !cc.nil? && cc.length == 0 and c1.length >= 4
        cc = c1.upcase.split(/\s+/)
      end

      if c2.length == 0 && !cc.nil? && cc.length > 0
        c2 = cc.map{|x| x["symbol"]}
      end
=end

      puts "c2.1=#{c2}"

      c2.each do |y|
        if y.length > 0
          zz = @@stocks.select{|x| x["description"].upcase == y.upcase}
          c2 = c2 + zz.map{|x| x["symbol"]} if zz.length > 0
        end

        if y.length >= 4
          zz = @@stocks.select{|x| x["description"].upcase.include?(y.upcase)}  #.sort_by { |x| x["description"].length }.first
          c2 = c2 + zz.map{|x| x["symbol"]} if zz.length > 0
        end
      end

      puts "c2.2=#{c2}"

      if c2.length > 0 
        c2.each do |x|
          c = x

          #cc = @@stocks.find{|x| x["symbol"].upcase == c.upcase}          
          #puts "Checking symbol '#{cc["symbol"]}'"
          puts "Checking symbol '#{c.upcase}'"


          #next if cc.nil?

          cc = @@yahoofin.quotes(c.upcase).values[0] rescue nil
          puts "cc=#{cc}"
          if cc.nil? || cc.length <= 0
            m.reply "Error loading stock data (symbol=#{c.upcase})." if c !~ /\./
            next
          end


          c = cc
          #puts "cc=#{cc}"
          botlog "#{c["longName"]} (#{c["symbol"]}) LU=#{@@stocks_lastupdate}",m

          changeColor = "03"
          

          if c["regularMarketChange"] < 0
            changeColor = "04" 
            changeSymbol = ""
          else
            changeColor = "03"
            changeSymbol = "+"
          end


          m.reply "" +
          "\x02#{c["symbol"]} (#{c["longName"]}):\x0f Last: #{c["regularMarketPrice"]} \x03#{changeColor}#{changeSymbol}#{c["regularMarketChange"].to_f.round(2)} \x0f\x03#{changeColor}#{changeSymbol}#{c["regularMarketChangePercent"].to_f.round(2)}%\x0f (Vol: #{c["regularMarketVolume"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse}) (Day: #{c["regularMarketDayLow"]}-#{c["regularMarketDayHigh"]}) (Year: #{c["fiftyTwoWeekLow"]}-#{c["fiftyTwoWeekHigh"]}) (200 Day Avg: #{c["twoHundredDayAverage"]}) (Cap: #{c["marketCap"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse})"
        end
      end
    end



    # OLD:

    def updatestocks_old
      @@stocks_mutex.synchronize do
        return if !@@stocks_lastupdate.nil?

        mystocks = HTTPX.plugin(:follow_redirects).get("https://api.gon.gs/v2/symbols/", headers:{"Accept" => "application/json" }).json
        #puts "AAAAAAAAAAAAAAAAA #{mystocks}"

        if !mystocks.nil? && !mystocks.nil? && mystocks.length > 0
            puts "Loading stock symbols"
            @@stocks = mystocks
            @@stocks_lastupdate = DateTime.now
            #puts @@stocks
        end
      end

    end

    def getStock_old(m,c)
      if m.bot.botconfig[:STOCKS_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:STOCKS_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      symbol_blacklist = ['LTC','ETH','BTC','CHMA']

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
          cc = HTTPX.plugin(:follow_redirects).get("https://api.gon.gs/v1/quote/#{cc["symbol"]}", headers:{"Accept" => "application/json" }).json
          if cc.nil? || cc.nil? || cc.length <= 0
            m.reply "Error loading stock data (symbol=#{cc["symbol"]})."
            next
          end


          c = cc[0]
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
          "\x02#{c["symbol"]} (#{c["name"]}):\x0f Last: #{c["price"]} \x03#{changeColor}#{changeSymbol}#{c["change"].to_f.round(2)} \x0f\x03#{changeColor}#{changeSymbol}#{c["changesPercentage"].to_f.round(2)}%\x0f (Vol: #{c["volume"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse}) Day: (#{c["dayLow"]}-#{c["dayHigh"]}) Year: (#{c["yearLow"]}-#{c["yearHigh"]}) Cap: #{c["marketCap"].to_s.reverse.gsub(/...(?=.)/,'\&,').reverse}"
        end
      end
    end

  end  
end
