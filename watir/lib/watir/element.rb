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
    
    private
    # for use with events' button property
    MouseButtonCodes=
      { :left => 1,
        :middle => 4,
        :right => 2,
      }

    # returns an object representing an event (a WIN32OLE object) 
    # see:
    # http://msdn.microsoft.com/en-us/library/ms535863%28VS.85%29.aspx
    def create_event_object(event_type, options)
      event_object=document_object.createEventObject
      
      event_object_hash=create_event_object_hash(event_type, options)
      event_object_hash.each_pair do |key,val|
        event_object[key.to_s]=val
      end
      return event_object
    end
    
    def create_event_object_hash(event_type, options)
      client_center=self.client_center
      button_code=options[:button_code] || 
        MouseButtonCodes[options[:button]] || 
        (['onclick', 'onmousedown', 'onmouseup'].include?(event_type) ? MouseButtonCodes[:left] : 0)
      event_stuff=
        { :type => event_type,
          :screenX => options[:screenX] || 0, # TODO/fix: use screen_center when implemented
          :screenY => options[:screenY] || 0,
          :clientX => options[:clientX] || client_center[0],
          :clientY => options[:clientY] || client_center[1],
          :offsetX => 0, # TODO/fix: dimensions / 2 here for center? 
          :offsetY => 0,
          :x => 0, # TODO/fix: ?? offset from the closest relatively positioned parent element of the element that fired the event
          :y => 0,
          :button => button_code,
          :keyCode => 0, # TODO/fix, implement this
          :ctrlKey => false,
          :ctrlLeft => false,
          :altKey => false,
          :shiftKey => false,
          :shiftLeft => false,
        }
    end
    
    # makes json for an event object from the given options. 
    # does so in a sort of naive way, but a way that doesn't require 
    # something as heavyweight as pulling in ActiveSupport or the JSON gem. 
    def create_event_object_json(options)
      event_object_hash=create_event_object_hash(nil, options).reject{|(k,v)| v.nil? }
      event_object_json="{"+event_object_hash.map do |(attr, val)|
        raise RuntimeError, "unexpected attribute #{attr}" unless attr.is_a?(Symbol) && attr.to_s=~ /\A[\w_]+\z/
        unless [Numeric, String, TrueClass, FalseClass].any?{|klass| val.is_a?(klass) }
          raise ArgumentError, "Cannot pass given key/value pair: #{attr.inspect} => #{val.inspect} (#{val.class})"
        end
        attr.to_s.inspect+": "+val.inspect
      end.join(", ")+"}"
    end
    
    public
    
    # Fires the click event on this element. 
    #
    # Options:
    # - :wait => true or false. If true, waits for the javascript call to return, and calls the #wait method. 
    #   If false, does not wait for the javascript to return and does not call #wait.
    #   Default is true.
    # - :highlight => true or false. Highlights the element while clicking if true. Default is true. 
    def click(options={})
      options={:wait => true, :highlight => true}.merge(options)
      result=nil
      with_highlight(options) do
        assert_enabled if respond_to?(:assert_enabled)
        if options[:wait]
          # we're putting all of the clicking actions in an array so that we can more easily separate out the 
          # overhead of checking existence and returning if existence fails. 
          actions=
           [ proc { fire_event('mousedown', options) },
             proc { fire_event('mouseup', options) },
             #proc { fire_event('click', options) },
             proc { element_object.respond_to?(:click) ? element_object.click : fire_event('click', options)
               # TODO/fix: this calls the 'click' function if there is one, but that doesn't pass information 
               # like button/clientX/etc. figure out how to pass that to the event that click fires. 
               # we can't just use the fire_event, because the click function does more than that. for example,
               # a link won't be followed just from firing the onclick event; the click function has to be called. 
               },
           ]
          actions.each do |action|
            # javascript stuff responding to previous events can cause self to stop existing, so check at every subsequent step
            if exists?
              result=action.call
            else
              return result
            end
          end
          wait
          result
        else
          document_object.parentWindow.setTimeout("
            (function(tagName, uniqueNumber, event_options)
            { var event_object=document.createEventObject();
              for(key in event_options)
              { event_object[key]=event_options[key];
              }
              var candidate_elements=document.getElementsByTagName(tagName);
              for(var i=0;i<candidate_elements.length;++i)
              { var element=candidate_elements[i];
                if(element.uniqueNumber==uniqueNumber)
                { element.fireEvent('onmousedown', event_object);
                  element.fireEvent('onmouseup', event_object);
                  //element.fireEvent('onclick', event_object); // #TODO/fix - same as above with click() vs fireEvent('onclick', ...)
                  element.click ? element.click() : element.fireEvent('onclick', event_object);
                }
              }
            })(#{self.tagName.inspect}, #{element_object.uniqueNumber.inspect}, #{create_event_object_json(options)})
          ", 0)
          nil
        end
      end
      result
    end

    # calls #click with :wait option false. 
    # Takes options:
    # - :highlight => true or false. Highlights the element while clicking if true. Default is true. 
    def click_no_wait(options={})
      click(options.merge(:wait => false))
    end

    # Executes a user defined "fireEvent" for objects with JavaScript events tied to them such as DHTML menus.
    #   usage: allows a generic way to fire javascript events on page objects such as "onMouseOver", "onClick", etc.
    #   raises: UnknownObjectException  if the object is not found
    #           ObjectDisabledException if the object is currently disabled
    def fire_event(event_type, options={})
      event_type = event_type.to_s.downcase # in case event_type was given as a symbol
      unless event_type =~ /\Aon(.*)\z/i
        event_type = "on"+event_type
      end
      
      options={:highlight => true, :wait => true}.merge(options)
      with_highlight(options) do
        assert_enabled if respond_to?(:assert_enabled)
        if options[:wait]
          # we need to pass fireEvent two arguments - the event type, and the event object. 
          # we can't do this directly. there is a bug or something, the result of which is 
          # that if we pass the WIN32OLE that is the return from document.createEventObject,
          # none of the information about it actually gets passed. its button attribute is
          # 0 regardless of what it was set to; same with clientx, clientY, and everything else. 
          # this seems to be an issue only with passing arguments which are WIN32OLEs to 
          # functions that are native functions (as opposed to functions defined by a user
          # in javascript). so, a workaround is to make a function that is written in javascript
          # that wraps around the native function and just passes the arguments to it. this
          # causes the objects to be passed correctly. to illustrate, compare: 
          #  window.alert(document.createEventObject)
          # this causes an alert to appear with the text "[object]"
          #  window.eval("alert_wrapped=function(message){alert(message);}")
          #  window.alert_wrapped(document.createEventObject)
          # this causes an alert to appear with the text "[object Event]"
          # so, information is lost in the first one, where it's passed straight
          # to the native function but not in the second one where the native function
          # is wrapped in a javascript function. 
          #
          # a generic solution follows, but it doesn't work. I'm leaving it in here in case
          # I can figure out something to do with it later:
          #window.eval("watir_wrap_native_for_win32ole=function(object, functionname)
          #             { var args=[];
          #               for(var i=2; i<arguments.length; ++i)
          #               { args.push(arguments[i]);
          #               }
          #               return object[functionname].apply(object, args);
          #             }")
          #
          # the problem with the above, using apply, is that it sometimse raises: 
          # WIN32OLERuntimeError: watir_wrap_native_for_win32ole
          #     OLE error code:0 in <Unknown>
          #       <No Description>
          #     HRESULT error code:0x80020101
          # 
          # so, instead, implementing to a version that doesn't use apply but 
          # therefore has to have  fixed number of arguments. 
          # TODO: move this to its own function? will when I run into a need for it outside of here, I guess. 
          window=document_object.parentWindow
          window.eval("watir_wrap_native_for_win32ole_two_args=function(object, functionname, arg1, arg2)
            { return object[functionname](arg1, arg2);
            }")
          # then use it, passing the event object. 
          # thus the buttons and mouse position and all that are successfully passed. 
          event_object= create_event_object(event_type, options)
          result=window.watir_wrap_native_for_win32ole_two_args(element_object, 'fireEvent', event_type, event_object)
          wait
          result
        else
          document_object.parentWindow.setTimeout("
            (function(tagName, uniqueNumber, event_type, event_options)
            { var event_object=document.createEventObject();
              for(key in event_options)
              { event_object[key]=event_options[key];
              }
              var candidate_elements=document.getElementsByTagName(tagName);
              for(var i=0;i<candidate_elements.length;++i)
              { if(candidate_elements[i].uniqueNumber==uniqueNumber)
                { candidate_elements[i].fireEvent(event_type, event_object);
                }
              }
            })(#{self.tagName.inspect}, #{element_object.uniqueNumber.inspect}, #{event_type.to_s.inspect}, #{create_event_object_json(options)})
          ", 0)
          nil
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
    
    
    # returns a two-element Vector containing the current scroll offset of this element relative
    # to any scrolling parents. 
    # this is basically stolen from prototype - see http://www.prototypejs.org/api/element/cumulativescrolloffset
    def scroll_offset
      # override the #scroll_offset defined in commonwatir because it calls #respond_to? which is very slow on WIN32OLE 
      xy=Vector[0,0]
      el=element_object
      begin
        begin
          xy+=Vector[el.scrollLeft, el.scrollTop]
        rescue WIN32OLERuntimeError
          # doesn't respnd to those; do nothing. 
        end
        el=el.parentNode
      end while el
      xy
    end
    
    private
    def element_object_exists?
      return nil if !@element_object

      win=container.document_object.parentWindow
      document_object=win.document # I don't know why container.document_object != container.document_object.parentWindow.document 

      # we need a javascript function to test equality because comparing two WIN32OLEs always returns false (unless they have the same object_id, which these don't) 
      win.execScript("__watir_javascript_equals__=function(a, b){return a==b;}")

      current_node=@element_object
      while current_node
        if win.__watir_javascript_equals__(current_node, document_object)
          # if we encounter the correct current document going up the parentNodes, @element_object does exist. 
          return true
        end
        begin
          current_node=current_node.parentNode
        rescue WIN32OLERuntimeError
          # if we encounter an error trying to access parentNode before reaching the current document, @element_object doesn't exist. 
          return false
        end
      end
      # if we escaped that loop, parentNode returned nil without encountering the current document; @element_object doesn't exist. 
      return false
    end
  end
end  
