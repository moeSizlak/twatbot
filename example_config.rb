
module MyApp
  module Config
    module BOT_A

      @config = nil

      class << self
        attr_accessor :config
      end

      @config = {
        :IRC_SERVER => "server.irc.com" ,
        :IRC_PORT => 7777 ,
        :IRC_CHANNELS => ["#chan1","#test1","#etc"] ,
        :IRC_USER => "username" ,
        :IRC_PASSWORD => "password" ,
        :IRC_SSL => true ,
        :IRC_NICK => "thebot" ,
        :IRC_PLUGINS => [
          "Plugins::RSSFeed",
          "Plugins::URL",
          "Plugins::TvMaze",
          "Plugins::IMDB",
          "Plugins::URLDB",
          "Plugins::MoeBTC",
          "Plugins::Weather",
          "Plugins::Election",
          "Plugins::RottenTomatoes",
          "Plugins::QuoteDB",
          "Plugins::CloudVision",
          "Plugins::Google",
          "Plugins::Wikipedia",
          "Plugins::TvMazeSchedule",
          "Plugins::CoronaVirus",
          "Plugins::Logmobile",
          "Plugins::TwitterSearch",
          "Plugins::Wolfram",
          "Plugins::Stocks",
          "Plugins::OpenAI",
          "Plugins::TwitterFeed",
        ],
      
        :IRC_RUN_AFTER_CONNECT => [
          proc do 
            User('some_user').send('some message')
            sleep 3
            Channel('#some_chan').join
            #etc ...
          end
        ],

        :IRC_LOGLEVEL => :info ,  # :debug

        :TWATBOT_SQL => 'postgres://user:pass@localhost/twatbot?encoding=utf8' ,

        :WOLFRAM_APP_ID => 'XXXXXXXXXXXXX',
        :WOLFRAM_SEARCH_EXCLUDE_CHANS => [],


      :TWITTER_BEARER_TOKEN => "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",

      # Plugins::RSSFeed
      :TWITTER_FEEDS  => [
        {:name => "Musk", :rule => "from:elonmusk", :chans => ["#testing123"], :include_replies => false},  
        {:name => "SpaceX", :rule => "from:SpaceX", :chans => ["#testing123"], :include_replies => false},  
        {:name => "BuffaloBlizzard", :rule => "buffalo blizzard", :chans => ["#testing123"], :include_replies => false},
      ]   ,  



      :OPENAI_SECRET_KEY => "zzzzzzzzzzzzzzzzzzzzzz",
      :OPENAI_ORG => "zzzzzzzzzzzzzz",
      :OPENAI_API_RATE_LIMIT_MINUTE  => 2 ,
      :OPENAI_API_RATE_LIMIT_DAY  => 300 ,
      :OPENAI_EXCLUDE_CHANS => [] ,
      :OPENAI_EXCLUDE_USERS => [] ,
      :OPENAI_PASTEBIN_DEVKEY => "zzzzzzzzzzzzzzzzzz",
      :OPENAI_PASTEBINEE_DEVKEY => "zzzzzzzzzzzzzzzzzzzzzzzz",
      :OPENAI_PIC_RATE_LIMIT_MINUTE  => 6 ,
      :OPENAI_PIC_RATE_LIMIT_DAY  => 6 ,



        # Plugins::TwitterSearch
      :TWITTER_SEARCH_EXCLUDE_CHANS => [],
        
        # Plugins::URL
        :URL_SUB_PLUGINS => [  # each one of these will be tried in order until one of them works: ,
          {:class => "URLHandlers::Youtube",  :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::IMDB",     :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::Dumpert",  :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::Imgur",    :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::TitleBot", :excludeChans => [], :excludeNicks => []},
        ],
        

        :YOUTUBE_GOOGLE_SERVER_KEY => "YOUR_GOOGLE_SERVER_KEY_FOR_YOUTUBE_API" ,
        :IMGUR_API_CLIENT_ID => "YOUR IMGUR API CLIENT ID" ,
        :OMDB_API_KEY => "XXXXXXXXXXXXXXXXX" ,
        :COINMARKETCAP_API_KEY => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',

        :CLOUD_VISION_CHANS  => [] ,
        :CLOUD_VISION_APIKEY => "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",

        # Plugins::CloudVision
      :GOOGLE_SEARCH_EXCLUSE_CHANS  => [],
      :GOOGLE_SEARCH_ENGINE_ID => "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      :GOOGLE_SEARCH_APIKEY => "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        
        # Plugins::RottenTomatoes
        :RT_EXCLUDE_CHANS => [] ,
        :RT_EXCLUDE_USERS => ["dickbot", "dickbot_"] ,
        
        # Plugins::IMDB
        :IMDB_EXCLUDE_CHANS => [] ,
        :IMDB_EXCLUDE_USERS => ["dickbot", "dickbot_"] ,
        
        # Plugins::TvMaze
        :TVDB_API_USERNAME => 'fake' ,
        :TVDB_API_USERKEY => '0123456789ABCDEF' ,
        :TVDB_API_KEY => '0123456789ABCDEF' ,
        :TVMAZE_EXCLUDE_CHANS => [] ,
        :TVMAZE_EXCLUDE_USERS => ["dickbot", "dickbot_"] ,
        
        # Plugins::RSSFeed
        :RSS_FEEDS => [
          {:name => "TorrentFreak", :url => "http://feeds.feedburner.com/Torrentfreak", :chans => ["#test1"], :old => nil},  
          #{:name => "Slashdot", :url => "http://rss.slashdot.org/Slashdot/slashdotMain", :chans => ["#test1"], :old => nil},
        ],

        # Plugins::MoeBTC
        :COINS => [] ,

        :CORONA_EXCLUDE_CHANS => [],
        :CORONA_EXCLUDE_USERS => [],

        # Plugins::Stocks
       :STOCKS_EXCLUDE_CHANS  => [] ,
       :STOCKS_EXCLUDE_USERS  => [] ,
          
        # Plugins::QuoteDB
        :QUOTEDB_CHANS => [] ,
        :QUOTEDB_EXCLUDE_USERS => [] ,
        :QUOTEDB_ENABLE_RANDQUOTE => 1 ,
        
        # Plugins::URLDB
        :URLDB_CHANS => [] ,
        :URLDB_EXCLUDE_USERS => [] ,
        :URLDB_IMAGEDIR => "",  # set this to a real path and images will be saved in it ,

        :URLDB_DATA => [
          {:chan => "#test", :exclude_users => [], :imagedir => "/var/www/test.com/public_html/images/urldb", :table => :TitleBot}
        ] ,


        
        # Plugins::Weather
        :WUNDERGROUND_API_KEY => 'YOUR_API_KEY_HERE' ,
        :WUNDERGROUND_API_RATE_LIMIT_MINUTE => 10 ,
        :WUNDERGROUND_API_RATE_LIMIT_DAY => 250 ,
        
        # Plugins::DickBot
        :DICKBOT_ENABLE => 0 ,
        :DICKBOT_IRC_SERVER => "server.irc.com" ,
        :DICKBOT_IRC_PORT => 7777 ,
        :DICKBOT_IRC_CHANNELS => ["#chan1","#test1","#etc"] ,
        :DICKBOT_IRC_USER => "username" ,
        :DICKBOT_IRC_PASSWORD => "password" ,
        :DICKBOT_IRC_SSL => true ,
        :DICKBOT_IRC_NICK => "theOTHERbot" ,
        :DICKBOT_IRC_PLUGINS => [ 
          #"Plugins:DickBot",
        ],

        :DICKBOT_IRC_RUN_AFTER_CONNECT => [
          proc do 
            User('some_user').send('some message')
            sleep 3
            Channel('#some_chan').join
            #etc ...
          end
        ],

        :DICKBOT_IRC_LOGLEVEL => :info ,  # :debug
        
        # prob1 is the percentage probability a insult will be thrown at someone who joins.
        # prob1 is the percentage probability that a thrown insult will be of the type Foul-O-Matic,
        # otherwise it will be of type Insult Generator
        :DICKBOT_JOIN_INSULTS => [ 
          {:chan => "#chan1", :prob1 => 35, :prob2 => 25},
          {:chan => "#chan2", :prob1 => 50, :prob2 => 25},
        ],
          
        # rate is average number of minutes between "random" speaks, implemented as a Poisson Process
        :DICKBOT_RANDOM_SPEAK => [ 
          {:chan => "#chan2", :rate => 0.5}, 
          {:chan => "#chan1", :rate => 1},
        ]
      }
    end
  end
