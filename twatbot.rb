# TWATBOT (c) 2016 moeSizlak

# Requires {{{
require 'cinch'
require 'sequel'
require 'logger'
# }}}

class MyBot < Cinch::Bot
  @botconfig
  attr_accessor :botconfig
end


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

class Module
  def all_the_modules
    [self] + constants.map {|const| const_get(const) }
    .select {|const| const.is_a? Module }
    .flat_map {|const| const.all_the_modules }
  end
end

def config_server(x)
  Kernel.const_get("MyApp::Config::#{x}").config
end

def botlog(msg, m = nil)
  logmsg = "[#{caller_locations(1,1)[0].base_label}] "
  
  if m
    logmsg << "{#{m.bot.botconfig[:NAME]}} [#{m.user} @ #{m.channel}] [MSG = '#{m.message}'] "
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
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

config = Hash[MyApp::Config.all_the_modules.select{|x| x.to_s =~ /^MyApp::Config::[a-zA-Z]((?!::).)*$/}.collect{ |x| [x.to_s.gsub(/^MyApp::Config::/,""), config_server(x.to_s.gsub(/^MyApp::Config::/,"")).merge({:NAME => x.to_s.gsub(/^MyApp::Config::/,"")})]}]

config.values.each_with_index do |server_config, i|

  server_config[:DB] = Sequel.connect(server_config[:TWATBOT_SQL], :loggers => [Logger.new($stdout)])

  server_config[:THREAD] = Thread.new(i) do |x|
    config.values[x][:BOT] = MyBot.new do
      @botconfig = config.values[x]

      configure do |c|
        c.server = @botconfig[:IRC_SERVER]
        c.port = @botconfig[:IRC_PORT]
        c.channels = @botconfig[:IRC_CHANNELS]
        c.user = @botconfig[:IRC_USER]
        c.password = @botconfig[:IRC_PASSWORD]
        c.ssl.use = @botconfig[:IRC_SSL]
        c.nick = @botconfig[:IRC_NICK]
        c.plugins.plugins = class_from_string_array(@botconfig[:IRC_PLUGINS])
      end    
      
      on :kick do |m|
        if User(m.params[1]) == bot.nick
          botlog "#{m.params[1]}: auto_rejoin(#{m.channel.name}, #{m.channel.key})", m
          Timer 300, {:shots => 1} { bot.join(m.channel.name, m.channel.key) }
        end
      end  


      on :connect do |m|
        (bot.botconfig[:IRC_RUN_AFTER_CONNECT] || []).each{ |s| self.instance_eval(&s) }
      end


      #on :connect do |m|
      #  Timer 5, {} do 
      #    bot.channel_list.find_ensured('#testing12').send("TIMER")
      #    this.stop
      #  end
      #end

    end

    puts "Started twatbot on server #{config.values[x][:NAME]}...\n"
    config.values[x][:BOT].loggers.level = config.values[x][:IRC_LOGLEVEL] || :info
    config.values[x][:BOT].start
  end



  if server_config[:DICKBOT_ENABLE] == 1
    server_config[:DICKBOTTHREAD] = Thread.new(i) do |x|
      config.values[x][:DICKBOT] = MyBot.new do
        @botconfig = config.values[x]

        configure do |c|
          c.server = @botconfig[:DICKBOT_IRC_SERVER]
          c.port = @botconfig[:DICKBOT_IRC_PORT]
          c.channels = @botconfig[:DICKBOT_IRC_CHANNELS]
          c.user = @botconfig[:DICKBOT_IRC_USER]
          c.password = @botconfig[:DICKBOT_IRC_PASSWORD]
          c.ssl.use = @botconfig[:DICKBOT_IRC_SSL]
          c.nick = @botconfig[:DICKBOT_IRC_NICK]
          c.plugins.plugins = class_from_string_array(@botconfig[:DICKBOT_IRC_PLUGINS])
        end  
        
        on :kick do |m|
          if User(m.params[1]) ==  bot.nick
            botlog "#{m.params[1]}: auto_rejoin(#{m.channel.name}, #{m.channel.key})", m
            Timer 300, {:shots => 1} {  bot.join(m.channel.name, m.channel.key) }
          end
        end

        on :connect do |m|
          (bot.botconfig[:DICKBOT_IRC_RUN_AFTER_CONNECT] || []).each{ |s| self.instance_eval(&s) }
        end

      end
      
      puts "Started dickbot on server #{config.values[x][:NAME]}...\n"
      config.values[x][:DICKBOT].loggers.level = config.values[x][:DICKBOT_IRC_LOGLEVEL] || :info
      config.values[x][:DICKBOT].start
    end
  end

end


config.each do |servername, server|
  server[:THREAD].join
  server[:DICKBOTTHREAD].join if server[:DICKBOT_ENABLE] == 1
end


