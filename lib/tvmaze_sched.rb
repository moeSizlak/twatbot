require 'cgi'
require 'unirest'
require 'time'
require 'sequel'
require 'nokogiri'
require 'open-uri'
require 'tzinfo'
require 'thread'



module Plugins
  class TvMazeSchedule
    include Cinch::Plugin

    @@updatetv_mutex = Mutex.new
    @@tv_schedule = nil

    set :react_on, :message

    timer 5,  {:method => :updatetv, :shots => 1}
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!all\s*$/, use_prefix: false, method: :nall
    match /^!(today|tonight)\s*$/, use_prefix: false, method: :today
    match /^!tomorrow\s*$/, use_prefix: false, method: :tomorrow
    match /^!yesterday\s*$/, use_prefix: false, method: :yesterday
    match /^!(sun|mon|tue|wed|thurs|fri|sat|sunday|monday|tuesday|wednesday|thursday|friday|saturday)\s*$/i, use_prefix: false, method: :tvday


    def initialize(*args)
      super
      @IMDBCacheEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:imdb_cache_entries]))
      @IMDBCacheEntry.unrestrict_primary_key

      @EpisodeEntry = Class.new(Sequel::Model(bot.botconfig[:DB][:episodes]))
      @EpisodeEntry.unrestrict_primary_key

      @config = bot.botconfig
    end


    def help(m)
      #if m.bot.botconfig[:TVMAZESCHED_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase)
      #  return
      #end

      m.user.notice "\x02".b + "\x03".b + "04" + "TV SCHEDULE:\n" + "\x0f".b + 
      "\x02".b + "  !all" + "\x0f".b + " - Show yesterday, today, and tomorrow's TV schedule\n" +
      "\x02".b + "  !today" + "\x0f".b + " - Show today's TV schedule\n" +
      "\x02".b + "  !tomorrow" + "\x0f".b + " - Show tomorrow's TV schedule\n" +
      "\x02".b + "  !yesterday" + "\x0f".b + " - Show yesterday's TV schedule\n" +
      "\x02".b + "  !sunday, !sun, !monday, !mon, etc...." + "\x0f".b + " - Show TV schedule for next <day>\n" 
    end

    def date_of_next(day)
      date  = Date.parse(day)
      delta = date > Date.today ? 0 : 7
      (date + delta).to_datetime
    end


    def updatetv
      if @@updatetv_mutex.try_lock

        Timer 1800, {:shots => 1} do
            updatetv
        end

        begin
          sleep 4
          last_tv_sched_update = @config[:DB][:bot_config].select(:last_tv_sched_update).limit(1).all[0][:last_tv_sched_update]
          last_tv_update_minutes_ago = ((Time.now - last_tv_sched_update)/60).to_i if !last_tv_sched_update.nil?
          puts "last_tv_update_minutes_ago = #{last_tv_update_minutes_ago}"
          if last_tv_sched_update.nil? || last_tv_update_minutes_ago >= 480
            @@tv_schedule = Unirest::get("http://api.tvmaze.com/schedule/full")
            if @@tv_schedule.body && @@tv_schedule.body.size>0
              myshows = @config[:DB][:imdb_cache_entries].distinct(:tv_maze_id).select(:tv_maze_id).all.map{|x| x[:tv_maze_id]}
              if myshows && myshows.count > 0
                @@tv_schedule.body.each do |ep|
                  if myshows.include?(ep["_embedded"]["show"]["id"])
                    s = @EpisodeEntry[ep["id"]]
                    s = @EpisodeEntry.new if !s
                    s.ep_id = ep["id"]
                    s.show_id = ep["_embedded"]["show"]["id"]
                    s.airstamp = ep["airstamp"]
                    s.season = ep["season"]
                    s.episode = ep["number"]
                    s.save
                  end
                end
              end
            end
          end

        rescue
          raise
        end
        
      else
        puts "[INFO] updatetv failed to acquire mutex.\n"
      end
    end

    def sched_today
      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)      
      today     = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where{(airstamp >= DateTime.parse((DateTime.now + 0).strftime("%Y-%m-%dT00:00:00%z"))) & (airstamp < DateTime.parse((DateTime.now + 1).strftime("%Y-%m-%dT00:00:00%z")))}.order(:name, :season, :episode).all
      return  "\x02".b + "\x03".b + "11" + "Today: "     + "\x0f".b +  today.map    {|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + sprintf("%02d", a[:episode].to_s) rescue nil}"}.join(" | ")
    end

    def sched_tomorrow
      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)
      tomorrow  = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where{(airstamp >= DateTime.parse((DateTime.now + 1).strftime("%Y-%m-%dT00:00:00%z"))) & (airstamp < DateTime.parse((DateTime.now + 2).strftime("%Y-%m-%dT00:00:00%z")))}.order(:name, :season, :episode).all
      return "\x02".b + "\x03".b + "09" + "Tomorrow: "  + "\x0f".b +  tomorrow.map {|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + sprintf("%02d", a[:episode].to_s) rescue nil}"}.join(" | ")
    end

    def sched_yesterday
      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)
      yesterday = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where{(airstamp >= DateTime.parse((DateTime.now - 1).strftime("%Y-%m-%dT00:00:00%z"))) & (airstamp < DateTime.parse((DateTime.now + 0).strftime("%Y-%m-%dT00:00:00%z")))}.order(:name, :season, :episode).all
      return "\x02".b + "\x03".b + "04" + "Yesterday: " + "\x0f".b +  yesterday.map{|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + sprintf("%02d", a[:episode].to_s) rescue nil}"}.join(" | ")
    end

    def nall(m)  
      m.user.notice sched_today
      m.user.notice sched_tomorrow
      m.user.notice sched_yesterday
    end

    def today(m)
      m.user.notice sched_today
    end

    def tomorrow(m)
      m.user.notice sched_tomorrow
    end

    def yesterday(m)
      m.user.notice sched_yesterday
    end

    def tvday(m,day)
      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)
      d = date_of_next(day)
      now = DateTime.now
      tvday = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where{(airstamp >= DateTime.parse((d + 0).strftime("%Y-%m-%dT00:00:00") + DateTime.now.strftime("%z"))) & (airstamp < DateTime.parse((d + 1).strftime("%Y-%m-%dT00:00:00") + DateTime.now.strftime("%z")))}.order(:name, :season, :episode).all
      puts tvday.count.to_s
      m.user.notice "\x02".b + "\x03".b + "04" + d.strftime('%A, %B %-d') + ": " + "\x0f".b +  tvday.map{|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + sprintf("%02d", a[:episode].to_s) rescue nil}"}.join(" | ")
    end


    
  end
end