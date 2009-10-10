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
    # TODO: look at this - seems to be named wrong; it locates, doesn't create anything. also uses the wrong constructor. 
    def self.create_from_element(container, element)
      raise NotImplementedError
      element.locate if element.respond_to?(:locate)
      o = element.ole_object.parentElement
      o = o.parentElement until o.tagName == 'TABLE'
      new container, :ole_object, o 
    end
    
    # override the highlight method, as if the tables rows are set to have a background color,
    # this will override the table background color, and the normal flash method won't work
    # TODO/Fix: move out to common 
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
      ole_to_element_collection(IETableRow, element_object.rows)
    end
  end
  
  # this class is a table body
  class IETableBody < IEElement
    include TBody
    def rows
      assert_exists
      ole_to_element_collection(IETableRow, element_object.rows)
    end
  end
    
  class IETableRow < IEElement
    include TableRow
    
    def cells
      assert_exists
      ole_to_element_collection(IETableCell, element_object.cells)
    end
  end
  
  # this class is a table cell - when called via the Table object
  class IETableCell < IEElement
    include TableCell
  end
  
end