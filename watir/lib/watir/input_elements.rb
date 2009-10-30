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
      assert_exists do
        if target.kind_of? String
          return true if self.value == target
        elsif target.kind_of? Regexp
          return true if self.value.match(target) != nil
        end
        return false
      end
    end
    
    # Drag the entire contents of the text field to another text field
    #  19 Jan 2005 - It is added as prototype functionality, and may change
    #   * destination_how   - symbol, :id, :name how we identify the drop target
    #   * destination_what  - string or regular expression, the name, id, etc of the text field that will be the drop target
    def drag_contents_to(destination_how, destination_what)
      assert_exists do
        destination = @container.text_field!(destination_how, destination_what)
        
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
  # Windows dialog is opened and handled by WinWindow (see scripts/select_file.rb), launched in a new process.  
  class IEFileField < IEInputElement
    include FileField
    
    # set the file location in the Choose file dialog 
    def set(file_path)
      assert_exists do
      
        require 'win32/process'
        require 'watir/win_window'
        rubyw_exe= File.join(Config::CONFIG['bindir'], 'rubyw')
        error_file_name=File.expand_path(File.join(File.dirname(__FILE__), 'scripts', 'select_file_error_status.marshal_dump'))
        select_file_script=File.expand_path(File.join(File.dirname(__FILE__), 'scripts', 'select_file.rb'))
        command_line=rubyw_exe+[select_file_script, browser.hwnd.to_s, file_path, error_file_name].map{|arg| " \"#{arg.gsub("/", "\\")}\""}.join('')
         # TODO/FIX: the above method of escaping seems to have issues with trailing slashes. 
        select_file_process=::Process.create('command_line' => command_line)
        
        click
        
        if ::Waiter.try_for(2, :exception => nil) { File.exists?(error_file_name) } # wait around a moment for the script to finish writing - #click returns before that script exits 
          marshaled_error=File.read(error_file_name)
          error=Marshal.load(marshaled_error)
          error[:backtrace]+= caller(0)
          File.delete(error_file_name)
          raise error[:class], error[:message], error[:backtrace]
        end
        return file_path
        # TODO/FIX: figure out what events ought to be fired here - onchange, maybe others
      end
    end
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