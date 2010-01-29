module Watir
  class Firefox::Table < Firefox::Element
    include Watir::Table

    def self.create_from_element(container, element)
      Watir::Table.create_from_element(container, element)
    end
  end # Table

  class Firefox::TBody < Firefox::Element
    include Watir::TBody
  end
end # FireWatir
