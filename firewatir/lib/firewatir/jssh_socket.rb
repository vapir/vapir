require 'json/pure'
require 'socket'
require 'logger'

class JsshError < StandardError
  attr_accessor :source, :lineNumber, :stack, :fileName
end
# This exception is thrown if we are unable to connect to JSSh.
class JsshUnableToStart < JsshError; end
class JsshUndefinedValueError < JsshError; end

class JsshSocket
  def self.logger
    @@logger||=begin
      logger=Logger.new nil#(File.join('c:/tmp/jssh_log.txt'))
      logger.level = Logger::DEBUG
      logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      logger.formatter=Logger::Formatter.new
      logger
    end
  end
  def logger
    self.class.logger
  end
  
  PROMPT="\n> "
  
  # IP Address of the machine where the script is to be executed. Default to localhost.
  JSSH_IP = "127.0.0.1"
  JSSH_PORT = 9997
  PrototypeFile=File.join(File.dirname(__FILE__), "prototype.functional.js")

  DEFAULT_SOCKET_TIMEOUT=16
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
    @socket = TCPSocket::new(@ip, @port)
    @socket.sync = true
    eat="Welcome to the Mozilla JavaScript Shell!"
    eaten=""
    while eat!=eaten
      ret=read_socket(LONG_SOCKET_TIMEOUT).chomp
      expect=eat[eaten.length...ret.length]
      if !ret
        raise JsshError, "Something went wrong initializing - no response (already received #{eaten.inspect})" 
      elsif ret != expect
        raise JsshError, "Something went wrong initializing - message #{ret.inspect} != #{expect.inspect}" 
      end
      eaten+=ret
    end
    if @prototype
      ret=send_and_read(File.read(PrototypeFile), LONG_SOCKET_TIMEOUT)
      raise JsshError, "Something went wrong loading Prototype - message #{ret.inspect}" if ret != "done!"
    end
    temp_object.assign({})
  end

  # sends the given message to the jssh socket. one usually wants to use less low-level stuff than this; this may 
  # become private. 
  def send(mesg, flags=0)
    raise NotImplementedError, "send is gone. use send_and_read, or, preferably, something better"
