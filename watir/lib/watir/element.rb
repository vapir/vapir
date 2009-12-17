module Watir
  # Base class for html elements.
  # This is not a class that users would normally access.
  class IEElement # Wrapper
    include IEContainer # presumes @container is defined
    include Element
    include Watir::Exception
    
    alias containing_object element_object
    alias ole_object element_object # TODO: deprecate this? 
    
    dom_attr :currentStyle
    dom_attr :disabled => [:disabled, :disabled?] # this applies to all elements for IE, apparently. 
    def enabled?
      !disabled
    end
    
    private
    def base_element_class
      IEElement
    end
    def browser_class
      IE
    end

    public
    
    # return the unique COM number for the element
    dom_attr :uniqueNumber => :unique_number
    # Return the outer html of the object - see http://msdn.microsoft.com/workshop/author/dhtml/reference/properties/outerhtml.asp?frame=true
    dom_attr :outerHTML => :outer_html

    # return the text before the element
    def before_text
      element_object.getAdjacentText("afterEnd")
    end
    
    # return the text after the element
    def after_text
      element_object.getAdjacentText("beforeBegin")
    end
    
    # Returns the text content of the element.
    dom_attr :innerText => :text

#    include Comparable
#    def <=> other
#      assert_exists
#      other.assert_exists
#      ole_object.sourceindex <=> other.ole_object.sourceindex
#    end
    dom_attr :sourceIndex => :source_index

#    # Return true if self is contained earlier in the html than other. 
#    alias :before? :< 
#    # Return true if self is contained later in the html than other. 
#    alias :after? :> 
      
    def typingspeed
      @container.typingspeed
    end
    def type_keys
      @type_keys || @container.type_keys
    end
    
    #   This method clicks the active element.
    #   raises: UnknownObjectException  if the object is not found
    #   ObjectDisabledException if the object is currently disabled
    def click
      with_highlight do
        assert_enabled if respond_to?(:assert_enabled)
        ole_object.click
      end
      wait
    end
    
    def click_no_wait
      with_highlight do
        assert_enabled if respond_to?(:assert_enabled)
        document_object.parentWindow.setTimeout("
          (function(tagName, uniqueNumber)
          { var candidate_elements=document.getElementsByTagName(tagName);
            for(var i=0;i<candidate_elements.length;++i)
            { if(candidate_elements[i].uniqueNumber==uniqueNumber)
              { candidate_elements[i].click();
              }
            }
          })(#{self.tagName.inspect}, #{element_object.uniqueNumber.inspect})
        ", 0)
      end
    end

    # Executes a user defined "fireEvent" for objects with JavaScript events tied to them such as DHTML menus.
    #   usage: allows a generic way to fire javascript events on page objects such as "onMouseOver", "onClick", etc.
    #   raises: UnknownObjectException  if the object is not found
    #           ObjectDisabledException if the object is currently disabled
    def fire_event(event, options={})
      options={:highlight => true, :wait => true}.merge(options)
      with_highlight(options) do
        assert_enabled if respond_to?(:assert_enabled)
        if options[:wait]
          ole_object.fireEvent(event.to_s)
          wait
        else
          document_object.parentWindow.setTimeout("
            (function(tagName, uniqueNumber, event)
            { var candidate_elements=document.getElementsByTagName(tagName);
              for(var i=0;i<candidate_elements.length;++i)
              { if(candidate_elements[i].uniqueNumber==uniqueNumber)
                 { candidate_elements[i].fireEvent(event);
                }
              }
            })(#{self.tagName.inspect}, #{element_object.uniqueNumber.inspect}, #{event.to_s.inspect})
          ", 0)
        end
      end
    end
    # Executes a user defined "fireEvent" for objects with JavaScript events tied to them such as DHTML menus.
    #   usage: allows a generic way to fire javascript events on page objects such as "onMouseOver", "onClick", etc.
    #   raises: UnknownObjectException  if the object is not found
    #           ObjectDisabledException if the object is currently disabled
    def fire_event_no_wait(event, options={})
      fire_event(event, options.merge(:wait => false))
    end
    
    def wait(options={})
      @container.wait(options)
    end

    # If any parent element isn't visible then we cannot write to the
    # element. The only realiable way to determine this is to iterate
    # up the DOM element tree checking every element to make sure it's
    # visible.
    def visible?
      # Now iterate up the DOM element tree and return false if any
      # parent element isn't visible or is disabled.
      assert_exists do
        object = element_object
        while object
          if currentStyle=object.currentstyle
            if currentStyle.invoke('visibility') =~ /^hidden$/i || currentStyle.invoke('display') =~ /^none$/i
              return false
            end
          end # i guess if there's no currentStyle we assume it is visible 
          
          # why would disabled affect visibility? 
          #if object.invoke('isDisabled')
          #  return false
          #end
          object = object.parentElement
        end
        true
      end
    end
    
    private
    # if the ole's #exists? method returns false, then it doesn't exist. also, if 
    # the parentNode is nil, then the element no longer exists on the DOM. 
    def element_object_exists?
      begin
        document_object=container.document_object.parentWindow.document # I don't know why document_object != document_object.parentWindow.document 
        win=document_object.parentWindow
        # we need a javascript function to test equality because comparing two WIN32OLEs always returns false (unless they have the same object_id, which these don't) 
        win.execScript("__watir_javascript_equals__=function(a, b){return a==b;}")
        current_node=@element_object
        while current_node
          if win.__watir_javascript_equals__(current_node, document_object)
            return true
          end
          current_node=current_node.parentNode
        end
        return false
      rescue WIN32OLERuntimeError
        false
      end
    end
  end
end  
