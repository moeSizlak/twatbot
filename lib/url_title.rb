require 'htmlentities'
require 'ethon'

module URLHandlers  
  class TitleBot
    def self.parse(url)
      title = TitleBot::getTitle(url);
      if !title.nil?
        url =~ /https?:\/\/([^\/]+)/
        host = $1
        return "[ " + title + " ] - " + host
      end
      
      return nil    
    end  
    
    def self.getTitle(url)
      coder = HTMLEntities.new
      recvd = String.new
      
      begin
        easy = Ethon::Easy.new url: url, followlocation: true, ssl_verifypeer: false, headers: {
          'User-Agent' => 'foo'
        }
        easy.on_body do |chunk, easy|
          recvd << chunk
          
          recvd =~ Regexp.new('<title[^>]*>\s*((?:(?!</title>).)*)\s*</title>', Regexp::MULTILINE | Regexp::IGNORECASE)
          if title_found = $1
            title_found = coder.decode title_found.force_encoding('utf-8')
            title_found.strip!
            title_found.gsub!(/[\s\r\n]+/m, ' ')
            return Cinch::Helpers.sanitize title_found
          end
          
          :abort if recvd.length > 1131072 || title_found
        end
        easy.perform
        rescue
        # EXCEPTION!
      end
      
      return nil
    end
    
    
    
  end  
end
