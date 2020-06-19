require 'htmlentities'
require 'ethon'
require 'tmpdir'
require 'tempfile'


module URLHandlers  
  module TitleBot

    def help
      return "\x02  <URL of HTML webpage>\x0f - Get HTML title of webpage."
    end


    def parse(url)
      title = getTitleAndLocation(url);
      if !title.nil? && !title[:title].nil?
        #url =~ /https?:\/\/([^\/]+)/
        title[:effective_url] =~ /https?:\/\/([^\/]+)/
        host = $1
        return "[ \x02" + title[:title] + "\x0f ] - " + host
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
          
          recvd =~ Regexp.new('<title[^>]*>[[:space:]]*((?:(?!</title>).){0,512})[[:space:]]*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found = coder.decode title_found.force_encoding('utf-8')
            title_found.strip!
            title_found.gsub!(/[[:space:]]+/m, ' ')
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
      
      begin
        easy = Ethon::Easy.new cookiefile: tmpcookiefile, cookiejar: tmpcookiefile, url: url, followlocation: true, ssl_verifypeer: false, accept_encoding: "gzip", headers: {
        #easy = Ethon::Easy.new url: url, followlocation: true, ssl_verifypeer: false, headers: {
          'User-Agent' => 'foo'
        }
        easy.on_body do |chunk, easy|
          myurl = easy.effective_url
          recvd << chunk

          #puts chunk
          
          recvd =~ Regexp.new('<title[^>]*>[[:space:]]*((?:(?!</title>).){0,512})[[:space:]]*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found = coder.decode title_found.force_encoding('utf-8')
            title_found.strip!
            title_found.gsub!(/[[:space:]]+/m, ' ')
            easy.cleanup rescue nil
            File.unlink(tmpcookiefile) rescue nil
            return {:title => Cinch::Helpers.sanitize(title_found), :effective_url => myurl }
          end
          
          :abort if recvd.length > 1131072 || title_found
        end
        easy.perform
        rescue
        # EXCEPTION!
      end
      
      easy.cleanup rescue nil
      File.unlink(tmpcookiefile) rescue nil
      return {:title => mytitle, :effective_url => myurl }
    end
    
    
  module_function :parse
  module_function :getTitle
  module_function :getTitleAndLocation
    
  end  
end
