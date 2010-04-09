# vapir-common/browser
require 'vapir-common/options'
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
    @@browser_classes = {}
    @@sub_options = {}
    @@default = nil
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
        #set_sub_options
        browser=klass.new *args, &block
        #browser=klass.allocate
        #browser.send :initialize, *args, &block
        browser
      end
      # makes sure that the class methods of Browser that call to the class methods of klass 
      # are overridden so that Browser class methods aren't inherited causing infinite loop. 
      def ensure_overridden
        if self==klass
          raise NotImplementedError, "This method must be overridden by #{self}!"
        end
      end

      # Create a new instance as with #new and start the browser on the
      # specified url.
      def start url
        ensure_overridden
        set_sub_options
        klass.start url
      end
      # Attach to an existing browser.
      def attach(how, what)
        ensure_overridden
        set_sub_options
        klass.attach(how, what)
      end
      def set_options options
        #ensure_overridden
        unless self==klass
          klass.set_options options
        end
      end
      def options
        self==klass ? {} : klass.options
      end

      def klass
        key = Vapir.options[:browser]
        #eval(@@browser_classes[key]) # this triggers the autoload
        browser_class_name=@@browser_classes[key]
        klass=browser_class_name.split('::').inject(Object) do |namespace, name_part|
          namespace.const_get(name_part)
        end
      end
      private :klass
      # Add support for the browser option, using the specified class, 
      # provided as a string. Optionally, additional options supported by
      # the class can be specified as an array of symbols. Options specified
      # by the user and included in this list will be passed (as a hash) to 
      # the set_options class method (if defined) before creating an instance.
      def support hash_args
        option = hash_args[:name]
        class_string = hash_args[:class]
        additional_options = hash_args[:options]
        library = hash_args[:library]
        gem = hash_args[:gem] || library

        @@browser_classes[option] = class_string
        @@sub_options[option] = additional_options

        autoload class_string, library
        activate_gem gem, option
      end
      
      def default
        @@default
      end
      # Specifies a default browser. Must be specified before options are parsed.
      def default= option
        @@default = option
      end
      # Returns the names of the browsers that are supported by this module.
      # These are the options for 'watir_browser' (env var) or 'browser:' (yaml).
      def browser_names
        @@browser_classes.keys
      end
      
      private
      def autoload class_string, library
        mod, klass = class_string.split('::')
        eval "module ::#{mod}; autoload :#{klass}, '#{library}'; end"
      end
      # Activate the gem (if installed). The default browser will be set
      # to the first gem that activates.
      def activate_gem gem_name, option
        begin
          gem gem_name 
          @@default ||= option
        rescue Gem::LoadError
        end
      end
      def set_sub_options
        sub_options = @@sub_options[Vapir.options[:browser]]
        return if sub_options.nil?
        specified_options = Vapir.options.reject {|k, v| !sub_options.include? k}
        self.set_options specified_options
      end
    end
    # locate is used by stuff that uses container. this doesn't actually locate the browser
    # but checks if it (still) exists. 
    def locate(options={})
      exists?
    end
    def locate!(options={})
      locate(options) || raise(Vapir::Exception::NoMatchingWindowFoundException, "The browser window seems to be gone")
    end
  end

end

require 'vapir-common/browsers'