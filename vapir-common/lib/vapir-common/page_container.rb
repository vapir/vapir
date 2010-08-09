module Vapir
  module PageContainer
    include Vapir::Container
    def containing_object
      document_object
    end
    def document_element_object
      document_object.documentElement || raise(Exception::ExistenceFailureException, "document_object.documentElement was nil")
    end
    alias document_element document_element_object
    
    def title
      document_object.title
    end
    # The url of the page object. 
    def url
      document_object.location.href
    end
    def page_container
      self
    end
  end
end
