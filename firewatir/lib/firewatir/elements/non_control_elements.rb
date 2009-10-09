module Watir
  class FFPre < FFElement
    include FFNonControlElement
    include Pre
  end

  class FFP < FFElement
    include FFNonControlElement
    include P
  end

  class FFDiv < FFElement
    include FFNonControlElement
    include Div
  end

  class FFSpan < FFElement
    include FFNonControlElement
    include Span
  end

  class FFStrong < FFElement
    include FFNonControlElement
    include Strong
  end

  class FFLabel < FFElement
    include FFNonControlElement
    include Label

    #
    # Description:
    #   Used to populate the properties in the to_s method.
    #
    #def label_string_creator
    #    n = []
    #    n <<   "for:".ljust(TO_S_SIZE) + self.for
    #    n <<   "inner text:".ljust(TO_S_SIZE) + self.text
    #    return n
    #end
    #private :label_string_creator

    #
    # Description:
    #   Creates string of properties of the object.
    #
    def to_s
      assert_exists
      super({"for" => "htmlFor","text" => "innerHTML"})
      #   r=r + label_string_creator
    end
    
    def for
      if for_object=document_object.getElementById(element_object.htmlFor)
        FFElement.factory(for_object.store_rand_prefix('firewatir_elements'), extra)
      else
        raise "no element found that this is for!"
      end
    end
  end

  class FFUl < FFElement
    include FFNonControlElement
    include Ul
  end

  class FFLi < FFElement
    include FFNonControlElement
    include Li
  end

  class FFDl < FFElement
    include FFNonControlElement
    include Dl
  end

  class FFDt < FFElement
    include FFNonControlElement
    include Dt
  end

  class FFDd < FFElement
    include FFNonControlElement
    include Dd
  end

  class FFH1 < FFElement
    include FFNonControlElement
    include H1
  end

  class FFH2 < FFElement
    include FFNonControlElement
    include H2
  end

  class FFH3 < FFElement
    include FFNonControlElement
    include H3
  end

  class FFH4 < FFElement
    include FFNonControlElement
    include H4
  end

  class FFH5 < FFElement
    include FFNonControlElement
    include H5
  end

  class FFH6 < FFElement
    include FFNonControlElement
    include H6
  end

  class FFMap < FFElement
    include FFNonControlElement
    include Map
  end

  class FFArea < FFElement
    include FFNonControlElement
    include Area
  end

  class FFEm < FFElement
    include FFNonControlElement
    include Em
  end

end # FireWatir
