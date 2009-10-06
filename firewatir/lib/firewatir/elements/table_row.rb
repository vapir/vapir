module Watir
  #
  # Description:
  # Class for Table row element.
  #
  class FFTableRow < FFElement
    include TableRow

    def self.tagName
      'tr'
    end
    #
    # Description:
    #   Locate the table row element on the page.
    #
#    def locate
#      @o = nil
#      case @how
#      when :jssh_name
#        @element_name = @what
#      when :xpath
#        @element_name = element_by_xpath(@container, @what)
#      else
#        @element_name = locate_tagged_element("TR", @how, @what)
#      end
#      @o = self
#    end

    #
    # Description:
    #   Initializes the instance of table row object.
    #
    # Input:
    #   - how - Attribute to identify the table row element.
    #   - what - Value of that attribute.
    #
#    def initialize(container, how, what)
#      @how = how
#      @what = what
#      @container = container
#      #super nil
#    end

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
        FFTableCell.new(cell, extra)
      end
    end

  end # TableRow
end # FireWatir
