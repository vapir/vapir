require "vapir-common/specifier"

module Vapir
  class ElementCollection
    include Enumerable

    def initialize(container, collection_class, extra={})
      @container=container
      @collection_class=collection_class
      @extra=extra.merge(:container => container)
    end

    # yields each element in the collection to the given block 
    def each # :yields: element
      candidates.each do |candidate|
        yield @collection_class.new(:element_object, candidate, @extra)
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
      candidates.length
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
      candidates.each do |candidate|
        yield @collection_class.new(:index, nil, @extra.merge(:index => index, :element_object => candidate)), index
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
      @collection_class.new(:index, nil, @extra.merge(:index => index))
    end
    # returns the first element in the collection. 
    def first
      at(:first)
    end
    # returns the last element. this will refer to the last element even if the number of elements changes, assuming relocation. 
    def last
      at(:last)
    end
    # returns an element for which the given block returns true (that is, not false or nil) when yielded that element 
    #
    # returns nil if no such element exists. 
    def find(&block) # :yields: element
      element=@collection_class.new(:custom, block, @extra.merge(:locate => false))
      element.exists? ? element : nil
    end
    alias detect find
    # returns an element for which the given block returns true (that is, not false or nil) when yielded that element 
    #
    # raises UnknownObjectException if no such element exists. 
    def find!(&block)
      element=@collection_class.new(:custom, block, @extra.merge(:locate => :assert))
    end
    alias detect! find!
    
    def inspect # :nodoc: 
      "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{map{|el|el.inspect}.join(', ')}>"
    end

    private
    include ElementObjectCandidates
    def candidates
      assert_container_exists
      matched_candidates(@collection_class.specifiers, @collection_class.all_dom_attr_aliases)
    end
    public
    def pretty_print(pp) # :nodoc: 
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
