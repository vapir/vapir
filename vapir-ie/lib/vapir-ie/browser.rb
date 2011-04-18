require 'vapir-ie/container'
require 'vapir-ie/page_container'
require 'vapir-ie/close_all'
require 'vapir-ie/modal_dialog'
require 'vapir-ie/win32ole'
require 'vapir-ie/ie-process'
require 'vapir-ie/logger'

module Vapir
  class IE < Browser
    include Vapir::Exception
    include IE::PageContainer
    
    # IE inserts some element whose tagName is empty and just acts as block level element
    # Probably some IE method of cleaning things
    # To pass the same to the xml parser we need to give some name to empty tagName
    EMPTY_TAG_NAME = "DUMMY"
    
    # The time, in seconds, it took for the new page to load after executing the
    # the last command
    attr_reader :down_load_time
    
    # access to the logger object
    attr_accessor :logger
    
    # this contains the list of unique urls that have been visited
    attr_reader :url_list
    
    class << self
      # Create a new IE window in a new process. 
      # This method will not work when
      # Vapir/Ruby is run under a service (instead of a user).
      def new_process(options={})
        new(options.merge(:new_process => true))
      end

      # Create a new IE window in a new process, starting at the specified URL. 
      # Same as IE.start.
      def start_process(url='about:blank', options={})
        new(options.merge(:new_process => true, :goto => url))
      end

      # Yields successively to each IE window on the current desktop. Takes a block.
      # This method will not work when
      # Vapir/Ruby is run under a service (instead of a user).
      # Yields to the window and its hwnd.
      def each_browser
        each_browser_object do |browser_object|
          yield attach(:browser_object, browser_object)
        end
      end
      alias each each_browser
      def browsers
        Enumerator.new(self, :each_browser)
      end

      # yields a WIN32OLE of each IE browser object that is available. 
      def each_browser_object
        shell = WIN32OLE.new('Shell.Application')
        shell.Windows.each do |window|
          if (window.path =~ /Internet Explorer/ rescue false) && (window.hwnd rescue false)
            yield window
          end
        end
      end
      def browser_objects
        Enumerator.new(self, :each_browser_object)
      end

    end
    
    # Create an IE browser.
    #
    # Takes a hash of options:
    # - :timeout - the number of seconds to wait for a window to appear when 
    #   attaching or launching. 
    # - :goto - a url to which the IE browser will navigate. by default this 
    #   is 'about:blank' for newly-launched IE instances, and the default is 
    #   not to navigate anywhere for attached instances. 
    # - :new_process - true or false, default is false. whether to launch this 
    #   IE instance as its own process (this has no effect if :attach is 
    #   specified)
    # - :attach - a two-element Array of [how, what] where how is one of:
    #   - :title - a string or regexp matching the title of the browser that
    #     should be attached to. 
    #   - :URL - a string or regexp matching the URL of the browser that 
    #     should be attached to. 
    #   - :HWND - specifies the HWND of the browser that should be attached to. 
    #   - :name - the name of the window (as specified in the second argument to a 
    #     window.open() javascript call) 
    #   - :browser_object - this is generally just used internally. 'what' 
    #     is a WIN32OLE object representing the browser. 
    #   - :wait - true or false, default is true. whether to wait for the browser
    #     to be ready before continuing. 
    def initialize(method_options = {})
      if method_options==true || method_options==false
        raise NotImplementedError, "#{self.class.name}.new takes an options hash - passing a boolean for 'suppress_new_window' is no longer supported. Please see the documentation for #{self.class}.new"
      end
      options = options_from_config(method_options, {:timeout => :attach_timeout, :new_process => :ie_launch_new_process, :wait => :wait, :visible => :browser_visible}, [:attach, :goto])

      @error_checkers = []
      
      @logger = DefaultLogger.new
      @url_list = []

      if options[:attach]
        how, what = *options[:attach]
        if how== :browser_object
          @browser_object = what
        else
          orig_how=how
          hows={ :title => proc{|bo| bo.document.title },
                 :URL => proc{|bo| bo.locationURL },
                 :name => proc{|bo| bo.document.parentWindow.name },
                 :HWND => proc{|bo| bo.HWND },
               }
          how=hows.keys.detect{|h| h.to_s.downcase==orig_how.to_s.downcase}
          raise ArgumentError, "how should be one of: #{hows.keys.inspect} (was #{orig_how.inspect})" unless how
          @browser_object = ::Waiter.try_for(options[:timeout], :exception => NoMatchingWindowFoundException.new("Unable to locate a window with #{how} of #{what}")) do
            self.class.browser_objects.detect do |browser_object|
              begin
                Vapir::fuzzy_match(hows[how].call(browser_object), what)
              rescue WIN32OLERuntimeError, NoMethodError
                false
              end
            end
          end
        end
        if method_options.key?(:visible)
          # only set visibility if it's explicitly in the options given to the method - don't set from config when using attach 
          self.visible= method_options[:visible]
        end
      else
        if options[:new_process]
          iep = Process.start
          @browser_object = iep.browser_object(:timeout => options[:timeout])
          @process_id = iep.process_id
        else
          @browser_object = WIN32OLE.new('InternetExplorer.Application')
        end
        self.visible= options[:visible]
        goto('about:blank')
      end
      goto(options[:goto]) if options[:goto]
      wait if options[:wait]
      self
    end

    def visible
      assert_exists
      @browser_object.visible
    end
    def visible=(visibility)
      assert_exists
      @browser_object.visible = visibility
    end
    
    # the WIN32OLE Internet Explorer object
    #
    # See: http://msdn.microsoft.com/en-us/library/aa752085%28v=VS.85%29.aspx
    # and http://msdn.microsoft.com/en-us/library/aa752084%28v=VS.85%29.aspx
    attr_reader :browser_object
    alias ie browser_object
    
    # Return the window handle of this browser
    def hwnd
      assert_exists
      @hwnd ||= @browser_object.hwnd
    end

    # returns the process id of this browser 
    def process_id
      @process_id ||= win_window.process_id
    end
    # kills this process. NOTE that this process may be running
    # multiple browsers; killing the process will kill them all. 
    # use #close to close a single browser. 
    def kill
      # todo: drop win32api; use ffi 
      require 'Win32API'
      right_to_terminate_process = 1
      handle = Win32API.new('kernel32.dll', 'OpenProcess', 'lil', 'l').
      call(right_to_terminate_process, 0, process_id)
      Win32API.new('kernel32.dll', 'TerminateProcess', 'll', 'l').call(handle, 0)
    end
    
    def win_window
      Vapir.require_winwindow
      @win_window||= WinWindow.new(hwnd)
    end
    
    def modal_dialog(options={})
      assert_exists do
        raise ArgumentError, "options argument must be a hash; received #{options.inspect} (#{options.class})" unless options.is_a?(Hash)
        modal=IE::ModalDialog.new(self, options.merge(:error => false))
        modal.exists? ? modal : nil
      end
    end
    
    def modal_dialog!(options={})
      assert_exists do
        IE::ModalDialog.new(self, options.merge(:error => true))
      end
    end

    # we expect one of these error codes when quitting or checking existence. 
    ExistenceFailureCodesRE = Regexp.new(
      { '0x800706ba' => 'The RPC server is unavailable',
        '0x80010108' => 'The object invoked has disconnected from its clients.',
        '0x800706be' => 'The remote procedure call failed.',
        '0x800706b5' => 'The interface is unknown.',
        '0x80004002' => 'No such interface supported',
      }.keys.join('|'), Regexp::IGNORECASE)

    # Are we attached to an open browser?
    def exists?
      !!(@browser_object && begin
        @browser_object.name
      rescue WIN32OLERuntimeError, NoMethodError
        raise unless $!.message =~ ExistenceFailureCodesRE
        false
      end)
    end
    alias :exist? :exists?
    
    # deprecated: use logger= instead
    def set_logger(logger)
      @logger = logger
    end
    
    def log(what)
      @logger.debug(what) if @logger
    end
    
    #
    # Accessing data outside the document
    #
    
    # Return the title of the document
    def title
      @browser_object.document.title
    end
    
    # Return the status of the window, typically from the status bar at the bottom.
    def status
      return @browser_object.statusText
    end
    
    #
    # Navigation
    #
    
    # Navigate to the specified URL.
    #  * url - string - the URL to navigate to
    def goto(url)
      assert_exists do
        @browser_object.navigate(url)
        wait
        return @down_load_time
      end
    end
    
    # Go to the previous page - the same as clicking the browsers back button
    # an WIN32OLERuntimeError exception is raised if the browser cant go back
    def back
      assert_exists do
        @browser_object.GoBack
        wait
      end
    end
    
    # Go to the next page - the same as clicking the browsers forward button
    # an WIN32OLERuntimeError exception is raised if the browser cant go forward
    def forward
      assert_exists do
        @browser_object.GoForward
        wait
      end
    end
    
    module RefreshConstants
      # http://msdn.microsoft.com/en-us/library/bb268230%28v=VS.85%29.aspx
      REFRESH_NORMAL = 0
      REFRESH_IFEXPIRED = 1
      REFRESH_COMPLETELY = 3
    end
    # Refresh the current page - the same as clicking the browsers refresh button
    # an WIN32OLERuntimeError exception is raised if the browser cant refresh
    def refresh
      assert_exists do
        @browser_object.refresh2(RefreshConstants::REFRESH_COMPLETELY)
        wait
      end
    end

    # clear the list of urls that we have visited
    def clear_url_list
      @url_list.clear
    end
    
    # Closes the Browser
    def close
      assert_exists
      @browser_object.stop
      @browser_object.quit
      # TODO/fix timeout; this shouldn't be a hard-coded magic number. 
      ::Waiter.try_for(32, :exception => WindowFailedToCloseException.new("The browser window did not close"), :interval => 1) do
        begin
          if exists?
            @browser_object.quit
            false
          else
            true
          end
        rescue WIN32OLERuntimeError, NoMethodError
          raise unless $!.message =~ ExistenceFailureCodesRE
          true
        end
      end
      @browser_object=nil
    end
    
    # Maximize the window (expands to fill the screen)
    def maximize
      win_window.maximize!
    end
    
    # Minimize the window (appears as icon on taskbar)
    def minimize
      win_window.minimize!
    end
    
    # Restore the window (after minimizing or maximizing)
    def restore
      win_window.restore!
    end
    
    # Make the window come to the front
    def bring_to_front
      win_window.really_set_foreground!
    end
    
    def front?
      win_window.foreground?
    end
    
    # Send key events to IE window.
    # See http://www.autoitscript.com/autoit3/docs/appendix/SendKeys.htm
    # for complete documentation on keys supported and syntax.
    def send_keys(key_string)
      assert_exists do
        require 'vapir-ie/autoit'
        bring_to_front
        Vapir.autoit.Send key_string
      end
    end
    
    # saves a screenshot of this browser window to the given filename. 
    #
    # the screenshot format is BMP (DIB), so you should name your files to end with .bmp 
    #
    # the last argument is an optional options hash, taking options:
    # - :dc => (default is :window). may be one of: 
    #   - :client takes a screenshot of the client area, which excludes the menu bar and other window trimmings.
    #   - :window (default) takes a screenshot of the full browser window
    #   - :desktop takes a screenshot of the full desktop
    def screen_capture(filename, options = {})
      unless options.is_a?(Hash)
        dc = options
        options = {:dc => dc}
        if config.warn_deprecated
          Kernel.warn_with_caller("WARNING: The API for #screen_capture has changed and the last argument is now an options hash. Please change calls to this method to specify :dc => #{dc.inspect}")
        end
      end
      screen_capture_win_window(filename, options)
    end
    
    def dir
      return File.expand_path(File.dirname(__FILE__))
    end
    
    #
    # Document and Document Data
    #
    
    # Return the current document
    def document
      assert_exists
      return @browser_object.document
    end
    alias document_object document
    
    def browser
      self
    end
    
    # returns the current url, as displayed in the address bar of the browser
    def url
      assert_exists
      return @browser_object.LocationURL
    end

    # Error checkers
    
    # this method runs the predefined error checks
    def run_error_checks
      assert_exists do
        @error_checkers.each { |e| e.call(self) }
      end
    end
    
    # this method is used to add an error checker that gets executed on every page load
    # *  checker   Proc Object, that contains the code to be run
    def add_checker(checker)
      @error_checkers << checker
    end
    
    # this allows a checker to be disabled
    # *  checker   Proc Object, the checker that is to be disabled
    def disable_checker(checker)
      @error_checkers.delete(checker)
    end

    # this method shows the name, id etc of the object that is currently active - ie the element that has focus
    # its mostly used in irb when creating a script
    def show_active # TODO/fix: move to common; test 
      
      current_object = document.activeElement
      current_element = base_class.factory(current_object)
      current_element.to_s
    end
    
    # Gives focus to the frame
    def focus
      document.activeElement.blur
      document.focus
    end
    
    
    # Functions written for using xpath for getting the elements.
    def xmlparser_document_object
      if @xml_parser_doc == nil
        create_xml_parser_doc
      end
      return @xml_parser_doc
    end

    # Create the Nokogiri object if it is nil. This method is private so can be called only
    # from xmlparser_document_object method.
    def create_xml_parser_doc
      require 'nokogiri'
      if @xml_parser_doc == nil
        htmlSource ="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<HTML>\n"
        htmlSource = html_source(document.body,htmlSource," ")
        htmlSource += "\n</HTML>\n"
        # Angrez: Resolving Jira issue WTR-114
        htmlSource = htmlSource.gsub(/&nbsp;/, '&#160;')
        begin
         #@xml_parser_doc = Nokogiri::HTML::Document.new(htmlSource)
          @xml_parser_doc = Nokogiri.parse(htmlSource)
        rescue => e
          output_xml_parser_doc("error.xml", htmlSource)
          raise e
        end
      end
    end
    private :create_xml_parser_doc
    
    def output_xml_parser_doc(name, text)
      file = File.open(name,"w")
      file.print(text)
      file.close
    end
    private :output_xml_parser_doc
    
    #Function Tokenizes the tag line and returns array of tokens.
    #Token could be either tagName or "=" or attribute name or attribute value
    #Attribute value could be either quoted string or single word
    def tokenize_tagline(outerHtml)
      outerHtml = outerHtml.gsub(/\n|\r/," ")
      #removing "< symbol", opening of current tag
      outerHtml =~ /^\s*<(.*)$/
      outerHtml = $1
      tokens = Array.new
      i = startOffset = 0
      length = outerHtml.length
      #puts outerHtml
      parsingValue = false
      while i < length do
        i +=1 while (i < length && outerHtml[i,1] =~ /\s/)
        next if i == length
        currentToken = outerHtml[i,1]
        
        #Either current tag has been closed or user has not closed the tag >
        # and we have received the opening of next element
        break if currentToken =~ /<|>/
        
        #parse quoted value
        if(currentToken == "\"" || currentToken == "'")
          parsingValue = false
          quote = currentToken
          startOffset = i
          i += 1
          i += 1 while (i < length && (outerHtml[i,1] != quote || outerHtml[i-1,1] == "\\"))
          if i == length
            tokens.push quote + outerHtml[startOffset..i-1]
          else
            tokens.push outerHtml[startOffset..i]
          end
        elsif currentToken == "="
          tokens.push "="
          parsingValue = true
        else
          startOffset = i
          i += 1 while (i < length && !(outerHtml[i,1] =~ /\s|=|<|>/)) if !parsingValue
          i += 1 while (i < length && !(outerHtml[i,1] =~ /\s|<|>/)) if parsingValue
          parsingValue = false
          i -= 1
          tokens.push outerHtml[startOffset..i]
        end
        i += 1
      end
      return tokens
    end
    private :tokenize_tagline
    
    # This function get and clean all the attributes of the tag.
    def all_tag_attributes(outerHtml)
      tokens = tokenize_tagline(outerHtml)
      #puts tokens
      tagLine = ""
      count = 1
      tokensLength = tokens.length
      expectedEqualityOP= false
      while count < tokensLength do
        if expectedEqualityOP == false
          #print Attribute Name
          # If attribute name is valid. Refer: http://www.w3.org/TR/REC-xml/#NT-Name
          if tokens[count] =~ /^(\w|_|:)(.*)$/
            tagLine += " #{tokens[count]}"
            expectedEqualityOP = true
          end
        elsif tokens[count] == "="
          count += 1
          if count == tokensLength
            tagLine += "=\"\""
          elsif(tokens[count][0,1] == "\"" || tokens[count][0,1] == "'")
            tagLine += "=#{tokens[count]}"
          else
            tagLine += "=\"#{tokens[count]}\""
          end
          expectedEqualityOP = false
        else
          #Opps! equality was expected but its not there.
          #Set value same as the attribute name e.g. selected="selected"
          tagLine += "=\"#{tokens[count-1]}\""
          expectedEqualityOP = false
          next
        end
        count += 1
      end
      tagLine += "=\"#{tokens[count-1]}\" " if expectedEqualityOP == true
      #puts tagLine
      return tagLine
    end
    private :all_tag_attributes
    
    # This function is used to escape the characters that are not valid XML data.
    def xml_escape(str)
      str = str.gsub(/&/,'&amp;')
      str = str.gsub(/</,'&lt;')
      str = str.gsub(/>/,'&gt;')
      str = str.gsub(/"/, '&quot;')
      str
    end
    private :xml_escape
    
    # Returns HTML Source
    # Traverse the DOM tree rooted at body element
    # and generate the HTML source.
    # element: Represent Current element
    # htmlString:HTML Source
    # spaces:(Used for debugging). Helps in indentation
    def html_source(element, htmlString, spaceString)
      begin
        tagLine = ""
        outerHtml = ""
        tagName = ""
        begin
          tagName = element.tagName.downcase
          tagName = EMPTY_TAG_NAME if tagName == ""
          # If tag is a mismatched tag.
          if !(tagName =~ /^(\w|_|:)(.*)$/)
            return htmlString
          end
        rescue
          #handling text nodes
          htmlString += xml_escape(element.toString)
          return htmlString
        end
        #puts tagName
        #Skip comment and script tag
        if tagName =~ /^!/ || tagName== "script" || tagName =="style"
          return htmlString
        end
        #tagLine += spaceString
        outerHtml = all_tag_attributes(element.outerHtml) if tagName != EMPTY_TAG_NAME
        tagLine += "<#{tagName} #{outerHtml}"
        
        canHaveChildren = element.canHaveChildren
        if canHaveChildren
          tagLine += ">"
        else
          tagLine += "/>" #self closing tag
        end
        #spaceString += spaceString
        htmlString += tagLine
        childElements = element.childnodes
        childElements.each do |child|
          htmlString = html_source(child,htmlString,spaceString)
        end
        if canHaveChildren
          #tagLine += spaceString
          tagLine ="</" + tagName + ">"
          htmlString += tagLine
        end
        return htmlString
      rescue => e
        puts e.to_s
      end
      return htmlString
    end
    private :html_source
    
    public
    # return the first element object (not Element) that matches the xpath
    def element_object_by_xpath(xpath)
      objects= element_objects_by_xpath(xpath)
      return (objects && objects[0])
    end
    
    # execute xpath and return an array of elements
    def element_objects_by_xpath(xpath)
      doc = xmlparser_document_object 
      modifiedXpath = ""
      selectedElements = Array.new
      
      # strip any trailing slash from the xpath expression (as used in watir unit tests)
      xpath.chop! unless (/\/$/ =~ xpath).nil?
      
      doc.xpath(xpath).each do |element|
        modifiedXpath = element.path
        temp = element_by_absolute_xpath(modifiedXpath) # temp = a DOM/COM element
        selectedElements << temp if temp != nil
      end
      return selectedElements
    end
    
    # Method that iterates over IE DOM object and get the elements for the given
    # xpath.
    def element_by_absolute_xpath(xpath)
      curElem = nil
      
      #puts "Hello; Given xpath is : #{xpath}"
      doc = document
      curElem = doc.getElementsByTagName("body").item(0)
      xpath =~ /^.*\/body\[?\d*\]?\/(.*)/
      xpath = $1
      
      if xpath == nil
        puts "Function Requires absolute XPath."
        return
      end
      
      arr = xpath.split(/\//)
      return nil if arr.length == 0
      
      lastTagName = arr[arr.length-1].to_s.upcase
      
      # lastTagName is like tagName[number] or just tagName. For the first case we need to
      # separate tagName and number.
      lastTagName =~ /(\w*)\[?\d*\]?/
      lastTagName = $1
      #puts lastTagName
      
      for element in arr do
        element =~ /(\w*)\[?(\d*)\]?/
        tagname = $1
        tagname = tagname.upcase
        
        if $2 != nil && $2 != ""
          index = $2
          index = "#{index}".to_i - 1
        else
          index = 0
        end
        
        #puts "#{element} #{tagname} #{index}"
        allElemns = curElem.childnodes
        if allElemns == nil || allElemns.length == 0
          puts "#{element} is null"
          next # Go to next element
        end
        
        #puts "Current element is : #{curElem.tagName}"
        allElemns.each do |child|
          gotIt = false
          begin
            curTag = child.tagName
            curTag = EMPTY_TAG_NAME if curTag == ""
          rescue
            next
          end
          #puts child.tagName
          if curTag == tagname
            index-=1
            if index < 0
              curElem = child
              break
            end
          end
        end
        
      #puts "Node selected at index #{index.to_s} : #{curElem.tagName}"
      end
      begin
        if curElem.tagName == lastTagName
          #puts curElem.tagName
          return curElem
        else
          return nil
        end
      rescue
        return nil
      end
    end
    private :element_by_absolute_xpath
    
    private
    def base_element_class
      IE::Element
    end
    def browser_class
      IE
    end
    
  end # class IE
  module WatirConfigCompatibility
    module Visible
      def visible
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #visible is deprecated; please use the new config framework with config.browser_visible"
        end
        config.browser_visible
      end
      def visible= visibility
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #visible= is deprecated; please use the new config framework with config.browser_visible="
        end
        config.browser_visible=visibility
      end
    end
    Vapir::IE.send(:extend, Visible)
  end
end
