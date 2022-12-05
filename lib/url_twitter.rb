require "open-uri"
require "nokogiri"
#require 'htmlentities'

module URLHandlers
  module Twitter

    def parse(url)

=begin
      u = URI.parse(url)

      # figure out the redirection of t.co shortlinks
      if u.host == "t.co"
        begin
          u.open(redirect: false)
        rescue OpenURI::HTTPRedirect => redirect
          u = redirect.uri
          puts "Handled t.co redirect to #{u}"
        end
      end

      return unless u.to_s =~ /^https?:\/\/([^.\/\s]+\.)*twitter\.com\/.*status/

      #coder = HTMLEntities.new

      # only the mobile site contains the data we need;
      # the main site only has lots of javascript
      u.host = "mobile.twitter.com"
      doc = Nokogiri::HTML(u.read)

      tweet = doc.css(".main-tweet div.tweet-text").first rescue nil
      return if tweet.nil?

      # highlight hashtags and ats
      tweet.css("a.twitter-hashtag,a.twitter-atreply").each do |a|
        a.replace("§_START_HASHTAG_§#{a.text}§_END_HASHTAG_§")
      end

      # fix links
      tweet.css("a").each do |a|
        href = a["href"]
        expanded = a["data-expanded-url"]
        tco = a["data-tco-id"]

        if expanded && expanded !~ /^https?:\/\/(([^.\/\s]+\.)*twitter\.com|t\.co)\//
          a.replace expanded
        elsif href && href !~ /^https?:\/\/(([^.\/\s]+\.)*twitter\.com|t\.co)\//
           a.replace href
        elsif href =~ /https?:\/\/t.co\//
          a.replace href
        elsif tco
          a.replace "http://t.co/#{a["data-tco-id"]}"
        elsif href =~ /^http/
          a.replace href
        else
          a.replace a.content
        end

      end

      # remove html tags and line breaks
      tweet = tweet.content.gsub(/[[:space:]]+/m, " ").strip

      # fix color codes that don't survive going through Nokogiri
      tweet.gsub!(/§_START_HASHTAG_§/, "\x0312")
      tweet.gsub!(/§_END_HASHTAG_§/, "\x0f\x02")

      username = doc.css(".main-tweet .username").first.content.strip
      fullname = doc.css(".main-tweet .fullname").first.content.strip
      timestamp = doc.css(".main-tweet td.tweet-content .metadata").first.content.gsub(/[[:space:]]+/m, " ").strip
      verified = doc.css(".main-tweet .fullname a.badge img[alt='Verified Account']").first.content.strip rescue nil

      #return "\x0303[Twitter]\x0f \x0304#{username}\x0f#{verified.nil? ? '' : "\u2713"} (#{fullname}): #{tweet} | \x0307#{timestamp}\x0f"
      return "\x0303[Twitter]\x0f \x0304#{username}\x0f#{verified.nil? ? '' : "\u2713"} (#{fullname}): \x02#{tweet}\x0f | \x0307#{timestamp}\x0f"

=end
      title = getTitleAndLocation(url)
      url =  title[:effective_url] rescue nil

      if(!url.nil? && url =~ /^(https?:\/\/(?:[^\/]*\.)*)twitter.com\//)
        url = url.gsub(/^(https?:\/\/)(?:[^\/]*\.)*twitter.com\//, '\1nitter.net/')
        title = getTitleAndLocation(url)

        #if !title.nil? && (!title[:title].nil? || !title[:description].nil?)
        if !title.nil? && !title[:title].nil?
          #url =~ /https?:\/\/([^\/]+)/
          title[:effective_url] =~ /https?:\/\/([^\/]+)/
          host = $1
          #return "[ \x02" + title[:title] + "\x0f ] - " + host + (title[:description].nil? ? '' : ("\n[ \x02" + title[:description] + "\x0f ] - " + host))
          return "[ \x02" + title[:title].gsub(/\s*\|\s*nitter\s*$/, "") + "\x0f ] - " + host.gsub(/nitter\.net/, "twitter.com")
        end
      end
      
      return nil

    end


  end
end