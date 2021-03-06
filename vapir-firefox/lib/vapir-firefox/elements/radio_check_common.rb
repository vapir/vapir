require 'vapir-firefox/elements/input_element'
require 'vapir-common/elements/elements'

module Vapir
  module Firefox::RadioCheckboxCommon
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
  class Firefox::Radio < Firefox::InputElement
    include Vapir::Radio
    include Firefox::RadioCheckboxCommon
  end # Radio

  #
  # Description:
  # Class for Checkbox element.
  #
  class Firefox::CheckBox < Firefox::InputElement
    include Vapir::CheckBox
    include Firefox::RadioCheckboxCommon
  end # CheckBox
end # Vapir
