module Watir
  
  # This class is the means of accessing an image on a page.
  # Normally a user would not need to create this object as it is returned by the Watir::Container#image method
  #
  # many of the methods available to this object are inherited from the Element class
  #
  class IEImage < IEElement
    include Image
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      super nil
#    end
    
#    def locate
#      if @how == :xpath
#        @o = @container.element_by_xpath(@what)
#      else
#        @o = @container.locate_tagged_element('IMG', @how, @what)
#      end
#    end
    
    # this method returns the file created date of the image
    def file_created_date
      assert_exists
      return @element_object.invoke("fileCreatedDate")
    end
    
    # this method returns the filesize of the image
    def file_size
      assert_exists
      return @element_object.invoke("fileSize").to_s
    end
    
    # returns the width in pixels of the image, as a string
    def width
      assert_exists
      return @element_object.invoke("width").to_s
    end
    
    # returns the height in pixels of the image, as a string
    def height
      assert_exists
      return @element_object.invoke("height").to_s
    end
    
    # This method attempts to find out if the image was actually loaded by the web browser.
    # If the image was not loaded, the browser is unable to determine some of the properties.
    # We look for these missing properties to see if the image is really there or not.
    # If the Disk cache is full (tools menu -> Internet options -> Temporary Internet Files), it may produce incorrect responses.
    def loaded?
      locate
      raise UnknownObjectException, "Unable to locate image using #{@how} and #{@what}" if @element_object == nil
      return false if @element_object.fileCreatedDate == "" and @element_object.fileSize.to_i == -1
      return true
    end
    
    # this method highlights the image (in fact it adds or removes a border around the image)
    #  * set_or_clear   - symbol - :set to set the border, :clear to remove it
    def highlight(set_or_clear)
      if set_or_clear == :set
        begin
          @original_border = element_object.border
          element_object.border = 1
        rescue
          @original_border = nil
        end
      else
        begin
          element_object.border = @original_border
          @original_border = nil
        rescue
          # we could be here for a number of reasons...
        ensure
          @original_border = nil
        end
      end
    end
    private :highlight
    
    # This method saves the image to the file path that is given.  The
    # path must be in windows format (c:\\dirname\\somename.gif).  This method
    # will not overwrite a previously existing image.  If an image already
    # exists at the given path then a dialog will be displayed prompting
    # for overwrite.
    # Raises a WatirException if AutoIt is not correctly installed
    # path - directory path and file name of where image should be saved
    def save(path)
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
      Thread.new do
        system("ruby -e \"require 'win32ole'; @autoit=WIN32OLE.new('AutoItX3.Control'); waitresult=@autoit.WinWait 'Save Picture', '', 15; if waitresult == 1\" -e \"@autoit.ControlSetText 'Save Picture', '', '1148', '#{path}'; @autoit.ControlSend 'Save Picture', '', '1', '{ENTER}';\" -e \"end\"")
      end
    end
    private :fill_save_image_dialog
  end
  
end