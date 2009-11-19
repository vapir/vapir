module Watir
  module FFRadioCheckboxCommon
    private
    # radios in firefox seem to be totally unresponsive to css color and border, but
    # they can change size, so use that for the highlight method. 
    # see http://www.456bereastreet.com/lab/styling-form-controls-revisited/radio-button/
    def set_highlight(options={})
      assert_exists do
        @original_height=element_object.offsetHeight
        @original_width=element_object.offsetWidth
        element_object.style.height=@original_height+3
        element_object.style.width=@original_width+3
      end
    end
    def clear_highlight(options={})
      element_object.style.height=@original_height
      element_object.style.width=@original_width
    end
  end
  class FFRadio < FFInputElement
    include Radio
    include FFRadioCheckboxCommon
  end # Radio

  #
  # Description:
  # Class for Checkbox element.
  #
  class FFCheckBox < FFInputElement
    include CheckBox
    include FFRadioCheckboxCommon
  end # CheckBox
end # FireWatir
