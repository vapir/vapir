require 'watir/specifier'

module Watir
  module Container
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
    # that to real how and what where 'how' is one of Watir::ElementObjectCandidates::HowList and 
    # 'what' corresponds. 
    # this also determines index, when appropriate. 
    def normalize_how_what_index(first, second, klass)
      case first
      when nil
        raise Watir::Exception::MissingWayOfFindingObjectException, "no first argument (how) was given!"
      when Hash
        how=:attributes
        what=first.dup
        index=what.delete(:index)
        unless second==nil
          raise(ArgumentError, "first argument was given as a Hash, so assumed to be the 'what' for how=:attributes, but a second argument was also given. arguments were #{first.inspect}, #{second.inspect}")
        end
      when String, Symbol
        if Watir::ElementObjectCandidates::HowList.include?(first)
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
              raise Watir::Exception::MissingWayOfFindingObjectException, "Cannot search using arguments #{first.inspect} (#{first.class}) and #{second.inspect} (#{second.class})"
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
              raise Watir::Exception::MissingWayOfFindingObjectException, "Cannot search for a #{klass} using the given argument: #{first.inspect} (other argument was #{second.inspect})"
            end
          end
        end
      else
        raise Watir::Exception::MissingWayOfFindingObjectException, "Locating with the given arguments is not recognized or supported: #{first.inspect}, #{second.inspect}"
      end
      return [how, what, index]
    end

    # asserts that this element exists - optionally, takes a block, and other calls to assert_exists
    # over the course of the block will not cause redundant assertions. 
    def assert_exists(options={})
      was_asserting_exists=@asserting_exists
      if (!@asserting_exists || options[:force])
        locate!
      end
      @asserting_exists=true
      begin
        if block_given?
          result=yield
        end
      ensure
        @asserting_exists=was_asserting_exists
      end
      result
    end
    
    def default_extra_for_contained
      extra={:container => self}
      extra[:browser]= browser if respond_to?(:browser)
      extra[:page_container]= page_container if respond_to?(:page_container)
      extra
    end
    alias extra_for_contained default_extra_for_contained
    
    # shows the available objects on the current container.
    # This is usually only used for debugging or writing new test scripts.
    # This is a nice feature to help find out what HTML objects are on a page
    # when developing a test case using FireWatir.
    #
    # Typical Usage:
    #   browser.show_all_objects
    #   browser.div(:id, 'foo').show_all_objects
    def show_all_objects(write_to=$stdout)
      # this used to reject tagNames 'br', 'hr', 'doctype', 'meta', and elements with no tagName
      element_object_arr=containing_object.getElementsByTagName('*')
      if Object.const_defined?('JsshObject') && element_object_arr.is_a?(JsshObject)
        element_objects=element_object_arr.to_array
      elsif Object.const_defined?('WIN32OLE') && element_object_arr.is_a?(WIN32OLE)
        element_objects=[]
        element_object_arr.each do |el|
          element_objects << el
        end
      else
        raise RuntimeError, "unknown element object list #{element_object_arr.inspect} (#{element_object_arr.class})"
      end
      elements=element_objects.map{|el| base_element_class.factory(el, extra_for_contained)}
      elements.each do |element|
        write_to.write element.to_s+"\n"
        write_to.write "------------------------------------------\n"
      end
      return elements
    end
  end
end
