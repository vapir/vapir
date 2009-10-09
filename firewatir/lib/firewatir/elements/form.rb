module Watir
  class FFForm < FFElement
    include Form

    # Submit the form. Equivalent to pressing Enter or Return to submit a form.
    def submit
      assert_exists
      dom_object.submit
      wait
    end

  end # Form
end # FireWatir
