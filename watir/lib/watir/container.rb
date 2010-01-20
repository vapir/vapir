module Watir
  # This module contains the factory methods that are used to access most html objects
  #
  # For example, to access a button on a web page that has the following html
  #  <input type = button name= 'b1' value='Click Me' onClick='javascript:doSomething()'>
  #
  # the following watir code could be used
  #
  #  ie.button(:name, 'b1').click
  #
  # or
  #
  #  ie.button(:value, 'Click Me').to_s
  #
  # there are many methods available to the Button object
  #
  # Is includable for classes that have @container, document and ole_inner_elements
  module IEContainer
    include Container
    include Watir::Exception
    
    def extra_for_contained
      extra={:container => self}
      extra[:browser]= @browser if @browser
      extra
    end

    # Note: @container is the container of this object, i.e. the container
    # of this container.
    # In other words, for ie.table().this_thing().text_field().set,
    # container of this_thing is the table.
    
    # This is used to change the typing speed when entering text on a page.
    attr_accessor :typingspeed
    attr_accessor :type_keys
    # The PageContainer object containing this element
    attr_accessor :page_container
    
    def copy_test_config(container) # only used by form and frame
      @typingspeed = container.typingspeed
      @type_keys = container.type_keys
    end
    private :copy_test_config
    
    # Write the specified string to the log.
    def log(what)
      @container.logger.debug(what) if @logger
    end
    
    def set_container container
      @container = container 
      @page_container = container.page_container
    end
        
    private
  end # module
end
