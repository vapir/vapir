require 'vapir-firefox/window'
require 'vapir-common/common_modal_dialog'
module Vapir
  # represents a window which is modal to a parent window 
  class Firefox::ModalDialog
    include Vapir::ModalDialog
    include Firefox::Window
    def locate
      candidates=[]
      Vapir::Firefox.each_window_object do |win|
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
      assert_exists
      options=handle_options(options, :timeout => nil) # we don't actually use timeout here. maybe should error on it? 
      # raise if no anonymous nodes are found (this is where the buttons are) 
      anonymous_dialog_nodes=@modal_window.document.getAnonymousNodes(@modal_window.document.documentElement) || raise("Could not find anonymous nodes on which to look for buttons")
      xul_buttons=[]
      anonymous_dialog_nodes.to_array.each do |node|
        xul_buttons+=node.getElementsByTagName('xul:button').to_array.select do |button|
          Vapir::fuzzy_match(button.label, button_text)
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
      assert_exists
      Firefox::ModalDialogDocument.new(self)
    end
    def browser_window_object
      assert_exists
      modal_window
    end
    def mozilla_window_class_name
      'MozillaDialogClass'
    end
  end

  # this module is for objects that can launch modal dialogs of their own. 
  # such things are a Firefox Browser, and a Firefox::ModalDialogDocument. 
  module Firefox::ModalDialogContainer
    # returns a Firefox::ModalDialog. 
    #
    # you may specify an options hash. keys supported are those supported by the second argument
    # to Firefox::ModalDialog#initialize, except that :error is overridden to false (use #modal_dialog!)
    # if you want an exception to raise) 
    def modal_dialog(options={})
      modal=Firefox::ModalDialog.new(self, options.merge(:error => false))
      modal.exists? ? modal : nil
    end
    
    # returns #modal_dialog if it exists; otherwise, errors. use this with the expectation that the dialog does exist. 
    # use #modal_dialog when you will check if it exists. 
    def modal_dialog!(options={})
      Firefox::ModalDialog.new(self, options.merge(:error => true))
    end
  end

  # this represents a document contained within a modal dialog (a Firefox::ModalDialog)
  # which was opened, generally, via a call to window.showModalDialog. 
  class Firefox::ModalDialogDocument
    include Firefox::PageContainer
    include Firefox::ModalDialogContainer

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
    def browser_window_object
      containing_modal_dialog.modal_window
    end
    def locate!(options={})
      exists? || raise(Vapir::Exception::NoMatchingWindowFoundException, "The modal dialog seems to have stopped existing.")
    end
    
    def exists?
      # todo/fix: will the document object change / become invalid / need to be relocated? 
      @containing_modal_dialog.exists? && document_object
    end
    
    def wait(options=nil)
      ::Waiter.try_for(Firefox::ARBITRARY_TIMEOUT) do
        !browser_object.webProgress.isLoadingDocument
      end
    end
    
    attr_reader :jssh_socket
  end
end
