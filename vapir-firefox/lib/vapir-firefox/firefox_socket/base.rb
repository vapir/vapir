require 'json'
require 'socket'
require 'timeout'
require 'vapir-common/config'
require 'vapir-firefox/javascript_object'
require 'vapir-common/external/core_extensions'
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

class IPSocket
  # sends the whole message 
  #
  # returns the number of broken-up sends that occured. 
  def sendall(message, flags=0)
    bytes_sent = 0
    packets = 0
    while bytes_sent < message.length
      send_result = send(message[bytes_sent..-1], flags)
      bytes_sent+= send_result
      packets+= 1
    end
    packets
  end
  # takes a timeout, and returns true if Kernel.select indicates that the socket
  # is ready to read within that timeout. if Kernel.select indicates that the socket
  # is in an error condition, this method will raise 
  def ready_to_recv?(timeout)
    select_result = Kernel.select([self], nil, [self], timeout)
    read_result, write_result, err_result = *select_result
    if select_result && err_result.include?(self)
      # never actually seen this condition, so not sure what error class to put here
      raise "the socket indicated an error condition when checking that it was ready for reading"
    else
      return select_result && read_result.include?(self)
    end
  end
end

# base exception class for all exceptions raised from FirefoxSocket 
class FirefoxSocketError < StandardError;end
# this exception covers all connection errors either on startup or during usage. often it represents an Errno error such as Errno::ECONNRESET. 
class FirefoxSocketConnectionError < FirefoxSocketError;end
# This exception is thrown if th FirefoxSocket is unable to initially connect. 
class FirefoxSocketUnableToStart < FirefoxSocketConnectionError;end
# Represents an error encountered on the javascript side, caught in a try/catch block. 
class FirefoxSocketJavascriptError < FirefoxSocketError
  attr_accessor :source, :name, :js_err, :lineNumber, :stack, :fileName
end
# represents a syntax error in javascript. 
class FirefoxSocketSyntaxError < FirefoxSocketJavascriptError;end
# raised when a javascript value is expected to be defined but is undefined
class FirefoxSocketUndefinedValueError < FirefoxSocketJavascriptError;end

# Base class for connecting to a firefox extension over a TCP socket. 
# does the work of interacting with the socket and translating ruby values to javascript and back. 
class FirefoxSocket
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
  
  PrototypeFile=File.join(File.dirname(__FILE__), "prototype.functional.js")
  # :startdoc:

  @base_configuration=Vapir::Configuration.new(nil) do |config|
    config.create_update :host, 'localhost'
    config.create :port, :validator => :positive_integer
    config.create_update :default_timeout, 64, :validator => :numeric
    config.create_update :short_timeout, (2**-2).to_f, :validator => :numeric
    config.create_update :read_size, 4096, :validator => :positive_integer
  end
  @configuration_parent=@base_configuration
  extend Vapir::Configurable

  include Vapir::Configurable
  def configuration_parent
    self.class.config
  end

  # the host to which this socket is connected 
  def host
    config.host
  end
  # the port on which this socket is connected 
  def port
    config.port
  end
  
  # Connects a new socket to firefox
  #
  # Takes options:
  # * :host => the ip to connect to, default localhost
  # * :port => the port to connect to
  def initialize(options={})
    config.update_hash options
    require 'thread'
    @mutex = Mutex.new
    begin
      @socket = TCPSocket::new(host, port)
      @socket.sync = true
      @expecting_prompt=false # initially, the welcome message comes before the prompt, so this so this is false to start with 
      @expecting_extra_maybe=false
      eat_welcome_message
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE
      err=FirefoxSocketUnableToStart.new("Could not connect to Firefox on #{host}:#{port}. Ensure that Firefox is running and has the extension listening on that port, or try restarting firefox.\nMessage from TCPSocket:\n#{$!.message}")
      err.set_backtrace($!.backtrace)
      raise err
    end
    initialize_environment
    @temp_object = object('VapirTemp')
    ret=send_and_read(File.read(PrototypeFile))
    if ret !~ /done!/
      @expecting_extra_maybe=true
      raise FirefoxSocketError, "Something went wrong loading Prototype - message #{ret.inspect}"
    end
    # Y combinator in javascript. 
    #
    #  example - recursive length function.
    #
    #  >> length=firefox_socket.root.Vapir.Ycomb(firefox_socket.function(:len){ "return function(list){ return list.length==0 ? 0 : 1+len(list.slice(1)); }; " })
    #  => #<JavascriptObject:0x01206880 type=function, debug_name=Vapir.Ycomb(function(len){ return function(list){ return list.length==0 ? 0 : 1+len(list.slice(1)); };  })>
    #  >> length.call(['a', 'b', 'c'])
    #  => 3
    root.Vapir.Ycomb=function(:gen){ "return function(f){ return f(f); }(function(f){ return gen(function(){ return f(f).apply(null, arguments); }); });" }
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
  # saying that the socket isn't ready after waiting for config.short_timeout. usually this will be true after a 
  # single read, as most things only take one #recv call to get the whole value. this waiting for config.short_timeout
  # can add up to being slow if you're doing a lot of socket activity.
  #
  # to solve this, performance can be improved significantly using the :length_before_value option. with this, you have
  # to write your javascript to return the length of the value to be sent,  followed by a newline, followed by the actual
  # value (which must be of the length it says it is, or this method will error). 
  #
  # if this option is set, this doesn't do any config.short_timeout waiting once it gets the full value, it returns 
  # immediately. 
  def read_value(options={})
    options=options_from_config(options, {:timeout => :default_timeout, :read_size => :read_size}, [:length_before_value])
    received_data = []
    value_string = ""
    size_to_read=options[:read_size]
    timeout=options[:timeout]
    already_read_length=false
    expected_size=nil
