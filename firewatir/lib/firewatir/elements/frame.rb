require 'firewatir/firefox'

module Watir
  class FFFrame < FFElement
    include Frame
    include FFHasDocument
    #include FFDocument

    def containing_object
      element_object.contentDocument
    end

    def document_object
      element_object.contentDocument # OR content_window_object.document
    end
    def content_window_object
      element_object.contentWindow
    end
    def url
      content_window_object.location.href
    end
    def text
      document_object.body.textContent
    end
    alias textContent text
  end # Frame
end # FireWatir
