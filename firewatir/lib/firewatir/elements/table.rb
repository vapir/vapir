module Watir

  module HasRowsAndColumns
    #
    # Description:
    #   Gets the table as a 2 dimensional array. Dont expect too much if there are nested tables, colspan etc.
    #
    # Output:
    #   2D array with rows and column text of the table.
    #
    def to_a
      rows.map{|row| row.cells.map{|cell| cell.to_s.strip}}
    end

    #
    # Description:
    #   Gets the array of rows in the table.
    #
    # Output:
    #   ElementCollection of rows.
    #
    def rows
      assert_exists
      ElementCollection.new(element_object.rows.to_array.map do |row|
        FFTableRow.new(:element_object, row, extra)
      end)
    end

  end
  
  class FFTable < FFElement
    include Table
    include HasRowsAndColumns
    #
    # Description:
    #   Override the highlight method, as if the tables rows are set to have a background color,
    #   this will override the table background color,  and the normal flash method wont work
    #
=begin #TODO: fix this
    def highlight(set_or_clear )
      case set_or_clear
      when :set
        @original_border=self.border
      if set_or_clear == :set
        begin
          @original_border = @o.border.to_i
          if self.border.to_i==1
            self.border = 2
          else
            self.border=1
          end
        #rescue
          @original_border = nil
        end
      else
        begin
          self.border= @original_border unless @original_border == nil
          @original_border = nil
        #rescue
          # we could be here for a number of reasons...
        ensure
          @original_border = nil
        end
      end
      super
    end
=end
    #
    # Description:
    #   Used to populate the properties in the to_s method.
    #
    #def table_string_creator
    #    n = []
    #    n <<   "rows:".ljust(TO_S_SIZE) + self.row_count.to_s
    #    n <<   "cols:".ljust(TO_S_SIZE) + self.column_count.to_s
    #    return n
    #end
    #private :table_string_creator

    # returns the properties of the object in a string
    # raises an ObjectNotFound exception if the object cannot be found
    # TODO: Implement to_s method for this class.

#    def to_s
#      assert_exists
#      r = super({"rows" => "rows.length", "cellspacing" => "cellspacing", "cellpadding" => "cellpadding", "border" => "border"})
#      # r += self.column_count.to_s
#    end

  end # Table

  class FFTBody < FFElement
    include FFNonControlElement
    include TBody
    include HasRowsAndColumns
  end
end # FireWatir
