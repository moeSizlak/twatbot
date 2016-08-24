require 'ethon'
require 'htmlentities'
require 'mysql2'

def dbsym(msg)
  return ":::::"+msg.to_s+":::::"
end

module Plugins
  class DickBot
    include Cinch::Plugin
    set :react_on, :message
    
    timer 0,  {:method => :initialize_speak_timers, :shots => 1}
    
    def initialize(*args)
      super
      @speaks = MyApp::Config::DICKBOT_RANDOM_SPEAK      
    end
    
    def initialize_speak_timers
      @speaks.each do |speak|
        speak[:speaks_available] = 0 if !speak.key?(:speaks_available) || !speak[:speaks_available].is_a?(Integer) || speak[:speaks_available] < 0
        speak[:rate] = 0 if !speak.key?(:rate) || !speak[:rate].is_a?(Numeric) || speak[:rate] < 0
        
        if(speak[:rate] > 0)
          prng = Random.new  
          next_timer = -60.0*Math.log(1.0-prng.rand).to_f/(1.0/speak[:rate].to_f)
          Timer next_timer, {:shots => 1} { speak_timer(speak) }
          info "Setting first speak timer for #{speak[:chan]} to #{next_timer} seconds."
        end
      end    
    end
    
    def speak_timer(speak)
      prng = Random.new
      next_timer = -60.0*Math.log(1.0-prng.rand).to_f/(1.0/speak[:rate].to_f)
      Timer next_timer, {:shots => 1} { speak_timer(speak) }
      speak[:speaks_available] += 1
      info "Setting next speak timer for #{speak[:chan]} to #{next_timer} seconds, there are #{speak[:speaks_available]} speaks_available."
    end
    
    match /^!imitate\s+(\S.*)$/, use_prefix: false, method: :imitate
    match /^!insult\s+(\S+)/, use_prefix: false, method: :insult
    match /^!insult2\s+(\S+)/, use_prefix: false, method: :insult2
    match lambda {|m| /(?:twatbot|dickbot|#{Regexp.escape(m.bot.nick.to_s)})\S*[:,]?(?:\s+(.*))?$/i}, use_prefix: false
    #match /(?:twatbot|dickbot):?(?:\s+(.*))?$/i, use_prefix: false
    #match /(.*)/i , use_prefix: false, method: :anytext
    match /(.*)/i , use_prefix: false, method: :ircaction, react_on: :action
    listen_to :join , method: :join_insult
    
    def ircaction(m, a)
      if a =~ /dickbot|twatbot|sizlak|#{Regexp.escape(@bot.nick.to_s)}/
        m.reply "stfu #{m.user} you fucking #{get_fom_insult}"
        #m.action_reply "rapes #{m.user}'s wife."
      end
    end
    
    def anytext(m, a)
      Channel("#testing12").send "AAA"
    end
    
    def weight_use(word, count)
      return count
    end
    
    def weight_one(word, count)
      return 1
    end
    
    def weight_vulgar(word, count)
      if(word =~ /(fuck|shit|ass|cunt|twat|mother|rape|kill|cock|dick|schwanz|4r5e|5h1t|5hit|a55|anal|anus|ar5e|arrse|arse|ass|ass-fucker|asses|assfucker|assfukka|asshole|assholes|asswhole|a_s_s|b00bs|b17ch|b1tch|ballbag|balls|ballsack|bastard|beastial|beastiality|bellend|bestial|bestiality|biatch|bitch|bitcher|bitchers|bitches|bitchin|bitching|bloody|blowjob|blowjobs|boiolas|bollock|bollok|boner|boob|boobs|booobs|boooobs|booooobs|booooooobs|breasts|buceta|bugger|bum|butt|butthole|buttmuch|buttplug|c0ck|c0cksucker|cawk|chink|cipa|cl1t|clit|clitoris|clits|cnut|cock|cock-sucker|cockface|cockhead|cockmunch|cockmuncher|cocks|cocksucker|cocksucking|cocksuka|cocksukka|cok|cokmuncher|coksucka|coon|cox|crap|cum|cummer|cumming|cums|cumshot|cunilingus|cunillingus|cunnilingus|cunt|cunts|cyalis|cyberfuc|cyberfucker|cyberfuckers|d1ck|damn|dick|dickhead|dildo|dildos|dink|dinks|dirsa|dlck|dog-fucker|doggin|dogging|donkeyribber|doosh|duche|dyke|ejaculate|ejaculated|ejaculatings|ejaculation|ejakulate|f4nny|fag|fagging|faggitt|faggot|faggs|fagot|fagots|fags|fanny|fannyflaps|fannyfucker|fanyy|fatass|fcuk|fcuker|fcuking|feck|fecker|felching|fellate|fellatio|fingerfuckers|fistfuck|flange|fook|fooker|fuck|fucka|fucked|fucker|fuckers|fuckhead|fuckheads|fuckin|fucking|fuckings|fuckingshitmotherfucker|fucks|fuckwhit|fuckwit|fudgepacker|fuk|fuker|fukker|fukkin|fuks|fukwhit|fukwit|fux|fux0r|f_u_c_k|gangbang|gaylord|gaysex|goatse|God|god-dam|god-damned|goddamn|goddamned|hell|heshe|hoar|hoare|hoer|homo|hore|horniest|horny|hotsex|jackoff|jap|jism|jizz|kawk|knob|knobead|knobed|knobend|knobhead|knobjocky|knobjokey|kock|kondum|kondums|kum|kummer|kumming|kums|kunilingus|l3itch|labia|lmfao|lust|lusting|m0f0|m0fo|m45terbate|ma5terb8|ma5terbate|masochist|master-bate|masterb8|masterbat|masterbat|masterbat|masterbat|masterbat|masturbat|mo-fo|mof0|mofo|mothafuck|mothafucka|mothafuckas|mothafuckaz|mothafucker|mothafuckers|mothafuckin|mothafuckings|mothafucks|motherfuck|motherfucked|motherfucker|motherfuckers|motherfuckin|motherfucking|motherfuckings|motherfuckka|motherfucks|muff|mutha|muthafecker|muthafuckker|muther|mutherfucker|n1gga|n1gger|nazi|nigg3r|nigg4h|nigga|niggah|niggas|niggaz|nigger|nob|nobhead|nobjocky|nobjokey|numbnuts|nutsack|orgasm|p0rn|pawn|pecker|penis|penisfucker|phonesex|phuck|phuk|phuked|phuking|phukked|phukking|phuks|phuq|pigfucker|pimpis|piss|pissed|pisser|pissers|pissflaps|pissing|poop|porn|porno|pornography|pornos|prick|pron|pube|pusse|pussi|pussies|pussy|rectum|retard|rimjaw|rimming|s\.o\.b\.|sadist|schlong|screwing|scroat|scrote|scrotum|semen|sex|sh1t|shag|shagger|shaggin|shagging|shemale|shit|shitdick|shite|shited|shitey|shitfuck|shitfull|shithead|shiting|shitings|shits|shitted|shitter|shitting|shittings|skank|slut|sluts|smegma|smut|snatch|son-of-a-bitch|spac|spunk|s_h_i_t|t1tt1e5|t1tties|teets|teez|testical|testicle|tit|titfuck|tits|titt|tittie5|tittiefucker|titties|tittyfuck|tittywank|titwank|tosser|turd|tw4t|twat|twathead|twatty|twunt|twunter|v14gra|v1gra|vagina|viagra|vulva|w00se|wang|wank|wanker|wanky|whoar|whore|willies|willy|xrated|xxx)/i)
        return (5 * count)
      else
        return count
      end
    end
    
    def gentext(order, nicks, seed, weightsystem)
      debug = 1
      info "SEED='#{seed}'" unless debug != 1
      
      order = 2 unless order == 1
      #order = 1
      prng = Random.new      
      con =  Mysql2::Client.new(:host => MyApp::Config::DICKBOT_SQL_SERVER, :username => MyApp::Config::DICKBOT_SQL_USER, :password => MyApp::Config::DICKBOT_SQL_PASSWORD, :database => MyApp::Config::DICKBOT_SQL_DATABASE)
      con.query("SET NAMES utf8")
      
      if !nicks || nicks == "" || nicks.length == 0
        nick_filter = ""
      else
        nick_filter = " and Nick in ("
        nicks.each do |nick|
          nick_filter << "'#{nick}',"
        end
        nick_filter.chomp!(",")
        nick_filter << ") "
      end      
      info ">>>>>" + nick_filter
         
         
      sentence = ""
        
      if(!seed || seed == "" || seed =~ /^\s*$/)
        word1 = dbsym("START")
        word2 = ""

      else
        info "COMPUTE FROM SEED BACKWARDS TO START" unless debug != 1
        seed.gsub!(/^\s*(\S+).*$/,'\1')
        
        if order == 1
          word2 = seed.dup
          sentence = seed.dup
          word1 = ""
          while word1 != dbsym("START") && word2 != dbsym("START")
            q = "select Word1, count(*) as count from WORDS1 where Word2 = '#{con.escape(word2)}' #{nick_filter} group by Word1 order by count(*) desc;"
            info q unless debug != 1
            result = con.query(q)
            info "done" unless debug != 1
            count = 0
            result.each do |r|
              w = weightsystem.call(r['Word1'], r['count'])
              count += w #1 #r['count']
              r['weight'] = w
            end
            rand = prng.rand(count)
            info "#{rand} / #{count}" unless debug != 1
            count = 0
            word2 = ""
            result.each do |r|
              count += r['weight']
              if count > rand
                word2 = r['Word1']
                break
              end
            end
            
            if word2 != dbsym("START")
              sentence = word2 + " " + sentence
            end
          end
          
          word1 = seed.dup
          word2 = ""
          sentence += " "
          
        elsif order == 2
          word2 = seed.dup
          sentence = seed.dup
          word1 = ""
        
          q = "select Word1, count(*) as count from WORDS1 where Word2 = '#{con.escape(word2)}' #{nick_filter} group by Word1 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          count = 0
          result.each do |r|
            w = weightsystem.call(r['Word1'], r['count'])
            count += w #1 #r['count']
            r['weight'] = w
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word1 = ""
          result.each do |r|
            count += r['weight']
            if count > rand
              word1 = r['Word1']
              break
            end
          end
          
          word1save = word1.dup
          word2save = word2.dup
            
          if word1 != dbsym("START")
            sentence = word1 + " " + word2        
          end
          
          word3 = word2.dup
          word2 = word1.dup
          
        
          while word2 != dbsym("START") && word3 != dbsym("START")
            q = "select Word1, count(*) as count from WORDS2 where Word2 = '#{con.escape(word2)}' and Word3 = '#{con.escape(word3)}' #{nick_filter} group by Word1 order by count(*) desc;"
            info q unless debug != 1
            result = con.query(q)
            info "done" unless debug != 1
            
            word3 = word2.dup
            
            count = 0
            result.each do |r|
              w = weightsystem.call(r['Word1'], r['count'])
              count +=  w #1 #r['count']
              r['weight'] = w
            end
            rand = prng.rand(count)
            info "#{rand} / #{count}" unless debug != 1
            count = 0
            word2 = ""
            result.each do |r|
              count +=  r['weight']
              if count > rand
                word2 = r['Word1']
                break
              end
            end
            
            if word2 != dbsym("START")
              sentence = word2 + " " + sentence
            end
          end
          
          word1 = word1save.dup
          word2 = word2save.dup
          sentence += " "
          
        end
      
        info "DONE: COMPUTE FROM SEED BACKWARDS TO START" unless debug != 1
      end
      

  
      if order == 1
        while word1 != dbsym("END")
          q = "select Word2, count(*) as count from WORDS1 where Word1 = '#{con.escape(word1)}' #{nick_filter} group by Word2 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          count = 0
          result.each do |r|
            w = weightsystem.call(r['Word2'], r['count'])
            count +=  w #1 #r['count']
            r['weight'] = w
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word1 = ""
          result.each do |r|
            count += r['weight']
            if count > rand
              word1 = r['Word2']
              break
            end
          end
          
          if word1 != dbsym("END")
            sentence += word1 + " " 
          end
        end
        
      elsif order == 2
        if word1 != dbsym("END") && word2 == ""
          q = "select Word2, count(*) as count from WORDS1 where Word1 = '#{con.escape(word1)}' #{nick_filter} group by Word2 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          count = 0
          result.each do |r|
            w = weightsystem.call(r['Word2'], r['count'])
            count +=  w #1 #r['count']
            r['weight'] = w
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word2 = ""
          result.each do |r|
            count += r['weight']
            if count > rand
              word2 = r['Word2']
              break
            end
          end
          
          if word2 != dbsym("END")
            sentence += word2 + " " 
          end
        end
      
        while word1 != dbsym("END") && word2 != dbsym("END")
          q = "select Word3, count(*) as count from WORDS2 where Word1 = '#{con.escape(word1)}' and Word2 = '#{con.escape(word2)}' #{nick_filter} group by Word3 order by count(*) desc;"
          info q unless debug != 1
          result = con.query(q)
          info "done" unless debug != 1
          
          word1 = word2.dup
          
          count = 0
          result.each do |r|
            w = weightsystem.call(r['Word3'], r['count'])
            count += w #1 #r['count']
            r['weight'] = w
          end
          rand = prng.rand(count)
          info "#{rand} / #{count}" unless debug != 1
          count = 0
          word2 = ""
          result.each do |r|
            count +=  r['weight']
            if count > rand
              word2 = r['Word3']
              break
            end
          end
          
          if word2 != dbsym("END")
            sentence += word2 + " " 
          end
        end        
      end
      
      return sentence.gsub(/Draylor/i, "Gaylord")
    
    end
    
    def imitate(m, a)
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"  
      a.strip!
      a.gsub!(/  /, " ") while a =~ /  /
      a = a.split(" ")
      nicks = a[0].split(",")
      info nicks.to_s
      
      m.reply gentext(2, nicks, nil, method(:weight_vulgar))
    end
    
    #Foul-O-Matic
    def get_fom_insult      
      thewords = [["tossing", "bloody", "shitting", "wanking", "stinky", "raging", "dementing", "dumb", "dipping", "fucking", "instant",
        "dipping", "holy", "maiming", "cocking", "ranting", "twunting", "hairy", "spunking", "flipping", "slapping",
        "sodding", "blooming", "frigging", "sponglicking", "guzzling", "glistering", "cock wielding", "failed", "artist formally known as", "unborn",
        "pulsating", "naked", "throbbing", "lonely", "failed", "stale", "spastic", "senile", "strangely shaped", "virgin",
        "bottled", "twin-headed", "fat", "gigantic", "sticky", "prodigal", "bald", "bearded", "horse-loving", "spotty",
        "spitting", "dandy", "fritzl-admiring", "friend of a", "indeterminable", "overrated", "fingerlicking", "diaper-wearing", "leg-humping",
        "gold-digging", "mong loving", "trout-faced", "cunt rotting", "flip-flopping", "rotting", "inbred", "badly drawn", "undead", "annoying",
        "whoring", "leaking", "dripping", "racist", "slutty", "cross-eyed", "irrelevant", "mental", "rotating", "scurvy looking",
        "rambling", "gag sacking", "cunting", "wrinkled old", "dried out", "sodding", "funky", "silly", "unhuman", "bloated",
        "wanktastic", "bum-banging", "cockmunching", "animal-fondling", "stillborn", "scruffy-looking", "hard-rubbing", "rectal", "glorious", "eye-less",
        "constipated", "bastardized", "utter", "hitler's personal", "irredeemable", "complete", "enormous", "probing", "dangling",
        "go suck a", "fuckfaced", "broadfaced", "titless", "son of a", "demonizing", "pigfaced", "treacherous", "retarded", "twittering",
        "one-balled", "dickless", "long-titted", "unimaginable", "bawdy", "lumpish", "wayward", "assbackward", "fawning", "clouted", "spongy", "spleeny",
        "foolish", "idle-minded", "brain-boiled", "crap-headed", "jizz-draped"],

        [ "cock", "tit", "cunt", "wank", "piss", "crap", "shit", "arse", "sperm", "nipple", "anus",
        "colon", "shaft", "dick", "poop", "semen", "slut", "suck", "earwax", "fart",
        "scrotum", "cock-tip", "tea-bag", "jizz", "cockstorm", "bunghole", "food trough", "bum",
        "butt", "shitface", "ass", "nut", "ginger", "llama", "tramp", "fudge", "vomit", "cum", "lard",
        "puke", "sphincter", "nerf", "turd", "cocksplurt", "cockthistle", "dickwhistle", "gloryhole",
        "gaylord", "spazz", "nutsack", "fuck", "spunk", "shitshark", "shitehawk", "fuckwit",
        "dipstick", "asswad", "chesticle", "clusterfuck", "douchewaffle", "retard", "bukake"],

        [ "force", "bottom", "hole", "goatse", "testicle", "balls", "bucket", "biscuit", "stain", "boy",
        "flaps", "erection", "mange", "twat", "twunt", "mong", "spack", "diarrhea", "sod",
        "excrement", "faggot", "pirate", "wipe", "sock", "sack", "barrel", "head", "zombie", "alien",
        "minge", "candle", "torch", "pipe", "bint", "jockey", "udder", "pig", "dog", "cockroach",
        "worm", "MILF", "sample", "infidel", "spunk-bubble", "stack", "handle", "badger", "wagon", "bandit",
        "lord", "bogle", "bollock", "tranny", "knob", "nugget", "king", "hole", "kid", "trailer", "lorry", "whale",
        "rag", "foot", "pile", "waffle", "bait", "barnacle", "clotpole", "dingleberry", "maggot"],

        [ "licker", "raper", "lover", "shiner", "blender", "fucker", "jacker", "butler", "packer", "rider",
        "wanker", "sucker", "felcher", "wiper", "experiment", "bender", "dictator", "basher", "piper", "slapper",
        "fondler", "plonker", "bastard", "handler", "herder", "fan", "amputee", "extractor", "professor", "graduate",
        "voyeur", "hogger", "collector", "detector", "sniffer"] ]


      combinations = [
        [0, 1, 2 ],
        [0, 1, 3 ],
        [0, 2, 3],
        [1, 2],
        [1, 3],
        [2, 3],
        [0, 1, 2, 3] ]
        
      theform = combinations.sample
      
      sentence = ""
      theform.each do |i|
        sentence << thewords[i].sample + " "
      end

      return sentence.chomp(" ")
    
    end
    
    # Insult Generator
    def get_ig_insult
      coder = HTMLEntities.new
      recvd = String.new
      url = 'http://www.insultgenerator.org/'
      

      easy = Ethon::Easy.new url: url, followlocation: true, ssl_verifypeer: false, headers: {
        'User-Agent' => 'foo'
      }
      easy.on_body do |chunk, easy|
        recvd << chunk
        
        recvd =~ Regexp.new('<div class="wrap">\s*<br><br>((?:(?!</div>).)+)', Regexp::MULTILINE | Regexp::IGNORECASE)
        if title_found = $1
          title_found = coder.decode title_found.force_encoding('utf-8')
          title_found.strip!
          #title_found.gsub!(/[\s\r\n]+/m, ' ')
                    
          begin
            con =  Mysql2::Client.new(:host => MyApp::Config::DICKBOT_SQL_SERVER, :username => MyApp::Config::DICKBOT_SQL_USER, :password => MyApp::Config::DICKBOT_SQL_PASSWORD, :database => MyApp::Config::DICKBOT_SQL_DATABASE)
            con.query("SET NAMES utf8")
            con.query("INSERT INTO Insults(Hash, Insult) VALUES (UNHEX(MD5('#{con.escape(title_found)}')), '#{con.escape(title_found)}')")
              
          rescue Mysql2::Error => e
            puts e.errno
            puts e.error
          end          
          
          return Cinch::Helpers.sanitize title_found
        end
        
        :abort if recvd.length > 131072 || title_found
      end
      easy.perform
      
      return nil
    end
    
    def insult(m, a)
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"  
      m.reply a + ": " + get_ig_insult()
    end
    
    def join_insult(m)
    
      if !MyApp::Config::DICKBOT_JOIN_INSULTS.map{|x| x[:chan]}.include?(m.channel.to_s) || m.bot.nick == m.user.to_s
        return
      end
      
      e = MyApp::Config::DICKBOT_JOIN_INSULTS.select{|x| x[:chan] == m.channel.to_s}[0]
      e[:prob1] = 0 if !e[:prob1].is_a? Integer || e[:prob1] < 0
      e[:prob1] = 100 if e[:prob1] > 100
      e[:prob2] = 0 if !e[:prob2].is_a? Integer || e[:prob2] < 0
      e[:prob2] = 100 if e[:prob2] > 100
      
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"  
      prng = Random.new  
      randnum = prng.rand(100)+1
      
      if(randnum <= e[:prob1]) 
        randnum = prng.rand(100)+1
        if randnum <= e[:prob2]
          m.reply "stfu #{m.user} you fucking #{get_fom_insult}"
        else
          m.reply m.user.to_s + ": " + get_ig_insult()
        end
      end

    end
    
    def insult2(m, a)
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"  
      m.reply a + ": " + get_fom_insult()
    end
    
    def execute(m, a)
      info "[USER = #{m.user}] [CHAN = #{m.channel}] [TIME = #{m.time}] #{m.message}"           
      m.reply gentext(2, nil, a, method(:weight_vulgar))      
    end
  
  end
end