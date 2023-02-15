

module Plugins
  class OpJoke
    include Cinch::Plugin

    #listen_to :join, method: :on_join
    #set :react_on, [:private, :message]
    #set :react_on, :private
    set :react_on, :message

    match /^[.!]op\s+(.*)$/i, use_prefix: false, method: :opjoke1
    match /^[.!]opme\s*$/i, use_prefix: false, method: :opjoke2



    def opjoke1(m, x)
      m.action_reply("sets mode +faggot #{x}")
    end

    def opjoke2(m)
      m.action_reply("sets mode +faggot #{m.user}")
    end


  end
end
