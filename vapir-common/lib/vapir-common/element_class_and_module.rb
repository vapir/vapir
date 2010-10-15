module Vapir
  # this module is for methods that should go on both common element modules (ie, TextField) as well
  # as browser-specific element classes (ie, Firefox::TextField). 
  module ElementClassAndModuleMethods
    # takes an element_object (JsshObject or WIN32OLE), and finds the most specific class 
    # that is < self whose specifiers match it. Returns an instance of that class using the given
    # element_object. 
    #
    # second argument, extra, is passed as the 'extra' argument to the Element constructor (see its documentation). 
    #
    # if you give a different how/what (third and fourth arguments, optional), then those are passed
    # to the Element constructor. 
    def factory(element_object, extra={}, how=nil, what=nil)
      curr_klass=self
      # since this gets included in the Element modules, too, check where we are 
      unless self.is_a?(Class) && self < Vapir::Element
        raise TypeError, "factory was called on #{self} (#{self.class}), which is not a Class that is < Element"
      end
      if how
        # use how and what as given
      elsif what
        raise ArgumentError, "'what' was given as #{what.inspect} (#{what.class}) but how was not given"
      else
        how=:element_object
        what=element_object
      end
      ObjectSpace.each_object(Class) do |klass|
        if klass < curr_klass
          Vapir::ElementObjectCandidates.match_candidates([element_object], klass.specifiers, klass.all_dom_attr_aliases) do |match|
            curr_klass=klass
            break
          end
        end
      end
      curr_klass.new(how, what, extra)
    end
    
    # takes any number of arguments, where each argument is either:
    # - a symbol or strings representing a method that is the same in ruby and on the dom
    # - or a hash of key/value pairs where each key is a dom attribute, and each value
    #   is a is a corresponding ruby method name or list of ruby method names.
    def dom_attr(*dom_attrs)
      dom_attrs.each do |arg|
        hash=arg.is_a?(Hash) ? arg : arg.is_a?(Symbol) || arg.is_a?(String) ? {arg => arg} : raise(ArgumentError, "don't know what to do with arg #{arg.inspect} (#{arg.class})")
        hash.each_pair do |dom_attr, ruby_method_names|
          ruby_method_names= ruby_method_names.is_a?(Array) ? ruby_method_names : [ruby_method_names]
          class_array_append 'dom_attrs', dom_attr
          ruby_method_names.each do |ruby_method_name|
            dom_attr_locate_alias(dom_attr, ruby_method_name)
            define_method ruby_method_name do
              method_from_element_object(dom_attr)
            end
          end
        end
      end
    end
    
    # creates aliases for locating by 
    def dom_attr_locate_alias(dom_attr, alias_name)
      dom_attr_aliases=class_hash_get('dom_attr_aliases')
      dom_attr_aliases[dom_attr] ||= Set.new
      dom_attr_aliases[dom_attr] << alias_name
    end
    
    # dom_function is about the same as dom_attr, but dom_attr doesn't take arguments. 
    # also, dom_function methods call #wait; dom_attr ones don't. 
    def dom_function(*dom_functions)
      dom_functions.each do |arg|
        hash=arg.is_a?(Hash) ? arg : arg.is_a?(Symbol) || arg.is_a?(String) ? {arg => arg} : raise(ArgumentError, "don't know what to do with arg #{arg.inspect} (#{arg.class})")
        hash.each_pair do |dom_function, ruby_method_names|
          ruby_method_names= ruby_method_names.is_a?(Array) ? ruby_method_names : [ruby_method_names]
          class_array_append 'dom_functions', dom_function
          ruby_method_names.each do |ruby_method_name|
            define_method ruby_method_name do |*args|
              result=method_from_element_object(dom_function, *args)
              wait
              result
            end
          end
        end
      end
    end
    
    # dom_setter takes arguments in the same format as dom_attr, but sends the given setter method (plus = sign)
    # to the element object. eg, 
    # module TextField
    #   dom_setter :value
    #   dom_setter :maxLength => :maxlength
    # end
    # the #value= method in ruby will send to #value= on the element object
    # the #maxlength= method in ruby will send to #maxLength= on the element object (note case difference). 
    def dom_setter(*dom_setters)
      dom_setters.each do |arg|
        hash=arg.is_a?(Hash) ? arg : arg.is_a?(Symbol) || arg.is_a?(String) ? {arg => arg} : raise(ArgumentError, "don't know what to do with arg #{arg.inspect} (#{arg.class})")
        hash.each_pair do |dom_setter, ruby_method_names|
          ruby_method_names= ruby_method_names.is_a?(Array) ? ruby_method_names : [ruby_method_names]
          class_array_append 'dom_setters', dom_setter
          ruby_method_names.each do |ruby_method_name|
            define_method(ruby_method_name.to_s+'=') do |value|
              element_object.send(dom_setter.to_s+'=', value)
            end
          end
        end
      end
    end
    
    # defines an element collection method on the given element - such as SelectList#options
    # or Table#rows. takes the name of the dom method that returns a collection
    # of element objects, a ruby method name, and an element class - actually this is
    # generally an Element module; this method goes ahead and finds the browser-specific
    # class that will actually be instantiated. the defined method returns an 
    # ElementCollection. 
    def element_collection(dom_attr, ruby_method_name, element_class)
      define_method ruby_method_name do
        assert_exists do
          ElementCollection.new(self, element_class_for(element_class), extra_for_contained.merge(:candidates => dom_attr))
        end
      end
    end

    # notes the given arguments to be inspected by #inspect and #to_s on each inheriting element. 
    # each argument may be a symbol, in which case the corresponding method is called on the element, or 
    # a hash, with the following keys:
    # - :label - how the the attribute is labeled in the string returned by #inspect or #to_s. 
    #            should be a string or symbol (but anything works; #to_s is called on the label). 
    # - :value - can be one of:
    #   - String starting with '@' - assumes this is an instance variable; gets the value of that instance variable
    #   - Symbol - assumes it is a method name, gives this to #send on the element. this is most commonly-used. 
    #   - Proc - calls the proc, giving this element as an argument. should return a string. #to_s is called on its return value.
    #   - anything else - just assumes that that is the value that is wanted in the string. 
    #     (see Element#attributes_for_stringifying)
    # - :if - if defined, should be a proc that returns false/nil if this should not be included in the 
    #   string, or anything else (that is, any value considered 'true') if it should. this element is passed
    #   as an argument to the proc. 
    def inspect_these(*inspect_these)
      inspect_these.each do |inspect_this|
        attribute_to_inspect=case inspect_this
        when Hash
          inspect_this
        when Symbol
          {:label => inspect_this, :value => inspect_this}
        else
          raise ArgumentError, "unrecognized thing to inspect: #{inspect_this} (#{inspect_this.class})"
        end
        class_array_append 'attributes_to_inspect', attribute_to_inspect
      end
    end
    alias inspect_this inspect_these
    # inspect_this_if(inspect_this, &block) is shorthand for 
    # inspect_this({:label => inspect_this, :value => inspect_this, :if => block)
    # if a block isn't given, the :if proc is the result of sending the inspect_this symbol to the element.
    # if inspect_this isn't a symbol, and no block is given, raises ArgumentError. 
    def inspect_this_if inspect_this, &block
      unless inspect_this.is_a?(Symbol) || block
        raise ArgumentError, "Either give a block, or specify a symbol as the first argument, instead of #{inspect_this.inspect} (#{inspect_this.class})"
      end
      to_inspect={:label => inspect_this, :value => inspect_this}
      to_inspect[:if]= block || proc {|element| element.send(inspect_this) }
      class_array_append 'attributes_to_inspect', to_inspect
    end
    
    def class_array_append(name, *elements)
