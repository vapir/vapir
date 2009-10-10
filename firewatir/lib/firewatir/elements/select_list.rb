module Watir
  #
  # Description:
  #   Class for SelectList element.
  #
  class FFSelectList < FFInputElement
    include SelectList

    # Returns an ElementCollection containing all the option elements of the select list 
    def options
      assert_exists
      jssh_to_element_collection(FFOption, element_object.options)
    end

  end # SelectList
end # FireWatir
