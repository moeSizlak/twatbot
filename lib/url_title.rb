require 'htmlentities'
require 'ethon'
require 'tmpdir'
require 'tempfile'
require 'nokogiri'


module URLHandlers  
  module TitleBot

    def help
      return "\x02  <URL of HTML webpage>\x0f - Get HTML title of webpage."
    end


    def parse(url)
      title = getTitleAndLocation(url);
      if !title.nil? && (!title[:title].nil? || !title[:description].nil?)
        #url =~ /https?:\/\/([^\/]+)/
        title[:effective_url] =~ /https?:\/\/([^\/]+)/
        host = $1
        return "[ \x02" + title[:title] + "\x0f ] - " + host + (title[:description].nil? ? '' : ("\n[ \x02" + title[:description] + "\x0f ] - " + host))
      end
      
      return nil    
    end  
    
    def getTitle(url)
      coder = HTMLEntities.new
      recvd = String.new
      t = Tempfile.new(['url_cookies', '.dat'])
      tmpcookiefile = t.path
      t.write("#HttpOnly_.dumpert.nl\tTRUE\t/\tFALSE\t0\tcpc\t10") if(url =~ /https?:\/\/[^\s\/]*dumpert.nl/)
      t.close
      
      begin
        easy = Ethon::Easy.new cookiefile: tmpcookiefile, cookiejar: tmpcookiefile, url: url, followlocation: true, ssl_verifypeer: false, accept_encoding: "gzip", headers: {
        #easy = Ethon::Easy.new url: url, followlocation: true, ssl_verifypeer: false, headers: {
          'User-Agent' => 'foo'
        }
        easy.on_body do |chunk, easy|
          recvd << chunk
          
          recvd =~ Regexp.new('<title[^>]*>[[:space:]]*((?:(?!</title>).){0,640})[[:space:]]*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found = coder.decode title_found.force_encoding('utf-8')
            title_found.strip!
            title_found.gsub!(/[[:space:]]+/m, ' ')
            title_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
            easy.cleanup rescue nil
            File.unlink(tmpcookiefile) rescue nil
            return Cinch::Helpers.sanitize title_found
          end
          
          :abort if recvd.length > 1131072 || title_found
        end
        easy.perform
        rescue
        # EXCEPTION!
      end
      
      easy.cleanup rescue nil
      File.unlink(tmpcookiefile) rescue nil
      return nil
    end
    
    def getTitleAndLocation(url)
      coder = HTMLEntities.new
      recvd = String.new
      mytitle = nil
      myurl = nil
      #tmpcookiefile = Dir::Tmpname.create(['url_cookies', '.dat']) { }
      t = Tempfile.new(['url_cookies', '.dat'])
      tmpcookiefile = t.path
      t.close

      desc_found = nil
      title_found = nil
      
      begin
        easy = Ethon::Easy.new cookiefile: tmpcookiefile, cookiejar: tmpcookiefile, url: url, followlocation: true, ssl_verifypeer: false, accept_encoding: "gzip", headers: {
        #easy = Ethon::Easy.new url: url, followlocation: true, ssl_verifypeer: false, headers: {
          'User-Agent' => 'foo'
        }
        easy.on_body do |chunk, easy|
          myurl = easy.effective_url
          recvd << chunk

          puts chunk

          recvd =~ Regexp.new('<[[:space:]]*meta[[:space:]]+[^>]*(?<=\b)name[[:space:]]*=[[:space:]]*([\'"])description\1[^>]*(?<=\b)content[[:space:]]*=[[:space:]]*([\'"])((?:(?!\2).){0,640})', Regexp::MULTILINE | Regexp::IGNORECASE)
          if desc_found = $3
            desc_found = coder.decode desc_found.force_encoding('utf-8')
            desc_found.strip!
            desc_found.gsub!(/[[:space:]]+/m, ' ')
            desc_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
          else
            recvd =~ Regexp.new('<[[:space:]]*meta[[:space:]]+[^>]*(?<=\b)content[[:space:]]*=[[:space:]]*([\'"])((?:(?!\1).){0,640})\1[^>]*(?<=\b)name[[:space:]]*=[[:space:]]*([\'"])description\3', Regexp::MULTILINE | Regexp::IGNORECASE)
            if desc_found = $2
              desc_found = coder.decode desc_found.force_encoding('utf-8')
              desc_found.strip!
              desc_found.gsub!(/[[:space:]]+/m, ' ')
              desc_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
            end
          end
          
          recvd =~ Regexp.new('<title[^>]*>[[:space:]]*((?:(?!</title>).){0,640})[[:space:]]*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found = coder.decode title_found.force_encoding('utf-8')
            title_found.strip!
            title_found.gsub!(/[[:space:]]+/m, ' ')
            title_found.gsub!(/(?:\p{Mark}{2})\p{Mark}+/u, '')
          end
          
          :abort if recvd.length > 1131072 || (title_found && desc_found)
        end
        easy.perform
        rescue
        # EXCEPTION!
      end
      
      easy.cleanup rescue nil
      File.unlink(tmpcookiefile) rescue nil

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

      return retval

    end
    
    
  module_function :parse
  module_function :getTitle
  module_function :getTitleAndLocation
    
  end  
end
