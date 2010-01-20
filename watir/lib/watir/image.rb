module Watir
  
  # This class is the means of accessing an image on a page.
  # Normally a user would not need to create this object as it is returned by the Watir::Container#image method
  #
  # many of the methods available to this object are inherited from the Element class
  #
  class IEImage < IEElement
    include Image
    
    dom_attr :fileSize => :file_size
    dom_attr :fileCreatedDate => :file_created_date
    
    # This method attempts to find out if the image was actually loaded by the web browser.
    # If the image was not loaded, the browser is unable to determine some of the properties.
    # We look for these missing properties to see if the image is really there or not.
    # If the Disk cache is full (tools menu -> Internet options -> Temporary Internet Files), it may produce incorrect responses.
    def loaded?
      assert_exists do
        !(element_object.fileCreatedDate == "" and element_object.fileSize.to_i == -1)
      end
    end
    alias_deprecated :hasLoaded?, :loaded?
    
    # This method saves the image to the file path that is given.  The
    # path must be in windows format (c:\\dirname\\somename.gif).  This method
    # will not overwrite a previously existing image.  If an image already
    # exists at the given path then a dialog will be displayed prompting
    # for overwrite.
    # Raises a WatirException if AutoIt is not correctly installed
    # path - directory path and file name of where image should be saved
    def save(path)
    # TODO: FIX
      require 'watir/windowhelper'
      WindowHelper.check_autoit_installed
      @container.goto(src)
      begin
        thrd = fill_save_image_dialog(path)
        @container.document.execCommand("SaveAs")
        thrd.join(5)
      ensure
        @container.back
      end
    end
    
    def fill_save_image_dialog(path)
      raise NotImplementedError
      #todo: FIX
      Thread.new do
        system("ruby -e \"require 'win32ole'; @autoit=WIN32OLE.new('AutoItX3.Control'); waitresult=@autoit.WinWait 'Save Picture', '', 15; if waitresult == 1\" -e \"@autoit.ControlSetText 'Save Picture', '', '1148', '#{path}'; @autoit.ControlSend 'Save Picture', '', '1', '{ENTER}';\" -e \"end\"")
      end
    end
    private :fill_save_image_dialog
  end
  
end