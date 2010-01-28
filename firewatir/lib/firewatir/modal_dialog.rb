require 'watir/win_window'
require 'watir/common_modal_dialog'
module Watir
  class FFModalDialog
    include ModalDialog
    def locate
      candidates=[]
      @browser.class.each_window_object do |win|
        opener=win.attr(:opener)
        opener=nil unless opener.type=='object'
        content=win.attr(:content)
        if content.type=='object'
          content_opener=content.attr(:opener)
          content_opener=nil unless content_opener.type=='object'
        end
        if [@browser.browser_window_object, @browser.content_window_object].any?{|_w| [opener, content_opener].compact.include?(_w) }
          candidates << win 
        end
      end
      if candidates.size==0
        nil
      elsif candidates.size==1
        @modal_window=candidates.first
      else
        raise "Multiple windows found which this is a parent of - cannot determine which is the expected modal dialog"
      end
    end
    
    def exists?
      # jssh_socket may be nil if the window has closed 
      @modal_window && @browser.jssh_socket && @browser.jssh_socket.object('getWindows()').to_js_array.include(@modal_window)
    end
    
    def text
      assert_exists
      @modal_window.document.documentElement.textContent
    end
    
    def set_text_field(value)
      assert_exists
      raise NotImplementedError
    end
    
    def click_button(button_text, options={})
      options=handle_options(options, :timeout => nil) # we don't actually use timeout here. maybe should error on it? 
      # raise if no anonymous nodes are found (this is where the buttons are) 
      anonymous_dialog_nodes=@modal_window.document.getAnonymousNodes(@modal_window.document.documentElement) || raise("Could not find anonymous nodes on which to look for buttons")
      xul_buttons=[]
      anonymous_dialog_nodes.to_array.each do |node|
        xul_buttons+=node.getElementsByTagName('xul:button').to_array.select do |button|
          Watir::fuzzy_match(button.label, button_text)
        end
      end
      raise("Found #{xul_buttons.size} buttons which match #{button_text} - expected to find 1") unless xul_buttons.size==1
      xul_button=xul_buttons.first
      xul_button.disabled=false # get around firefox's stupid thing where the default button is disabled for a few seconds or something, god knows why
      xul_button.click
    end
    
    def close
      @modal_window.close
    end
    
    def document
      FFModalDialogDocument.new(self)
    end
  end
  class FFModalDialogDocument
    include FFPageContainer

    def initialize(containing_modal_dialog, options={})
      options=handle_options(options, :timeout => ModalDialog::DEFAULT_TIMEOUT, :error => true)
      @jssh_socket=containing_modal_dialog.browser.jssh_socket
      @browser_object=containing_modal_dialog.modal_window.getBrowser

      @containing_modal_dialog=containing_modal_dialog
    end
    attr_reader :containing_modal_dialog
    attr_reader :browser_object
    
    def document_object
      browser_object.contentDocument
    end
    def content_window_object
      browser_object.contentWindow
    end
    def locate!(options={})
      exists? || raise(Watir::Exception::NoMatchingWindowFoundException, "The modal dialog seems to have stopped existing.")
    end
    
    def exists?
      # todo/fix: will the document object change / become invalid / need to be relocated? 
      @containing_modal_dialog.exists? && document_object
    end
    
    # this looks for a modal dialog on this modal dialog. but really it's modal to the same browser window
    # that this is modal to, so we will check for the modal on the browser, see if it isn't the same as our
    # self, and return it if so. 
    def modal_dialog
      raise NotImplementedError
      ::Waiter.try_for(ModalDialog::DEFAULT_TIMEOUT, 
                        :exception => NoMatchingWindowFoundException.new("No other modal dialog was found on the browser."),
                        :condition => proc{|md| md.hwnd != containing_modal_dialog.hwnd }
                      ) do
        modal_dialog=containing_modal_dialog.browser.modal_dialog
      end
    end
    
    def wait(options=nil)
      ::Waiter.try_for(Firefox::ARBITRARY_TIMEOUT) do
        !browser_object.webProgress.isLoadingDocument
      end
    end
    
    attr_reader :jssh_socket
  end
end
