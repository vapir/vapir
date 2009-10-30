require 'watir/specifier'
require 'watir/elements/element_collection'

module Watir
  module Container
    # returns an Element of the given class klass with the specified how & what, and
    # with self as its container. 
    # takes options:
    # - :locate => true/false, whether the element should locate itself (this will cause it 
    #    to raise an exception if it can't find itself). if :locate is false and no matching
    #    element exists, this returns nil. #todo: maybe this should return the not-found element
    #    anyway? on the idea that it could come into existence, as in watir/unittests/defer_test.rb
    # - :other_attributes => Hash, attributes other than the given how/what to look for. This is
    #    used by radio and checkbox to specify :value (the third argument). 
    # 
    # see also #extra_for_contained on inheriting classes (IEElement, FFElement) for what this passes to the created 
    # element, in terms of browser, container, other things each element uses. 
    def element_by_howwhat(klass, how, what, other={})
      other={:locate => false, :other_attributes => nil}.merge(other)
      how, what, index=*normalize_howwhat_index(how, what, klass.default_how)
      if other[:other_attributes]
        if how==:attributes
          what.merge!(other[:other_attributes])
        else
          raise ArgumentError, ":other_attributes option was given, but we are not locating by attributes. We are locating by how=#{how.inspect} what=#{what.inspect}. :other_attributes option was #{other[:other_attributes].inspect}"
        end
      end
      element=klass.new(how, what, extra_for_contained.merge(:index => index, :locate => other[:locate]))
      element.exists? ? element : nil
    end
    # returns an ElementCollection of Elements that are instances of the given class klass below
    # this container. 
    def element_collection(klass)
      elements=[]
      Watir::Specifier.match_candidates(Watir::Specifier.specifier_candidates(self, klass.specifiers), klass.specifiers) do |match|
        elements << klass.new(:element_object, match, extra_for_contained)
      end
      ElementCollection.new(elements)
    end
    
    # takes how and what in the form that users use, and translates it to a standard form 
    # where how is one of Watir::Specifier::HowList and what corresponds. 
    def normalize_howwhat_index(how, what, default_how=nil)
      case how
      when nil
        raise ArgumentError, "no how was given!"
      when Hash
        how=how.dup
        index=how.delete(:index)
        what==nil ? [:attributes, how, index] : raise(ArgumentError, "'how' was given as a Hash, so assumed to be the 'what' for :attributes, but 'what' was also given. how=#{how.inspect}, what=#{what.inspect}")
      when String, Symbol
        if Watir::Specifier::HowList.include?(how)
          [how, what, nil]
        else
          if what.nil?
            if default_how
              [:attributes, {default_how => how}, nil]
            else
              raise Watir::Exception::MissingWayOfFindingObjectException, "Cannot search using how=#{how.inspect} (#{how.class}), what=#{what.inspect} (#{what.class}), default_how=#{default_how.inspect} (#{default_how.class})"
            end
          elsif how==:index
            [:attributes, {}, what]
          else
            [:attributes, {how.to_sym => what}, nil]
          end
        end
      else
        raise ArgumentError, "Locating with how=#{how.inspect} is not recognized or supported. Also given what=#{what.inspect}"
      end
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
      elements=ElementCollection.new(element_objects.map{|el| base_element_class.factory(el)})
      elements.each do |element|
        write_to.write element.to_s+"\n"
        write_to.write "------------------------------------------\n"
      end
      return elements
    end
  end
end
