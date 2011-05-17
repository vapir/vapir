=begin
    #
    # This module contains the factory methods that are used to access most html objects
    #
    # For example, to access a button on a web page that has the following html
    #  <input type = button name= 'b1' value='Click Me' onClick='javascript:doSomething()'>
    #
    # the following Firewatir code could be used
    #
    #  ff.button(:name, 'b1').click
    #
    # or
    #
    #  ff.button(:value, 'Click Me').to_s
    # 
    # One can use any attribute to uniquely identify an element including the user defined attributes
    # that is rendered on the HTML screen. Though, Attribute used to access an element depends on the type of element,
    # attributes used frequently to address an element are listed below
    #
    #    :index      - find the item using the index in the container ( a container can be a document, 
    #                  a TableCell, a Span, a Div or a P)
    #                  index is 1 based
    #    :name       - find the item using the name attribute
    #    :id         - find the item using the id attribute
    #    :value      - find the item using the value attribute
    #    :caption    - same as value
    #    :xpath      - finds the item using xpath query
    #
    # Typical Usage
    #
    #    ff.button(:id,    'b_1')                       # access the button with an ID of b_1
    #    ff.button(:name,  'verify_data')               # access the button with a name of verify_data
    #    ff.button(:value, 'Login')                     # access the button with a value (the text displayed on the button) of Login
    #    ff.button(:caption, 'Login')                   # same as above
    #    ff.button(:value, /Log/)                       # access the button that has text matching /Log/
    #    ff.button(:index, 2)                           # access the second button on the page ( 1 based, so the first button is accessed with :index,1)
    #
=end

require 'vapir-common/container'

module Vapir
  module Firefox::Container 
    include Vapir::Container
    
    def extra_for_contained
      base_extra_for_contained.merge(:firefox_socket => firefox_socket)
    end

    public
    # Returns array of element objects that match the given XPath query.
    #   Refer: https://developer.mozilla.org/en/DOM/document.evaluate
    def element_objects_by_xpath(xpath)
      elements=[]
      result=document_object.evaluate(xpath, containing_object, nil, firefox_socket.Components.interfaces.nsIDOMXPathResult.ORDERED_NODE_ITERATOR_TYPE, nil)
      while element=result.iterateNext
        elements << element
      end
      elements
    end

    # Returns the first element object that matches the given XPath query.
    #   Refer: http://developer.mozilla.org/en/docs/DOM:document.evaluate
    def element_object_by_xpath(xpath)
      document_object.evaluate(xpath, containing_object, nil, firefox_socket.Components.interfaces.nsIDOMXPathResult.FIRST_ORDERED_NODE_TYPE, nil).singleNodeValue
    end

    # Returns the first element that matches the given xpath expression or query.
    def element_by_xpath(xpath)
      # TODO: move this to common; should work the same for IE 
      base_element_class.factory(element_object_by_xpath(xpath), extra_for_contained)
    end

    # Returns the array of elements that match the given xpath query.
    def elements_by_xpath(xpath)
      # TODO/FIX: shouldn't this return an ElementCollection? tests seem to expect it not to, addressing it with 0-based indexing, but that seems insconsistent with everything else. 
      # TODO: move this to common; should work the same for IE 
      element_objects_by_xpath(xpath).map do |element_object|
        base_element_class.factory(element_object, extra_for_contained)
      end
    end

    # returns a JavascriptObject representing an array of text nodes below this element in the DOM 
    # heirarchy which are visible - that is, their parent element is visible. 
    #
    # same as the Vapir::Common #visible_text_nodes implementation, but much much faster.
    def visible_text_nodes
      assert_exists do
        visible_text_nodes_method.call(containing_object, document_object).to_array
      end
    end

    private
    # returns a javascript function that takes a node and a document object, and returns 
    # true if the element's display property will allow it to be displayed; false if not. 
    def element_displayed_method
      @element_displayed_method ||= firefox_socket.root.Vapir['element_displayed']
    end
    # returns a javascript function that takes a node and a document object, and returns 
    # the visibility of that node, obtained by ascending the dom until an explicit 
    # definition for visibility is found. 
    def element_real_visibility_method
      @element_real_visibility_method ||= firefox_socket.root.Vapir['element_real_visibility']
    end
    
    # returns a proc that takes a node and a document object, and returns 
    # an Array of strings, each of which is the data of a text node beneath the given node which 
    # is visible. 
    def visible_text_nodes_method
      @visible_text_nodes_method ||= firefox_socket.root.Vapir['visible_text_nodes']
    end
  end
end # module 

