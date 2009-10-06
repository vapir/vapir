module Watir
  #
  # Description:
  #   Base class containing items that are common between select list, text field, button, hidden, file field classes.
  #
  class FFInputElement < FFElement
    Specifiers= [ {:tagName => 'input'},
                  {:tagName => 'textarea'},
                  {:tagName => 'button'},
                  {:tagName => 'select'},
                ]
    ContainerMethods=:input
    ContainerCollectionMethods=:inputs
    include InputElement

    #
    # Description:
    #   Initializes the instance of element.
    #
    # Input:
    #   - how - Attribute to identify the element.
    #   - what - Value of that attribute.
    #
#    def initialize(container, how, what)
#      @how = how
#      @what = what
#      @container = container
#      #@element_name = ""
#      #super(nil)
#    end

  end # FireWatir
end # InputElement
