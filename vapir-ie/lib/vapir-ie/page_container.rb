require 'vapir-ie/container'
require 'vapir-common/page_container'

module Vapir
  # A PageContainer contains an HTML Document. In other words, it is a 
  # what JavaScript calls a Window.
  #
  # this assumes that document_object is defined on the includer. 
  module IE::PageContainer
    include Vapir::PageContainer

    # Used internally to determine when IE has finished loading a page
    # http://msdn.microsoft.com/en-us/library/system.windows.forms.webbrowserreadystate.aspx
    # http://msdn.microsoft.com/en-us/library/system.windows.forms.webbrowser.readystate.aspx
    module WebBrowserReadyState
      Uninitialized = 0 # No document is currently loaded.
      Loading       = 1 # The control is loading a new document.
      Loaded        = 2 # The control has loaded and initialized the new document, but has not yet received all the document data.
      Interactive   = 3 # The control has loaded enough of the document to allow limited user interaction, such as clicking hyperlinks that have been displayed.
      Complete      = 4 # The control has finished loading the new document and all its contents.
    end
    READYSTATE_COMPLETE = WebBrowserReadyState::Complete
       
    include IE::Container
    include Vapir::Exception

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
    
    def content_window_object
      document_object.parentWindow
    end
    
    # The HTML of the current page
    def html
      document_element.outerHTML
    end
    
    # The text of the current page
    def text
      document_element.innerText
    end

    def close
      content_window_object.close
    end

    # Execute the given JavaScript string
    def execute_script(source)
      retried=false
      result=nil
      begin
        result=document_object.parentWindow.eval(source)
      rescue WIN32OLERuntimeError, NoMethodError
        # don't retry more than once; don't catch anything but the particular thing we're looking for 
        if retried || $!.message !~ /unknown property or method:? `eval'/
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
        ::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => "The browser was still busy after #{options[:timeout]} seconds") do
          return unless exists?
          !browser_object.busy
        end
        ::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => "The browser's readyState was still not ready for interaction after #{options[:timeout]} seconds") do
          return unless exists?
          [WebBrowserReadyState::Interactive, WebBrowserReadyState::Complete].include?(browser_object.readyState)
        end
      end
      # if the document object is gone, then we want to just return. 
      # in subsequent code where we want the document object, we will call this proc 
      # so that we don't have to deal with checking for error / returning every time. 
      doc_or_ret = proc do
        begin
          document_object
        rescue WIN32OLERuntimeError, NoMethodError
          return
        end
      end
      ::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => "The browser's document was still not defined after #{options[:timeout]} seconds") do
        return unless exists?
        doc_or_ret.call
      end
      urls=[]
      all_frames_complete_result=::Waiter.try_for(options[:timeout]-(Time.now-start_load_time), :interval => options[:interval], :exception => nil, :condition => proc{|result| result==true }) do
        return unless exists?
        all_frames_complete?(doc_or_ret.call, urls)
      end
      case all_frames_complete_result
      when false
        raise "A frame on the browser did not come into readyState complete after #{options[:timeout]} seconds"
      when ::Exception
        message = "A frame on the browser encountered an error.\n"
        if all_frames_complete_result.message =~ /0x80070005/
          message += "An 'Access is denied' error might be fixed by adding the domain of the site to your 'Trusted Sites'.\n"
        end
        message+="Original message was:\n\n"
        message+=all_frames_complete_result.message
        raise all_frames_complete_result.class, message, all_frames_complete_result.backtrace
      when true
        # dandy; carry on. 
      else
        # this should never happen. 
        raise "Unexpected result from all_frames_complete?: #{all_frames_complete_result.inspect}"
      end
      @url_list=(@url_list || [])+urls
      
      @down_load_time= Time.now - start_load_time
      run_error_checks if respond_to?(:run_error_checks)
      sleep @pause_after_wait if options[:sleep]
      @down_load_time
    end
    alias page_container_wait wait # alias this so that Frame can clobber the #wait method 
    
    private
    # this returns true if all frames are complete. 
    # it returns false if a frame is incomplete. 
    # if an unexpected exception is encountered, it returns that exception. yes, returns, not raises, 
    # due to the fact that an exception may indicate either the frame not being complete, or an actual
    # error condition - it is difficult to differentiate. in the usage above, in #wait, we check
    # if an exception is still being raised at the end of the specified interval, and raise it if so. 
    # if it stops being raised, we carry on. 
    def all_frames_complete?(document, urls=nil)
      begin
        if urls && !urls.include?(document.location.href)
          urls << document.location.href
        end
        frames=document.frames
        return ['complete', 'interactive'].include?(document.readyState) && (0...frames.length).all? do |i|
          frame=document.frames[i.to_s]
          frame_document=begin
            frame.document
          rescue WIN32OLERuntimeError, NoMethodError
            $!
          end
          case frame_document
          when nil
            # frame hasn't loaded to the point where it has a document yet 
            false
          when WIN32OLE
            # frame has a document - check recursively 
            all_frames_complete?(frame_document, urls)
          when WIN32OLERuntimeError, NoMethodError
            # if we get a WIN32OLERuntimeError with access denied, that is probably a 404 and it's not going 
            # to load, so no reason to keep waiting for it - consider it 'complete' and return true. 
            # there's probably a better method of determining this but I haven't found it yet. 
            true
          else # don't know what we'd have here 
            raise RuntimeError, "unknown frame.document: #{frame_document.inspect} (#{frame_document.class})"
          end
        end
      rescue WIN32OLERuntimeError, NoMethodError
        return $!
      end
    end
  end # module
end