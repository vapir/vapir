module Watir
  class IEFrame < IEElement
    include IEContainer
    include Frame
    include IEPageContainer
    
    def content_window_object
      element_object.contentWindow
    end
    
    def document_object
      content_window_object.document
    end
    alias document document_object
    def containing_object
      content_window_object.document
    end

    def attach_command
      @container.page_container.attach_command + ".frame(#{@how.inspect}, #{@what.inspect})"
    end
    
  end
end