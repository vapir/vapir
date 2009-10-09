module Watir
  #
  # Description:
  #   Class for FileField element.
  #
  class FFFileField < FFInputElement
    include FileField

    #
    # Description:
    #   Sets the path of the file in the textbox.
    #
    # Input:
    #   path - Path of the file.
    #
    def set(path)
      assert_exists
      element_object.value=path
      fireEvent("onChange")
    end

  end # FileField
end # FireWatir
