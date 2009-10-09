require 'firewatir/firefox'

module Watir
  class FFFrame < FFElement
    include FFContainer
    include Frame
    include FFHasDocument
    #include FFDocument

    def container_candidates(specifiers)
      if @container.is_a?(Browser) || @container.is_a?(Frame)
        candidates=@container.content_window_object.frames.to_array.map{|c|c.frameElement}
      else
        Watir::Specifier.specifier_candidates(@container, specifiers)
      end
    end

    def containing_object
      element_object.contentDocument
    end

    def document_object
      element_object.contentDocument # OR content_window_object.document
    end
    def content_window_object
      element_object.contentWindow
    end
    #attr_reader :document
    def url
      content_window_object.location.href
    end
    def text
      document_object.body.textContent
    end
    alias textContent text
  end # Frame
end # FireWatir
