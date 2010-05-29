require "vapir-common/specifier"

module Vapir
  class ElementCollection
    include Enumerable

    def initialize(container, collection_class, extra={})
      @container=container
      @collection_class=collection_class
      @extra=extra.merge(:container => container)
    end

    def each
      candidates.each do |candidate|
        yield @collection_class.new(:element_object, candidate, @extra)
      end
      self
    end
    def each_index
      (1..length).each do |i|
        yield i
      end
    end
    def length
      candidates.length
    end
    alias size length
    def empty?
      size==0
    end
    alias each_with_enumerable_index each_with_index # call ruby's 0-based indexing enumerable_index; call ours element_index
    def each_with_element_index
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
    def at(index)
      @collection_class.new(:index, nil, @extra.merge(:index => index))
    end
    def first
      at(:first)
    end
    def last
      at(:last)
    end
    
    def find(&block)
      element=@collection_class.new(:custom, block, @extra.merge(:locate => false))
      element.exists? ? element : nil
    end
    alias detect find
    def find!(&block)
      element=@collection_class.new(:custom, block, @extra.merge(:locate => :assert))
    end
    alias detect! find!
    
    def inspect
      "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{map{|el|el.inspect}.join(', ')}>"
    end

    private
    include ElementObjectCandidates
    def candidates
      assert_container_exists
      matched_candidates(@collection_class.specifiers, @collection_class.all_dom_attr_aliases)
    end
    public
    def pretty_print(pp)
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
