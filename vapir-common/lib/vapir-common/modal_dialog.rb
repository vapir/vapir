module Vapir
  module ModalDialog
    DEFAULT_TIMEOUT=4
    def default_initialize(browser, options={})
      options=handle_options(options, :timeout => ModalDialog::DEFAULT_TIMEOUT, :error => true)
      @browser=browser
      ::Waiter.try_for(options[:timeout], :exception => (options[:error] && Vapir::Exception::NoMatchingWindowFoundException.new("No popup was found on the browser"))) do
        locate
      end
    end
    alias initialize default_initialize
    
    def locate!(options={})
      exists? || raise(Vapir::Exception::WindowGoneException, "The modal dialog seems to have stopped existing.")
    end
    alias assert_exists locate!
    
    attr_reader :browser
    attr_reader :modal_window

    [:locate, :exists?, :text, :set_text_field, :click_button, :close, :document].each do |virtual_method|
      define_method(virtual_method) do
        raise NotImplementedError, "The method \##{virtual method} should be defined on the class #{self.class}"
      end
    end
  end
end
