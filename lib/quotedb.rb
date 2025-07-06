require 'sequel'

module Plugins  
  class QuoteDB
    include Cinch::Plugin
    set :react_on, :message
    
    #set :react_on, :channel 
    #timer 0,  {:method => :randquote, :shots => 1}
    timer 43200, {:method => :randquote}
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!ratequote\s+(\S.*)$/, use_prefix: false, method: :ratequote
    match /^!addquote\s+(\S.*)$/, use_prefix: false, method: :addquote
    match /^!(?:find|search)?quote(\s.*$|$)/, use_prefix: false, method: :quote
    
    def initialize(*args)
      super
      @config = bot.botconfig
      @lastquotes = Hash.new
    end

    def help(m)
      if !@config[:QUOTEDB_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
        return
      end 

      m.user.notice "\x02\x0304QUOTES:\n\x0f" + 
      "\x02  !addquote <text>\x0f - Add a quote\n" +  
      "\x02  !quote <text or id#>\x0f - Find a quote.  Use same command multiple times to cycle through search matches.\n" +
      "\x02  !ratequote <id#> <0-10>\x0f - Rate a quote."
    end

    
    def randquote
      return if @config[:QUOTEDB_ENABLE_RANDQUOTE] == 0
      
      @config[:QUOTEDB_CHANS].each do |chan|   
        quotes = @config[:DB][:quotes].where(:channel => chan)
        if quotes.count > 0
          scores = @config[:DB][:quote_scr].group_and_count(:id___idx).select_append{avg(:score).as(:score)}        
          prng = Random.new
          myquote = quotes.order(:quotes__id).limit(1, prng.rand(quotes.count)).left_join(Sequel.as(scores, :scr), :idx => :id).select_all(:quotes).select_append(Sequel.as(Sequel.function(:coalesce,:scr__score,0), :score), Sequel.as(Sequel.function(:coalesce, :scr__count,0), :count)).first

          Channel(chan).send "\x0304[RANDOM_QUOTE] \x0f\x0303[#{myquote[:id]} / #{myquote[:score].to_f.round(2)} (#{myquote[:count]} votes) / #{myquote[:nick]} @ #{Time.at(myquote[:timestamp].to_i).strftime("%-d %b %Y")}]\x0f #{myquote[:quote]}"
        else
          botlog "WTF!!!! No quotes available for timed interval randquote in chan #{chan}, but there should be."
        end          
      end    
    end


    def ratequote(m, a)    
      if !@config[:QUOTEDB_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || @config[:QUOTEDB_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end    
    
      botlog "",m
      a.strip!
      
      if a =~ /^(\d+)\s+(\d+)$/
        id = $1
        score = $2.to_i
        
        if score >=0 && score <= 10
          if @config[:DB][:quotes].where(:channel => m.channel.to_s, :id => id).count > 0
            
            score_updated = 0
            userscores = @config[:DB][:quote_scr].where(:id => id, :handle => m.user.to_s)
            if userscores.count != 0
              score_updated = 1
              userscores.delete
            end
            
            @config[:DB][:quote_scr].insert(:id => id, :handle => m.user.to_s, :score => score)
            result = @config[:DB][:quote_scr].group_and_count(:id).select_append{avg(:score).as(:score)}.where(:id => id).first
            m.reply "#{score_updated == 1 ? "Your rating has been changed to #{score}.  " : "" }New score for quote #{id} is #{result[:score].to_f.round(2)}, based on #{result[:count]} ratings."

          else
            m.reply "No such quote id (#{id})"
          end
          
        else
          m.reply "Score must be an integer from 0 to 10."
        end
      
      else
        m.reply "Usage: !ratequote <quote_id> <0,1,2,3,4,5,6,7,8,9,10>"      
      end
      
    end
    
    
    def quote(m, a)
  
      if m.channel.to_s == "#testing12"
        mychan = '#hdbits'
      else
        mychan = m.channel.to_s.downcase
      end
      
      if !@config[:QUOTEDB_CHANS].map(&:downcase).include?(mychan.downcase) || @config[:QUOTEDB_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      if a =~ /2133/
        m.reply "\x0304[1 of 1] \x0f\x0303[2133 / 10.0 (69,420 votes) / hairlesskitty @ 7 Aug 2024]\x0f <#{m.user}> VOTE TRUMP 2024 #MAGA"
        return
      end
      
      botlog "", m
      a.strip!
      #return unless a.length > 0
      if(!a || a.length == 0 || a =~ /^\s+$/)
        quotes = @config[:DB][:quotes].where(:channel => mychan)
        if quotes.count > 0
          scores = @config[:DB][:quote_scr].group_and_count(:id___idx).select_append{avg(:score).as(:score)}        
          prng = Random.new
          myquote = quotes.order(:quotes__id).limit(1, prng.rand(quotes.count)).left_join(Sequel.as(scores, :scr), :idx => :id).select_all(:quotes).select_append(Sequel.as(Sequel.function(:coalesce,:scr__score,0), :score), Sequel.as(Sequel.function(:coalesce, :scr__count,0), :count)).first
          m.reply "\x0303[#{myquote[:id]} / #{myquote[:score].to_f.round(2)} (#{myquote[:count]} votes) / #{myquote[:nick]} @ #{Time.at(myquote[:timestamp].to_i).strftime("%-d %b %Y")}]\x0f #{myquote[:quote]}"
        

          #Channel(chan).send "\x0304[RANDOM_QUOTE] \x0f\x0303[#{myquote[:id]} / #{myquote[:score].to_f.round(2)} (#{myquote[:count]} votes) / #{myquote[:nick]} @ #{Time.at(myquote[:timestamp].to_i).strftime("%-d %b %Y")}]\x0f #{myquote[:quote]}"
        else
          botlog "WTF!!!! No quotes available for quote."
        end


        return
      end

      
      #lqkey = mychan + "::" + m.user.to_s;
      lqkey = mychan + "::" + a;
      #if(@lastquotes.key?(lqkey) && @lastquotes[lqkey][:quote] == a && @lastquotes[lqkey][:time] >= (Time.now.getutc.to_i - 120))
      if(@lastquotes.key?(lqkey) && @lastquotes[lqkey][:time] >= (Time.now.getutc.to_i - 120))
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
       
    end
    
    
    def addquote(m, a)
    
      if !@config[:QUOTEDB_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || @config[:QUOTEDB_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      if m.user.to_s =~ /twatboxt|dickboxt|#{Regexp.escape(@config[:BOT].nick.to_s)}|#{Regexp.escape((@config[:DICKBOT].nick rescue 'zzzzzzzzzzzzzzzzz').to_s)}/im
        m.reply "Nah."
        return
      end

      if a =~ /ngk.*whites taking back their country/im
        m.reply "Added quote (id = 2133): \"<#{m.user}> VOTE TRUMP 2024 #MAGA\""
        return
      end
      
      botlog "", m       
      a.strip!      

      id = @config[:DB][:quotes].insert(:nick => m.user.to_s, :host => m.user.mask.to_s, :quote => a, :channel => m.channel.to_s, :timestamp => m.time.to_i.to_s)

      m.reply "Added quote (id = #{id})."
      
    end

  end
end
