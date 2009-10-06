module Watir
  #
  # Description:
  #   Class for Option element.
  #
  class FFOption < FFInputElement
    include Option
    TAG='option'
    #
    # Description:
    #   Initializes the instance of option object.
    #
    # Input:
    #   - select_list - instance of select list element.
    #   - attribute - Attribute to identify the option.
    #   - value - Value of that attribute.
    #
#    def initialize (select_list, attribute, value)
#      @select_list = @container = select_list
#      @how = attribute
#      @what = value
#      @option = nil
#      
#      unless [:text, :value, :jssh_name].include? attribute 
#        raise Exception::MissingWayOfFindingObjectException, "Option does not support attribute #{@how}"
#      end
#      #puts @select_list.o.length
#      #puts "what is : #{@what}, how is #{@how}, list name is : #{@select_list.element_name}"
#      if(attribute == :jssh_name)
#        @dom_object = JsshObject.new(@what, jssh_socket)
#        @option = self
#      else    
#        @select_list.each do |option| # items in the list
#          #puts "option is : #{option}"
#          if(attribute == :value)
#            match_value = option.value
#          else    
#            match_value = option.text
#          end    
#          #puts "value is #{match_value}"
#          if value.matches( match_value) #option.invoke(attribute))
#            @option = option
#            @dom_object = option.dom_object
#            break
#          end
#        end
#      end    
#    end
    
    #
    # Description:
    #   Checks if option exists or not.
    #
#    def assert_exists
#      unless @option
#        raise Exception::UnknownObjectException,  
#                "Unable to locate an option using #{@how} and #{@what}"
#      end
#    end
#    private :assert_exists
#    def initialize *args
#      raise NotImplementedError
#    end
    
    #
    # Description:
    #   Selects the option.
    #
    def select
      assert_exists
      dom_object.selected=true
    end
    
    #
    # Description:
    #   Gets the class name of the option.
    #
    # Output:
    #   Class name of the option.
    #
    def class_name
      assert_exists
      dom_object.className
    end
    
    #
    # Description:
    #   Gets the text of the option.
    #
    # Output:
    #   Text of the option.
    #
    def text
      assert_exists
      dom_object.text
    end
    
    #
    # Description:
    #   Gets the value of the option.
    #
    # Output:
    #   Value of the option.
    #
    def value
      assert_exists
      dom_object.value
    end
    
    #
    # Description:
    #   Gets the status of the option; whether it is selected or not.
    #
    # Output:
    #   True if option is selected, false otherwise.
    #
    def selected
      assert_exists
      dom_object.selected
    end
    def selected=(val)
      assert_exists
      dom_object.selected=val
    end
    
    
  end # Option
end # FireWatir