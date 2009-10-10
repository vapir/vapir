module Watir
  class IEFrame < IEElement
    include IEContainer
    include Frame
    include IEPageContainer
    
    # Find the frame denoted by how and what in the container and return its ole_object
#    def locate
#      how = @how
#      what = @what
#      frames = @container.document.frames
#      target = nil
#      
#      for i in 0..(frames.length - 1)
#        this_frame = frames.item(i)
#        case how
#        when :index
#          index = i + 1
#          return this_frame if index == what
#        when :name
#          begin
#            return this_frame if what.matches(this_frame.name)
#          rescue # access denied?
#          end
#        when :id
#          # We assume that pages contain frames or iframes, but not both.
#          this_frame_tag = @container.document.getElementsByTagName("FRAME").item(i)
#          return this_frame if this_frame_tag and what.matches(this_frame_tag.invoke("id"))
#          this_iframe_tag = @container.document.getElementsByTagName("IFRAME").item(i)
#          return this_frame if this_iframe_tag and what.matches(this_iframe_tag.invoke("id"))
#        when :src
#          this_frame_tag = @container.document.getElementsByTagName("FRAME").item(i)
#          return this_frame if this_frame_tag and what.matches(this_frame_tag.src)
#          this_iframe_tag = @container.document.getElementsByTagName("IFRAME").item(i) 
#          return this_frame if this_iframe_tag and what.matches(this_iframe_tag.src)
#        else
#          raise ArgumentError, "Argument #{how} not supported"
#        end
#      end
#      
#      raise UnknownFrameException, "Unable to locate a frame with #{how.to_s} #{what}"
#    end
    
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      @o = locate
#      copy_test_config container
#    end
    
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
    #def container_candidates(specifiers)
      #if @container.is_a?(Browser) || @container.is_a?(Frame)
      #  frames=[]
      #  document_frames=@container.document_object.frames
      #  for i in 0...(document_frames.length)
      #    frames << document_frames.item(i)
      #  end
      #  frames
      #else
      #  raise Watir::Exception::MissingWayOfFindingObjectException, "Unable to locate frames with container #{@contaner.inspect} (#{@container.class}). only Frame and Browser are supported for locating frames."
      #  #Watir::Specifier.specifier_candidates(@container, specifiers)
      #end
    #end
    
  end
end