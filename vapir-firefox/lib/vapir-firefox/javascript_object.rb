# represents a javascript object in ruby. 
class JavascriptObject
  # the reference to the javascript object this JavascriptObject represents 
  attr_reader :ref
  # the FirefoxSocket this JavascriptObject is on 
  attr_reader :firefox_socket
  # whether this represents the result of a function call (if it does, then FirefoxSocket#typeof won't be called on it)
  attr_reader :function_result
  # this tracks the origins of this object - what calls were made along the way to get it. 
  attr_reader :debug_name
# :stopdoc:
#  def logger
#    firefox_socket.logger
#  end

# :startdoc:

  public
  # initializes a JavascriptObject with a string of javascript containing a reference to
  # the object, and a FirefoxSocket that the object is defined on. 
  def initialize(ref, firefox_socket, other={})
    other={:debug_name => ref, :function_result => false}.merge(other)
    raise ArgumentError, "Empty object reference!" if !ref || ref==''
    raise ArgumentError, "Reference must be a string - got #{ref.inspect} (#{ref.class.name})" unless ref.is_a?(String)
    raise ArgumentError, "Not given a FirefoxSocket, instead given #{firefox_socket.inspect} (#{firefox_socket.class.name})" unless firefox_socket.is_a?(FirefoxSocket)
    @ref=ref
    @firefox_socket=firefox_socket
    @debug_name=other[:debug_name]
    @function_result=other[:function_result]
#    logger.info { "#{self.class} initialized: #{debug_name} (type #{type})" }
  end

  # returns the value, via FirefoxSocket#value_json
  def val
    firefox_socket.value_json(ref, :error_on_undefined => !function_result)
  end
  
  # whether JavascriptObject shall try to dynamically define methods on initialization, using 
  # #define_methods! default is false. 
  def self.always_define_methods
    unless class_variable_defined?('@@always_define_methods')
      # if not defined, set the default. 
      @@always_define_methods=false
    end
    @@always_define_methods
  end
  # set whether JavascriptObject shall try to dynamically define methods in #val_or_object, using
  # #define_methods! 
  #
  # I find this useful to set to true in irb, for tab-completion of methods. it may cause
  # operations to be considerably slower, however. 
  #
  # for always setting this in irb, I set this beforehand, overriding the default, 
  # by including in my .irbrc the following (which doesn't require this file to be
  # required):
  #
  #  class JavascriptObject
  #    @@always_define_methods=true
  #  end
  def self.always_define_methods=(val)
    @@always_define_methods = val
  end

  # returns the value just as a string with no attempt to deal with type using json. via FirefoxSocket#value 
  #
  # note that this can be slow if it evaluates to a blank string. for example, if ref is just ""
  # then FirefoxSocket#value will wait DEFAULT_SOCKET_TIMEOUT seconds for data that is not to come. 
  # this also happens with functions that return undefined. if ref="function(){do_some_stuff;}" 
  # (with no return), it will also wait DEFAULT_SOCKET_TIMEOUT. 
  def val_str
    firefox_socket.value(ref)
  end

  # returns javascript typeof this object 
  def type
    if function_result # don't get type for function results, causes function evaluations when you probably didn't want that. 
      nil
    else
