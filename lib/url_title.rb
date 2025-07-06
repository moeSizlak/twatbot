require 'htmlentities'
require 'httpx'
require 'uri'


module URLHandlers  
  module TitleBot

    def help
      return "\x02  <URL of HTML webpage>\x0f - Get HTML title of webpage."
    end


    def parse(url)
      title = getTitleAndLocation(url);
      if !title.nil? && !title[:title].nil? && title[:title].length > 0

        url =~ /https?:\/\/([^\/]+)/
        host1 = $1.downcase
        title[:effective_url] =~ /https?:\/\/([^\/]+)/
        host2 = $1.downcase
        
        domain_redirect = false
        if(host1 != host2 && host1 !~ /^\d+\.\d+\.\d+\.\d+$/ && host2 !~ /^\d+\.\d+\.\d+\.\d+$/)
          domain1 = host1.gsub(/^.*([^\.]*\.[^\.]*)$/, '\1')
          domain2 = host2.gsub(/^.*([^\.]*\.[^\.]*)$/, '\1')

          domain_redirect = true if domain1 != domain2
        end

        return "[ \x02#{title[:title]}\x0f ]" + (domain_redirect == true ? (" :: \x0307#{host2}\x0f") : '')
      end
      
      return nil    
    end  
    
    def getTitle(url)
      coder = HTMLEntities.new
      recvd = String.new

      begin
        http = HTTPX.plugin(:cookies).plugin(:follow_redirects).with(timeout: { request_timeout: 15 }).with(headers: {
          'User-Agent' => (url =~ /tiktok.com\// ? 'facebookexternalhit/1.1' : 'foo')
        })
        http = http.with_cookies([{ name: "cpc", value: "10", httponly: true }]) if(url =~ /https?:\/\/[^\s\/]*dumpert.nl/)
        response = http.get(url)

        while chunk = response.body.read(16_384)
          recvd << chunk
          
          recvd =~ Regexp.new('<title[^>]*>[[:space:]]*((?:(?!</title>).){0,1024})[[:space:]]*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found = coder.decode title_found.force_encoding('utf-8')
            title_found.strip!
            title_found.gsub!(/[[:space:]]+/m, ' ')
            title_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
            response.close
            return Cinch::Helpers.sanitize title_found
          end
          
          response.close if recvd.length > 1131072 || title_found
        end
        rescue
        # EXCEPTION!
      end
      
      response.close rescue nil
      return nil
    end
    
    def getTitleAndLocation(url)
      coder = HTMLEntities.new
      recvd = String.new
      mytitle = nil
      myurl = nil
      mycode = nil
      desc_found = nil
      title_found = nil

      ua = 'foo'
      ua = 'facebookexternalhit/1.1' if url =~ /tiktok.com\//
      ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36' if url =~ /nitter.poast.org\//
      puts "UA = #{ua}"

      headers = { 'User-Agent' => ua}

      begin
        http = HTTPX.plugin(:cookies).plugin(:follow_redirects).with(timeout: { request_timeout: 15 }).with(headers: headers)
        response = http.get(url)

        while chunk = response.body.read(16_384)
          myurl = response.uri.to_s
          mycode = response.status
          recvd << chunk

          if 1==0 && desc_found.nil?
            recvd =~ Regexp.new('<[[:space:]]*meta[[:space:]]+[^>]*(?<=\b)name[[:space:]]*=[[:space:]]*([\'"])description\1[^>]*(?<=\b)content[[:space:]]*=[[:space:]]*([\'"])((?:(?!\2).){0,1024})', Regexp::MULTILINE | Regexp::IGNORECASE)
            if desc_found = $3
              desc_found = coder.decode desc_found.force_encoding('utf-8')
              desc_found = coder.decode desc_found.force_encoding('utf-8')
              desc_found.strip!
              desc_found.gsub!(/[[:space:]]+/m, ' ')
              desc_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
            else
              recvd =~ Regexp.new('<[[:space:]]*meta[[:space:]]+[^>]*(?<=\b)content[[:space:]]*=[[:space:]]*([\'"])((?:(?!\1).){0,1024})\1[^>]*(?<=\b)name[[:space:]]*=[[:space:]]*([\'"])description\3', Regexp::MULTILINE | Regexp::IGNORECASE)
              if desc_found = $2
                desc_found = coder.decode desc_found.force_encoding('utf-8')
                desc_found = coder.decode desc_found.force_encoding('utf-8')
                desc_found.strip!
                desc_found.gsub!(/[[:space:]]+/m, ' ')
                desc_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
              end
            end
          end
          
          if title_found.nil?
            recvd =~ Regexp.new('<title[^>]*>[[:space:]]*((?:(?!</title>).){0,1024})[[:space:]]*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
            if title_found = $1
              title_found = coder.decode title_found.force_encoding('utf-8')
              title_found.strip!
              title_found.gsub!(/[[:space:]]+/m, ' ')
              title_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
            end
          end
          
          response.close if recvd.length > 1131072 || title_found
        end

        rescue
        # EXCEPTION!
      end

      response.close rescue nil

      retval = {:effective_url => myurl}

      if(title_found)
        retval[:title] = Cinch::Helpers.sanitize(title_found)
      else
        retval[:title] = nil
      end

      if(desc_found)
        retval[:description] = Cinch::Helpers.sanitize(desc_found)
      else
        retval[:description] = nil
      end

      retval[:response_code] = mycode

      return retval

    end


    def getEffectiveUrl(url)
      myurl = nil


      begin
        http = HTTPX.plugin(:cookies).plugin(:follow_redirects).with(timeout: { request_timeout: 15 }).with(headers: {
          'User-Agent' => (url =~ /tiktok.com\// ? 'facebookexternalhit/1.1' : 'foo')
        })
        response = http.get(url)
        
        while chunk = response.body.read(16_384)
          myurl = response.uri.to_s
          response.close
        end

      rescue
        # EXCEPTION!
      end

      response.close rescue nil
      return myurl
    end
    
    
  module_function :parse
  module_function :getTitle
  module_function :getTitleAndLocation
  module_function :getEffectiveUrl
    
  end  
end
