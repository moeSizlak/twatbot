
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
    ]
    
    # Plugins::URL
    URL_SUB_PLUGINS = [  # each one of these will be tried in order until one of them works:
      {:class => "URLHandlers::Youtube",  :excludeChans => [], :excludeNicks => []},
      {:class => "URLHandlers::IMDB",     :excludeChans => [], :excludeNicks => []},
      {:class => "URLHandlers::Dumpert",  :excludeChans => [], :excludeNicks => []},
      {:class => "URLHandlers::TitleBot", :excludeChans => [], :excludeNicks => []},
    ]
    
    YOUTUBE_GOOGLE_SERVER_KEY = "YOUR_GOOGLE_SERVER_KEY_FOR_YOUTUBE_API"
    
    # Plugins::IMDB
    IMDB_EXCLUDE_CHANS = []
    IMDB_EXCLUDE_USERS = []
    
    # Plugins::TvMaze
    TVMAZE_EXCLUDE_CHANS = []
    TVMAZE_EXCLUDE_USERS = []
    
    # Plugins::RSSFeed
    RSS_FEEDS = [
      {:name => "TorrentFreak", :url => "http://feeds.feedburner.com/Torrentfreak", :chans => ["#test1"], :old => nil},  
      #{:name => "Slashdot", :url => "http://rss.slashdot.org/Slashdot/slashdotMain", :chans => ["#test1"], :old => nil},
    ]
      
    # Plugins::URLDB
    URLDB_CHANS = []
    URLDB_EXCLUDE_USERS = []
    URLDB_SQL_SERVER = '127.0.0.1'
    URLDB_SQL_USER = 'yoursqlusername'
    URLDB_SQL_PASSWORD = 'yoursqlpassword'
    URLDB_SQL_DATABASE = "yoursqldatabase"
    URLDB_IMAGEDIR = ""  # set this to a real path and images will be saved in it
    
  end
end
  
    