#      logger.add(-1) { "retrieving type for #{debug_name}" }
      @type||= firefox_socket.typeof(ref)
    end
  end
  
  # calls the javascript instanceof operator on this object and the given interface (expected to 
  # be a JavascriptObject) note that the javascript instanceof operator is not to be confused with 
  # ruby's #instance_of? method - this takes a javascript interface; #instance_of? takes a ruby 
  # module.
  # 
  # example:
  #  window.instanceof(window.firefox_socket.Components.interfaces.nsIDOMChromeWindow)
  #  => true
  def instanceof(interface)
    firefox_socket.instanceof(self.ref, interface.ref)
  end
  # returns an array of interfaces which this object is an instance of. this is achieved 
  # by looping over each value of Components.interfaces (see https://developer.mozilla.org/en/Components.interfaces ) 
  # and calling the #instanceof operator with this and the interface. 
  #
  # this may be rather slow. 
  def implemented_interfaces
    firefox_socket.Components.interfaces.to_hash.inject([]) do |list, (key, interface)|
      list << interface if instanceof(interface)
      list
    end
  end
  
  # returns the type of object that is reported by the javascript toString() method, which
  # returns such as "[object Object]" or "[object XPCNativeWrapper [object HTMLDocument]]"
  # This method returns 'Object' or 'XPCNativeWrapper [object HTMLDocument]' respectively.
  # Raises an error if this JavascriptObject points to something other than a javascript 'object'
  # type ('function' or 'number' or whatever)
  #
  # this isn't used, doesn't seem useful, and may go away in the future. 
  def object_type
    @object_type ||= begin
      case type
      when 'object'
        self.toString! =~ /\A\[object\s+(.*)\]\Z/
        $1
      else
        raise FirefoxSocketJavascriptError, "Type is #{type}, not object"
      end
    end
  end
  
  # checks the type of this object, and if it is a type that can be simply converted to a ruby
  # object via json, returns the ruby value. that occurs if the type is one of:
  # 
  # 'boolean','number','string','null'
  #
  # otherwise - if the type is something else (probably 'function' or 'object'; or maybe something else)
  # then this JavascriptObject is returned. 
  # 
  # if the object this refers to is undefined in javascript, then behavor depends on the options 
  # hash. if :error_on_undefined is true, then nil is returned; otherwise FirefoxSocketUndefinedValueError 
  # is raised. 
  #
  # if this is a function result, this will store the result in a temporary location (thereby
  # calling the function to acquire the result) before making the above decision. 
  #
  # this method also calls #define_methods! on this if JavascriptObject.always_define_methods is true. 
  # this can be overridden in the options hash using the :define_methods key (true or false). 
  def val_or_object(options={})
    options={:error_on_undefined=>true, :define_methods => self.class.always_define_methods}.merge(options)
    if function_result # calling functions multiple times is bad, so store in temp before figuring out what to do with it
      store_rand_object_key(firefox_socket.temp_object).val_or_object(options.merge(:error_on_undefined => false))
    else
      case self.type
      when 'undefined'
        if !options[:error_on_undefined]
          nil
        else
          raise FirefoxSocketUndefinedValueError, "undefined expression represented by #{self.inspect} (javascript reference is #{@ref})"
        end
      when 'boolean','number','string','null'
        val
      else # 'function','object', or anything else 
        if options[:define_methods] && type=='object'
          define_methods!
        end
        self
      end
    end
  end
  # does the work of #method_missing to determine whether to call a function what to return based 
  # on the defined behavior of the given suffix. see #method_missing for more. information. 
  def assign_or_call_or_val_or_object_by_suffix(suffix, *args)
    if suffix=='='
      assign(*args)
    else
      obj = if !args.empty? || type=='function'
        pass(*args)
      else
        self
      end
      case suffix
      when nil
        obj.val_or_object
      when '?'
        obj.val_or_object(:error_on_undefined => false)
      when '!'
        obj.val
      else
        raise ArgumentError, "suffix should be one of: nil, '?', '!', '='; got: #{suffix.inspect}"
      end
    end
  end
  
  # returns a JavascriptObject representing the given attribute. Checks the type, and if it is a 
  # function, calls the function with any arguments given (which are converted to javascript) 
  # and returns the return value of the function (or nil if the function returns undefined). 
  #
  # If the attribute is undefined, raises an error (if you want an attribute even if it's 
  # undefined, use #invoke? or #attr). 
  def invoke(attribute, *args)
    attr(attribute).assign_or_call_or_val_or_object_by_suffix(nil, *args)
  end
  # same as #invoke, but returns nil for undefined attributes rather than raising an
  # error. 
  def invoke?(attribute, *args)
    attr(attribute).assign_or_call_or_val_or_object_by_suffix('?', *args)
  end
  
  # returns a JavascriptObject referencing the given attribute of this object 
  def attr(attribute, options={})
    unless (attribute.is_a?(String) || attribute.is_a?(Symbol)) && attribute.to_s =~ /\A[a-z_][a-z0-9_]*\z/i
      raise FirefoxSocketSyntaxError, "#{attribute.inspect} (#{attribute.class.inspect}) is not a valid attribute!"
    end
    JavascriptObject.new("#{ref}.#{attribute}", firefox_socket, :debug_name => "#{debug_name}.#{attribute}")
  end

  # assigns the given ruby value (converted to javascript) to the reference
  # for this object. returns self. 
  def assign(val)
    @debug_name="(#{debug_name}=#{val.is_a?(JavascriptObject) ? val.debug_name : FirefoxSocket.to_javascript(val)})"
    result=assign_expr(FirefoxSocket.to_javascript(val))
