# load the correct version of win32ole

# Use our modified win32ole library

if RUBY_VERSION =~ /^1\.8/
  $LOAD_PATH.unshift  File.expand_path(File.join(File.dirname(__FILE__), '..', 'vapir-ie', 'win32ole'))
else
  # loading win32ole from stdlib on 1.9
end


require 'win32ole'

WIN32OLE.codepage = WIN32OLE::CP_UTF8

# necessary extension of win32ole 
class WIN32OLE
  def respond_to?(method)
    super || object_respond_to?(method)
  end
  
  # checks if WIN32OLE#ole_method returns an WIN32OLE_METHOD, or errors. 
  # WARNING: #ole_method is pretty slow, and consequently so is this. you are likely to be better
  # off just calling a method you are not sure exists, and rescuing the WIN32OLERuntimeError
  # that is raised if it doesn't exist. 
  def object_respond_to?(method)
    method=method.to_s
    # strip assignment = from methods. going to assume that if it has a getter method, it will take assignment, too. this may not be correct, but will have to do. 
    if method =~ /=\z/
      method=$`
    end
    respond_to_cache[method]
  end
  
  private
  def respond_to_cache
    @respond_to_cache||=Hash.new do |hash, key|
      hash[key]=begin
        !!self.ole_method(key)
      rescue WIN32OLERuntimeError, NoMethodError
        false
      end
    end
  end
end
