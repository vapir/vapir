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
    def active_element
      base_element_class.new(nil, nil, extra_for_contained.merge(:candidates => proc{|container| [container.document_object.activeElement] })).to_subtype
    end
  end
end
