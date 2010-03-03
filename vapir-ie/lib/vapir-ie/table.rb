require 'vapir-ie/element'
require 'vapir-common/elements/elements'

module Vapir

  # This class is used for dealing with tables.
  # Normally a user would not need to create this object as it is returned by the Vapir::Container#table method
  #
  # many of the methods available to this object are inherited from the Element class
  #
  class IE::Table < IE::Element
    include Vapir::Table
    
    def self.create_from_element(container, element)
      Vapir::Table.create_from_element(container, element)
    end
  end
  
  # this class is a table body
  class IE::TableBody < IE::Element
    include Vapir::TBody
  end
    
  class IE::TableRow < IE::Element
    include Vapir::TableRow
  end
  
  # this class is a table cell - when called via the Table object
  class IE::TableCell < IE::Element
    include Vapir::TableCell
  end
  
end
