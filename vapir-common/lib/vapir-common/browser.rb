# vapir-common/browser
require 'vapir-common/options' # stub; this stuff is deprecated 
require 'vapir-common/config'
require 'vapir-common/version'
require 'vapir-common/browsers'

module Vapir
  
=begin rdoc

Watir is a family of open-source drivers for automating web browsers. You
can use it to write tests that are easy to read and maintain. 

Watir drives browsers the same way people do. It clicks links, fills in forms,
presses buttons. Watir also checks results, such as whether expected text 
appears on a page.

The Watir family currently includes support for Internet Explorer (on Windows),
Firefox (on Windows, Mac and Linux) and Safari (on Mac). 

Project Homepage: http://wtr.rubyforge.org

This Browser module provides a generic interface
that tests can use to access any browser. The actual browser (and thus
the actual Watir driver) is determined at runtime based on configuration
settings.

  require 'vapir'
  browser = Watir::Browser.new
  browser.goto 'http://google.com'
  browser.text_field(:name, 'q').set 'pickaxe'
  browser.button(:name, 'btnG').click
  if browser.text.include? 'Programming Ruby'
    puts 'Text was found'
  else
    puts 'Text was not found'
  end

A comprehensive summary of the Watir API can be found here
http://wiki.openqa.org/display/WTR/Methods+supported+by+Element

There are two ways to configure the browser that will be used by your tests.

One is to set the +watir_browser+ environment variable to +ie+ or +firefox+. 
(How you do this depends on your platform.)

The other is to create a file that looks like this.

  browser: ie

And then to add this line to your script, after the require statement and 
before you invoke Browser.new.

  Watir.options_file = 'path/to/the/file/you/just/created'

=end rdoc
  
  class Browser
    class << self
      alias __new__ new
      def inherited(subclass)
        class << subclass
          alias new __new__
        end
      end

      # Create a new instance of a browser driver, as determined by the
      # configuration settings. (Don't be fooled: this is not actually 
      # an instance of Browser class.)
      def new *args, &block
        browser=browser_class.new *args, &block
        browser
      end
      # makes sure that the class methods of Browser that call to the class methods of browser_class 
      # are overridden so that Browser class methods aren't inherited causing infinite loop. 
      def ensure_overridden
        if self==browser_class
          raise NotImplementedError, "This method must be overridden by #{self}!"
        end
      end

      # Create a new instance as with #new and start the browser on the
      # specified url.
      def start url
        ensure_overridden
        browser_class.start url
      end
      # Attach to an existing browser.
      def attach(how, what)
        ensure_overridden
        browser_class.attach(how, what)
      end
      def set_options options
        unless self==browser_closs
          browser_class.set_options options
        end
      end
      def options
        self==browser_class ? {} : browser_class.options
      end

      def browser_class
        key = Vapir.config.default_browser
        browser_class=SupportedBrowsers[key.to_sym][:class_name].split('::').inject(Object) do |namespace, name_part|
          namespace.const_get(name_part) # this triggers autoload if it's not loaded 
        end
      end
      private :browser_class
      
      def default
        # deprecate
        Vapir.config.default_browser
      end
      # Specifies a default browser. Must be specified before options are parsed.
      def default= default_browser
        # deprecate
        Vapir.config.default_browser = default_browser
      end
    end

    include Configurable
    def configuration_parent
      browser_class.config
    end
    
    # locate is used by stuff that uses container. this doesn't actually locate the browser
    # but checks if it (still) exists. 
    def locate(options={})
      exists?
    end
    def locate!(options={})
      locate(options) || raise(Vapir::Exception::WindowGoneException, "The browser window seems to be gone")
    end
    def inspect
      "#<#{self.class}:0x#{(self.hash*2).to_s(16)} " + (exists? ? "url=#{url.inspect} title=#{title.inspect}" : "exists?=false") + '>'
    end
    
    # does the work of #screen_capture when the WinWindow library is being used for that. see #screen_capture documentation (browser-specific)
    def screen_capture_win_window(filename, options = {})
      options = handle_options(options, :dc => :window, :format => nil)
      if options[:format] && !(options[:format].is_a?(String) && options[:format].downcase == 'bmp')
        raise ArgumentError, ":format was specified as #{options[:format].inspect} but only 'bmp' is supported when :dc is #{options[:dc].inspect}"
      end
      if options[:dc] == :desktop
        win_window.really_set_foreground!
        screenshot_win=WinWindow.desktop_window
        options[:dc] = :window
      else
        screenshot_win=win_window
      end
      screenshot_win.capture_to_bmp_file(filename, :dc => options[:dc])
    end
    private :screen_capture_win_window
  end

end
