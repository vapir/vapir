module Watir
  class FFFrame < FFElement
    include Frame
    include FFContainer
    TAG='frame'
    DefaultHow=:name
    ContainerMethods=:frame
    ContainerCollectionMethods=:frames
    #
    # Description:
    #   Initializes the instance of frame or iframe object.
    #
    # Input:
    #   - how - Attribute to identify the frame element.
    #   - what - Value of that attribute.
    #
#    def initialize(*args)
#      super
#      #TODO/FIX: initialize properly?
#      @frame_object=@dom_object
#      @dom_object=@frame_object.contentDocument
#      @document=FFDocument.new self
#    end
    def container_candidates(specifiers)
      raise unless @container.is_a?(Browser) || @container.is_a?(Frame)
      candidates=content_window_object.frames.to_array.map{|c|c.frameElement}
    end
    def locate(*args)
      super
      if @dom_object
        @frame_object=@dom_object
        @dom_object=@frame_object.contentDocument
        @document=FFDocument.new self
      end
      @dom_object
    end

    def html
      assert_exists
      get_frame_html
    end
    
    def document_object
      @frame_object.contentDocument # OR content_window_object.document
    end
    def content_window_object
      assert_exists
      @frame_object.contentWindow
    end
    attr_reader :document
    def url
      content_window_object.location.href
    end
  end # Frame
end # FireWatir
