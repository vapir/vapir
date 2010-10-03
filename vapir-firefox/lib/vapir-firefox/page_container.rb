require 'vapir-firefox/container'
require 'vapir-common/page_container'

module Vapir
  module Firefox::PageContainer
    include Vapir::PageContainer
    include Firefox::Container
    #def content_window_object
    #  document_object.parentWindow
    #end
    def text
      document_element.textContent
    end
    
    # evaluates a given javascript string in the context of the browser's content window. anything 
    # that is a top-level variable on the window will be seen as a top-level variable in the
    # evaluated script.
    #
    # returns the last evaluated expression. 
    #
    # raises an error if the given javascript errors. 
    #
    # you may specify a hash of other variables that will be available in your script. for example:
    #
    #  >> browser.execute_script("element.tagName + ' ' + foo", :element => browser.buttons.first.element_object, :foo => "baz")
    #  => "BUTTON baz"
    #
    # note, however, that if the name of the variable that you use is the same as a variable on the 
    # window, the window's variable is what will be in scope. for example:
    #
    #   >> browser.execute_script("typeof document", :document => "a string")
    #   => "object"
    #
    # the type is 'object' (not 'string') because window.document is what is seen in the scope.
    #
    # this function is most useful if you need to execute javascript that is only allowed to run in
    # the context of the content window. one example of this is Flash objects - if you try to access 
    # their methods from the top-level context, you get an exception:
    #
    #  >> browser.element(:tag_name => 'embed').element_object.PercentLoaded()
    #  JsshError::Error: NPMethod called on non-NPObject wrapped JSObject!
    #
    # but, this method executes script in the context of the content window, so the following works:
    #
    #  >> browser.execute_script('element.PercentLoaded()', :element => browser.element(:tag_name => 'embed').element_object)
    #  => 100
    def execute_script(javascript, other_variables={})
      sandbox=jssh_socket.Components.utils.Sandbox(content_window_object)
      sandbox.window=content_window_object.window
      other_variables.each do |name, var|
        sandbox[name]=var
      end
      return jssh_socket.Components.utils.evalInSandbox('with(window) { '+javascript+' }', sandbox)
    end

    # Returns the html of the document
    def outer_html
      jssh_socket.object("(function(document)
      { var temp_el=document.createElement('div');
        for(var i in document.childNodes)
        { try
          { temp_el.appendChild(document.childNodes[i].cloneNode(true));
          }
          catch(e)
          {}
        }
        return temp_el.innerHTML;
      })").call(document_object)
    end
    alias html outer_html
  end
end
