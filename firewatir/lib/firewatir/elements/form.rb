module Watir
  class FFForm < FFElement
    include Form
    TAG='form'
    DefaultHow=:name
    ContainerMethods=:form
    ContainerCollectionMethods=:forms

    # Submit the form. Equivalent to pressing Enter or Return to submit a form.
    def submit
      assert_exists
      dom_object.submit
      wait
    end

  end # Form
end # FireWatir
