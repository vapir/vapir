module Watir
  #
  # Description:
  #   Class for SelectList element.
  #
  class FFSelectList < FFInputElement
    include SelectList

    #
    # Description:
    #   Gets all the items in the select list as an array.
    #   An empty array is returned if the select box has no contents.
    #
    # Output:
    #   Array containing the items of the select list.
    #
    def options
      ElementCollection.new(element_object.options.to_array.map do |option_object|
        FFOption.new(:element_object, option_object, extra)
      end)
    end

  end # SelectList
end # FireWatir
