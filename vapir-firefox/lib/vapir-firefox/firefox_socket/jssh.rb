require 'vapir-firefox/firefox_socket/base'

# A JsshSocket represents a connection to Firefox over a socket opened to the JSSH extension. 
class JsshSocket < FirefoxSocket
  @configuration_parent = FirefoxSocket.config
  config.update_hash({
    :port => 9997,
  })

  def eat_welcome_message
    @prompt="\n> "
    welcome="Welcome to the Mozilla JavaScript Shell!\n"
    read=read_value
    if !read
      @expecting_extra_maybe=true
      raise FirefoxSocketUnableToStart, "Something went wrong initializing - no response" 
    elsif read != welcome
      @expecting_extra_maybe=true
      raise FirefoxSocketUnableToStart, "Something went wrong initializing - message #{read.inspect} != #{welcome.inspect}" 
    end
  end
end

