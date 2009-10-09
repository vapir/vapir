require 'watir/specifier'
#require 'watir/elements/element_collection'

module Watir
  module Container
    def element_by_howwhat(klass, how, what, other={})
      other={:locate => false, :other_attributes => nil}.merge(other)
      how, what, index=*normalize_howwhat_index(how, what, klass.respond_to?(:default_how) && klass.default_how)
      if other[:other_attributes]
        if how==:attributes
          what.merge!(other[:other_attributes])
        else
          raise
        end
      end
      element=klass.new(how, what, extra.merge(:index => index, :locate => other[:locate]))
      element.exists? ? element : nil
    end
    def element_collection(klass)
      elements=[]
      Watir::Specifier.match_candidates(Watir::Specifier.specifier_candidates(self, klass.specifiers), klass.specifiers) do |match|
        elements << klass.new(:element_object, match, extra)
      end
      ElementCollection.new(elements)
    end
    def normalize_howwhat_index(how, what, default_how=nil)
      case how
      when nil
        raise
      when Hash
        how=how.dup
        index=how.delete(:index)
        what==nil ? [:attributes, how, index] : raise
      when String, Symbol
        if Watir::Specifier::HowList.include?(how)
          [how, what, nil]
        else
          if what.nil?
            if default_how
              [:attributes, {default_how => how}, nil]
            else
              raise
            end
          elsif how==:index
            [:attributes, {}, what]
          else
            [:attributes, {how.to_sym => what}, nil]
          end
        end
      else
        raise
      end
    end
  end
end
