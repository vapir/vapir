module Watir
  # Base class for html elements.
  # This is not a class that users would normally access.
  class IEElement # Wrapper
    include Element
    include Watir::Exception
    include IEContainer # presumes @container is defined
    attr_accessor :container
    
    # number of spaces that separate the property from the value in the to_s method
    TO_S_SIZE = 14
    
    def initialize(how, what, extra={})
      @how, @what=how, what
      raise ArgumentError, "how (first argument) should be a Symbol, not: #{how.inspect}" unless how.is_a?(Symbol)
      @extra=extra
      @index=extra[:index] && Integer(extra[:index])
      @container=extra[:container]
      @browser=extra[:browser]
      locate! unless extra.key?(:locate) && !extra[:locate]
    end
    
    # Return the ole object, allowing any methods of the DOM that Watir doesn't support to be used.
    #def ole_object # BUG: should use an attribute reader and rename the instance variable
    #  return @o
    #end

    class << self
      def factory(element_object, extra={})
        curr_klass=self
        ObjectSpace.each_object(Class) do |klass|
          if klass < curr_klass
            Watir::Specifier.match_candidates([element_object], klass.specifiers) do |match|
              curr_klass=klass
            end
          end
        end
        curr_klass.new(:element_object, element_object, extra)
      end
    end
    
    alias ole_object element_object 
    alias containing_object element_object
    #def ole_object=(o)
    #  @element_object = o
    #end
    
    extend DomWrap
    dom_wrap :currentStyle
    
    def inspect
      '#<%s:0x%x located=%s how=%s what=%s>' % [self.class, hash*2, !!ole_object, @how.inspect, @what.inspect]
    end
    
    private
    def base_element_klass
      IEElement
    end
    def browser_klass
      IE
    end
    private
#    def self.def_wrap(ruby_method_name, ole_method_name=nil)
#      ole_method_name = ruby_method_name unless ole_method_name
#      class_eval "def #{ruby_method_name}
#                          assert_exists
#                          ole_object.invoke('#{ole_method_name}')
#                        end"
#    end
#    def self.def_wrap_guard(method_name)
#      class_eval "def #{method_name}
#                          assert_exists
#                          begin
#                            ole_object.invoke('#{method_name}')
#                          rescue
#                            ''
#                          end
#                        end"
#    end



    public
    def assert_exists
      locate if respond_to?(:locate)
      unless ole_object
        raise UnknownObjectException.new(
          Watir::Exception.message_for_unable_to_locate(@how, @what))
      end
    end
    def assert_enabled
      unless enabled?
        raise ObjectDisabledException, "object #{@how} and #{@what} is disabled"
      end
    end
    
#    # return the name of the element (as defined in html)
#    def_wrap_guard :name
#    # return the id of the element
#    def_wrap_guard :id
#    # return whether the element is disabled
#    def_wrap :disabled
#    alias disabled? disabled
#    # return the value of the element
#    def_wrap_guard :value
#    # return the title of the element
#    def_wrap_guard :title
#    # return the style of the element
#    def_wrap_guard :style
#    
#    def_wrap_guard :alt
#    def_wrap_guard :src
#    
#    # return the type of the element
#    def_wrap_guard :type # input elements only
#    # return the url the link points to
#    def_wrap :href # link only
#    # return the ID of the control that this label is associated with
#    #def_wrap :for, :htmlFor # label only
#    # return the class name of the element
#    # raise an ObjectNotFound exception if the object cannot be found
#    def_wrap :class_name, :className
#    # return the unique COM number for the element
#    def_wrap :unique_number, :uniqueNumber
#    # Return the outer html of the object - see http://msdn.microsoft.com/workshop/author/dhtml/reference/properties/outerhtml.asp?frame=true
#    def_wrap :html, :outerHTML

    # return the text before the element
    def before_text # label only
      assert_exists
      begin
        ole_object.getAdjacentText("afterEnd").strip
      rescue
                ''
      end
    end
    
    # return the text after the element
    def after_text # label only
      assert_exists
      begin
        ole_object.getAdjacentText("beforeBegin").strip
      rescue
                ''
      end
    end
    
    # Return the innerText of the object
    # Raise an ObjectNotFound exception if the object cannot be found
    def text
      assert_exists
      return ole_object.innerText.strip
    end
    
    def ole_inner_elements
      assert_exists
      return ole_object.all
    end
    private :ole_inner_elements
    
    def document
      assert_exists
      return ole_object
    end

    # Return the element immediately containing self. 
    def parent
      raise NotImplementedError
      assert_exists
      result = IEElement.new(ole_object.parentelement)
      result.set_container self
      result
    end
    
    include Comparable
    def <=> other
      assert_exists
      other.assert_exists
      ole_object.sourceindex <=> other.ole_object.sourceindex
    end

    # Return true if self is contained earlier in the html than other. 
    alias :before? :< 
    # Return true if self is contained later in the html than other. 
    alias :after? :> 
      
    def typingspeed
      @container.typingspeed
    end
		def type_keys
			return @container.type_keys if @type_keys.nil? 
			@type_keys
		end
    def activeObjectHighLightColor
      @container.activeObjectHighLightColor
    end
    
    # Return an array with many of the properties, in a format to be used by the to_s method
