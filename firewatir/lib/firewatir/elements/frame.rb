module Watir
  class FFFrame < FFElement
    include Frame
    include FFContainer
    #
    # Description:
    #   Initializes the instance of frame or iframe object.
    #
    # Input:
    #   - how - Attribute to identify the frame element.
    #   - what - Value of that attribute.
    #
    def initialize(container, how, what)
      @how = how
      @what = what
      @container = container
      @document=FFDocument.new self
    end

    def locate
      @dom_object||= if(@how == :jssh_name)
        JsshObject.new @what, jssh_socket
      else
        locate_frame(@how, @what)
      end
    end
    def locate_frame(how, what)
      if @container.is_a?(Firefox) || @container.is_a?(FFFrame)
        candidates=@container.content_window_object.frames
      else
        raise "locate_frame is not implemented to deal with locating frames on classes other than Watir::Firefox and Watir::FFFrame"
      end

      specifier=howwhat_to_specifier(how, what)
      index=specifier.delete(:index)
      if match=match_candidates(candidates.to_array.map{|c|c.frameElement}, specifier, index)
        return match.store_rand_prefix('firewatir_frames')
      end
      return nil
    end

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
