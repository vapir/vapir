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
    # see also #extra_for_contained on inheriting classes (IEElement, FFElement) for what this passes to the created 
    # element, in terms of browser, container, other things each element uses. 
    def element_by_howwhat(klass, how, what, other={})
      other={:other_attributes => nil}.merge(other)
      how, what, index=*normalize_howwhat_index(how, what, klass.default_how)
      if other[:other_attributes]
        if how==:attributes
          what.merge!(other[:other_attributes])
        else
          raise ArgumentError, ":other_attributes option was given, but we are not locating by attributes. We are locating by how=#{how.inspect} what=#{what.inspect}. :other_attributes option was #{other[:other_attributes].inspect}"
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
    
    # takes how and what in the form that users use, and translates it to a standard form 
    # where how is one of Watir::ElementObjectCandidates::HowList and what corresponds. 
    def normalize_howwhat_index(how, what, default_how=nil)
      case how
      when nil
        raise Watir::Exception::MissingWayOfFindingObjectException, "no how was given!"
      when Hash
        how=how.dup
        index=how.delete(:index)
        what==nil ? [:attributes, how, index] : raise(ArgumentError, "first argument was given as a Hash, so assumed to be the 'what' for how=:attributes, but 'what' was also given. how=#{how.inspect}, what=#{what.inspect}")
      when String, Symbol
        if Watir::ElementObjectCandidates::HowList.include?(how)
          [how, what, nil]
        else
          if what.nil?
            if default_how
              [:attributes, {default_how => how}, nil]
            else
              raise Watir::Exception::MissingWayOfFindingObjectException, "Cannot search using how=#{how.inspect} (#{how.class}), what=#{what.inspect} (#{what.class}), default_how=#{default_how.inspect} (#{default_how.class})"
            end
          elsif how==:index # this is different because the index number doesn't go in the 'what'
            [:index, nil, what]
          else
            [:attributes, {how.to_sym => what}, nil]
          end
        end
      else
        raise Watir::Exception::MissingWayOfFindingObjectException, "Locating with how=#{how.inspect} is not recognized or supported. Also given what=#{what.inspect}"
      end
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
