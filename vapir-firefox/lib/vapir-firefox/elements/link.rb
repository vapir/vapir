require 'vapir-firefox/element'
require 'vapir-common/elements/elements'

module Vapir
  #
  # Description:
  #   Class for Link element.
  #
  class Firefox::Link < Firefox::Element
    include Vapir::Link

    #TODO: if an image is used as part of the link, this will return true
    #def link_has_image
    #    assert_exists
    #    return true  if @o.getElementsByTagName("IMG").length > 0
    #    return false
    #end

    #TODO: this method returns the src of an image, if an image is used as part of the link
    #def src # BUG?
    #    assert_exists
    #    if @o.getElementsByTagName("IMG").length > 0
    #        return  @o.getElementsByTagName("IMG")[0.to_s].src
    #    else
    #        return ""
    #    end
    #end

  end # Link
end # Vapir
