module Watir
  # Base class for html elements.
  # This is not a class that users would normally access.
  class FFElement
    include Watir::FFContainer
    include Element

    # Creates new instance of FFElement. 
    def initialize(how, what, extra={})
      unless @jssh_socket=extra[:jssh_socket]
        raise RuntimeError, "No JSSH socket given! Firefox elements need this (specified in the :jssh_socket key of the extra hash)"
      end
      default_initialize(how, what, extra)
    end

    attr_reader :jssh_socket
    
    def outer_html
      # in case doing appendChild of self on the temp_parent_element causes it to be removed from our parentNode, we first copy the list of parentNode's childNodes (our siblings)
      # todo/fix: can use cloneNode instead of all this? 
      if parentNode=element_object.parentNode
        parentNode=parentNode.store_rand_temp
        orig_siblings=jssh_socket.object('[]').store_rand_prefix('firewatir_elements')
        parentNode.childNodes.to_array.each do |node|
          orig_siblings.push node
        end
      end
      
      temp_parent_element=document_object.createElement('div')
      temp_parent_element.appendChild(element_object)
      self_outer_html=temp_parent_element.innerHTML
      
      # reinsert self in parentNode's childNodes if we have disappeared due to the appendChild on different parent
      if parentNode && parentNode.childNodes.length != orig_siblings.length
        while parentNode.childNodes.length > 0
          parentNode.removeChild(parentNode.childNodes[0])
        end
        while orig_siblings.length > 0
          parentNode.appendChild orig_siblings.shift
        end
      end
      
      return self_outer_html
    end
    alias outerHTML outer_html
    
    # the containing object is what #locate uses to find stuff contained by this element. 
    # this is generally the same as the dom object, but different for Browser and Frame. 
    alias containing_object element_object

