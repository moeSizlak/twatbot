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


 
    def op(m, chan)
      Channel(chan).op(m.user)
      #m.reply('hi')
    end

    def kickass(m)
      puts "KILLING SPAMBOT: '#{m.channel}', '#{m.user}'"
      Channel(m.channel).kick(m.user, ["fuck off and die", "shitbird", "cunt", "faggot", "i hope you get inoperable bowel cancer", "gtfo tbh"].sample)
    end

    def test123(m)
      puts m.user.data
    end

    def on_join(m)
      return unless @auto_ops.map{|x| x[:chan].downcase}.include?(m.channel.to_s.downcase)
      return unless matches?(m.user.mask)
      return unless !m.channel.opped?(m.user)
      puts "OPCHECK (m.bot.name) (#{m.channel}) (#{m.user}) =>#{m.channel.opped?(m.user)}"
      Channel(m.channel).op(m.user)
      puts "OPCHECK (m.bot.name) (#{m.channel}) (#{m.user}) =>#{m.channel.opped?(m.user)}"
    end


    def matches?(user)
      @auto_ops.each do |a|
        next unless a[:mask].match(user)
        return true
      end

      false
    end





  end
end
