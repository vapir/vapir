module Watir
  #
  # Description:
  #   Base class for checkbox and radio button elements.
  #
  module FFRadioCheckCommon
    extend DomWrap
    
    dom_wrap :set? => :checked, :getState => :checked, :checked? => :checked, :isSet? => :checked
    #
    # Description:
    #   Checks if element i.e. radio button or check box is checked or not.
    #
    # Output:
    #   True if element is checked, false otherwise.
    #
#    def set?
#      assert_exists
#      return checked
#    end
#    alias getState set?
#    alias checked? set?
#    alias isSet?   set?

    #
    # Description:
    #   Unchecks the radio button or check box element.
    #   Raises ObjectDisabledException exception if element is disabled.
    #
    def clear
      assert_exists
      assert_enabled
      #highlight(:set)
      set_clear_item(false)
      #highlight(:clear)
    end

    #
    # Description:
    #   Checks the radio button or check box element.
    #   Raises ObjectDisabledException exception if element is disabled.
    #
    def set
      assert_exists
      assert_enabled
      #highlight(:set)
      set_clear_item(true)
      #highlight(:clear)
    end

    #
    # Description:
    #   Used by clear and set method to uncheck and check radio button and checkbox element respectively.
    #
    # TODO/FIX: check value so that set/clear is actually respected
    def set_clear_item(set)
      fire_event("onclick")
      @container.wait
    end
    private :set_clear_item

  end # RadioCheckCommon

  #
  # Description:
  #   Class for RadioButton element.
  #
  class FFRadio < FFInputElement
    include FFRadioCheckCommon
    include Radio
    def clear
      assert_exists
      assert_enabled
      #higlight(:set)
      assign('checked', false)
      #highlight(:clear)
    end

  end # Radio

  #
  # Description:
  # Class for Checkbox element.
  #
  class FFCheckBox < FFInputElement
    include FFRadioCheckCommon
    include CheckBox
    #
    # Description:
    #   Checks or unchecks the checkbox. If no value is supplied it will check the checkbox.
    #   Raises ObjectDisabledException exception if the object is disabled
    #
    # Input:
    #   - set_or_clear - Parameter indicated whether to check or uncheck the checkbox.
    #                    True to check the check box, false for unchecking the checkbox.
    #
    def set( set_or_clear=true )
      assert_exists
      assert_enabled
      highlight(:set)

      if set_or_clear == true
        if checked == false
          set_clear_item( true )
        end
      else
        self.clear
      end
      highlight(:clear )
    end

    #
    # Description:
    #   Unchecks the checkbox.
    #   Raises ObjectDisabledException exception if the object is disabled
    #
    def clear
      assert_exists
      assert_enabled
      highlight( :set)
      if checked == true
        set_clear_item( false )
      end
      highlight( :clear)
    end

  end # CheckBox
end # FireWatir
