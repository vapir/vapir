require 'active_support/inflector'
class Module
  def alias_deprecated(to, from)
    define_method to do |*args|
      STDERR.puts "DEPRECATION WARNING: #{self.class.name}\##{to} is deprecated. Please use #{self.class.name}\##{from}\n(called from #{caller.map{|c|"\n"+c}})"
      send(from, *args)
    end
  end
end
module Watir
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
            method_from_element_object(dom_method_name, *args)
          end
        end
      end
    end
    def dom_wrap_deprecated(ruby_method_name, dom_method_name, new_method_name)
      define_method ruby_method_name do |*args|
        STDERR.puts "DEPRECATION WARNING: #{self.class.name}\##{ruby_method_name} is deprecated, please use #{self.class.name}\##{new_method_name}\n(called from #{caller.map{|c|"\n"+c}}})"
        method_from_element_object(dom_method_name, *args)
      end
    end
  end
  module ElementModule
    # set container methods on inherit
    def self.included(includer) # when this module gets included (by a Watir Element module)
      __orig_included_before_ElementModule__=includer.respond_to?(:included) ? includer.method(:included) : nil
      includer_metaclass=(class << includer;self;end)
      includer_metaclass.send(:define_method, :included) do |subincluder| # make its .included method
          __orig_included_before_ElementModule__.call(subincluder) if __orig_included_before_ElementModule__

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
                      locate! # make sure self is located before trying contained stuff 
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
              container_module.module_eval do
                define_method('show_'+container_multiple_method.to_s) do |*io|
                  io=io.first||$stdout # io is a *array so that you don't have to give an arg (since procs don't do default args)
                  element_collection=element_collection(subincluder)
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
        includer.constants.each do |const| # copy all of its constants onto wherever it was included
          subincluder.const_set(const, includer.const_get(const))
        end
        
        class << subincluder
          def attributes_to_inspect
            super_attrs=superclass.respond_to?(:attributes_to_inspect) ? superclass.attributes_to_inspect : []
            super_attrs + (const_defined?('AttributesToInspect') ? const_get('AttributesToInspect') : [])
          end
        end
      end
      
      includer.send :extend, DomWrap
      includer_metaclass.send(:define_method, :dom_wrap_inspect) do |*args|
        dom_wrap *args
        inspect_these *args
      end
      includer_metaclass.send(:define_method, :inspect_these) do |*args|
        # set default inspect variables. This constant gets copied onto the Element classes by constant-copying code above.
        unless includer.const_defined?('AttributesToInspect')
          includer.const_set('AttributesToInspect', [])
        end
        attributes_to_inspect=includer.const_get('AttributesToInspect')
        args.each do |arg|
          attributes_to_inspect << case arg
          when Hash
            arg
          when Symbol
            {:label => arg, :value => arg}
          else
            raise RuntimeError, "unrecognized thing to inspect: #{arg} (#{arg.class})"
          end
        end
      end
      includer_metaclass.send(:define_method, :inspect_this_if) do |arg, *ifproc|
        ifproc=ifproc.first
        to_inspect={:label => arg, :value => proc{ send(arg).inspect }}
        to_inspect[:if] = ifproc || proc{ send(arg) }
        inspect_these(to_inspect)
      end
