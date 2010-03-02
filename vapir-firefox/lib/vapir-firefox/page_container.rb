module Vapir
  module Firefox::PageContainer
    def containing_object
      document_object
    end
    include Firefox::Container
    def url
      document_object.location.href
    end
    def title
      document_object.title
    end
    def document_element
      document_object.documentElement
    end
    #def content_window_object
    #  document_object.parentWindow
    #end
    def text
      document_element.textContent
    end
    
    def page_container
      self
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
    def html
      jssh_socket.value_json("(function(document){
        var temp_el=document.createElement('div');
        var orig_childs=[];
        while(document.childNodes.length > 0)
        { orig_childs.push(document.childNodes[0]);
          document.removeChild(document.childNodes[0]); 
          /* we remove each childNode here because doing appendChild on temp_el removes it 
           * from document anyway (at least when appendChild works), so we just remove all
           * childNodes so that adding them back in the right order is simpler (using orig_childs)
           */
        }
        for(var i in orig_childs)
        { try
          { temp_el.appendChild(orig_childs[i]);
          }
          catch(e)
          {}
        }
        retval=temp_el.innerHTML;
        while(orig_childs.length > 0)
        { document.appendChild(orig_childs.shift());
        }
        return retval;
      })(#{document_object.ref})", :timeout => JsshSocket::LONG_SOCKET_TIMEOUT)
=begin
      temp_el=document_object.createElement('div') # make a temporary element
      orig_childs=jssh_socket.object('[]').store_rand_object_key(@browser_jssh_objects)
      while document_object.childNodes.length > 0
        orig_childs.push(document_object.childNodes[0])
        document_object.removeChild(document_object.childNodes[0])
      end
      orig_childs.to_array.each do |child|
        begin
          temp_el.appendChild(child)
        rescue JsshError
        end
      end
      result=temp_el.innerHTML
      while orig_childs.length > 0
        document_object.appendChild(orig_childs.shift())
      end
      return result
=end      
    end
  end
end