#    alias ole_object element_object

    private
    def base_element_class
      FFElement
    end
    def browser_class
      Firefox
    end

    public
    def currentStyle # currentStyle is IE; document.defaultView.getComputedStyle is mozilla. 
      document_object.defaultView.getComputedStyle(element_object, nil)
    end
    
    public

    # Returns true if this Element's #text matches the given String or Regexp to match; otherwise false. 
    def contains_text?(match)
      self_text=self.text
      if match.kind_of? Regexp
        !!self_text =~ match
      elsif match.kind_of? String
        self_text.include?(match)
      else
        raise TypeError, "Expected String or Regexp, got #{match.inspect} (#{match.class.name})"
      end
    end
    alias contains_text contains_text?

    # Fires the given event on this element. 
    # The given event name can be either of the form 'onclick' (for compatibility with IE) or just 'click' (can also be Symbol :onclick or :click)
    # takes options:
    # - :wait => true/false - (default true) whether to wait for the fire event to return, and call #wait (see #wait's documentation). 
    #   if false, fires the event in a setTimeout(click function, 0) in the browser. 
    # - :highlight => true/false - (default true) whether to highlight this Element when firing the event. 
    #
    # TODO: Provide ability to specify event parameters like keycode for key events, and click screen
    #       coordinates for mouse events.
    def fire_event(event, options={})
      options={:wait => true, :highlight => true}.merge(options)
      with_highlight(options) do

        event = event.to_s.downcase # in case event was given as a symbol
        event =~ /\Aon(.*)\z/i
        event = $1 if $1
      
        # info about event types harvested from:
        #   http://www.howtocreate.co.uk/tutorials/javascript/domevents
        case event
        when 'abort', 'blur', 'change', 'error', 'focus', 'load', 'reset', 'resize', 'scroll', 'select', 'submit', 'unload'
          dom_event_type = 'HTMLEvents'
          dom_event_init = [:initEvent, event, true, true]
        when 'keydown', 'keypress', 'keyup'
          dom_event_type = 'KeyEvents'
          # Firefox has a proprietary initializer for keydown/keypress/keyup.
          # Args are as follows:
          #                                type,   bubbles, cancelable, windowObject,          ctrlKey, altKey, shiftKey, metaKey, keyCode, charCode
          dom_event_init = [:initKeyEvent, event, true,    true,      content_window_object, false,  false, false,   false,   0,      0]
        when 'click', 'dblclick', 'mousedown', 'mousemove', 'mouseout', 'mouseover', 'mouseup'
          dom_event_type = 'MouseEvents'
          # Args are as follows:             type,   bubbles, cancelable, windowObject,          detail, screenX, screenY, clientX, clientY, ctrlKey, altKey, shiftKey, metaKey, button, relatedTarget
          dom_event_init = [:initMouseEvent, event, true,    true,      content_window_object, 1,      0,       0,       0,      0,       false,  false, false,   false,   0,      nil]
        else
          dom_event_type = 'HTMLEvents'
          dom_event_init = [:initEvent, event, true, true]
        end
        event=document_object.createEvent(dom_event_type)
        event.invoke(*dom_event_init) # calls to the init*Event method
        if !options[:wait]
          raise "need a content window on which to setTimeout if we are not waiting" unless content_window_object
          fire_event_func=jssh_socket.object("(function(dom_object, event){return function(){dom_object.dispatchEvent(event)};})").pass(element_object, event)
          content_window_object.setTimeout(fire_event_func, 0)
        else
          element_object.dispatchEvent(event)
        end

        # I do not know why the following was here, clobbering the event type. 
        #if(element_type == "HTMLSelectElement")
        #  dom_event_type = 'HTMLEvents'
        #  dom_event_init = "initEvent(\"#{event}\", true, true)"
        #end
      
        wait if options[:wait]
      end
    end

    # Fires the click event on this element. 
    #
    # Options:
    # - :wait => true or false. If true, waits for the javascript call to return, and calls the #wait method. 
    #   If false, does not wait for the javascript to return and does not call #wait.
    #   Default is true.
    # - :highlight => true or false. Highlights the element while clicking if true. Default is true. 
    def click(options={})
      options={:wait => true, :highlight => true}.merge(options)
      with_highlight(options) do
        assert_enabled if respond_to?(:assert_enabled)
        if element_object.respond_to?(:click)
          if options[:wait]
            element_object.click
          else
            click_func=jssh_socket.object("(function(dom_object){return function(){dom_object.click()};})").pass(element_object)
            content_window_object.setTimeout(click_func, 0)
          end
        else
          fire_event('onclick', options)
        end
      end
      wait if options[:wait]
    end

    # calls #click with :wait option false. 
    # Takes options:
    # - :highlight => true or false. Highlights the element while clicking if true. Default is true. 
    def click_no_wait(options={})
      click(options.merge(:wait => false))
    end
  
    # Waits for the browser to finish loading, if it is loading. See Firefox#wait. 
    def wait(options={})
      @container.wait(options)
    end
    # Checks this element and its parents for display: none or visibility: hidden, these are 
    # the most common methods to hide an html element. Returns false if this seems to be hidden
    # or a parent is hidden. 
    def visible? 
      assert_exists do
        element_to_check=element_object
        while element_to_check && !element_to_check.instanceof(jssh_socket.Components.interfaces.nsIDOMDocument)
          style=document_object.defaultView.getComputedStyle(element_to_check, nil)
          if style.visibility =~ /\Ahidden\z/i || style[:display] =~ /\Anone\z/i
            return false
          end
          element_to_check=element_to_check.parentNode
        end
      end
      return true
    end

    # Returns the text content of the element.
    dom_attr :textContent => :text
    
    private
    def element_object_exists?
#      parent=@element_object
#      while true
#        return false unless parent # if we encounter a parent such that parentNode is nil, we aren't on the document. 
#        return true if parent==document_object # if we encounter the document as a parent, we are on the document. 
#        new_parent=parent.parentNode
#        raise(RuntimeError, "Circular reference in parents!") if new_parent==parent
#        parent=new_parent
#      end
      # above is horrendously slow; optimized below. 
      return false unless @element_object
      return jssh_socket.object("(function(parent, document_object)
      { while(true)
        { if(!parent)
          { return false;
          }
          if(parent==document_object)
          { return true;
          }
          parent=parent.parentNode;
        }
      })").call(@element_object, container.document_object) # use the container's document so that frames look at their parent document, not their own document 
    end
  
#    def invoke(js_method)
#      element_object.invoke(js_method)
#    end

#    def assign(property, value)
#      locate
#      element_object.attr(property).assign(value)
#    end
    
  end # Element
end # FireWatir
