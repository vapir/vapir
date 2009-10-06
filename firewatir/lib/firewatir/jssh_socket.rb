require 'json'

class JsshSocket
  # IP Address of the machine where the script is to be executed. Default to localhost.
  JSSH_IP = "127.0.0.1"
  JSSH_PORT = 9997
  PrototypeFile=File.join(File.dirname(__FILE__), "prototype.functional.js")

  DEFAULT_SOCKET_TIMEOUT=1
  LONG_SOCKET_TIMEOUT=32
  SHORT_SOCKET_TIMEOUT=(2**-16).to_f
  
  class JsshError < StandardError; end
  # This exception is thrown if we are unable to connect to JSSh.
  class UnableToStartJSShException < JsshError; end
  class UndefinedValueError < JsshError; end

  attr_reader :ip, :port, :prototype
  
  # Connects a new socket to jssh
  def initialize(options={})
    @ip=options[:jssh_ip] || JSSH_IP
    @port=options[:jssh_port] || JSSH_PORT
    @prototype=options.key?(:send_prototype) ? options[:send_prototype] : true
    no_of_tries = 0
    begin
      @socket = TCPSocket::new(@ip, @port)
    rescue
      no_of_tries += 1
      retry if no_of_tries < 3
      raise UnableToStartJSShException, "Unable to connect to IP : #{@ip} on port #{@port}. Make sure that JSSh is properly installed and Firefox is running with '-jssh' option"
    end
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

  def send(mesg, flags=0)
#    STDERR.puts "calling send on a JsshSocket directly is deprecated. From:\n"
#    caller.each{|c| STDERR.puts "\t"+c}
    @socket.send mesg, flags
  end
  # Evaluate javascript and return result. Raise an exception if an error occurred.
  def js_eval(str, timeout=DEFAULT_SOCKET_TIMEOUT)
    if (leftover=recv_socket(SHORT_SOCKET_TIMEOUT)) && leftover != "\n> "
      STDERR.puts("WARNING: value(s) #{leftover.inspect} left on #{self.inspect}")
    end
    str=str.to_s.gsub("\n","")
    str=str+"\n" unless str =~ /\n\z/
    @socket.send(str, 0)
    value = read_socket(timeout)
    if md = /^(\w+)Error:(.*)$/.match(value)
      errclassname="Jssh#{md[1]}Error"
      unless JsshSocket.const_defined?(errclassname)
        JsshSocket.const_set(errclassname, Class.new(JsshError))
      end
      raise JsshSocket.const_get(errclassname), "#{md[2]} - evaluating #{str.inspect}"
    end
    value
  end

  # returns the value of the given javascript expression, as reported by JSSH. 
  # This will be a string, the given expression's toString. 
  def value(js)
    js_eval(js)
  end
  
  # assigns to the javascript reference on the left the javascript expression on the right. 
  # returns the value of the expression as reported by JSSH, which
  # will be a string, the expression's toString. 
  def assign(js_left, js_right)
    js_eval("#{js_left}= #{js_right}")
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments (javascript expressions). returns the return value of the function,
  # a string, the toString of the javascript value. 
  def call(js_function, *js_args)
    js_eval("#{js_function}(#{js_args.join(', ')})")
  end
  
  # if the given javascript expression ends with an = symbol, #handle calls to #assign 
  # assuming it is given one argument; if the expression refers to a function, calls 
  # that function with the given arguments using #call; if the expression is some other 
  # value, returns that value (its javascript toString), calling #value, assuming 
  # given no arguments.
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
        raise UndefinedValueError, "undefined expression #{js_expr.inspect}"
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
  # value. 
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
  def assign_json(js_left, rb_right)
    ensure_prototype
    js_right=rb_right.to_json
    parse_json(value("Object.toJSON(#{js_left}=#{js_right})"))
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments, each argument being converted from a ruby object to a javascript object
  # via JSON. returns the return value of the function, of equivalent type to the javascript 
  # return value, converted from javascript to ruby via JSON. 
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
  # arguments.
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
        raise UndefinedValueError, "undefined expression #{js_expr}"
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
    raise JSON::ParserError, "Blank string!" if json.blank?
    return *JSON.parse("["+json+"]")
  end

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

  #
  # Description:
  #  Reads the javascript execution result from the jssh socket.
  #
  # Input:
  # 	- socket - It is the jssh socket, the  only point of communication between the browser and firewatir scripts.
  #
  # Output:
  #	The javascript execution result as string.
  #
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

end

class JsshElement
  attr_reader :element_ref, :jssh_socket
  def initialize(element_ref, jssh_socket)
    raise JsshError, "Empty element reference!" if !element_ref || element_ref.blank?
    raise ArgumentError, "Not given a JsshSocket, instead given #{jssh_socket.inspect}" unless jssh_socket.is_a?(JsshSocket)
    @element_ref=element_ref
    @jssh_socket=jssh_socket
  end
  
  def value
    jssh_socket.value(element_ref)
  end
  def value_json
    jssh_socket.value_json(element_ref)
  end
  def type
    jssh_socket.typeof(element_ref)
  end
  def assign(val)
    jssh_socket.assign(element_ref, val)
  end
  def assign_json(val)
    jssh_socket.assign_json(element_ref, val)
  end
  def [](key)
    jssh_socket.value_json("#{element_ref}[#{key.to_json}]")
  end
  
  def []=(key, value)
    jssh_socket.assign_json("#{element_ref}[#{key.to_json}]", value)
  end
  def invoke_json(method, *args)
    jssh_socket.handle_json("#{element_ref}.#{method}", *args)
  end

  def invoke(method, *args)
    jssh_socket.handle("#{element_ref}.#{method}", *args)
  end

  def method_missing(method, *args)
    if method.to_s =~ /[^a-z_]/i # don't deal with any special character crap 
      Object.instance_method(:method_missing).bind(self).call(method, *args) # let Object#method_missing raise its usual error 
    end
    jssh_socket.handle_json("#{element_ref}.#{method}", *args)
  end
end
