module Watir
  class FFFrame < FFElement
    include Frame
    include FFContainer

    def container_candidates(specifiers)
      raise unless @container.is_a?(Browser) || @container.is_a?(Frame)
      candidates=@container.content_window_object.frames.to_array.map{|c|c.frameElement}
    end

    def dom_object
      @element_object.contentDocument
    end

    def html
      raise NotImplementedError
    end
    
    def document_object
      @element_object.contentDocument # OR content_window_object.document
    end
    def content_window_object
      @element_object.contentWindow
    end
    attr_reader :document
    def url
      content_window_object.location.href
    end
  end # Frame
end # FireWatir
