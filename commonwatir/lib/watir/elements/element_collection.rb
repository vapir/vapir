module Watir
  class ElementCollection
    include Enumerable
    def initialize(enumerable=nil)
      if enumerable && !enumerable.is_a?(Enumerable)
        raise ArgumentError, "Initialize giving an enumerable, not #{enumerable.inspect} (#{enumerable.class})"
      end
      @array=[]
      enumerable.each do |element|
        @array << element
      end
      @array.freeze
    end
    def to_a
      @array.dup # return unfrozen dup
    end
    
    def each
      @array.each do |element|
        yield element
      end
    end
    def each_index
      (1..size).each do |i|
        yield i
      end
    end
    
    def [](index)
      at(index)
    end
    def at(index)
      unless index.is_a?(Integer) && (1..size).include?(index)
        raise IndexError, "Expected an integer between 1 and #{size}"
      end
      array_index=index-1
      @array.at(array_index)
    end
    def index(obj)
      array_index=@array.index(obj)
      array_index && array_index+1
    end
    
    def inspect
      "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{@array.map{|el|el.inspect}.join(', ')}>"
    end

    # methods to just pass to the array 
    [:empty?, :size, :length, :first, :last, :include?].each do |method|
      define_method method do |*args|
        @array.send(method, *args)
      end
    end
    def ==(other_collection)
      other_collection.class==self.class && other_collection.to_a==@array
    end
  end
end
