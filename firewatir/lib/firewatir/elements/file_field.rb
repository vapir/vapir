module Watir
  #
  # Description:
  #   Class for FileField element.
  #
  class FFFileField < FFInputElement
    include FileField
    Specifiers=[{:tagName => 'input', :type => 'file'}]
    DefaultHow=:name
    ContainerMethods=:file_field
    ContainerCollectionMethods=:file_fields

    #
    # Description:
    #   Sets the path of the file in the textbox.
    #
    # Input:
    #   path - Path of the file.
    #
    def set(path)
      assert_exists
      dom_object.value=path
      fireEvent("onChange")
    end

  end # FileField
end # FireWatir
