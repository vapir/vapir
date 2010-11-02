require 'json'
require 'socket'
require 'timeout'
#require 'logger'

# :stopdoc:
#class LoggerWithCallstack < Logger
#  class TimeElapsedFormatter < Formatter
#    def initialize
#      super
#      @time_started=Time.now
#    end
#    def format_datetime(time)
#      "%10.3f"%(time.to_f-@time_started.to_f)
#    end
#
#  end
#  def add(severity, message = nil, progname = nil, &block)
#    severity ||= UNKNOWN
#    if @logdev.nil? or severity < @level
#      return true
#    end
#    progname ||= @progname
#    if message.nil?
#      if block_given?
#        message = yield
#      else
#        message = progname
#        progname = @progname
#      end
#    end
#    message=message.to_s+" FROM: "+caller.map{|c|"\t\t#{c}\n"}.join("")
#    @logdev.write(
#      format_message(format_severity(severity), Time.now, progname, message))
#    true
#  end
#end

# :startdoc:

# base exception class for all exceptions raised from Jssh sockets and objects. 
class JsshError < StandardError;end
# this exception covers all connection errors either on startup or during usage. often it represents an Errno error such as Errno::ECONNRESET. 
class JsshConnectionError < JsshError;end
# This exception is thrown if we are unable to connect to JSSh.
class JsshUnableToStart < JsshConnectionError;end
# Represents an error encountered on the javascript side, caught in a try/catch block. 
class JsshJavascriptError < JsshError
  attr_accessor :source, :js_err, :lineNumber, :stack, :fileName
end
# represents a syntax error in javascript. 
class JsshSyntaxError < JsshJavascriptError;end
# raised when a javascript value is expected to be defined but is undefined
class JsshUndefinedValueError < JsshJavascriptError;end

# A JsshSocket represents a connection to Firefox over a socket opened to the JSSH extension. It 
# does the work of interacting with the socket and translating ruby values to javascript and back. 
class JsshSocket
  # :stopdoc:
#  def self.logger
#    @@logger||=begin
#      logfile=File.open('c:/tmp/jssh_log.txt', File::WRONLY|File::TRUNC|File::CREAT)
#      logfile.sync=true
#      logger=Logger.new(logfile)
#      logger.level = -1#Logger::DEBUG#Logger::INFO
#      #logger.formatter=LoggerWithCallstack::TimeElapsedFormatter.new
#      logger
#    end
#  end
#  def logger
#    self.class.logger
#  end
  
  PROMPT="\n> "
  
  PrototypeFile=File.join(File.dirname(__FILE__), "prototype.functional.js")
  # :startdoc:

  # default IP Address of the machine where the script is to be executed. Default to localhost.
  DEFAULT_IP = "127.0.0.1"
  # default port to connect to. 
  DEFAULT_PORT = 9997

  # maximum time JsshSocket waits for a value to be sent before giving up 
  DEFAULT_SOCKET_TIMEOUT=64
  # maximum time JsshSocket will wait for additional reads on a socket that is actively sending 
  SHORT_SOCKET_TIMEOUT=(2**-2).to_f
  # the number of bytes to read from the socket at a time 
  READ_SIZE=4096

  # the IP to which this socket is connected 
  attr_reader :ip
  # the port on which this socket is connected 
  attr_reader :port
  # whether the prototye javascript library is loaded 
  attr_reader :prototype
  
  # Connects a new socket to jssh
  #
  # Takes options:
  # * :jssh_ip => the ip to connect to, default 127.0.0.1
  # * :jssh_port => the port to connect to, default 9997
  # * :send_prototype => true|false, whether to load and send the Prototype library (the functional programming part of it anyway, and JSON bits)
  def initialize(options={})
    @ip=options[:jssh_ip] || DEFAULT_IP
    @port=options[:jssh_port] || DEFAULT_PORT
    @prototype=options.key?(:send_prototype) ? options[:send_prototype] : true
    begin
      @socket = TCPSocket::new(@ip, @port)
      @socket.sync = true
      @expecting_prompt=false # initially, the welcome message comes before the prompt, so this so this is false to start with 
      @expecting_extra_maybe=false
      welcome="Welcome to the Mozilla JavaScript Shell!\n"
      read=read_value
      if !read
        @expecting_extra_maybe=true
        raise JsshUnableToStart, "Something went wrong initializing - no response" 
      elsif read != welcome
        @expecting_extra_maybe=true
        raise JsshUnableToStart, "Something went wrong initializing - message #{read.inspect} != #{welcome.inspect}" 
      end
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE
      err=JsshUnableToStart.new("Could not connect to JSSH sever #{@ip}:#{@port}. Ensure that Firefox is running and has JSSH configured, or try restarting firefox.\nMessage from TCPSocket:\n#{$!.message}")
      err.set_backtrace($!.backtrace)
      raise err
    end
    if @prototype
      ret=send_and_read(File.read(PrototypeFile))
      if ret != "done!"
        @expecting_extra_maybe=true
        raise JsshError, "Something went wrong loading Prototype - message #{ret.inspect}"
      end
    end
    ret=send_and_read("(function()
    { nativeJSON=Components.classes['@mozilla.org/dom/json;1'].createInstance(Components.interfaces.nsIJSON);
      nativeJSON_encode_length=function(object)
      { var encoded=nativeJSON.encode(object);
        return encoded.length.toString()+\"\\n\"+encoded;
      }
      return 'done!';
    })()")
    if ret != "done!"
      @expecting_extra_maybe=true
      raise JsshError, "Something went wrong initializing native JSON - message #{ret.inspect}"
    end
    temp_object.assign({})
  end

  private
  # sets the error state if an exception is encountered while running the given block. the 
  # exception is not rescued. 
  def ensuring_extra_handled
    begin
      yield
    rescue Exception
      @expecting_extra_maybe = true
      raise
    end
  end
  # reads from the socket and returns what seems to be the value that should be returned, by stripping prompts 
  # from the beginning and end where appropriate. 
  # 
  # does not deal with prompts in between values, because attempting to parse those out is impossible, it being
  # perfectly possible that a string the same as the prompt is part of actual data. (even stripping it from the 
  # ends of the string is not entirely certain; data could have it at the ends too, but that's the best that can
  # be done.) so, read_value should be called after every line, or you can end up with stuff like:
  # 
  #  >> @socket.send "3\n4\n5\n", 0
  #  => 6
  #  >> read_value
  #  => "3\n> 4\n> 5"
  #
  # by default, read_value reads until the socket is done being ready. "done being ready" is defined as Kernel.select 
  # saying that the socket isn't ready after waiting for SHORT_SOCKET_TIMEOUT. usually this will be true after a 
  # single read, as most things only take one #recv call to get the whole value. this waiting for SHORT_SOCKET_TIMEOUT
  # can add up to being slow if you're doing a lot of socket activity.
  #
  # to solve this, performance can be improved significantly using the :length_before_value option. with this, you have
  # to write your javascript to return the length of the value to be sent,  followed by a newline, followed by the actual
  # value (which must be of the length it says it is, or this method will error). 
  #
  # if this option is set, this doesn't do any SHORT_SOCKET_TIMEOUT waiting once it gets the full value, it returns 
  # immediately. 
  def read_value(options={})
    options={:timeout => DEFAULT_SOCKET_TIMEOUT, :length_before_value => false, :read_size => READ_SIZE}.merge(options)
    received_data = []
    value_string = ""
    size_to_read=options[:read_size]
    timeout=options[:timeout]
    already_read_length=false
    expected_size=nil
