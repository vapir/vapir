module Watir
  class FFFrame < FFElement
    include Frame
    include FFContainer
    TAG='frame'
    #
    # Description:
    #   Initializes the instance of frame or iframe object.
    #
    # Input:
    #   - how - Attribute to identify the frame element.
    #   - what - Value of that attribute.
    #
    def initialize(*args)
      super
      @document=FFDocument.new self
    end
    DefaultHow=:name
    ContainerMethods=:frame
    ContainerCollectionMethods=:frames

    def html
      assert_exists
      get_frame_html
    end

    def document_object
      assert_exists
      @dom_object.contentDocument # OR content_window_object.document
    end
    def content_window_object
      assert_exists
      @dom_object.contentWindow
    end
    attr_reader :document
    def url
      content_window_object.location.href
    end
  end # Frame
end # FireWatir
