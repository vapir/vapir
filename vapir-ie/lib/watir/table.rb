module Watir

  # This class is used for dealing with tables.
  # Normally a user would not need to create this object as it is returned by the Watir::Container#table method
  #
  # many of the methods available to this object are inherited from the Element class
  #
  class IE::Table < IE::Element
    include Watir::Table
    
    def self.create_from_element(container, element)
      Watir::Table.create_from_element(container, element)
    end
  end
  
  # this class is a table body
  class IE::TableBody < IE::Element
    include Watir::TBody
  end
    
  class IE::TableRow < IE::Element
    include Watir::TableRow
  end
  
  # this class is a table cell - when called via the Table object
  class IE::TableCell < IE::Element
    include Watir::TableCell
  end
  
end