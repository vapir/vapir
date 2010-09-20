require 'vapir-firefox/browser.rb'

module Vapir
  class Firefox
    module ClearTracksMethods
      #--
      #
      # currently defined sanitizer items are: 
      #  ["cache", "cookies", "offlineApps", "history", "formdata", "downloads", "passwords", "sessions", "siteSettings"]
      def sanitizer # :nodoc:
        @@sanitizer ||= begin
          sanitizer_class = jssh_socket.object('Sanitizer')
          if sanitizer_class.type=='undefined'
            loader = jssh_socket.Components.classes["@mozilla.org/moz/jssubscript-loader;1"].getService(jssh_socket.Components.interfaces.mozIJSSubScriptLoader)
            loader.loadSubScript("chrome://browser/content/sanitize.js")
            sanitizer_class = jssh_socket.object('Sanitizer')
          end 
          sanitizer_class.new
        end
      end
      # 
      def clear_history
        sanitizer.items.history.clear()
      end
      def clear_cookies
        sanitizer.items.cookies.clear()
        #cookie_manager = jssh_socket.Components.classes["@mozilla.org/cookiemanager;1"].getService(jssh_socket.Components.interfaces.nsICookieManager)
        #cookie_manager.removeAll()
      end
      def clear_cache
        sanitizer.items.cache.clear
      end
      alias clear_temporary_files clear_cache
      def clear_all_tracks
        sanitizer.items.to_hash.inject({}) do |hash, (key, item)|
          # don't try to clear siteSettings; sometimes siteSettings.clear() raises 
          # an error which jssh doesn't handle properly - it somehow bypasses the 
          # try/catch block and shows up on the socket outside of the returned value. 
          # jssh bug? 
          if key!='siteSettings' && hash[key].canClear 
            hash[key]=(item.clear() rescue $!)
          end
          hash
        end
      end
    end
    include ClearTracksMethods
    extend ClearTracksMethods
  end
end
