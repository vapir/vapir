module Watir
  module Specifier
    HowList=[:attributes, :jssh_name, :jssh_object, :dom_object, :xpath]
    LocateAliases=Hash.new{|hash,key| [key]}.merge!(:text => [:text, :textContent])
    
    module_function
    def match_candidates(candidates, specifiers_list)
      candidates.each do |candidate|
        match=true
        match&&= specifiers_list.any? do |specifier|
          specifier.all? do |(how, what)|
            if how==:types
              what.any? do |type|
                Watir::Specifier.fuzzy_match(candidate[:type], type)
              end
            else
              LocateAliases[how].any? do |how_alias|
                Watir::Specifier.fuzzy_match(candidate[how_alias], what)
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
=begin
  class Specifier
    MatchAliases=Hash.new{|hash,key| [key]}.merge!(:text => [:text, :textContent])
    # options:
    # - :specifiers => an array of specifier hashes
    # - :how, :what => 
    def initialize(options={})
      options={}.merge(options)
      @howwhat_specifier=if what.nil?
        case how
        when String, Symbol
          default_how ? {default_how => how} : {how.to_sym => what}
        when Hash
          how.dup
        when nil
          {}
        else
          default_how ? {default_how => how} : (raise "Invalid how: #{how.inspect}; what: #{what.inspect}")
        end
      else # what is not nil
        if how.is_a?(String)||how.is_a?(Symbol)
          {how.to_sym => what}
        else
          raise "Invalid how: #{how.inspect}; what: #{what.inspect}"
        end
      end
#      spec.inject({}) do |hash,(how,what)|
#        hash[MatchAliases[how.to_sym]]=what
#        hash
#      end
    end
    def self.howwhat_to_specifier(how, what, )
    
  end
=end
end
