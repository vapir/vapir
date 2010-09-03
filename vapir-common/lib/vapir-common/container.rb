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
      case other[:locate]
      when :assert, true, false
        element=klass.new(how, what, extra.merge(:locate => other[:locate]))
      when :nil_unless_exists
        element=klass.new(how, what, extra.merge(:locate => true))
        element.exists? ? element : nil
      else
        raise ArgumentError, "Unrecognized value given for :locate: #{other[:locate].inspect} (#{other[:locate].class})"
      end
    end
    
    # figure out how and what from the form(s) that users give to the container methods, and translate 
    # that to real how and what where 'how' is one of Vapir::ElementObjectCandidates::HowList and 
    # 'what' corresponds. 
    # this also determines index, when appropriate. 
    def normalize_how_what_index(first, second, klass)
      case first
      when nil
        raise Vapir::Exception::MissingWayOfFindingObjectException, "no first argument (how) was given!"
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
          elsif first==:index # this is different because the index number doesn't go in the 'what'
            how=first
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
    
    def default_extra_for_contained
      extra={:container => self}
      extra[:browser]= browser if respond_to?(:browser)
      extra[:page_container]= page_container if respond_to?(:page_container)
      extra
    end
    alias extra_for_contained default_extra_for_contained

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
        element=element.to_factory
        write_to.write element.to_s+"\n"
        write_to.write '-'*42+"\n"
        element
      end
    end
  end
end
