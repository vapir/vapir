module Watir
  #
  # Description:
  # Class for Table Cell.
  #
  class FFTableCell < FFElement
    include TableCell

    alias to_s text

    #
    # Description:
    #   Gets the col span of table cell.
    #
    # Output:
    #   Colspan of table cell.
    #
    def colspan
      assert_exists
      invoke("colSpan")
    end

  end # TableCell
end # FireWatir
