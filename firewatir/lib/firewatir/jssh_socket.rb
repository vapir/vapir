require 'json/pure'
require 'socket'

class JsshError < StandardError; end
# This exception is thrown if we are unable to connect to JSSh.
class JsshUnableToStart < JsshError; end
class JsshUndefinedValueError < JsshError; end

class JsshSocket
  # IP Address of the machine where the script is to be executed. Default to localhost.
  JSSH_IP = "127.0.0.1"
  JSSH_PORT = 9997
  PrototypeFile=File.join(File.dirname(__FILE__), "prototype.functional.js")

  DEFAULT_SOCKET_TIMEOUT=1
  LONG_SOCKET_TIMEOUT=32
  SHORT_SOCKET_TIMEOUT=(2**-16).to_f
  

  attr_reader :ip, :port, :prototype
  
  # Connects a new socket to jssh
  # Takes options:
  # * :jssh_ip => the ip to connect to, default 127.0.0.1
  # * :jssh_port => the port to connect to, default 9997
  # * :send_prototype => true|false, whether to load and send the Prototype library (the functional programming part of it anyway, and JSON bits)
  def initialize(options={})
    @ip=options[:jssh_ip] || JSSH_IP
    @port=options[:jssh_port] || JSSH_PORT
    @prototype=options.key?(:send_prototype) ? options[:send_prototype] : true
    no_of_tries = 0
#    begin
      @socket = TCPSocket::new(@ip, @port)
#    rescue
#      no_of_tries += 1
#      retry if no_of_tries < 3
#      raise JsshUnableToStart, "Unable to connect to IP : #{@ip} on port #{@port}. Make sure that JSSh is properly installed and Firefox is running with '-jssh' option"
#    end
    @socket.sync = true
    eat="Welcome to the Mozilla JavaScript Shell!"
    eaten=""
    while eat!=eaten
      ret=read_socket(LONG_SOCKET_TIMEOUT)
      if !ret
        raise JsshError, "Something went wrong initializing - no response (already ate #{eaten.inspect})" 
      elsif ret != eat[0...ret.length]
        raise JsshError, "Something went wrong initializing - message #{ret.inspect} != #{eat[0...ret.length].inspect}" 
      end
      eaten+=ret
    end
    if @prototype
      send(File.read(PrototypeFile))
      ret=read_socket(LONG_SOCKET_TIMEOUT)
      raise JsshError, "Something went wrong loading Prototype - message #{ret.inspect}" if ret != "done!"
    end
  end

  # sends the given message to the jssh socket. one usually wants to use less low-level stuff than this; this may 
  # become private. 
  def send(mesg, flags=0)
