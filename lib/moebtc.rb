module Plugins  
  class MoeBTC
    include Cinch::Plugin
    set :react_on, :message
    
    match /^\.moe/i, use_prefix: false
    
    def execute(m)
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"
    
      x = rand
      myreply = "\x03".b + "04" + "Bitstamp" + "\x0f".b + " | Buy: $" + sprintf("%01.2f", ((x <= 0.9) ? (rand * 10) : ((x <= 0.95) ? (rand * 50) : ((x <= 0.99) ? (rand * 100) : (rand * 1000)))))
      m.reply myreply
    end
  end  
end