require 'vapir-common/element'
require 'vapir-ie/container'

module Vapir
  # Base class for html elements.
  # This is not a class that users would normally access.
  class IE::Element # Wrapper
    include IE::Container # presumes @container is defined
    include Vapir::Element
    include Vapir::Exception
    
    alias containing_object element_object
    alias ole_object element_object # TODO: deprecate this? 
    
    dom_attr :currentStyle => [:current_style_object, :computed_style_object]
    alias_deprecated :currentStyle, :current_style_object
    dom_attr :disabled => [:disabled, :disabled?] # this applies to all elements for IE, apparently. 
    def enabled?
      !disabled
    end
    # Checks if this element is enabled or not. Raises ObjectDisabledException if this is disabled.
    def assert_enabled
      # TODO: dry? copied from common InputElement
      if disabled
        raise Exception::ObjectDisabledException, "#{self.inspect} is disabled"
      end
    end
    
    private
    def base_element_class
      IE::Element
    end
    def browser_class
      IE
    end

    public
    
    # return the unique COM number for the element
    dom_attr :uniqueNumber => :unique_number
    # Return the outer html of the object - see http://msdn.microsoft.com/workshop/author/dhtml/reference/properties/outerhtml.asp?frame=true
    dom_attr :outerHTML => :outer_html

    # text immediately before this element 
    # 
    # http://msdn.microsoft.com/en-us/library/ms536427(VS.85).aspx
    def text_before_begin
      element_object.getAdjacentText("beforeBegin")
    end
    # text after the start of the element but before all other content in the element
    # 
    # http://msdn.microsoft.com/en-us/library/ms536427(VS.85).aspx
    def text_after_begin
      element_object.getAdjacentText("afterBegin")
    end
    # text immediately before the end of the element but after all other content in the element
    # 
    # http://msdn.microsoft.com/en-us/library/ms536427(VS.85).aspx
    def text_before_end
      element_object.getAdjacentText("beforeEnd")
    end
    # text immediately before this element 
    #
    # http://msdn.microsoft.com/en-us/library/ms536427(VS.85).aspx
    def text_after_end
      element_object.getAdjacentText("afterEnd")
    end
    # strange, counterintuitive aliases from watir 
    alias before_text text_after_end
    alias after_text text_before_begin
    
    # Returns the text content of the element.
    dom_attr :innerText => :text

#    include Comparable
#    def <=> other
#      assert_exists
#      other.assert_exists
#      ole_object.sourceindex <=> other.ole_object.sourceindex
#    end
    dom_attr :sourceIndex => :source_index

    # Return true if self is contained earlier in the html than other. 
    def before?(other)
      source_index < other.source_index
    end
    # Return true if self is contained later in the html than other. 
    def after?(other)
      source_index > other.source_index
    end
      
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
        event_object.send(key.to_s+'=', val)
      end
      return event_object
    end
    
    def create_event_object_hash(event_type, options)
      event_stuff=
        { :type => event_type,
          :keyCode => 0, # TODO/fix, implement this
          :ctrlKey => false,
          :ctrlLeft => false,
          :altKey => false,
          :altLeft => false,
          :shiftKey => false,
          :shiftLeft => false,
        }

      if %w(onclick onmousedown onmouseup ondblclick onmouseover onmouseout onmousemove).include?(event_type)
        client_center=self.client_center

        button_code=options[:button_code] || 
          MouseButtonCodes[options[:button]] || 
          (%w(onclick onmousedown onmouseup ondblclick).include?(event_type) ? MouseButtonCodes[:left] : 0)

        event_stuff.merge!(
          { :screenX => 0, # TODO/fix: use screen_center when implemented
            :screenY => 0,
            :clientX => client_center[0],
            :clientY => client_center[1],
            #:offsetX => , # if set this will clobber clientX/clientY. is itself set from clientX/Y when not set. 
            #:offsetY => ,
            #:x => , # these also seem to get set from clientX/Y 
            #:y => ,
            :button => button_code,
          })
      end
      relevant_options=options.reject do |optkey,optv|
        !%w(type keyCode ctrlKey ctrlLeft altKey altLeft shiftKey shiftLeft screenX screenY clientX clientY offsetX offsetY x y).detect{|keystr| keystr.to_sym==optkey}
      end
      return event_stuff.merge(relevant_options)
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
            handling_existence_failure(:handle => proc{ return result }) do
              assert_exists :force => true
              result=action.call
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

    def self.element_object_style(element_object, document_object)
      if element_object.nodeType==1
        element_object.currentStyle
      else
        nil
      end
    end
    
    
    # returns a two-element Vector containing the current scroll offset of this element relative
    # to any scrolling parents. 
    # this is basically stolen from prototype - see http://www.prototypejs.org/api/element/cumulativescrolloffset
    def scroll_offset
      # override the #scroll_offset defined in vapir-common because it calls #respond_to? which is very slow on WIN32OLE 
      xy=Vector[0,0]
      el=element_object
      begin
        begin
          if (scroll_left=el.scrollLeft).is_a?(Numeric) && (scroll_top=el.scrollTop).is_a?(Numeric)
            xy+=Vector[scroll_left, scroll_top]
          end
        rescue WIN32OLERuntimeError
          # doesn't respond to those; do nothing. 
        end
        el=el.parentNode
      end while el
      xy
    end
    
    private
    def element_object_exists?
      return false if !@element_object

      begin
        doc=container.document_object || (return false)
        win=doc.parentWindow || (return false)
        document_object=win.document || (return false) # I don't know why container.document_object != container.document_object.parentWindow.document 
      rescue WIN32OLERuntimeError
        # if a call to these methods from the above block raised this exception, we don't exist. 
        # if that's not the error, it's unexpected; raise. 
        if $!.message =~ /unknown property or method `(parentWindow|contentWindow|document)'/
          return false
        else
          raise
        end
      end
      begin
        # we need a javascript function to test equality because comparing two WIN32OLEs always returns false (unless they have the same object_id, which these don't) 
        win.execScript("__watir_javascript_equals__=function(a, b){return a==b;}")
      rescue WIN32OLERuntimeError
        return false
      end

      current_node=@element_object
      while current_node
        begin
          if win.__watir_javascript_equals__(current_node, document_object)
            # if we encounter the correct current document going up the parentNodes, @element_object does exist. 
            return true
          end
          current_node=current_node.parentNode
        rescue WIN32OLERuntimeError
          # two possibilities for why we're here:
          # if the method __watir_javascript_equals__ stops existing, then that probably means the window changed, meaning @element object doesn't exist anymore. 
          # if we encounter an error trying to access parentNode before reaching the current document, @element_object doesn't exist. 
          return false
        end
      end
      # if we escaped that loop, parentNode returned nil without encountering the current document; @element_object doesn't exist. 
      return false
    end
  end
end
  