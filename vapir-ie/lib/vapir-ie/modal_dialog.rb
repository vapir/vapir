require 'vapir-common/modal_dialog'
require 'vapir-ie/page_container'

module Vapir
  class IE::ModalDialog
    include Vapir::ModalDialog
    def locate
      @modal_window=@browser.win_window.enabled_popup
    end
    
    def exists?
      @modal_window && @modal_window.exists?
    end
    
    def text
      assert_exists
      @modal_window.children.select{|child| child.class_name.downcase=='static' && child.text!=''}.map{|c| c.text }.join(' ')
    end
    
    def set_text_field(value)
      assert_exists
      edit_field=@modal_window.children.detect{|child| child.class_name=='Edit'} || (raise "No Edit field in the popup!")
      edit_field.send_set_text!(value)
      value
    end
    
    def click_button(button_text, options={})
      assert_exists
      options=handle_options(options, :timeout => ModalDialog::DEFAULT_TIMEOUT)
      @modal_window.click_child_button_try_for!(button_text, options[:timeout])
    end
    
    def close
      if (document=IE::ModalDialogDocument.new(self, :error => false, :timeout => 0)) && document.exists?
        document.close
      else
        @modal_window.send_close!
      end
      ::Waiter.try_for(ModalDialog::DEFAULT_TIMEOUT, :exception => Vapir::Exception::WindowException.new("The modal window failed to close")) do
        !exists?
      end
    end
    
    def hwnd
      assert_exists
      @modal_window.hwnd
    end
    def win_window
      @modal_window
    end
    
    def document
      assert_exists
      IE::ModalDialogDocument.new(self)
    end
  end
  class IE::ModalDialogDocument
    include IE::PageContainer
    @@iedialog_file = (File.expand_path(File.dirname(__FILE__) + '/..') + "/vapir-ie/IEDialog/Release/IEDialog.dll").gsub('/', '\\')

    def get_unknown(*args)
      require 'Win32API'
      @@get_unknown ||= Win32API.new(@@iedialog_file, 'GetUnknown', ['l', 'p'], 'v')
      @@get_unknown.call(*args)
    end
    def initialize(containing_modal_dialog, options={})
      options=handle_options(options, :timeout => ModalDialog::DEFAULT_TIMEOUT, :error => true)
      @containing_modal_dialog=containing_modal_dialog
      
      intUnknown = nil
      ::Waiter.try_for(options[:timeout], :exception => (options[:error] && "Unable to attach to Modal Window after #{options[:timeout]} seconds.")) do
        intPointer = [0].pack("L") # will contain the int value of the IUnknown*
        get_unknown(@containing_modal_dialog.hwnd, intPointer)
        intArray = intPointer.unpack('L')
        intUnknown = intArray.first
        intUnknown > 0
      end
      if intUnknown && intUnknown > 0
        @document_object = WIN32OLE.connect_unknown(intUnknown)
      end
    end
    attr_reader :containing_modal_dialog
    attr_reader :document_object
    def locate!(options={})
      exists? || raise(Vapir::Exception::NoMatchingWindowFoundException, "The modal dialog seems to have stopped existing.")
    end
    
    def exists?
      # todo/fix: will the document object change / become invalid / need to be relocated? 
      @document_object && @containing_modal_dialog.exists?
    end
    
    # this looks for a modal dialog on this modal dialog. but really it's modal to the same browser window
    # that this is modal to, so we will check for the modal on the browser, see if it isn't the same as our
    # self, and return it if so. 
    def modal_dialog(options={})
      ::Waiter.try_for(ModalDialog::DEFAULT_TIMEOUT, 
                        :exception => NoMatchingWindowFoundException.new("No other modal dialog was found on the browser."),
                        :condition => proc{|md| md.hwnd != containing_modal_dialog.hwnd }
                      ) do
        modal_dialog=containing_modal_dialog.browser.modal_dialog(options)
      end
    end
  end
end
=begin
module Watir
  class IE::ModalDialog
    include IE::Container
    include IE::PageContainer
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