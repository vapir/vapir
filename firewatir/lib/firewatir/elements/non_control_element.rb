module Watir

  # Base class containing items that are common between the span, div, label, p and pre classes.
  class FFNonControlElement < FFElement
    include NonControlElement
    def self.inherited subclass
      method_names=subclass.respond_to?(:method_names) ? subclass.method_names : []
      #TODO/FIX: icky, move all of these into #method_names's 
      method_names << subclass.name.split('::').last.sub(/\AFF/,'').split(/(?=[A-Z])/).join('_').downcase
      method_names.uniq.each do |method_name|
        Watir::FFContainer.module_eval do
          define_method method_name do |*args| # can't take how, what as args because blocks don't do default values 
            raise ArgumentError, "Pass one or two arguments!" if args.size>2
            how, what=*args
            element_by_howwhat(subclass, how, what)
          end
        end
      end
    end

    #
    # Description:
    #   Locate the element on the page. Element can be a span, div, label, p or pre HTML tag.
    #
#    def locate
#      case @how
#      when :jssh_name
#        @element_name = @what
#      when :xpath
#        @element_name = element_by_xpath(@container, @what)
#      else
#        @element_name = locate_tagged_element(self.class::TAG, @how, @what)
#      end
#      @o = self
#    end

    #   - how - Attribute to identify the element.
    #   - what - Value of that attribute.
#    def initialize(container, how, what)
#      #@element = Element.new(nil)
#      @how = how
#      @what = what
#      @container = container
#      @o = nil
#    end

    # Returns a string of properties of the object.
    def to_s(attributes = nil)
      assert_exists
      hash_properties = {"text"=>"innerHTML"}
      hash_properties.update(attributes) if attributes != nil
      r = super(hash_properties)
      #r = string_creator
      #r += span_div_string_creator
      return r#.join("\n")
    end

  end # NonControlElement
end # FireWatir
