class Module
  def alias_deprecated(to, from)
    define_method to do |*args|
      if !respond_to?(:config) || config.warn_deprecated
        Kernel.warn_with_caller "DEPRECATION WARNING: #{self.class.name}\##{to} is deprecated. Please use #{self.class.name}\##{from}"
      end
      send(from, *args)
    end
  end
end

class String
  if method_defined?(:ord)
    alias vapir_ord ord
  else
    def vapir_ord
      unpack("U*")[0] # assume it's unicode 
    end
  end
end

unless :to_proc.respond_to?(:to_proc)
  class Symbol
    # Turns the symbol into a simple proc, which is especially useful for enumerations. Examples:
    #
    #   # The same as people.collect { |p| p.name }
    #   people.collect(&:name)
    #
    #   # The same as people.select { |p| p.manager? }.collect { |p| p.salary }
    #   people.select(&:manager?).collect(&:salary)
    def to_proc
      Proc.new { |*args| args[0].__send__(self, *args[1..-1]) }
    end
  end
end

class Hash
  # returns a hash whose keys are the intersection of the keys of this hash and the keys given 
  # as arguments to this function. values are the same as in this hash. 
  def select_keys(*keys)
    keys.inject(self.class.new) do |hash,key|
      self.key?(key) ? hash.merge(key => self[key]) : hash
    end
  end
end

module Kernel
  # this is the Y-combinator, which allows anonymous recursive functions. for a simple example, 
  # to define a recursive function to return the length of an array:
  #
  #  length = ycomb do |len|
  #    proc{|list| list == [] ? 0 : len.call(list[1..-1]) }
  #  end
  #
  # see https://secure.wikimedia.org/wikipedia/en/wiki/Fixed_point_combinator#Y_combinator
  # and chapter 9 of the little schemer, available as the sample chapter at http://www.ccs.neu.edu/home/matthias/BTLS/
  def ycomb
    proc{|f| f.call(f) }.call(proc{|f| yield proc{|*x| f.call(f).call(*x) } })
  end
  module_function :ycomb

  def warn_with_caller(message)
    Kernel.warn "#{message}\ncalled from: #{caller[1..-1].map{|c|"\n\t"+c}}"
  end
  module_function :warn_with_caller
end

require 'enumerator'
module Vapir
  Enumerator = Object.const_defined?('Enumerator') ? ::Enumerator : Enumerable::Enumerator
end

