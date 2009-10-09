module Watir
  module Specifier
    HowList=[:attributes, :jssh_name, :jssh_object, :dom_object, :xpath]
    LocateAliases=Hash.new{|hash,key| [key]}.merge!({ :text => [:text, :textContent],
                                                        :class => [:class, :className],
                                                      })
    
    module_function
    def match_candidates(candidates, specifiers_list)
      candidates.each do |candidate|
        match=true
        match&&= specifiers_list.any? do |specifier|
          specifier.all? do |(how, what)|
            if how==:types
              what.any? do |type|
                Watir::Specifier.fuzzy_match(candidate.getAttribute(:type), type)
              end
            else
              LocateAliases[how].any? do |how_alias|
                attr=candidate.respond_to?(how_alias) ? candidate[how_alias] : candidate.getAttribute(how_alias)
                #Watir::Specifier.fuzzy_match(candidate.getAttribute(how_alias), what)
                Watir::Specifier.fuzzy_match(attr, what)
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
