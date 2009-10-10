require 'watir/elements/element'
require 'watir/common_container'

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
                  {:tagName => 'input', :types => ['text', 'password', 'hidden']},
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
      assert_enabled
      assert_not_readonly
      with_highlight do
        element_object.focus
        fire_event('onFocus', :just_fire => true)
        element_object.select
        fire_event("onSelect", :just_fire => true)
        element_object.value = ''
        fire_event :onKeyDown, :just_fire => true
        fire_event :onKeyPress, :just_fire => true
        fire_event :onKeyUp, :just_fire => true
        fire_event('onBlur', :just_fire => true)
        fire_event("onChange", :just_fire => true)
      end
    end
    # Appends the specified string value to the contents of the text box.
    #   Raises UnknownObjectException if the object cant be found
    #   Raises ObjectDisabledException if the object is disabled
    #   Raises ObjectReadOnlyException if the object is read only
    def append(value)
      assert_enabled
      assert_not_readonly
      
      with_highlight do
        existing_value_chars=element_object.value.split(//)
        new_value_chars=existing_value_chars+value.split(//)
        #value_chars=value.split(//) # split on blank regexp (rather than iterating over each byte) for multibyte chars
        if self.type.downcase=='text' && maxlength && maxlength >= 0 && new_value_chars.length > maxlength
          new_value_chars=new_value_chars[0...maxlength]
        end
        element_object.scrollIntoView
        type_keys=respond_to?(:type_keys) ? self.type_keys : true # TODO: FIX
        typingspeed=respond_to?(:typingspeed) ? self.typingspeed : 0 # TODO: FIX
        if type_keys
          element_object.focus
          fire_event('onFocus', :just_fire => true)
          element_object.select
          fire_event("onSelect", :just_fire => true)
          ((existing_value_chars.length)...new_value_chars.length).each do |i|
            #sleep typingspeed
            element_object.value = new_value_chars[0..i].join('')
            fire_event :onKeyDown, :just_fire => true
            fire_event :onKeyPress, :just_fire => true
            fire_event :onKeyUp, :just_fire => true
          end
          fire_event('onBlur', :just_fire => true)
          fire_event("onChange", :just_fire => true)
        else
          element_object.value = element_object.value + value
        end
        wait
      end
    end
    # Sets the contents of the text box to the specified text value
    #   Raises UnknownObjectException if the object cant be found
    #   Raises ObjectDisabledException if the object is disabled
    #   Raises ObjectReadOnlyException if the object is read only
    def set(value)
      #element_object.value=''
      clear
      append(value)
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
        changed=false
        options.each do |option|
          if option.selected
            option.selected=false
            changed=true
          end
        end
        if changed
          fire_event :onchange, :just_fire => true
          wait
        end
      end
    end
    alias :clearSelection :clear
    
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

    # Does the SelectList have an option whose text matches the given text or regexp? 
    def option_texts_include?(text_or_regexp)
      option_texts.grep(text_or_regexp).size > 0
    end
    alias include? option_texts_include?
    alias includes? option_texts_include?

    # Is the specified option (text) selected? Raises exception of option does not exist.
    def selected_option_texts_include?(text_or_regexp)
      unless includes? text_or_regexp
        raise Watir::Exception::UnknownObjectException, "Option #{text_or_regexp.inspect} not found."
      end
      selected_option_texts.grep(text_or_regexp).size > 0
    end
    alias selected? selected_option_texts_include?
    
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
      any_matched=false
      with_highlight(method_options[:highlight]) do
        self.options.each do |option|
          if yield option
            any_matched=true
            if !option.selected
              option.selected=true
              any_changed=true
            end
          end
        end
        if any_changed
          fire_event(:onchange, method_options.merge(:highlight => false))
        end
        if !any_matched
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
          fire_event :onclick, :just_fire => true
        end
        if checked!=state # firing the click event doesn't change the checked state in IE. check and change if needed. 
          element_object.checked=state
        end
        fire_event :onchange, :just_fire => true
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
    
    # returns all of the cells of this table. to get the cells including nested tables, 
    # use #table_cells, which is defined on all containers (including Table) 
    def cells
      ElementCollection.new(rows.inject([]) do |cells_arr, row|
        cells_arr+row.cells.to_a
      end)
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
        base_element_class.factory(for_object, extra)
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
