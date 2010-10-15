require "vapir-common/specifier"

module Vapir
  class ElementCollection
    include Enumerable

    def initialize(container, collection_class, extra={}, how=nil, what=nil)
      @container=container
      @collection_class=collection_class
      @extra=extra.merge(:container => container)
      @how=how
      @what=what
    end

    # yields each element in the collection to the given block 
    def each # :yields: element
      element_objects.each do |element_object|
        # todo: instantiated Element should use @how/@what? that would make #each the same as with #each_by_index 
        yield @collection_class.new(:element_object, element_object, @extra)
      end
      self
    end
    # yields each index from 1..length. 
    # 
    # note that if you are using this and accessing each subscript, it will be exponentially slower
    # than using #each or #each_with_index. 
    def each_index # :yields: index
      (1..length).each do |i|
        yield i
      end
    end
    # returns the number of elements in the collection 
    def length
      element_objects.length
    end
    alias size length
    # returns true if this collection contains no elements 
    def empty?
      size==0
    end
    alias each_with_enumerable_index each_with_index # call ruby's 0-based indexing enumerable_index; call ours element_index
    # yields each element and index in the collection 
    def each_with_element_index # :yields: element, index
      index=1
      element_objects.each do |element_object|
        yield @collection_class.new(@how, @what, @extra.merge(:index => index, :element_object => element_object, :locate => false)), index
        index+=1
      end
      self
    end
    alias each_with_index each_with_element_index
    
    # yields each element, specified by index (as opposed to by :element_object as #each yields)
    # same as #each_with_index, except it doesn't yield the index number. 
    def each_by_index # :yields: element
      each_with_element_index do |element, i|
        yield element
      end
    end
    # returns the element at the given index in the collection. indices start at 1. 
    def [](index)
      at(index)
    end
    # returns the element at the given index in the collection. indices start at 1. 
    def at(index)
      @collection_class.new(@how, @what, @extra.merge(:index => index))
    end
    # returns the first element in the collection. 
    def first
      at(:first)
    end
    # returns the last element. this will refer to the last element even if the number of elements changes, assuming relocation. 
    def last
      at(:last)
    end
    
    alias enumerable_select select
    def select(&block) # :yields: element
      # TODO: test
      if @how
        enumerable_select(&block)
      else
        ElementCollection.new(@container, @collection_class, @extra, :custom, block)
      end
    end
    
    alias enumerable_reject reject
    def reject(&block) # :yields: element
      # TODO: test 
      if @how
        enumerable_reject(&block)
      else
        ElementCollection.new(@container, @collection_class, @extra, :custom, proc{|el| !block.call(el) })
      end
    end
      
    alias enumerable_find find
    # returns an element for which the given block returns true (that is, not false or nil) when yielded that element 
    #
    # returns nil if no such element exists. 
    def find(&block) # :yields: element
      if @how # can't set how=:custom if @how is given to us, so fall back to Enumerable's #find method 
        enumerable_find(&block)
      else
        element=@collection_class.new(:custom, block, @extra.merge(:locate => false))
        element.exists? ? element : nil
      end
    end
    alias detect find
    # returns an element for which the given block returns true (that is, not false or nil) when yielded that element 
    #
    # raises UnknownObjectException if no such element exists. 
    def find!(&block)
      if @how # can't set how=:custom if @how is given to us, so fall back to Enumerable's #find method 
        enumerable_find(&block) || begin
          # TODO: DRY against Element#locate!
          klass=(@collection_class <= Frame) ? Vapir::Exception::UnknownFrameException : Vapir::Exception::UnknownObjectException
          message="Unable to locate #{@collection_class} using custom find block"
          message+="\non element collection #{self.inspect}"
          message+="\non container: #{@container.inspect}"
          raise(klass, message)
        end
      else
        element=@collection_class.new(:custom, block, @extra.merge(:locate => :assert))
      end
    end
    alias detect! find!
    
    private
    include ElementObjectCandidates
    def element_objects
      # TODO: this is heavily redundant with Element#locate; DRY 
      assert_container_exists
      case @how
      when nil
        matched_candidates(@collection_class.specifiers, @collection_class.all_dom_attr_aliases)
      when :xpath
        unless @container.respond_to?(:element_objects_by_xpath)
          raise Vapir::Exception::MissingWayOfFindingObjectException, "Locating by xpath is not supported on the container #{@container.inspect}"
        end
        by_xpath=@container.element_objects_by_xpath(@what)
        match_candidates(by_xpath, @collection_class.specifiers, @collection_class.all_dom_attr_aliases)
      when :attributes
        specified_attributes=@what
        specifiers=@collection_class.specifiers.map{|spec| spec.merge(specified_attributes)}
        
        matched_candidates(specifiers, @collection_class.all_dom_attr_aliases)
      when :custom
        matched_candidates(@collection_class.specifiers, @collection_class.all_dom_attr_aliases).select do |candidate|
          @what.call(@collection_class.new(:element_object, candidate, @extra))
        end
      else
        raise Vapir::Exception::MissingWayOfFindingObjectException, "Unknown 'how' given: #{@how.inspect} (#{@how.class}). 'what' was #{@what.inspect} (#{@what.class})"
      end
    end
    public
    def inspect # :nodoc: 
      # todo: include how/what if set 
      "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{map{|el|el.inspect}.join(', ')}>"
    end
    def pretty_print(pp) # :nodoc: 
      # todo: include how/what if set 
      pp.object_address_group(self) do
        pp.seplist(self, lambda { pp.text ',' }) do |element|
          pp.breakable ' '
          pp.group(0) do
            pp.pp element
          end
        end
      end
    end
  end
end