end





module MyApp
  module Config
    module BOT_B
      @config = nil

      class << self
        attr_accessor :config
      end

      @config = {
        :IRC_SERVER => "different.server.irc.com" ,
        :IRC_PORT => 7777 ,
        :IRC_CHANNELS => ["#chanX","#testY","#etcZ"] ,
        :IRC_USER => "username" ,
        :IRC_PASSWORD => "password" ,
        :IRC_SSL => true ,
        :IRC_NICK => "thebot" ,
        :IRC_PLUGINS => [
          "Plugins::RSSFeed",
          "Plugins::URL",
          "Plugins::TvMaze",
          "Plugins::IMDB",
          "Plugins::URLDB",
          "Plugins::MoeBTC",
          "Plugins::Weather",
          "Plugins::Election",
          "Plugins::RottenTomatoes",
          "Plugins::QuoteDB",
          "Plugins::CloudVision",
          "Plugins::Google",
          "Plugins::Wikipedia",
          "Plugins::TvMazeSchedule",
          "Plugins::CoronaVirus",
          "Plugins::Logmobile",
          "Plugins::TwitterSearch",
          "Plugins::Wolfram",
          "Plugins::Stocks",
          "Plugins::OpenAI",
          "Plugins::TwitterFeed",
        ],
      
        :TWATBOT_SQL => 'postgres://user:pass@localhost/twatbot?encoding=utf8' ,
        
        # Plugins::URL
        :URL_SUB_PLUGINS => [  # each one of these will be tried in order until one of them works: ,
          {:class => "URLHandlers::Youtube",  :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::IMDB",     :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::Dumpert",  :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::Imgur",    :excludeChans => [], :excludeNicks => []},
          {:class => "URLHandlers::TitleBot", :excludeChans => [], :excludeNicks => []},
        ],
        
        :YOUTUBE_GOOGLE_SERVER_KEY => "YOUR_GOOGLE_SERVER_KEY_FOR_YOUTUBE_API" ,
        :IMGUR_API_CLIENT_ID => "YOUR IMGUR API CLIENT ID" ,
        :OMDB_API_KEY => "XXXXXXXXXXXXXXXXX" ,
        :COINMARKETCAP_API_KEY => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        
        # Plugins::RottenTomatoes
        :RT_EXCLUDE_CHANS => [] ,
        :RT_EXCLUDE_USERS => ["dickbot", "dickbot_"] ,
        
        # Plugins::IMDB
        :IMDB_EXCLUDE_CHANS => [] ,
        :IMDB_EXCLUDE_USERS => ["dickbot", "dickbot_"] ,
        
        # Plugins::TvMaze
        :TVDB_API_USERNAME => 'fake' ,
        :TVDB_API_USERKEY => '0123456789ABCDEF' ,
        :TVDB_API_KEY => '0123456789ABCDEF' ,
        :TVMAZE_EXCLUDE_CHANS => [] ,
        :TVMAZE_EXCLUDE_USERS => ["dickbot", "dickbot_"] ,
        
        # Plugins::RSSFeed
        :RSS_FEEDS => [
          {:name => "TorrentFreak", :url => "http://feeds.feedburner.com/Torrentfreak", :chans => ["#test1"], :old => nil},  
          #{:name => "Slashdot", :url => "http://rss.slashdot.org/Slashdot/slashdotMain", :chans => ["#test1"], :old => nil},
        ],
          
        # Plugins::QuoteDB
        :QUOTEDB_CHANS => [] ,
        :QUOTEDB_EXCLUDE_USERS => [] ,
        :QUOTEDB_ENABLE_RANDQUOTE => 1 ,
        
        # Plugins::URLDB
        :URLDB_CHANS => [] ,
        :URLDB_EXCLUDE_USERS => [] ,
        :URLDB_IMAGEDIR => "",  # set this to a real path and images will be saved in it ,
        
        # Plugins::Weather
        :WUNDERGROUND_API_KEY => 'YOUR_API_KEY_HERE' ,
        :WUNDERGROUND_API_RATE_LIMIT_MINUTE => 10 ,
        :WUNDERGROUND_API_RATE_LIMIT_DAY => 250 ,
        
        # Plugins::DickBot
        :DICKBOT_ENABLE => 0 ,
        :DICKBOT_IRC_SERVER => "server.irc.com" ,
        :DICKBOT_IRC_PORT => 7777 ,
        :DICKBOT_IRC_CHANNELS => ["#chan1","#test1","#etc"] ,
        :DICKBOT_IRC_USER => "username" ,
        :DICKBOT_IRC_PASSWORD => "password" ,
        :DICKBOT_IRC_SSL => true ,
        :DICKBOT_IRC_NICK => "theOTHERbot" ,
        :DICKBOT_IRC_PLUGINS => [ 
          #"Plugins:DickBot",
        ],

        # Plugins::MoeBTC
        :COINS => [] ,

        :CORONA_EXCLUDE_CHANS => [],
        :CORONA_EXCLUDE_USERS => [],

        # Plugins::Stocks
       :STOCKS_EXCLUDE_CHANS  => [] ,
       :STOCKS_EXCLUDE_USERS  => [] ,
        
        # prob1 is the percentage probability a insult will be thrown at someone who joins.
        # prob1 is the percentage probability that a thrown insult will be of the type Foul-O-Matic,
        # otherwise it will be of type Insult Generator
        :DICKBOT_JOIN_INSULTS => [ 
          {:chan => "#chan1", :prob1 => 35, :prob2 => 25},
          {:chan => "#chan2", :prob1 => 50, :prob2 => 25},
        ],
          
        # rate is average number of minutes between "random" speaks, implemented as a Poisson Process
        :DICKBOT_RANDOM_SPEAK => [ 
          {:chan => "#chan2", :rate => 0.5}, 
          {:chan => "#chan1", :rate => 1},
        ]
      }  
    end
  end
end

    