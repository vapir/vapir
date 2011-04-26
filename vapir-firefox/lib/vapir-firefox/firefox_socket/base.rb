# base exception class for all exceptions raised from Jssh sockets and objects. 
class FirefoxSocketError < StandardError;end
# this exception covers all connection errors either on startup or during usage. often it represents an Errno error such as Errno::ECONNRESET. 
class FirefoxSocketConnectionError < FirefoxSocketError;end
# This exception is thrown if we are unable to connect to JSSh.
class FirefoxSocketUnableToStart < FirefoxSocketConnectionError;end
# Represents an error encountered on the javascript side, caught in a try/catch block. 
class FirefoxSocketJavascriptError < FirefoxSocketError
  attr_accessor :source, :js_err, :lineNumber, :stack, :fileName
end
# represents a syntax error in javascript. 
class FirefoxSocketSyntaxError < FirefoxSocketJavascriptError;end
# raised when a javascript value is expected to be defined but is undefined
class FirefoxSocketUndefinedValueError < FirefoxSocketJavascriptError;end

# abstract base class for socket connections to firefox extensions 
class FirefoxSocket
end
