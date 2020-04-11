require 'pg'
#require 'sequel'

QUERYSIZE = 30000

def dbsym(msg)
  return ":::::"+msg.to_s+":::::"
end

def filter_msg(msg)
  #msg.downcase!
  msg.gsub!(/[^ -~]/, '')
  msg.gsub!(/["]/, '')
  msg.gsub!(/^'/, '')
  msg.gsub!(/'$/, '')
  msg.gsub!(/ '/, ' ')
  msg.gsub!(/' /, ' ')
  msg.gsub!(/https?:\/\/[^ ]*/, '')  
  msg.gsub!(/;/, ',') 
  msg.gsub!(/  /, ' ') while msg =~ /  /
  return msg.split(" ")
end

if !ARGV || ARGV.length < 1
  abort "ERROR: Usage: ruby #{$0} <IRC_LOG_FILE>"
  elsif !File.exist?(ARGV[0])
  abort "ERROR: File not found: #{ARGV[0]}"
end

con =  PG.connect(:host => "localhost", :user => "dbuser", :password => "dbpw", :dbname => "db")

#con.query("SET AUTOCOMMIT = OFF")


q1base = "INSERT INTO \"WORDS1\" (\"Word1\", \"Word2\", \"Nick\", \"Chan\") VALUES "
q1 = q1base 
q2base = "INSERT INTO \"WORDS2\" (\"Word1\", \"Word2\", \"Word3\", \"Nick\", \"Chan\") VALUES "
q2 = q2base 

ARGV.each do |f|
  text = File.open(f)
  puts f.to_s
        
  text.each_line do |line|
    begin
    if line =~ /^[\d:\[\]]+\s+\*\s+(\S+)\s+(.*)$/
      line = "00:00 <ACTION__#{$1}> #{$2}"
    end
  
    if line =~ /^[^<]{0,25}<[@+]*([^>]*)>\s*(.*)\s*$/
      nick = $1
      words = filter_msg($2)
      if(words && words.length > 0)
        words.unshift(dbsym("START"))
        words.push(dbsym("END")) 
             
        (0..words.length-2).each do |i|      
          q1add = "('#{con.escape_string(words[i][0..254])}','#{con.escape_string(words[i+1][0..254])}','#{con.escape_string(nick)}','#newzbin'),"
          if (q1.length+q1add.length) >= QUERYSIZE # SHOW VARIABLES LIKE 'max_allowed_packet';
            con.exec(q1.chomp(','))
            q1 = q1base + q1add
          else
            q1 += q1add
          end      
        end       
             
        (0..words.length-3).each do |i|      
          q2add = "('#{con.escape_string(words[i][0..254])}','#{con.escape_string(words[i+1][0..254])}','#{con.escape_string(words[i+2][0..254])}','#{con.escape_string(nick)}','#newzbin'),"
          if (q2.length+q2add.length) >= QUERYSIZE # SHOW VARIABLES LIKE 'max_allowed_packet';
            con.exec(q2.chomp(','))
            q2 = q2base + q2add
          else
            q2 += q2add
          end      
        end         
      end    
    end
    rescue Exception => e  
      puts e.message  
      puts e.backtrace.inspect
    end
  end
  
  text.close
end


con.exec(q1.chomp(','))  
con.exec(q2.chomp(','))  
con.exec("commit")
