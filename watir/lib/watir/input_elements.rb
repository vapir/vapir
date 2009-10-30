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
    
    # Returns all the items in the select list as an array.
    # An empty array is returned if the select box has no contents.
    # Raises UnknownObjectException if the select box is not found
    def options
      assert_exists
      ole_to_element_collection(IEOption, element_object.options, :select_list => self)
    end
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
    #
    # TODO: move to common 
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
  end
  
  # For fields that accept file uploads
  # Windows dialog is opened and handled in this case by autoit 
  # launching into a new process. 
  class IEFileField < IEInputElement
    include FileField
    
    # set the file location in the Choose file dialog 
    def set(file_path)
      assert_exists
      
      require 'win32/process'
      require 'timeout'
      rubyw_exe= File.join(Config::CONFIG['bindir'], 'rubyw').gsub("/", "\\")
      select_file_script=File.expand_path(File.join(File.dirname(__FILE__), 'scripts', 'select_file.rb')).gsub("/", "\\")
      select_file_process=::Process.create('command_line' => rubyw_exe+[select_file_script, browser.hwnd, file_path].map{|arg| " \"#{arg}\""}.join(''))
      
      begin
        Timeout::timeout(32) do
          click
        end
      rescue Timeout::Error
        raise "Something went wrong setting the file field"
      end
      
      # below doesn't work; waitpid2 blocks (even if in its own thread) so can't go before click; and after click, it's already dead. 
      # TODO/FIX: figure out a way for select_file_process to indicate a success/failure to us here 
      #process_result=::Process.waitpid2(process.process_id)
      #if process_result.last != 0
      #  
      #end
    end
=begin
      require 'lib/win_window'
      require 'lib/waiter'
      container_window=WinWindow.new(browser.hwnd)

      popup=nil
      upload_dialog=::Waiter.try_for(16, :exception => nil) do
        if (popup=container_window.enabled_popup) && UploadWindowTitles.values.include?(popup.text)
          popup
        end
      end
      unless upload_dialog
        raise Watir::Exception::NoMatchingWindowFoundException.new('No window found to upload a file - '+(popup ? "enabled popup exists but has unrecognized text #{popup.text}" : 'no popup is on the browser'))
      end
      filename_fields=UploadWindowFilenameFields.map do |control_args|
        upload_dialog.child_control_with_preceding_label(*control_args)
      end
      unless (filename_field=filename_fields.compact.first)
        raise Watir::Exception::NoMatchingWindowFoundException, "Could not find a filename field in the File Upload dialog"
      end
      filename_field.send_set_text! file_path
      upload_dialog.click_child_button_try_for!('Open', 4, :exception => WinWindow::Error.new("Failed to click the Open button on the File Upload dialog. It exists, but we couldn't click it."))
    end
=end
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