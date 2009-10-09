require 'active_support/inflector'

module Watir
  class ElementCollection # TODO/FIX: move this somewhere more appropriate
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

    # methods with no index arg, just pass to the array 
    [:empty?, :size, :length, :first, :last, :include?].each do |method|
      define_method method do |*args|
        @array.send(method, *args)
      end
    end
    def ==(other_collection)
      other_collection.class==self.class && other_collection.to_a==@array
    end
  end
  module DomWrap
    # takes any number of arguments, where each argument is either a symbols or strings representing 
    # a method that is the same in ruby and on the dom, or a hash of key/value pairs where each
    # key is a ruby method name and value is a corresponding dom method_name. 
    #
    # see immediately following method definition for an example. 
    def dom_wrap(*args)
      args.each do |arg|
        hash=arg.is_a?(Hash) ? arg : arg.is_a?(Symbol) || arg.is_a?(String) ? {arg => arg} : raise("don't know what to do with arg #{arg.inspect} (#{arg.class})")
        hash.each_pair do |ruby_method_name, dom_method_name|
          define_method ruby_method_name do |*args|
            assert_exists
            if element_object.respond_to?(dom_method_name)
              element_object.method_missing(dom_method_name, *args)
              # note: using method_missing (not get) so that attribute= methods can be used 
            elsif args.length==0
              element_object.getAttribute(dom_method_name)
            else
              raise ArgumentError, "Arguments were given to #{ruby_method_name} but there is no function #{dom_method_name} to pass them to!"
            end
          end
        end
      end
    end
  end
  module ElementModule
    # set container methods on inherit
    def self.included(includer) # when this module gets included (by a Watir Element module)
      __orig_included_before_SetContainerMethodsOnInherit__=includer.respond_to?(:included) ? includer.method(:included) : nil
      (class << includer;self;end).send(:define_method, :included) do |subincluder| # make its .included method
          __orig_included_before_SetContainerMethodsOnInherit__.call(subincluder) if __orig_included_before_SetContainerMethodsOnInherit__

          container_modules=subincluder.included_modules.select do |mod| # get Container modules that the subincluder includes (ie, Watir::FFTextField includes the Watir::FFContainer Container module)
            mod.included_modules.include?(Watir::Container)
          end
  
          const_to_array=proc do |const_name| # take a constant name, and return an array 
            const_got=includer.const_defined?(const_name) ? includer.const_get(const_name) : []
            const_got.is_a?(Enumerable) ? const_got : [const_got]
          end
  
          container_modules.each do |container_module|
            const_to_array.call('ContainerSingleMethod').each do |container_single_method|
              # define both bang-methods (like #text_field!) and not (#text_field) with corresponding :locate option for element_by_howwhat
              [{:method_name => container_single_method, :locate => false}, {:method_name => container_single_method.to_s+'!', :locate => true}].each do |method_hash|
                unless container_module.method_defined?(method_hash[:method_name])
                  container_module.module_eval do
                    define_method(method_hash[:method_name]) do |how, *what_args| # can't take how, what as args because blocks don't do default values so it will want 2 args
                      what=what_args.shift # what is the first what_arg
                      other_attribute_keys=subincluder.const_defined?('ContainerMethodExtraArgs') ? subincluder::ContainerMethodExtraArgs : []
                      raise ArgumentError, "\##{method_hash[:method_name]} takes 1 to #{2+other_attribute_keys.length} arguments! Got #{([how, what]+what_args).map{|a|a.inspect}.join(', ')}}" if what_args.size>other_attribute_keys.length
                      if what_args.size == 0
                        other_attributes= nil
                      else
                        other_attributes={}
                        what_args.each_with_index do |arg, i|
                          other_attributes[other_attribute_keys[i]]=arg
                        end
                      end
                      #STDERR.puts([subincluder, how, what, {:locate => method_hash[:locate], :other_attributes => other_attributes}].inspect)
                      element_by_howwhat(subincluder, how, what, :locate => method_hash[:locate], :other_attributes => other_attributes)
                    end
                  end
                end
              end
            end
            const_to_array.call('ContainerMultipleMethod').each do |container_multiple_method|
              unless container_module.method_defined?(container_multiple_method)
                container_module.module_eval do
                  define_method(container_multiple_method) do
                    element_collection(subincluder)
                  end
                end
              end
            end
          end
        
        # copy constants (like Specifiers) onto classes when inherited
  # CopyConstants is here to set the constants of the Element modules below onto the actual classes
  # that instantiate per-browser (Watir::IETextField, Watir::FFTextField, etc) so that calling #const_defined?
  # on those returns true, and so that the constants defined here clobber any inherited stuff from superclasses
  # which is unwanted. 
        includer.constants.each do |const| # copy all of its constants onto wherever it was included
          subincluder.const_set(const, includer.const_get(const))
        end
      end
      
      includer.send(:extend, DomWrap)
    end
  end
  # this is to define common constants from the class name rather than repeating slight variations
  # on the class name for every class
  module ContainerMethodsFromName
    def self.included(includer)
      single_meth=includer.name.demodulize.underscore
      multiple_meth=includer.name.demodulize.underscore.pluralize
      raise "defining container methods #{single_meth}: single is the same as multiple! specify Container*Method constants manually." if single_meth==multiple_meth
      includer.const_set('ContainerSingleMethod', single_meth)
      includer.const_set('ContainerMultipleMethod', multiple_meth)
    end
  end

  module Element
    include ContainerMethodsFromName
    Specifiers=[{}] # one specifier with no criteria - note that an empty specifiers list
                     # would match no elements; a non-empty list with no criteria matches any
                     # element.
    include ElementModule
    
    dom_wrap :tagName, :id, :title, :tag_name => :tagName, :text => :textContent, :inner_html => :innerHTML, :html => :innerHTML
    dom_wrap :class_name => :className
    dom_wrap :scrollIntoView
    dom_wrap :get_attribute_value => :getAttribute, :attribute_value => :getAttribute
    
    # Flash the element the specified number of times.
    # Defaults to 10 flashes.
    def flash number=10
      assert_exists
      number.times do
        highlight(:set)
        sleep 0.05
        highlight(:clear)
        sleep 0.05
      end
      nil
    end
  end
end
