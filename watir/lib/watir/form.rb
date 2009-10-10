module Watir

  class IEForm < IEElement
    include Form
    
    # Submit the data -- equivalent to pressing Enter or Return to submit a form.
    def submit 
      assert_exists
      @element_object.invoke('submit')
      wait
    end
    
    # This method is responsible for setting and clearing the colored highlighting on the specified form.
    # use :set  to set the highlight
    #   :clear  to clear the highlight
    # TODO: move to common
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
