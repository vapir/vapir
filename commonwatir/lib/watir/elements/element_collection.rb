module Watir
  module ElementObjectCandidates
    private
    def assert_container
      unless @container
        raise Watir::Exception::MissingContainerException, "No container is defined for this #{self.class.inspect}"
      end
    end
    
    def assert_container_exists
      assert_container
      @container.locate!
    end

    # this is used by #locate in Element and by ElementCollection. 
    def element_object_candidates(specifiers)
      @container.assert_exists(:force => true) do
        case @extra[:candidates]
        when nil
          Watir::Specifier.specifier_candidates(@container, specifiers)
        when Symbol
          Watir::Element.object_collection_to_enumerable(@container.element_object.send(@extra[:candidates]))
        when Proc
          @extra[:candidates].call(@container)
        else
          raise Watir::Exception::MissingWayOfFindingObjectException, "Unknown method of specifying candidates: #{@extra[:candidates].inspect} (#{@extra[:candidates].class})"
        end
      end
    end
    def matched_candidates(specifiers, &block)
      Watir::Specifier.match_candidates(element_object_candidates(specifiers), specifiers, &block)
    end
  end

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
      #each_with_enumerable_index do |element, enumerable_index|
      #  yield element, enumerable_index+1
      #end
      # above method makes it use how=:element_object - since we're associating with index, going by how=:index seems more logical, hence below
      each_index do |i|
        yield at(i), i
      end
    end
    alias each_with_index each_with_element_index
    
    def [](index)
      at(index)
    end
    def at(index)
      @collection_class.new(:index, nil, @extra.merge(:index => index))
    end
    def first
      at(1)
    end
    def last
      specifiers=@collection_class.specifiers
      element=@collection_class.new(:custom, proc{true}, @extra.merge(:candidates => proc do |container|
        [Watir::Specifier.match_candidates(Watir::Specifier.specifier_candidates(container, specifiers), specifiers).to_a.last]
      end))
    end
    
    def find(&block)
      element=@collection_class.new(:custom, block, @extra.merge(:locate => false))
      element.exists? ? element : nil
    end
    alias detect find
    
    def inspect
      "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{map{|el|el.inspect}.join(', ')}>"
    end

    private
    include ElementObjectCandidates
    def candidates
      assert_container_exists
      matched_candidates(@collection_class.specifiers)
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
