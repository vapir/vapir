require 'vapir-ie/element'
require 'vapir-common/elements/elements'
require 'vapir-ie/page_container'

module Vapir
  class IE::Frame < IE::Element
    include Frame
    include IE::PageContainer
    
    def content_window_object
      element_object.contentWindow
    end
    
    def document_object
      content_window_object.document
    end
    alias document document_object

    def attach_command
      @container.page_container.attach_command + ".frame(#{@how.inspect}, #{@what.inspect})"
    end
    
  end
end