require 'watir/elements/element'
require 'watir/commoncontainer'

module Watir
  module Frame
    Specifiers=[ {:tagName => 'frame'},
                 {:tagName => 'iframe'},
               ]
    include ContainerMethodsFromName
    include ElementModule
    DefaultHow=:name
    
    dom_wrap_inspect :name, :src
  end
  module InputElement
    Specifiers= [ {:tagName => 'input'},
                  {:tagName => 'textarea'},
                  {:tagName => 'button'},
                  {:tagName => 'select'},
                ]
    ContainerSingleMethod=['input', 'input_element']
    ContainerMultipleMethod=['inputs', 'input_elements']
    include ElementModule
    
    dom_wrap_inspect :name, :value, :type
    dom_wrap :value=
    dom_wrap :default_value => :defaultValue
    dom_wrap :disabled
    alias disabled? disabled
    dom_wrap :readonly => :readOnly, :readonly? => :readOnly, :readOnly? => :readOnly
    dom_wrap :focus

    # Checks if this element is enabled or not. Raises ObjectDisabledException if this is disabled.
    def assert_enabled
      if disabled
        raise Exception::ObjectDisabledException, "#{self.inspect} is disabled"
      end
    end

    #   Checks if object is readonly or not. Raises ObjectReadOnlyException if this is readonly
    def assert_not_readonly
      if readonly
        raise Exception::ObjectReadOnlyException, "#{self.inspect} is readonly"
      end
    end

    # Returns true if element is enabled, otherwise returns false.
    def enabled?
      !disabled
    end
    
  end
  module TextField
    Specifiers= [ {:tagName => 'textarea'},
                  {:tagName => 'input', :types => ['text', 'textarea','password','hidden']},
                ]
    include ContainerMethodsFromName
    include ElementModule
    
    dom_wrap :size, :maxLength, :maxlength => :maxLength
    dom_wrap_deprecated :getContents, :value, :value
    
    # Clears the contents of the text box.
    #   Raises UnknownObjectException if the object can't be found
    #   Raises ObjectDisabledException if the object is disabled
    #   Raises ObjectReadOnlyException if the object is read only
    def clear
      set ''
    end
    # Appends the specified string value to the contents of the text box.
    #   Raises UnknownObjectException if the object cant be found
    #   Raises ObjectDisabledException if the object is disabled
    #   Raises ObjectReadOnlyException if the object is read only
    def append(text)
      set value+text
    end
    # Sets the contents of the text box to the specified text value
    #   Raises UnknownObjectException if the object cant be found
    #   Raises ObjectDisabledException if the object is disabled
    #   Raises ObjectReadOnlyException if the object is read only
    # todo/fix: type_keys and typingspeed
    def set(value)
      assert_enabled
      assert_not_readonly
      
      highlight(:set)
      
      value_chars=value.split(//) # split on blank regexp (rather than iterating over each byte) for multibyte chars
      if self.type.downcase=='text' && maxlength && maxlength >= 0 && value_chars.length > maxlength
        value_chars=value_chars[0...maxlength]
        value=value_chars.join('')
      end
      element_object.scrollIntoView
      type_keys=respond_to?(:type_keys) ? self.type_keys : true
      typingspeed=respond_to?(:typingspeed) ? self.typingspeed : 0
      if type_keys
        element_object.focus
        fire_event('onFocus', :highlight => false)
        element_object.select
        fire_event("onSelect", :highlight => false)
        (0..value_chars.length).each do |i|
          sleep typingspeed
          element_object.value = value_chars[0...i].join('')
          fire_event :onKeyDown, :highlight => false
          fire_event :onKeyPress, :highlight => false
          fire_event :onKeyUp, :highlight => false
        end
        fire_event("onChange", :highlight => false)
        fire_event('onBlur', :highlight => false)
      else
        element_object.value = value
      end
      wait
      highlight(:clear)
    end
  end
  module Hidden
    Specifiers=[{:tagName => 'input', :type => 'hidden'}]
    include ContainerMethodsFromName
    DefaultHow=:name
    include ElementModule
    
    # Sets the value of this hidden field. Overriden from TextField, as there is no way to set focus and type to a hidden field
    def set(value)
      self.value=value
    end

    # Appends the value to the value of this hidden field. 
    def append(append_value)
      self.value = self.value + append_value
    end

    # Clears the value of this hidden field. 
    def clear
      self.value = ""
    end

    # Hidden element is never visible - returns false.
    def visible?
      assert_exists
      false
    end
  end
  module Button
    Specifiers=[ {:tagName => 'input', :types => ['button', 'submit', 'image', 'reset']}, 
                 {:tagName => 'button'}
               ]
    include ContainerMethodsFromName
    DefaultHow=:value
    include ElementModule
    dom_wrap :src, :height, :width # these are used on <input type=image>
  end
  module FileField
    Specifiers=[{:tagName => 'input', :type => 'file'}]
    include ContainerMethodsFromName
    DefaultHow=:name
    include ElementModule
  end
  module Option
    TAG='option'
    include ContainerMethodsFromName
    include ElementModule
    dom_wrap :text, :value, :selected, :selected=
  end
  module SelectList
    TAG='select'
    include ContainerMethodsFromName
    include ElementModule

    def [](index)
      options[index]
    end

    #   Clears the selected items in the select box.
    def clear
      assert_exists
      with_highlight do
        wait = false
        options.each do |option|
          option.selected=false
          wait=true
        end
        fire_event :onchange, :highlight => false
        self.wait if wait
      end
    end
    alias_deprecated :clearSelection, :clear
    
    # selects options whose text matches the given text. 
    # Raises NoValueFoundException if the specified value is not found.
    #
    # takes method_options hash (note, these are flags for the function, not to be confused with the Options of the select list)
    # - :wait => true/false  default true. controls whether #wait is called and whether fire_event or fire_event_no_wait is
    #   used for the onchange event. 
    def select_text(option_text, method_options={})
      select_options_if(method_options) {|option| Watir::Specifier.fuzzy_match(option.text, option_text) }
    end
    alias select select_text
    alias set select_text

    # selects options whose value matches the given value. 
    # Raises NoValueFoundException if the specified value is not found.
    #
    # takes options hash (note, these are flags for the function, not to be confused with the Options of the select list)
    # - :wait => true/false  default true. controls whether #wait is called and whether fire_event or fire_event_no_wait is
    #   used for the onchange event. 
    def select_value(option_value, method_options={})
      select_options_if(method_options) {|option| Watir::Specifier.fuzzy_match(option.value, option_value) }
    end
    
    def option_texts
      options.map{|o| o.text }
    end
    alias_deprecated :getAllContents, :option_texts
    
    #   Returns an array of selected option Elements in this select list.
    #   An empty array is returned if the select box has no selected item.
    def selected_options
      assert_exists
      options.select{|o|o.selected}
    end

    def selected_option_texts
      selected_options.map{|o| o.text }
    end
    
    alias_deprecated :getSelectedItems, :selected_option_texts

    private
    # yields each option, selects the option if the given block returns true. fires onchange event if
    # any have changed. raises Watir::Exception::NoValueFoundException if none matched. 
    # takes options hash (note, these are flags for the function, not to be confused with the Options of the select list)
    # - :wait => true/false  default true. controls whether #wait is called and whether fire_event or fire_event_no_wait is
    #   used for the onchange event. 
    def select_options_if(method_options={})
      method_options={:wait => true, :highlight => true}.merge(method_options)
      raise ArgumentError, "no block given!" unless block_given?
      any_changed=false
      with_highlight(method_options[:highlight]) do
        self.options.each do |option|
          if yield option
            any_changed=true
            option.selected=true
          end
        end
        if any_changed
          fire_event(:onchange, method_options.merge(:highlight => false))
        else
          raise Watir::Exception::NoValueFoundException
        end
      end
    end
  end
  
  module RadioCheckBoxCommon
    extend DomWrap
    dom_wrap :checked, :checked? => :checked, :set? => :checked
    dom_wrap_deprecated :isSet?, :checked, :checked
    dom_wrap_deprecated :getState, :checked, :checked

    #   Unchecks the radio button or check box element.
    #   Raises ObjectDisabledException exception if element is disabled.
    def clear
      set(false)
    end
    
    #   Checks the radio button or check box element.
    #   Raises ObjectDisabledException exception if element is disabled.
    def set(state=true)
      assert_exists
      assert_enabled
      with_highlight do
        if checked!=state || self.is_a?(Radio) # don't click if it's already checked. but do anyway if it's a radio. 
          fire_event :onclick, :highlight => false
        end
        if checked!=state # firing the click event doesn't change the checked state in IE. check and change if needed. 
          element_object.checked=state
        end
        fire_event :onchange, :highlight => false
        wait
      end
    end
  end
  
  module Radio
    Specifiers=[{:tagName => 'input', :type => 'radio'}]
    include ContainerMethodsFromName
    ContainerMethodExtraArgs=[:value]
    include ElementModule
    
    include RadioCheckBoxCommon
    inspect_these :checked
  end
  module CheckBox
    Specifiers=[{:tagName => 'input', :type => 'checkbox'}]
    ContainerSingleMethod=['checkbox', 'check_box']
    ContainerMultipleMethod=['checkboxes', 'check_boxes']
    ContainerMethodExtraArgs=[:value]
    include ElementModule

    include RadioCheckBoxCommon
    inspect_these :checked
  end
  module Form
    TAG='form'
    include ContainerMethodsFromName
    DefaultHow=:name
    include ElementModule
    
    dom_wrap_inspect :name, :action
  end
  module Image
    TAG = 'IMG'
    include ContainerMethodsFromName
    DefaultHow=:name
    include ElementModule
    
    dom_wrap_inspect :src, :name, :width, :height, :alt
    dom_wrap :border
  end
  module HasRowsAndColumns
    # Returns a 2 dimensional array of text contents of each row and column of the table or tbody.
    def to_a
      rows.map{|row| row.cells.map{|cell| cell.text.strip}}
    end

    # iterates through the rows in the table. Yields a TableRow object
    def each_row
      rows.each do |row|
        yield row
      end
    end
    alias each each_row

    # Returns the TableRow at the given index. 
    # indices start at 1.
    def [](index)
      rows[index]
    end
    
    # Returns the number of rows inside the table. does not recurse through
    # nested tables. 
    def row_count
      element_object.rows.length
    end
    
    # returns the number of columns of the table, either on the row at the given index
    # or (by default) on the first row.
    # takes into account any defined colSpans.
    # returns nil if the table has no rows. 
    # (if you want the number of cells - not taking into account colspans - use #cell_count
    # on the row in question)
    def column_count(index=nil)
      if index
        rows[index].column_count
      elsif row=rows.first
        row.column_count
      else
        nil
      end
    end
    
    #
    # Description:
    #   Get the text of each column in the specified row.
    #
    # Input:
    #   Row index (starting at 1)
    #
    # Output:
    #   Value of all columns present in the row.
    #
    # is this method really useful?
    def row_texts_at(row_index)
      rows[row_index].cells.map do |cell|
        cell.text
      end
    end
    alias_deprecated :row_values, :row_texts_at
    
    # Returns an array containing the text values in the specified column index in each row. 
    def column_texts_at(column_index)
      rows.map do |row|
        row.cells[column_index].text
      end
    end
    alias_deprecated :column_values, :column_texts_at
    
    
    # I was going to define #cell_count(index=nil) here as an alternative to #column_count
    # but it seems confusing; to me #cell_count on a Table would count up all the cells in
    # all rows, so going to avoid confusion and not do it. 

  end
  module Table
    # Table assumes the inheriting class defines a #rows method which returns 
    # an ElementCollection
    TAG = 'TABLE'
    include ContainerMethodsFromName
    include ElementModule
    include HasRowsAndColumns
    
  end
  module TBody
    TAG = 'TBODY'
    ContainerSingleMethod=['tbody']
    ContainerMultipleMethod=['tbodies']
    include ElementModule
    include HasRowsAndColumns
  end
  module TableRow
    # TableRow assumes that the inheriting class defines a #cells method which
    # returns an ElementCollection
    TAG='tr'
    include ContainerMethodsFromName
    include ElementModule
    
    #   Iterate over each cell in the row.
    def each_cell
      cells.each do |cell|
        yield cell
      end
    end
    alias each each_cell
    
    # returns the TableCell at the specified index
    def [](index)
      cells[index]
    end
    
    def column_count
      cells.inject(0) do |count, cell|
        count+ cell.colSpan || 1
      end
    end
    def cell_count
      cells.length
    end
  end
  module TableCell
    TAG='td'
    include ContainerMethodsFromName
    include ElementModule
    dom_wrap :colSpan, :rowSpan, :colspan => :colSpan, :rowspan => :rowSpan
  end
  module Link
    TAG = 'A'
    ContainerSingleMethod=['a', 'link']
    ContainerMultipleMethod=['as', 'links']
    include ElementModule
    
    dom_wrap_inspect :href, :name
  end
  module Pre
    TAG = 'PRE'
    include ContainerMethodsFromName
    include ElementModule
  end
  module P
    TAG = 'P'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Div
    TAG = 'DIV'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Span
    TAG = 'SPAN'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Strong
    TAG = 'STRONG'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Label
    TAG = 'LABEL'
    include ContainerMethodsFromName
    include ElementModule
    
    dom_wrap_inspect :htmlFor

    def for
      raise "document is not defined - cannot search for labeled element" unless document_object
      if for_object=document_object.getElementById(element_object.htmlFor)
        base_element_klass.factory(for_object, extra)
      else
        raise "no element found that #{self.inspect} is for!"
      end
    end
  end
  module Ul
    TAG = 'UL'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Li
    TAG = 'LI'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Dl
    TAG = 'DL'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Dt
    TAG = 'DT'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Dd
    TAG = 'DD'
    include ContainerMethodsFromName
    include ElementModule
  end
  module H1
    TAG = 'H1'
    include ContainerMethodsFromName
    include ElementModule
  end
  module H2
    TAG = 'H2'
    include ContainerMethodsFromName
    include ElementModule
  end
  module H3
    TAG = 'H3'
    include ContainerMethodsFromName
    include ElementModule
  end
  module H4
    TAG = 'H4'
    include ContainerMethodsFromName
    include ElementModule
  end
  module H5
    TAG = 'H5'
    include ContainerMethodsFromName
    include ElementModule
  end
  module H6
    TAG = 'H6'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Map
    TAG = 'MAP'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Area
    TAG = 'AREA'
    include ContainerMethodsFromName
    include ElementModule
  end
  module Em
    TAG = 'EM'
    include ContainerMethodsFromName
    include ElementModule
  end
end
