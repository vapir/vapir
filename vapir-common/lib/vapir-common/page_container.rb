module Vapir
  module PageContainer
    def containing_object
      document_object
    end
    def document_element
      document_object.documentElement
    end
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
