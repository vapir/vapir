module Watir    
  # A PageContainer contains an HTML Document. In other words, it is a 
  # what JavaScript calls a Window.
  #
  # this assumes that document_object is defined on the includer. 
  module IE::PageContainer
    # Used internally to determine when IE has finished loading a page
    READYSTATE_COMPLETE = 4
       
    def containing_object
      document_object
    end
    include IE::Container
    include Watir::Exception

    # This method checks the currently displayed page for http errors, 404, 500 etc
    # It gets called internally by the wait method, so a user does not need to call it explicitly
    def check_for_http_error
      # check for IE7
      n = self.document.invoke('parentWindow').navigator.appVersion
      m=/MSIE\s(.*?);/.match( n )
      if m and m[1] =='7.0'
        if m = /HTTP (\d\d\d.*)/.match( self.title )
          raise NavigationException, m[1]
        end
      else
        # assume its IE6
        url = self.document.location.href
        if /shdoclc.dll/.match(url)
          m = /id=IEText.*?>(.*?)</i.match(self.html)
          raise NavigationException, m[1] if m
        end
      end
      false
    end 
    
    def document_element
      document_object.documentElement
    end
    def content_window_object
      document_object.parentWindow
    end
    
    def page_container
      self
    end

    # The HTML of the current page
    def html
      document_element.outerHTML
    end
    
    # The url of the page object. 
    def url
      document_object.location.href
    end
    
    # The text of the current page
    def text
      document_element.innerText
    end

    def close
      content_window_object.close
    end

    def title
      document_object.title
    end

    # Execute the given JavaScript string
    def execute_script(source)
      retried=false
      result=nil
      begin
        result=document_object.parentWindow.eval(source)
      rescue WIN32OLERuntimeError
        # don't retry more than once; don't catch anything but the particular thing we're looking for 
        if retried || $!.message.split("\n").map{|line| line.strip}!=["unknown property or method `eval'","HRESULT error code:0x80020006","Unknown name."]
          raise
        end
        # this can happen if no scripts have executed at all - the 'eval' function doesn't exist. 
        # execScript works, but behaves differently than eval (it doesn't return anything) - but 
        # once an execScript has run, eval is subsequently defined. so, execScript a blank script, 
        # and then try again with eval.
        document.parentWindow.execScript('null')
        retried=true
        retry
      end
      return result
    end
    
    # Block execution until the page has loaded.
    # =nodoc
    # Note: This code needs to be prepared for the ie object to be closed at 
    # any moment!
    def wait(options={})
      unless options.is_a?(Hash)
        raise ArgumentError, "given options should be a Hash, not #{options.inspect} (#{options.class})\nold conflicting arguments of no_sleep or last_url are gone"
      end
      options={:sleep => false, :interval => 0.1, :timeout => 120}.merge(options)
      @xml_parser_doc = nil
      @down_load_time = nil
      start_load_time = Time.now
      
      if respond_to?(:browser_object)
        ::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => "The browser was still busy at the end of the specified interval") do
          return unless exists?
          !browser_object.busy
        end
        ::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => "The browser's readyState was still not READYSTATE_COMPLETE at the end of the specified interval") do
          return unless exists?
          browser_object.readyState == READYSTATE_COMPLETE
        end
      end
      ::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => "The browser's document was still not defined at the end of the specified interval") do
        return unless exists?
        document_object
      end
      urls=[]
      ::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => "A frame on the browser did not come into readyState complete by the end of the specified interval") do
        return unless exists?
        all_frames_complete?(document_object, urls)
      end
      @url_list=(@url_list || [])+urls
      
      @down_load_time= Time.now - start_load_time
      run_error_checks if respond_to?(:run_error_checks)
      sleep @pause_after_wait if options[:sleep]
      @down_load_time
    end
    
    private
    def all_frames_complete?(document, urls=nil)
      begin
        if urls && !urls.include?(document.location.href)
          urls << document.location.href
        end
        frames=document.frames
        return document.readyState=='complete' && (0...frames.length).all? do |i|
          frame=document.frames[i.to_s]
          frame_document=begin
            frame.document
          rescue WIN32OLERuntimeError
            $!
          end
          case frame_document
          when nil
            # frame hasn't loaded to the point where it has a document yet 
            false
          when WIN32OLE
            # frame has a document - check recursively 
            all_frames_complete?(frame_document, urls)
          when WIN32OLERuntimeError 
            # if we get a WIN32OLERuntimeError with access denied, that is probably a 404 and it's not going 
            # to load, so no reason to keep waiting for it - consider it 'complete' and return true. 
            # there's probably a better method of determining this but I haven't found it yet. 
            true
          else # don't know what we'd have here 
            raise RuntimeError, "unknown frame.document: #{frame_document.inspect} (#{frame_document.class})"
          end
        end
      rescue WIN32OLERuntimeError
        false
      end
    end
    public
    # Search the current page for specified text or regexp.
    # Returns the index if the specified text was found.
    # Returns matchdata object if the specified regexp was found.
    # 
    # *Deprecated* 
    # Instead use 
    #   IE#text.include? target 
    # or
    #   IE#text.match target
    def contains_text(target)
        if target.kind_of? Regexp
          self.text.match(target)
        elsif target.kind_of? String
          self.text.index(target)
        else
          raise ArgumentError, "Argument #{target} should be a string or regexp."
        end
    end

  end # module
end