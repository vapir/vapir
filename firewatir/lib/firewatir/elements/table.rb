module Watir
  class FFTable < FFElement
    include Table

    def self.create_from_element(container, element)
      Watir::Table.create_from_element(container, element)
    end
  end # Table

  class FFTBody < FFElement
    include TBody
  end
end # FireWatir