#    STDERR.puts "calling send on a JsshSocket directly is deprecated. From:\n"
#    caller.each{|c| STDERR.puts "\t"+c}
#    @socket.send mesg, flags
  end
  
  # reads data from the socket until it is done being ready. ("done being ready" is defined as Kernel.select saying
  # it isn't ready immediately (zero timeout)).
  # times out (waiting for an initial recv from the socket) after the given number 
  # of seconds, default is DEFAULT_SOCKET_TIMEOUT. 
  #
  # usually you will want read_value though. or value, which takes an expression. or value_json, which actually
  # deals with data types. 
  def recv_socket(timeout=DEFAULT_SOCKET_TIMEOUT)
    received_data = []
    data = ""
    logger.debug "RECV_SOCKET is starting. timeout=#{timeout}"
    while(s= Kernel.select([@socket] , nil , nil, timeout))
      data = @socket.recv(1024)
      unless data==PROMPT && received_data.empty? # if we recv PROMPT here (first thing recv'd), then switch to zero timeout, then the value will probably get left on the socket 
        timeout=0.0
      end
      received_data << data
      logger.debug "RECV_SOCKET is continuing. timeout=#{timeout}; data=#{data.inspect}"
    end
    logger.debug "RECV_SOCKET is done. received_data=#{received_data.inspect}"
    received_data.pop if received_data.last==PROMPT
    received_data.shift if received_data.first==PROMPT
    received_data.empty? ? nil : received_data.join('')
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
    value= send_and_read(str.gsub("\n",""), timeout)
    if md = /\A(\w+Error):(.*)/m.match(value)
      js_error(md[1], md[2], str)
    elsif md = /\Auncaught exception: (.*)/m.match(value)
      js_error(nil, md[1], str)
    end
    value
  end

  def send_and_read(js_expr, timeout=DEFAULT_SOCKET_TIMEOUT)
    logger.debug "SEND_AND_READ is starting. timeout=#{timeout}"
    logger.debug "SEND_AND_READ is checking for leftovers"
    if (leftover=recv_socket(SHORT_SOCKET_TIMEOUT)) && leftover != PROMPT
      STDERR.puts("WARNING: value(s) #{leftover.inspect} left on #{self.inspect}. last evaluated thing was: #{@last_expression}")
      logger.warn("SEND_AND_READ: value(s) #{leftover.inspect} left on jssh socket. last evaluated thing was: #{@last_expression}")
    end
    @last_expression=js_expr
    js_expr=js_expr+"\n" unless js_expr =~ /\n\z/
    logger.debug "SEND_AND_READ sending #{js_expr.inspect}"
    @socket.send(js_expr, 0)
    return read_socket(timeout)
  end
  
  def js_error(errclassname, message, source, stuff={})
    errclass=if errclassname
      unless JsshSocket.const_defined?(errclassname)
        JsshSocket.const_set(errclassname, Class.new(JsshError))
      end
      JsshSocket.const_get(errclassname)
    else
      JsshError
    end
    err=errclass.new(message+"\nEvaluating:\n#{source}\n\nOther stuff:\n#{stuff.inspect}")
    err.source=source
    ["lineNumber", "stack", "fileName"].each do |attr|
      if stuff.key?(attr)
        err.send(:"#{attr}=", stuff[attr])
      end
    end
    raise err
  end

  # returns the value of the given javascript expression, as reported by JSSH. 
  # This will be a string, the given expression's toString. 
  def value(js)
    send_and_read("(function(){return #{js}})()")
  end
  
  # assigns to the javascript reference on the left the javascript expression on the right. 
  # returns the value of the expression as reported by JSSH, which
  # will be a string, the expression's toString. Uses #js_eval; see its documentation.
  def assign(js_left, js_right)
    value("#{js_left}= #{js_right}")
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments (javascript expressions). returns the return value of the function,
  # a string, the toString of the javascript value. Uses #js_eval; see its documentation.
  def call(js_function, *js_args)
    value("#{js_function}(#{js_args.join(', ')})")
  end
  
  # if the given javascript expression ends with an = symbol, #handle calls to #assign 
  # assuming it is given one argument; if the expression refers to a function, calls 
  # that function with the given arguments using #call; if the expression is some other 
  # value, returns that value (its javascript toString), calling #value, assuming 
  # given no arguments. Uses #value; see its documentation.
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
  # value. Will raise an error if the javascript errors. 
  def value_json(js, options={})
    options={:error_on_undefined => true}.merge(options)
    ensure_prototype
    wrapped_js=
      "try
       { var result_f=(function(){return #{js}});
         var result=result_f();
         if((typeof result) == 'undefined' && #{options[:error_on_undefined].to_json})
         { throw({'name': 'ReferenceError',
                  'message': 'undefined expression in: '+result_f.toString()
                 });
         }
         Object.toJSON([false, result]);
       }catch(e)
       { Object.toJSON([true, e]);
       }"
    val=send_and_read(wrapped_js)
    errord_and_val=*parse_json(val)
    unless errord_and_val.length==2
      raise RuntimeError, "unexpected result: \n\t#{errord_and_val.inspect} \nencountered parsing value: \n\t#{val.inspect} \nreturned from expression: \n\t#{js.inspect}"
    end
    errord,val= *errord_and_val
    if errord
      case val
      when Hash
        js_error(val['name'],val['message'],js,val)
      when String
        js_error(nil, val, js)
      else
        js_error(nil, val.inspect, js)
      end
    else
      val
    end
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
  # Uses #value_json; see its documentation.
  def assign_json(js_left, rb_right)
    ensure_prototype
    js_right=rb_right.to_json
    value_json("#{js_left}=#{js_right}")
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments, each argument being converted from a ruby object to a javascript object
  # via JSON. returns the return value of the function, of equivalent type to the javascript 
  # return value, converted from javascript to ruby via JSON. 
  # Uses #value_json; see its documentation.
  def call_json(js_function, *rb_args)
    ensure_prototype
    js_args=rb_args.map{|arg| arg.to_json}
    value_json("#{js_function}(#{js_args.join(', ')})")
  end

  # does the same thing as #handle, but with json, calling #assign_json, #value_json, 
  # or #call_json. 
  # if the given javascript expression ends with an = symbol, #handle_json calls to 
  # #assign_json assuming it is given one argument; if the expression refers to a function, 
  # calls that function with the given arguments using #call_json; if the expression is 
  # some other value, returns that value, converted to ruby via JSON, assuming given no 
  # arguments. Uses #value_json; see its documentation.
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

  # returns the type of the given expression using javascript typeof operator, with the exception that
  # if the expression is null, returns 'null' - whereas typeof(null) in javascript returns 'object'
  def typeof(expression)
    # this approach evaluates the expression twice if it === null. that is no good. 
    #value_json("(function(){type=typeof(#{expression});return (#{expression}===null) ? 'null' : type;})()")
    
    # this approach errors (in javascript) if expression is undefined. no good. 
    #type,isnull = *value_json("(function(expr){return [typeof(expr), expr===null];})(#{expression})")
    #isnull ? 'null' : type
    
    # this approach, combining the above and handling errors, seems to work. 
    js="(function()
        { try
          { return (function(expr)
            { type=typeof(expr);
              return (expr===null) ? 'null' : type;
            })(#{expression});
          }catch(e)
          { if(e.name=='ReferenceError')
            { return 'undefined';
            }
            else
            { throw(e);
            }
          }
        })()"
    type=value_json js
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
    raise JSON::ParserError, "Not a string! got: #{json.inspect}" unless json.is_a?(String)
    raise JSON::ParserError, "Blank string!" if json==''
    begin
      return *JSON.parse("["+json+"]")
    rescue JSON::ParserError
      $!.message += "\nParsing: #{json.inspect}"
      raise
    end
  end

  def object(ref)
    JsshObject.new(ref, self)
  end
  
  def temp_object
    @temp_object ||= object('JsshTemp')
  end
end

class JsshObject
  attr_reader :ref, :jssh_socket
  attr_reader :function_result
  attr_reader :type
  protected
  def type=(type)
    @type=type
  end
  def function_result=(fr)
    @function_result=fr
  end

  public
  # initializes a JsshObject with a string of javascript containing a reference to
  # the object, and a  JsshSocket that the object is defined on. 
  def initialize(ref, jssh_socket)
    raise ArgumentError, "Empty object reference!" if !ref || ref==''
    raise ArgumentError, "Reference must be a string - got #{ref.inspect}" unless ref.is_a?(String)
    raise ArgumentError, "Not given a JsshSocket, instead given #{jssh_socket.inspect}" unless jssh_socket.is_a?(JsshSocket)
    @ref=ref
    @jssh_socket=jssh_socket
  end
  
  # returns the value, via JsshSocket#value_json
  def val
    jssh_socket.value_json(ref, :error_on_undefined => !function_result)
  end

  # returns the value just as a string with no attempt to deal with type using json. via JsshSocket#value 
  #
  # note that this can be slow if it evaluates to a blank string. for example, if ref is just ""
  # then JsshSocket#value will wait DEFAULT_SOCKET_TIMEOUT seconds for data that is not to come. 
  # this also happens with functions that return undefined. if ref="function(){do_some_stuff;}" 
  # (with no return), it will also wait DEFAULT_SOCKET_TIMEOUT. 
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
    @object_type ||= begin
      case type
      when 'object'
        self.toString! =~ /\A\[object\s+(.*)\]\Z/
        $1
      else
        raise JsshError, "Type is #{type}, not object"
      end
    end
  end
  
  def val_or_object(options={})
    options={:error_on_undefined=>true}.merge(options)
    if function_result # calling functions multiple times is bad, so store in temp before figuring out what to do with it
      store_rand_object_key(jssh_socket.temp_object).val_or_object(:error_on_undefined => false)
    else
      case self.type
      when 'undefined'
        if function_result
          nil
        elsif !options[:error_on_undefined]
          self
        else
          raise JsshUndefinedValueError, "undefined expression #{ref}"
        end
      when 'boolean','number','string','null'
        val
      when 'function','object'
        self
      else
        # here we perhaps could (but won't for now) raise JsshError, "Unknown type: #{type}"
        self
      end
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
      attr_obj.pass(*args).val_or_object
    else
      if args.empty?
        attr_obj.val_or_object
      else
        raise ArgumentError, "Cannot pass arguments to expression #{attr_obj.ref} of type #{type}"
      end
    end
  end
  
  # returns a JsshObject referencing the given attribute of this object 
  def attr(attribute)
    JsshObject.new("#{ref}.#{attribute}", jssh_socket)
  end

  # assigns (via JsshSocket#assign) the given ruby value (converted to_json) to the reference
  # for this object. returns self. 
  def assign(val)
    assign_expr val.to_json
  end
  # assigns the given javascript expression (string) to the reference for this object 
  def assign_expr(val)
    jssh_socket.value_json("(function(val){#{ref}=val; return null;}(#{val}))")
    # don't want to use JsshSocket#assign_json because converting the assignment to json is error-prone and we don't really care. 
    # don't want to use JsshSocket#assign because the result can be blank and cause send_and_read to wait for data that's not coming - also 
    # using a json function is better because it catches errors much more elegantly. 
    # so, wrap it in a function that returns nil. 
    self
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
  # >> foo.tagName
  # => "DIV"
  def store(js_variable)
    stored=JsshObject.new(js_variable, jssh_socket)
    stored.assign_expr(self.ref)
    stored.function_result=false
    stored
  end
  
  def store_rand_named(&name_proc)
    begin
      name=name_proc.call("%.16x"%rand(2**64))
    end while JsshObject.new(name,jssh_socket).type!='undefined'
    # okay, more than one iteration is ridiculously unlikely, sure, but just to be safe. 
    store(name)
  end
  
  def store_rand_prefix(prefix)
    store_rand_named do |r|
      prefix+"_"+r
    end
  end

  def store_rand_object_key(object)
    raise ArgumentError("Object is not a JsshObject: got #{object.inspect}") unless object.is_a?(JsshObject)
    store_rand_named do |r|
      object.sub(r).ref
    end
  end

  def sub_expr(key_expr)
    JsshObject.new("#{ref}[#{key_expr}]", jssh_socket)
  end
  
  # returns a JsshObject referring to a subscript of this object, specified as a _javascript_ expression 
  # (doesn't use to_json) 
  def sub(key)
    sub_expr(key.to_json)
  end

  # returns a JsshObject referring to a subscript of this object, or a value if it is simple (see #val_or_object)
  # subscript is specified as ruby (converted to_json). 
  def [](key)
    sub(key).val_or_object(:error_on_undefined => false)
  end
  # assigns the given ruby value (passed through json via JsshSocket#assign_json) to the given subscript
  # (key is converted to_json). 
  def []=(key, value)
    self.sub(key).assign(value)
  end

  # calls a binary operator with self and another operand 
  def binary_operator(operator, operand)
    JsshObject.new("(#{ref}#{operator}#{operand.to_json})", jssh_socket).val_or_object
  end
  def +(operand)
    binary_operator('+', operand)
  end
  def -(operand)
    binary_operator('-', operand)
  end
  def /(operand)
    binary_operator('/', operand)
  end
  def *(operand)
    binary_operator('*', operand)
  end
  def %(operand)
    binary_operator('%', operand)
  end
  def ==(operand)
    binary_operator('==', operand)
  end
  def >(operand)
    binary_operator('>', operand)
  end
  def <(operand)
    binary_operator('<', operand)
  end
  def >=(operand)
    binary_operator('>=', operand)
  end
  def <=(operand)
    binary_operator('<=', operand)
  end
  
  # method_missing handles unknown method calls in a way that makes it possible to write 
  # javascript-like syntax in ruby, to some extent. 
  #
  # method_missing will only try to deal with methods that look like /^[a-z_][a-z0-9_]*$/i - no
  # special characters, only alphanumeric/underscores, starting with alpha or underscore - with
  # the exception of three special behaviors:
  # 
  # If the method ends with an equals sign (=), it does assignment - it calls JsshSocket#assign_json 
  # to do the assignment and returns the assigned value. 
  #
  # If the method ends with a bang (!), then it will attempt to get the value (using json) of the
  # reference, using JsonObject#val. For simple types (null, string, boolean, number), this is what 
  # happens by default anyway, but if you have an object or an array that you know you can json-ize, 
  # you can use ! to force that. See #get documentation  for more information. 
  #
  # If the method ends with a question mark (?), then it will attempt to get a string representing the
  # value, using JsonObject#val_str. This is safer than ! because the javascript conversion to json 
  # can error. This also catches the JsshUndefinedValueError that can occur, and just returns nil
  # for undefined stuff. 
  #
  # otherwise, method_missing calls to #get, and returns a JsshObject, a string, a boolean, a number, or
  # null - see documentation for #get. 
  #
  # Since #get returns a JsshObject for javascript objects, this means that you can string together 
  # method_missings and the result looks rather like javascript.
  #
  # this lets you do things like:
  # >> jssh_socket.object('getWindows()').length
  # => 2
  # >> jssh_socket.object('getWindows()')[1].getBrowser.contentDocument?
  # => "[object XPCNativeWrapper [object HTMLDocument]]"
  # >> document=jssh_socket.object('getWindows()')[1].getBrowser.contentDocument
  # => #<JsshObject:0x34f01fc @ref="getWindows()[1].getBrowser().contentDocument" ...>
  # >> document.title
  # => "ruby - Google Search"
  # >> document.forms[0].q.value
  # => "ruby"
  # >> document.forms[0].q.value='foobar'
  # => "foobar"
  # >> document.forms[0].q.value
  # => "foobar"
  #
  # $A and $H, used below, are methods of the Prototype javascript library, which add nice functional 
  # methods to arrays and hashes - see http://www.prototypejs.org/
  # You can use these methods with method_missing just like any other:
  #
  # >> js_hash=jssh_socket.object('$H')
  # => #<JsshObject:0x2beb598 @ref="$H" ...>
  # >> js_arr=jssh_socket.object('$A')
  # => #<JsshObject:0x2be40e0 @ref="$A" ...>
  #
  # >> js_arr.pass(document.body.childNodes).pluck! :tagName
  # => ["TEXTAREA", "DIV", "NOSCRIPT", "DIV", "DIV", "DIV", "BR", "TABLE", "DIV", "DIV", "DIV", "TEXTAREA", "DIV", "DIV", "SCRIPT"]
  # >> js_arr.pass(document.body.childNodes).pluck! :id
  # => ["csi", "header", "", "ssb", "tbd", "res", "", "nav", "wml", "", "", "hcache", "xjsd", "xjsi", ""]
  # >> js_hash.pass(document.getElementById('tbd')).keys!
  # => ["addEventListener", "appendChild", "className", "parentNode", "getElementsByTagName", "title", "style", "innerHTML", "nextSibling", "tagName", "id", "nodeName", "nodeValue", "nodeType", "childNodes", "firstChild", "lastChild", "previousSibling", "attributes", "ownerDocument", "insertBefore", "replaceChild", "removeChild", "hasChildNodes", "cloneNode", "normalize", "isSupported", "namespaceURI", "prefix", "localName", "hasAttributes", "getAttribute", "setAttribute", "removeAttribute", "getAttributeNode", "setAttributeNode", "removeAttributeNode", "getAttributeNS", "setAttributeNS", "removeAttributeNS", "getAttributeNodeNS", "setAttributeNodeNS", "getElementsByTagNameNS", "hasAttribute", "hasAttributeNS", "ELEMENT_NODE", "ATTRIBUTE_NODE", "TEXT_NODE", "CDATA_SECTION_NODE", "ENTITY_REFERENCE_NODE", "ENTITY_NODE", "PROCESSING_INSTRUCTION_NODE", "COMMENT_NODE", "DOCUMENT_NODE", "DOCUMENT_TYPE_NODE", "DOCUMENT_FRAGMENT_NODE", "NOTATION_NODE", "lang", "dir", "align", "offsetTop", "offsetLeft", "offsetWidth", "offsetHeight", "offsetParent", "scrollTop", "scrollLeft", "scrollHeight", "scrollWidth", "clientTop", "clientLeft", "clientHeight", "clientWidth", "tabIndex", "contentEditable", "blur", "focus", "spellcheck", "removeEventListener", "dispatchEvent", "baseURI", "compareDocumentPosition", "textContent", "isSameNode", "lookupPrefix", "isDefaultNamespace", "lookupNamespaceURI", "isEqualNode", "getFeature", "setUserData", "getUserData", "DOCUMENT_POSITION_DISCONNECTED", "DOCUMENT_POSITION_PRECEDING", "DOCUMENT_POSITION_FOLLOWING", "DOCUMENT_POSITION_CONTAINS", "DOCUMENT_POSITION_CONTAINED_BY", "DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC", "getElementsByClassName", "getClientRects", "getBoundingClientRect"]
  #
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
      got=get(method, *args)
      got.is_a?(JsshObject) ? got.val : got
    when '?'
      begin
        got=get(method, *args)
        got.is_a?(JsshObject) ? got.val_str : got
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
  
  def to_js_array
    jssh_socket.object('$A').pass(self)
  end
  def to_js_hash
    jssh_socket.object('$H').pass(self)
  end
  def to_js_hash_safe
    jssh_socket.object('$_H').pass(self)
  end
  def to_array
    JsshArray.new(self.ref, self.jssh_socket)
  end
  def to_hash
    JsshHash.new(self.ref, self.jssh_socket)
  end
end


class JsshArray < JsshObject
  def each
    length=self.length
    raise JsshError, "length #{length.inspect} is not a non-negative integer on #{self.ref}" unless length.is_a?(Integer) && length >= 0
    for i in 0...length
      yield self[i]
    end
  end
  include Enumerable
  def to_json # Enumerable clobbers this; redefine
    ref
  end
end

class JsshHash < JsshObject
  def keys
    keyfunc="function(obj)
             { var keys=[];
               for(var key in obj)
               { keys.push(key);
               }
               return keys;
             }"
    @keys=jssh_socket.object(keyfunc).call(self)
  end
  def each
    keys.each do |key|
      yield [key, self[key]]
    end
  end
  def each_pair
    each do |(k,v)|
      yield k,v
    end
  end

  include Enumerable
  def to_json # Enumerable clobbers this; redefine
    ref
  end
end
