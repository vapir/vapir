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
    
    # Returns an initialized instance of a table object
    #   * container      - the container
    #   * how         - symbol - how we access the table
    #   * what         - what we use to access the table - id, name index etc
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      super nil
#    end
#    
#    def locate
#      if @how == :xpath
#        @o = @container.element_by_xpath(@what)
#      elsif @how == :ole_object
#        @o = @what
#      else
#        @o = @container.locate_tagged_element('TABLE', @how, @what)
#      end
#    end
    
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
    
    # this method is used to populate the properties in the to_s method
    def table_string_creator
      n = []
      n << "rows:".ljust(TO_S_SIZE) + self.row_count.to_s
      n << "cols:".ljust(TO_S_SIZE) + self.column_count.to_s
      return n
    end
    private :table_string_creator
    
    # returns the properties of the object in a string
    # raises an ObjectNotFound exception if the object cannot be found
    def to_s
      assert_exists
      r = string_creator
      r += table_string_creator
      return r.join("\n")
    end
    
    def rows
      assert_exists
      rows=[]
      element_object.rows.each do |row|
        rows << IETableRow.new(:element_object, row, extra)
      end
      
      ElementCollection.new(rows)
    end

    # iterates through the rows in the table. Yields a TableRow object
    def each
      assert_exists
      rows.each do |row|
        yield row
      end
    end
    
    # Returns a row in the table
    #   * index         - the index of the row
    def [](index)
      assert_exists
      rows[index]
    end
    
    # Returns the number of rows inside the table. does not recurse through
    # nested tables. 
    def row_count
      assert_exists
      element_object.rows.length
    end

    # This method returns the number of columns in a row of the table.
    # Raises an UnknownObjectException if the table doesn't exist.
    #   * index         - the index of the row
    def column_count(index=1)
      assert_exists
      _row(index).cells.length
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
    
    def table_body(index=1)
      raise NotImplementedError # wrong
#      return element_object.getElementsByTagName('TBODY')[index]
    end
    private :table_body
    
    # returns a watir object
    def tbody(how, what)
      raise NotImplementedError
#      return IETableBody.new(@container, how, what, self)
    end
    
    # returns a watir object
    def bodies
      raise NotImplementedError
#      assert_exists
#      return IETableBodies.new(@container, element_object)
    end
    
    # returns an ole object
    def _row(index)
      raise NotImplementedError
#      return element_object.invoke("rows")[(index - 1).to_s]
    end
    private :_row
    
    # Returns an array containing all the text values in the specified column
    # Raises an UnknownCellException if the specified column does not exist in every
    # Raises an UnknownObjectException if the table doesn't exist.
    # row of the table
    #   * columnnumber  - column index to extract values from
    def column_values(columnnumber)
      return (1..row_count).collect {|i| self[i][columnnumber].text}
    end
    
    # Returns an array containing all the text values in the specified row
    # Raises an UnknownObjectException if the table doesn't exist.
    #   * rownumber  - row index to extract values from
    def row_values(rownumber)
      return (1..column_count(rownumber)).collect {|i| self[rownumber][i].text}
    end
    
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
    
#    def locate
#      @o = nil
#      if @how == :ole_object
#        @o = @what
#      elsif @how == :xpath
#        @o = @container.element_by_xpath(@what)
#      else
#        @o = @container.locate_tagged_element("TR", @how, @what)
#      end
#      if @o # cant call the assert_exists here, as an exists? method call will fail
#        @cells = []
#        @o.cells.each do |oo|
#          @cells << IETableCell.new(@container, :ole_object, oo)
#        end
#      end
#    end
#    
#    # Returns an initialized instance of a table row
#    #   * o  - the object contained in the row
#    #   * container  - an instance of an IE object
#    #   * how          - symbol - how we access the row
#    #   * what         - what we use to access the row - id, index etc. If how is :ole_object then what is a Internet Explorer Raw Row
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      super nil
#    end
    
    # this method iterates through each of the cells in the row. Yields a TableCell object
    def each
      locate
      0.upto(@cells.length-1) { |i| yield @cells[i] }
    end
    
    # Returns an element from the row as a TableCell object
    def [](index)
      assert_exists
      if @cells.length < index
        raise UnknownCellException, "Unable to locate a cell at index #{index}" 
      end
      return @cells[(index - 1)]
    end
    
    # defaults all missing methods to the array of elements, to be able to
    # use the row as an array
    #        def method_missing(aSymbol, *args)
    #            return @o.send(aSymbol, *args)
    #        end
    def column_count
      locate
      @cells.length
    end
  end
  
  # this class is a table cell - when called via the Table object
  class IETableCell < IEElement
    include TableCell
    include Watir::Exception
    include IEContainer
    
#    def locate
#      if @how == :xpath
#        @o = @container.element_by_xpath(@what)
#      elsif @how == :ole_object
#        @o = @what
#      else
#        @o = @container.locate_tagged_element("TD", @how, @what)
#      end
#    end
#    
#    # Returns an initialized instance of a table cell
#    #   * container  - an  IE object
#    #   * how        - symbol - how we access the cell
#    #   * what       - what we use to access the cell - id, name index etc
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      super nil
#    end
    
#    def ole_inner_elements
#      locate
#      return element_object.all
#    end
#    private :ole_inner_elements

# ???     
#    def document
#      locate
#      return element_object
#    end
    
    alias to_s text
    
    def colspan
      locate
      element_object.colSpan
    end
    
  end
  
end