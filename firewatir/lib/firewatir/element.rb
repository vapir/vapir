require 'firewatir/specifier'

module Watir
  # Base class for html elements.
  # This is not a class that users would normally access.
  class FFElement
    include Watir::FFContainer
    include Element
    # Number of spaces that separate the property from the value in the to_s method
    TO_S_SIZE = 14
  

    # How to get the nodes using XPath in mozilla.
    #ORDERED_NODE_ITERATOR_TYPE = 5
    # To get the number of nodes returned by the xpath expression
    #NUMBER_TYPE = 1
    # To get single node value
    #FIRST_ORDERED_NODE_TYPE = 9
    # This stores the level to which we have gone finding element inside another element.
    # This is just to make sure that every element has unique name in JSSH.
    
    class << self
      def factory(dom_object, extra={})
        curr_klass=self
        ObjectSpace.each_object(Class) do |klass|
          if klass < curr_klass
            Watir::Specifier.match_candidates([dom_object], klass.specifiers) do |match|
              curr_klass=klass
            end
          end
        end
        curr_klass.new(:dom_object, dom_object, extra)
      end
    
      # look for constants to define specifiers - either class::Specifier, or
      # the simpler class::TAG
      def specifiers
        if self.const_defined?('Specifiers') # note that though constants are inherited, this checks if Specifiers is defined on the class itself 
                                              # (although the class itself may not define them, these are mostly defined for classes by element classes in commonwatir)
          #self.const_get('Specifiers')
          self::Specifiers
        elsif self.const_defined?('TAG')
          [{:tagName => self::TAG}]
        else
          raise "No way found to specify #{self}."
        end
      end
      
      def default_how
        self.const_defined?('DefaultHow') ? self.const_get('DefaultHow') : nil
      end
      
    end

    #
    # Description:
    #    Creates new instance of element. 
    #
    #    Used internally by FireWatir.
    #
    # Input:
    #   
    #
    def initialize(how, what, extra={})
      @how, @what=how, what
      raise ArgumentError, "how (first argument) should be a Symbol, not: #{how.inspect}" unless how.is_a?(Symbol)
      @extra=extra
      @index=extra[:index] && Integer(extra[:index])
      @container=extra[:container]
      @browser=extra[:browser]
      @jssh_socket=extra[:jssh_socket] || (@container ? @container.jssh_socket : @browser ? @browser.jssh_socket : nil)
      locate! unless extra.key?(:locate) && !extra[:locate]
    end

    attr_reader :browser
    attr_reader :container
    attr_reader :jssh_socket
    attr_reader :how, :what, :index
    attr_reader :element_object
    alias dom_object element_object
    alias element_name element_object
