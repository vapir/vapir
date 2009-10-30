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
  end
  
  # this class is a table body
  class IETableBody < IEElement
    include TBody
  end
    
  class IETableRow < IEElement
    include TableRow
  end
  
  # this class is a table cell - when called via the Table object
  class IETableCell < IEElement
    include TableCell
  end
  
end