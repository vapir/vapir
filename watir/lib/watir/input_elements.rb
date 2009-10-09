module Watir
  
  class IEInputElement < IEElement
    include InputElement
#    def locate
#      @o = @container.locate_input_element(@how, @what, self.class::INPUT_TYPES)
#    end
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      super(nil)
#    end
  end

  #
  # Input: Select
  #
  
  # This class is the way in which select boxes are manipulated.
  # Normally a user would not need to create this object as it is returned by the Watir::Container#select_list method
  class IESelectList < IEInputElement
    include SelectList
#    INPUT_TYPES = ["select-one", "select-multiple"]

    
    # Returns all the items in the select list as an array.
    # An empty array is returned if the select box has no contents.
    # Raises UnknownObjectException if the select box is not found
    def options
      options_list=[]
      element_object.options.each do |option_object|
        options_list << IEOption.new(:element_object, option_object, extra)
      end
      ElementCollection.new(options_list)
    end
    
    # Does the SelectList include the specified option (text)?
#    def include? text_or_regexp
#      getAllContents.grep(text_or_regexp).size > 0
#    end

    # Is the specified option (text) selected? Raises exception of option does not exist.
#    def selected? text_or_regexp
#      unless includes? text_or_regexp
#        raise UnknownObjectException, "Option #{text_or_regexp.inspect} not found."
#      end

#      getSelectedItems.grep(text_or_regexp).size > 0
#    end

#    def option(attribute, value)
#      assert_exists
#      IEOption.new(self, attribute, value)
#    end
  end
  
#  module IEOptionAccess
#    def text
#      @option.text
#    end
#    def value
#      @option.value
#    end
#    def selected
#      @option.selected
#    end
#  end
#  
#  class IEOptionWrapper
#    include IEOptionAccess
#    def initialize(option)
#      @option = option
#    end
#  end
  
  # An item in a select list
  class IEOption < IEElement
    include Option
#    include IEOptionAccess
    include Watir::Exception
#    def initialize(select_list, attribute, value)
#      @select_list = select_list
#      @how = attribute
#      @what = value
#      @option = nil
#      
#      unless [:text, :value, :label].include? attribute
#        raise MissingWayOfFindingObjectException,
#                    "Option does not support attribute #{@how}"
#      end
#      @select_list.o.each do |option| # items in the list
#        if value.matches(option.invoke(attribute.to_s))
#          @option = option
#          break
#        end
#      end
#      
#    end
#    def assert_exists
#      unless @option
#        raise UnknownObjectException,
#                    "Unable to locate an option using #{@how} and #{@what}"
#      end
#    end
#    private :assert_exists
    def select
      assert_exists
      element_object.selected=true
      #@select_list.select_item_in_select_list(@how, @what)
    end
  end
  
  # 
  # Input: Button
  #
  
  # Returned by the Watir::Container#button method
  class IEButton < IEInputElement
    include Button
    INPUT_TYPES = ["button", "submit", "image", "reset"]
  end

  #
  # Input: Text
  #
  
  # This class is the main class for Text Fields
  # Normally a user would not need to create this object as it is returned by the Watir::Container#text_field method
  class IETextField < IEInputElement
    include TextField
    INPUT_TYPES = ["text", "password", "textarea"]
    
#    def_wrap_guard :size
    
#    def maxlength
#      assert_exists
#      begin
#        ole_object.invoke('maxlength').to_i
#      rescue WIN32OLERuntimeError
#        0
#      end
#    end
        
    # Returns true or false if the text field is read only.
    #   Raises UnknownObjectException if the object can't be found.
#    def_wrap :readonly?, :readOnly
    
    def text_string_creator
      n = []
      n << "length:".ljust(TO_S_SIZE) + self.size.to_s
      n << "max length:".ljust(TO_S_SIZE) + self.maxlength.to_s
      n << "read only:".ljust(TO_S_SIZE) + self.readonly?.to_s
      n
    end
    private :text_string_creator
    
