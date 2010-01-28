require 'watir/win_window'

module Watir
  DEFAULT_MODAL_TIMEOUT=4
  class IEModalDialog
    def initialize(browser, options={})
      options={:timeout => DEFAULT_MODAL_TIMEOUT}.merge(options)
      @browser=browser
      @browser_win=browser.win_window
      @popup_win=::Waiter.try_for(options[:timeout], :exception => Watir::Exception::NoMatchingWindowFoundException.new("No popup was found on the browser")) do
        @browser_win.enabled_popup
      end
    end
    
    def exists?
      @popup_win.exists?
    end
    
    def text
      @popup_win.children.select{|child| child.class_name.downcase=='static' && child.text!=''}.map{|c| c.text }.join(' ')
    end
    
    def set_text_field(value)
      edit_field=@popup_win.children.detect{|child| child.class_name=='Edit'} || (raise "No Edit field in the popup!")
      edit_field.send_set_text!(value)
      value
    end
    
    def click_button(button_text)
      @popup_win.click_child_button_try_for!(button_text, DEFAULT_MODAL_TIMEOUT)
    end
    
    def hwnd
      @popup_win.hwnd
    end
    def win_window
      @popup_win
    end
    
    def document
      IEModalDialogDocument.new(self)
    end
  end
  class IEModalDialogDocument
    include IEContainer
    include IEPageContainer
    @@iedialog_file = (File.expand_path(File.dirname(__FILE__) + '/..') + "/watir/IEDialog/Release/IEDialog.dll").gsub('/', '\\')

    GetUnknown = Win32API.new(@@iedialog_file, 'GetUnknown', ['l', 'p'], 'v')
    def initialize(modal_dialog)
      @modal_dialog=modal_dialog
      options={:timeout => DEFAULT_MODAL_TIMEOUT}
      
      intUnknown = nil
      ::Waiter.try_for(options[:timeout], :exception => "Unable to attach to Modal Window after #{options[:timeuot]} seconds.") do
        intPointer = [0].pack("L") # will contain the int value of the IUnknown*
        GetUnknown.call(@modal_dialog.hwnd, intPointer)
        intArray = intPointer.unpack('L')
        intUnknown = intArray.first
        intUnknown > 0
      end
      
      @document_object = WIN32OLE.connect_unknown(intUnknown)
    end
    attr_reader :document_object
    alias containing_object document_object
    def locate!
      true
    end
  end
end
=begin
module Watir
  class IEModalDialog
    include IEContainer
    include IEPageContainer
    include Win32

    # Return the current window handle
    attr_reader :hwnd

    def find_modal_from_window
      # Use handle of our parent window to see if we have any currently
      # enabled popup.
      hwnd = @container.hwnd
      hwnd_modal = 0
      begin
        Watir::until_with_timeout do
          hwnd_modal, arr = GetWindow.call(hwnd, GW_ENABLEDPOPUP) # GW_ENABLEDPOPUP = 6
          hwnd_modal > 0
        end
      rescue TimeOutException
        return nil
      end
      if hwnd_modal == hwnd || hwnd_modal == 0
        hwnd_modal = nil
      end
      @hwnd = hwnd_modal
    end
    private :find_modal_from_window

    def locate
      how = @how
      what = @what

      case how
      when nil
        unless find_modal_from_window
          raise NoMatchingWindowFoundException, 
            "Modal Dialog not found. Timeout = #{Watir::IE.attach_timeout}"
        end
      when :title
        case what.class.to_s
        # TODO: re-write like WET's so we can select on regular expressions too.
        when "String"
          begin
            Watir::until_with_timeout do
              title = "#{what} -- Web Page Dialog"
              @hwnd, arr = FindWindowEx.call(0, 0, nil, title)
              @hwnd > 0
            end
          rescue TimeOutException
            raise NoMatchingWindowFoundException, 
              "Modal Dialog with title #{what} not found. Timeout = #{Watir::IE.attach_timeout}"
          end
        else
          raise ArgumentError, "Title value must be String"
        end
      else
        raise ArgumentError, "Only null and :title methods are supported"
      end

      intUnknown = 0
      begin
        Watir::until_with_timeout do
          intPointer = " " * 4 # will contain the int value of the IUnknown*
          GetUnknown.call(@hwnd, intPointer)
          intArray = intPointer.unpack('L')
          intUnknown = intArray.first
          intUnknown > 0
        end
      rescue TimeOutException => e        
        raise NoMatchingWindowFoundException, 
          "Unable to attach to Modal Window #{what.inspect} after #{e.duration} seconds."
      end
      
      copy_test_config @parent_container
      @document = WIN32OLE.connect_unknown(intUnknown)
    end

    def initialize(container, how, what=nil)
      set_container container
      @how = how
      @what = what
      @parent_container = container
      # locate our modal dialog's Document object and save it
      begin
        locate
      rescue NoMethodError => e
        message = 
          "IE#modal_dialog not supported with the current version of Ruby (#{RUBY_VERSION}).\n" + 
          "See http://jira.openqa.org/browse/WTR-2 for details.\n" +
            e.message
        raise NoMethodError.new(message)
      end
    end

    def document
      @document
    end
    
    # Return the title of the document
    def title
      document.title
    end

    def close
      document.parentWindow.close
    end

    def attach_command
      "Watir::IE.find(:hwnd, #{@container.hwnd}).modal_dialog"
    end
      
    def wait(options={})
    end
    
    # Return true if the modal exists. Mostly this is useful for testing whether
    # a modal has closed.
    def exists?
      Watir::Win32::window_exists? @hwnd
    end
    alias :exist? :exists?
  end
end
=end