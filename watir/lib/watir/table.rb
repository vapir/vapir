module Watir

  # This class is used for dealing with tables.
  # Normally a user would not need to create this object as it is returned by the Watir::Container#table method
  #
  # many of the methods available to this object are inherited from the Element class
  #
  class IETable < IEElement
    include Table
    include IEContainer
    
    # Returns the table object containing the element
    #   * container  - an instance of an IE object
    #   * anElement  - a Watir object (TextField, Button, etc.)
    def self.create_from_element(container, element)
      element.locate if element.respond_to?(:locate)
      o = element.ole_object.parentElement
      o = o.parentElement until o.tagName == 'TABLE'
      new container, :ole_object, o 
    end
    
    # override the highlight method, as if the tables rows are set to have a background color,
    # this will override the table background color, and the normal flash method won't work
    def highlight(set_or_clear)
      if set_or_clear == :set
        begin
          @original_border = element_object.border.to_i
          if element_object.border.to_i==1
            element_object.border = 2
          else
            element_object.border = 1
          end
        rescue
          @original_border = nil
        end
      else
        begin
          element_object.border= @original_border unless @original_border == nil
          @original_border = nil
        rescue
          # we could be here for a number of reasons...
        ensure
          @original_border = nil
        end
      end
      super
    end
    
    def rows
      assert_exists
      rows=[]
      element_object.rows.each do |row|
        rows << IETableRow.new(:element_object, row, extra)
      end
      ElementCollection.new(rows)
    end
    
    # This method returns the table as a 2 dimensional array. 
    # Don't expect too much if there are nested tables, colspan etc.
    # Raises an UnknownObjectException if the table doesn't exist.
    # http://www.w3.org/TR/html4/struct/tables.html
    def to_a
      raise NotImplementedError # this is wrong 
      assert_exists
      y = []
      table_rows = element_object.getElementsByTagName("TR")
      for row in table_rows
        x = []
        for td in row.getElementsbyTagName("TD")
          x << td.innerText.strip
        end
        y << x
      end
      return y
    end
    
#    def table_body(index=1)
#      raise NotImplementedError # wrong
#      return element_object.getElementsByTagName('TBODY')[index]
#    end
#    private :table_body
    
    # returns a watir object
#    def tbody(how, what)
#      raise NotImplementedError
#      return IETableBody.new(@container, how, what, self)
#    end
    
    # returns a watir object
#    def bodies
#      raise NotImplementedError
#      assert_exists
#      return IETableBodies.new(@container, element_object)
#    end
    
    # returns an ole object
#    def _row(index)
#      raise NotImplementedError
#      return element_object.invoke("rows")[(index - 1).to_s]
#    end
#    private :_row
    
    # Returns an array containing all the text values in the specified column
    # Raises an UnknownCellException if the specified column does not exist in every
    # Raises an UnknownObjectException if the table doesn't exist.
    # row of the table
    #   * columnnumber  - column index to extract values from
#    def column_values(columnnumber)
#      return (1..row_count).collect {|i| self[i][columnnumber].text}
#    end
    
    # Returns an array containing all the text values in the specified row
    # Raises an UnknownObjectException if the table doesn't exist.
    #   * rownumber  - row index to extract values from
#    def row_values(rownumber)
#      return (1..column_count(rownumber)).collect {|i| self[rownumber][i].text}
#    end
    
  end
  
  # this class is a collection of the table body objects that exist in the table
  # it wouldnt normally be created by a user, but gets returned by the bodies method of the Table object
  # many of the methods available to this object are inherited from the Element class
  #
#  class IETableBodies < IEElement
#    def initialize(container, parent_table)
#      set_container container
#      @o = parent_table     # in this case, @o is the parent table
#    end
#    
#    # returns the number of TableBodies that exist in the table
#    def length
#      assert_exists
#      return @o.tBodies.length
#    end
#    
#    # returns the n'th Body as a Watir TableBody object
#    def []n
#      assert_exists
#      return TableBody.new(@container, :ole_object, ole_table_body_at_index(n))
#    end
#    
#    # returns an ole table body
#    def ole_table_body_at_index(n)
#      return @o.tBodies.item(n-1)
#    end
#    
#    # iterates through each of the TableBodies in the Table. Yields a TableBody object
#    def each
#      1.upto(@o.tBodies.length) do |i| 
#        yield IETableBody.new(@container, :ole_object, ole_table_body_at_index(i))
#      end
#    end
#    
#  end
  
  # this class is a table body
  class IETableBody < IEElement
    include TBody
#    def locate
#      @o = nil
#      if @how == :ole_object
#        @o = @what     # in this case, @o is the table body
#      elsif @how == :index
#        @o = @parent_table.bodies.ole_table_body_at_index(@what)
#      end
#      @rows = []
#      if @o
#        @o.rows.each do |oo|
#          @rows << IETableRow.new(@container, :ole_object, oo)
#        end
#      end
#    end
#    
#    def initialize(container, how, what, parent_table=nil)
#      set_container container
#      @how = how
#      @what = what
#      @parent_table = parent_table
#      super nil
#    end
    
    # returns the specified row as a TableRow object
    def [](n)
      assert_exists
      return @rows[n - 1]
    end
    
    # iterates through all the rows in the table body
    def each
      locate
      0.upto(@rows.length - 1) { |i| yield @rows[i] }
    end
    
    # returns the number of rows in this table body.
    def length
      return @rows.length
    end
  end
    
  class IETableRow < IEElement
    include TableRow
    
    def cells
      assert_exists
      cells=[]
      element_object.cells.each do |cell|
        cells << IETableCell.new(:element_object, cell, extra)
      end
      ElementCollection.new(cells)
    end
  end
  
  # this class is a table cell - when called via the Table object
  class IETableCell < IEElement
    include TableCell
  end
  
end