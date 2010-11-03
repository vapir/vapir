require 'vapir-common/element'
require 'vapir-firefox/container'

module Vapir
  # Base class for html elements.
  # This is not a class that users would normally access.
  class Firefox::Element
    include Vapir::Firefox::Container
    include Vapir::Element

    # Creates new instance of Firefox::Element. 
    def initialize(how, what, extra={})
      @jssh_socket=extra[:jssh_socket]
      @jssh_socket||= (extra[:browser].jssh_socket if extra[:browser])
      @jssh_socket||= (extra[:container].jssh_socket if extra[:container])
      @jssh_socket||= (what.jssh_socket if how==:element_object)
      unless @jssh_socket
        raise RuntimeError, "No JSSH socket given! Firefox elements need this (specified in the :jssh_socket key of the extra hash)"
      end
      default_initialize(how, what, extra)
    end

    attr_reader :jssh_socket
    
    def outer_html
      temp_parent_element=document_object.createElement('div')
      temp_parent_element.appendChild(element_object.cloneNode(true))
      self_outer_html=temp_parent_element.innerHTML
      
      return self_outer_html
    end
    alias outerHTML outer_html
    
    # the containing object is what #locate uses to find stuff contained by this element. 
    # this is generally the same as the dom object, but different for Browser and Frame. 
    alias containing_object element_object

    private
    def base_element_class
      Firefox::Element
    end
    def browser_class
      Firefox
    end

    public
    def current_style_object # currentStyle is IE; document.defaultView.getComputedStyle is mozilla. 
      document_object.defaultView.getComputedStyle(element_object, nil)
    end
    alias computed_style_object current_style_object
    alias_deprecated :currentStyle, :current_style_object
    
    # Fires the given event on this element. 
    # The given event name can be either of the form 'onclick' (for compatibility with IE) or just 'click' (can also be Symbol :onclick or :click)
    # takes options:
    # - :wait => true/false - (default true) whether to wait for the fire event to return, and call #wait (see #wait's documentation). 
    #   if false, fires the event in a setTimeout(click function, 0) in the browser. 
    # - :highlight => true/false - (default true) whether to highlight this Element when firing the event. 
    #
    # TODO: Provide ability to specify event parameters like keycode for key events, and click screen
    #       coordinates for mouse events.
    def fire_event(event_type, options={})
      options={:wait => true, :highlight => true}.merge(options)
      with_highlight(options) do
        event=create_event_object(event_type, options)
        if !options[:wait]
          raise "need a content window on which to setTimeout if we are not waiting" unless content_window_object
          fire_event_func=jssh_socket.object("(function(element_object, event){return function(){element_object.dispatchEvent(event)};})").pass(element_object, event)
          content_window_object.setTimeout(fire_event_func, 0)
          nil
        else
          result=element_object.dispatchEvent(event)
          wait if exists?
          result
        end
      end
    end
    
    private
    # for use with events' button property:
    # https://developer.mozilla.org/en/DOM/event.button
    MouseButtonCodes=
      { :left => 0,
        :middle => 1,
        :right => 2,
      }

    # returns an object representing an event (a jssh object) 
    def create_event_object(event_type, options)
      event_type = event_type.to_s.downcase # in case event_type was given as a symbol
      if event_type =~ /\Aon(.*)\z/i
        event_type = $1
      end
      
      # info about event types harvested from:
      #   http://www.howtocreate.co.uk/tutorials/javascript/domevents
      # the following sets up the dom event type (dom_event_type{, the function 
      # to be called to initialize the event (init_event_func), and the arguments 
      # to pass to that function (init_event_args). 
      # the arguments list is an array of two-element arrays (a hash would 
      # be more appropriate except that order needs to be preserved). only
      # the second element is passed to the function that initializes the event;
      # the first element is just there to identify what the argument is/does
      # for clarity when reading this code. 
      case event_type
      when 'keydown', 'keypress', 'keyup'
        dom_event_type = 'KeyEvents'
        init_event_func=:initKeyEvent
        init_event_args=
          [ [:type, event_type],
            [:bubbles, true],
            [:cancelable, true],
            [:windowObject, content_window_object],
            [:ctrlKey, options[:ctrlKey] || false],
            [:altKey, options[:altKey] || false],
            [:shiftKey, options[:shiftKey] || false],
            [:metaKey, options[:metaKey] || false],
            [:keyCode, options[:keyCode] || 0],
            [:charCode, options[:charCode] || 0],
          ]
      when 'click', 'dblclick', 'mousedown', 'mousemove', 'mouseout', 'mouseover', 'mouseup'
        dom_event_type = 'MouseEvents'
        init_event_func = :initMouseEvent
        client_center=self.client_center
        init_event_args=
          [ [:type, event_type],
            [:bubbles, true],
            [:cancelable, true],
            [:windowObject, content_window_object], # aka view
            [:detail, event_type=='dblclick' ? 2 : 1], # value is always 2 for double-click; default to 1 for other stuff. 
            [:screenX, options[:screenX] || 0], # TODO/fix - use screen_offset (or screen_center) when implemented/exists 
            [:screenY, options[:screenY] || 0],
            [:clientX, options[:clientX] || client_center[0]], # by default, assume the mouse is at the center of the element 
            [:clientY, options[:clientY] || client_center[1]],
            [:ctrlKey, options[:ctrlKey] || false],
            [:altKey, options[:altKey] || false],
            [:shiftKey, options[:shiftKey] || false],
            [:metaKey, options[:metaKey] || false],
            [:button, MouseButtonCodes[options[:button] || :left]],
            [:relatedTarget, nil],
          ]
      #when 'abort', 'blur', 'change', 'error', 'focus', 'load', 'reset', 'resize', 'scroll', 'select', 'submit', 'unload'
      else
        dom_event_type = 'HTMLEvents'
        init_event_func=:initEvent
        init_event_args=
          [ [:type, event_type],
            [:bubbles, true],
            [:cancelable, true],
          ]
      end
      event=document_object.createEvent(dom_event_type)
      event.invoke(init_event_func, *init_event_args.map{|arg| arg.last }) # calls to the init*Event method
      return event
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
          [:mousedown, :mouseup, :click].each do |event_type|
            # javascript stuff responding to previous events can cause self to stop existing, so check at every subsequent step
            if exists?
              result=fire_event(event_type, options)
            else
              return result
            end
          end
          wait
        else
          mouse_down_event=create_event_object('mousedown', options)
          mouse_up_event=create_event_object('mouseup', options)
          click_event=create_event_object('click', options)
          content_window_object.setTimeout(jssh_socket.call_function(:element_object => element_object, :mouse_down_event => mouse_down_event, :mouse_up_event => mouse_up_event, :click_event => click_event) do 
          " return function()
            { element_object.dispatchEvent(mouse_down_event);
              element_object.dispatchEvent(mouse_up_event);
              element_object.dispatchEvent(click_event);
            };"
          end, 0)
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

    # Waits for the browser to finish loading, if it is loading. See Firefox#wait. 
    def wait(options={})
      @container.wait(options)
    end
    
    # Checks this element and its parents for display: none or visibility: hidden, these are 
    # the most common methods to hide an html element. Returns false if this seems to be hidden
    # or a parent is hidden. 
    def visible? 
      assert_exists do
        jssh_socket.call_function(:element_to_check => element_object, :document_object => document_object) do %Q(
          var really_visible=null;
          while(element_to_check) //&& !(element_to_check instanceof Components.interfaces.nsIDOMDocument)
          { var style = element_to_check.nodeType==1 ? document_object.defaultView.getComputedStyle(element_to_check, null) : null;
            if(style)
            { // only pay attention to the innermost definition that really defines visibility - one of 'hidden', 'collapse' (only for table elements), 
              // or 'visible'. ignore 'inherit'; keep looking upward. 
              // this makes it so that if we encounter an explicit 'visible', we don't pay attention to any 'hidden' further up. 
              // this style is inherited - may be pointless for firefox, but IE uses the 'inherited' value. not sure if/when ff does.
              var visibility=style && style.visibility;
              if(really_visible==null && visibility)
              { visibility=visibility.toLowerCase();
                if(visibility=='hidden' || visibility=='collapse')
                { really_visible=false;
                  return false; // don't need to continue knowing it's not visible. 
                }
                else if(visibility=='visible')
                { really_visible=true; // we don't return true yet because a parent with display of 'none' can override 
                }
              }
              // check for display property. this is not inherited, and a parent with display of 'none' overrides an immediate visibility='visible' 
              var display=style && style.display;
              if(display && display.toLowerCase()=='none')
              { return false;
              }
            }
            element_to_check=element_to_check.parentNode;
          }
          return true;
        )
        end
      end
    end
    

    def self.element_object_style(element_object, document_object)
      if element_object.nodeType==1 #element_object.instanceof(element_object.jssh_socket.Components.interfaces.nsIDOMDocument)
        document_object.defaultView.getComputedStyle(element_object, nil)
      else
        nil
      end
    end

    # Returns the text content of the element.
    dom_attr :textContent => :text
    
    private
    def element_object_exists?
      return false unless @element_object
      return jssh_socket.call_function(:parent => @element_object, :document_object => container.document_object) do  # use the container's document so that frames look at their parent document, not their own document
      " while(true)
        { if(!parent)
          { return false; // if we encounter a parent such that parentNode is nil, we aren't on the document. 
          }
          if(parent==document_object) // if we encounter the document as a parent, we are on the document. 
          { return true;
          }
          parent=parent.parentNode;
        }"
      end
    end
  
  end # Element
end # Vapir
