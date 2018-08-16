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
    set :react_on, :private
    
    match /^op$/, use_prefix: false, method: :op
    match lambda {|m| /^#{m.bot.botconfig[:OP_PASSWORD]}\s+op\s+(#[^\s]+)\s*$/im}, use_prefix: false, method: :op

    def initialize(*args)
      super
      @config = bot.botconfig  
    end


 
    def op(m, chan)
      Channel(chan).op(m.user)
      m.reply('hi')
    end
   
  end
end
