module Watir

  # Base class containing items that are common between the span, div, label, p and pre classes.
  module FFNonControlElement
=begin
    def self.included subclass
      method_names=subclass.respond_to?(:method_names) ? subclass.method_names : []
      #TODO/FIX: icky, move all of these into #method_names's 
      method_names << subclass.name.split('::').last.sub(/\AFF/,'').split(/(?=[A-Z])/).join('_').downcase
      method_names.uniq.each do |method_name|
        Watir::FFContainer.module_eval do
          define_method method_name do |how, *what_args| # can't take how, what as args because blocks don't do default values 
            raise ArgumentError, "Pass one or two arguments!" if what_args.size>1
            what=*what_args
            element_by_howwhat(subclass, how, what)
          end
        end
      end
    end
=end

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