#    def to_s
#      assert_exists
#      r = string_creator
#      r += text_string_creator
#      r.join("\n")
#    end
    
    def assert_not_readonly
      if self.readonly?
        raise ObjectReadOnlyException, 
          "Textfield #{@how} and #{@what} is read only."
      end
    end
    
    # Returns true if the text field contents is matches the specified target,
    # which can be either a string or a regular expression.
    #   Raises UnknownObjectException if the object can't be found
    def verify_contains(target) # FIXME: verify_contains should have same name and semantics as IE#contains_text (prolly make this work for all elements)
      assert_exists
      if target.kind_of? String
        return true if self.value == target
      elsif target.kind_of? Regexp
        return true if self.value.match(target) != nil
      end
      return false
    end
    
    # Drag the entire contents of the text field to another text field
    #  19 Jan 2005 - It is added as prototype functionality, and may change
    #   * destination_how   - symbol, :id, :name how we identify the drop target
    #   * destination_what  - string or regular expression, the name, id, etc of the text field that will be the drop target
    def drag_contents_to(destination_how, destination_what)
      assert_exists
      destination = @container.text_field!(destination_how, destination_what)
      unless destination.exists?
        raise UnknownObjectException, "Unable to locate destination using #{destination_how } and #{destination_what } "
      end
      
      element_object.focus
      element_object.select
      value = self.value
      
      element_object.fireEvent("onSelect")
      element_object.fireEvent("ondragstart")
      element_object.fireEvent("ondrag")
      destination.fireEvent("onDragEnter")
      destination.fireEvent("onDragOver")
      destination.fireEvent("ondrop")
      
      element_object.fireEvent("ondragend")
      destination.value = destination.value + value.to_s
      self.value = ""
    end
    
    
    # Sets the value of the text field directly. 
    # It causes no events to be fired or exceptions to be raised, 
    # so generally shouldn't be used.
    # It is preffered to use the set method.
    def value=(v)
      assert_exists
      element_object.value = v.to_s
    end
    
    def requires_typing
    	@type_keys = true
    	self
    end
    def abhors_typing
    	@type_keys = false
    	self
    end
  end
  
  # this class can be used to access hidden field objects
  # Normally a user would not need to create this object as it is returned by the Watir::Container#hidden method
  class IEHidden < IETextField
    include Hidden
    INPUT_TYPES = ["hidden"]
    
    # set is overriden in this class, as there is no way to set focus to a hidden field
    def set(n)
      self.value = n
    end
    
    # override the append method, so that focus isnt set to the hidden object
    def append(n)
      self.value = self.value.to_s + n.to_s
    end
    
    # override the clear method, so that focus isnt set to the hidden object
    def clear
      self.value = ""
    end
    
    # this method will do nothing, as you cant set focus to a hidden field
    def focus
    end
    
    # Hidden element is never visible - returns false.
    def visible?
      assert_exists
      false
    end
    
  end
  
  # For fields that accept file uploads
  # Windows dialog is opened and handled in this case by autoit 
  # launching into a new process. 
  class IEFileField < IEInputElement
    include FileField
    INPUT_TYPES = ["file"]
    POPUP_TITLES = ['Choose file', 'Choose File to Upload']
    
    # set the file location in the Choose file dialog in a new process
    # will raise a Watir Exception if AutoIt is not correctly installed
    def set(path_to_file)
      assert_exists
      require 'watir/windowhelper'
      WindowHelper.check_autoit_installed
      begin
        Thread.new do
          sleep 1 # it takes some time for popup to appear

          system %{ruby -e '
              require "win32ole"

              @autoit = WIN32OLE.new("AutoItX3.Control")
              time    = Time.now

              while (Time.now - time) < 15 # the loop will wait up to 15 seconds for popup to appear
                #{POPUP_TITLES.inspect}.each do |popup_title|
                  next unless @autoit.WinWait(popup_title, "", 1) == 1

                  @autoit.ControlSetText(popup_title, "", "Edit1", #{path_to_file.inspect})
                  @autoit.ControlSend(popup_title, "", "Button2", "{ENTER}")
                  exit
                end # each
              end # while
          '}
        end.join(1)
      rescue
        raise Watir::Exception::WatirException, "Problem accessing Choose file dialog"
      end
      click
    end
  end
  
  # This class is the class for radio buttons and check boxes.
  # It contains methods common to both.
  # Normally a user would not need to create this object as it is returned by the Watir::Container#checkbox or Watir::Container#radio methods
  #
  # most of the methods available to this element are inherited from the Element class
  #
  module IERadioCheckCommon
#    def locate
#      @o = @container.locate_input_element(@how, @what, self.class::INPUT_TYPES, @value)
#    end
#    def initialize(container, how, what, value=nil)
#      super container, how, what
#      @value = value
#    end
    
    def inspect
      '#<%s:0x%x located=%s how=%s what=%s value=%s>' % [self.class, hash*2, !!ole_object, @how.inspect, @what.inspect, @value.inspect]
    end
    
    # This method determines if a radio button or check box is set.
    # Returns true is set/checked or false if not set/checked.
    # Raises UnknownObjectException if its unable to locate an object.
    def set? # could be just "checked?"
      assert_exists
      return element_object.checked
    end
    alias checked? set?
    
    # This method is the common code for setting or clearing checkboxes and radio.
    def set_clear_item(set)
      element_object.checked = set
      element_object.fireEvent("onClick")
      @container.wait
    end
    private :set_clear_item
    
  end
  
  #--
  #  this class makes the docs better
  #++
  # This class is the watir representation of a radio button.
  class IERadio < IEElement
    include IERadioCheckCommon
    include Radio
    INPUT_TYPES = ["radio"]
    # This method clears a radio button. One of them will almost always be set.
    # Returns true if set or false if not set.
    #   Raises UnknownObjectException if its unable to locate an object
    #         ObjectDisabledException IF THE OBJECT IS DISABLED
    def clear
      assert_enabled
      highlight(:set)
      set_clear_item(false)
      highlight(:clear)
    end
    
    # This method sets the radio list item.
    #   Raises UnknownObjectException  if it's unable to locate an object
    #         ObjectDisabledException  if the object is disabled
    def set
      assert_enabled
      highlight(:set)
      element_object.scrollIntoView
      set_clear_item(true)
      highlight(:clear)
    end
    
  end
  
  # This class is the watir representation of a check box.
  class IECheckBox < IEElement
    include IERadioCheckCommon
    include CheckBox
    INPUT_TYPES = ["checkbox"]
    # With no arguments supplied, sets the check box.
    # If the optional value is supplied, the checkbox is set, when its true and 
    # cleared when its false
    #   Raises UnknownObjectException if it's unable to locate an object
    #         ObjectDisabledException if the object is disabled
    def set(value=true)
      assert_enabled
      highlight :set
      unless element_object.checked == value
        set_clear_item value
      end
      highlight :clear
    end
    
    # Clears a check box.
    #   Raises UnknownObjectException if its unable to locate an object
    #         ObjectDisabledException if the object is disabled
    def clear
      set false
    end
        
  end
  
end