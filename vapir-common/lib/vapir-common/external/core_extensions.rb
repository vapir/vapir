class Module
  def alias_deprecated(to, from)
    define_method to do |*args|
      Kernel.warn_with_caller "DEPRECATION WARNING: #{self.class.name}\##{to} is deprecated. Please use #{self.class.name}\##{from}"
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

class Symbol
  def to_proc
    proc{|__x__| __x__.send(self)}
  end
end

module Kernel
  # this is the Y-combinator, which allows anonymous recursive functions. for a simple example, 
  # to define a recursive function to return the length of an array:
  #
  # length = ycomb do |len|
  #   proc{|list| list == [] ? 0 : len.call(list[1..-1]) }
  # end
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
