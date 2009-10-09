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
      ElementCollection.new(element_object.cells.to_array.map do |cell|
        FFTableCell.new(:element_object, cell, extra)
      end)
    end

  end # TableRow
end # FireWatir
