module Watir
  #
  # Description:
  #   Class for Option element.
  #
  class FFOption < FFElement
    include Option
    def select
      assert_exists
      element_object.selected=true
    end
    
  end # Option
end # FireWatir