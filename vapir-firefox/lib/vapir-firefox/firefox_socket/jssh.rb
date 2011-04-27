require 'vapir-firefox/firefox_socket/base'

# A JsshSocket represents a connection to Firefox over a socket opened to the JSSH extension. 
class JsshSocket < FirefoxSocket
  @configuration_parent = FirefoxSocket.config
  config.update_hash({
    :port => 9997,
  })
end