#    alias ole_object element_object

    private
    def container_candidates(specifiers)
      raise unless @container
      ids=specifiers.map{|s| s[:id] }.compact.uniq
      tags=specifiers.map{|s| s[:tagName] }.compact.uniq
      names=specifiers.map{|s| s[:name] }.compact.uniq
      classNames=specifiers.inject([]){|arr,s| arr+[s[:class], s[:className]]}.compact.uniq # this (or, all of these) should probably look back through Watir::Specifier::LocateAliases to check for that crap, but this will do 

      # we can only use getElementById if:
      # - id is a string, as getElementById doesn't do regexp
      # - index is 1 or nil; otherwise even though it's not really valid, other identical ids won't get searched
      # - id is the _only_ specifier, otherwise if the same id is used multiple times but the first one doesn't match 
      #   the given specifiers, the element won't be found
      # - @container has getElementById defined (that is, it's a Browser or a Frame), otherwise if we called 
      #   document_object.getElementById we wouldn't know if what's returned is below @container in the DOM heirarchy or not
      if ids.size==1 && ids.first.is_a?(String) && (!@index || @index==1) && !specifiers.any?{|s| s.keys.any?{|k|k!=:id}} && @container.dom_object.respond_to?(:getElementById)
        candidates= if by_id=document_object.getElementById(ids.first)
          [by_id]
        else
          []
        end
      elsif tags.size==1 && tags.first.is_a?(String)
        candidates=@container.dom_object.getElementsByTagName(tags.first).to_array
      elsif names.size==1 && names.first.is_a?(String) && @container.dom_object.respond_to?(:getElementsByName)
        candidates=@container.dom_object.getElementsByName(names.first).to_array
      elsif classNames.size==1 && classNames.first.is_a?(String) && @container.dom_object.respond_to?(:getElementsByClassName)
        candidates=@container.dom_object.getElementsByClassName(classNames.first).to_array
      else # would be nice to use getElementsByTagName for each tag name, but we can't because then we don't know the ordering for index
        candidates=@container.dom_object.getElementsByTagName('*').to_array
      end
      candidates
    end

    public
    # locates a javascript reference for this element
    def locate(options={})
      default_options={}
      if @browser && @updated_at && @browser.updated_at > @updated_at
        default_options[:relocate]=:recursive
      end
      options=default_options.merge(options)
      if options[:relocate]
        @element_object=nil
      end
      element_object_existed=!!@element_object
      @element_object||= begin
        case @how
        when :jssh_object, :dom_object
          raise if options[:relocate]
          @what
        when :jssh_name
          raise if options[:relocate]
          JsshObject.new(@what, jssh_socket)
        when :xpath
          by_xpath=element_object_by_xpath(@container.dom_object, @what)
          matched_by_xpath=nil
          Watir::Specifier.match_candidates(by_xpath ? [by_xpath] : [], self.class.specifiers) do |match|
            matched_by_xpath=match
          end
          matched_by_xpath
        when :attributes
          #if options[:relocate]==:recursive && !@container.is_a?(Browser) # don't try to locate a browser 
          #  raise unless @container
          #  @container.locate(options)
          #end
          if !@container
            raise
          end
          @container.locate(options)
          specified_attributes=@what
          specifiers=self.class.specifiers.map{|spec| spec.merge(specified_attributes)}
          
          matched_candidate=nil
          matched_count=0
          Watir::Specifier.match_candidates(container_candidates(specifiers), specifiers) do |match|
          matched_count+=1
            if !@index || @index==matched_count
              matched_candidate=match.store_rand_prefix("firewatir_elements")
              break
            end
          end
          matched_candidate
        else
          raise Watir::Exception::MissingWayOfFindingObjectException
        end
      end
      if !element_object_existed && @element_object
        @updated_at=Time.now
      end
      @element_object
    end
    def locate!(options={})
      locate(options) || raise(self.class==FFFrame ? Watir::Exception::UnknownFrameException : Watir::Exception::UnknownObjectException)
    end

    private
    #def self.def_wrap(ruby_method_name, ole_method_name = nil)
    #  ole_method_name = ruby_method_name unless ole_method_name
    #  define_method ruby_method_name do
    #    locate
    #    attr=dom_object.attr(ole_method_name)
    #    attr.type=='undefined' ? nil : dom_object.get(ole_method_name)
    #  end
    #end
  
    #def get_attribute_value(attribute_name)
    #  dom_object.getAttribute attribute_name
    #end
  
    public
    def currentStyle # currentStyle is IE; document.defaultView.getComputedStyle is mozilla. 
      document_object.defaultView.getComputedStyle(dom_object, nil)
    end
    
    #
    # Description:
    #   Returns an array of the properties of an element, in a format to be used by the to_s method.
    #   additional attributes are returned based on the supplied atributes hash.
    #   name, type, id, value and disabled attributes are common to all the elements.
    #   This method is used internally by to_s method.
    #
    # Output:
    #   Array with values of the following properties:
    #   name, type, id, value disabled and the supplied attribues list.
    #
    def string_creator(attributes = nil)
      n = []
      n << "name:".ljust(TO_S_SIZE) + get_attribute_value("name").inspect
      n << "type:".ljust(TO_S_SIZE) + get_attribute_value("type").inspect
      n << "id:".ljust(TO_S_SIZE) + get_attribute_value("id").inspect
      n << "value:".ljust(TO_S_SIZE) + get_attribute_value("value").inspect
      n << "disabled:".ljust(TO_S_SIZE) + get_attribute_value("disabled").inspect
      #n << "style:".ljust(TO_S_SIZE) + get_attribute_value("style")
      #n << "class:".ljust(TO_S_SIZE) + get_attribute_value("className")
    
      if(attributes != nil)
        attributes.each do |key,value|
          n << "#{key}:".ljust(TO_S_SIZE) + get_attribute_value(value).inspect
        end
      end
      return n
    end
  
    #
    # Description:
    #   Sets and clears the colored highlighting on the currently active element.
    #
    # Input:
    #   set_or_clear - this can have following two values
    #   :set - To set the color of the element.
    #   :clear - To clear the color of the element.
    #
    def highlight(set_or_clear)
      if set_or_clear == :set
        @original_color=dom_object.style.background
        dom_object.style.background=DEFAULT_HIGHLIGHT_COLOR
      elsif set_or_clear==:clear
        begin
          dom_object.style.background=@original_color
        ensure
          @original_color=nil
        end
      else
        raise ArgumentError, "argument must me :set or :clear; got #{set_or_clear.inspect}"
      end
    end
    protected :highlight
  
    public

    #
    #
    # Description:
    #   Matches the given text with the current text shown in the browser for that particular element.
    #
    # Input:
    #   target - Text to match. Can be a string or regex
    #
    # Output:
    #   Returns the index if the specified text was found.
    #   Returns matchdata object if the specified regexp was found.
    #
    def contains_text?(target)
      self_text=self.text
      if target.kind_of? Regexp
        !!self_text =~ target
      elsif target.kind_of? String
        self_text.include?(target)
      else
        raise TypeError, "Expected String or Regexp, got #{target.inspect} (#{target.class.name})"
      end
    end
    alias contains_text contains_text?
    


    def inspect
      '#<%s:0x%x dom_ref=%s how=%s what=%s>' % [self.class, hash*2, element_object ? element_object.ref : '', @how.inspect, @what.inspect]
    end

    #
    # Description:
    #   Returns array of elements that matches a given XPath query.
    #   Mozilla browser directly supports XPath query on its DOM. So no need to create the DOM tree as WATiR does for IE.
    #   Refer: https://developer.mozilla.org/en/DOM/document.evaluate
    #   Used internally by Firewatir use ff.elements_by_xpath instead.
    #
    # Input:
    #   xpath - The xpath expression or query.
    #
    # Output:
    #   Array of elements that matched the xpath expression provided as parameter.
    #
    def element_objects_by_xpath(container_object, xpath)
      elements=[]
      result=document_object.evaluate(xpath, container_object, nil, jssh_socket.Components.interfaces.nsIDOMXPathResult.ORDERED_NODE_ITERATOR_TYPE, nil)
      while element=result.iterateNext
        elements << element.store_rand_object_key(@browser_jssh_objects)
      end
      elements
    end

    #
    # Description:
    #   Returns first element found while traversing the DOM; that matches an given XPath query.
    #   Mozilla browser directly supports XPath query on its DOM. So no need to create the DOM tree as WATiR does for IE.
    #   Refer: http://developer.mozilla.org/en/docs/DOM:document.evaluate
    #   Used internally by Firewatir use ff.element_by_xpath instead.
    #
    # Input:
    #   xpath - The xpath expression or query.
    #
    # Output:
    #   First element in DOM that matched the XPath expression or query.
    #
    def element_object_by_xpath(container_object, xpath)
      document_object.evaluate(xpath, container_object, nil, jssh_socket.Components.interfaces.nsIDOMXPathResult.FIRST_ORDERED_NODE_TYPE, nil).singleNodeValue
    end

    #
    # Description:
    #   Returns the type of element. For e.g.: HTMLAnchorElement. used internally by Firewatir
    #
    # Output:
    #   Type of the element.
    #
    def element_type
      dom_object.object_type
    end
    #private :element_type

    def parent(options={})
      @parent=nil if options[:reload]
      @parent||=begin
        parentNode=element_object.parentNode
        if parentNode
          FFElement.factory(parentNode.store_rand_prefix('firewatir_elements'), extra)
        else
          nil
        end
      end
    end
    
    #
    # Description:
    #   Fires the provided event for an element and by default waits for the action to get completed.
    #
    # Input:
    #   event - Event to be fired like "onclick", "onchange" etc.
    #   wait - Whether to wait for the action to get completed or not. By default its true.
    #
    # TODO: Provide ability to specify event parameters like keycode for key events, and click screen
    #       coordinates for mouse events.
    def fire_event(event, wait = true)
      assert_exists
      event = event.to_s.downcase # in case event was given as a symbol

      event =~ /\Aon(.*)\z/i
      event = $1 if $1

      # check if we've got an old-school on-event
      #jssh_socket.send("typeof(#{element_object}.#{event});\n", 0)
      #is_defined = jssh_socket.read_socket

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
      event.get(*dom_event_init) # calls to the init*Event method
      element_object.dispatchEvent(event)

      #if(element_type == "HTMLSelectElement")
      #  dom_event_type = 'HTMLEvents'
      #  dom_event_init = "initEvent(\"#{event}\", true, true)"
      #end

      #jssh_command  = "var event = #{document_object.ref}.createEvent(\"#{dom_event_type}\"); "
      #jssh_command << "event.#{dom_event_init}; "
      #jssh_command << "#{element_object.ref}.dispatchEvent(event);"

      #puts "JSSH COMMAND:\n#{jssh_command}\n"
      #jssh_socket.send_and_read jssh_command
      wait() if wait

    end
    alias fireEvent fire_event

    #
    # Description:
    #   Returns the value of the specified attribute of an element.
    #
    #def attribute_value(attribute_name)
    #  #puts attribute_name
    #  assert_exists()
    #  return_value = get_attribute_value(attribute_name)
    #  return return_value
    #end

    #
    # Description:
    #   Checks if element exists or not. Raises UnknownObjectException if element doesn't exists.
    #
    def assert_exists
      unless exists?
        raise Exception::UnknownObjectException.new(Watir::Exception.message_for_unable_to_locate(@how, @what))
      end
    end

    #
    # Description:
    #   Checks if element is enabled or not. Raises ObjectDisabledException if object is disabled and
    #   you are trying to use the object.
    #
    def assert_enabled
      unless enabled?
        raise Exception::ObjectDisabledException, "object #{@how} and #{@what} is disabled"
      end
    end

    #
    # Description:
    #   First checks if element exists or not. Then checks if element is enabled or not.
    #
    # Output:
    #   Returns true if element exists and is enabled, else returns false.
    #
    def enabled?
      !disabled
    end

    # Returns whether the element is disabled
    def disabled
      assert_exists
      dom_object.respond_to?(:disabled) && dom_object.disabled
    end
    alias disabled? disabled
    
    #
    # Description:
    #   Checks element for display: none or visibility: hidden, these are
    #   the most common methods to hide an html element
  
    def visible? 
      assert_exists 
      currentStyle.visibility!='hidden' && currentStyle[:display]!='none' # note: don't use #display as it is defined on Object. http://www.ruby-doc.org/core/classes/Object.html#M000340
    end 

    #
    # Description:
    #   Checks if element exists or not. If element is not located yet then first locates the element.
    #
    # Output:
    #   True if element exists, false otherwise.
    #
    def exists?
      !!locate
    rescue UnknownFrameException
      false
    end
    alias exist? exists?

    #
    # Description:
    #   Returns the text of the element.
    #
    # Output:
    #   Text of the element.
    #
    def text
      dom_object.textContent
    end
    alias innerText text

    # Returns the name of the element (as defined in html)
    #def_wrap :name
    # Returns the id of the element
    #def_wrap :id
    # Returns the state of the element
    #def_wrap :checked
    # Returns the value of the element
    #def_wrap :value
    # Returns the title of the element
    #def_wrap :title
    # Returns the value of 'alt' attribute in case of Image element.
    #def_wrap :alt
    # Returns the value of 'href' attribute in case of Anchor element.
    #def_wrap :src
    # Returns the type of the element. Use in case of Input element only.
    #def_wrap :type
    # Returns the url the Anchor element points to.
    #def_wrap :href
    # Return the ID of the control that this label is associated with
    #def_wrap :for, :htmlFor
    # Returns the class name of the element
    #def_wrap :class_name, :className
    # Return the html of the object
    #def_wrap :html, :innerHTML
    # Return the action of form
    #def_wrap :action
    #def_wrap :style
    #def_wrap :scrollIntoView

    #
    # Description:
    #   Display basic details about the object. Sample output for a button is shown.
    #   Raises UnknownObjectException if the object is not found.
    #      name      b4
    #      type      button
    #      id         b5
    #      value      Disabled Button
    #      disabled   true
    #
    # Output:
    #   Array with value of properties shown above.
    #
