module Vapir  
  
  # This class is the means of accessing a link on a page
  # Normally a user would not need to create this object as it is returned by the Vapir::Container#link method
  # many of the methods available to this object are inherited from the Element class
  #
  class IE::Link < IE::Element
    include Vapir::Link
    
    # if an image is used as part of the link, this will return true
    def link_has_image
      images.length > 0
    end
    
    def src
      raise NotImplementedError, "Link#src is gone. use Link#images to get a collection of images from which you may get the #src attribute"
    end
  end
  
end