module Watir
  
  class IEInputElement < IEElement
    include InputElement
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
      ole_to_element_collection(IEOption, element_object.options, :select_list => self)
    end
    
#    def option(attribute, value)
#      assert_exists
#      IEOption.new(self, attribute, value)
#    end
  end
  
  # An item in a select list
  class IEOption < IEElement
    include Option
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
#    def_wrap_guard :size
    
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
    #def value=(v)
    #  assert_exists
    #  element_object.value = v.to_s
    #end
    
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
    #def set(n)
    #  self.value = n
    #end
    #
    ## override the append method, so that focus isnt set to the hidden object
    #def append(n)
    #  self.value = self.value.to_s + n.to_s
    #end
    #
    ## override the clear method, so that focus isnt set to the hidden object
    #def clear
    #  self.value = ""
    #end
    #
    ## this method will do nothing, as you cant set focus to a hidden field
    #def focus
    #end
    #
    ## Hidden element is never visible - returns false.
    #def visible?
    #  assert_exists
    #  false
    #end
    
  end
  
  # For fields that accept file uploads
  # Windows dialog is opened and handled in this case by autoit 
  # launching into a new process. 
  class IEFileField < IEInputElement
    include FileField
    # titles of file upload window titles in supported browsers 
    UploadWindowTitles= { :IE8 => "Choose File to Upload", 
                          :IE7 => 'Choose file', 
                        }
    # list of arguments to give to WinWindow#child_control_with_preceding_label to find the filename field
    # on dialogs of supported browsers (just the one right now because it's the same in ie7 and ie8)
    UploadWindowFilenameFields = [["File &name:", {:control_class_name => 'ComboBoxEx32'}]]
    
    def set(setPath)
      assert_exists
      click_no_wait
      require 'lib/win_window'
      require 'lib/waiter'
      container_window=WinWindow.new(browser.hwnd)

      upload_dialog=::Waiter.try_for(16, :exception => Watir::Exception::NoMatchingWindowFoundException.new('No window found to upload a file')) do
        if (popup=container_window.enabled_popup) && UploadWindowTitles.values.include?(popup.text)
          popup
        end
      end
        
      filename_fields=UploadWindowFilenameFields.map do |control_args|
        upload_dialog.child_control_with_preceding_label(*control_args)
      end
      (filename_field=filename_fields.compact.first) || (raise Watir::Exception::NoMatchingWindowFoundException, "Could not find a filename field in the File Upload dialog")
      filename_field.send_set_text! setPath
      upload_dialog.click_child_button_try_for!('Open', 4, :exception => WinWindow::Error.new("Failed to click the Open button on the File Upload dialog. It exists, but we couldn't click it."))
    end
    # set the file location in the Choose file dialog in a new process
    # will raise a Watir Exception if AutoIt is not correctly installed
#    def set(path_to_file)
#      assert_exists
#      require 'watir/windowhelper'
#      WindowHelper.check_autoit_installed
#      begin
#        Thread.new do
#          sleep 1 # it takes some time for popup to appear
#
#          system %{ruby -e '
#              require "win32ole"
#
#              @autoit = WIN32OLE.new("AutoItX3.Control")
#              time    = Time.now
#
#              while (Time.now - time) < 15 # the loop will wait up to 15 seconds for popup to appear
#                #{POPUP_TITLES.inspect}.each do |popup_title|
#                  next unless @autoit.WinWait(popup_title, "", 1) == 1
#
#                  @autoit.ControlSetText(popup_title, "", "Edit1", #{path_to_file.inspect})
#                  @autoit.ControlSend(popup_title, "", "Button2", "{ENTER}")
#                  exit
#                end # each
#              end # while
#          '}
#        end.join(1)
#      rescue
#        raise Watir::Exception::WatirException, "Problem accessing Choose file dialog"
#      end
#      click
#    end
  end
  
  #--
  #  this class makes the docs better
  #++
  # This class is the watir representation of a radio button.
  class IERadio < IEInputElement
    include Radio
  end
  
  # This class is the watir representation of a check box.
  class IECheckBox < IEInputElement
    include CheckBox
  end
  
end