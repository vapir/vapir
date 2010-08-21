require 'vapir-common/element_collection'
require 'set'
require 'matrix'
require 'vapir-common/element_class_and_module'

module Vapir
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
          # todo: move this into the ie flavor, doesn't need to be in common 
          got_attribute=false
          attribute=nil
          begin
            attribute=element_object.method_missing(dom_method_name)
            got_attribute=true
          rescue WIN32OLERuntimeError, NoMethodError
          end
          if !got_attribute
            if args.length==0
              begin
                if (node=element_object.getAttributeNode(dom_method_name.to_s))
                  attribute=node.value
                  got_attribute=true
                end
              rescue WIN32OLERuntimeError, NoMethodError
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
              if (node=element_object.getAttributeNode(dom_method_name.to_s))
                node.value
              else
                nil
              end
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
    
    def html
      Kernel.warn_with_caller "#html is deprecated, please use #outer_html or #inner_html. #html currently returns #outer_html (note that it previously returned inner_html on firefox)"
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
      @page_container=extra[:page_container]
      @element_object=extra[:element_object] # this will in most cases not be set, but may be set in some cases from ElementCollection enumeration 
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
    
    private
    # returns whether the specified index for this element is equivalent to finding the first element 
    def index_is_first
      [nil, :first, 1].include?(index)
    end
    def assert_no_index
      unless index_is_first
        raise NotImplementedError, "Specifying an index is not supported for locating by #{@how}"
      end
    end
    # iterates over the element object candidates yielded by the given method. 
    # returns the match at the given index. if a block is given, the block should 
    # return true when the yielded element object is a match and false when it is not. 
    # if no block is given, then it is assumed that every element object candidate
    # returned by the candidates_method is a match. candidates_method_args are
    # passed to the candidates method untouched. 
    def candidate_match_at_index(index, candidates_method, *candidates_method_args)
      matched_candidate=nil
      matched_count=0
      candidates_method.call(*candidates_method_args) do |candidate|
        candidate_matches=block_given? ? yield(candidate) : true
        if candidate_matches
          matched_count+=1
          if index==matched_count || index_is_first || index==:last
            matched_candidate=candidate
            break unless index==:last
          end
        end
      end
      matched_candidate
    end
    public
    # locates the element object for this element 
    def locate
      if element_object_exists?
        return @element_object
      end
      new_element_object= begin
        case @how
        when :element_object
          assert_no_index
          if @element_object # if @element_object is already set, it must not exist, since we check #element_object_exists? above. 
            raise Vapir::Exception::UnableToRelocateException, "This #{self.class.name} was specified using #{how.inspect} and cannot be relocated."
          else
            @what
          end
        when :xpath
          assert_container_exists
          unless @container.respond_to?(:element_object_by_xpath)
            raise Vapir::Exception::MissingWayOfFindingObjectException, "Locating by xpath is not supported on the container #{@container.inspect}"
          end
          # todo/fix: implement index for this, using element_objects_by_xpath ? 
          assert_no_index
          by_xpath=@container.element_object_by_xpath(@what)
          match_candidates(by_xpath ? [by_xpath] : [], self.class.specifiers, self.class.all_dom_attr_aliases).first
        when :label
          assert_no_index
          unless document_object
            raise "No document object found for this #{self.inspect} - needed to search by id for label from #{@container.inspect}"
          end
          unless what.is_a?(Label)
            raise "how=:label specified on this #{self.class}, but 'what' is not a Label! what=#{what.inspect} (#{what.class})"
          end
          what.locate!
          by_label=document_object.getElementById(what.for)
          match_candidates(by_label ? [by_label] : [], self.class.specifiers, self.class.all_dom_attr_aliases).first
        when :attributes
          assert_container_exists
          specified_attributes=@what
          specifiers=self.class.specifiers.map{|spec| spec.merge(specified_attributes)}
          
          candidate_match_at_index(@index, method(:matched_candidates), specifiers, self.class.all_dom_attr_aliases)
        when :index
          assert_container_exists
          unless @what.nil?
            raise ArgumentError, "'what' was specified, but when 'how'=:index, no 'what' is used (just extra[:index])"
          end
          unless @index
            raise ArgumentError, "'how' was given as :index but no index was given"
          end
          candidate_match_at_index(@index, method(:matched_candidates), self.class.specifiers, self.class.all_dom_attr_aliases)
        when :custom
          assert_container_exists
          # this allows a proc to be given as 'what', which is called yielding candidates, each being 
          # an instanted Element of this class. this might seem a bit odd - instantiating a bunch 
          # of elements in order to figure out which element_object to use in locating this one. 
          # the purpose is so that this Element can be relocated if we lose the element_object. 
          # the Elements that are yielded are instantiated by :element object which cannot be 
          # relocated. 
          #
          # this integrates with ElementCollection, where Enumerable methods #detect,
          # #select, and #reject are overridden to use it. 
          # 
          # the proc should return true (that is, not false or nil) when it likes the given Element - 
          # when it matches what it expects of this Element. 
          candidate_match_at_index(@index, method(:matched_candidates), self.class.specifiers, self.class.all_dom_attr_aliases) do |candidate|
            what.call(self.class.new(:element_object, candidate, @extra))
          end
        else
          raise Vapir::Exception::MissingWayOfFindingObjectException, "Unknown 'how' given: #{@how.inspect} (#{@how.class}). 'what' was #{@what.inspect} (#{@what.class})"
        end
      end
      @element_object=new_element_object
    end
    def locate!
      locate || begin
        klass=self.is_a?(Frame) ? Vapir::Exception::UnknownFrameException : Vapir::Exception::UnknownObjectException
        message="Unable to locate #{self.class}, using #{@how}"+(@what ? ": "+@what.inspect : '')+(@index ? ", index #{@index}" : "")
        message+="\non container: #{@container.inspect}" if @container
        raise(klass, message)
      end
    end
    
    public
    # Returns whether this element actually exists.
    def exists?
      handling_existence_failure(:handle => proc { return false }) do
        return !!locate
      end
    end
    alias :exist? :exists?
    
    # method to access dom attributes by defined aliases. 
    # unlike get_attribute, this only looks at the specific dom attributes that Watir knows about, and 
    # the aliases for those that Watir defines. 
    def attr(attribute)
      unless attribute.is_a?(String) || attribute.is_a?(Symbol)
        raise TypeError, "attribute should be string or symbol; got #{attribute.inspect}"
      end
      attribute=attribute.to_sym
      all_aliases=self.class.all_dom_attr_aliases
      dom_attrs=all_aliases.reject{|dom_attr, attr_aliases| !attr_aliases.include?(attribute) }.keys
      case dom_attrs.size
      when 0
        raise ArgumentError, "Not a recognized attribute: #{attribute}"
      when 1
        method_from_element_object(dom_attrs.first)
      else
        raise ArgumentError, "Ambiguously aliased attribute #{attribute} may refer to any of: #{dom_attrs.join(', ')}"
      end
    end
    
    # returns an Element that represents the same object as self, but is an instance of the 
    # most-specific class < self.class that can represent that object. 
    #
    # For example, if we have a table, get its first element, and call #to_factory on it:
    #
    # a_table=browser.tables.first
    # => #<Vapir::IE::Table:0x071bc70c how=:index index=:first tagName="TABLE">
    # a_element=a_table.elements.first
    # => #<Vapir::IE::Element:0x071b856c how=:index index=:first tagName="TBODY" id="">
    # a_element.to_factory
    # => #<Vapir::IE::TableBody:0x071af78c how=:index index=:first tagName="TBODY" id="">
    #
    # we get back a Vapir::TableBody. 
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
      assert_exists do
        # yeah, this line is an unreadable mess, but I have to skip over it so many times debugging that it's worth just sticking it on one line 
        (options={:highlight => true}.merge(options)); (was_highlighting=@highlighting); (set_highlight(options) if !@highlighting && options[:highlight]); (@highlighting=true)
        begin; result=yield
        ensure
          @highlighting=was_highlighting
          if !@highlighting && options[:highlight]
            handling_existence_failure do
              assert_exists :force => true
              clear_highlight(options)
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
        Kernel.warn_with_caller "DEPRECATION WARNING: #{self.class.name}\#flash takes an options hash - passing a number is deprecated. Please use #{self.class.name}\#flash(:count => #{options[:count]})"
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
    
    # returns an array of all text nodes below this element in the DOM heirarchy 
    def text_nodes
      # TODO: needs tests 
      assert_exists do
        recurse_text_nodes=proc do |rproc, e_obj|
          case e_obj.nodeType
          when 1 # TODO: name a constant ELEMENT_NODE, rather than magic number 
            object_collection_to_enumerable(e_obj.childNodes).inject([]) do |result, c_obj|
              result + rproc.call(rproc, c_obj)
            end
          when 3 # TODO: name a constant TEXT_NODE, rather than magic number 
            [e_obj.data]
          else
            #Kernel.warn("ignoring node of type #{e_obj.nodeType}")
            []
          end
        end
        recurse_text_nodes.call(recurse_text_nodes, element_object)
      end
    end
    # returns an array of text nodes below this element in the DOM heirarchy which are visible - 
    # that is, their parent element is visible. 
    def visible_text_nodes
      # TODO: needs tests 
      assert_exists do
        # define a nice recursive function to iterate down through the children 
        recurse_text_nodes=proc do |rproc, e_obj, parent_visibility|
          case e_obj.nodeType
          when 1 # TODO: name a constant ELEMENT_NODE, rather than magic number 
            style=element_object_style(e_obj, document_object)
            our_visibility = style && (visibility=style.invoke('visibility'))
            unless our_visibility && ['hidden', 'collapse', 'visible'].include?(our_visibility=our_visibility.strip.downcase)
              our_visibility = parent_visibility
            end
            if (display=style.invoke('display')) && display.strip.downcase=='none'
              []
            else
              object_collection_to_enumerable(e_obj.childNodes).inject([]) do |result, c_obj|
                result + rproc.call(rproc, c_obj, our_visibility)
              end
            end
          when 3 # TODO: name a constant TEXT_NODE, rather than magic number 
            if ['hidden','collapse'].include?(parent_visibility)
              []
            else
              [e_obj.data]
            end
          else
            #Kernel.warn("ignoring node of type #{e_obj.nodeType}")
            []
          end
        end
  
        # determine the current visibility and display. TODO: this is copied/adapted from #visible?; should DRY 
        element_to_check=element_object
        real_visibility=nil
        while element_to_check #&& !element_to_check.instanceof(nsIDOMDocument)
          if (style=element_object_style(element_to_check, document_object))
            # only pay attention to the innermost definition that really defines visibility - one of 'hidden', 'collapse' (only for table elements), 
            # or 'visible'. ignore 'inherit'; keep looking upward. 
            # this makes it so that if we encounter an explicit 'visible', we don't pay attention to any 'hidden' further up. 
            # this style is inherited - may be pointless for firefox, but IE uses the 'inherited' value. not sure if/when ff does.
            if real_visibility==nil && (visibility=style.invoke('visibility'))
              visibility=visibility.strip.downcase
              if ['hidden', 'collapse', 'visible'].include?(visibility)
                real_visibility=visibility
              end
            end
            # check for display property. this is not inherited, and a parent with display of 'none' overrides an immediate visibility='visible' 
            display=style.invoke('display')
            if display && (display=display.strip.downcase)=='none'
              # if display is none, then this element is not visible, and thus has no visible text nodes underneath. 
              return []
            end
          end
          element_to_check=element_to_check.parentNode
        end
        recurse_text_nodes.call(recurse_text_nodes, element_object, real_visibility)
      end
    end
    # returns an visible text inside this element by concatenating text nodes below this element in the DOM heirarchy which are visible.
    def visible_text
      # TODO: needs tests 
      visible_text_nodes.join('')
    end

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
        if el.respond_to?(:scrollLeft) && el.respond_to?(:scrollTop) && (scroll_left=el.scrollLeft).is_a?(Numeric) && (scroll_top=el.scrollTop).is_a?(Numeric)
          xy+=Vector[scroll_left, scroll_top]
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
    
    attr_reader :browser
    attr_reader :page_container

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
    # Firefox::TextField) that inherits from the base_element_class of self. That is, this returns
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
        length = object.length
        (0...length).each do |i|
          begin
            array << object.item(i)
          rescue WIN32OLERuntimeError
            # not rescuing, just adding information
            raise $!.class, "accessing item #{i} of #{length}, encountered:\n"+$!.message, $!.backtrace
          end
        end
        array
      else
        raise TypeError, "Don't know how to make enumerable from given object #{object.inspect} (#{object.class})"
      end
    end
    
  end
end
