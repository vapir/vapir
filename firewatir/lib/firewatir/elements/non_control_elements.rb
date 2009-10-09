module Watir
  class FFPre < FFNonControlElement
    include Pre
    TAG = 'PRE'
    ContainerMethods=:pre
    ContainerCollectionMethods=:pres
  end

  class FFP < FFNonControlElement
    include P
    TAG = 'P'
    ContainerMethods=:p
    ContainerCollectionMethods=:ps
  end

  class FFDiv < FFNonControlElement
    include Div
    TAG = 'DIV'
    ContainerMethods=:div
    ContainerCollectionMethods=:divs
  end

  class FFSpan < FFNonControlElement
    include Span
    TAG = 'SPAN'
    ContainerMethods=:span
    ContainerCollectionMethods=:spans
  end

  class FFStrong < FFNonControlElement
    include Strong
    TAG = 'STRONG'
    ContainerMethods=:strong
    ContainerCollectionMethods=:strongs
  end

  class FFLabel < FFNonControlElement
    include Label
    TAG = 'LABEL'
    ContainerMethods=:label
    ContainerCollectionMethods=:labels

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
      if for_object=document_object.getElementById(dom_object.htmlFor)
        FFElement.factory(for_object.store_rand_prefix('firewatir_elements'), extra)
      else
        raise "no element found that this is for!"
      end
    end
  end

  class FFUl < FFNonControlElement
    include Ul
    TAG = 'UL'
  end

  class FFLi < FFNonControlElement
    include Li
    TAG = 'LI'
  end

  class FFDl < FFNonControlElement
    include Dl
    TAG = 'DL'
  end

  class FFDt < FFNonControlElement
    include Dt
    TAG = 'DT'
  end

  class FFDd < FFNonControlElement
    include Dd
    TAG = 'DD'
  end

  class FFH1 < FFNonControlElement
    include H1
    TAG = 'H1'
  end

  class FFH2 < FFNonControlElement
    include H2
    TAG = 'H2'
  end

  class FFH3 < FFNonControlElement
    include H3
    TAG = 'H3'
  end

  class FFH4 < FFNonControlElement
    include H4
    TAG = 'H4'
  end

  class FFH5 < FFNonControlElement
    include H5
    TAG = 'H5'
  end

  class FFH6 < FFNonControlElement
    include H6
    TAG = 'H6'
  end

  class FFMap < FFNonControlElement
    include Map
    TAG = 'MAP'
  end

  class FFArea < FFNonControlElement
    include Area
    TAG = 'AREA'
  end

  class FFTBody < FFNonControlElement
    include TBody
    TAG = 'TBODY'
  end
  
  class FFEm < FFNonControlElement
    include Em
    TAG = 'EM'
  end

end # FireWatir
