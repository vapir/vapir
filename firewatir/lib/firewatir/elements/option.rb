module Watir
  #
  # Description:
  #   Class for Option element.
  #
  class FFOption < FFInputElement
    include Option
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