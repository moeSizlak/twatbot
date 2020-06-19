require 'sequel'
require 'date'

module Plugins  
  class Logmobile
    include Cinch::Plugin
    set :react_on, :message
    
    #set :react_on, :channel 

    timer 600, {:method => :clear_hash}
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!log\s*search\s+(\S.*)$/, use_prefix: false, method: :logsearch
    
    def initialize(*args)
      super
      @config = bot.botconfig
      @lastquotes = Hash.new
    end

    def help(m)
      if !@config[:QUOTEDB_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end 

      m.user.notice "\x02\x0304LOGMOBILE:\n\x0f" + 
      "\x02  !log search <text>\x0f - Add a quote\n" +  
      "\x02  !log count <text>\x0f - Find a quote.  Use same command multiple times to cycle through search matches.\n" +
      "\x02  !ratequote <id#> <0-10>\x0f - Rate a quote."
    end

    def clear_hash
      @lastquotes.each do |k, v|
        if v[:time] >= (Time.now.getutc.to_i - 120)
          @lastquotes[k] = nil
        end
      end
    end

      
    def logsearch(m, a)
  
      if m.channel.to_s == "#testing12"
        mychan = '#newzbin'
      else
        mychan = m.channel.to_s.downcase
      end
      
      if !@config[:LOGMOBILE_DIRS].map{|x| x[:chan].downcase}.include?(mychan.downcase) #|| @config[:QUOTEDB_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      maxhits = 100

      myconfig = @config[:LOGMOBILE_DIRS].find{|x| x[:chan].downcase == mychan.downcase}
      mydir = myconfig[:dir]
      myformat = myconfig[:format]

      
      botlog "", m
      a.strip!
      #return unless a.length > 0
      if(!a || a.length < 3 || a =~ /^\s+$/)
        return
      end

      a = a.split(/\s+/)


      
      #lqkey = mychan + "::" + m.user.to_s;
      lqkey = mychan + "::" + a;
      if @lastquotes.key?(lqkey) 
        @lastquotes[lqkey][:offset] += 1
        @lastquotes[lqkey][:time] = Time.now.getutc.to_i
      else
        @lastquotes[lqkey] = Hash.new
        #@lastquotes[lqkey][:quote] = a
        @lastquotes[lqkey][:offset] = 0
        @lastquotes[lqkey][:time] = Time.now.getutc.to_i
      end

      botlog @lastquotes[lqkey][:offset].to_s, m
      #botlog @lastquotes.key(lqkey) && @lastquotes[lqkey][:quote] == a && @lastquote[lqkey][:time] >= (Time.now.getutc.to_i - 60)), m


      myfiles = []
      Dir.foreach(mydir) do |filename|
        next if filename == '.' || filename == '..' || File.directory?(filename) || filename.gsub(/\d/, '::digit::') != myformat.gsub(/[YMD]/, '::digit::')
        mydate = Date.parse(filename[myformat.index("YYYY"), 4] + '-' + filename[myformat.index("MM"), 2] + '-' + filename[myformat.index("DD"), 2]) rescue nil
        next if !mydate

        myfiles.push({:filename => filename, :date => mydate})
      end


      myfiles = myfiles.sort_by{ |p| p[:filename][myformat.index("YYYY"), 4] + '-' + p[:filename][myformat.index("MM"), 2] + '-' + p[:filename][myformat.index("DD"), 2] }.reverse
      puts myfiles

      myfiles.each do |file|
        ##File.readlines(file[:filename]).each do |line|

        #end
      end

      

      
=begin




      a.gsub!(/\s/, ' ')
      a.gsub!(/\s\s/, ' ') while a =~ /\s\s/
      words = a.split(" ")
      
      quotes = @config[:DB][:quotes].where(Sequel.ilike(:channel, mychan))
      words.each do |word|
        quotes = quotes.where(Sequel.ilike(:quote, '%'+quotes.escape_like(word)+'%'))
      end     
      
      if a =~ /^\d+$/
        #quotes = quotes.or{Sequel.&({id: a}, {channel: mychan})}
        quotes = quotes.or{Sequel.&({id: a}, Sequel.ilike(:channel, mychan))}
      end
      
      rc = quotes.count
      
      if rc && rc > 0      
        scores = @config[:DB][:quote_scr].group_and_count(:id___idx).select_append{avg(:score).as(:score)} 
        result = quotes.order(Sequel.desc(:timestamp)).limit(1, @lastquotes[lqkey][:offset]).left_join(Sequel.as(scores, :scr), :idx => :id).select_all(:quotes).select_append(Sequel.as(Sequel.function(:coalesce,:scr__score,0), :score), Sequel.as(Sequel.function(:coalesce, :scr__count,0), :count)).first   
        if result
          m.reply "\x0304[#{@lastquotes[lqkey][:offset] + 1} of #{rc}] \x0f\x0303[#{result[:id]} / #{result[:score].to_f.round(2)} (#{result[:count]} votes) / #{result[:nick]} @ #{Time.at(result[:timestamp].to_i).strftime("%-d %b %Y")}]\x0f #{result[:quote]}"
        else
          m.reply "No additional matches."
          @lastquotes[lqkey][:offset] = -1
        end
      else
        m.reply "No matches."
        @lastquotes[lqkey][:offset] = -1
      end
=end       
    end

    
    

  end
end
