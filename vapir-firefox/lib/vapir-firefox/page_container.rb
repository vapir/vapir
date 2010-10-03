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
    
    # evaluates a given javascript string. 
    # returns the last evaluated expression. 
    # raises an error if the given javascript errors. 
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