#    logger.info { "#{self.class} assigned: #{debug_name} (type #{type})" }
    result
  end
  # assigns the given javascript expression (string) to the reference for this object 
  def assign_expr(val)
    firefox_socket.value_json("(function(val){#{ref}=val; return null;}(#{val}))")
    @type=nil # uncache this 
    # don't want to use FirefoxSocket#assign_json because converting the result of the assignment (that is, the expression assigned) to json is error-prone and we don't really care about the result. 
    # don't want to use FirefoxSocket#assign because the result can be blank and cause send_and_read to wait for data that's not coming - also 
    # using a json function is better because it catches errors much more elegantly. 
    # so, wrap it in a function that returns nil. 
    self
  end
  
  # returns a JavascriptObject for the result of calling the function represented by this object, passing 
  # the given arguments, which are converted to javascript. if this is not a function, javascript will raise an error. 
  def pass(*args)
    JavascriptObject.new("#{ref}(#{args.map{|arg| FirefoxSocket.to_javascript(arg)}.join(', ')})", firefox_socket, :function_result => true, :debug_name => "#{debug_name}(#{args.map{|arg| arg.is_a?(JavascriptObject) ? arg.debug_name : FirefoxSocket.to_javascript(arg)}.join(', ')})")
  end
  
  # returns the value (via FirefoxSocket#value_json) or a JavascriptObject (see #val_or_object) of the return 
  # value of this function (assumes this object is a function) passing it the given arguments (which 
  # are converted to javascript). 
  #
  # simply, it just calls self.pass(*args).val_or_object
  def call(*args)
    pass(*args).val_or_object
  end
  
  # assuming the javascript object represented is a constructor, this returns a new
  # instance passing the given arguments. 
  #
  #  date_class = firefox_socket.object('Date')
  #  => #<JavascriptObject:0x0118eee8 type=function, debug_name=Date>
  #  date = date_class.new
  #  => #<JavascriptObject:0x01188a84 type=object, debug_name=new Date()>
  #  date.getFullYear
  #  => 2010
  #  date_class.new('october 4, 1978').getFullYear
  #  => 1978
  def new(*args)
    JavascriptObject.new("new #{ref}", firefox_socket, :debug_name => "new #{debug_name}").call(*args)
  end

  # sets the given javascript variable to this object, and returns a JavascriptObject referring
  # to the variable. 
  #
  #  >> foo=document.getElementById('guser').store('foo')
  #  => #<JavascriptObject:0x2dff870 @ref="foo" ...>
  #  >> foo.tagName
  #  => "DIV"
  #
  # the second argument is only used internally and shouldn't be used. 
  def store(js_variable, somewhere_meaningful=true)
    stored=JavascriptObject.new(js_variable, firefox_socket, :function_result => false, :debug_name => somewhere_meaningful ? "(#{js_variable}=#{debug_name})" : debug_name)
    stored.assign_expr(self.ref)
    stored
  end
  
  private
  # takes a block which, when yielded a random key, should result in a random reference. this checks
  # that the reference is not already in use and stores this object in that reference, and returns 
  # a JavascriptObject referring to the stored object. 
  def store_rand_named(&name_proc)
    base=36
    length=32
    begin
      name=name_proc.call(("%#{length}s"%rand(base**length).to_s(base)).tr(' ','0'))
    end #while JavascriptObject.new(name,firefox_socket).type!='undefined'
    # okay, more than one iteration is ridiculously unlikely, sure, but just to be safe. 
    store(name, false)
  end
  public
  
  # stores this object in a random key of the given object and returns the stored object. 
  def store_rand_object_key(object)
    raise ArgumentError("Object is not a JavascriptObject: got #{object.inspect}") unless object.is_a?(JavascriptObject)
    store_rand_named do |r|
      object.sub(r).ref
    end
  end
  
  # stores this object in a random key of the designated temporary object for this socket and returns the stored object. 
  def store_rand_temp
    store_rand_object_key(firefox_socket.temp_object)
  end

  # returns a JavascriptObject referring to a subscript of this object, specified as a ruby object converted to 
  # javascript. 
  #
  # similar to [], but [] calls #val_or_object; this always returns a JavascriptObject. 
  def sub(key)
    JavascriptObject.new("#{ref}[#{FirefoxSocket.to_javascript(key)}]", firefox_socket, :debug_name => "#{debug_name}[#{key.is_a?(JavascriptObject) ? key.debug_name : FirefoxSocket.to_javascript(key)}]")
  end

  # returns a JavascriptObject referring to a subscript of this object, or a value if it is simple (see #val_or_object)
  #
  # subscript is specified as ruby (converted to javascript). 
  def [](key)
    sub(key).val_or_object(:error_on_undefined => false)
  end

  # assigns the given ruby value (which is converted to javascript) to the given subscript
  # (the key is also converted to javascript). 
  def []=(key, value)
    self.sub(key).assign(value)
  end

  # calls a binary operator (in javascript) with self and another operand.
  #
  # the operator should be string of javascript; the operand will be converted to javascript. 
  def binary_operator(operator, operand)
    JavascriptObject.new("(#{ref}#{operator}#{FirefoxSocket.to_javascript(operand)})", firefox_socket, :debug_name => "(#{debug_name}#{operator}#{operand.is_a?(JavascriptObject) ? operand.debug_name : FirefoxSocket.to_javascript(operand)})").val_or_object
  end
  # addition, using the + operator in javascript 
  def +(operand)
    binary_operator('+', operand)
  end
  # subtraction, using the - operator in javascript 
  def -(operand)
    binary_operator('-', operand)
  end
  # division, using the / operator in javascript 
  def /(operand)
    binary_operator('/', operand)
  end
  # multiplication, using the * operator in javascript 
  def *(operand)
    binary_operator('*', operand)
  end
  # modulus, using the % operator in javascript 
  def %(operand)
    binary_operator('%', operand)
  end
  # returns true if the javascript object represented by this is equal to the given operand. 
  def ==(operand)
    operand.is_a?(JavascriptObject) && binary_operator('==', operand)
  end
  # javascript triple-equals (===) operator. very different from ruby's tripl-equals operator - 
  # in javascript this means "really really equal"; in ruby it means "sort of equal-ish" 
  def triple_equals(operand)
    operand.is_a?(JavascriptObject) && binary_operator('===', operand)
  end
  # inequality, using the > operator in javascript 
  def >(operand)
    binary_operator('>', operand)
  end
  # inequality, using the < operator in javascript 
  def <(operand)
    binary_operator('<', operand)
  end
  # inequality, using the >= operator in javascript 
  def >=(operand)
    binary_operator('>=', operand)
  end
  # inequality, using the <= operator in javascript 
  def <=(operand)
    binary_operator('<=', operand)
  end
  
  # method_missing handles unknown method calls in a way that makes it possible to write 
  # javascript-like syntax in ruby, to some extent. 
  #
  # method_missing checks the attribute of the represented javascript object with with the name of the given method. if that 
  # attribute refers to a function, then that function is called with any given arguments 
  # (like #invoke does). If that attribute is undefined, an error will be raised, unless a '?' 
  # suffix is used (see below). 
  #
  # method_missing will only try to deal with methods that look like /^[a-z_][a-z0-9_]*$/i - no
  # special characters, only alphanumeric/underscores, starting with alpha or underscore - with
  # the exception of three special behaviors:
  # 
  # If the method ends with an equals sign (=), it does assignment - it calls #assign on the given 
  # attribute, with the given (single) argument, to do the assignment and returns the assigned 
  # value. 
  #
  # If the method ends with a bang (!), then it will attempt to get the value of the reference, 
  # using JavascriptObject#val, which converts the javascript to json and then to ruby. For simple types 
  # (null, string, boolean, number), this is what gets returned anyway. With other types (usually 
  # the 'object' type), attempting to convert to json can raise errors or cause infinite 
  # recursion, so is not attempted. but if you have an object or an array that you know you can 
  # json-ize, you can use ! to force that. 
  #
  # If the method ends with a question mark (?), then if the attribute is undefined, no error is 
  # raised (as usually happens) - instead nil is just returned. 
  #
  # otherwise, method_missing behaves like #invoke, and returns a JavascriptObject, a string, a boolean, 
  # a number, or null. 
  #
  # Since method_missing returns a JavascriptObject for javascript objects, this means that you can 
  # string together method_missings and the result looks rather like javascript.
  #--
  # $A and $H, used below, are methods of the Prototype javascript library, which add nice functional 
  # methods to arrays and hashes - see http://www.prototypejs.org/
  # You can use these methods with method_missing just like any other:
  #
  #  >> js_hash=firefox_socket.object('$H')
  #  => #<JavascriptObject:0x2beb598 @ref="$H" ...>
  #  >> js_arr=firefox_socket.object('$A')
  #  => #<JavascriptObject:0x2be40e0 @ref="$A" ...>
  # 
  #  >> js_arr.call(document.body.childNodes).pluck! :tagName
  #  => ["TEXTAREA", "DIV", "NOSCRIPT", "DIV", "DIV", "DIV", "BR", "TABLE", "DIV", "DIV", "DIV", "TEXTAREA", "DIV", "DIV", "SCRIPT"]
  #  >> js_arr.call(document.body.childNodes).pluck! :id
  #  => ["csi", "header", "", "ssb", "tbd", "res", "", "nav", "wml", "", "", "hcache", "xjsd", "xjsi", ""]
  #  >> js_hash.call(document.getElementById('tbd')).keys!
  #  => ["addEventListener", "appendChild", "className", "parentNode", "getElementsByTagName", "title", ...]
  def method_missing(method, *args)
    method=method.to_s
    if method =~ /\A([a-z_][a-z0-9_]*)([=?!])?\z/i
      method = $1
      suffix = $2
      attr(method).assign_or_call_or_val_or_object_by_suffix(suffix, *args)
    else
      # don't deal with any special character crap 
      super
    end
  end
  # calls define_method for each key of this object as a hash. useful for tab-completing attributes 
  # in irb, mostly. 
  def define_methods! # :nodoc:
    metaclass=(class << self; self; end)
    keys=firefox_socket.object("function(obj) { var keys=[]; for(var key in obj) { keys.push(key); } return keys; }").pass(self).val
    
    keys.grep(/\A[a-z_][a-z0-9_]*\z/i).reject{|k| self.class.method_defined?(k)}.each do |key|
      metaclass.send(:define_method, key) do |*args|
        invoke(key, *args)
      end
    end
  end
  # returns true if this object responds to the given method (that is, it's a defined ruby method) 
  # or if #method_missing will handle it 
  def respond_to?(method, include_private = false)
    super || object_respond_to?(method)
  end
  # returns true if the javascript object this represents responds to the given method. this does not pay attention
  # to any defined ruby methods, just javascript. 
  def object_respond_to?(method)
    method=method.to_s
    if method =~ /^([a-z_][a-z0-9_]*)([=?!])?$/i
      method = $1
      suffix = $2
    else # don't deal with any special character crap 
      return false
    end

    if self.type=='undefined'
      return false
    elsif suffix=='='
      if self.type=='object'
        return true # yeah, you can generally assign attributes to objects
      else
        return false # no, you can't generally assign attributes to (boolean, number, string, null)
      end
    else
      attr=attr(method)
      return attr.type!='undefined'
    end
  end
  
  # undefine Object#id, and... anything else I think of that needs undef'ing in the future 
  [:id, :display].each do |method_name|
    if method_defined?(method_name)
      undef_method(method_name)
    end
  end
  
  # returns this object passed through the $A function of the prototype javascript library. 
  def to_js_array
    firefox_socket.object('$A').call(self)
  end
  # returns this object passed through the $H function of the prototype javascript library. 
  def to_js_hash
    firefox_socket.object('$H').call(self)
  end
  # returns this object passed through a javascript function which copies each key onto a blank object and rescues any errors. 
  def to_js_hash_safe
    firefox_socket.object('$_H').call(self)
  end
  # returns a JavascriptArray representing this object 
  def to_array
    JavascriptArray.new(self.ref, self.firefox_socket, :debug_name => debug_name)
  end
  # returns a JavascriptHash representing this object 
  def to_hash
    JavascriptHash.new(self.ref, self.firefox_socket, :debug_name => debug_name)
  end
  # returns a JavascriptDOMNode representing this object 
  def to_dom
    JavascriptDOMNode.new(self.ref, self.firefox_socket, :debug_name => debug_name)
  end

  # returns a ruby Hash. each key/value pair of this object
  # is represented in the returned hash. 
  #
  # if an error is encountered trying to access the value for an attribute, then in the 
  # returned hash, that attribute is set to the error that was encountered rather than 
  # the actual value (since the value wasn't successfully retrieved). 
  #
  # options may be specified. the only option currently supported is:
  # * :recurse => a number or nil. if it's a number, then this will recurse to that
  #   depth. If it's nil, this won't recurse at all. 
  #
  # below the specified recursion level, this will return this JavascriptObject rather than recursing
  # down into it. 
  #
  # this function isn't expected to raise any errors, since encountered errors are set as 
  # attribute values. 
  def to_ruby_hash(options={})
    options={:recurse => 1}.merge(options)
    return self if !options[:recurse] || options[:recurse]==0
    return self if self.type!='object'
    next_options=options.merge(:recurse => options[:recurse]-1)
    begin
      keys=self.to_hash.keys
    rescue FirefoxSocketError
      return self
    end
    keys.inject({}) do |hash, key|
      val=begin
        self[key]
      rescue FirefoxSocketError
        $!
      end
      hash[key]=if val.is_a?(JavascriptObject)
        val.to_ruby_hash(next_options)
      else
        val
      end
      hash
    end
  end
  
  # returns an Array in which each element is the #val_or_Object of each element of this javascript array. 
  def to_ruby_array
    self.to_array.to_a
  end
  
  # represents this javascript object in one line, displaying the type and debug name. 
  def inspect
    "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{[:type, :debug_name].map{|attr| attr.to_s+'='+send(attr).to_s}.join(', ')}>"
  end
  def pretty_print(pp) # :nodoc:
    pp.object_address_group(self) do
      pp.seplist([:type, :debug_name], lambda { pp.text ',' }) do |attr|
        pp.breakable ' '
        pp.group(0) do
          pp.text attr.to_s
          pp.text ': '
          #pp.breakable
          pp.text send(attr)
        end
      end
    end
  end