#      includer.inspect_these(:how, :what, {:label => :index, :value => proc{ @index }, :if => proc{ @index }}, :tag_name, :id)  # set defaults to inspect
    end
  end
  # this is to define common constants from the class name rather than repeating slight variations
  # on the class name for every class
  module ContainerMethodsFromName
    def self.included(includer)
      single_meth=includer.name.demodulize.underscore
      multiple_meth=single_meth.pluralize
      if single_meth==multiple_meth
        raise RuntimeError, "defining container methods #{single_meth}: single is the same as multiple! specify Container*Method constants manually."
      end
      includer.const_set('ContainerSingleMethod', [single_meth])
      includer.const_set('ContainerMultipleMethod', [multiple_meth])
    end
  end

  # this is included by every Element. it relies on the including class implementing a 
  # #element_object method 
  # some stuff assumes the element has a defined @container. 
  module Element
    include ContainerMethodsFromName
    Specifiers=[{}] # one specifier with no criteria - note that an empty specifiers list
                     # would match no elements; a non-empty list with no criteria matches any
                     # element.
    def self.included(element_klass)
      # look for constants to define specifiers - either class::Specifier, or
      # the simpler class::TAG
      def element_klass.specifiers
        if self.const_defined?('Specifiers') # note that though constants are inherited, this checks if Specifiers is defined on the class itself 
                                              # (although the class itself may not define them, these are mostly defined for classes by element classes in commonwatir)
          #self.const_get('Specifiers')
          self::Specifiers
        elsif self.const_defined?('TAG')
          [{:tagName => self::TAG}]
        else
          raise "No way found to specify #{self}."
        end
      end
      
      def element_klass.default_how
        self.const_defined?('DefaultHow') ? self.const_get('DefaultHow') : nil
      end
      
    end
    include ElementModule
    
    private
    def method_from_element_object(dom_method_name, *args)
      assert_exists

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
        elsif args.length==0
          if element_object.object_respond_to?(:getAttributeNode)
            element_object.getAttributeNode(dom_method_name.to_s).value
            #element_object.getAttribute(dom_method_name.to_s)
          else
            nil
          end
        else
          raise ArgumentError, "Arguments were given to #{ruby_method_name} but there is no function #{dom_method_name} to pass them to!"
        end
      end
    end
    public
    
    inspect_these(:how, :what, {:label => :index, :value => proc{ @index }, :if => proc{ @index }})
    dom_wrap_inspect :tagName, :id
    dom_wrap :className, :title, :innerHTML, :tag_name => :tagName, :text => :textContent, :inner_html => :innerHTML, :class_name => :className
    #TODO/FIX: this was is outerhtml in IE; innerHTML in FF. maybe just deprecate this and go with the html names?
    #dom_wrap :html => :innerHTML
    dom_wrap :style
    dom_wrap :scrollIntoView
    dom_wrap :get_attribute_value => :getAttribute, :attribute_value => :getAttribute

    # #text is defined on browser-specific Element classes 
    alias_deprecated :innerText, :text
    alias_deprecated :textContent, :text
    
    attr_reader :how
    attr_reader :what
    
    def html
      STDERR.puts "#html is deprecated, please use #outer_html or #inner_html. #html currently returns #outer_html (note that it previously returned inner_html on firefox)"
      outer_html
    end

    private
    # this is used by #locate. 
    # it may be overridden, as it is by Frame classes
    def container_candidates(specifiers)
      Watir::Specifier.specifier_candidates(@container, specifiers)
    end

    public
    # locates a javascript reference for this element
    def locate(options={})
      default_options={}
      if @browser && @updated_at && @browser.respond_to?(:updated_at) && @browser.updated_at > @updated_at # TODO: implement this for IE; only exists for Firefox now. 
        default_options[:relocate]=:recursive
      end
      if element_object && Object.const_defined?('WIN32OLE') && element_object.is_a?(WIN32OLE) # if we have a WIN32OLE element object 
        if !element_object.exists?
          default_options[:relocate]=true
        end
      end
      options=default_options.merge(options)
      if options[:relocate]
        @element_object=nil
      end
      element_object_existed=!!@element_object
      @element_object||= begin
        case @how
        when :element_object
          raise if options[:relocate]
          @what
        when :xpath
          if !@container
            raise
          end
          @container.locate!(options)
          unless @container.respond_to?(:element_object_by_xpath)
            raise Watir::Exception::MissingWayOfFindingObjectException, "Locating by xpath is not supported on the container #{@container.inspect}"
          end
          by_xpath=@container.element_object_by_xpath(@what)
          # todo/fix: implement @index for this, using element_objects_by_xpath ? 
          matched_by_xpath=nil
          Watir::Specifier.match_candidates(by_xpath ? [by_xpath] : [], self.class.specifiers) do |match|
            matched_by_xpath=match
          end
          matched_by_xpath
        when :attributes
          if !@container
            raise
          end
          @container.locate!(options)
          specified_attributes=@what
          specifiers=self.class.specifiers.map{|spec| spec.merge(specified_attributes)}
          
          matched_candidate=nil
          matched_count=0
          container_candidates=container_candidates(specifiers)
          Watir::Specifier.match_candidates(container_candidates, specifiers) do |match|
            matched_count+=1
            if !@index || @index==matched_count
              matched_candidate=match
              break
            end
          end
          matched_candidate
        else
          raise Watir::Exception::MissingWayOfFindingObjectException
        end
      end
      if !element_object_existed && @element_object
        @updated_at=Time.now
      end
      @element_object
    end
    def locate!(options={})
      locate(options) || raise(self.is_a?(Frame) ? Watir::Exception::UnknownFrameException : Watir::Exception::UnknownObjectException, Watir::Exception.message_for_unable_to_locate(@how, @what, @index))
    end
    alias assert_exists locate!

    # Returns whether this element actually exists.
    def exists?
      !!locate
    end
    alias :exist? :exists?

    # takes a block. sets highlight on this element; calls the block; clears the highlight.
    # the clear is in an ensure block so that you can call return from the given block. 
    # doesn't actually perform the highlighting if argument do_highlight is false. 
    def with_highlight(do_highlight=true)
      highlight(:set) if do_highlight
      begin
        yield
      ensure
        highlight(:clear) if do_highlight
      end
    end

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

    # accesses the object representing this Element in the DOM. 
    # will error if this Element does not exist. 
    def element_object
      #locate!
      @element_object
    end
    
    def browser
      @container.browser
    end
    def document_object
      @container.document_object
    end
    def content_window_object
      @container.content_window_object
    end
    def browser_window_object
      @container.browser_window_object
    end
    
    def attributes_for_stringifying
      self.class.attributes_to_inspect.map do |inspect_hash|
        if !inspect_hash[:if] || inspect_hash[:if].call
          value=case inspect_hash[:value]
          when /\A@/ # starts with @, look for instance variable
            instance_variable_get(inspect_hash[:value]).inspect
          when Symbol
            send(inspect_hash[:value]).inspect
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
        " "+attr.first+'='+attr.last
      end.join('') + ">"
    end
    def to_s
      attrs=attributes_for_stringifying
      longest_label=attrs.inject(0) {|max, attr| [max, attr.first.size].max }
      "#{self.class.name}:0x#{"%.8x"%(self.hash*2)}\n"+attrs.map do |attr|
        (attr.first+": ").ljust(longest_label+2)+attr.last+"\n"
      end.join('')
    end
  end
end
