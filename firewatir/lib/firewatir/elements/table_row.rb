module Watir
  #
  # Description:
  # Class for Table row element.
  #
  class FFTableRow < FFElement
    include TableRow

    #
    # Description:
    #   Gets the length of columns in table row.
    #
    # Output:
    #   Length of columns in table row.
    #
    def column_count
      assert_exists
      arr_cells = cells
      return arr_cells.length
    end

    #
    # Description:
    #   Get cell at specified index in a row.
    #
    # Input:
    #   key - column index.
    #
    # Output:
    #   Table cell element at specified index.
    #
    def [] (key)
      assert_exists
      arr_cells = cells
      return arr_cells[key - 1]
    end

    #
    # Description:
    #   Iterate over each cell in a row.
    #
    def each
      assert_exists
      arr_cells = cells
      for i in 0..arr_cells.length - 1 do
        yield arr_cells[i]
      end
    end

    #
    # Description:
    #   Get array of all cells in Table Row
    #
    # Output:
    #   Array containing Table Cell elements.
    #
    def cells
      assert_exists
      dom_object.cells.to_array.map do |cell|
        FFTableCell.new(:dom_object, cell, extra)
      end
    end

  end # TableRow
end # FireWatir
