module Watir  
  
  # This class is the means of accessing a link on a page
  # Normally a user would not need to create this object as it is returned by the Watir::Container#link method
  # many of the methods available to this object are inherited from the Element class
  #
  class IELink < IEElement
    include Link
    
    # if an image is used as part of the link, this will return true
    def link_has_image
      assert_exists
      return true if element_object.getElementsByTagName("IMG").length > 0
      return false
    end
    
    # this method returns the src of an image, if an image is used as part of the link
    def src # BUG?
      assert_exists
      if element_object.getElementsByTagName("IMG").length > 0
        return element_object.getElementsByTagName("IMG")[0.to_s].src
      else
        return ""
      end
    end
  end
  
end