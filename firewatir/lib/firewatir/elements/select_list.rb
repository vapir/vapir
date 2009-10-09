module Watir
  #
  # Description:
  #   Class for SelectList element.
  #
  class FFSelectList < FFInputElement
    include SelectList

    #   Clears the selected items in the select box.
    def clear
      assert_exists
      #highlight(:set)
      wait = false
      options.each do |option|
        option.selected=false
        wait=true
      end
      fire_event :change
      self.wait if wait
      #highlight(:clear)
    end
    alias clearSelection clear

#    def each
#      raise NotImplementedError
#    end

    #
    # Description:
    #   Get option element at specified index in select list.
    #
    # Input:
    #   index (starting at 1)
    #
    # Output:
    #   Option element at specified index
    #
    def [](index)
      options[index]
    end

    #
    # Description:
    #   Selects an item by text. If you need to select multiple items you need to call this function for each item.
    #
    # Input:
    #   - item - Text of item to be selected.
    #
    def select_text(option_text)
      option=options.detect{|option| Watir::Specifier.fuzzy_match(option.text, option_text)} || (raise Watir::Exception::NoValueFoundException)
      option.selected=true
      fire_event :change
    end
    alias select select_text
    alias set select_text

    #
    # Description:
    #   Selects an item by value. If you need to select multiple items you need to call this function for each item.
    #
    # Input:
    # - item - Value of the item to be selected.
    #
    def select_value(option_value)
      option=options.detect{|option| Watir::Specifier.fuzzy_match(option.value, option_value)} || (raise Watir::Exception::NoValueFoundException)
      option.selected=true
      fire_event :change
    end

    #
    # Description:
    #   Gets all the items in the select list as an array.
    #   An empty array is returned if the select box has no contents.
    #
    # Output:
    #   Array containing the items of the select list.
    #
    def options
      ElementCollection.new(element_object.options.to_array.map do |option_object|
        FFOption.new(:element_object, option_object, extra)
      end)
    end

    def option_texts
      options.map{|o| o.text }
    end
    alias getAllContents option_texts

    #
    # Description:
    #   Gets all the selected items in the select list as an array.
    #   An empty array is returned if the select box has no selected item.
    #
    # Output:
    #   Array containing the selected items of the select list.
    #
    def selected_options
      assert_exists
      options.select{|o|o.selected}
    end

    def selected_option_texts
      selected_options.map{|o| o.text }
    end
    
    alias getSelectedItems selected_option_texts

    #
    # Description:
    #   Get the option using attribute and its value.
    #
    # Input:
    #   - attribute - Attribute used to find the option.
    #   - value - value of that attribute.
    #
#    def option (attribute, value)
#      raise NotImplementedError
#      assert_exists
#      FFOption.new(self, attribute, value)
#    end
    
    private
    
    # Description:
    #   Selects items from the select box.
    #
    # Input:
    #   - name  - :value or :text - how we find an item in the select box
    #   - item  - value of either item text or item value.
    #
#    def select_items_in_select_list(attribute, value)
#      raise NotImplementedError
#      assert_exists
      
#      attribute = attribute.to_s
#      found     = false
      
#      value = value.to_s unless [Regexp, String].any? { |e| value.kind_of? e }

#      highlight( :set )
#      each do |option|
#        next unless value.matches(option.invoke(attribute))
#        found = true  
#        next if option.selected
#        
#        option.assign('selected', true)
#        fireEvent("onChange")
#        wait
#      end
#      highlight( :clear )

#      unless found
#        raise Exception::NoValueFoundException, "No option with #{attribute} of #{value.inspect} in this select element"
#      end
      
#      value
#    end

    #

  end # Selects
end # FireWatir
