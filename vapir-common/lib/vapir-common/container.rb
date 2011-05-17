require 'vapir-common/specifier'

module Vapir
  module Container
    module_function
    # returns an Element of the given class klass with the specified how & what, and
    # with self as its container. 
    # takes options:
    # - :locate => true, false, :assert, or :nil_unless_exists
    #    whether the element should locate itself. 
    #    - false -  will not attempt to locate element at all
    #    - true - will try to locate element but not complain if it can't
    #    - :assert - will raise UnkownObjectException if it can't locate. 
    #    - :nil_unless_exists - will attempt to locate the element, and only return it if 
    #      successful - returns nil otherwise. 
    # - :other_attributes => Hash, attributes other than the given how/what to look for. This is
    #    used by radio and checkbox to specify :value (the third argument). 
    #
    # the arguments 'first' and 'second' (they are the first and second arguments given
    # to the container method, not to this method) correspond to 'how' and 'what, after a fashion. 
    # 
    # see also #extra_for_contained on inheriting classes (IE::Element, Firefox::Element) for what this passes to the created 
    # element, in terms of browser, container, other things each element uses. 
    def element_by_howwhat(klass, first, second, other={})
      other={:other_attributes => nil}.merge(other)
      
      how, what, index= *normalize_how_what_index(first, second, klass)

      if other[:other_attributes]
        if how==:attributes
          what.merge!(other[:other_attributes])
        else
          raise ArgumentError, "other attributes were given, but we are not locating by attributes. We are locating by how=#{how.inspect} what=#{what.inspect}. other attributes given were #{other[:other_attributes].inspect}"
        end
      end
      extra=extra_for_contained.merge(:index => index)
      extra.merge!(other[:extra]) if other[:extra]
      if !other.key?(:locate)
        element=klass.new(how, what, extra)
      elsif other[:locate]==:nil_unless_exists
        element=klass.new(how, what, extra.merge(:locate => true))
        element.exists? ? element : nil
      else
        element=klass.new(how, what, extra.merge(:locate => other[:locate]))
      end
    end
    
    # figure out how and what from the form(s) that users give to the container methods, and translate 
    # that to real how and what where 'how' is one of Vapir::ElementObjectCandidates::HowList and 
    # 'what' corresponds. 
    # this also determines index, when appropriate. 
    def normalize_how_what_index(first, second, klass)
      case first
      when nil
        if second==nil
          how, what, index = nil, nil, nil
        else
          raise Vapir::Exception::MissingWayOfFindingObjectException, "first argument ('how') was nil but second argument ('what') was given as #{second.inspect}"
        end
      when Hash
        how=:attributes
        what=first.dup
        index=what.delete(:index)
        unless second==nil
          raise(ArgumentError, "first argument was given as a Hash, so assumed to be the 'what' for how=:attributes, but a second argument was also given. arguments were #{first.inspect}, #{second.inspect}")
        end
      when String, Symbol
        if Vapir::ElementObjectCandidates::HowList.include?(first)
          how=first
          what=second
          index=nil
        else
          if second.nil?
            if klass.default_how
              how=:attributes
              what={klass.default_how => first}
              index=nil
            else
              raise Vapir::Exception::MissingWayOfFindingObjectException, "Cannot search using arguments #{first.inspect} (#{first.class}) and #{second.inspect} (#{second.class})"
            end
          elsif first==:index # index isn't a real 'how' 
            how=nil
            what=nil
            index=second
          else
            if klass.all_dom_attr_aliases.any?{|(dom_attr, aliases)| aliases.include?(first.to_sym) || dom_attr==first.to_sym}
              how=:attributes
              what={first.to_sym => second}
              index=nil
            else
              raise Vapir::Exception::MissingWayOfFindingObjectException, "Cannot search for a #{klass} using the given argument: #{first.inspect} (other argument was #{second.inspect})"
            end
          end
        end
      else
        raise Vapir::Exception::MissingWayOfFindingObjectException, "Locating with the given arguments is not recognized or supported: #{first.inspect}, #{second.inspect}"
      end
      return [how, what, index]
    end

    public
    # asserts that this element exists - optionally, takes a block, and other calls to assert_exists
    # over the course of the block will not cause redundant assertions. 
    def assert_exists(options={})
      # yeah, this line is an unreadable mess, but I have to skip over it so many times debugging that it's worth just sticking it on one line 
      (was_asserting_exists=@asserting_exists); (locate! if !@asserting_exists || options[:force]); (@asserting_exists=true)
      begin; result=yield if block_given?
      ensure
        @asserting_exists=was_asserting_exists
      end
      result
    end
    public
    # catch exceptions that indicate some failure of something existing. 
    # 
    # takes an options hash:
    # - :handle indicates how the method should handle an encountered exception. value may be:
    #   - :ignore (default) - the exception is ignored and nil is returned. 
    #   - :raise - the exception is raised (same as if this method weren't used at all). 
    #   - :return - returns the exception which was raised. 
    #   - Proc, Method - the proc or method is called with the exception as an argument. 
    # - :assert_exists causes the method to check existence before yielding to the block. 
    #   value may be:
    #   - :force (default) - assert_exists(:force => true) is called so that existence is checked 
    #     even if we're inside an assert_exists block already. this is the most common case, since
    #     this method is generally used when the element may have recently stopped existing.
    #   - true - assert_exists is called (without the :force option)
    #   - false - assert_exists is not called. 
    #
    # If no exception was raised, then the result of the give block is returned. 
    #--
    # this may be overridden elsewhere to deal with any other stuff that indicates failure to exist, as it is
    # to catch WIN32OLERuntimeErrors for Vapir::IE. 
    def handling_existence_failure(options={})
      options=handle_options(options, {:assert_exists => :force}, [:handle])
      begin
        case options[:assert_exists]
        when true
          assert_exists
        when :force
          assert_exists(:force => true)
        when false, nil
        else
          raise ArgumentError, "option :assert_exists should be true, false, or :force; got #{options[:assert_exists].inspect}"
        end
        yield
      rescue Vapir::Exception::ExistenceFailureException
        handle_existence_failure($!, options.reject{|k,v| ![:handle].include?(k) })
      end
    end
    alias base_handling_existence_failure handling_existence_failure # :nodoc:
    private
    # handles any errors encountered by #handling_existence_failure (either the
    # common one or a browser-specific one) 
    def handle_existence_failure(error, options={})
      options=handle_options(options, :handle => :ignore)
      case options[:handle]
      when :raise
        raise error
      when :ignore
        nil
      when :return
        error
      when Proc, Method
        options[:handle].call(error)
      else
        raise ArgumentError, "Don't know what to do when told to handle by :handle => #{options[:handle].inspect}"
      end
    end
    public
    
    def base_extra_for_contained
      extra={:container => self}
      extra[:browser]= browser if respond_to?(:browser)
      extra[:page_container]= page_container if respond_to?(:page_container)
      extra
    end
    alias extra_for_contained base_extra_for_contained

    # returns an array of text nodes below this element in the DOM heirarchy which are visible - 
    # that is, their parent element is visible. 
    def visible_text_nodes
      assert_exists do
        visible_text_nodes_method.call(containing_object, document_object)
      end
    end
    # returns an visible text inside this element by concatenating text nodes below this element in the DOM heirarchy which are visible.
    def visible_text
      # TODO: needs tests 
      visible_text_nodes.join('')
    end

    # Checks if this container's text includes the given regexp or string. 
    # Returns true if the container's #text matches the given String or Regexp; otherwise false. 
    # 
    # *Deprecated* 
    # Instead use 
    #   Container#text.include? target 
    # or
    #   Container#text.match target
    def contains_text?(match)
      if match.kind_of? Regexp
        !!(text =~ match)
      elsif match.kind_of? String
        text.include?(match)
      else
        raise TypeError, "Expected String or Regexp, got #{match.inspect} (#{match.class.name})"
      end
    end
    alias contains_text contains_text?
    
    # this is defined on each class to reflect the browser's particular implementation. 
    def element_object_style(element_object, document_object)
      base_element_class.element_object_style(element_object, document_object)
    end
    private :element_object_style

    # for a common module, such as a TextField, returns an elements-specific class (such as
    # Firefox::TextField) that inherits from the base_element_class of self. That is, this returns
    # a sibling class, as it were, of whatever class inheriting from Element is instantiated.
    def element_class_for(common_module)
      element_class=nil
      ObjectSpace.each_object(Class) do |klass|
        if klass < common_module && klass <= base_element_class && (!element_class || element_class < klass)
          element_class= klass
        end
      end
      unless element_class
        raise RuntimeError, "No class found that inherits from both #{common_module} and #{base_element_class}"
      end
      element_class
    end
    
    private
    # returns a proc that takes a node and a document object, and returns 
    # true if the element's display property will allow it to be displayed; false if not. 
    def element_displayed_method
      @element_displayed_method ||= proc do |node, document_object|
        style= node.nodeType==1 ? base_element_class.element_object_style(node, document_object) : nil
        display = style && style.invoke('display')
        displayed = display ? display.strip.downcase!='none' : true
        displayed
      end
    end
    
    # returns a proc that takes a node and a document object, and returns 
    # the visibility of that node, obtained by ascending the dom until an explicit 
    # definition for visibility is found. 
    def element_real_visibility_method
      @element_real_visibility_method ||= proc do |element_to_check, document_object|
        real_visibility=nil
        while element_to_check && real_visibility==nil
          style = base_element_class.element_object_style(element_to_check, document_object)
          if style
            # only pay attention to the innermost definition that really defines visibility - one of 'hidden', 'collapse' (only for table elements), 
            # or 'visible'. ignore 'inherit'; keep looking upward. 
            # this makes it so that if we encounter an explicit 'visible', we don't pay attention to any 'hidden' further up. 
            # this style is inherited - may be pointless for firefox, but IE uses the 'inherited' value. not sure if/when ff does.
            if style.invoke('visibility')
              visibility=style.invoke('visibility').strip.downcase
              if ['hidden', 'collapse', 'visible'].include?(visibility)
                real_visibility=visibility
              end
            end
          end
          element_to_check=element_to_check.parentNode
        end
        real_visibility
      end
    end

    # returns a proc that takes a node and a document object, and returns 
    # an Array of strings, each of which is the data of a text node beneath the given node which 
    # is visible. 
    def visible_text_nodes_method
      @visible_text_nodes_method ||= proc do |element_object, document_object|
        recurse_text_nodes=ycomb do |recurse|
          proc do |node, parent_visibility|
            case node.nodeType
            when 1, 9 # TODO: name a constant ELEMENT_NODE, rather than magic number 
              style= node.nodeType==1 ? base_element_class.element_object_style(node, document_object) : nil
              our_visibility = style && (visibility=style.invoke('visibility'))
              unless our_visibility && ['hidden', 'collapse', 'visible'].include?(our_visibility=our_visibility.strip.downcase)
                our_visibility = parent_visibility
              end
              if !element_displayed_method.call(node, document_object)
                []
              else
                Vapir::Element.object_collection_to_enumerable(node.childNodes).inject([]) do |result, child_node|
                  result + recurse.call(child_node, our_visibility)
                end
              end
            when 3 # TODO: name a constant TEXT_NODE, rather than magic number 
              if parent_visibility && ['hidden','collapse'].include?(parent_visibility.downcase)
                []
              else
                [node.data]
              end
            else
              #Kernel.warn("ignoring node of type #{node.nodeType}")
              []
            end
          end
        end
  
        # determine the current visibility and display. 
        element_to_check=element_object
        while element_to_check
          if !element_displayed_method.call(element_to_check, document_object)
            # check for display property. this is not inherited, and a parent with display of 'none' overrides an immediate visibility='visible' 
            # if display is none, then this element is not visible, and thus has no visible text nodes underneath. 
            return []
          end
          element_to_check=element_to_check.parentNode
        end
        recurse_text_nodes.call(element_object, element_real_visibility_method.call(element_object, document_object))
      end
    end
    
    public
    # shows the available objects on the current container.
    # This is usually only used for debugging or writing new test scripts.
    # This is a nice feature to help find out what HTML objects are on a page
    # when developing a test case using Vapir.
    #
    # Typical Usage:
    #   browser.show_all_objects
    #   browser.div(:id, 'foo').show_all_objects
    #
    # API: no
    def show_all_objects(write_to=$stdout)
      # this used to reject tagNames 'br', 'hr', 'doctype', 'meta', and elements with no tagName
      elements.map do |element| 
        element=element.to_subtype
        write_to.write element.to_s+"\n"
        write_to.write '-'*42+"\n"
        element
      end
    end
    module WatirContainerConfigCompatibility
      def type_keys
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #type_keys is deprecated; please use the new config framework with config.type_keys"
        end
        config.type_keys
      end
      def type_keys=(arg) # deprecate
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #type_keys= is deprecated; please use the new config framework with config.type_keys="
        end
        config.type_keys= arg
      end
      def typingspeed
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #typingspeed is deprecated; please use the new config framework with config.typing_interval"
        end
        config.typing_interval
      end
      def typingspeed=(arg)
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #typingspeed= is deprecated; please use the new config framework with config.typing_interval="
        end
        config.typing_interval=arg
      end
    end
  end
end

