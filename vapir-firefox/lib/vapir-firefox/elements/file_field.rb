module Watir
  #
  # Description:
  #   Class for FileField element.
  #
  class Firefox::FileField < Firefox::InputElement
    include Watir::FileField

    #
    # Description:
    #   Sets the path of the file in the textbox.
    #
    # Input:
    #   path - Path of the file.
    #
    def set(path)
      assert_exists do
        element_object.value=path
        fire_event("onChange")
      end
    end

  end # FileField
end # FireWatir
