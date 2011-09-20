# vapir-common/browser
require 'vapir-common/options' # stub; this stuff is deprecated 
require 'vapir-common/config'
require 'vapir-common/version'
require 'vapir-common/browsers'

module Vapir
  # The common Browser class from which classes specific to Firefox or IE browsers inherit. 
  # 
  # Calls to this class are delegated to a browser inheriting from this, which is set using config.default_browser
  class Browser
    class << self
      alias __new__ new # :nodoc:
      def inherited(subclass) # :nodoc:
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
      alias new_window new

      # Create a new browser instance, starting at the specified url.
      # If no url is given, start at about:blank.
      def start(url='about:blank', options={})
        raise ArgumentError, "URL must be a string; got #{url.inspect}" unless url.is_a?(String)
        new(options.merge(:goto => url))
      end
      alias start_window start

      # Attach to an existing browser window. Returns an instance of the current default browser class. 
      #
      # the window to be attached to can be
      # referenced by url, title, or window handle ('how' argument)
      #
      # The 'what' argument can be either a string or a regular expression, in the 
      # case of of :url or :title. 
      #
      #  Vapir::Browser.attach(:url, 'http://www.google.com')
      #  Vapir::Browser.attach(:title, 'Google')
      #  Vapir::Browser.attach(:hwnd, 528140)
      #
      # see the implementing browser's +new+ method for more details on what may be passed. 
      def attach(how, what, options={})
        new(options.merge(:attach => [how, what]))
      end
      alias find attach

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
      if filename =~ /\.(\w+)\z/
        extension = $1
      end
      options = handle_options(options, :dc => :window, :format => extension)
      if options[:dc] == :desktop
        win_window.really_set_foreground!
        screenshot_win=WinWindow.desktop_window
        options[:dc] = :window
      else
        screenshot_win=win_window
      end
      if !options[:format] || options[:format].downcase == 'bmp'
        screenshot_win.capture_to_bmp_file(filename, :dc => options[:dc])
      else
        begin
          require 'rmagick'
        rescue LoadError
          raise $!.class, "To use :format => #{format.inspect}, please install rmagick: http://rmagick.rubyforge.org/install-faq.html#win\n\n"+$!.message
        end
        bmp_blob = screenshot_win.capture_to_bmp_blob(:dc => options[:dc])
        magick_img = Magick::Image.from_blob(bmp_blob)[0]
        magick_img.write(filename) # magick handles converting based on extension 
      end
    end
    private :screen_capture_win_window
  end

  module WatirConfigCompatibility
    if defined?($FAST_SPEED)
      if config.warn_deprecated
        Kernel.warn "WARNING: The $FAST_SPEED global is gone. Please use the new config framework, and unset that global to silence this warning."
      end
      Vapir.config.typing_interval=0
      Vapir.config.type_keys=false
    end
    Speeds = {
      :zippy => {
        :typing_interval => 0,
        :type_keys => false,
      },
      :fast => {
        :typing_interval => 0,
        :type_keys => true,
      },
      :slow => {
        :typing_interval => 0.08,
        :type_keys => true,
      },
    }.freeze
    module WatirBrowserClassConfigCompatibility
      OptionsKeys = [:speed, :attach_timeout, :visible]
      def options
        if self==Vapir::Browser
          return browser_class.options
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #options is deprecated; please use the new config framework"
        end
        OptionsKeys.inject({}) do |hash, key|
          respond_to?(key) ? hash.merge(key => self.send(key)) : hash
        end.freeze
      end
      def set_options(options)
        if self==Vapir::Browser
          return browser_class.set_options(options)
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #set_options is deprecated; please use the new config framework"
        end
        
        unless (unknown_options = options.keys - OptionsKeys.select{|key| respond_to?("#{key}=")}).empty?
          raise ArgumentError, "unknown options: #{unknown_options.inspect}"
        end
        options.each do |key, value|
          self.send("#{key}=", value)
        end
      end
      def attach_timeout
        if self==Vapir::Browser
          return browser_class.attach_timeout
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #attach_timeout is deprecated; please use the new config framework with config.attach_timeout"
        end
        config.attach_timeout
      end
      def attach_timeout=(timeout)
        if self==Vapir::Browser
          return browser_class.attach_timeout=timeout
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #attach_timeout= is deprecated; please use the new config framework with config.attach_timeout="
        end
        config.attach_timeout = timeout
      end
    end
    Vapir::Browser.send(:extend, WatirBrowserClassConfigCompatibility)
    module Speed
      def speed
        if self==Vapir::Browser
          return browser_class.speed
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #speed is deprecated; please use the new config framework with config.typing_interval and config.type_keys"
        end
        Speeds.keys.detect do |speed_key|
          Speeds[speed_key].all? do |config_key, value|
            config[config_key] == value
          end
        end || :other
      end
      def speed=(speed_key)
        if self==Vapir::Browser
          return browser_class.speed=speed_key
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #speed= is deprecated; please use the new config framework with config.typing_interval= and config.type_keys="
        end
        unless Speeds.key?(speed_key)
          raise ArgumentError, "Invalid speed: #{speed_key}. expected #{Speeds.keys.map{|k| k.inspect }.join(', ')}"
        end
        Speeds[speed_key].each do |config_key, value|
          config[config_key]=value
        end
      end
      def set_slow_speed
        if self==Vapir::Browser
          return browser_class.set_slow_speed
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #set_slow_speed is deprecated; please use the new config framework with config.typing_interval= and config.type_keys="
        end
        self.speed= :slow
      end
      def set_fast_speed
        if self==Vapir::Browser
          return browser_class.set_fast_speed
        end
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #set_fast_speed is deprecated; please use the new config framework with config.typing_interval= and config.type_keys="
        end
        self.speed= :fast
      end
    end
    Vapir::Browser.send(:extend, Speed)
    Vapir::Browser.send(:include, Speed)
  end
end