#    def string_creator
#      n = []
##      n <<   "type:".ljust(TO_S_SIZE) + self.type.to_s
#      n <<   "id:".ljust(TO_S_SIZE) +         self.id.to_s
##      n <<   "name:".ljust(TO_S_SIZE) +       self.name.to_s
##      n <<   "value:".ljust(TO_S_SIZE) +      self.value.to_s
#      n <<   "disabled:".ljust(TO_S_SIZE) +   self.disabled.to_s
#      return n
#    end
#    private :string_creator
#    
#    # Display basic details about the object. Sample output for a button is shown.
#    # Raises UnknownObjectException if the object is not found.
#    #      name      b4
#    #      type      button
#    #      id         b5
#    #      value      Disabled Button
#    #      disabled   true
#    def to_s
#      assert_exists
#      return string_creator.join("\n")
#    end
    
    # This method is responsible for setting and clearing the colored highlighting on the currently active element.
    # use :set   to set the highlight
    #   :clear  to clear the highlight
    # TODO: Make this two methods: set_highlight & clear_highlight
    # TODO: Remove begin/rescue blocks
    def highlight(set_or_clear)
      if set_or_clear == :set
        begin
          @original_color ||= style.backgroundColor
          style.backgroundColor = @container.activeObjectHighLightColor
        rescue
          @original_color = nil
        end
      else # BUG: assumes is :clear, but could actually be anything
        begin
          style.backgroundColor = @original_color unless @original_color == nil
        rescue
          # we could be here for a number of reasons...
          # e.g. page may have reloaded and the reference is no longer valid
        ensure
          @original_color = nil
        end
      end
    end
    private :highlight
    
    # takes a block. sets highlight on this element; calls the block; clears the highlight.
    # the clear is in an ensure block so that you can call return from the given block. 
    # doesn't actually perform the highlighting if argument do_highlight is false. 
    def with_highlight(do_highlight=true)
      highlight(:set) if do_highlight
      begin
        yield
      ensure
        highlight(:clear) if do_highlight
      end
    end
    
    #   This method clicks the active element.
    #   raises: UnknownObjectException  if the object is not found
    #   ObjectDisabledException if the object is currently disabled
    def click
      click!
      @container.wait
    end
    
    def click_no_wait
      assert_enabled
      highlight(:set)
      unique_number=element_object.uniqueNumber
      #Thread.new { ole_object.click } # that doesn't work.
      browser.document.parentWindow.setTimeout("
        (function(tagName, uniqueNumber)
        { var candidate_elements=document.getElementsByTagName(tagName);
          for(var i=0;i<candidate_elements.length;++i)
          { if(candidate_elements[i].uniqueNumber==uniqueNumber)
            { candidate_elements[i].click();
            }
          }
        })(#{self.tagName.to_json}, #{element_object.uniqueNumber.to_json})
      ", 0)
      highlight(:clear)
    end

    def click!
      assert_enabled
      
      highlight(:set)
      ole_object.click
      highlight(:clear)
    end
    
    # Executes a user defined "fireEvent" for objects with JavaScript events tied to them such as DHTML menus.
    #   usage: allows a generic way to fire javascript events on page objects such as "onMouseOver", "onClick", etc.
    #   raises: UnknownObjectException  if the object is not found
    #           ObjectDisabledException if the object is currently disabled
    def fire_event(event, options={})
      options={:highlight => true}.merge(options)
      with_highlight(options[:highlight]) do
        ole_object.fireEvent(event.to_s)
        wait
      end
    end
    # Executes a user defined "fireEvent" for objects with JavaScript events tied to them such as DHTML menus.
    #   usage: allows a generic way to fire javascript events on page objects such as "onMouseOver", "onClick", etc.
    #   raises: UnknownObjectException  if the object is not found
    #           ObjectDisabledException if the object is currently disabled
    def fire_event_no_wait(event, options)
      assert_enabled
      options={:highlight => true}.merge(options)
      with_highlight(options[:highlight]) do
        unique_number=element_object.uniqueNumber
        #Thread.new { ole_object.click } # that doesn't work.
        browser.document.parentWindow.setTimeout("
          (function(tagName, uniqueNumber, event)
          { var candidate_elements=document.getElementsByTagName(tagName);
            for(var i=0;i<candidate_elements.length;++i)
            { if(candidate_elements[i].uniqueNumber==uniqueNumber)
               { candidate_elements[i].fireEvent(event);
              }
            }
          })(#{self.tagName.to_json}, #{element_object.uniqueNumber.to_json}, #{event.to_s.to_json})
        ", 0)
      end
    end
    
    # This method sets focus on the active element.
    #   raises: UnknownObjectException  if the object is not found
    #           ObjectDisabledException if the object is currently disabled
    def focus
      assert_enabled
      ole_object.focus
    end
    
    # Returns true if the element is enabled, false if it isn't.
    #   raises: UnknownObjectException  if the object is not found
    def enabled?
      !disabled
    end

    # Returns whether the element is disabled
    def disabled
      assert_exists
      element_object.respond_to?(:disabled) && element_object.disabled
    end
    alias disabled? disabled
    # If any parent element isn't visible then we cannot write to the
    # element. The only realiable way to determine this is to iterate
    # up the DOM element tree checking every element to make sure it's
    # visible.
    def visible?
      # Now iterate up the DOM element tree and return false if any
      # parent element isn't visible or is disabled.
      assert_exists
      object = @element_object
      while object
        begin
          if object.currentstyle.invoke('visibility') =~ /^hidden$/i
            return false
          end
          if object.currentstyle.invoke('display') =~ /^none$/i
            return false
          end
          if object.invoke('isDisabled')
            return false
          end
        rescue WIN32OLERuntimeError
        end
        object = object.parentElement
      end
      true
    end
    
    # Get attribute value for any attribute of the element.
    # Returns null if attribute doesn't exist.
    def attribute_value(attribute_name)
      assert_exists
      return ole_object.getAttribute(attribute_name)
    end
    
  end
  
  class ElementMapper # Still to be used
    include IEContainer
    
    def initialize wrapper_class, container, how, what
      @wrapper_class = wrapper_class
      set_container
      @how = how
      @what = what
    end
    
    def method_missing method, *args
      locate
      @wrapper_class.new(@element_object).send(method, *args)
    end
  end
end  
