require 'cgi'
require 'unirest'
require 'time'
require 'thread'

module Plugins
  class Election
    include Cinch::Plugin
    set :react_on, :message
    
    match /^!(?:election|trump|clinton|cunt|president)/, use_prefix: false, method: :get_chart
        
    def get_chart(m)
      botlog "", m
      chart = nil
      
      url = "http://elections.huffingtonpost.com/pollster/api/charts/2016-general-election-trump-vs-clinton.json"
      chart = Unirest::get(url)
        
      if chart.body && chart.body.key?("estimates")
        if chart.body["estimates"].size>0
          clinton = chart.body["estimates"].select { |e| e.fetch("choice", "") == "Clinton" && e.fetch("value", nil)}
          trump   = chart.body["estimates"].select { |e| e.fetch("choice", "") == "Trump" && e.fetch("value", nil) }
          other   = chart.body["estimates"].select { |e| e.fetch("choice", "") == "Other" && e.fetch("value", nil) }
          
          if(clinton && clinton.size > 0)
            clinton = clinton[0]["value"]
          else
            clinton = "?"
          end
          
          if(trump && trump.size > 0)
            trump = trump[0]["value"]
          else
            trump = "?"
          end
          
          if(other && other.size > 0)
            other = other[0]["value"]
          else
            other = "?"
          end
        
          now = Date.today
          electionDate = Date.parse("2016-11-08")
          daysLeft = electionDate - now
          
          color_pipe = "01"     
          color_name = "04"
          color_title = "03"
          color_colons = "12"
          color_text = "07"
             
          myreply = ""
          myreply << "\x03".b + color_name + "2016 Election" + "\x0f".b
          myreply << " | " + "\x03".b + "Hillary" + "\x0f".b + ": " +"\x03".b + color_text + clinton + "\x0f".b
          myreply << " | " + "\x03".b + "Trump"   + "\x0f".b + ": " +"\x03".b + color_text + trump   + "\x0f".b
          myreply << " | " + "\x03".b + "Other"   + "\x0f".b + ": " +"\x03".b + color_text + other   + "\x0f".b
          myreply << " | " + "\x03".b + "Days Left"   + "\x0f".b + ": " +"\x03".b + color_text + "#{daysLeft.to_i}"   + "\x0f".b

          m.reply myreply
          
        end       
      end      
    end
  end
end
    