require 'vapir-common/modal_dialog'
require 'vapir-ie/page_container'

module Vapir
  class IE::ModalDialog
    include Vapir::ModalDialog
    def locate
      @modal_window=@browser.win_window.enabled_popup || begin
        # IE9 modal dialogs aren't modal to the actual browser window. instead it creates some
        # other window with class_name="Alternate Modal Top Most" and makes the modal dialog modal 
        # to that thing instead. this has the same text (title) as the browser window but that 
        # is the only relationship I have found so far to the browser window. I'd like to use a
        # stronger relationship than that, but, it'll have to do. 
        matching_windows = WinWindow::All.select do |win|
          win.parent && win.parent.class_name == "Alternate Modal Top Most" && win.parent.text == @browser.win_window.text
        end
        case matching_windows.size
        when 0
          nil
        when 1
          matching_windows.first
        else
          raise Vapir::Exception::WindowException, "found multiple windows that looked like popups: #{matching_windows.inspect}"
        end
      end
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
      exists? || raise(Vapir::Exception::WindowGoneException, "The modal dialog seems to have stopped existing.")
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