end

# represents a node on the DOM. not substantially from JavascriptObject, but #inspect 
# is more informative, and #dump is defined for extensive debug info. 
#
# This class is mostly useful for debug, not used anywhere in production at the moment. 
class JavascriptDOMNode < JavascriptObject
  def inspect_stuff # :nodoc:
    [:nodeName, :nodeType, :nodeValue, :tagName, :textContent, :id, :name, :value, :type, :className, :hidden].map do |attrn|
      attr=attr(attrn)
      if ['undefined','null'].include?(attr.type)
        nil
      else
        [attrn, attr.val_or_object(:error_on_undefined => false)]
      end
    end.compact
  end
  # returns a string with a bunch of information about this dom node 
  def inspect
    "\#<#{self.class.name} #{inspect_stuff.map{|(k,v)| "#{k}=#{v.inspect}"}.join(', ')}>"
  end
  def pretty_print(pp) # :nodoc:
    pp.object_address_group(self) do
      pp.seplist(inspect_stuff, lambda { pp.text ',' }) do |attr_val|
        pp.breakable ' '
        pp.group(0) do
          pp.text attr_val.first.to_s
          pp.text ': '
          #pp.breakable
          pp.text attr_val.last.inspect
        end
      end
    end
  end
  # returns a string (most useful when written to STDOUT or to a file) consisting of this dom node 
  # and its child nodes, recursively. each node is one line and depth is indicated by spacing. 
  #
  # call #dump(:recurse => n) to recurse down only n levels. default is to recurse all the way down the dom tree. 
  def dump(options={})
    options={:recurse => nil, :level => 0}.merge(options)
    next_options=options.merge(:recurse => options[:recurse] && (options[:recurse]-1), :level => options[:level]+1)
    result=(" "*options[:level]*2)+self.inspect+"\n"
    if options[:recurse]==0
      result+=(" "*next_options[:level]*2)+"...\n"
    else 
      self.childNodes.to_array.each do |child|
        result+=child.to_dom.dump(next_options)
      end
    end
    result
  end