#    STDERR.puts "calling send on a JsshSocket directly is deprecated. From:\n"
#    caller.each{|c| STDERR.puts "\t"+c}
    @socket.send mesg, flags
  end
  
  # reads data from the socket until it is done being ready. ("done being ready" is defined as, it isn't ready 
  # for recv to be called for more stuff, following the first send of whatever arbitrary number of bytes, 
  # after SHORT_SOCKET_TIMEOUT). times out (waiting for an initial recv from the socket) after the given number 
  # of seconds, default is DEFAULT_SOCKET_TIMEOUT. 
  #
  # usually you will want read_value though. or value, which takes an expression. or value_json, which actually
  # deals with data types. 
  def recv_socket(timeout=DEFAULT_SOCKET_TIMEOUT)
    received_any=false
    received_data = ""
    data = ""
    while(s= Kernel.select([@socket] , nil , nil, timeout))
      timeout=SHORT_SOCKET_TIMEOUT
      received_any=true
      data = @socket.recv(1024)
      received_data += data
    end
    received_any ? received_data : nil
  end

  # reads from the socket and returns what seems to be the value that should be returned, by stripping prompts 
  # from the beginning and end. 
  # 
  # does not deal with prompts in between values, because attempting to parse those out is impossible, it being
  # perfectly possible that a string the same as the prompt is part of actual data. (even stripping it from the 
  # ends of the string is not entirely certain; data could have it at the ends too, but that's the best that can
  # be done.) so, read_value should be called after every line, or you can end up with stuff like:
  # >> jssh_socket.send "3\n4\n5\n"
  # => 6
  # >> jssh_socket.read_socket
  # => "3\n> 4\n> 5"
  def read_value(timeout=DEFAULT_SOCKET_TIMEOUT)
    if(value=recv_socket(timeout))
      #Remove the command prompt. Every result returned by JSSH has "\n> " at the end.
      value.sub!(/\A\n?> /, '')
      value.sub!(/\n?\n> \z/, '')
      return value
    else
      return nil
    end
  end
  alias read_socket read_value # really this shouldn't be called read_socket, but it is for backward compatibility 

  # Evaluate javascript and return result. Raise an exception if an error occurred.
  # Takes one expression and strips out newlines so that only one value will be returned, so you're going to have to
  # use semicolons, and no // style comments. 
  # If you're sure that you only have one line-ending expression, you can dump it into send (for now. maybe that will
  # go away, maybe there will be something to replace it.) 
  def js_eval(str, timeout=DEFAULT_SOCKET_TIMEOUT)
    if (leftover=recv_socket(SHORT_SOCKET_TIMEOUT)) && leftover != "\n> "
      STDERR.puts("WARNING: value(s) #{leftover.inspect} left on #{self.inspect}")
    end
    str=str.to_s.gsub("\n","")
    str=str+"\n" unless str =~ /\n\z/
    @socket.send(str, 0)
    value = read_socket(timeout)
    if md = /^(\w+)Error:(.*)$/.match(value)
      errclassname="JsshJavascript#{md[1]}Error"
      unless JsshSocket.const_defined?(errclassname)
        JsshSocket.const_set(errclassname, Class.new(JsshError))
      end
      raise JsshSocket.const_get(errclassname), "#{md[2]} - evaluating #{str.inspect}"
    end
    value
  end

  # returns the value of the given javascript expression, as reported by JSSH. 
  # This will be a string, the given expression's toString. Uses #js_eval; see its documentation.
  def value(js)
    js_eval(js)
  end
  
  # assigns to the javascript reference on the left the javascript expression on the right. 
  # returns the value of the expression as reported by JSSH, which
  # will be a string, the expression's toString. Uses #js_eval; see its documentation.
  def assign(js_left, js_right)
    js_eval("#{js_left}= #{js_right}")
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments (javascript expressions). returns the return value of the function,
  # a string, the toString of the javascript value. Uses #js_eval; see its documentation.
  def call(js_function, *js_args)
    js_eval("#{js_function}(#{js_args.join(', ')})")
  end
  
  # if the given javascript expression ends with an = symbol, #handle calls to #assign 
  # assuming it is given one argument; if the expression refers to a function, calls 
  # that function with the given arguments using #call; if the expression is some other 
  # value, returns that value (its javascript toString), calling #value, assuming 
  # given no arguments. Uses #js_eval; see its documentation.
  def handle(js_expr, *args)
    if js_expr=~/=\z/ # doing assignment
      js_left=$`
      if args.size != 1
        raise ArgumentError, "Assignment (#{js_expr}) must take one argument"
      end
      assign(js_left, *args)
    else
      type=typeof(js_expr)
      case type
      when "function"
        call(js_expr, *args)
      when "undefined"
        raise JsshUndefinedValueError, "undefined expression #{js_expr.inspect}"
      else
        if !args.empty?
          raise ArgumentError, "Cannot pass arguments to expression #{js_expr.inspect} of type #{type}"
        end
        value(js_expr)
      end
    end
  end

  # returns the value of the given javascript expression. Assuming that it can
  # be converted to JSON, will return the equivalent ruby data type to the javascript
  # value. Uses #js_eval; see its documentation.
  def value_json(js)
    ensure_prototype
    parse_json(value("Object.toJSON(#{js})"))
  end
  
  # assigns to the javascript reference on the left the object on the right. 
  # Assuming the right object can be converted to JSON, the javascript value will 
  # be the equivalent javascript data type to the ruby object. Will return 
  # the assigned value, converted from its javascript value back to ruby. So, the return
  # value won't be exactly equivalent if you use symbols for example. 
  #
  # >> jssh_socket.assign_json('bar', {:foo => [:baz, 'qux']})
  # => {"foo"=>["baz", "qux"]}
  #
  # Uses #js_eval; see its documentation.
  def assign_json(js_left, rb_right)
    ensure_prototype
    js_right=rb_right.to_json
    parse_json(value("Object.toJSON(#{js_left}=#{js_right})"))
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments, each argument being converted from a ruby object to a javascript object
  # via JSON. returns the return value of the function, of equivalent type to the javascript 
  # return value, converted from javascript to ruby via JSON. 
  # Uses #js_eval; see its documentation.
  def call_json(js_function, *rb_args)
    ensure_prototype
    js_args=rb_args.map{|arg| arg.to_json}
    parse_json(value("Object.toJSON(#{js_function}(#{js_args.join(', ')}))"))
  end

  # does the same thing as #handle, but with json, calling #assign_json, #value_json, 
  # or #call_json. 
  # if the given javascript expression ends with an = symbol, #handle_json calls to 
  # #assign_json assuming it is given one argument; if the expression refers to a function, 
  # calls that function with the given arguments using #call_json; if the expression is 
  # some other value, returns that value, converted to ruby via JSON, assuming given no 
  # arguments. Uses #js_eval; see its documentation.
  def handle_json(js_expr, *args)
    ensure_prototype
    if js_expr=~/=\z/ # doing assignment
      js_left=$`
      if args.size != 1
        raise ArgumentError, "Assignment (#{js_expr}) must take one argument"
      end
      assign_json(js_left, *args)
    else
      type=typeof(js_expr)
      case type
      when "function"
        call_json(js_expr, *args)
      when "undefined"
        raise JsshUndefinedValueError, "undefined expression #{js_expr}"
      else
        if !args.empty?
          raise ArgumentError, "Cannot pass arguments to expression #{js_expr.inspect} of type #{type}"
        end
        value_json(js_expr)
      end
    end
  end
  
  # raises error if the prototype library (needed for JSON stuff in javascript) has not been loaded
  def ensure_prototype
    unless prototype
      raise JsshError, "Cannot invoke JSON on a Jssh session that does not have the Prototype library"
    end
  end

  # returns the type of the given expression. Uses #js_eval; see its documentation.
  def typeof(expression)
    js_eval("typeof(#{expression})")
  end

  # sticks a json string inside array brackets because on windows (at least?) 
  # the ruby json library craps out on some stuff. 
  #
  # >> JSON.parse('3')
  # JSON::ParserError: A JSON text must at least contain two octets!
  # >> JSON.parse('333')
  # JSON::ParserError: 618: unexpected token at '333'
  # >> JSON.parse('""')
  # JSON::ParserError: 618: unexpected token at '""'
  # >> JSON.parse('[]')
  # => []
  def parse_json(json)
    raise JSON::ParserError, "Blank string!" if json==''
    return *JSON.parse("["+json+"]")
  end

  def object(ref)
    JsshObject.new(ref, self)
  end
