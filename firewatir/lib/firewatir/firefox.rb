=begin rdoc
   This is FireWatir, Web Application Testing In Ruby using Firefox browser

   Typical usage:
    # include the controller
    require "firewatir"

    # go to the page you want to test
    ff = FireWatir::Firefox.start("http://myserver/mypage")

    # enter "Angrez" into an input field named "username"
    ff.text_field(:name, "username").set("Angrez")

    # enter "Ruby Co" into input field with id "company_ID"
    ff.text_field(:id, "company_ID").set("Ruby Co")

    # click on a link that has "green" somewhere in the text that is displayed
    # to the user, using a regular expression
    ff.link(:text, /green/)

    # click button that has a caption of "Cancel"
    ff.button(:value, "Cancel").click

   FireWatir allows your script to read and interact with HTML objects--HTML tags
   and their attributes and contents.  Types of objects that FireWatir can identify
   include:

   Type         Description
   ===========  ===============================================================
   button       <input> tags, with the type="button" attribute
   check_box    <input> tags, with the type="checkbox" attribute
   div          <div> tags
   form
   frame
   hidden       hidden <input> tags
   image        <img> tags
   label
   link         <a> (anchor) tags
   p            <p> (paragraph) tags
   radio        radio buttons; <input> tags, with the type="radio" attribute
   select_list  <select> tags, known informally as drop-down boxes
   span         <span> tags
   table        <table> tags
   text_field   <input> tags with the type="text" attribute (a single-line
                text field), the type="text_area" attribute (a multi-line
                text field), and the type="password" attribute (a
                single-line field in which the input is replaced with asterisks)

   In general, there are several ways to identify a specific object.  FireWatir's
   syntax is in the form (how, what), where "how" is a means of identifying
   the object, and "what" is the specific string or regular expression
   that FireWatir will seek, as shown in the examples above.  Available "how"
   options depend upon the type of object, but here are a few examples:

   How           Description
   ============  ===============================================================
   :id           Used to find an object that has an "id=" attribute. Since each
                 id should be unique, according to the XHTML specification,
                 this is recommended as the most reliable method to find an
                 object.
   :name         Used to find an object that has a "name=" attribute.  This is
                 useful for older versions of HTML, but "name" is deprecated
                 in XHTML.
   :value        Used to find a text field with a given default value, or a
                 button with a given caption
   :index        Used to find the nth object of the specified type on a page.
                 For example, button(:index, 2) finds the second button.
                 Current versions of FireWatir use 1-based indexing, but future
                 versions will use 0-based indexing.
   :xpath	     The xpath expression for identifying the element.

   Note that the XHTML specification requires that tags and their attributes be
   in lower case.  FireWatir doesn't enforce this; FireWatir will find tags and
   attributes whether they're in upper, lower, or mixed case.  This is either
   a bug or a feature.

   FireWatir uses JSSh for interacting with the browser.  For further information on
   Firefox and DOM go to the following Web page:

   http://www.xulplanet.com/references/objref/

=end

require 'watir/waiter'
require 'firewatir/window'
require 'firewatir/modal_dialog'