end

# this class represents a javascript array - that is, a javascript object that has a 'length' 
# attribute which is a non-negative integer, and returns elements at each subscript from 0
# to less than than that length. 
class JavascriptArray < JavascriptObject
  # yields the element at each subscript of this javascript array, from 0 to self.length. 
  def each
    length=self.length
    raise FirefoxSocketJavascriptError, "length #{length.inspect} is not a non-negative integer on #{self.ref}" unless length.is_a?(Integer) && length >= 0
    for i in 0...length
      element=self[i]
      if element.is_a?(JavascriptObject)
        # yield a more permanent reference than the array subscript 
        element=element.store_rand_temp
      end
      yield element
    end
  end
  include Enumerable
end

# this class represents a hash, or 'object' type in javascript. 
class JavascriptHash < JavascriptObject
  # returns an array of keys of this javascript object 
  def keys
    @keys=firefox_socket.call_function(:obj => self){ "var keys=[]; for(var key in obj) { keys.push(key); } return keys;" }.val
  end
  # returns whether the given key is a defined key of this javascript object 
  def key?(key)
    firefox_socket.call_function(:obj => self, :key => key){ "return key in obj;" }
  end
  # yields each key and value 
  def each(&block) # :yields: key, value
    keys.each do |key|
      if block.arity==1
        yield [key, self[key]]
      else
        yield key, self[key]
      end
    end
  end
  # yields each key and value for this object 
  def each_pair
    each do |key,value|
      yield key,value
    end
  end

  include Enumerable
end

