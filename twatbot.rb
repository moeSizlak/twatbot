# TWATBOT (c) 2016 moeSizlak

# Requires {{{
require 'cinch'
require 'sequel'
require 'logger'
# }}}

def class_from_string(str)
  str.split('::').inject(Object) do |mod, class_name|
    mod.const_get(class_name)
  end
end

def class_from_string_array(arr)
  arr.each_with_index do |str, index|
    str.split('::').inject(Object) do |mod, class_name|
      arr[index] = mod.const_get(class_name)
    end
  end
end

def botlog(msg, m = nil)
  logmsg = "[#{caller_locations(1,1)[0].base_label}] "
  
  if m
    logmsg << "[#{m.user} @ #{m.channel}] [MSG = '#{m.message}'] "
  end
  
  logmsg << "#{msg}"
  
  info logmsg
end

if !ARGV || ARGV.length != 1
  abort "ERROR: Usage: ruby #{$0} <CONFIG_FILE>"
  elsif !File.exist?(ARGV[0])
  abort "ERROR: Config file not found: #{ARGV[0]}"
  else
  require File.absolute_path(ARGV[0])
end

STDOUT.sync = true
DB = Sequel.connect(MyApp::Config::TWATBOT_SQL, :loggers => [Logger.new($stdout)])
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

a = Thread.new do
  bot = Cinch::Bot.new do
    configure do |c|
      c.server = MyApp::Config::IRC_SERVER
      c.port = MyApp::Config::IRC_PORT
      c.channels = MyApp::Config::IRC_CHANNELS
      c.user = MyApp::Config::IRC_USER
      c.password = MyApp::Config::IRC_PASSWORD
      c.ssl.use = MyApp::Config::IRC_SSL
      c.nick = MyApp::Config::IRC_NICK
      c.plugins.plugins = class_from_string_array(MyApp::Config::IRC_PLUGINS)
    end    
    
    on :kick do |m|
        if User(m.params[1]) == bot.nick
          botlog "auto_rejoin,  #{m.params[1]}", m
          Timer 300, {:shots => 1} { m.channel.join(m.channel.key) }
        end
    end
    
  end

  puts "Starting twatbot..."
  bot.loggers.level = :info
  bot.start
end

if MyApp::Config::DICKBOT_ENABLE == 1
  b = Thread.new do
    dickbot = Cinch::Bot.new do
      configure do |c|
        c.server = MyApp::Config::DICKBOT_IRC_SERVER
        c.port = MyApp::Config::DICKBOT_IRC_PORT
        c.channels = MyApp::Config::DICKBOT_IRC_CHANNELS
        c.user = MyApp::Config::DICKBOT_IRC_USER
        c.password = MyApp::Config::DICKBOT_IRC_PASSWORD
        c.ssl.use = MyApp::Config::DICKBOT_IRC_SSL
        c.nick = MyApp::Config::DICKBOT_IRC_NICK
        c.plugins.plugins = class_from_string_array(MyApp::Config::DICKBOT_IRC_PLUGINS)
      end  
      
      on :kick do |m|
        if User(m.params[1]) == dickbot.nick
          botlog "auto_rejoin,  #{m.params[1]}", m
          Timer 300, {:shots => 1} { m.channel.join(m.channel.key) }
        end
      end
      
    end
    
    puts "Starting dickbot..."
    dickbot.loggers.level = :info
    dickbot.start
  end
end

a.join
b.join if MyApp::Config::DICKBOT_ENABLE == 1