module Watir
  include Watir::Exception
  
  class Firefox < Browser
    include Firefox::PageContainer
    include Firefox::Window
    include Firefox::ModalDialogContainer

    def self.initialize_jssh_socket
      # if it already exists and is not nil, then we are clobbering an existing one, presumably dead. but a new socket will not have any objects of the old one, so warn 
      if class_variable_defined?('@@jssh_socket') && @@jssh_socket 
        Kernel.warn "WARNING: JSSH_SOCKET RESET: resetting jssh socket. Any active javascript references will not exist on the new socket!"
      end
      @@jssh_socket=JsshSocket.new
      @@firewatir_jssh_objects=@@jssh_socket.object("FireWatir").assign({})
      @@jssh_socket
    end
    def self.jssh_socket(options={})
      if options[:reset] || !(class_variable_defined?('@@jssh_socket') && @@jssh_socket)
        initialize_jssh_socket
      end
      if options[:reset_if_dead]
        begin
          @@jssh_socket.assert_socket
        rescue JsshConnectionError
          initialize_jssh_socket
        end
      end
      @@jssh_socket
    end
    def jssh_socket(options=nil)
      options ? self.class.jssh_socket(options) : @@jssh_socket
    end

    # Description: 
    #   Starts the firefox browser. 
    #   On windows this starts the first version listed in the registry.
    #
    # Input:
    #   options  - Hash of any of the following options:
    #     :wait_time - Time to wait for Firefox to start. By default it waits for 2 seconds.
    #                 This is done because if Firefox is not started and we try to connect
    #                 to jssh on port 9997 an exception is thrown.
    #     :profile  - The Firefox profile to use. If none is specified, Firefox will use
    #                 the last used profile.
    #     :suppress_launch_process - do not create a new firefox process. Connect to an existing one.
    # TODO: Start the firefox version given by user.
    def initialize(options = {})
      if(options.kind_of?(Integer))
        options = {:wait_time => options}
        Kernel.warn "DEPRECATION WARNING: #{self.class.name}.new takes an options hash - passing a number is deprecated. Please use #{self.class.name}.new(:wait_time => #{options[:wait_time]})\n(called from #{caller.map{|c|"\n"+c}})"
      end
      options=handle_options(options, {:wait_time => 20}, [:attach, :goto, :binary_path])
      if options[:binary_path]
        @binary_path=options[:binary_path]
      end
      
      # check for jssh not running, firefox may be open but not with -jssh
      # if its not open at all, regardless of the :suppress_launch_process option start it
      # error if running without jssh, we don't want to kill their current window (mac only)
      begin
        jssh_socket(:reset_if_dead => true).assert_socket
      rescue JsshError
        # here we're going to assume that since it's not connecting, we need to launch firefox. 
        if options[:attach]
          raise Watir::Exception::NoBrowserException, "cannot attach using #{options[:attach].inspect} - could not connect to Firefox with JSSH"
        else
          launch_browser
          # if we just launched a the browser process, attach to the window
          # that opened when we did that. 
          # but if options[:attach] is explicitly given as false (not nil), 
          # take that to mean we don't want to attach to the window launched 
          # when the process starts. 
          unless options[:attach]==false
            options[:attach]=[:title, //]
          end
        end
        ::Waiter.try_for(options[:wait_time], :exception => Watir::Exception::NoBrowserException.new("Could not connect to the JSSH socket on the browser after #{options[:wait_time]} seconds. Either Firefox did not start or JSSH is not installed and listening.")) do
          begin
            jssh_socket(:reset_if_dead => true).assert_socket
            true
          rescue JsshUnableToStart
            false
          end
        end
      end
      @browser_jssh_objects = jssh_socket.object('{}').store_rand_object_key(@@firewatir_jssh_objects) # this is an object that holds stuff for this browser 
      
      if options[:attach]
        attach(*options[:attach])
      else
        open_window
      end
      set_browser_document
      set_defaults
      if options[:goto]
        goto(options[:goto])
      end
    end
    
#    def self.firefox_is_running?
      # TODO/FIX: implement!
#      true
#    end
#    def firefox_is_running?
#      self.class.firefox_is_running?
#    end

    def mozilla_window_class_name
      'MozillaUIWindowClass'
    end

    def browser
      self
    end
    
    def inspect
      "#<#{self.class}:0x#{(self.hash*2).to_s(16)} " + (exists? ? "url=#{url.inspect} title=#{title.inspect}" : "exists?=false") + '>'
    end

    def exists?
      # jssh_socket may be nil if the window has closed 
      jssh_socket && browser_window_object && jssh_socket.object('getWindows()').to_js_array.include(browser_window_object)
    end
    
    # Launches firebox browser
    # options as .new

    def launch_browser(options = {})
      if(options[:profile])
        profile_opt = "-no-remote -P #{options[:profile]}"
      else
        profile_opt = ""
      end

      bin = path_to_bin()
      @t = Thread.new { system("#{bin} -jssh #{profile_opt}") }
    end
    private :launch_browser

    # Creates a new instance of Firefox. Loads the URL and return the instance.
    # Input:
    #   url - url of the page to be loaded.
    def self.start(url)
      new(:goto => url)
    end
    

    # Loads the given url in the browser. Waits for the page to get loaded.
    def goto(url)
      assert_exists
      browser_object.loadURI url
      wait
    end

    # Loads the previous page (if there is any) in the browser. Waits for the page to get loaded.
    def back
      if browser_object.canGoBack
        browser_object.goBack
      else
        raise Watir::Exception::NavigationException, "Cannot go back!"
      end
      wait
    end

    # Loads the next page (if there is any) in the browser. Waits for the page to get loaded.
    def forward
      if browser_object.canGoForward
        browser_object.goForward
      else
        raise Watir::Exception::NavigationException, "Cannot go forward!"
      end
      wait
    end

    # Reloads the current page in the browser. Waits for the page to get loaded.
    def refresh
      browser_object.reload
      wait
    end
    
    private
    # This function creates a new socket at port 9997 and sets the default values for instance and class variables.
    # Generatesi UnableToStartJSShException if cannot connect to jssh even after 3 tries.
    def set_defaults(no_of_tries = 0)
      @error_checkers = []
    end

    #   Sets the document, window and browser variables to point to correct object in JSSh.
    def set_browser_document
      unless browser_window_object
        raise "Window must be set (using open_window or attach) before the browser document can be set!"
      end
      @browser_object=@browser_jssh_objects[:browser]= ::Waiter.try_for(2, :exception => Watir::Exception::NoMatchingWindowFoundException.new("The browser could not be found on the specified Firefox window!")) do
        if browser_window_object.respond_to?(:getBrowser)
          browser_window_object.getBrowser
        end
      end
      
      # the following are not stored elsewhere; the ref will just be to attributes of the browser, so that updating the 
      # browser (in javascript) will cause all of these refs to reflect that as well 
      @document_object=browser_object.contentDocument
      @content_window_object=browser_object.contentWindow 
        # note that browser_window_object.content is the same thing, but simpler to refer to stuff on browser_object since that is updated by the nsIWebProgressListener below
      @body_object=document_object.body
      
      @updated_at_epoch_ms=@browser_jssh_objects.attr(:updated_at_epoch_ms).assign_expr('new Date().getTime()')
      @updated_at_offset=Time.now.to_f-jssh_socket.value_json('new Date().getTime()')/1000.0
    
      # Add eventlistener for browser window so that we can reset the document back whenever there is redirect
      # or browser loads on its own after some time. Useful when you are searching for flight results etc and
      # page goes to search page after that it goes automatically to results page.
      # Details : http://zenit.senecac.on.ca/wiki/index.php/Mozilla.dev.tech.xul#What_is_an_example_of_addProgressListener.3F
      @browser_jssh_objects[:listener_object]={}
      listener_object=@browser_jssh_objects[:listener_object]
      listener_object[:QueryInterface]=jssh_socket.object(
        "function(aIID)
         { if(aIID.equals(Components.interfaces.nsIWebProgressListener) || aIID.equals(Components.interfaces.nsISupportsWeakReference) || aIID.equals(Components.interfaces.nsISupports))
           { return this;
           }
           throw Components.results.NS_NOINTERFACE;
         }")
      listener_object[:onStateChange]= jssh_socket.object(
        "function(aWebProgress, aRequest, aStateFlags, aStatus)
         { if(aStateFlags & Components.interfaces.nsIWebProgressListener.STATE_STOP && aStateFlags & Components.interfaces.nsIWebProgressListener.STATE_IS_NETWORK)
           { #{@updated_at_epoch_ms.ref}=new Date().getTime();
             #{browser_object.ref}=#{browser_window_object.ref}.getBrowser();
           }
         }")
      browser_object.addProgressListener(listener_object)
    end

    public
    attr_reader :browser_window_object
    attr_reader :content_window_object
    attr_reader :browser_object
    attr_reader :document_object
    attr_reader :body_object
    
    def updated_at
      Time.at(@updated_at_epoch_ms.val/1000.0)+@updated_at_offset
    end

    public
    #   Closes the window.
    def close
      assert_exists
      begin
        browser_window_object.close
        @@jssh_socket.assert_socket
      rescue JsshConnectionError # the socket may disconnect when we close the browser, causing the JsshSocket to complain 
        @@jssh_socket=nil
      end
      @browser_window_object=@browser_object=@document_object=@content_window_object=@body_object=nil
@launched_browser_process=false #TODO/FIX: check here if we originally launched the browser process
      if @launched_browser_process && @@jssh_socket
        quit_browser(:force => false)
      end
    end

    # Closes all firefox windows by quitting the browser 
    def close_all
      quit_browser(:force => false)
    end

    # quits the browser. 
    # quit_browser(:force => true) will force the browser to quit. 
    def quit_browser(options={})
      options=handle_options(options, :force => false)
      # from https://developer.mozilla.org/en/How_to_Quit_a_XUL_Application
      appStartup= jssh_socket.Components.classes['@mozilla.org/toolkit/app-startup;1'].getService(jssh_socket.Components.interfaces.nsIAppStartup)
      quitSeverity = options[:force] ? jssh_socket.Components.interfaces.nsIAppStartup.eForceQuit : jssh_socket.Components.interfaces.nsIAppStartup.eAttemptQuit
      begin
        appStartup.quit(quitSeverity)
        ::Waiter.try_for(8, :exception => Exception::WatirException.new("The browser did not quit")) do
          @@jssh_socket.assert_socket # this should error, going up past the waiter to the rescue block above 
          false
        end
      rescue JsshConnectionError
        @@jssh_socket=nil
      end
      # TODO/FIX: poll to wait for the process itself to finish? the socket closes (which we wait for 
      # above) before the process itself has exited, so if Firefox.new is called between the socket 
      # closing and the process exiting, Firefox pops up with:
      #  Close Firefox
      #  A copy of Firefox is already open. Only one copy of Firefox can be open at a time.
      #  [OK]
      # until that's implemented, just wait for an arbitrary amount of time. (ick)
      sleep 2

      @browser_window_object=@browser_object=@document_object=@content_window_object=@body_object=nil
      nil
    end

    #   Used for attaching pop up window to an existing Firefox window, either by url or title.
    #   ff.attach(:url, 'http://www.google.com')
    #   ff.attach(:title, 'Google')
    #
    # Output:
    #   Instance of newly attached window.
    def attach(how, what)
      @browser_window_object = case how
      when :jssh_object
        what
      else
        find_window(how, what)
      end
      
      unless @browser_window_object
        raise Exception::NoMatchingWindowFoundException.new("Unable to locate window, using #{how} and #{what}")
      end
      set_browser_document
      self
    end

    # Class method to return a browser object if a window matches for how
    # and what. Window can be referenced by url or title.
    # The second argument can be either a string or a regular expression.
    # Watir::Browser.attach(:url, 'http://www.google.com')
    # Watir::Browser.attach(:title, 'Google')
    def self.attach how, what
      new(:attach => [how, what])
    end

    # loads up a new window in an existing process
    # Watir::Browser.attach() with no arguments passed the attach method will create a new window
    # this will only be called one time per instance we're only ever going to run in 1 window

    def open_window
      begin
        @browser_window_name="firewatir_window_%.16x"%rand(2**64)
      end while jssh_socket.value_json("$A(getWindows()).detect(function(win){return win.name==#{@browser_window_name.to_jssh}}) ? true : false")
      watcher=jssh_socket.Components.classes["@mozilla.org/embedcomp/window-watcher;1"].getService(jssh_socket.Components.interfaces.nsIWindowWatcher)
      # nsIWindowWatcher is used to launch new top-level windows. see https://developer.mozilla.org/en/Working_with_windows_in_chrome_code
      
      @browser_window_object=@browser_jssh_objects[:browser_window]=watcher.openWindow(nil, 'chrome://browser/content/browser.xul', @browser_window_name, 'resizable', nil)
      return @browser_window_object
    end
    private :open_window

    def self.each
      each_browser_window_object do |win|
        yield self.attach(:jssh_object, win)
      end
    end

    def self.each_browser_window_object
      mediator=jssh_socket.Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(jssh_socket.Components.interfaces.nsIWindowMediator)
      enumerator=mediator.getEnumerator("navigator:browser")
      while enumerator.hasMoreElements
        win=enumerator.getNext
        yield win
      end
      nil
    end
    def self.browser_window_objects
      window_objects=[]
      each_browser_window_object do |window_object|
        window_objects << window_object
      end
      window_objects
    end
    def self.each_window_object
      mediator=jssh_socket.Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(jssh_socket.Components.interfaces.nsIWindowMediator)
      enumerator=mediator.getEnumerator(nil)
      while enumerator.hasMoreElements
        win=enumerator.getNext
        yield win
      end
      nil
    end
    def self.window_objects
      window_objects=[]
      each_window_object do |window_object|
        window_objects << window_object
      end
      window_objects
    end
    
    # return the window jssh object for the browser window with the given title or url.
    #   how - :url or :title
    #   what - string or regexp
    #
    # Start searching windows in reverse order so that we attach/find the latest opened window.
    def find_window(how, what)
      orig_how=how
      hows={ :title => proc{|content_window| content_window.title },
             :URL => proc{|content_window| content_window.location.href },
           }
      how=hows.keys.detect{|h| h.to_s.downcase==orig_how.to_s.downcase}
      raise ArgumentError, "how should be one of: #{hows.keys.inspect} (was #{orig_how.inspect})" unless how
      found_win=nil
      self.class.each_browser_window_object do |win|
        found_win=win if Watir::fuzzy_match(hows[how].call(win.getBrowser.contentDocument),what)
        # we don't break here if found_win is set because we want the last match if there are multiple. 
      end
      return found_win
    end
    private :find_window

    #
    # Description:
    #   Matches the given text with the current text shown in the browser.
    #
    # Input:
    #   target - Text to match. Can be a string or regex
    #
    # Output:
    #   Returns the index if the specified text was found.
    #   Returns matchdata object if the specified regexp was found.
    #
    def contains_text(target)
      case target
      when Regexp
        self.text.match(target)
      when String
        self.text.index(target)
      else
        raise TypeError, "Argument #{target} should be a string or regexp."
      end
    end

    #   Returns the Status of the page currently loaded in the browser from statusbar.
    #
    # Output:
    #   Status of the page.
    #
    def status
      #content_window_object.status
      browser_window_object.XULBrowserWindow.statusText
    end

    # Returns the text of the page currently loaded in the browser.
    def text
      body_object.textContent
    end

    # Maximize the current browser window.
    def maximize()
      browser_window_object.maximize
    end

    # Minimize the current browser window.
    def minimize()
      browser_window_object.minimize
    end

    ARBITRARY_TIMEOUT=30 # seconds 
    # Waits for the page to get loaded.
    def wait(options={})
      return unless exists?
      unless options.is_a?(Hash)
        raise ArgumentError, "given options should be a Hash, not #{options.inspect} (#{options.class})\nold conflicting arguments of no_sleep or last_url are gone"
      end
      options={:sleep => false, :last_url => nil}.merge(options)
      started=Time.now
      while browser_object.webProgress.isLoadingDocument
        sleep 0.1
        if Time.now - started > ARBITRARY_TIMEOUT
          raise "Page Load Timeout"
        end
      end

      # If the redirect is to a download attachment that does not reload this page, this
      # method will loop forever. Therefore, we need to ensure that if this method is called
      # twice with the same URL, we simply accept that we're done.
      url= document_object.URL

      if(url != options[:last_url])
        # Check for Javascript redirect. As we are connected to Firefox via JSSh. JSSh
        # doesn't detect any javascript redirects so check it here.
        # If page redirects to itself that this code will enter in infinite loop.
        # So we currently don't wait for such a page.
        # wait variable in JSSh tells if we should wait more for the page to get loaded
        # or continue. -1 means page is not redirected. Anyother positive values means wait.
        metas=document_object.getElementsByTagName 'meta'
        wait_time=metas.to_array.map do |meta|
          if meta.httpEquiv =~ /^refresh$/i && (content_split=meta.content.split(';'))[1]!=url
            content_split[0].to_i
          end
        end.compact.max
        
        if wait_time
          sleep(wait_time)
          wait(:last_url => url)
        end    
      end
      run_error_checks
      return self
    end

    # Add an error checker that gets called on every page load.
    # * checker - a Proc object
    def add_checker(checker)
      @error_checkers << checker
    end

    # Disable an error checker
    # * checker - a Proc object that is to be disabled
    def disable_checker(checker)
      @error_checkers.delete(checker)
    end

    # Run the predefined error checks. This is automatically called on every page load.
    def run_error_checks
      @error_checkers.each { |e| e.call(self) }
    end


    def startClicker(*args)
      raise NotImplementedError, "startClicker is gone. Use Firefox#modal_dialog.click_button (generally preceded by a Element#click_no_wait)"
    end

    private

    def path_to_bin
      path = @binary_path || begin
        case current_os
        when :windows
          path_from_registry
        when :macosx
          path_from_spotlight
        when :linux
          `which firefox`.strip
        end
      end
      raise "unable to locate Firefox executable" if path.nil? || path.empty?
      path
    end

    def current_os
      @current_os ||= begin
        platform= RUBY_PLATFORM =~ /java/ ? java.lang.System.getProperty("os.name") : RUBY_PLATFORM
        case platform
        when /mswin|windows|mingw32/i
          :windows
        when /darwin|mac os/i
          :macosx
        when /linux/i
          :linux
        else
          raise "Unidentified platform #{platform}"
        end
      end
    end

    def path_from_registry
      raise NotImplementedError, "(need to know how to access windows registry on JRuby)" if RUBY_PLATFORM =~ /java/
      require 'win32/registry'
      lm = ::Win32::Registry::HKEY_LOCAL_MACHINE
      lm.open('SOFTWARE\Mozilla\Mozilla Firefox') do |reg|
        reg1 = lm.open("SOFTWARE\\Mozilla\\Mozilla Firefox\\#{reg.keys[0]}\\Main")
        if entry = reg1.find { |key, type, data| key =~ /pathtoexe/i }
          return entry.last
        end
      end
    end

    def path_from_spotlight
      ff = %x[mdfind 'kMDItemCFBundleIdentifier == "org.mozilla.firefox"']
      ff = ff.empty? ? '/Applications/Firefox.app' : ff.split("\n").first

      "#{ff}/Contents/MacOS/firefox-bin"
    end

    private
    def base_element_class
      Firefox::Element
    end
    def browser_class
      Firefox
    end
  end # Firefox
end # FireWatir
