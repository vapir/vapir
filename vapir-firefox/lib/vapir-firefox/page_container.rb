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
    
    # returns nil or raises an error if the given javascript errors. 
    #
    # todo/fix: this should return the last evaluated value, like ie's? 
    def execute_script(javascript)
      jssh_socket.value_json("(function()
      { with(#{content_window_object.ref})
        { #{javascript} }
        return null;
      })()")
      #sandbox=jssh_socket.Components.utils.Sandbox(content_window_object)
      #sandbox.window=content_window_object
      #sandbox.document=content_window_object.document
      #return jssh_socket.Components.utils.evalInSandbox(javascript, sandbox)
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
