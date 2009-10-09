module Watir

  # this class contains items that are common between the span, div, and pre objects
  # it would not normally be used directly
  #
  # many of the methods available to this object are inherited from the Element class
  #
  module IENonControlElement
    def self.included subclass
      class_name = subclass.to_s.demodulize
      method_name = class_name.sub(/\AIE/i,'').underscore
#      puts "IN #{self}.inherited: subclass=#{subclass.inspect}; class_name=#{class_name.inspect}; method_name=#{method_name.inspect}"
#      Watir::IEContainer.module_eval "def #{method_name}(how, what=nil)
#      return #{class_name}.new(self, how, what); end"
    end
    include Watir::Exception

#    def locate
#      if @how == :xpath
#        @o = @container.element_by_xpath(@what)
#      else
#        @o = @container.locate_tagged_element(self.class::TAG, @how, @what)
#      end
#    end
#    
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      super nil
#    end

    # this method is used to populate the properties in the to_s method
#    def span_div_string_creator
#      n = []
#      n <<   "class:".ljust(TO_S_SIZE) + self.class_name
#      n <<   "text:".ljust(TO_S_SIZE) + self.text
#      return n
#    end
#    private :span_div_string_creator
#
#    # returns the properties of the object in a string
#    # raises an ObjectNotFound exception if the object cannot be found
#    def to_s
#      assert_exists
#      r = string_creator
#      r += span_div_string_creator
#      return r.join("\n")
#    end
  end


  class IEPre < IEElement
    include IENonControlElement
    include Pre
  end

  class IEP < IEElement
    include IENonControlElement
    include P
  end

  # this class is used to deal with Div tags in the html page. http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/div.asp?frame=true
  # It would not normally be created by users
  class IEDiv < IEElement
    include IENonControlElement
    include Div
  end

  # this class is used to deal with Span tags in the html page. It would not normally be created by users
  class IESpan < IEElement
    include IENonControlElement
    include Span
  end

  class IEMap < IEElement
    include IENonControlElement
    include Map
  end

  class IEArea < IEElement
    include IENonControlElement
    include Area
  end

  # Accesses Label element on the html page - http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/label.asp?frame=true
  class IELabel < IEElement
    include IENonControlElement
    include Label

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
#    def to_s
#      assert_exists
#      r = string_creator
#      r += label_string_creator
#      return r.join("\n")
#    end
  end

  class IELi < IEElement
    include IENonControlElement
    include Li
  end
  class IEUl < IEElement
    include IENonControlElement
    include Ul
  end
  class IEH1 < IEElement
    include IENonControlElement
    include H1
  end
  class IEH2 < IEElement
    include IENonControlElement
    include H2
  end
  class IEH3 < IEElement
    include IENonControlElement
    include H3
  end
  class IEH4 < IEElement
    include IENonControlElement
    include H4
  end
  class IEH5 < IEElement
    include IENonControlElement
    include H5
  end
  class IEH6 < IEElement
    include IENonControlElement
    include H6
  end
  class IEDl < IEElement
    include IENonControlElement
    include Dl
  end
  class IEDt < IEElement
    include IENonControlElement
    include Dt
  end
  class IEDd < IEElement
    include IENonControlElement
    include Dd
  end
  class IEStrong < IEElement
    include IENonControlElement
    include Strong
  end
  class IEEm < IEElement
    include IENonControlElement
    include Em
  end

end