#    logger.add(-1) { "RECV_SOCKET is starting. timeout=#{timeout}" }
    while size_to_read > 0 && ensuring_extra_handled { @socket.ready_to_recv?(timeout) }
      data = ensuring_extra_handled { @socket.recv(size_to_read) }
      received_data << data
      value_string << data
      if @prompt && @expecting_prompt && utf8_length_safe(value_string) > @prompt.length
        if value_string =~ /\A#{Regexp.escape(@prompt)}/
          value_string.sub!(/\A#{Regexp.escape(@prompt)}/, '')
          @expecting_prompt=false
        else
          value_string << clear_error
          raise FirefoxSocketError, "Expected a prompt! received unexpected data #{value_string.inspect}. maybe left on the socket by last evaluated expression? last expression was:\n\n#{@last_expression}"
        end
      end
      if !@prompt || !@expecting_prompt 
        if options[:length_before_value] && !already_read_length && value_string.length > 0
          if value_string =~ /\A(\d+)\n/
            expected_size=$1.to_i
            already_read_length=true
            value_string.sub!(/\A\d+\n/, '')
          elsif value_string =~ /\A\d+\z/ 
            # rather unlikely, but maybe we just received part of the number so far - ignore
          else
            @expecting_extra_maybe=true
            raise FirefoxSocketError, "Expected length! unexpected data with no preceding length received: #{value_string.inspect}\n\nlast thing we sent was: #{@last_expression}"
          end
        end
        if expected_size
          size_to_read = expected_size - utf8_length_safe(value_string)
        end
        unless value_string.empty? # switch to short timeout - unless we got a prompt (leaving value_string blank). switching to short timeout when all we got was a prompt would probably accidentally leave the value on the socket. 
          timeout=config.short_timeout
        end
      end
      
      # Kernel.select seems to indicate that a dead socket is ready to read, and returns endless blank strings to recv. rather irritating. 
      if received_data.length >= 3 && received_data[-3..-1].all?{|rd| rd==''}
        raise FirefoxSocketConnectionError, "Socket seems to no longer be connected"
      end
#      logger.add(-1) { "RECV_SOCKET is continuing. timeout=#{timeout}; data=#{data.inspect}" }
    end
#    logger.debug { "RECV_SOCKET is done. received_data=#{received_data.inspect}; value_string=#{value_string.inspect}" }
    if @expecting_extra_maybe
      if @socket.ready_to_recv?(config.short_timeout)
        cleared_error=clear_error
        if @prompt && cleared_error==@prompt
          # if all we got was the prompt, just stick it on the value here so that the code below will deal with setting @execting_prompt correctly 
          value_string << cleared_error
        else
          raise FirefoxSocketError, "We finished receiving but the socket was still ready to send! extra data received were: #{cleared_error}"
        end
      end
      @expecting_extra_maybe=false
    end
    
    if expected_size 
      value_string_length=value_string.unpack("U*").length # JSSH returns a utf-8 string, so unpack each character to get the right length 
      
      if value_string_length == expected_size
        @expecting_prompt=true if @prompt
      elsif @prompt && value_string_length == expected_size + @prompt.length &&  value_string =~ /#{Regexp.escape(@prompt)}\z/
        value_string.sub!(/#{Regexp.escape(@prompt)}\z/, '')
        @expecting_prompt=false
      else
        @expecting_extra_maybe=true if value_string_length < expected_size
        raise FirefoxSocketError, "Expected a value of size #{expected_size}; received data of size #{value_string_length}: #{value_string.inspect}"
      end
    else
      if @prompt && value_string =~ /#{Regexp.escape(@prompt)}\z/ # what if the value happens to end with the same string as the prompt? 
        value_string.sub!(/#{Regexp.escape(@prompt)}\z/, '')
        @expecting_prompt=false
      else
        @expecting_prompt=true if @prompt
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
        raise($!.class, $!.message+"\n\ngetting utf8 length of string #{string.inspect}", $!.backtrace)
      end
    end
  end
  # this should be called when an error occurs and we want to clear the socket of any value remaining on it. 
  # tries for config.short_timeout to see if a value will appear on the socket; if one does, returns it. 
  def clear_error
    data=""
    while @socket.ready_to_recv?(config.short_timeout)
      # clear any other crap left on the socket 
      data << @socket.recv(config.read_size)
    end
    if @prompt && data =~ /#{Regexp.escape(@prompt)}\z/
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
    js_expr+=@input_terminator if @input_terminator
#    logger.debug { "SEND_AND_READ sending #{js_expr.inspect}" }
    @mutex.synchronize do
      @socket.sendall(js_expr)
      return read_value(options)
    end
  end
  
  private
  # creates a ruby exception from the given information and raises it. 
  def js_error(name, message, source, js_error_object={})
    require 'stringio'
    require 'pp'
    pretty_js_error_object=""
    PP.pp(js_error_object, StringIO.new(pretty_js_error_object))
    err=FirefoxSocketJavascriptError.new("#{message}\nEvaluating:\n#{source}\n\nJavascript error object:\n#{pretty_js_error_object}")
    err.name=name
    err.source=source
    err.js_err=js_error_object
    ["lineNumber", "stack", "fileName"].each do |attr|
      if js_error_object.key?(attr)
        err.send("#{attr}=", js_error_object[attr])
      end
    end
    raise err
  end
  public

  # returns a string of javascript representing the given object. if given an Array or Hash, 
  # operates recursively. this is like converting to JSON, but this supports more data types 
  # than can be represented in JSON. supported data types are:
  # - Array, Set (converts to javascript Array)
  # - Hash (converts to javascript Object)
  # - JavascriptObject (just uses the reference the JavascriptObject represents) 
  # - Regexp (converts to javascript RegExp)
  # - String, Symbol (converts to a javascript string)
  # - Integer, Float
  # - true, false, nil
  def self.to_javascript(object)
    if ['Array', 'Set'].any?{|klass_name| Object.const_defined?(klass_name) && object.is_a?(Object.const_get(klass_name)) }
      "["+object.map{|element| to_javascript(element) }.join(", ")+"]"
    elsif object.is_a?(Hash)
      "{"+object.map{|(key, value)| to_javascript(key)+": "+to_javascript(value) }.join(", ")+"}"
    elsif object.is_a?(JavascriptObject)
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

  # returns the value of the given javascript expression, as reported by the the firefox extension. 
  #
  # This will be a string, the given expression's toString. 
  def value(js)
    # this is wrapped in a function so that ...
    # dang, now I can't remember. I'm sure I had a good reason at the time. 
    send_and_read("(function(){return #{js}})()")
  end
  
  # assigns to the javascript reference on the left the javascript expression on the right. 
  # returns the value of the expression as reported by the firefox extension, which
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
        raise FirefoxSocketUndefinedValueError, "undefined expression #{js_expr.inspect}"
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
    send_and_read_passthrough_options=[:timeout]
    options=handle_options(options, {:error_on_undefined => true}, send_and_read_passthrough_options)
    raise ArgumentError, "Expected a string containing a javascript expression! received #{js.inspect} (#{js.class})" unless js.is_a?(String)
    ref_error=options[:error_on_undefined] ? "typeof(result)=='undefined' ? {errored: true, value: {'name': 'ReferenceError', 'message': 'undefined expression in: '+result_f.toString()}} : " : ""
    wrapped_js=
      "try
       { var result_f=(function(){return #{js}});
         var result=result_f();
         nativeJSON_encode_length(#{ref_error} {errored: false, value: result});
       }catch(e)
       { nativeJSON_encode_length({errored: true, value: Object.extend({}, e)});
       }"
    val=send_and_read(wrapped_js, options.select_keys(*send_and_read_passthrough_options).merge(:length_before_value => true))
    error_or_val_json(val, js)
  end
  private
  # takes a json value (a string) of the form {errored: boolean, value: anything},
  # checks if an error is indicated, and creates and raises an appropriate exception
  # if so. 
  def error_or_val_json(val, js)
    if !val || val==''
      @expecting_extra_maybe=true
      raise FirefoxSocketError, "received no value! may have timed out waiting for a value that was not coming."
    end
    if val=~ /\ASyntaxError: /
      raise FirefoxSocketSyntaxError, val
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
    js_right=FirefoxSocket.to_javascript(rb_right)
    value_json("#{js_left}=#{js_right}")
  end
  
  # calls to the given function (javascript reference to a function) passing it the
  # given arguments, each argument being converted from a ruby object to a javascript object
  # via JSON. returns the return value of the function, of equivalent type to the javascript 
  # return value, converted from javascript to ruby via JSON. 
  # Uses #value_json; see its documentation.
  def call_json(js_function, *rb_args)
    js_args=rb_args.map{|arg| FirefoxSocket.to_javascript(arg) }
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
        raise FirefoxSocketUndefinedValueError, "undefined expression #{js_expr}"
      else
        if !args.empty?
          raise ArgumentError, "Cannot pass arguments to expression #{js_expr.inspect} of type #{type}"
        end
        value_json(js_expr)
      end
    end
  end

  # returns the type of the given expression using javascript typeof operator, with the exception that
  # if the expression is null, returns 'null' - whereas typeof(null) in javascript returns 'object'
  def typeof(expression)
    js="try
{ nativeJSON_encode_length({errored: false, value: (function(object){ return (object===null) ? 'null' : (typeof object); })(#{expression})});
} catch(e)
{ nativeJSON_encode_length(e.name=='ReferenceError' ? {errored: false, value: 'undefined'} : {errored: true, value: Object.extend({}, e)});
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

  # takes a reference and returns a new JavascriptObject representing that reference on this socket. 
  # ref should be a string representing a reference in javascript. 
  def object(ref, other={})
    JavascriptObject.new(ref, self, {:debug_name => ref}.merge(other))
  end
  # takes a reference and returns a new JavascriptObject representing that reference on this socket, 
  # stored on this socket's temporary object. 
  def object_in_temp(ref, other={})
    object(ref, other).store_rand_temp
  end
  
  # represents the root of the space seen by the FirefoxSocket, and implements #method_missing to 
  # return objects at the root level in a similar manner to JavascriptObject's #method_missing. 
  #
  # for example, jssh_socket.root.Components will return the top-level Components object; 
  # jssh_socket.root.ctypes will return the ctypes top-level object if that is defined, or error 
  # if not. 
  #
  # if the object is a function, then it will be called with any given arguments:
  #  >> jssh_socket.root.getWindows
  #  => #<JavascriptObject:0x0254d150 type=object, debug_name=getWindows()>
  #  >> jssh_socket.root.eval("3+2")
  #  => 5
  #
  # If any arguments are given to an object that is not a function, you will get an error: 
  #  >> jssh_socket.root.Components('wat')
  #  ArgumentError: Cannot pass arguments to Javascript object #<JavascriptObject:0x02545978 type=object, debug_name=Components>
  #
  # special behaviors exist for the suffixes !, ?, and =. 
  #
  # - '?' suffix returns nil if the object does not exist, rather than raising an exception. for
  #   example:
  #    >> jssh_socket.root.foo
  #    FirefoxSocketUndefinedValueError: undefined expression represented by #<JavascriptObject:0x024c3ae0 type=undefined, debug_name=foo> (javascript reference is foo)
  #    >> jssh_socket.root.foo?
  #    => nil
  # - '=' suffix sets the named object to what is given, for example:
  #    >> jssh_socket.root.foo?
  #    => nil
  #    >> jssh_socket.root.foo={:x => ['y', 'z']}
  #    => {:x=>["y", "z"]}
  #    >> jssh_socket.root.foo
  #    => #<JavascriptObject:0x024a3510 type=object, debug_name=foo>
  # - '!' suffix tries to convert the value to json in javascrit and back from json to ruby, even 
  #   when it might be unsafe (causing infinite rucursion or other errors). for example:
  #    >> jssh_socket.root.foo!
  #    => {"x"=>["y", "z"]}
  #   it can be used with function results that would normally result in a JavascriptObject:
  #    >> jssh_socket.root.eval!("[1, 2, 3]")
  #    => [1, 2, 3]
  #   and of course it can error if you try to do something you shouldn't:
  #    >> jssh_socket.root.getWindows!
  #    FirefoxSocketError::NS_ERROR_FAILURE: Component returned failure code: 0x80004005 (NS_ERROR_FAILURE) [nsIJSON.encode]
  def root
    firefox_socket=self
    @root ||= begin
      root = Object.new
      root_metaclass = (class << root; self; end)
      root_metaclass.send(:define_method, :method_missing) do |method, *args|
        method=method.to_s
        if method =~ /\A([a-z_][a-z0-9_]*)([=?!])?\z/i
          method = $1
          suffix = $2
          firefox_socket.object(method).assign_or_call_or_val_or_object_by_suffix(suffix, *args)
        else
          # don't deal with any special character crap 
          super
        end
      end
      root_metaclass.send(:define_method, :[]) do |attribute|
        firefox_socket.object(attribute).val_or_object(:error_on_undefined => false)
      end
      root_metaclass.send(:define_method, :[]=) do |attribute, value|
        firefox_socket.object(attribute).assign(value).val_or_object(:error_on_undefined => false)
      end
      root
    end
  end
  
  # Creates and returns a JavascriptObject representing a function. 
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
  #   => #<JavascriptObject:0x0248e78c type=function, debug_name=function(a, b){ return a+b; }>
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

  # returns a JavascriptObject representing a designated top-level object for temporary storage of stuff
  # on this socket. 
  #
  # really, temporary values could be stored anywhere. this just gives one nice consistent designated place to stick them. 
  attr_reader :temp_object
  # returns a JavascriptObject representing the Components top-level javascript object. 
  #
  # https://developer.mozilla.org/en/Components_object
  def Components
    @components ||= root.Components
  end
  # raises an informative error if the socket is down for some reason 
  def assert_socket
    begin
      actual, expected=[value_json('["foo"]'), ["foo"]]
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE
      raise(FirefoxSocketConnectionError, "Encountered a socket error while checking the socket.\n#{$!.class}\n#{$!.message}", $!.backtrace)
    end
    unless expected==actual
      raise FirefoxSocketError, "The socket seems to have a problem: sent #{expected.inspect} but got back #{actual.inspect}"
    end
  end
  
  # returns a string of basic information about this socket. 
  def inspect
    "\#<#{self.class.name}:0x#{"%.8x"%(self.hash*2)} #{[:host, :port].map{|attr| attr.to_s+'='+send(attr).inspect}.join(', ')}>"
  end
end

