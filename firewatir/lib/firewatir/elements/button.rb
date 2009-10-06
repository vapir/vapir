module Watir
  #
  # Description:
  #   Class for Button element.
  #
  class FFButton < FFInputElement
    include Button
    Specifiers=[ {:tagName => 'input', :types => ['button', 'submit', 'image', 'reset']}, 
                 {:tagName => 'button'}
               ]
    DefaultHow=:value
    ContainerMethods=:button
    ContainerCollectionMethods=:buttons

  end # Button
end # FireWatir
