module Watir

  # Forms
  
  module IEFormAccess
    def name
      @element_object.getAttributeNode('name').value
    end
    def action
      @element_object.action
    end
    def method
      @element_object.invoke('method')
    end
    def id
      @element_object.invoke('id')
    end
  end
  
  # wraps around a form OLE object
  class IEFormWrapper
    include IEFormAccess
    def initialize ole_object
      @element_object = ole_object
    end
  end
  
  #   Form Factory object
  class IEForm < IEElement
    include Form
    include IEFormAccess
    include IEContainer
    
    attr_accessor :form, :ole_object
    
    #   * container   - the containing object, normally an instance of IE
    #   * how         - symbol - how we access the form (:name, :id, :index, :action, :method)
    #   * what        - what we use to access the form
#    def initialize(container, how, what)
#      set_container container
#      @how = how
#      @what = what
#      
#      log "Get form how is #{@how}  what is #{@what} "
#      
#      # Get form using xpath.
#      if @how == :xpath
#        @element_object = @container.element_by_xpath(@what)
#      else
#        count = 1
#        doc = @container.document
#        doc.forms.each do |thisForm|
#          next unless @element_object == nil
#          
#          wrapped = IEFormWrapper.new(thisForm)
#          @element_object =
#          case @how
#          when :name, :id, :method, :action
#            @what.matches(wrapped.send(@how)) ? thisForm : nil
#          when :index
#            count == @what ? thisForm : nil
#          else
#            raise MissingWayOfFindingObjectException, "#{how} is an unknown way of finding a form (#{what})"
#          end
#          count += 1
#        end
#      end
#      super(@element_object)
#      
#      copy_test_config container
#    end
    
    def exists?
      @element_object ? true : false
    end
    alias :exist? :exists?
    
    def assert_exists
      unless exists?
        raise UnknownFormException, 
          "Unable to locate a form using #{@how} and #{@what}" 
      end
    end
    
    # Submit the data -- equivalent to pressing Enter or Return to submit a form.
    def submit 
      assert_exists
      @element_object.invoke('submit')
      @container.wait
    end
    
    def ole_inner_elements
      assert_exists
      @element_object.elements
    end
    private :ole_inner_elements
    
    def document
      return @element_object
    end
    
    def wait(no_sleep=false)
      @container.wait(no_sleep)
    end
    
    # This method is responsible for setting and clearing the colored highlighting on the specified form.
    # use :set  to set the highlight
    #   :clear  to clear the highlight
    def highlight(set_or_clear, element, count)
      
      if set_or_clear == :set
        begin
          original_color = element.style.backgroundColor
          original_color = "" if original_color==nil
          element.style.backgroundColor = activeObjectHighLightColor
#        rescue => e
#          puts e
#          puts e.backtrace.join("\n")
#          original_color = ""
        end
        @original_styles[count] = original_color
      else
        begin
          element.style.backgroundColor = @original_styles[ count]
#        rescue => e
#          puts e
          # we could be here for a number of reasons...
#        ensure
        end
      end
    end
    private :highlight
    
    # causes the object to flash. Normally used in IRB when creating scripts
    # Default is 10
    def flash number=10
      @original_styles = {}
      number.times do
        count = 0
        @element_object.elements.each do |element|
          highlight(:set, element, count)
          count += 1
        end
        sleep 0.05
        count = 0
        @element_object.elements.each do |element|
          highlight(:clear, element, count)
          count += 1
        end
        sleep 0.05
      end
    end
    
  end # class IEForm
  
end

module Watir
  class IEForms < IEElementCollections
    def element_class; Form; end
    def element_tag; 'FORM'; end
    def length
      @container.document.getElementsByTagName("FORM").length
    end
  end

  module IEContainer
    def forms
      Forms.new(self)
    end
  end
end