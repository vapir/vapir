module Watir
  class FFPre < FFNonControlElement
    TAG = 'PRE'
  end

  class FFP < FFNonControlElement
    TAG = 'P'
  end

  class FFDiv < FFNonControlElement
    TAG = 'DIV'
  end

  class FFSpan < FFNonControlElement
    TAG = 'SPAN'
  end

  class FFStrong < FFNonControlElement
    TAG = 'STRONG'
  end

  class FFLabel < FFNonControlElement
    TAG = 'LABEL'

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
  end

  class FFUl < FFNonControlElement
    TAG = 'UL'
  end

  class FFLi < FFNonControlElement
    TAG = 'LI'
  end

  class FFDl < FFNonControlElement
    TAG = 'DL'
  end

  class FFDt < FFNonControlElement
    TAG = 'DT'
  end

  class FFDd < FFNonControlElement
    TAG = 'DD'
  end

  class FFH1 < FFNonControlElement
    TAG = 'H1'
  end

  class FFH2 < FFNonControlElement
    TAG = 'H2'
  end

  class FFH3 < FFNonControlElement
    TAG = 'H3'
  end

  class FFH4 < FFNonControlElement
    TAG = 'H4'
  end

  class FFH5 < FFNonControlElement
    TAG = 'H5'
  end

  class FFH6 < FFNonControlElement
    TAG = 'H6'
  end

  class FFMap < FFNonControlElement
    TAG = 'MAP'
  end

  class FFArea < FFNonControlElement
    TAG = 'AREA'
  end

  class FFBody < FFNonControlElement
    TAG = 'TBODY'
  end
  
  class FFEm < FFNonControlElement
    TAG = 'EM'
  end

end # FireWatir
