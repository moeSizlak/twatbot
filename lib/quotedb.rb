require 'mysql2'

LIKE_METACHARACTER_REGEX = /([\\%_])/
LIKE_METACHARACTER_ESCAPE = '\\\\\1'
def like_sanitize(value)
  raise ArgumentError unless value.respond_to?(:gsub)
  value.gsub(LIKE_METACHARACTER_REGEX, LIKE_METACHARACTER_ESCAPE)
end


module Plugins  
  class QuoteDB
    include Cinch::Plugin
    set :react_on, :message
    
    #set :react_on, :channel 
    #timer 0,  {:method => :randquote, :shots => 1}
    timer 21600, {:method => :randquote}

    
    match /^!ratequote\s+(\S.*)$/, use_prefix: false, method: :ratequote
    match /^!addquote\s+(\S.*)$/, use_prefix: false, method: :addquote
    match /^!(?:find|search)?quote\s+(\S.*)$/, use_prefix: false, method: :quote
    
    def initialize(*args)
      super
      @lastquotes = Hash.new
    end
    
    def randquote
      return if MyApp::Config::QUOTEDB_ENABLE_RANDQUOTE == 0
      
      MyApp::Config::QUOTEDB_CHANS.each do |chan|
        con =  Mysql2::Client.new(:host => MyApp::Config::QUOTEDB_SQL_SERVER, :username => MyApp::Config::QUOTEDB_SQL_USER, :password => MyApp::Config::QUOTEDB_SQL_PASSWORD, :database => MyApp::Config::QUOTEDB_SQL_DATABASE)
        con.query("SET NAMES utf8")
        result = con.query("select id from quotes where channel = '#{con.escape(chan)}' order by RAND()")
        
        if result && result.count > 0   
        
          prng = Random.new 
          random = prng.rand(result.count)
          myid = -1;
          result.each do |r|
            if random == 0
              myid = r['id']
              break
            end
            random -= 1
          end
          
          result = con.query("select a.*, b.score, b.count from quotes a left join (select id, AVG(score) as score, count(*) as count from quote_scr group by id ) b on a.id=b.id where a.id='#{myid}'")
          con.close if con
          
          if result && result.count > 0
            Channel(chan).send "\x03".b + "04" + "[RANDOM_QUOTE] " + "\x0f".b + "\x03".b + "03" + "[#{result.first['id']} / #{result.first['score'] ? result.first['score'].to_f.round(2).to_s + " (#{result.first['count']} votes)" : '(0 votes)'} / #{result.first['nick']} @ #{Time.at(result.first['timestamp'].to_i).strftime("%-d %b %Y")}]" + "\x0f".b + " #{result.first['quote']}"
          else
            info "WTF!!!! No quotes available for timed interval randquote in chan #{chan}, but there should be."
          end
        end  
        
      end    
    end
    
    def ratequote(m, a)
    
      if !MyApp::Config::QUOTEDB_CHANS.include?(m.channel.to_s) || MyApp::Config::QUOTEDB_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end    
    
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"
      a.strip!
      
      if a =~ /^(\d+)\s+(\d+)$/
        id = $1
        score = $2.to_i
        
        if score >=0 && score <= 10
          con =  Mysql2::Client.new(:host => MyApp::Config::QUOTEDB_SQL_SERVER, :username => MyApp::Config::QUOTEDB_SQL_USER, :password => MyApp::Config::QUOTEDB_SQL_PASSWORD, :database => MyApp::Config::QUOTEDB_SQL_DATABASE)
          con.query("SET NAMES utf8")
          result = con.query("select count(*) as count from quotes where channel = '#{con.escape(m.channel.to_s)}' and id='#{con.escape(id)}'")
          
          if result && result.first && result.first['count'].to_i > 0
            
            result = con.query("select count(*) as count from quote_scr where id='#{con.escape(id)}' and handle='#{con.escape(m.user.to_s)}'")
            score_updated = 0
            if result && result.first && result.first['count'].to_i != 0
              score_updated = 1
              con.query("delete from quote_scr where id='#{con.escape(id)}' and handle='#{con.escape(m.user.to_s)}'")
            end
            
            con.query("insert into quote_scr (handle, id, score) values ('#{con.escape(m.user.to_s)}', '#{con.escape(id)}', '#{score}')")
            result = con.query("select count(*) as count, AVG(score) as score from quote_scr where id='#{con.escape(id)}' group by id")
            
            if result && result.first
              m.reply "#{score_updated == 1 ? "Your rating has been changed to #{score}.  " : "" }New score for quote #{id} is #{result.first['score'].to_f.round(2)}, based on #{result.first['count']} ratings."
            end
            
          else
            m.reply "No such quote id (#{id})"
          end
          
        else
          m.reply "Score must be an integer from 0 to 10."
        end
      
      else
        m.reply "Usage: !ratequote <quote_id> <0,1,2,3,4,5,6,7,8,9,10>"      
      end
      
      con.close if con
      
    end
    
    
    def quote(m, a)
    
      if !MyApp::Config::QUOTEDB_CHANS.include?(m.channel.to_s) || MyApp::Config::QUOTEDB_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end
      
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"
      a.strip!
      return unless a.length > 0
      
      lqkey = m.channel.to_s + "::" + m.user.to_s;
      if(@lastquotes.key?(lqkey) && @lastquotes[lqkey][:quote] == a && @lastquotes[lqkey][:time] >= (Time.now.getutc.to_i - 60))
        @lastquotes[lqkey][:offset] += 1
        @lastquotes[lqkey][:time] = Time.now.getutc.to_i
      else
        @lastquotes[lqkey] = Hash.new
        @lastquotes[lqkey][:quote] = a
        @lastquotes[lqkey][:offset] = 0
        @lastquotes[lqkey][:time] = Time.now.getutc.to_i
      end

      info @lastquotes[lqkey][:offset].to_s
      #info @lastquotes.key(lqkey) && @lastquotes[lqkey][:quote] == a && @lastquote[lqkey][:time] >= (Time.now.getutc.to_i - 60))

      con =  Mysql2::Client.new(:host => MyApp::Config::QUOTEDB_SQL_SERVER, :username => MyApp::Config::QUOTEDB_SQL_USER, :password => MyApp::Config::QUOTEDB_SQL_PASSWORD, :database => MyApp::Config::QUOTEDB_SQL_DATABASE)
      con.query("SET NAMES utf8")
      idclause = "  "
      if a =~ /^\d+$/
        idclause = " or a.id='#{a}' "
      end
      
      a.gsub!(/\s/, ' ')
      a.gsub!(/\s\s/, ' ') while a =~ /\s\s/
      words = a.split(" ")
      
      q = "select a.*, b.score, b.count from quotes a left join (select id, AVG(score) as score, count(*) as count from quote_scr group by id ) b on a.id=b.id where channel = '#{con.escape(m.channel.to_s)}' "
      words.each do |word|
        q += " and quote LIKE '%#{con.escape(like_sanitize(word))}%' "
      end
      q += " #{idclause} order by timestamp desc limit 1 offset #{@lastquotes[lqkey][:offset]}"
      
      result = con.query(q)     
      con.close if con
      
      if result && result.count > 0
        m.reply "\x03".b + "04" + "[Q] " + "\x0f".b + "\x03".b + "03" + "[#{result.first['id']} / #{result.first['score'] ? result.first['score'].to_f.round(2).to_s + " (#{result.first['count']} votes)" : '(0 votes)'} / #{result.first['nick']} @ #{Time.at(result.first['timestamp'].to_i).strftime("%-d %b %Y")}]" + "\x0f".b + " #{result.first['quote']}"
      else
        m.reply "No #{@lastquotes[lqkey][:offset] != 0 ? "additional " : ""}matches."
        @lastquotes[lqkey][:offset] = -1
      end
      
    
    end
    
    
    def addquote(m, a)
    
      if !MyApp::Config::QUOTEDB_CHANS.include?(m.channel.to_s) || MyApp::Config::QUOTEDB_EXCLUDE_USERS.include?(m.user.to_s)
        return
      end
      
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"       
      a.strip!
      
      begin
        con =  Mysql2::Client.new(:host => MyApp::Config::QUOTEDB_SQL_SERVER, :username => MyApp::Config::QUOTEDB_SQL_USER, :password => MyApp::Config::QUOTEDB_SQL_PASSWORD, :database => MyApp::Config::QUOTEDB_SQL_DATABASE)
        con.query("SET NAMES utf8")
        con.query("INSERT INTO quotes(nick, host, quote, channel, timestamp) VALUES ('#{con.escape(m.user.to_s)}', '#{con.escape(m.user.mask.to_s)}', '#{con.escape(a)}', '#{con.escape(m.channel.to_s)}', '#{con.escape(m.time.to_i.to_s)}')")
        id = con.last_id
        
        rescue Mysql2::Error => e
        puts e.errno
        puts e.error
        info "[DEBUG] [QUOTEDB] [" + m.user.to_s + "] [" + m.channel.to_s + "] [" + m.time.to_s + "]" + e.errno.to_s + " " + e.error
        
        ensure
        con.close if con
      end
      
      m.reply "Added quote (id = #{id})."
      
    end

  end
end