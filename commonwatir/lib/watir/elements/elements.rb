require 'watir/elements/element'
require 'watir/common_container'

module Watir
  module Frame
    extend ElementHelper
    
    add_specifier :tagName => 'frame'
    add_specifier :tagName => 'iframe'
    
    container_single_method :frame
    container_collection_method :frames
    default_how :name
    
    dom_attr :name
    dom_attr :src
    inspect_these :name, :src
  end
  module InputElement
    extend ElementHelper
    
    add_specifier :tagName => 'input'
    add_specifier :tagName => 'textarea'
    add_specifier :tagName => 'button'
    add_specifier :tagName => 'select'
    
    container_single_method :input, :input_element
    container_collection_method :inputs, :input_elements
    
    dom_attr :name, :value, :type
    dom_attr :disabled => [:disabled, :disabled?]
    dom_attr :readOnly => [:readonly, :readonly?]
    dom_attr :defaultValue => :default_value
    dom_function :focus
    dom_setter :value
    inspect_these :name, :value, :type

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
    extend ElementHelper
    
    add_specifier :tagName => 'textarea'
    add_specifier :tagName => 'input', :types => ['text', 'password', 'hidden']
    
    container_single_method :text_field
    container_collection_method :text_fields
    
    dom_attr :size, :maxLength => :maxlength
    alias_deprecated :getContents, :value
    
    # Clears the contents of the text field.
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
#        fire_event('onBlur', :just_fire => true)
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
#            sleep typingspeed
            element_object.value = new_value_chars[0..i].join('')
            fire_event :onKeyDown, :just_fire => true
            fire_event :onKeyPress, :just_fire => true
            fire_event :onKeyUp, :just_fire => true
          end
#          fire_event('onBlur', :just_fire => true)
          fire_event("onChange", :just_fire => true)
        else
          element_object.value = element_object.value + value
        end
        wait
      end
    end
    # Sets the contents of the text field to the given value
    #   Raises UnknownObjectException if the object cant be found
    #   Raises ObjectDisabledException if the object is disabled
    #   Raises ObjectReadOnlyException if the object is read only
    def set(value)
      with_highlight do
        clear
        append(value)
      end
    end
  end
  module Hidden
    extend ElementHelper
    add_specifier :tagName => 'input', :type => 'hidden'
    container_single_method :hidden
    container_collection_method :hiddens
    default_how :name

    
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
    extend ElementHelper
    add_specifier :tagName => 'input', :types => ['button', 'submit', 'image', 'reset']
    add_specifier :tagName => 'button'
    container_single_method :button
    container_collection_method :buttons
    default_how :value

    dom_attr :src, :height, :width # these are used on <input type=image>
  end
  module FileField
    extend ElementHelper
    add_specifier :tagName => 'input', :type => 'file'
    container_single_method :file_field
    container_collection_method :file_fields
    default_how :name
  end
  module Option
    extend ElementHelper
    add_specifier :tagName => 'option'
    container_single_method :option
    container_collection_method :options
    
    inspect_these :text, :value, :selected
    dom_attr :text, :value, :selected
    
    # sets this Option's selected state to the given (true or false). 
    # if this Option is aware of its select list (this will generally be the case if you
    # got this Option from a SelectList container), will fire the onchange event on the 
    # select list if our state changes. 
    def selected=(state)
      assert_exists
      state_was=element_object.selected
      element_object.selected=state
      if @extra[:select_list] && state_was != state
        @extra[:select_list].fire_event(:onchange)
      end
      wait
    end
    #dom_setter :selected

    # selects this option, firing the onchange event on the containing select list if we 
    # are aware of it (see #selected=) 
    def select
      self.selected=true
    end
  end
  module SelectList
    extend ElementHelper
    add_specifier :tagName => 'select'
    container_single_method :select_list
    container_collection_method :select_lists

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
      assert_enabled
      any_matched=false
      with_highlight(method_options[:highlight]) do
        i=0
        # TODO: FIX this when relocating on element collections works. sometimes the OLE object for a select list goes 
        # away when a new option is selected (seems to be related to javascript events?) and it has to be relocated. 
        # relocating by :element_object (which is how #options get specified) doesn't work, it errors, so as a temporary 
        # workaround, just reload the options every iteration. 
        while i < options.length
          i+=1
          option=options[i]
