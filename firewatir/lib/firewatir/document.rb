module Watir
  #
  # Description:
  #   Class for returning the document element.
  #
  class FFDocument
    include Document
    include Watir::FFContainer
    @@current_level = 0

    #
    # Description:
    #   Creates new instance of Document class.
    #
    def initialize(container)
      @length = 0
      @elements = nil
      @arr_elements = ""
      @container = container
    end
    
    def document_object
      @container.document_object
    end
    def content_window_object
      @container.content_window_object
    end
    def browser_window_object
      @container.browser_window_object
    end
    
    def frames
      # TODO: FIX, copied from locate_frame, should be DRY 
      if @container.is_a?(Firefox) || @container.is_a?(FFFrame)
        candidates=@container.content_window_object.frames
      else
        raise "frames is not implemented to deal with locating frames on classes other than Watir::Firefox and Watir::FFFrame"
      end
      
      return candidates.to_array.map{|c| FFFrame.new(@container, :jssh_name, c.frameElement.store_rand_prefix('firewatir_frames').ref)}
    end

    #
    # Description:
    #   Find all the elements in the document by querying DOM.
    #   Set the class variables like length and the variable name of array storing the elements in JSSH.
    #
    # Output:
    #   Array of elements.
    #
    def all
      @arr_elements = "arr_coll_#{@@current_level}"
      jssh_command = "var arr_coll_#{@@current_level}=new Array(); "

      if(@container.is_a?(Firefox) || @container.is_a?(FFFrame))
        jssh_command <<"var element_collection = null; element_collection = #{document_object.ref}.getElementsByTagName(\"*\");
                                if(element_collection != null && typeof(element_collection) != 'undefined')
                                {
                                    for (var i = 0; i < element_collection.length; i++)
                                    {
                                        if((element_collection[i].tagName != 'BR') && (element_collection[i].tagName != 'HR') && (element_collection[i].tagName != 'DOCTYPE') && (element_collection[i].tagName != 'META') && (typeof(element_collection[i].tagName) != 'undefined'))
                                            arr_coll_#{@@current_level}.push(element_collection[i]);
                                    }
                                }
                                arr_coll_#{@@current_level}.length;"
      else
        jssh_command <<"var element_collection = null; element_collection = #{@container.element_name}.getElementsByTagName(\"*\");
                                    if(element_collection!= null && typeof(element_collection) != 'undefined')
                                    {
                                        for (var i = 0; i < element_collection.length; i++)
                                        {
                                            if((element_collection[i].tagName != 'BR') && (element_collection[i].tagName != 'HR') && (element_collection[i].tagName != 'DOCTYPE') && (element_collection[i].tagName != 'META') && (typeof(element_collection[i].tagName) != 'undefined'))
                                            arr_coll_#{@@current_level}.push(element_collection[i]);
                                        }
                                    }
                                    arr_coll_#{@@current_level}.length;"
      end

      # Remove \n that are there in the string as a result of pressing enter while formatting.
      jssh_command.gsub!(/\n/, "")
      #puts  jssh_command
      @length = jssh_socket.send_and_read(jssh_command).to_i;
      #puts "elements length is in locate_tagged_elements is : #{@length}"

      elements = nil
      elements = Array.new(@length)
      for i in 0..@length - 1 do
        temp = FFElement.new("arr_coll_#{@@current_level}[#{i}]", @container)
        elements[i] = temp
      end
      @@current_level += 1
      return elements

    end

    def getElementById(id)
      el=document_object.getElementById(id)
      el.type=='undefined' ? nil : el
    end

    #
    # Description:
    #   Returns the count of elements in the document.
    #
    # Output:
    #   Count of elements found in the document.
    #
    def length
      return @length
    end
    alias_method :size, :length

    #
    # Description:
    #   Iterates over elements in the document.
    #
    def each
      for i in 0..@length - 1
        yield FFElement.new("#{@arr_elements}[#{i}]", @container)
      end
    end

    #
    # Description:
    #   Gets the element at the nth index in the array of the elements.
    #
    # Input:
    #   n - Index of element you want to access. Index is 1 based.
    #
    # Output:
    #   Element at the nth index.
    #
    def [](n)
      return FFElement.new("#{@arr_elements}[#{n-1}]", @container)
    end

    #
    # Description:
    #   Get all forms available on the page.
    #   Used internally by Firewatir use ff.show_forms instead.
    #
    # Output:
    #   Array containing Form elements
    #
    def get_forms()
      document_object.forms.to_array.map
    end

    #
    # Description:
    #   Get all images available on the page.
    #   Used internally by Firewatir use ff.show_images instead.
    #
    # Output:
    #   Array containing Image elements
    #
    def get_images
      return FFImages.new(@container)
    end

    #
    # Description:
    #   Get all links available on the page.
    #   Used internally by Firewatir use ff.show_links instead.
    #
    # Output:
    #   Array containing Link elements
    #
    def get_links
      return FFLinks.new(@container)
    end

    #
    # Description:
    #   Get all divs available on the page.
    #   Used internally by Firewatir use ff.show_divs instead.
    #
    # Output:
    #   Array containing Div elements
    #
    def get_divs
      return FFDivs.new(@container)
    end

    #
    # Description:
    #   Get all tables available on the page.
    #   Used internally by Firewatir use ff.show_tables instead.
    #
    # Output:
    #   Array containing Table elements
    #
    def get_tables
      return FFTables.new(@container)
    end

    #
    # Description:
    #   Get all pres available on the page.
    #   Used internally by Firewatir use ff.show_pres instead.
    #
    # Output:
    #   Array containing Pre elements
    #
    def get_pres
      return FFPres.new(@container)
    end

    #
    # Description:
    #   Get all spans available on the page.
    #   Used internally by Firewatir use ff.show_spans instead.
    #
    # Output:
    #   Array containing Span elements
    #
    def get_spans
      return FFSpans.new(@container)
    end

    #
    # Description:
    #   Get all labels available on the page.
    #   Used internally by Firewatir use ff.show_labels instead.
    #
    # Output:
    #   Array containing Label elements
    #
    def get_labels
      return FFLabels.new(@container)
    end
    
  end # Docuemnt
end # FireWatir