=begin
      name='@@'+name.to_s
      unless self.class_variable_defined?(name)
        class_variable_set(name, [])
      end
      class_variable_get(name).push(*elements)
=end
      name=name.to_s.capitalize
      unless self.const_defined?(name)
        self.const_set(name, [])
      end
      self.const_get(name).push(*elements)
    end

    def class_array_get(name)
      # just return the value of appending nothing
      class_array_append(name) 
    end
    def class_hash_merge(name, hash)
      name=name.to_s.capitalize
      unless self.const_defined?(name)
        self.const_set(name, {})
      end
      self.const_get(name).merge!(hash)
    end
    def class_hash_get(name)
      class_hash_merge(name, {})
    end
    def set_or_get_class_var(class_var, *arg)
      if arg.length==0
        class_variable_defined?(class_var) ? class_variable_get(class_var) : nil
      elsif arg.length==1
        class_variable_set(class_var, arg.first)
      else
        raise ArgumentError, "#{arg.length} arguments given; expected one or two. arguments were #{arg.inspect}"
      end
    end
    def default_how(*arg)
      set_or_get_class_var('@@default_how', *arg)
    end
    def add_container_method_extra_args(*args)
      class_array_append('container_method_extra_args', *args)
    end
    def container_method_extra_args
      class_array_get('container_method_extra_args')
    end
    def specifiers
      class_array_get 'specifiers'
    end
    def container_single_methods
      class_array_get 'container_single_methods'
    end
    def container_collection_methods
      class_array_get 'container_collection_methods'
    end

    def parent_element_module(*arg)
      defined_parent=set_or_get_class_var('@@parent_element_module', *arg)
      defined_parent || (self==Watir::Element ? nil : Watir::Element)
    end
    def all_dom_attrs
      super_attrs= parent_element_module ? parent_element_module.all_dom_attrs : []
      super_attrs + class_array_get('dom_attrs')
    end
    def all_dom_attr_aliases
      aliases=class_hash_get('dom_attr_aliases').dup
      super_aliases= parent_element_module ? parent_element_module.all_dom_attr_aliases : {}
      super_aliases.each_pair do |attr, alias_list|
        aliases[attr] = (aliases[attr] || Set.new) + alias_list
      end
      aliases
    end
  end
  module ElementHelper
    def add_specifier(specifier)
      class_array_append 'specifiers', specifier
    end

    def container_single_method(*method_names)
      class_array_append 'container_single_methods', *method_names
      element_module=self
      method_names.each do |method_name|
        Vapir::Element.module_eval do
          # these methods (Element#parent_table, Element#parent_div, etc)
          # iterate through parent nodes looking for a parent of the specified
          # type. if no element of that type is found which is a parent of
          # self, returns nil. 
          define_method("parent_#{method_name}") do
            element_class=element_class_for(element_module)
            parentNode=element_object
            while true
              parentNode=parentNode.parentNode
              unless parentNode && parentNode != document_object # don't ascend up to the document. #TODO/Fix - for IE, comparing WIN32OLEs doesn't really work, this comparison is pointless. 
                return nil
              end
              matched=Vapir::ElementObjectCandidates.match_candidates([parentNode], element_class.specifiers, element_class.all_dom_attr_aliases)
              if matched.size > 0
                return element_class.new(:element_object, parentNode, extra_for_contained) # this is a little weird, passing extra_for_contained so that this is the container of its parent. 
              end
            end
          end
        end
        element_module = self
        # define both bang-methods (like #text_field!) and not (#text_field) with corresponding :locate option for element_by_howwhat
        [ {:method_name => method_name, :locate => true}, 
          {:method_name => method_name.to_s+'!', :locate => :assert},
          {:method_name => method_name.to_s+'?', :locate => :nil_unless_exists},
        ].each do |method_hash|
          Vapir::Container.module_eval do
            define_method(method_hash[:method_name]) do |how, *what_args| # can't take how, what as args because blocks don't do default values so it will want 2 args
              #locate! # make sure self is located before trying contained stuff 
              what=what_args.shift # what is the first what_arg
              other_attribute_keys=element_class_for(element_module).container_method_extra_args
              if what_args.size>other_attribute_keys.length
                raise ArgumentError, "\##{method_hash[:method_name]} takes 1 to #{2+other_attribute_keys.length} arguments! Got #{([how, what]+what_args).map{|a|a.inspect}.join(', ')}}"
              end
              if what_args.size == 0
                other_attributes= nil
              else
                other_attributes={}
                what_args.each_with_index do |arg, i|
                  other_attributes[other_attribute_keys[i]]=arg
                end
              end
              element_by_howwhat(element_class_for(element_module), how, what, :locate => method_hash[:locate], :other_attributes => other_attributes)
            end
          end
        end
      end
    end
    def container_collection_method(*method_names)
      class_array_append 'container_collection_methods', *method_names
      element_module=self
      method_names.each do |container_multiple_method|
        Vapir::Container.module_eval do
          # returns an ElementCollection of Elements that are instances of the including class 
          define_method(container_multiple_method) do |*args|
            case args.length
            when 0
              ElementCollection.new(self, element_class_for(element_module), extra_for_contained)
            when 1,2
              first, second=*args
              how, what, index= *normalize_how_what_index(first, second, element_class_for(element_module))
              if index
                raise ArgumentError, "Cannot specify index on collection method! specified index was #{index.inspect}"
              end
              ElementCollection.new(self, element_class_for(element_module), extra_for_contained, how, what)
            else
              raise ArgumentError, "wrong number of arguments - expected 0 arguments, 1 argument (hash of attributes), or 2 arguments ('how' and 'what'). got #{args.length}: #{args.inspect}"
            end
          end
          define_method('child_'+container_multiple_method.to_s) do
            ElementCollection.new(self, element_class_for(element_module), extra_for_contained.merge(:candidates => :childNodes))
          end
          define_method('show_'+container_multiple_method.to_s) do |*io|
            io=io.first||$stdout # io is a *array so that you don't have to give an arg (since procs don't do default args)
            element_collection=ElementCollection.new(self, element_class_for(element_module), extra_for_contained)
            io.write("There are #{element_collection.length} #{container_multiple_method}\n")
            element_collection.each do |element|
              io.write(element.to_s)
            end
          end
          alias_deprecated "show#{container_multiple_method.to_s.capitalize}", "show_"+container_multiple_method.to_s
        end
      end
    end

    include ElementClassAndModuleMethods
    
    def included(including_class)
      including_class.send :extend, ElementClassAndModuleMethods
      
      # copy constants (like Specifiers) onto classes when inherited
      # this is here to set the constants of the Element modules below onto the actual classes that instantiate 
      # per-browser (Vapir::IE::TextField, Vapir::Firefox::TextField, etc) so that calling #const_defined? on those 
      # returns true, and so that the constants defined here clobber any inherited stuff from superclasses
      # which is unwanted. 
      self.constants.each do |const| # copy all of its constants onto wherever it was included
        to_copy=self.const_get(const)
        to_copy=to_copy.dup if [Hash, Array, Set].any?{|klass| to_copy.is_a?(klass) }
        including_class.const_set(const, to_copy)
      end
      
      # now the constants (above) have switched away from constants to class variables, pretty much, so copy those.
      self.class_variables.each do |class_var|
        to_copy=class_variable_get(class_var)
        to_copy=to_copy.dup if [Hash, Array, Set].any?{|klass| to_copy.is_a?(klass) }
        including_class.send(:class_variable_set, class_var, to_copy)
      end
      
      class << including_class
        def attributes_to_inspect
          super_attrs=superclass.respond_to?(:attributes_to_inspect) ? superclass.attributes_to_inspect : []
          super_attrs + class_array_get('attributes_to_inspect')
        end
        def all_dom_attrs
          super_attrs=superclass.respond_to?(:all_dom_attrs) ? superclass.all_dom_attrs : []
          super_attrs + class_array_get('dom_attrs')
        end
        def all_dom_attr_aliases
          aliases=class_hash_get('dom_attr_aliases').dup
          super_aliases=superclass.respond_to?(:all_dom_attr_aliases) ? superclass.all_dom_attr_aliases : {}
          super_aliases.each_pair do |attr, alias_list|
            aliases[attr] = (aliases[attr] || Set.new) + alias_list
          end
          aliases
        end
      end
    end
    
  end
end
