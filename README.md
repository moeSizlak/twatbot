# twatbot

This is an IRC bot using Ruby and the cinch gem.  It is modular and includes several plugins.  It uses postgres SQL.  There are 2 main bots:

* twatbot - This is the main bot.
* dickbot - This is a markov chain rambling bot with a propensity toward vulgarity and violence.

twatbot includes the following plugins:

* tvmaze - get info about TV shows from tvmaze and !mdb
* !mdb - get info about movies from !mdb and rotten tomatos (this depends on a modified version of the !mdb gem)
* weather - get weather from weather underground, uses Google geocoding to resolve locations
* rss - monitors RSS feeds and prints new entries to irc
* crypto_coins - gets info about cryptocoins from coinmarketcap
* quotedb - quote database
* election - get info about elections
* URL Database - Save all URL's to a database, and optionally save a cached copy of images
* URL Listener - monitors IRC for certains types of URL's and prints info about them:
  * YouTube
  * Imgur
  * Dumpert
  * !mdb
  * HTML Titles


## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

The following (non-exhaustive) Ruby Gems are required:

```
cinch
sequel
logger
!mdb (modified)
nokogiri
open-uri
json
ethon
htmlentities
unirest
filemagic
mime/types
net/http
feedjira
uri
tmpdir
tempfile
thread
time
tzinfo
ruby-duration
securerandom
```

### Installing


## Running the tests


### Break down into end to end tests


## Deployment


## Built With


## Contributing


## Versioning
 

## Authors

* moeSizlak

## License


## Acknowledgments

