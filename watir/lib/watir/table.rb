module Watir

  # This class is used for dealing with tables.
  # Normally a user would not need to create this object as it is returned by the Watir::Container#table method
  #
  # many of the methods available to this object are inherited from the Element class
  #
  class IETable < IEElement
    include Table
    include IEContainer
    
    def self.create_from_element(container, element)
      Watir::Table.create_from_element(container, element)
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