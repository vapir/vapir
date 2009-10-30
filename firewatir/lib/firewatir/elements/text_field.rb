module Watir
  #
  # Description:
  # Class for Text Field element.
  #
  class FFTextField < FFInputElement
    include TextField

    #
    # Description:
    #   Checks if the provided text matches with the contents of text field. Text can be a string or regular expression.
    #
    # Input:
    #   - containsThis - Text to verify.
    #
    # Output:
    #   True if provided text matches with the contents of text field, false otherwise.
    #
    def verify_contains( containsThis )
      assert_exists do
        if containsThis.kind_of? String
          return true if self.value == containsThis
        elsif containsThis.kind_of? Regexp
          return true if self.value.match(containsThis) != nil
        end
        return false
      end
    end

    # this method is used to drag the entire contents of the text field to another text field
    #  19 Jan 2005 - It is added as prototype functionality, and may change
    #   * destination_how   - symbol, :id, :name how we identify the drop target
    #   * destination_what  - string or regular expression, the name, id, etc of the text field that will be the drop target
    # TODO: Can we have support for this in Firefox.
    #def drag_contents_to( destination_how , destination_what)
    #    assert_exists
    #    destination = element.text_field(destination_how, destination_what)
    #    raise UnknownObjectException ,  "Unable to locate destination using #{destination_how } and #{destination_what } "   if destination.exists? == false

    #    focus
    #    select()
    #    value = self.value

    #    fireEvent("onSelect")
    #    fireEvent("ondragstart")
    #    fireEvent("ondrag")
    #    destination.fireEvent("onDragEnter")
    #    destination.fireEvent("onDragOver")
    #    destination.fireEvent("ondrop")

    #    fireEvent("ondragend")
    #    destination.value= ( destination.value + value.to_s  )
    #    self.value = ""
    #end
    # alias dragContentsTo drag_contents_to



  end # TextField
end # FireWatir

