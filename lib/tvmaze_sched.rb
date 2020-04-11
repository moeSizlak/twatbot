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
    @@updatetv2_mutex = Mutex.new
    @@updatetv3_mutex = Mutex.new
    @@tv_schedule = nil

    set :react_on, :message

    timer 5,  {:method => :updatetv, :shots => 1}
    #timer 5,  {:method => :updatetv2, :shots => 1}
    timer 5,  {:method => :updatetv3, :shots => 1}
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!all\s*$/, use_prefix: false, method: :nall
    match /^!(today|tonight)\s*$/, use_prefix: false, method: :today
    match /^!tomorrow\s*$/, use_prefix: false, method: :tomorrow
    match /^!yesterday\s*$/, use_prefix: false, method: :yesterday
    match /^!(sun|mon|tue|wed|thurs|fri|sat|sunday|monday|tuesday|wednesday|thursday|friday|saturday)\s*$/i, use_prefix: false, method: :tvday
    match /^!prem[a-zA-Z]*(\d*)(?:\s+(\S.*(?<=\S)))?\s*$/i, use_prefix: false, method: :prem


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
      "\x02".b + "  !sunday, !sun, !monday, !mon, etc...." + "\x0f".b + " - Show TV schedule for next <day>\n" +
      "\x02".b + "  !premiers<optional max# of premiers, default 15> <optional show name or network search term>" + "\x0f".b + " - Show season premier dates\n" 
    end

    def date_of_next(day)
      date  = Date.parse(day)
      delta = date > Date.today ? 0 : 7
      (date + delta).to_datetime
    end


    def updatetv2
      if @@updatetv2_mutex.try_lock    

        begin
          sleep 4
          myshows = @IMDBCacheEntry.where(:network => nil).order(:tv_maze_id).limit(20)
          myshows.each do |myshow|
            show = Unirest::get("http://api.tvmaze.com/shows/" + myshow.tv_maze_id.to_s)
            if show.body && show.body.size>0
              network = show.body.dig("network", "name")
              network = show.body.dig("webChannel", "name") if !network
              if network
                myshow.network = network
                myshow.save
              end
            end
          end 
        rescue 
          
        end

       Timer 11, {:shots => 1} do
          updatetv2
        end
        
      else
        puts "[INFO] updatetv2 failed to acquire mutex.\n"
      end
    end




    def updatetv3
      if @@updatetv3_mutex.try_lock    

        Timer 1800, {:shots => 1} do
            updatetv3
        end

        begin
          sleep 4
          last_update = @config[:DB][:bot_config].select(:last_tvmaze_shows_update).limit(1).all[0][:last_tvmaze_shows_update]
          last_update_minutes_ago = ((Time.now - last_update)/60).to_i if !last_update.nil?
          puts "last_tv_shows_update_minutes_ago = #{last_update_minutes_ago}"
          if last_update.nil? || last_update_minutes_ago >= 720

            page = @config[:DB][:bot_config].select(:last_tvmaze_shows_page_number).limit(1).all[0][:last_tvmaze_shows_page_number]
            page = 0 if page.nil?
            shows = Unirest::get("http://api.tvmaze.com/shows?page=#{page}")

            while shows && shows.body && shows.body.size > 0
              puts "Successfully got shows page# #{page}."
              shows.body.each do |show|
                name = show.dig("name")
                status = show.dig("status")
                network = show.dig("network", "name")
                network = show.dig("webChannel", "name") if !network
                imdblink = show.dig("externals", "imdb")
                tvdblink = show.dig("externals", "thetvdb")
                puts "imdblink=#{imdblink}\ntvdblink=#{tvdblink}"

                if imdblink.nil? && !tvdblink.nil?
                  imdblink = TVDB.new(m.bot.botconfig[:TVDB_API_KEY], m.bot.botconfig[:TVDB_API_USERNAME], m.bot.botconfig[:TVDB_API_USERKEY], tvdblink.to_s).show["imdbId"] rescue nil
                  puts "imdblink(from tvdb)=#{imdblink}"
                end

                if imdblink
                  imdblink = 'http://www.imdb.com/title/' + imdblink
                end

                c = @IMDBCacheEntry[show["id"]]
                if c
                  c.name = name
                  c.status = status
                  c.network = network
                  c.imdburl = imdblink
                  c.save
                else
                  c = @IMDBCacheEntry.create(:tv_maze_id => show["id"], :imdburl => imdblink, :name => name, :status =>status, :network => network)  #, :next_episode => airstamp_next_utc, :tv_maze_last_update => Sequel::CURRENT_TIMESTAMP, :next_episode_number => ne
                end
              end
              
              @config[:DB][:bot_config].update(:last_tvmaze_shows_page_number => page)
              @config[:DB][:bot_config].update(:last_tvmaze_shows_update => Sequel::CURRENT_TIMESTAMP)
              page += 1
              puts "Trying to get shows page# #{page}."

              sleep 11
              shows = Unirest::get("http://api.tvmaze.com/shows?page=#{page}")
            end

          end          

        rescue 
          raise
        end


        
      else
        puts "[INFO] updatetv3 failed to acquire mutex.\n"
      end
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
                g = []

                @@tv_schedule.body.each do |ep|     
                  ii = g.find_index{|x| x[:show_id] == ep["_embedded"]["show"]["id"]}
                  if ii.nil?
                    g.push({:show_id=>ep["_embedded"]["show"]["id"], :next_ep=>ep["airstamp"], :eps=>[ep["id"]]})
                  else
                    g[ii][:eps].push(ep["id"])
                    if ep["airstamp"] < g[ii][:next_ep]
                      g[ii][:next_ep] = ep["airstamp"]
                    end
                  end

                  #if myshows.include?(ep["_embedded"]["show"]["id"])
                  c = @IMDBCacheEntry[ep["_embedded"]["show"]["id"]]
                  if c
                    s = @EpisodeEntry[ep["id"]]
                    s = @EpisodeEntry.new if !s
                    s.ep_id = ep["id"]
                    s.show_id = ep["_embedded"]["show"]["id"]
                    s.airstamp = ep["airstamp"]
                    s.season = ep["season"]
                    s.episode = ep["number"]
                    s.save

                    status = ep.dig("_embedded", "show", "status")
                    network = ep.dig("_embedded", "show", "network", "name")
                    network = ep.dig("_embedded", "show", "webChannel", "name") if !network
                    c.network = network
                    c.status = status
                    c.save
                  end
                end

                g.each do |show|
                  #bot.botconfig[:DB][:episodes].where(:show_id => show[:show_id]).where{airstamp >= show[:next_ep]}.exclude(:ep_id => show[:eps]).delete
                  bot.botconfig[:DB][:episodes].where(:show_id => show[:show_id]).where{airstamp >= Sequel::CURRENT_TIMESTAMP}.exclude(:ep_id => show[:eps]).delete
                end

                bot.botconfig[:DB][:episodes].where{airstamp >= Sequel::CURRENT_TIMESTAMP}.exclude(:show_id => g.map{|x| x[:show_id]}).delete



                @config[:DB][:bot_config].update(:last_tv_sched_update => Sequel::CURRENT_TIMESTAMP)
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
      return  "\x02".b + "\x03".b + "11" + "Today: "     + "\x0f".b +  today.map    {|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + (a[:episode].nil? ? 'Special' : sprintf("%02d", a[:episode].to_s)) rescue nil}"}.join(" | ")
    end

    def sched_tomorrow
      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)
      tomorrow  = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where{(airstamp >= DateTime.parse((DateTime.now + 1).strftime("%Y-%m-%dT00:00:00%z"))) & (airstamp < DateTime.parse((DateTime.now + 2).strftime("%Y-%m-%dT00:00:00%z")))}.order(:name, :season, :episode).all
      return "\x02".b + "\x03".b + "09" + "Tomorrow: "  + "\x0f".b +  tomorrow.map {|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + (a[:episode].nil? ? 'Special' : sprintf("%02d", a[:episode].to_s)) rescue nil}"}.join(" | ")
    end

    def sched_yesterday
      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)
      yesterday = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where{(airstamp >= DateTime.parse((DateTime.now - 1).strftime("%Y-%m-%dT00:00:00%z"))) & (airstamp < DateTime.parse((DateTime.now + 0).strftime("%Y-%m-%dT00:00:00%z")))}.order(:name, :season, :episode).all
      return "\x02".b + "\x03".b + "04" + "Yesterday: " + "\x0f".b +  yesterday.map{|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + (a[:episode].nil? ? 'Special' : sprintf("%02d", a[:episode].to_s)) rescue nil}"}.join(" | ")
    end

    def nall(m)  
      if ['#hdbits', '##tv', '#newzbin'].include?(m.channel.name.downcase)      
        m.reply sched_today
        m.reply sched_tomorrow
        m.reply sched_yesterday
      else
        m.user.notice sched_today
        m.user.notice sched_tomorrow
        m.user.notice sched_yesterday
      end
    end

    def today(m)
      if ['#hdbits', '##tv', '#newzbin'].include?(m.channel.name.downcase)
        m.reply sched_today
      else
        m.user.notice sched_today
      end
    end

    def tomorrow(m)
      if ['#hdbits', '##tv', '#newzbin'].include?(m.channel.name.downcase)
        m.reply sched_tomorrow
      else
        m.user.notice sched_tomorrow
      end
    end

    def yesterday(m)
      if ['#hdbits', '##tv', '#newzbin'].include?(m.channel.name.downcase)
        m.reply sched_yesterday
      else
        m.user.notice sched_yesterday
      end
    end

    def tvday(m,day)
      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)
      d = date_of_next(day)
      now = DateTime.now
      t = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where{(airstamp >= DateTime.parse((d + 0).strftime("%Y-%m-%dT00:00:00") + DateTime.now.strftime("%z"))) & (airstamp < DateTime.parse((d + 1).strftime("%Y-%m-%dT00:00:00") + DateTime.now.strftime("%z")))}.order(:name, :season, :episode).all
      puts t.count.to_s

      if ['#hdbits', '##tv', '#newzbin'].include?(m.channel.name.downcase)
        m.reply "\x02".b + "\x03".b + "04" + d.strftime('%A, %B %-d') + ": " + "\x0f".b +  t.map{|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + (a[:episode].nil? ? 'Special' : sprintf("%02d", a[:episode].to_s)) rescue nil}"}.join(" | ")
      else
        m.user.notice "\x02".b + "\x03".b + "04" + d.strftime('%A, %B %-d') + ": " + "\x0f".b +  t.map{|a| "\x02".b + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - #{a[:season].to_s + "x" + (a[:episode].nil? ? 'Special' : sprintf("%02d", a[:episode].to_s)) rescue nil}"}.join(" | ")
      end
    end

    def prem(m, x, s)
      if !x || x=="" || x !~ /^\d+$/
        x=15
      else
        x=x.to_i
      end
      #puts "search='#{s}'"

      swords = []
      if s
        s.strip!
        s.gsub!(/\s/, ' ')
        s.gsub!(/\s\s/, ' ') while s =~ /\s\s/
        swords = s.split(" ")
      end

      myshows = @config[:DB][:tv_groups].distinct(:show_id).select(:show_id)
      prems = @config[:DB][:episodes].join(:imdb_cache_entries, tv_maze_id: :show_id).where(show_id: myshows).where(episode: 1).where{(airstamp >= DateTime.parse((DateTime.now + 0).strftime("%Y-%m-%dT00:00:00%z")))}
      swords.each do |word|
        prems = prems.where(  (Sequel.ilike(:network, '%'+prems.escape_like(word)+'%')) | (Sequel.ilike(:name, '%'+prems.escape_like(word)+'%'))  )
      end 
      total = prems.count
      if total > 0
        prems = prems.order(Sequel.function(:date_trunc, 'day', :airstamp), :name).limit(x).all

        text = ""
        if total > prems.length
          text << "Showing #{x} of #{total} matches.  (Use \"!prem<max> <show/network search term>\" for a higher maximum number of results.)"
        else
          text << "Showing all #{total} matches."
        end

        if ['#hdbits', '##tv', '#newzbin'].include?(m.channel.name.downcase)
          m.user.send "\x02".b + "\x03".b + "04" + "SEASON PREMIERS: #{text}" + "\x0f".b +  "\n" + prems.map{|a| "\x02".b + a[:airstamp].localtime.strftime('%a, %b %d') + "\x0f".b + " - " + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - Season #{a[:season]}"}.join("\n")
        else
          m.user.notice "\x02".b + "\x03".b + "04" + "SEASON PREMIERS: #{text}" + "\x0f".b +  "\n" + prems.map{|a| "\x02".b + a[:airstamp].localtime.strftime('%a, %b %d') + "\x0f".b + " - " + "\x1f".b + "#{a[:name]}" + "\x0f".b + " - Season #{a[:season]}"}.join("\n")
        end
      else
        if ['#hdbits', '##tv', '#newzbin'].include?(m.channel.name.downcase)
          m.user.send "\x02".b + "\x03".b + "04" + "Nothing found." + "\x0f".b
        else
          m.user.notice "\x02".b + "\x03".b + "04" + "Nothing found." + "\x0f".b
        end
      end
    end


    
  end
end