#    def to_s(attributes=nil)
#      #puts "here in to_s"
#      #puts caller(0)
#      assert_exists
#      if(element_type == "HTMLTableCellElement")
#        return text()
#      else
#        result = string_creator(attributes).join("\n")
#        return result
#      end
#    end
    def to_s(*args)
      inspect
    end

    def internal_click(options={})
      options={:wait => true}.merge(options)
      assert_exists
      assert_enabled
      highlight(:set)
      case element_type
      when "HTMLAnchorElement", "HTMLImageElement"
        # Special check for link or anchor tag. Because click() doesn't work on links.
        # More info: http://www.w3.org/TR/DOM-Level-2-HTML/html.html#ID-48250443
        # https://bugzilla.mozilla.org/show_bug.cgi?id=148585

        event=document_object.createEvent('MouseEvents').store_rand_prefix('events')
        event.initMouseEvent('click',true,true,nil,1,0,0,0,0,false,false,false,false,0,nil)
        dom_object.dispatchEvent(event)
      else
        if dom_object.attr(:click).type=='undefined'
          fire_event('onclick')
        else
          if options[:wait]
            dom_object.click
          else
            #click_func=jssh_socket.object("(function(dom_object){return function(){dom_object.click()};})").pass(dom_object)
            click_func=dom_object.attr(:click)
            content_window_object.setTimeout(click_func, 0)
          end
        end
      end
      highlight(:clear)
      self.wait if options[:wait]
    end

    #
    # Description:
    #   Function to fire click event on elements.
    #
    def click
      internal_click :wait => true
    end
    
    def click_no_wait
      internal_click :wait => false
    end
  
    #
    # Description:
    #   Wait for the browser to get loaded, after the event is being fired.
    #
    def wait
      #ff = FireWatir::Firefox.new
      #ff.wait()
      #puts @container
      @container.wait()
    end

    #
    # Description:
    #   Function is used for click events that generates javascript pop up.
    #   Doesn't fire the click event immediately instead, it stores the state of the object. User then tells which button
    #   is to be clicked in case a javascript pop up comes after clicking the element. Depending upon the button to be clicked
    #   the functions 'alert' and 'confirm' are re-defined in JavaScript to return appropriate values either true or false. Then the
    #   re-defined functions are send to jssh which then fires the click event of the element using the state
    #   stored above. So the click event is fired in the second statement. Therefore, if you are using this function you
    #   need to call 'click_js_popup_button()' function in the next statement to actually trigger the click event.
    #
    #   Typical Usage:
    #       ff.button(:id, "button").click_no_wait()
    #       ff.click_js_popup_button("OK")
    #
    #def click_no_wait
    #    assert_exists
    #    assert_enabled
    #
    #    highlight(:set)
    #    @@current_js_object = Element.new("#{element_object}", @container)
    #end

    #
    # Description:
    #   Function to click specified button on the javascript pop up. Currently you can only click
    #   either OK or Cancel button.
    #   Functions alert and confirm are redefined so that it doesn't causes the JSSH to get blocked. Also this
    #   will make Firewatir cross platform.
    #
    # Input:
    #   button to be clicked
    #
    #def click_js_popup(button = "OK")
    #    jssh_command = "var win = browser.contentWindow;"
    #    if(button =~ /ok/i)
    #        jssh_command << "var popuptext = '';win.alert = function(param) {popuptext = param; return true; };
    #                         win.confirm = function(param) {popuptext = param; return true; };"
    #    elsif(button =~ /cancel/i)
    #        jssh_command << "var popuptext = '';win.alert = function(param) {popuptext = param; return false; };
    #                         win.confirm = function(param) {popuptext = param; return false; };"
    #    end
    #    jssh_command.gsub!(/\n/, "")
    #    jssh_socket.send("#{jssh_command}\n", 0)
    #    jssh_socket.read_socket
    #    click_js_popup_creator_button()
    #    #jssh_socket.send("popuptext_alert;\n", 0)
    #    #jssh_socket.read_socket
    #    jssh_socket.send("\n", 0)
    #    jssh_socket.read_socket
    #end

    #
    # Description:
    #   Clicks on button or link or any element that triggers a javascript pop up.
    #   Used internally by function click_js_popup.
    #
    #def click_js_popup_creator_button
    #    #puts @@current_js_object.element_name
    #    jssh_socket.send("#{@@current_js_object.element_name}\n;", 0)
    #    temp = jssh_socket.read_socket
    #    temp =~ /\[object\s(.*)\]/
    #    if $1
    #        type = $1
    #    else
    #        # This is done because in JSSh if you write element name of anchor type
    #        # then it displays the link to which it navigates instead of displaying
    #        # object type. So above regex match will return nil
    #        type = "HTMLAnchorElement"
    #    end
    #    #puts type
    #    case type
    #        when "HTMLAnchorElement", "HTMLImageElement"
    #            jssh_command = "var event = document.createEvent(\"MouseEvents\");"
    #            # Info about initMouseEvent at: http://www.xulplanet.com/references/objref/MouseEvent.html
    #            jssh_command << "event.initMouseEvent('click',true,true,null,1,0,0,0,0,false,false,false,false,0,null);"
    #            jssh_command << "#{@@current_js_object.element_name}.dispatchEvent(event);\n"
    #
    #            jssh_socket.send("#{jssh_command}", 0)
    #            jssh_socket.read_socket
    #        when "HTMLDivElement", "HTMLSpanElement"
    #             jssh_socket.send("typeof(#{element_object}.#{event.downcase});\n", 0)
    #             isDefined = jssh_socket.read_socket
    #             #puts "is method there : #{isDefined}"
    #             if(isDefined != "undefined")
    #                 if(element_type == "HTMLSelectElement")
    #                     jssh_command = "var event = document.createEvent(\"HTMLEvents\");
    #                                     event.initEvent(\"click\", true, true);
    #                                     #{element_object}.dispatchEvent(event);"
    #                     jssh_command.gsub!(/\n/, "")
    #                     jssh_socket.send("#{jssh_command}\n", 0)
    #                     jssh_socket.read_socket
    #                 else
    #                     jssh_socket.send("#{element_object}.#{event.downcase}();\n", 0)
    #                     jssh_socket.read_socket
    #                 end
    #             end
    #        else
    #            jssh_command = "#{@@current_js_object.element_name}.click();\n";
    #            jssh_socket.send("#{jssh_command}", 0)
    #            jssh_socket.read_socket
    #    end
    #    @@current_level = 0
    #    @@current_js_object = nil
    #end
    #private :click_js_popup_creator_button

    
    def invoke(js_method)
      dom_object.get(js_method)
    end
  
    def assign(property, value)
      locate
      dom_object.attr(property).assign(value)
    end
    
    def document_object
      @container.document_object
    end
    
    def content_window_object
      @container.content_window_object
    end
    def browser_window_object
      @container.browser_window_object
    end
    
  end # Element
end # FireWatir
