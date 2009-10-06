module Watir

  # this class contains items that are common between the span, div, and pre objects
  # it would not normally be used directly
  #
  # many of the methods available to this object are inherited from the Element class
  #
  class IENonControlElement < IEElement
    include NonControlElement
    def self.inherited subclass
      class_name = subclass.to_s.demodulize
      method_name = class_name.sub(/\AIE/i,'').underscore
#      puts "IN #{self}.inherited: subclass=#{subclass.inspect}; class_name=#{class_name.inspect}; method_name=#{method_name.inspect}"
      Watir::IEContainer.module_eval "def #{method_name}(how, what=nil)
      return #{class_name}.new(self, how, what); end"
    end
    include Watir::Exception

    def locate
      if @how == :xpath
        @o = @container.element_by_xpath(@what)
      else
        @o = @container.locate_tagged_element(self.class::TAG, @how, @what)
      end
    end

    def initialize(container, how, what)
      set_container container
      @how = how
      @what = what
      super nil
    end

    # this method is used to populate the properties in the to_s method
    def span_div_string_creator
      n = []
      n <<   "class:".ljust(TO_S_SIZE) + self.class_name
      n <<   "text:".ljust(TO_S_SIZE) + self.text
      return n
    end
    private :span_div_string_creator

    # returns the properties of the object in a string
    # raises an ObjectNotFound exception if the object cannot be found
    def to_s
      assert_exists
      r = string_creator
      r += span_div_string_creator
      return r.join("\n")
    end
  end


  class IEPre < IENonControlElement
    TAG = 'PRE'
  end

  class IEP < IENonControlElement
    TAG = 'P'
  end

  # this class is used to deal with Div tags in the html page. http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/div.asp?frame=true
  # It would not normally be created by users
  class IEDiv < IENonControlElement
    TAG = 'DIV'
  end

  # this class is used to deal with Span tags in the html page. It would not normally be created by users
  class IESpan < IENonControlElement
    TAG = 'SPAN'
  end

  class IEMap < IENonControlElement
    TAG = 'MAP'
  end

  class IEArea < IENonControlElement
    TAG = 'AREA'
  end

  # Accesses Label element on the html page - http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/label.asp?frame=true
  class IELabel < IENonControlElement
    TAG = 'LABEL'

    # this method is used to populate the properties in the to_s method
    def label_string_creator
      n = []
      n <<   "for:".ljust(TO_S_SIZE) + self.for
      n <<   "text:".ljust(TO_S_SIZE) + self.text
      return n
    end
    private :label_string_creator

    # returns the properties of the object in a string
    # raises an ObjectNotFound exception if the object cannot be found
    def to_s
      assert_exists
      r = string_creator
      r += label_string_creator
      return r.join("\n")
    end
  end

  class IELi < IENonControlElement
    TAG = 'LI'
  end
  class IEUl < IENonControlElement
    TAG = 'UL'
  end
  class IEH1 < IENonControlElement
    TAG = 'H1'
  end
  class IEH2 < IENonControlElement
    TAG = 'H2'
  end
  class IEH3 < IENonControlElement
    TAG = 'H3'
  end
  class IEH4 < IENonControlElement
    TAG = 'H4'
  end
  class IEH5 < IENonControlElement
    TAG = 'H5'
  end
  class IEH6 < IENonControlElement
    TAG = 'H6'
  end
  class IEDl < IENonControlElement
    TAG = 'DL'
  end
  class IEDt < IENonControlElement
    TAG = 'DT'
  end
  class IEDd < IENonControlElement
    TAG = 'DD'
  end
  class IEStrong < IENonControlElement
    TAG = 'STRONG'
  end
  class IEEm < IENonControlElement
    TAG = 'EM'
  end

end