#    logger.add(-1) { "RECV_SOCKET is starting. timeout=#{timeout}" }
    while size_to_read > 0 && ensuring_extra_handled { Kernel.select([@socket] , nil , nil, timeout) }
      data = ensuring_extra_handled { @socket.recv(size_to_read) }
      received_data << data
      value_string << data
      if @expecting_prompt && utf8_length_safe(value_string) > PROMPT.length
        if value_string =~ /\A#{Regexp.escape(PROMPT)}/
          value_string.sub!(/\A#{Regexp.escape(PROMPT)}/, '')
          @expecting_prompt=false
        else
          value_string << clear_error
          raise JsshError, "Expected a prompt! received unexpected data #{value_string.inspect}. maybe left on the socket by last evaluated expression? last expression was:\n\n#{@last_expression}"
        end
      end
      if !@expecting_prompt 
        if options[:length_before_value] && !already_read_length && value_string.length > 0
          if value_string =~ /\A(\d+)\n/
            expected_size=$1.to_i
            already_read_length=true
            value_string.sub!(/\A\d+\n/, '')
          elsif value_string =~ /\A\d+\z/ 
            # rather unlikely, but maybe we just received part of the number so far - ignore
          else
            @expecting_extra_maybe=true
            raise JsshError, "Expected length! unexpected data with no preceding length received: #{value_string.inspect}"
          end
        end
        if expected_size
          size_to_read = expected_size - utf8_length_safe(value_string)
        end
        unless value_string.empty? # switch to short timeout - unless we got a prompt (leaving value_string blank). switching to short timeout when all we got was a prompt would probably accidentally leave the value on the socket. 
          timeout=SHORT_SOCKET_TIMEOUT
        end
      end
      
      # Kernel.select seems to indicate that a dead socket is ready to read, and returns endless blank strings to recv. rather irritating. 
      if received_data.length >= 3 && received_data[-3..-1].all?{|rd| rd==''}
        raise JsshConnectionError, "Socket seems to no longer be connected"
      end
#      logger.add(-1) { "RECV_SOCKET is continuing. timeout=#{timeout}; data=#{data.inspect}" }
    end
#    logger.debug { "RECV_SOCKET is done. received_data=#{received_data.inspect}; value_string=#{value_string.inspect}" }
    if @expecting_extra_maybe
      if Kernel.select([@socket] , nil , nil, SHORT_SOCKET_TIMEOUT)
        cleared_error=clear_error
        if cleared_error==PROMPT
          # if all we got was the prompt, just stick it on the value here so that the code below will deal with setting @execting_prompt correctly 
          value_string << cleared_error
        else
          raise JsshError, "We finished receiving but the socket was still ready to send! extra data received were: #{cleared_error}"
        end
      end
      @expecting_extra_maybe=false
    end
    
    if expected_size 
      value_string_length=value_string.unpack("U*").length # JSSH returns a utf-8 string, so unpack each character to get the right length 
      
      if value_string_length == expected_size
        @expecting_prompt=true
      elsif value_string_length == expected_size + PROMPT.length &&  value_string =~ /#{Regexp.escape(PROMPT)}\z/
        value_string.sub!(/#{Regexp.escape(PROMPT)}\z/, '')
        @expecting_prompt=false
      else
        @expecting_extra_maybe=true if value_string_length < expected_size
        raise JsshError, "Expected a value of size #{expected_size}; received data of size #{value_string_length}: #{value_string.inspect}"
      end
    else
       if value_string =~ /#{Regexp.escape(PROMPT)}\z/ # what if the value happens to end with the same string as the prompt? 
        value_string.sub!(/#{Regexp.escape(PROMPT)}\z/, '')
        @expecting_prompt=false
      else
        @expecting_prompt=true
      end
    end
    return value_string
  end
  
  private
  # returns the number of complete utf-8 encoded characters in the string, without erroring on
  # partial characters. 
  def utf8_length_safe(string)
    string=string.dup
    begin
      string.unpack("U*").length
    rescue ArgumentError # this happens when the socket receive gets split across a utf8 character. we drop the incomplete character from the end. 
      if $!.message =~ /malformed UTF-8 character \(expected \d+ bytes, given (\d+) bytes\)/
        given=$1.to_i
        string[0...(-given)].unpack("U*").length
      else # otherwise, this is some other issue we weren't expecting; we will not rescue it. 
        raise
      end
    end
  end
  # this should be called when an error occurs and we want to clear the socket of any value remaining on it. 
  # tries for SHORT_SOCKET_TIMEOUT to see if a value will appear on the socket; if one does, returns it. 
  def clear_error
    data=""
    while Kernel.select([@socket], nil, nil, SHORT_SOCKET_TIMEOUT)
      # clear any other crap left on the socket 
      data << @socket.recv(READ_SIZE)
    end
    if data =~ /#{Regexp.escape(PROMPT)}\z/
      @expecting_prompt=false
    end
    data
  end

  # sends the given javascript expression which is evaluated, reads the resulting value from the socket, and returns that value. 
  #
  # options are passed to #read_value untouched; the only one that probably ought to be used here is :timeout. 
  def send_and_read(js_expr, options={})
#    logger.add(-1) { "SEND_AND_READ is starting. options=#{options.inspect}" }
    @last_expression=js_expr
    js_expr=js_expr+"\n" unless js_expr =~ /\n\z/
#    logger.debug { "SEND_AND_READ sending #{js_expr.inspect}" }
    @socket.send(js_expr, 0)
    return read_value(options)
  end
  
  private
  # creates a ruby exception from the given information and raises it. 
  def js_error(errclassname, message, source, stuff={})
    errclass=if errclassname
      unless JsshError.const_defined?(errclassname)
        JsshError.const_set(errclassname, Class.new(JsshJavascriptError))
      end
      JsshError.const_get(errclassname)
    else
      JsshJavascriptError
    end
    err=errclass.new("#{message}\nEvaluating:\n#{source}\n\nOther stuff:\n#{stuff.inspect}")
    err.source=source
    err.js_err=stuff
    ["lineNumber", "stack", "fileName"].each do |attr|
      if stuff.key?(attr)
        err.send("#{attr}=", stuff[attr])
      end
    end
    raise err
  end
  public

  def self.to_javascript(object)
    if ['Array', 'Set'].any?{|klass_name| Object.const_defined?(klass_name) && object.is_a?(Object.const_get(klass_name)) }
      "["+object.map{|element| to_javascript(element) }.join(", ")+"]"
    elsif object.is_a?(Hash)
      "{"+object.map{|(key, value)| to_javascript(key)+": "+to_javascript(value) }.join(", ")+"}"
    elsif object.is_a?(JsshObject)
      object.ref
    elsif [true, false, nil].include?(object) || [Integer, Float, String, Symbol].any?{|klass| object.is_a?(klass) }
      object.to_json
    elsif object.is_a?(Regexp)
      # get the flags javascript recognizes - not the same ones as ruby. 
      js_flags = {Regexp::MULTILINE => 'm', Regexp::IGNORECASE => 'i'}.inject("") do |flags, (bit, flag)|
        flags + (object.options & bit > 0 ? flag : '')
      end
      # "new RegExp("+to_javascript(object.source)+", "+to_javascript(js_flags)+")"
      js_source = object.source.empty? ? "/(?:)/" : object.inspect
      js_source.sub!(/\w*\z/, '') # drop ruby flags 
      js_source + js_flags
    else
      raise "Unable to represent object as javascript: #{object.inspect} (#{object.class})"
    end
  end

  # returns the value of the given javascript expression, as reported by JSSH. 
  #
  # This will be a string, the given expression's toString. 
  def value(js)
    # this is wrapped in a function so that ...
    # dang, now I can't remember. I'm sure I had a good reason at the time. 
    send_and_read("(function(){return #{js}})()")
  end
  
  # assigns to the javascript reference on the left the javascript expression on the right. 
  # returns the value of the expression as reported by JSSH, which
  # will be a string, the expression's toString. Uses #value; see its documentation.
  def assign(js_left, js_right)
    value("#{js_left}= #{js_right}")
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments (javascript expressions). returns the return value of the function,
  # a string, the toString of the javascript value. Uses #value; see its documentation.
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
    raise ArgumentError, "Expected a string containing a javascript expression! received #{js.inspect} (#{js.class})" unless js.is_a?(String)
    ensure_prototype
    ref_error=options[:error_on_undefined] ? "typeof(result)=='undefined' ? {errored: true, value: {'name': 'ReferenceError', 'message': 'undefined expression in: '+result_f.toString()}} : " : ""
    wrapped_js=
      "try
       { var result_f=(function(){return #{js}});
         var result=result_f();
         nativeJSON_encode_length(#{ref_error} {errored: false, value: result});
       }catch(e)
       { nativeJSON_encode_length({errored: true, value: Object.extend({}, e)});
       }"
    val=send_and_read(wrapped_js, options.merge(:length_before_value => true))
    error_or_val_json(val, js)
  end
  private
  # takes a json value (a string) of the form {errored: boolean, value: anything},
  # checks if an error is indicated, and creates and raises an appropriate exception
  # if so. 
  def error_or_val_json(val, js)
    if !val || val==''
      @expecting_extra_maybe=true
      raise JsshError, "received no value! may have timed out waiting for a value that was not coming."
    end
    if val=~ /\ASyntaxError: /
      raise JsshSyntaxError, val
    end
    errord_and_val=parse_json(val)
    unless errord_and_val.is_a?(Hash) && errord_and_val.keys.sort == ['errored', 'value'].sort
      raise RuntimeError, "unexpected result: \n\t#{errord_and_val.inspect} \nencountered parsing value: \n\t#{val.inspect} \nreturned from expression: \n\t#{js.inspect}"
    end
    errord=errord_and_val['errored']
    val= errord_and_val['value']
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
  public
  
  # assigns to the javascript reference on the left the object on the right. 
  # Assuming the right object can be converted to JSON, the javascript value will 
  # be the equivalent javascript data type to the ruby object. Will return 
  # the assigned value, converted from its javascript value back to ruby. So, the return
  # value won't be exactly equivalent if you use symbols for example. 
  #
  #  >> jssh_socket.assign_json('bar', {:foo => [:baz, 'qux']})
  #  => {"foo"=>["baz", "qux"]}
  #
  # Uses #value_json; see its documentation.
  def assign_json(js_left, rb_right)
    ensure_prototype
    js_right=JsshSocket.to_javascript(rb_right)
    value_json("#{js_left}=#{js_right}")
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments, each argument being converted from a ruby object to a javascript object
  # via JSON. returns the return value of the function, of equivalent type to the javascript 
  # return value, converted from javascript to ruby via JSON. 
  # Uses #value_json; see its documentation.
  def call_json(js_function, *rb_args)
    ensure_prototype
    js_args=rb_args.map{|arg| JsshSocket.to_javascript(arg) }
    value_json("#{js_function}(#{js_args.join(', ')})")
  end

  # does the same thing as #handle, but with json, calling #assign_json, #value_json, 
  # or #call_json. 
  #
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
      raise JsshError, "This functionality requires the prototype library; cannot be called on a Jssh session that has not loaded the Prototype library"
    end
  end

  # returns the type of the given expression using javascript typeof operator, with the exception that
  # if the expression is null, returns 'null' - whereas typeof(null) in javascript returns 'object'
  def typeof(expression)
    ensure_prototype
    js="try
{ nativeJSON_encode_length({errored: false, value: (function(object){ return (object===null) ? 'null' : (typeof object); })(#{expression})});
} catch(e)
{ if(e.name=='ReferenceError')
  { nativeJSON_encode_length({errored: false, value: 'undefined'});
  }
  else
  { nativeJSON_encode_length({errored: true, value: Object.extend({}, e)});
  }
}"
    error_or_val_json(send_and_read(js, :length_before_value => true),js)
  end
  
  # uses the javascript 'instanceof' operator, passing it the given 
  # expression and interface. this should return true or false. 
  def instanceof(js_expression, js_interface)
    value_json "(#{js_expression}) instanceof (#{js_interface})"
  end

  # parses the given JSON string using JSON.parse
  # Raises JSON::ParserError if given a blank string, something that is not a string, or 
  # a string that contains invalid JSON
  def parse_json(json)
    err_class=JSON::ParserError
    decoder=JSON.method(:parse)
    # err_class=ActiveSupport::JSON::ParseError
    # decoder=ActiveSupport::JSON.method(:decode)
    raise err_class, "Not a string! got: #{json.inspect}" unless json.is_a?(String)
    raise err_class, "Blank string!" if json==''
    begin
      return decoder.call(json)
    rescue err_class
      err=$!.class.new($!.message+"\nParsing: #{json.inspect}")
      err.set_backtrace($!.backtrace)
      raise err
    end
  end

  # takes a reference and returns a new JsshObject representing that reference on this socket. 
  # ref should be a string representing a reference in javascript. 
  def object(ref, other={})
    JsshObject.new(ref, self, {:debug_name => ref}.merge(other))
  end

  def object_in_temp(ref, other={})
    object(ref, other).store_rand_temp
  end
  
  # represents the root of the space seen by the JsshSocket, and implements #method_missing to 
  # return objects at the root level in a similar manner to JsshObject's #method_missing. 
  #
  # for example, jssh_socket.root.Components will return the top-level Components object; 
  # jssh_socket.root.ctypes will return the ctypes top-level object if that is defined, or error 
  # if not. 
  #
  # if the object is a function, then it will be called with any given arguments:
  #  >> jssh_socket.root.getWindows
  #  => #<JsshObject:0x0254d150 type=object, debug_name=getWindows()>
  #  >> jssh_socket.root.eval("3+2")
  #  => 5
  #
  # If any arguments are given to an object that is not a function, you will get an error: 
  #  >> jssh_socket.root.Components('wat')
  #  ArgumentError: Cannot pass arguments to Javascript object #<JsshObject:0x02545978 type=object, debug_name=Components>
  #
  # special behaviors exist for the suffixes !, ?, and =. 
  #
  # - '?' suffix returns nil if the object does not exist, rather than raising an exception. for
  #   example:
  #    >> jssh_socket.root.foo
  #    JsshUndefinedValueError: undefined expression represented by #<JsshObject:0x024c3ae0 type=undefined, debug_name=foo> (javascript reference is foo)
  #    >> jssh_socket.root.foo?
  #    => nil
  # - '=' suffix sets the named object to what is given, for example:
  #    >> jssh_socket.root.foo?
  #    => nil
  #    >> jssh_socket.root.foo={:x => ['y', 'z']}
  #    => {:x=>["y", "z"]}
  #    >> jssh_socket.root.foo
  #    => #<JsshObject:0x024a3510 type=object, debug_name=foo>
  # - '!' suffix tries to convert the value to json in javascrit and back from json to ruby, even 
  #   when it might be unsafe (causing infinite rucursion or other errors). for example:
  #    >> jssh_socket.root.foo!
  #    => {"x"=>["y", "z"]}
  #   it can be used with function results that would normally result in a JsshObject:
  #    >> jssh_socket.root.eval!("[1, 2, 3]")
  #    => [1, 2, 3]
  #   and of course it can error if you try to do something you shouldn't:
  #    >> jssh_socket.root.getWindows!
  #    JsshError::NS_ERROR_FAILURE: Component returned failure code: 0x80004005 (NS_ERROR_FAILURE) [nsIJSON.encode]
  def root
    jssh_socket=self
#    @root ||= begin
      root = Object.new
      (class << root; self; end).send(:define_method, :method_missing) do |method, *args|
        method=method.to_s
        if method =~ /\A([a-z_][a-z0-9_]*)([=?!])?\z/i
          method = $1
          special = $2
          obj=jssh_socket.object(method)
          if special=='='
            jssh_socket.object(method, :define_methods => false).assign(*args)
          else
            type=obj.type
            if type=='function'
              obj=obj.pass(*args)
            elsif !args.empty?
              raise ArgumentError, "Cannot pass arguments to Javascript object #{obj.inspect}"
            end
            case special
            when nil
              obj.val_or_object
            when '?'
              obj.val_or_object(:error_on_undefined => false)
            when '!'
              obj.val
            else # this shouldn't happen
              super
            end
          end
        else
          # don't deal with any special character crap 
          super
        end
      end
      root
#    end
  end
  
  # Creates and returns a JsshObject representing a function. 
  #
  # Takes any number of arguments, which should be strings or symbols, which are arguments to the 
  # javascript function. 
  #
  # The javascript function is specified as the result of a block which must be given to 
  # #function. 
  #
  # An example:
  #   jssh_socket.function(:a, :b) do
  #     "return a+b;"
  #   end
  #   => #<JsshObject:0x0248e78c type=function, debug_name=function(a, b){ return a+b; }>
  #
  # This is exactly the same as doing 
  #   jssh_socket.object("function(a, b){ return a+b; }")
  # but it is a bit more concise and reads a bit more ruby-like. 
  #
  # a longer example to return the text of a thing (rather contrived, but, it works): 
  #
  #   jssh_socket.function(:node) do %q[
  #     if(node.nodeType==3)
  #     { return node.data;
  #     }
  #     else if(node.nodeType==1)
  #     { return node.textContent;
  #     }
  #     else
  #     { return "what?";
  #     }
  #   ]
  #   end.call(some_node)
  def function(*arg_names)
    unless arg_names.all?{|arg| (arg.is_a?(String) || arg.is_a?(Symbol)) && arg.to_s =~ /\A[a-z_][a-z0-9_]*\z/i }
      raise ArgumentError, "Arguments to \#function should be strings or symbols representing the names of arguments to the function. got #{arg_names.inspect}"
    end
    unless block_given?
      raise ArgumentError, "\#function should be given a block which results in a string representing the body of a javascript function. no block was given!"
    end
    function_body = yield
    unless function_body.is_a?(String)
      raise ArgumentError, "The block given to \#function must return a string representing the body of a javascript function! instead got #{function_body.inspect}"
    end
    nl = function_body.include?("\n") ? "\n" : ""
    object("function(#{arg_names.join(", ")})#{nl}{ #{function_body} #{nl}}")
  end
  
  # takes a hash of arguments with keys that are strings or symbols that will be variables in the 
  # scope of the function in javascript, and a block which results in a string which should be the 
  # body of a javascript function. calls the given function with the given arguments. 
  #
  # an example:
  #  jssh_socket.call_function(:x => 3, :y => {:z => 'foobar'}) do
  #    "return x + y['z'].length;"
  #  end
  # 
  # will return 9. 
  def call_function(arguments_hash={}, &block)
    argument_names, argument_vals = *arguments_hash.inject([[],[]]) do |(names, vals),(name, val)|
      [names + [name], vals + [val]]
    end
    function(*argument_names, &block).call(*argument_vals)
  end

  # returns a JsshObject representing a designated top-level object for temporary storage of stuff
  # on this socket. 
  #
  # really, temporary values could be stored anywhere. this just gives one nice consistent designated place to stick them. 
  def temp_object
    @temp_object ||= object('JsshTemp')
  end
  # returns a JsshObject representing the Components top-level javascript object. 
  #
  # https://developer.mozilla.org/en/Components_object
  def Components
    @components ||= object('Components')
  end
  # returns a JsshObject representing the return value of JSSH's builtin getWindows() function. 
  def getWindows
    @getwindows ||= object('getWindows()')
  end
  # raises an informative error if the socket is down for some reason 
  def assert_socket
    begin
      actual, expected=if prototype
        [value_json('["foo"]'), ["foo"]]
      else
        [value('"foo"'), "foo"]
      end
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE
      raise(JsshConnectionError, "Encountered a socket error while checking the socket.\n#{$!.class}\n#{$!.message}", $!.backtrace)
    end
    unless expected==actual
      raise JsshError, "The socket seems to have a problem: sent #{expected.inspect} but got back #{actual.inspect}"
    end
  end
  
  # returns a string of basic information about this socket. 
  def inspect
    "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{[:ip, :port, :prototype].map{|attr| aa="@#{attr}";aa+'='+instance_variable_get(aa).inspect}.join(', ')}>"
  end
end

# represents a javascript object in ruby. 
class JsshObject
  # the reference to the javascript object this JsshObject represents 
  attr_reader :ref
  # the JsshSocket this JsshObject is on 
  attr_reader :jssh_socket
  # whether this represents the result of a function call (if it does, then JsshSocket#typeof won't be called on it)
  attr_reader :function_result
  # this tracks the origins of this object - what calls were made along the way to get it. 
  attr_reader :debug_name
# :stopdoc:
#  def logger
#    jssh_socket.logger
#  end

# :startdoc:

  public
  # initializes a JsshObject with a string of javascript containing a reference to
  # the object, and a  JsshSocket that the object is defined on. 
  def initialize(ref, jssh_socket, other={})
    other={:debug_name => ref, :function_result => false, :define_methods => self.class.always_define_methods}.merge(other)
    raise ArgumentError, "Empty object reference!" if !ref || ref==''
    raise ArgumentError, "Reference must be a string - got #{ref.inspect} (#{ref.class.name})" unless ref.is_a?(String)
    raise ArgumentError, "Not given a JsshSocket, instead given #{jssh_socket.inspect} (#{jssh_socket.class.name})" unless jssh_socket.is_a?(JsshSocket)
    @ref=ref
    @jssh_socket=jssh_socket
    @debug_name=other[:debug_name]
    @function_result=other[:function_result]
    if other[:define_methods] && type=='object'
      define_methods!
    end
#    logger.info { "#{self.class} initialized: #{debug_name} (type #{type})" }
  end

  # returns the value, via JsshSocket#value_json
  def val
    jssh_socket.value_json(ref, :error_on_undefined => !function_result)
  end
  
  # whether JsshObject shall try to dynamically define methods on initialization, using 
  # #define_methods! default is false. 
  def self.always_define_methods
    unless class_variable_defined?('@@always_define_methods')
      # if not defined, set the default. 
      @@always_define_methods=false
    end
    @@always_define_methods
  end
  # set whether JsshObject shall try to dynamically define methods on initialization, using
  # #define_methods! 
  #
  # I find this useful to set to true in irb, for tab-completion of methods. it may cause
  # jssh operations to be considerably slower, however. 
  #
  # for always setting this in irb, I set this beforehand, overriding the default, 
  # by including in my .irbrc the following (which doesn't require jssh_socket.rb to be
  # required):
  #
  #  class JsshObject
  #    @@always_define_methods=true
  #  end
  def self.always_define_methods=(val)
    @@always_define_methods = val
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
    if function_result # don't get type for function results, causes function evaluations when you probably didn't want that. 
      nil
    else
#      logger.add(-1) { "retrieving type for #{debug_name}" }
      @type||= jssh_socket.typeof(ref)
    end
  end
  
  # returns javascript instanceof operator on this and the given interface (expected to be a JsshObject)
  # note that this is javascript, not to be confused with ruby's #instance_of? method. 
  # 
  # example:
  # window.instanceof(window.jssh_socket.Components.interfaces.nsIDOMChromeWindow)
  # => true
  def instanceof(interface)
    jssh_socket.instanceof(self.ref, interface.ref)
  end
  # returns an array of interfaces which this object is an instance of. this is achieved 
  # by looping over each value of Components.interfaces (see https://developer.mozilla.org/en/Components.interfaces ) 
  # and calling the #instanceof operator with this and the interface. 
  #
  # this may be rather slow. 
  def implemented_interfaces
    jssh_socket.Components.interfaces.to_hash.inject([]) do |list, (key, interface)|
      list << interface if instanceof(interface)
      list
    end
  end
  
  # returns the type of object that is reported by the javascript toString() method, which
  # returns such as "[object Object]" or "[object XPCNativeWrapper [object HTMLDocument]]"
  # This method returns 'Object' or 'XPCNativeWrapper [object HTMLDocument]' respectively.
  # Raises an error if this JsshObject points to something other than a javascript 'object'
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
        raise JsshError, "Type is #{type}, not object"
      end
    end
  end
  
  # checks the type of this object, and if it is a type that can be simply converted to a ruby
  # object via jason, returns the ruby value. that occurs if the type is one of:
  # 
  # 'boolean','number','string','null'
  #
  # otherwise - if the type is something else (probably 'function' or 'object'; or maybe something else)
  # then this JsshObject is returned. 
  # 
  # if self is undefined in javascript, then behavor depends on the options hash. if :error_on_undefined is
  # true, then nil is returned; otherwise JsshUndefinedValueError is raised. 
  #
  # if this is a function result, this will store the result in a temporary location (thereby
  # calling the function to acquire the result) before making the above decision. 
  def val_or_object(options={})
    options={:error_on_undefined=>true}.merge(options)
    if function_result # calling functions multiple times is bad, so store in temp before figuring out what to do with it
      store_rand_object_key(jssh_socket.temp_object).val_or_object(:error_on_undefined => false)
    else
      case self.type
      when 'undefined'
        if !options[:error_on_undefined]
          nil
        else
          raise JsshUndefinedValueError, "undefined expression represented by #{self.inspect} (javascript reference is #{@ref})"
        end
      when 'boolean','number','string','null'
        val
      else # 'function','object', or anything else 
        self
      end
    end
  end
  
  # returns a JsshObject representing the given attribute. Checks the type, and if 
  # it is a function, references the _return value_ of the function (with the given
  # arguments, if any, which are in ruby, converted to javascript). If the type of the 
  # expression is undefined, raises an error (if you want an attribute even if it's 
  # undefined, use #attr). 
  def invoke(attribute, *args)
    invoke_attr_err_args(attribute, true, *args)
  end
  # same as #invoke, but returns nil for undefined attributes rather than raising an
  # error. this is used by method_missing when passed a question-mark method. 
  #
  # example, assuming some jssh_object: 
  #  > jssh_object.type
  #  => 'object'
  #  > jssh_object.some_undefined_attribute
  #  
  def invoke?(attribute, *args)
    invoke_attr_err_args(attribute, false, *args)
  end
  def invoke_attr_err_args(attribute, err, *args)
    attr_obj=attr(attribute)
    type=attr_obj.type
    attr_obj=attr(attribute)
    type=attr_obj.type
    case type
    when 'function'
      attr_obj.call(*args)
    else
      if args.empty?
        attr_obj.val_or_object(:error_on_undefined => err)
      else
        raise ArgumentError, "Cannot pass arguments to expression #{attr_obj.ref} of type #{type}"
      end
    end
  end
  private :invoke_attr_err_args
  
  # returns a JsshObject referencing the given attribute of this object 
  def attr(attribute, options={})
    unless (attribute.is_a?(String) || attribute.is_a?(Symbol)) && attribute.to_s =~ /\A[a-z_][a-z0-9_]*\z/i
      raise JsshSyntaxError, "#{attribute.inspect} (#{attribute.class.inspect}) is not a valid attribute!"
    end
    JsshObject.new("#{ref}.#{attribute}", jssh_socket, {:debug_name => "#{debug_name}.#{attribute}"}.merge(options))
  end

  # assigns the given ruby value (converted to javascript) to the reference
  # for this object. returns self. 
  def assign(val)
    @debug_name="(#{debug_name}=#{val.is_a?(JsshObject) ? val.debug_name : JsshSocket.to_javascript(val)})"
    result=assign_expr(JsshSocket.to_javascript(val))
#    logger.info { "#{self.class} assigned: #{debug_name} (type #{type})" }
    result
  end
  # assigns the given javascript expression (string) to the reference for this object 
  def assign_expr(val)
    jssh_socket.value_json("(function(val){#{ref}=val; return null;}(#{val}))")
    @type=nil # uncache this 
    # don't want to use JsshSocket#assign_json because converting the result of the assignment (that is, the expression assigned) to json is error-prone and we don't really care about the result. 
    # don't want to use JsshSocket#assign because the result can be blank and cause send_and_read to wait for data that's not coming - also 
    # using a json function is better because it catches errors much more elegantly. 
    # so, wrap it in a function that returns nil. 
    self
  end
  
  # returns a JsshObject for the result of calling the function represented by this object, passing 
  # the given arguments, which are converted to javascript. if this is not a function, javascript will raise an error. 
  def pass(*args)
    JsshObject.new("#{ref}(#{args.map{|arg| JsshSocket.to_javascript(arg)}.join(', ')})", jssh_socket, :function_result => true, :debug_name => "#{debug_name}(#{args.map{|arg| arg.is_a?(JsshObject) ? arg.debug_name : JsshSocket.to_javascript(arg)}.join(', ')})")
  end
  
  # returns the value (via JsshSocket#value_json) or a JsshObject (see #val_or_object) of the return 
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
  #  date_class = jssh_socket.object('Date')
  #  => #<JsshObject:0x0118eee8 type=function, debug_name=Date>
  #  date = date_class.new
  #  => #<JsshObject:0x01188a84 type=object, debug_name=new Date()>
  #  date.getFullYear
  #  => 2010
  #  date_class.new('october 4, 1978').getFullYear
  #  => 1978
  def new(*args)
    JsshObject.new("new #{ref}", jssh_socket, :debug_name => "new #{debug_name}").call(*args)
  end

  # sets the given javascript variable to this object, and returns a JsshObject referring
  # to the variable. 
  #
  #  >> foo=document.getElementById('guser').store('foo')
  #  => #<JsshObject:0x2dff870 @ref="foo" ...>
  #  >> foo.tagName
  #  => "DIV"
  #
  # the second argument is only used internally and shouldn't be used. 
  def store(js_variable, somewhere_meaningful=true)
    stored=JsshObject.new(js_variable, jssh_socket, :function_result => false, :debug_name => somewhere_meaningful ? "(#{js_variable}=#{debug_name})" : debug_name)
    stored.assign_expr(self.ref)
    stored
  end
  
  private
  # takes a block which, when yielded a random key, should result in a random reference. this checks
  # that the reference is not already in use and stores this object in that reference, and returns 
  # a JsshObject referring to the stored object. 
  def store_rand_named(&name_proc)
    base=36
    length=6
    begin
      name=name_proc.call(("%#{length}s"%rand(base**length).to_s(base)).tr(' ','0'))
    end while JsshObject.new(name,jssh_socket).type!='undefined'
    # okay, more than one iteration is ridiculously unlikely, sure, but just to be safe. 
    store(name, false)
  end
  public
  
  # stores this object in a randomly-named top-level variable with the given prefix followed by an underscore, and returns the stored object. 
  def store_rand_prefix(prefix)
    store_rand_named do |r|
      prefix+"_"+r
    end
  end

  # stores this object in a random key of the given object and returns the stored object. 
  def store_rand_object_key(object)
    raise ArgumentError("Object is not a JsshObject: got #{object.inspect}") unless object.is_a?(JsshObject)
    store_rand_named do |r|
      object.sub(r).ref
    end
  end
  
  # stores this object in a random key of the designated temporary object for this socket and returns the stored object. 
  def store_rand_temp
    store_rand_object_key(jssh_socket.temp_object)
  end

  # returns a JsshObject referring to a subscript of this object, specified as a ruby object converted to 
  # javascript. 
  #
  # similar to [], but [] calls #val_or_object; this always returns a JsshObject. 
  def sub(key)
    JsshObject.new("#{ref}[#{JsshSocket.to_javascript(key)}]", jssh_socket, :debug_name => "#{debug_name}[#{key.is_a?(JsshObject) ? key.debug_name : JsshSocket.to_javascript(key)}]")
  end

  # returns a JsshObject referring to a subscript of this object, or a value if it is simple (see #val_or_object)
  #
  # subscript is specified as ruby (converted to javascript). 
  def [](key)
    sub(key).val_or_object(:error_on_undefined => false)
  end

  # assigns the given ruby value (passed through json via JsshSocket#assign_json) to the given subscript
  # (key is converted to javascript). 
  def []=(key, value)
    self.sub(key).assign(value)
  end

  # calls a binary operator (in javascript) with self and another operand 
  def binary_operator(operator, operand)
    JsshObject.new("(#{ref}#{operator}#{JsshSocket.to_javascript(operand)})", jssh_socket, :debug_name => "(#{debug_name}#{operator}#{operand.is_a?(JsshObject) ? operand.debug_name : JsshSocket.to_javascript(operand)})").val_or_object
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
    operand.is_a?(JsshObject) && binary_operator('==', operand)
  end
  # javascript triple-equals (===) operator. very different from ruby's tripl-equals operator - 
  # in javascript this means "really really equal"; in ruby it means "sort of equal-ish" 
  def triple_equals(operand)
    operand.is_a?(JsshObject) && binary_operator('===', operand)
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
  # method_missing will only try to deal with methods that look like /^[a-z_][a-z0-9_]*$/i - no
  # special characters, only alphanumeric/underscores, starting with alpha or underscore - with
  # the exception of three special behaviors:
  # 
  # If the method ends with an equals sign (=), it does assignment - it calls #assign on the given attribute 
  # to do the assignment and returns the assigned value. 
  #
  # If the method ends with a bang (!), then it will attempt to get the value (using json) of the
  # reference, using JsshObject#val. For simple types (null, string, boolean, number), this is what 
  # happens by default anyway. With other types (usually the 'object' type), attempting to 
  # convert to json can raise errors or cause infinite recursion, so is not attempted. but if you 
  # have an object or an array that you know you can json-ize, you can use ! to force that. 
  #
  # If the method ends with a question mark (?), then it will attempt to get a string representing the
  # value, using JsshObject#val_str. This is safer than ! because the javascript conversion to json 
  # can error. This also catches the JsshUndefinedValueError that can occur, and just returns nil
  # for undefined stuff. 
  #
  # otherwise, method_missing calls to #invoke, and returns a JsshObject, a string, a boolean, a number, or
  # null - see documentation for #invoke. 
  #
  # Since #invoke returns a JsshObject for javascript objects, this means that you can string together 
  # method_missings and the result looks rather like javascript.
  #
  # this lets you do things like:
  # 
  #  >> jssh_socket.object('getWindows()').length
  #  => 2
  #  >> jssh_socket.object('getWindows()')[1].getBrowser.contentDocument?
  #  => "[object XPCNativeWrapper [object HTMLDocument]]"
  #  >> document=jssh_socket.object('getWindows()')[1].getBrowser.contentDocument
  #  => #<JsshObject:0x34f01fc @ref="getWindows()[1].getBrowser().contentDocument" ...>
  #  >> document.title
  #  => "ruby - Google Search"
  #  >> document.forms[0].q.value
  #  => "ruby"
  #  >> document.forms[0].q.value='foobar'
  #  => "foobar"
  #  >> document.forms[0].q.value
  #  => "foobar"
  #--
  # $A and $H, used below, are methods of the Prototype javascript library, which add nice functional 
  # methods to arrays and hashes - see http://www.prototypejs.org/
  # You can use these methods with method_missing just like any other:
  #
  #  >> js_hash=jssh_socket.object('$H')
  #  => #<JsshObject:0x2beb598 @ref="$H" ...>
  #  >> js_arr=jssh_socket.object('$A')
  #  => #<JsshObject:0x2be40e0 @ref="$A" ...>
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
      special = $2
    else # don't deal with any special character crap 
      #Object.instance_method(:method_missing).bind(self).call(method, *args) # let Object#method_missing raise its usual error 
      return super
    end
    case special
    when nil
      invoke(method, *args)
    when '?'
      invoke?(method, *args)
    when '!'
      got=invoke(method, *args)
      got.is_a?(JsshObject) ? got.val : got
    when '='
      attr(method, :define_methods => false).assign(*args)
    else
      Object.instance_method(:method_missing).bind(self).call(method, *args) # this shouldn't happen 
    end
  end
  # calls define_method for each key of this object as a hash. useful for tab-completing attributes 
  # in irb, mostly. 
  def define_methods! # :nodoc:
    metaclass=(class << self; self; end)
    keys=jssh_socket.object("function(obj) { var keys=[]; for(var key in obj) { keys.push(key); } return keys; }").pass(self).val
    
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
      special = $2
    else # don't deal with any special character crap 
      return false
    end

    if self.type=='undefined'
      return false
    elsif special=='='
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
      eval('undef '+method_name.to_s)
    end
  end
  
  # returns this object passed through the $A function of the prototype javascript library. 
  def to_js_array
    jssh_socket.object('$A').call(self)
  end
  # returns this object passed through the $H function of the prototype javascript library. 
  def to_js_hash
    jssh_socket.object('$H').call(self)
  end
  # returns this object passed through a javascript function which copies each key onto a blank object and rescues any errors. 
  def to_js_hash_safe
    jssh_socket.object('$_H').call(self)
  end
  # returns a JsshArray representing this object 
  def to_array
    JsshArray.new(self.ref, self.jssh_socket, :debug_name => debug_name)
  end
  # returns a JsshHash representing this object 
  def to_hash
    JsshHash.new(self.ref, self.jssh_socket, :debug_name => debug_name)
  end
  # returns a JsshDOMNode representing this object 
  def to_dom
    JsshDOMNode.new(self.ref, self.jssh_socket, :debug_name => debug_name)
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
  # below the specified recursion level, this will return this JsshObject rather than recursing
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
    rescue JsshError
      return self
    end
    keys.inject({}) do |hash, key|
      val=begin
        self[key]
      rescue JsshError
        $!
      end
      hash[key]=if val.is_a?(JsshObject)
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

# represents a node on the DOM. not substantially from JsshObject, but #inspect 
# is more informative, and #dump is defined for extensive debug info. 
#
# This class is mostly useful for debug, not used anywhere in production at the moment. 
class JsshDOMNode < JsshObject
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
class JsshArray < JsshObject
  # yields the element at each subscript of this javascript array, from 0 to self.length. 
  def each
    length=self.length
    raise JsshError, "length #{length.inspect} is not a non-negative integer on #{self.ref}" unless length.is_a?(Integer) && length >= 0
    for i in 0...length
      element=self[i]
      if element.is_a?(JsshObject)
        # yield a more permanent reference than the array subscript 
        element=element.store_rand_temp
      end
      yield element
    end
  end
  include Enumerable
end

# this class represents a hash, or 'object' type in javascript. 
class JsshHash < JsshObject
  # returns an array of keys of this javascript object 
  def keys
    keyfunc="function(obj) { var keys=[]; for(var key in obj) { keys.push(key); } return keys; }"
    @keys=jssh_socket.object(keyfunc).pass(self).val
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
