require 'vapir-ie/element'
require 'vapir-common/elements/elements'
require 'vapir-ie/page_container'

module Vapir
  class IE::Frame < IE::Element
    include Frame
    include IE::PageContainer
    
    # waiting on a Frame should carry on upwards to the browser - the sorts of operations that we wait after 
    # (clicking a link or whatever) tend to affect other frames too; waiting on just this frame doesn't 
    # make sense. 
    def wait(options={}) # :nodoc:
      return unless config.wait
      if browser # prefer to wait on the browser
        browser.wait(options)
      elsif container # if we don't have the browser, wait on the container (presumably this exists) 
        container.wait(options)
      else # but if we don't have a container either, just call to PageContainer#wait (by this alias) 
        page_container_wait(options)
      end
    end
    
    def content_window_object
      element_object.contentWindow
    end
    
    def document_object
      content_window_object.document
    end
    alias document document_object
    
  end
end