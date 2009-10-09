module Watir
  class Element
    # Flash the element the specified number of times.
    # Defaults to 10 flashes.
    def flash number=10
      assert_exists
      number.times do
        highlight(:set)
        sleep 0.05
        highlight(:clear)
        sleep 0.05
      end
      nil
    end
  end
end