end

class JsshObject
  attr_reader :ref, :jssh_socket
  attr_accessor :function_result
  
  # initializes a JsshObject with a string of javascript containing a reference to
  # the object, and a  JsshSocket that the object is defined on. 
  def initialize(ref, jssh_socket)
    raise JsshError, "Empty object reference!" if !ref || ref==''
    raise ArgumentError, "Not given a JsshSocket, instead given #{jssh_socket.inspect}" unless jssh_socket.is_a?(JsshSocket)
    @ref=ref
    @jssh_socket=jssh_socket
  end
  
  # returns the value, via JsshSocket#value_json
  def val
    jssh_socket.value_json(ref)
  end

  # returns the value just as a string with no attempt to deal with type using json. via JsshSocket#value 
  def val_str
    jssh_socket.value(ref)
  end

  # returns javascript typeof this object 
  def type
    @type ||= jssh_socket.typeof(ref)
  end
  
  # returns the type of object that is reported by the javascript toString() method, which
  # returns such as "[object Object]" or "[object XPCNativeWrapper [object HTMLDocument]]"
  # This method returns 'Object' or 'XPCNativeWrapper [object HTMLDocument]' respectively.
  # Raises an error if this JsshObject points to something other than a javascript 'object'
  # type ('function' or 'number' or whatever)
  def object_type
    type=self.type
    case type
    when 'object'
      self.toString.val =~ /\A\[object\s+(.*)\]\Z/
      $1
    else
      raise JsshError, "Type is #{type}, not object"
    end
  end
  
  # returns a JsshObject representing the given attribute. Checks the type, and if 
  # it is a function, references the _return value_ of the function (with the given
  # arguments, if any, which are in ruby, converted to_json). If undefined, raises an 
  # error (if you want an attribute even if it's undefined, use #attr). 
  def get(attribute, *args)
    attr_obj=attr(attribute)
    type=attr_obj.type
    case type
    when 'function'
      attr_obj.pass(*args)
    when 'undefined'
      raise JsshUndefinedValueError, "undefined expression #{attr_obj.ref}"
    else
      if args.empty?
        attr_obj
      else
        raise ArgumentError, "Cannot pass arguments to expression #{attr_obj.ref} of type #{type}"
      end
    end
  end
  
  # returns a JsshObject referencing the given attribute of this object 
  def attr(attribute)
    JsshObject.new("#{ref}.#{attribute}", jssh_socket)
  end

  # returns a JsshObject referring to a subscript of this object, specified as a _javascript_ expression 
  # (doesn't use to_json) 
  def sub(key)
    JsshObject.new("#{ref}[#{key}]", jssh_socket)
  end

  # returns a JsshObjct referring to a subscript of this object, specified as ruby (convert to_json) 
  def [](key)
    sub(key.to_json)
  end
  # assigns the given ruby value (passed through json via JsshSocket#assign_json) to the given subscript
  # (key is converted to_json). 
  def []=(key, value)
    self[key].assign(value)
  end

  # assigns the given ruby value (passed through json via JsshSocket#assign_json) to the reference
  # for this object
  def assign(val)
    jssh_socket.assign_json(ref, val)
  end
  # assigns the given javascript expression (string) to the reference for this object 
  def assign_expr(val)
    jssh_socket.assign(ref, val)
  end
  
  # returns a JsshObject for this object - assumes that this object is a function - passing 
  # this function the specified arguments, which are converted to_json
  def pass(*args)
    obj=JsshObject.new("#{ref}(#{args.map{|arg| arg.to_json}.join(', ')})", jssh_socket)
    obj.function_result=true
    obj
  end
  
  # returns the value (via JsshSocket#value_json) of the return value of this function
  # (assumes this object is a function) passing it thet given arguments (which are converted to_json). 
  # simply, it just calls self.pass(*args).val 
  def call(*args)
    pass(*args).val
  end
  
  # sets the given javascript variable to this object, and returns a JsshObject referring
  # to the variable. 
  #
  # >> foo=document.getElementById('guser').store('foo')
  # => #<JsshObject:0x2dff870 @ref="foo" ...>
  # >> foo.tagName!
  # => "DIV"
  def store(js_variable)
    stored=JsshObject.new(js_variable, jssh_socket)
    stored.assign_expr(self.ref)
    stored.function_result=false
    stored
  end

  # method_missing handles unknown method calls in a way that makes it possible to write 
  # javascript-like syntax in ruby, to some extent. 
  # 
  # if doing assignment (method ends with = ), calls JsshSocket#assign_json to do the assignment 
  # and returns the assigned value. 
  #
  # otherwise, calls #get to return a JsshObject. 
  #
  # now, #get always returns a JsshObject. this means that you can string together method_missings.
  # but at some point you will want a value out of the expression. 
  # at that point you can either call #val, or you can stick a ! at the end of the method and 
  # method_missing will call #val
  # you can add a ? to call #val_str - this is safer, because the javascript conversion to json 
  # can error. This also catches the JsshUndefinedValueError that #get throws and just returns nil
  # for undefined stuff. 
  #
  # method_missing doesn't deal with anything other than methods named with alphanumeric or underscores. 
  # no special characters, except for =, !, or ? at the end. 
  #
  # this lets you do things like:
  # >> jssh_socket.object('getWindows()').length!
  # => 2
  # >> jssh_socket.object('getWindows()')[1].getBrowser.contentDocument?
  # => "[object XPCNativeWrapper [object HTMLDocument]]"
  # >> document=jssh_socket.object('getWindows()')[1].getBrowser.contentDocument
  # => #<JsshObject:0x34f01fc @ref="getWindows()[1].getBrowser().contentDocument" ...>
  # >> document.title!
  # => "ruby - Google Search"
  # >> document.forms[0].q.value!
  # => "ruby"
  # >> document.forms[0].q.value='foobar'
  # => "foobar"
  # >> document.forms[0].q.value!
  # => "foobar"
  def method_missing(method, *args)
    method=method.to_s
    if method =~ /^([a-z_][a-z0-9_]*)([=?!])?$/i
      method = $1
      special = $2
    else # don't deal with any special character crap 
      Object.instance_method(:method_missing).bind(self).call(method, *args) # let Object#method_missing raise its usual error 
    end
    case special
    when nil
      get(method, *args)
    when '!'
      get(method, *args).val
    when '?'
      begin
        get(method, *args).val_str
      rescue JsshUndefinedValueError
        nil
      end
    when '='
      jssh_socket.assign_json("#{ref}.#{method}", *args)
    else
      Object.instance_method(:method_missing).bind(self).call(method, *args) # this shouldn't happen 
    end
  end
  
  # okay, so it's not actually json, but it makes it so that when #to_json is called, it gets the reference
  # instead of '#<JsshObject:0x2de5524>'
  def to_json
    ref
  end
end
