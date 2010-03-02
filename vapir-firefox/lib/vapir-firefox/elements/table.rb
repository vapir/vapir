module Vapir
  class Firefox::Table < Firefox::Element
    include Vapir::Table

    def self.create_from_element(container, element)
      Vapir::Table.create_from_element(container, element)
    end
  end # Table

  class Firefox::TBody < Firefox::Element
    include Vapir::TBody
  end
end # Vapir
