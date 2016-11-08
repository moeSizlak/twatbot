require 'cgi'
require 'unirest'
require 'time'
require 'thread'
require 'net/http'

module Plugins
  class Election
    include Cinch::Plugin
    set :react_on, :message
    
    match /^!(?:election|trump|clinton|cunt|president|hillary|donald|don|thedonald|the donald|donny)/i, use_prefix: false, method: :get_result
        
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
          myreply << " | " + "\x03".b + "Hillary" + "\x0f".b + ": " +"\x03".b + color_text + clinton.to_s + "\x0f".b
          myreply << " | " + "\x03".b + "Trump"   + "\x0f".b + ": " +"\x03".b + color_text + trump.to_s   + "\x0f".b
          myreply << " | " + "\x03".b + "Other"   + "\x0f".b + ": " +"\x03".b + color_text + other.to_s   + "\x0f".b
          myreply << " | " + "\x03".b + "Days Left"   + "\x0f".b + ": " +"\x03".b + color_text + "#{daysLeft.to_i}"   + "\x0f".b

          m.reply myreply
          
        end       
      end      
    end
    
    def get_result(m)
      botlog "", m
      results = nil
      
      #require 'net/http'
      #baseurl = "http://www.politico.com/mapdata/2012/US.xml?cachebuster="
      baseurl = "http://s3.amazonaws.com/origin-east-elections.politico.com/mapdata/2016/LIVE.xml?cachebuster="
      url = URI(baseurl + Time.now.utc.strftime("%Y%m%d%H%M%S"))
      
      results = Net::HTTP.get(url)
      results = results.strip.split("\n")
      results.map! do |x|
        x = x.split("|")
        x.map! do |y|
          y = y.split(';')
        end
      end
      
      ev_clinton = results[2][0][0]
      ev_trump = results[2][0][2]
      pv_clinton = results.last.select{|x| x[1] == 'Dem'}[0][2]
      pv_trump = results.last.select{|x| x[1] == 'GOP'}[0][2]
      pv_total = 0
      results.last.drop(2).each{|x| pv_total += x[2].to_i}
      
      color_pipe = "01"     
      color_name = "04"
      color_title = "03"
      color_colons = "12"
      color_text = "07"
         
      myreply = ""
      myreply << "\x03".b + color_name + "2016 Election (#{results.last[0][6]}% Reporting)" + "\x0f".b
      myreply << " | " + "\x03".b + "Hillary" + "\x0f".b + ": " +"\x03".b + color_text + "#{ev_clinton} EV (#{pv_clinton.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} popular votes [#{((100.0 * pv_clinton.to_f)/pv_total.to_f).round(1)}%])" + "\x0f".b
      myreply << " | " + "\x03".b + "Trump"   + "\x0f".b + ": " +"\x03".b + color_text + "#{ev_trump} EV (#{pv_trump.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} popular votes [#{((100.0 * pv_trump.to_f)/pv_total.to_f).round(1)}%])" + "\x0f".b
      myreply << " | " + "\x03".b + "Other"   + "\x0f".b + ": " +"\x03".b + color_text + "0 EV (#{(pv_total.to_i - (pv_clinton.to_i + pv_trump.to_i)).to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} popular votes [#{((100.0 * (pv_total.to_i - (pv_clinton.to_i + pv_trump.to_i)).to_f)/pv_total.to_f).round(1)}%])" + "\x0f".b
      
      m.reply myreply 
  
    end
    
  end
end
    
