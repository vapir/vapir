require 'active_support/inflector'

module Watir
  module SetContainerMethodsOnInheritandCopyConstants
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
              unless container_module.method_defined?(container_single_method)
                container_module.module_eval do
                  define_method(container_single_method) do |how, *what_args| # can't take how, what as args because blocks don't do default values 
                    raise ArgumentError, "\##{container_single_method} takes one or two arguments!" if what_args.size>1
                  what=*what_args
                    element_by_howwhat(subincluder, how, what, :locate => false)
                  end
                  define_method(container_single_method.to_s+'!') do |how, *what_args| # can't take how, what as args because blocks don't do default values 
                    raise ArgumentError, "\##{container_single_method} takes one or two arguments!" if what_args.size>1
                  what=*what_args
                    element_by_howwhat(subincluder, how, what, :locate => true)
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
        
        includer.constants.each do |const| # copy all of its constants onto wherever it was included
          subincluder.const_set(const, includer.const_get(const))
        end
      end
    end
  end
  # CopyConstants is here to set the constants of the Element modules below onto the actual classes
  # that instantiate per-browser (Watir::IETextField, Watir::FFTextField, etc) so that calling #const_defined?
  # on those returns true, and so that the constants defined here clobber any inherited stuff from superclasses
  # which is unwanted. 
  module CopyConstants
    def self.included(includer) # when a module includes CopyConstants
      __orig_included_before_CopyConstants__=includer.respond_to?(:included) ? includer.method(:included) : nil
      (class << includer;self;end).send(:define_method, :included) do |subincluder| # make its .included method
        __orig_included_before_CopyConstants__.call(subincluder) if __orig_included_before_CopyConstants__
        includer.constants.each do |const| # copy all of its constants onto wherever it was included
          subincluder.const_set(const, includer.const_get(const))
        end
      end
    end
  end
  # and this one defines those constants from the class name 
  module ContainerMethodsFromName
    def self.included(includer)
      single_meth=includer.name.demodulize.underscore
      multiple_meth=includer.name.demodulize.underscore.pluralize
      includer.const_set('ContainerSingleMethod', single_meth)
      includer.const_set('ContainerMultipleMethod', multiple_meth)
    end
  end

  module Element
    include ContainerMethodsFromName
    Specifiers=[{}] # one specifier with no criteria - note that an empty specifiers list
                     # would match no elements; a non-empty list with no criteria matches any
                     # element.
    include SetContainerMethodsOnInheritandCopyConstants
    
    # takes any number of arguments, where each argument is either a symbols or strings representing 
    # a method that is the same in ruby and on the dom, or a hash of key/value pairs where each
    # key is a ruby method name and value is a corresponding dom method_name. 
    #
    # see immediately following method definition for an example. 
    def self.dom_wrap(*args)
      args.each do |arg|
        hash=arg.is_a?(Hash) ? arg : arg.is_a?(Symbol) || arg.is_a?(String) ? {arg => arg} : raise("don't know what to do with arg #{arg.inspect} (#{arg.class})")
        hash.each_pair do |ruby_method_name, dom_method_name|
          define_method ruby_method_name do |*args|
            assert_exists
            dom_object.get(dom_method_name, *args)
          end
        end
      end
    end
    dom_wrap :id
    
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