#        self.options.each do |option|
          if yield option
            any_matched=true
            option.selected=true # note that this fires the onchange event on this SelectList 
          end
        end
        if !any_matched
          raise Watir::Exception::NoValueFoundException, "Could not find any options matching those specified on #{self.inspect}"
        end
      end
    end
  end
  
  module RadioCheckBoxCommon
    extend ElementClassAndModuleMethods
    dom_attr :checked => [:checked, :checked?, :set?]
    alias_deprecated :isSet?, :checked
    alias_deprecated :getState, :checked

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
          if browser_class.name != 'Watir::Firefox'  # compare by name to not trigger autoload or raise NameError if not loaded 
            # in firefox, firing the onclick event changes the state. in IE, it doesn't, so do that first 
            element_object.checked=state
          end
          fire_event :onclick, :just_fire => true
          fire_event :onchange, :just_fire => true
        end
        wait
      end
    end
  end
  
  module Radio
    extend ElementHelper
    add_specifier :tagName => 'input', :type => 'radio'
    container_single_method :radio
    container_collection_method :radios
    ContainerMethodExtraArgs=[:value]

    include RadioCheckBoxCommon
    inspect_these :checked
  end
  module CheckBox
    extend ElementHelper
    add_specifier :tagName => 'input', :type => 'checkbox'
    container_single_method :checkbox, :check_box
    container_collection_method :checkboxes, :check_boxes
    ContainerMethodExtraArgs=[:value]


    include RadioCheckBoxCommon
    inspect_these :checked
  end
  module Form
    extend ElementHelper
    add_specifier :tagName => 'form'
    container_single_method :form
    container_collection_method :forms
    default_how :name

    dom_attr :name, :action
    inspect_these :name, :action
  end
  module Image
    extend ElementHelper
    add_specifier :tagName => 'IMG'
    container_single_method :image
    container_collection_method :images
    default_how :name

    
    dom_attr :src, :name, :width, :height, :alt, :border
    inspect_these :src, :name, :width, :height, :alt
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
    # I was going to define #cell_count(index=nil) here as an alternative to #column_count
    # but it seems confusing; to me #cell_count on a Table would count up all the cells in
    # all rows, so going to avoid confusion and not do it. 
    
    # Returns an array of the text of each cell in the row at the given index.
    def row_texts_at(row_index)
      rows[row_index].cells.map do |cell|
        cell.text
      end
    end
    alias_deprecated :row_values, :row_texts_at
    
    # Returns an array containing the text of the cell in the specified index in each row. 
    def column_texts_at(column_index)
      rows.map do |row|
        row.cells[column_index].text
      end
    end
    alias_deprecated :column_values, :column_texts_at
  end
  module Table
    extend ElementHelper
    # Table assumes the inheriting class defines a #rows method which returns 
    # an ElementCollection
    add_specifier :tagName => 'TABLE'
    container_single_method :table
    container_collection_method :tables

    include HasRowsAndColumns
    
  end
  module TBody
    extend ElementHelper
    add_specifier :tagName => 'TBODY'
    container_single_method :tbody
    container_collection_method :tbodies

    include HasRowsAndColumns
  end
  module TableRow
    extend ElementHelper
    # TableRow assumes that the inheriting class defines a #cells method which
    # returns an ElementCollection
    add_specifier :tagName => 'tr'
    container_single_method :table_row
    container_collection_method :table_rows
    
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
    
    # returns the cell of the current row at the given column index (starting from 1), taking
    # into account conSpans of other cells. 
    #
    # returns nil if index is greater than the number of columns of this row. 
    def cell_at_colum(index)
      cells.detect do |cell|
        index=index-(cell.colSpan || 1)
        index <= 0
      end
    end
  end
  module TableCell
    extend ElementHelper
    add_specifier :tagName => 'td'
    add_specifier :tagName => 'th'
    container_single_method :table_cell
    container_collection_method :table_cells

    dom_attr :colSpan => [:colSpan, :colspan], :rowSpan => [:rowSpan, :rowspan]
  end
  module Link
    extend ElementHelper
    add_specifier :tagName => 'A'
    container_single_method :a, :link
    container_collection_method :as, :links

    dom_attr :href, :name
    inspect_these :href, :name
  end
  module Pre
    extend ElementHelper
    add_specifier :tagName => 'PRE'
    container_single_method :pre
    container_collection_method :pres
  end
  module P
    extend ElementHelper
    add_specifier :tagName => 'P'
    container_single_method :p
    container_collection_method :ps
  end
  module Div
    extend ElementHelper
    add_specifier :tagName => 'DIV'
    container_single_method :div
    container_collection_method :divs
  end
  module Span
    extend ElementHelper
    add_specifier :tagName => 'SPAN'
    container_single_method :span
    container_collection_method :spans
  end
  module Strong
    extend ElementHelper
    add_specifier :tagName => 'STRONG'
    container_single_method :strong
    container_collection_method :strongs
  end
  module Label
    extend ElementHelper
    add_specifier :tagName => 'LABEL'
    container_single_method :label
    container_collection_method :labels
    
    dom_attr :htmlFor => [:html_for, :for]
    inspect_these :for

    def for_element
      raise "document is not defined - cannot search for labeled element" unless document_object
      if for_object=document_object.getElementById(element_object.htmlFor)
        base_element_class.factory(for_object, extra_for_contained, :label, self)
      else
        raise UnknownObjectException, "no element found that #{self.inspect} is for!"
      end
    end
  end
  module Ul
    extend ElementHelper
    add_specifier :tagName => 'UL'
    container_single_method :ul
    container_collection_method :uls
  end
  module Li
    extend ElementHelper
    add_specifier :tagName => 'LI'
    container_single_method :li
    container_collection_method :lis
  end
  module Dl
    extend ElementHelper
    add_specifier :tagName => 'DL'
    container_single_method :dl
    container_collection_method :dls
  end
  module Dt
    extend ElementHelper
    add_specifier :tagName => 'DT'
    container_single_method :dt
    container_collection_method :dts
  end
  module Dd
    extend ElementHelper
    add_specifier :tagName => 'DD'
    container_single_method :dd
    container_collection_method :dds
  end
  module H1
    extend ElementHelper
    add_specifier :tagName => 'H1'
    container_single_method :h1
    container_collection_method :h1s
  end
  module H2
    extend ElementHelper
    add_specifier :tagName => 'H2'
    container_single_method :h2
    container_collection_method :h2s
  end
  module H3
    extend ElementHelper
    add_specifier :tagName => 'H3'
    container_single_method :h3
    container_collection_method :h3s
  end
  module H4
    extend ElementHelper
    add_specifier :tagName => 'H4'
    container_single_method :h4
    container_collection_method :h4s
  end
  module H5
    extend ElementHelper
    add_specifier :tagName => 'H5'
    container_single_method :h5
    container_collection_method :h5s
  end
  module H6
    extend ElementHelper
    add_specifier :tagName => 'H6'
    container_single_method :h6
    container_collection_method :h6s
  end
  module Map
    extend ElementHelper
    add_specifier :tagName => 'MAP'
    container_single_method :map
    container_collection_method :maps
  end
  module Area
    extend ElementHelper
    add_specifier :tagName => 'AREA'
    container_single_method :area
    container_collection_method :areas
  end
  module Em
    extend ElementHelper
    add_specifier :tagName => 'EM'
    container_single_method :em
    container_collection_method :ems
  end
end
