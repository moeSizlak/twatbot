require 'cgi'
require 'unirest'
require 'time'
require 'sequel'
require 'nokogiri'
require 'open-uri'
require 'tzinfo'


module Plugins
  class Op
    include Cinch::Plugin

    listen_to :join, method: :on_join
    #set :react_on, [:private, :message]
    set :react_on, :private
    #set :react_on, :message

    #spambot killers:
    match /(\u0041|\u13aa|\u0391|\u0410)(\u0054|\u03a4|\u0422|\u13a2){2}(\u2c9a|\u039d|\u004e)(\u003a|\u02f8|\u16ec|\ufe55|\uff1a|\u2806)|(\u13aa|\u0391|\u0410)(\u03a4|\u0422|\u13a2){2}(\u2c9a|\u039d)/, use_prefix: false, method: :kickass, react_on: :message
    match /^(?=.*[^ -~\r\n])[^[:space:]]{3}[[:space:]][^[:space:]]{5}[[:space:]][^[:space:]]{4}[[:space:]][^[:space:]]{7}[[:space:]][^[:space:]]{3}[[:space:]][^[:space:]]{5}/, use_prefix: false, method: :kickass, react_on: :message
    match /.*https?:\/\/williampitcock\.com/, use_prefix: false, method: :kickass, react_on: :message
    match /^THIS CHANNEL.*COVID/, use_prefix: false, method: :kickass, react_on: :message
    match /^[.!]op\s+(.*)$/i, use_prefix: false, method: :opjoke1
    match /^[.!]opme\s*$/i, use_prefix: false, method: :opjoke2


    match lambda {|m| /^#{m.bot.botconfig[:OP_PASSWORD]}\s+op\s+(#[^\s]+)\s*$/im}, use_prefix: false, method: :op
    
    
    match /^ppppp$/, use_prefix: false, method: :test123, react_on: :message


    def initialize(*args)
      super
      @config = bot.botconfig  
      
      @auto_ops = [] 
      @config[:DB][:auto_ops].where(:server =>  @config[:NAME]).each do |row|
        @auto_ops << {:chan => row[:channel], :mask => Cinch::Mask.from(row[:mask])}
      end      

    end

    def opjoke1(m, x)
      m.action_reply("sets mode +faggot #{x}")
    end

    def opjoke2(m)
      m.action_reply("sets mode +faggot #{m.user}")
    end


 
    def op(m, chan)
      Channel(chan).op(m.user)
      #m.reply('hi')
    end

    def kickass(m)
      puts "KILLING SPAMBOT: '#{m.channel}', '#{m.user}'"
      Channel(m.channel).kick(m.user, ["no it fucking hasn't", "sigh......", "rm -rf /", "fuck off and die", "shitbird", "cunt", "faggot", "i hope you get inoperable bowel cancer", "gtfo tbh", "suck the dick of life", "eat shit and die", "cunting shit nugget", "bloody wanker", "shitlord", "fuckface", "Cunty McCuntington", "Shitty McShitface", "Faggy McFagface", "FUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU"].sample)
    end

    def test123(m)
      puts "#{m.bot.nick}: #{m.user.data}"
      #m.reply "ok=#{Cinch::Mask.from('*!buckeye@happy.cow.org').match(m.channel.users.keys.find|x| x.to_s=='eefer'})}"
      #m.reply "ok=#{m.channel.users.keys.find{|x| x.to_s== "moeSizlak"}.mask}"

    end

    def on_join(m)

      Timer 65, {:shots => 1} do
        if m.bot.name == "dickbot"
          sleep 5
        else
          sleep 10
        end

        if m.channel.to_s.downcase == '##tv' && !m.channel.opped?(m.user.nick) && !m.channel.voiced?(m.user.nick)
          m.channel.voice(m.user.nick) 
          puts "Voicing #{m.user.name}."
        end

      end

      return unless @auto_ops.map{|x| x[:chan].downcase}.include?(m.channel.to_s.downcase)
      return unless matches?(m.channel.to_s, m.user.mask)

      if m.bot.name == "dickbot"
        sleep 120
      else
        sleep 30
      end

      return unless !m.channel.opped?(m.user.nick)
      puts "OPCHECK (#{m.bot.name}) (#{m.channel}) (#{m.user}) =>#{m.channel.opped?(m.user.nick)}"
      Channel(m.channel).op(m.user)

    end


    def matches?(chan, user)
      @auto_ops.each do |a|
        next unless a[:chan].downcase == chan.downcase && a[:mask].match(user)
        return true
      end

      false
    end





  end
end
