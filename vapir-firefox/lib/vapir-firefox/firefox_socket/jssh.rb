require 'vapir-firefox/firefox_socket/base'

# A JsshSocket represents a connection to Firefox over a socket opened to the JSSH extension. It 
# does the work of interacting with the socket and translating ruby values to javascript and back. 
class JsshSocket < FirefoxSocket
  @configuration_parent = FirefoxSocket.config
  config.update_hash({
    :port => 9997,
  })
end

