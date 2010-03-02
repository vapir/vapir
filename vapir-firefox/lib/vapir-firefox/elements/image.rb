module Vapir
  #
  # Description:
  #   Class for Image element.
  #
  class Firefox::Image < Firefox::Element
    include Vapir::Image

    # this method returns the file created date of the image
    #def file_created_date
    #    assert_exists
    #    return @o.invoke("fileCreatedDate")
    #end
    # alias fileCreatedDate file_created_date

    # this method returns the filesize of the image
    #def file_size
    #    assert_exists
    #    return @o.invoke("fileSize")
    #end
    # alias fileSize file_size

    # This method attempts to find out if the image was actually loaded by the web browser.
    # If the image was not loaded, the browser is unable to determine some of the properties.
    # We look for these missing properties to see if the image is really there or not.
    # If the Disk cache is full ( tools menu -> Internet options -> Temporary Internet Files) , it may produce incorrect responses.
    #def has_loaded
    #    locate
    #    raise UnknownObjectException, "Unable to locate image using #{@how} and #{@what}" if @o == nil
    #    return false if @o.fileCreatedDate == "" and  @o.fileSize.to_i == -1
    #    return true
    #end
    # alias hasLoaded? loaded?
  end # Image
end # Vapir
