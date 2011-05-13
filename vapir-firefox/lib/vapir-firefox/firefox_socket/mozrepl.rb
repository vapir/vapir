require 'vapir-firefox/firefox_socket/base'

# A MozreplSocket represents a connection to Firefox over a socket opened to the MozRepl extension. 
class MozreplSocket < FirefoxSocket
  @configuration_parent = FirefoxSocket.config
  config.update_hash({
    :port => 4242,
  })

  # returns an array of command line flags that should be used to invoke firefox for mozrepl 
  def self.command_line_flags(options={})
    options = config.defined_hash.merge(options)
    ['-repl', options['port']]
  end
  
  def eat_welcome_message
    read=read_value
    if !read
      @expecting_extra_maybe=true
      raise FirefoxSocketUnableToStart, "Something went wrong initializing - no response" 
    elsif read !~ /Welcome to MozRepl/
      @expecting_extra_maybe=true
      raise FirefoxSocketUnableToStart, "Something went wrong initializing - message #{read.inspect}"
    end
    if read =~ /yours will be named "([^"]+)"/
      @replname=$1
    else
      @replname='repl'
    end
    @prompt="#{@replname}> "
    @expecting_prompt = read !~ /#{Regexp.escape(@prompt)}\z/
  end
  def initialize_environment
    # change the prompt mode to something less decorative 
    #send_and_read("#{@replname}.home()")
    send_and_read("#{@replname}.setenv('printPrompt', false)")
    @prompt="\n"
    @expecting_prompt=false
    send_and_read("#{@replname}.setenv('inputMode', 'multiline')")
    @input_terminator = "--end-remote-input\n"

    # set up objects that are needed: nativeJSON_encode_length, VapirTemp, and Vapir
    ret=send_and_read(%Q((function(the_repl, context)
    { var nativeJSON=Components.classes['@mozilla.org/dom/json;1'].createInstance(Components.interfaces.nsIJSON);
      context.nativeJSON_encode_length=function(object)
      { var encoded=nativeJSON.encode(object);
        the_repl.print(encoded.length.toString()+"\\n"+encoded, false);
      }
      context.VapirTemp = {};
      context.Vapir = {};
      return 'done!';
    })(#{@replname}, this)))
    if ret !~ /done!/
      @expecting_extra_maybe=true
      raise FirefoxSocketError, "Something went wrong initializing environment - message #{ret.inspect}"
    end
  end
end

