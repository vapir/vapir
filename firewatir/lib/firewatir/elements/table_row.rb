module Watir
  #
  # Description:
  # Class for Table row element.
  #
  class FFTableRow < FFElement
    include TableRow


    #
    # Description:
    #   Get array of all cells in Table Row
    #
    # Output:
    #   Array containing Table Cell elements.
    #
    def cells
      assert_exists
      jssh_to_element_collection(FFTableCell, element_object.cells)
    end

  end # TableRow
end # FireWatir
