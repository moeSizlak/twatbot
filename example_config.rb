
module MyApp
  module Config
    IRC_SERVER = "server.irc.com"
    IRC_PORT = 7777
    IRC_CHANNELS = ["#chan1","#test1","#etc"]
    IRC_USER = "username"
    IRC_PASSWORD = "password"
    IRC_SSL = true
    IRC_NICK = "thebot"
    IRC_PLUGINS = [
      "Plugins::RSSFeed",
      "Plugins::URL",
      "Plugins::TvMaze",
      "Plugins::IMDB",
      #"Plugins::URLDB",
      #"Plugins::MoeBTC",
      #"Plugins::QuoteDB",
    ]
    
    # Plugins::URL
    URL_SUB_PLUGINS = [  # each one of these will be tried in order until one of them works:
      {:class => "URLHandlers::Youtube",  :excludeChans => [], :excludeNicks => []},
      {:class => "URLHandlers::IMDB",     :excludeChans => [], :excludeNicks => []},
      {:class => "URLHandlers::Dumpert",  :excludeChans => [], :excludeNicks => []},
      {:class => "URLHandlers::Imgur",    :excludeChans => [], :excludeNicks => []},
      {:class => "URLHandlers::TitleBot", :excludeChans => [], :excludeNicks => []},
    ]
    
    YOUTUBE_GOOGLE_SERVER_KEY = "YOUR_GOOGLE_SERVER_KEY_FOR_YOUTUBE_API"
    IMGUR_API_CLIENT_ID = "YOUR IMGUR API CLIENT ID"
    
    # Plugins::IMDB
    IMDB_EXCLUDE_CHANS = []
    IMDB_EXCLUDE_USERS = ["dickbot", "dickbot_"]
    
    # Plugins::TvMaze
    TVMAZE_EXCLUDE_CHANS = []
    TVMAZE_EXCLUDE_USERS = ["dickbot", "dickbot_"]
    
    # Plugins::RSSFeed
    RSS_FEEDS = [
      {:name => "TorrentFreak", :url => "http://feeds.feedburner.com/Torrentfreak", :chans => ["#test1"], :old => nil},  
      #{:name => "Slashdot", :url => "http://rss.slashdot.org/Slashdot/slashdotMain", :chans => ["#test1"], :old => nil},
    ]
      
    # Plugins::QuoteDB
    QUOTEDB_CHANS = []
    QUOTEDB_EXCLUDE_USERS = []
    QUOTEDB_SQL_SERVER = '127.0.0.1'
    QUOTEDB_SQL_USER = 'yoursqlusername'
    QUOTEDB_SQL_PASSWORD = 'yoursqlpassword'
    QUOTEDB_SQL_DATABASE = "yoursqldatabase"
    QUOTEDB_ENABLE_RANDQUOTE = 1
    
    # Plugins::URLDB
    URLDB_CHANS = []
    URLDB_EXCLUDE_USERS = []
    URLDB_SQL_SERVER = '127.0.0.1'
    URLDB_SQL_USER = 'yoursqlusername'
    URLDB_SQL_PASSWORD = 'yoursqlpassword'
    URLDB_SQL_DATABASE = "yoursqldatabase"
    URLDB_IMAGEDIR = ""  # set this to a real path and images will be saved in it
    
    # Plugins::DickBot
    DICKBOT_ENABLE = 0
    DICKBOT_IRC_SERVER = "server.irc.com"
    DICKBOT_IRC_PORT = 7777
    DICKBOT_IRC_CHANNELS = ["#chan1","#test1","#etc"]
    DICKBOT_IRC_USER = "username"
    DICKBOT_IRC_PASSWORD = "password"
    DICKBOT_IRC_SSL = true
    DICKBOT_IRC_NICK = "theOTHERbot"
    DICKBOT_IRC_PLUGINS = [
      #"Plugins:DickBot",
    ]
    
    # prob1 is the percentage probability a insult will be thrown at someone who joins.
    # prob1 is the percentage probability that a thrown insult will be of the type Foul-O-Matic,
    # otherwise it will be of type Insult Generator
    DICKBOT_JOIN_INSULTS = [
      {:chan => "#chan1", :prob1 => 35, :prob2 => 25},
      {:chan => "#chan2", :prob1 => 50, :prob2 => 25},
      ]
      
    # rate is average number of minutes between "random" speaks, implemented as a Poisson Process
    DICKBOT_RANDOM_SPEAK = [
      {:chan => "#chan2", :rate => 0.5}, 
      {:chan => "#chan1", :rate => 1},
      ]
    
    DICKBOT_SQL_SERVER = '127.0.0.1'
    DICKBOT_SQL_USER = 'yoursqlusername'
    DICKBOT_SQL_PASSWORD = 'yoursqlpassword'
    DICKBOT_SQL_DATABASE = "yoursqldatabase"
    
  end
end
  
    