module Watir
  module Specifier
    HowList=[:attributes, :element_object, :xpath]
    LocateAliases=Hash.new{|hash,key| [] }.merge(
                  { :text => [:textContent, :innerText],
                    :class => [:className],
                    :class_name => [:className],
                    :caption => [:textContent, :value], # this is used for buttons so you can get whatever text is on the button, be it value or inner text. 
                    :url => [:href],
                  })
    
    module_function
    def match_candidates(candidates, specifiers_list)
      # this proc works around hasAttribute not existing in IE 
      has_attribute = proc do |element, attr|
        if Object.const_defined?('JsshObject') && element.is_a?(JsshObject)
          element.js_respond_to?(:hasAttribute) && element.hasAttribute(attr)
        elsif Object.const_defined?('WIN32OLE') && element.is_a?(WIN32OLE)
          found_attribute=false
          element_attributes= element.respond_to?('attributes') ? (element.attributes || []) : []
          element_attributes.each do |ole_attribute|
            if ole_attribute.nodeName.downcase==attr.to_s.downcase
              found_attribute=true
              break
            end
          end
          found_attribute
        else
          raise RuntimeError, "element type not recognized: #{element.inspect} (#{element.class.name})"
        end
      end
      candidates.each do |candidate|
        candidate_attributes=proc do |attr|
          attrs=[]
          attrs << candidate.getAttribute(attr.to_s) if has_attribute.call(candidate, attr)#candidate.respond_to?(:hasAttribute) && candidate.hasAttribute(attr.to_s)
          if Object.const_defined?('JsshObject') && candidate.is_a?(JsshObject)
            if candidate.js_respond_to?(attr)
              attrs << candidate.get(attr)
            end
          elsif Object.const_defined?('WIN32OLE') && candidate.is_a?(WIN32OLE)
            if candidate.ole_respond_to?(attr)#ole_methods.detect{|meth| meth.to_s==attr.to_s}
              attrs << candidate.invoke(attr.to_s)
            end
          else
            raise RuntimeError, "candidate type not recognized: #{candidate.inspect} (#{candidate.class.name})"
          end
          attrs
        end
        match=true
        match&&= specifiers_list.any? do |specifier|
          specifier.all? do |(how, what)|
            if how==:types
              what.any? do |type|
#                candidate_attributes=[]
#                candidate_attributes << candidate.getAttribute('type') if candidate.respond_to?(:hasAttribute) && candidate.hasAttribute('type') # this won't work for default types, like a plain <input> where type defaults to text
#                respond_to=case candidate
#                when JsshObject
#                  candidate.js_respond_to?(:type)
#                when WIN32OLE
#                end
#                candidate_attributes << candidate.method_missing(:type) if candidate.js_respond_to?(:type)        # but this one gets the default type if it's not an attribute
#                candidate_attributes.any?{|attr| Watir::Specifier.fuzzy_match(attr, type)}
                candidate_attributes.call(:type).any?{|attr| Watir::Specifier.fuzzy_match(attr, type)}
              end
            else
              ([how]+LocateAliases[how]).any? do |how_alias|
                #attr=candidate.hasAttribute(how_alias) ? candidate.getAttribute(how_alias) : candidate.respond_to?(how_alias) ? candidate.get(how_alias) : nil
#                candidate_attributes=[]
#                candidate_attributes << candidate.getAttribute(how_alias) if candidate.respond_to?(:hasAttribute) && candidate.hasAttribute(how_alias)
#                candidate_attributes << candidate.get(how_alias) if candidate.js_respond_to?(how_alias)
#                candidate_attributes.any?{|attr| Watir::Specifier.fuzzy_match(attr, what)}
                candidate_attributes.call(how_alias).any?{|attr| Watir::Specifier.fuzzy_match(attr, what)}
              end
            end
          end
        end
        if match
          yield candidate
        end
      end
      nil
    end
    module_function
    def fuzzy_match(attr, what)
      case what
      when String, Symbol
        case attr
        when String, Symbol
          attr.to_s.downcase.strip==what.to_s.downcase.strip
        else
          attr==what
        end
      when Regexp
        case attr
        when Regexp
          attr==what
        else
         attr =~ what
        end
     else
        attr==what
      end
    end
  end
end
