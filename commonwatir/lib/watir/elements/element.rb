require 'watir/elements/element_collection'
require 'set'
require 'matrix'

class Module
  def alias_deprecated(to, from)
    define_method to do |*args|
      Kernel.warn "DEPRECATION WARNING: #{self.class.name}\##{to} is deprecated. Please use #{self.class.name}\##{from}\n(called from #{caller.map{|c|"\n"+c}})"
      send(from, *args)
    end
  end
end
module Watir
  # this module is for methods that should go on both common element modules (ie, TextField) as well
  # as browser-specific element classes (ie, FFTextField). 
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
      unless self.is_a?(Class) && self < Watir::Element
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
          Watir::ElementObjectCandidates.match_candidates([element_object], klass.specifiers, klass.all_dom_attr_aliases) do |match|
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
  end
  module ElementHelper
    def add_specifier(specifier)
      class_array_append 'specifiers', specifier
    end

    def container_single_method(*method_names)
      class_array_append 'container_single_methods', *method_names
    end
    def container_collection_method(*method_names)
      class_array_append 'container_collection_methods', *method_names
    end

    include ElementClassAndModuleMethods
    
    def included(including_class)
      including_class.send :extend, ElementClassAndModuleMethods
      
      # get Container modules that the including_class includes (ie, Watir::FFTextField includes the Watir::FFContainer Container module)
      container_modules=including_class.included_modules.select do |mod|
        mod.included_modules.include?(Watir::Container)
      end
  
      container_modules.each do |container_module|
        class_array_get('container_single_methods').each do |container_single_method|
          # define both bang-methods (like #text_field!) and not (#text_field) with corresponding :locate option for element_by_howwhat
          [ {:method_name => container_single_method, :locate => true}, 
            {:method_name => container_single_method.to_s+'!', :locate => :assert},
            {:method_name => container_single_method.to_s+'?', :locate => :nil_unless_exists},
          ].each do |method_hash|
            unless container_module.method_defined?(method_hash[:method_name])
              container_module.module_eval do
                define_method(method_hash[:method_name]) do |how, *what_args| # can't take how, what as args because blocks don't do default values so it will want 2 args
                  #locate! # make sure self is located before trying contained stuff 
                  what=what_args.shift # what is the first what_arg
                  other_attribute_keys=including_class.container_method_extra_args
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
                  element_by_howwhat(including_class, how, what, :locate => method_hash[:locate], :other_attributes => other_attributes)
                end
              end
            end
          end
        end
        class_array_get('container_collection_methods').each do |container_multiple_method|
          container_module.module_eval do
            # returns an ElementCollection of Elements that are instances of the including class 
            define_method(container_multiple_method) do
              ElementCollection.new(self, including_class, extra_for_contained)
            end
          end
          container_module.module_eval do
            define_method('child_'+container_multiple_method.to_s) do
              ElementCollection.new(self, including_class, extra_for_contained.merge(:candidates => :childNodes))
            end
            define_method('show_'+container_multiple_method.to_s) do |*io|
              io=io.first||$stdout # io is a *array so that you don't have to give an arg (since procs don't do default args)
              element_collection=ElementCollection.new(self, including_class, extra_for_contained)
              io.write("There are #{element_collection.length} #{container_multiple_method}\n")
              element_collection.each do |element|
                io.write(element.to_s)
              end
            end
            alias_deprecated "show#{container_multiple_method.to_s.capitalize}", "show_"+container_multiple_method.to_s
          end
        end
      end

      # copy constants (like Specifiers) onto classes when inherited
      # this is here to set the constants of the Element modules below onto the actual classes that instantiate 
      # per-browser (Watir::IETextField, Watir::FFTextField, etc) so that calling #const_defined? on those 
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

  # this is included by every Element. it relies on the including class implementing a 
  # #element_object method 
  # some stuff assumes the element has a defined @container. 
  module Element
    extend ElementHelper
    add_specifier({}) # one specifier with no criteria - note that having no specifiers 
                      # would match no elements; having a specifier with no criteria matches any
                      # element.
    container_single_method :element
    container_collection_method :elements
    
    private
    # invokes the given method on the element_object, passing it the given args. 
    # if the element_object doesn't respond to the method name:
    # - if you don't give it any arguments, returns element_object.getAttributeNode(dom_method_name).value
    # - if you give it any arguments, raises ArgumentError, as you can't pass more arguments to getAttributeNode.
    #
    # it may support setter methods (that is, method_from_element_object('value=', 'foo')), but this has 
    # caused issues in the past - WIN32OLE complaining about doing stuff with a terminated object, and then
    # when garbage collection gets called, ruby terminating abnormally when garbage-collecting an 
    # unrecognized type. so, not so much recommended. 
    def method_from_element_object(dom_method_name, *args)
      assert_exists do
        if Object.const_defined?('WIN32OLE') && element_object.is_a?(WIN32OLE)
          # avoid respond_to? on WIN32OLE because it's slow. just call the method and rescue if it fails. 
          # the else block works fine for win32ole, but it's slower, so optimizing for IE here. 
          got_attribute=false
          attribute=nil
          begin
            attribute=element_object.method_missing(dom_method_name)
            got_attribute=true
          rescue WIN32OLERuntimeError
          end
          if !got_attribute
            if args.length==0
              begin
                attribute=element_object.getAttributeNode(dom_method_name.to_s).value
                got_attribute=true
              rescue WIN32OLERuntimeError
              end
            else
              raise ArgumentError, "Arguments were given to #{ruby_method_name} but there is no function #{dom_method_name} to pass them to!"
            end
          end
          attribute
        else
          if element_object.object_respond_to?(dom_method_name)
            element_object.method_missing(dom_method_name, *args)
            # note: using method_missing (not invoke) so that attribute= methods can be used. 
            # but that is problematic. see documentation above. 
          elsif args.length==0
            if element_object.object_respond_to?(:getAttributeNode)
              element_object.getAttributeNode(dom_method_name.to_s).value
            else
              nil
            end
          else
            raise ArgumentError, "Arguments were given to #{ruby_method_name} but there is no function #{dom_method_name} to pass them to!"
          end
        end
      end
    end
    public
    
    dom_attr :id
    inspect_this :how
    inspect_this_if(:what) do |element|
      ![:element_object, :index].include?(element.how) # if how==:element_object, don't show the element object in inspect. if how==:index, what is nil. 
    end
    inspect_this_if(:index) # uses the default 'if'; shows index if it's not nil 
    inspect_these :tag_name, :id

    dom_attr :name # this isn't really valid on elements but is used so much that we define it here. (it may be repeated on elements where it is actually is valid)

    dom_attr :title, :tagName => [:tagName, :tag_name], :innerHTML => [:innerHTML, :inner_html], :className => [:className, :class_name]
    dom_attr_locate_alias :className, :class # this isn't defined as a dom_attr because we don't want to clobber ruby's #class method 
    dom_attr :style
    dom_function :scrollIntoView => [:scrollIntoView, :scroll_into_view]

    # Get attribute value for any attribute of the element.
    # Returns null if attribute doesn't exist.
    dom_function :getAttribute => [:get_attribute_value, :attribute_value]

    # #text is defined on browser-specific Element classes 
    alias_deprecated :innerText, :text
    alias_deprecated :textContent, :text
    alias_deprecated :fireEvent, :fire_event
    
    attr_reader :how
    attr_reader :what
    attr_reader :index
    
    # returns whether the specified index for this element is equivalent to finding the first element 
    def index_is_first
      [nil, :first, 1].include?(index)
    end
    
    def html
      Kernel.warn "#html is deprecated, please use #outer_html or #inner_html. #html currently returns #outer_html (note that it previously returned inner_html on firefox)\n(called from #{caller.map{|c|"\n"+c}})"
      outer_html
    end

    include ElementObjectCandidates
    
    public
    
    # the class-specific Elements may implement their own #initialize, but should call to this
    # after they've done their stuff
    def default_initialize(how, what, extra={})
      @how, @what=how, what
      raise ArgumentError, "how (first argument) should be a Symbol, not: #{how.inspect}" unless how.is_a?(Symbol)
      @extra=extra
      @index=begin
        valid_symbols=[:first, :last]
        if valid_symbols.include?(@extra[:index]) || @extra[:index].nil? || (@extra[:index].is_a?(Integer) && @extra[:index] > 0)
          @extra[:index]
        elsif valid_symbols.map{|sym| sym.to_s}.include?(@extra[:index])
          @extra[:index].to_sym
        elsif @extra[:index] =~ /\A\d+\z/
          Integer(@extra[:index])
        else
          raise ArgumentError, "expected extra[:index] to be a positive integer, a string that looks like a positive integer, :first, or :last. received #{@extra[:index]} (#{@extra[:index].class})"
        end
      end
      @container=extra[:container]
      @browser=extra[:browser]
      extra[:locate]=true unless @extra.key?(:locate) # set default 
      case extra[:locate]
      when :assert
        locate!
      when true
        locate
      when false
      else
        raise ArgumentError, "Unrecognized value given for extra[:locate]: #{extra[:locate].inspect} (#{extra[:locate].class})"
      end
    end
    
    # alias it in case class-specific ones don't need to override
    alias initialize default_initialize
    
    # locates the element object for this element 
    # 
    # takes options hash. currently the only option is
    # - :relocate => nil, :recursive, true, false 
    #   - nil or not set (default): this Element is only relocated if the browser is updated (in firefox) or the WIN32OLE stops existing (IE). 
    #   - :recursive: this element and its containers are relocated, recursively up to the containing browser. 
    #   - false: no relocating is done even if the browser is updated or the element_object stops existing. 
    #   - true: this Element is relocated. the container is relocated only if the browser is updated or the element_object stops existing. 
    def locate(options={})
      if options[:relocate]==nil && @element_object # don't override if it is set to false; only if it's nil, and don't set :relocate there's no @element_object (that's an initial locate, not a relocate) 
        if @browser && @updated_at && @browser.respond_to?(:updated_at) && @browser.updated_at > @updated_at # TODO: implement this for IE; only exists for Firefox now. 
          options[:relocate]=:recursive
        elsif !element_object_exists?
          options[:relocate]=true
        end
      end
      container_locate_options={}
      if options[:relocate]==:recursive
        container_locate_options[:relocate]= options[:relocate]
      end
      if options[:relocate]
        @element_object=nil
      end
      element_object_existed=!!@element_object
      @element_object||= begin
        case @how
        when :element_object
          @element_object=@what # this is needed for checking its existence 
          if options[:relocate] && !element_object_exists?
            raise Watir::Exception::UnableToRelocateException, "This #{self.class.name} was specified using #{how.inspect} and cannot be relocated."
          end
          @what
        when :xpath
          assert_container
          @container.locate!(container_locate_options)
          unless @container.respond_to?(:element_object_by_xpath)
            raise Watir::Exception::MissingWayOfFindingObjectException, "Locating by xpath is not supported on the container #{@container.inspect}"
          end
          # todo/fix: implement index for this, using element_objects_by_xpath ? 
          unless index_is_first
            raise NotImplementedError, "Specifying an index is not supported for locating by xpath"
          end
          by_xpath=@container.element_object_by_xpath(@what)
          match_candidates(by_xpath ? [by_xpath] : [], self.class.specifiers, self.class.all_dom_attr_aliases).first
        when :label
          unless document_object
            raise "No document object found for this #{self.inspect} - needed to search by id for label from #{@container.inspect}"
          end
          unless what.is_a?(Label)
            raise "how=:label specified on this #{self.class}, but 'what' is not a Label! what=#{what.inspect} (#{what.class})"
          end
          what.locate!(container_locate_options) # the what Label is functionally synonymous with the @container. actually it is currently always the same as the @container. 
          by_label=document_object.getElementById(@container.for)
          match_candidates(by_label ? [by_label] : [], self.class.specifiers, self.class.all_dom_attr_aliases).first
        when :attributes
          assert_container
          @container.locate!(container_locate_options)
          specified_attributes=@what
          specifiers=self.class.specifiers.map{|spec| spec.merge(specified_attributes)}
          
          matched_candidate=nil
          matched_count=0
          matched_candidates(specifiers, self.class.all_dom_attr_aliases) do |match|
            matched_count+=1
            if @index==matched_count || index_is_first || @index==:last
              matched_candidate=match
              break unless @index==:last
            end
          end
          matched_candidate
        when :index
          # TODO/FIX: DRY; basically repeats how=:attributes 
          unless @what.nil?
            raise ArgumentError, "'what' was specified, but when 'how'=:index, no 'what' is used (just extra[:index])"
          end
          unless @index
            raise ArgumentError, "'how' was given as :index but no index was given"
          end
          matched_candidate=nil
          matched_count=0
          matched_candidates(self.class.specifiers, self.class.all_dom_attr_aliases) do |match|
            matched_count+=1
            if @index==matched_count || index_is_first || @index==:last
              matched_candidate=match
              break unless @index==:last
            end
          end
          matched_candidate
        when :custom
          # this allows a proc to be given as 'what', which is called yielding candidates, each being 
          # an instanted Element of this class. this might seem a bit odd - instantiating a bunch 
          # of elements in order to figure out which element_object to use in locating this one. 
          # the purpose is so that this Element can be relocated if we lose the element_object. 
          # the Elements that are yielded are instantiated by :element object which cannot be 
          # relocated. 
          #
          # the alternative to this would be for the calling code to loop over the element collection
          # for this class on the container - that is, instead of:
          #   found_div=frame.divs.detect{|div| weird_criteria_for(div) }
          # which can't be relocated - since element collections use :element object - you'd do
          #   found_div=frame.div(:custom, proc{|div| weird_criteria_for(div) })
          # this way, found_div can be relocated. yay! 
          # 
          # the proc should return true (that is, not false or nil) when it likes the given Element - 
          # when it matches what it expects of this Element. 
          by_custom=nil
          matched_candidates(self.class.specifiers, self.class.all_dom_attr_aliases) do |match|
            if what.call(self.class.new(:element_object, match, @extra))
              by_custom=match
              break
            end
          end
          by_custom
        else
          raise Watir::Exception::MissingWayOfFindingObjectException, "Unknown 'how' given: #{@how.inspect} (#{@how.class}). 'what' was #{@what.inspect} (#{@what.class})"
        end
      end
      if !element_object_existed && @element_object
        @updated_at=Time.now
      end
      @element_object
    end
    def locate!(options={})
      locate(options) || begin
        klass=self.is_a?(Frame) ? Watir::Exception::UnknownFrameException : Watir::Exception::UnknownObjectException
        message="Unable to locate #{self.class}, using #{@how}"+(@what ? ": "+@what.inspect : '')+(@index ? ", index #{@index}" : "")
        message+="\non container: #{@container.inspect}" if @container
        raise(klass, message)
      end
    end
    
    public
    # Returns whether this element actually exists.
    def exists?
      begin
        !!locate
      rescue Watir::Exception::UnknownObjectException, Exception::NoMatchingWindowFoundException # if the window itself is gone, certainly we don't exist. 
        false
      end
    end
    alias :exist? :exists?
    
    # returns an Element that represents the same object as self, but is an instance of the 
    # most-specific class < self.class that can represent that object. 
    #
    # For example, if we have a table, get its first element, and call #to_factory on it:
    #
    # a_table=browser.tables.first
    # => #<Watir::IETable:0x071bc70c how=:index index=:first tagName="TABLE">
    # a_element=a_table.elements.first
    # => #<Watir::IEElement:0x071b856c how=:index index=:first tagName="TBODY" id="">
    # a_element.to_factory
    # => #<Watir::IETableBody:0x071af78c how=:index index=:first tagName="TBODY" id="">
    #
    # we get back a Watir::TableBody. 
    def to_factory
      self.class.factory(element_object, @extra, @how, @what)
    end

    # takes a block. sets highlight on this element; calls the block; clears the highlight.
    # the clear is in an ensure block so that you can call return from the given block. 
    # doesn't actually perform the highlighting if argument do_highlight is false. 
    #
    # also, you can nest these safely; it checks if you're already highlighting before trying
    # to set and subsequently clear the highlight. 
    #
    # the block is called within an assert_exists block, so for methods that highlight, the
    # assert_exists can generally be omitted from there. 
    def with_highlight(options={})
      highlight_option_keys=[:color]
      #options=handle_options(options, {:highlight => true}, highlight_option_keys)
      options={:highlight => true}.merge(options)
      highlight_options=options.reject{|(k,v)| !highlight_option_keys.include?(k) }
      assert_exists do
        was_highlighting=@highlighting
        if (!@highlighting && options[:highlight])
          set_highlight(highlight_options)
        end
        @highlighting=true
        begin
          result=yield
        ensure
          @highlighting=was_highlighting
          if !@highlighting && options[:highlight] && exists? # if we stopped existing during the highlight, don't try to clear. 
            if Object.const_defined?('WIN32OLE') # if WIN32OLE exists, calling clear_highlight may raise WIN32OLERuntimeError, even though we just checked existence. 
              exception_to_rescue=WIN32OLERuntimeError
            else # otherwise, make a dummy class, inheriting from Exception that won't ever be instantiated to be rescued. 
              exception_to_rescue=(@@dummy_exception ||= Class.new(::Exception))
            end
            begin
              clear_highlight(highlight_options)
            rescue exception_to_rescue
              # apparently despite checking existence above, sometimes the element object actually disappears between checking its existence 
              # and clear_highlight using it, raising WIN32OLERuntimeError. 
              # don't actually do anything in the rescue block here. 
            end
          end
        end
        result
      end
    end
    
    private
    # The default color for highlighting objects as they are accessed.
    DEFAULT_HIGHLIGHT_COLOR = "yellow"

    # Sets or clears the colored highlighting on the currently active element.
    # set_or_clear - should be 
    # :set - To set highlight
    # :clear - To restore the element to its original color
    #
    # todo: is this used anymore? I think it's all with_highlight. 
    def highlight(set_or_clear)
      if set_or_clear == :set
        set_highlight
      elsif set_or_clear==:clear
        clear_highlight
      else
        raise ArgumentError, "argument must be :set or :clear; got #{set_or_clear.inspect}"
      end
    end

    def set_highlight_color(options={})
      #options=handle_options(options, :color => DEFAULT_HIGHLIGHT_COLOR)
      options={:color => DEFAULT_HIGHLIGHT_COLOR}.merge(options)
      assert_exists do
        @original_color=element_object.style.backgroundColor
        element_object.style.backgroundColor=options[:color]
      end
    end
    def clear_highlight_color(options={})
      #options=handle_options(options, {}) # no options yet
      begin
        element_object.style.backgroundColor=@original_color
      ensure
        @original_color=nil
      end
    end
    # Highlights the image by adding a border 
    def set_highlight_border(options={})
      #options=handle_options(options, {}) # no options yet
      assert_exists do
        @original_border= element_object.border.to_i
        element_object.border= @original_border+1
      end
    end
    # restores the image to its original border 
    # TODO: and border color 
    def clear_highlight_border(options={})
      #options=handle_options(options, {}) # no options yet
      assert_exists do
        begin
          element_object.border = @original_border
        ensure
          @original_border = nil
        end
      end
    end
    alias set_highlight set_highlight_color
    alias clear_highlight clear_highlight_color

    public
    # Flash the element the specified number of times.
    # Defaults to 10 flashes.
    def flash(options={})
      if options.is_a?(Fixnum)
        options={:count => options}
        Kernel.warn "DEPRECATION WARNING: #{self.class.name}\#flash takes an options hash - passing a number is deprecated. Please use #{self.class.name}\#flash(:count => #{options[:count]})\n(called from #{caller.map{|c|"\n"+c}})"
      end
      options={:count => 10, :sleep => 0.05}.merge(options)
      #options=handle_options(options, {:count => 10, :sleep => 0.05}, [:color])
      assert_exists do
        options[:count].times do
          with_highlight(options) do
            sleep options[:sleep]
          end
          sleep options[:sleep]
        end
      end
      nil
    end

    # Return the element immediately containing this element. 
    # returns nil if there is no parent, or if the parent is the document. 
    #
    # this is cached; call parent(:reload => true) if you wish to uncache it. 
    def parent(options={})
      @parent=nil if options[:reload]
      @parent||=begin
        parentNode=element_object.parentNode
        if parentNode && parentNode != document_object # don't ascend up to the document. #TODO/Fix - for IE, comparing WIN32OLEs doesn't really work, this comparison is pointless. 
          base_element_class.factory(parentNode, extra_for_contained) # this is a little weird, passing extra_for_contained so that this is the container of its parent. 
        else
          nil
        end
      end
    end
    
    # Checks this element and its parents for display: none or visibility: hidden, these are 
    # the most common methods to hide an html element. Returns false if this seems to be hidden
    # or a parent is hidden. 
    def visible? 
      assert_exists do
        element_to_check=element_object
        #nsIDOMDocument=jssh_socket.Components.interfaces.nsIDOMDocument
        really_visible=nil
        while element_to_check #&& !element_to_check.instanceof(nsIDOMDocument)
          if (style=element_object_style(element_to_check, document_object))
            # only pay attention to the innermost definition that really defines visibility - one of 'hidden', 'collapse' (only for table elements), 
            # or 'visible'. ignore 'inherit'; keep looking upward. 
            # this makes it so that if we encounter an explicit 'visible', we don't pay attention to any 'hidden' further up. 
            # this style is inherited - may be pointless for firefox, but IE uses the 'inherited' value. not sure if/when ff does.
            if really_visible==nil && (visibility=style.invoke('visibility'))
              visibility=visibility.strip.downcase
              if visibility=='hidden' || visibility=='collapse'
                really_visible=false
                return false # don't need to continue knowing it's not visible. 
              elsif visibility=='visible'
                really_visible=true # we don't return true yet because a parent with display of 'none' can override 
              end
            end
            # check for display property. this is not inherited, and a parent with display of 'none' overrides an immediate visibility='visible' 
            display=style.invoke('display')
            if display && display.strip.downcase=='none'
              return false  
            end
          end
          element_to_check=element_to_check.parentNode
        end
      end
      return true
    end
    private
    # this is defined on each class to reflect the browser's particular implementation. 
    def element_object_style(element_object, document_object)
      self.class.element_object_style(element_object, document_object)
    end
    
    public
    # returns a Vector with two elements, the x,y 
    # coordinates of this element (its top left point)
    # from the top left edge of the window
    def document_offset
      xy=Vector[0,0]
      el=element_object
      begin
        xy+=Vector[el.offsetLeft, el.offsetTop]
        el=el.offsetParent
      end while el
      xy
    end
    
    # returns a two-element Vector containing the offset of this element on the client area. 
    # see also #client_center
    def client_offset
      document_offset-scroll_offset
    end

    # returns a two-element Vector with the position of the center of this element
    # on the client area. 
    # intended to be used with mouse events' clientX and clientY. 
    # https://developer.mozilla.org/en/DOM/event.clientX
    # https://developer.mozilla.org/en/DOM/event.clientY
    def client_center
      client_offset+dimensions.map{|dim| dim/2}
    end

    # returns a two-element Vector containing the current scroll offset of this element relative
    # to any scrolling parents. 
    # this is basically stolen from prototype - see http://www.prototypejs.org/api/element/cumulativescrolloffset
    def scroll_offset
      xy=Vector[0,0]
      el=element_object
      begin
        if el.respond_to?(:scrollLeft)
          xy+=Vector[el.scrollLeft, el.scrollTop]
        end
        el=el.parentNode
      end while el
      xy
    end

    # returns a two-element Vector containing the position of this element on the screen.
    # see also #screen_center
    # not yet implemented. 
    def screen_offset
      raise NotImplementedError
    end
    
    # returns a two-element Vector containing the current position of the center of
    # this element on the screen. 
    # intended to be used with mouse events' screenX and screenY. 
    # https://developer.mozilla.org/en/DOM/event.screenX
    # https://developer.mozilla.org/en/DOM/event.screenY
    #
    # not yet implemented.
    def screen_center
      screen_offset+dimensions.map{|dim| dim/2}
    end

    # returns a two-element Vector with the width and height of this element. 
    def dimensions
      Vector[element_object.offsetWidth, element_object.offsetHeight]
    end
    # returns a two-element Vector with the position of the center of this element
    # on the document. 
    def document_center
      document_offset+dimensions.map{|dim| dim/2}
    end

    # accesses the object representing this Element in the DOM. 
    def element_object
      assert_exists
      @element_object
    end
    def container
      assert_container
      @container
    end
    
    def browser
      assert_container
      @container.browser
    end
    def document_object
      assert_container
      @container.document_object
    end
    def content_window_object
      assert_container
      @container.content_window_object
    end
    def browser_window_object
      assert_container
      @container.browser_window_object
    end
    
    def attributes_for_stringifying
      attributes_to_inspect=self.class.attributes_to_inspect
      unless exists?
        attributes_to_inspect=[{:value => :exists?, :label => :exists?}]+attributes_to_inspect.select{|inspect_hash| [:how, :what, :index].include?(inspect_hash[:label]) }
      end
      attributes_to_inspect.map do |inspect_hash|
        if !inspect_hash[:if] || inspect_hash[:if].call(self)
          value=case inspect_hash[:value]
          when /\A@/ # starts with @, look for instance variable
            instance_variable_get(inspect_hash[:value]).inspect
          when Symbol
            send(inspect_hash[:value])
          when Proc
            inspect_hash[:value].call(self)
          else
            inspect_hash[:value]
          end
          [inspect_hash[:label].to_s, value]
        end
      end.compact
    end
    def inspect
      "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)}"+attributes_for_stringifying.map do |attr|
        " "+attr.first+'='+attr.last.inspect
      end.join('') + ">"
    end
    def to_s
      attrs=attributes_for_stringifying
      longest_label=attrs.inject(0) {|max, attr| [max, attr.first.size].max }
      "#{self.class.name}:0x#{"%.8x"%(self.hash*2)}\n"+attrs.map do |attr|
        (attr.first+": ").ljust(longest_label+2)+attr.last.inspect+"\n"
      end.join('')
    end

    def pretty_print(pp)
      pp.object_address_group(self) do
        pp.seplist(attributes_for_stringifying, lambda { pp.text ',' }) do |attr|
          pp.breakable ' '
          pp.group(0) do
            pp.text attr.first
            pp.text ':'
            pp.breakable
            pp.pp attr.last
          end
        end
      end
    end

    # for a common module, such as a TextField, returns an elements-specific class (such as
    # FFTextField) that inherits from the base_element_class of self. That is, this returns
    # a sibling class, as it were, of whatever class inheriting from Element is instantiated.
    def element_class_for(common_module)
      element_class=nil
      ObjectSpace.each_object(Class) do |klass|
        if klass < common_module && klass < base_element_class
          element_class= klass
        end
      end
      unless element_class
        raise RuntimeError, "No class found that inherits from both #{common_module} and #{base_element_class}"
      end
      element_class
    end
    
    module_function
    def object_collection_to_enumerable(object)
      if object.is_a?(Enumerable)
        object
      elsif Object.const_defined?('JsshObject') && object.is_a?(JsshObject)
        object.to_array
      elsif Object.const_defined?('WIN32OLE') && object.is_a?(WIN32OLE)
        array=[]
        (0...object.length).each do |i|
          array << object.item(i)
        end
        array
      else
        raise TypeError, "Don't know how to make enumerable from given object #{object.inspect} (#{object.class})"
      end
    end
    
  end
end
