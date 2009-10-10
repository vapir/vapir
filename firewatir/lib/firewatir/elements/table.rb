module Watir
  class FFTable < FFElement
    include Table
    # returns an ElementCollection of rows in the table.
    def rows
      assert_exists
      jssh_to_element_collection(FFTableRow, element_object.rows)
    end
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

  end # Table

  class FFTBody < FFElement
    include TBody
    # returns an ElementCollection of rows in the tbody.
    def rows
      assert_exists
      jssh_to_element_collection(FFTableRow, element_object.rows)
    end
  end
end # FireWatir
