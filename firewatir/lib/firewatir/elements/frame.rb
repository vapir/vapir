module Watir
  class FFFrame < FFElement
    include Frame

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
    end

    def locate
      if(@how == :jssh_name)
        @element_name = @what
      else
        @element_name = locate_frame(@how, @what)
      end
      #puts @element_name
      @o = self

    end

    def html
      assert_exists
      get_frame_html
    end

    def document_var # unfinished
      "document"
    end

    def body_var # unfinished
      "body"
    end

    def window_var
      "window"
    end

    def browser_var
      "browser"
    end

    def document
      @container.document
    end
  end # Frame
end # FireWatir
