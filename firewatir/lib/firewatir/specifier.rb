module Watir
  module Specifier
    HowList=[:attributes, :jssh_name, :jssh_object, :dom_object, :xpath]
    LocateAliases=Hash.new{|hash,key| [] }.merge(
                  { :text => [:textContent],
                    :class => [:className],
                    :class_name => [:className],
                    :caption => [:textContent, :value], # this is used for buttons so you can get whatever text is on the button, be it value or inner text. 
                    :url => [:href],
                  })
    
    module_function
    def match_candidates(candidates, specifiers_list)
      candidates.each do |candidate|
        match=true
        match&&= specifiers_list.any? do |specifier|
          specifier.all? do |(how, what)|
            if how==:types
              what.any? do |type|
                candidate_attributes=[]
                candidate_attributes << candidate.getAttribute(:type) if candidate.respond_to?(:hasAttribute) && candidate.hasAttribute(:type) # this won't work for default types, like a plain <input> where type defaults to text
                candidate_attributes << candidate.get(:type) if candidate.js_respond_to?(:type)        # but this one gets the default type if it's not an attribute
                candidate_attributes.any?{|attr| Watir::Specifier.fuzzy_match(attr, type)}
              end
            else
              ([how]+LocateAliases[how]).any? do |how_alias|
                #attr=candidate.hasAttribute(how_alias) ? candidate.getAttribute(how_alias) : candidate.respond_to?(how_alias) ? candidate.get(how_alias) : nil
                candidate_attributes=[]
                candidate_attributes << candidate.getAttribute(how_alias) if candidate.respond_to?(:hasAttribute) && candidate.hasAttribute(how_alias)
                candidate_attributes << candidate.get(how_alias) if candidate.js_respond_to?(how_alias)
                candidate_attributes.any?{|attr| Watir::Specifier.fuzzy_match(attr, what)}
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
