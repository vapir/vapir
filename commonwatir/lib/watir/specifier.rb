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
    def specifier_candidates(container, specifiers)
      if container.nil?
        raise ArgumentError, "no container specified!"
      end
      unless specifiers.is_a?(Enumerable) && specifiers.all?{|spec| spec.is_a?(Hash)}
        raise ArgumentError, "specifiers should be a list of Hashes!"
      end
      attributes_in_specifiers=proc do |attr|
        specifiers.inject([]) do |arr, spec|
          spec.each_pair do |spec_attr, spec_val|
            if (spec_attr==attr || Watir::Specifier::LocateAliases[spec_attr].include?(attr)) && !arr.include?(spec_val)
              arr << spec_val
            end
          end
          arr
        end
      end
      ids=attributes_in_specifiers.call(:id)
      tags=attributes_in_specifiers.call(:tagName)
      names=attributes_in_specifiers.call(:name)
      classNames=attributes_in_specifiers.call(:className)

      # we can only use getElementById if:
      # - id is a string, as getElementById doesn't do regexp
      # - index is 1 or nil; otherwise even though it's not really valid, other identical ids won't get searched
      # - id is the _only_ specifier, otherwise if the same id is used multiple times but the first one doesn't match 
      #   the given specifiers, the element won't be found
      # - container has getElementById defined (that is, it's a Browser or a Frame), otherwise if we called 
      #   document_object.getElementById we wouldn't know if what's returned is below container in the DOM heirarchy or not
      if ids.size==1 && ids.first.is_a?(String) && (!@index || @index==1) && !specifiers.any?{|s| s.keys.any?{|k|k!=:id}} && container.containing_object.respond_to?(:getElementById)
        candidates= if by_id=document_object.getElementById(ids.first)
          [by_id]
        else
          []
        end
      elsif names.size==1 && names.first.is_a?(String) && container.containing_object.respond_to?(:getElementsByName)
        candidates=container.containing_object.getElementsByName(names.first)#.to_array
      elsif classNames.size==1 && classNames.first.is_a?(String) && container.containing_object.respond_to?(:getElementsByClassName)
        candidates=container.containing_object.getElementsByClassName(classNames.first)#.to_array
      elsif tags.size==1 && tags.first.is_a?(String)
        candidates=container.containing_object.getElementsByTagName(tags.first)#.to_array
      else # would be nice to use getElementsByTagName for each tag name, but we can't because then we don't know the ordering for index
        candidates=container.containing_object.getElementsByTagName('*')#.to_array
      end
      if candidates.is_a?(Array)
        candidates
      elsif Object.const_defined?('JsshObject') && candidates.is_a?(JsshObject)
        candidates.to_array
      elsif Object.const_defined?('WIN32OLE') && candidates.is_a?(WIN32OLE)
        candidates.send :extend, Enumerable
      else
        raise RuntimeError # this shouldn't happen
      end
    end
    
    module_function
    def match_candidates(candidates, specifiers_list)
      # this proc works around hasAttribute not existing in IE 
      has_attribute = proc do |element, attr|
        if Object.const_defined?('WIN32OLE') && element.is_a?(WIN32OLE)
          begin
            !element.getAttributeNode(attr.to_s).nil?
          rescue WIN32OLERuntimeError
            false
          end
        else
          element.object_respond_to?(:hasAttribute) && element.hasAttribute(attr)
        end
      end
      candidates.each do |candidate|
        candidate_attributes=proc do |attr|
          attrs=[]
          attrs << candidate.getAttributeNode(attr.to_s).value if has_attribute.call(candidate, attr)
          if candidate.object_respond_to?(attr)
            attrs << candidate.invoke(attr.to_s)
          end
#          if Object.const_defined?('JsshObject') && candidate.is_a?(JsshObject)
#            if candidate.js_respond_to?(attr)
#              attrs << candidate.invoke(attr)
#            end
#          elsif Object.const_defined?('WIN32OLE') && candidate.is_a?(WIN32OLE)
#            begin
#              attrs << candidate.invoke(attr.to_s)
#            rescue WIN32OLERuntimeError
#            end
#          else
#            raise RuntimeError, "candidate type not recognized: #{candidate.inspect} (#{candidate.class.name})"
#          end
          attrs
        end
        match= specifiers_list.any? do |specifier|
          specifier.all? do |(how, what)|
            if how==:types
              what.any? do |type|
                candidate_attributes.call(:type).any?{|attr| Watir::Specifier.fuzzy_match(attr, type)}
              end
            else
              ([how]+LocateAliases[how]).any? do |how_alias|
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
      when Numeric
        attr==what || attr==what.to_s
      else
        attr==what
      end
    end
  end
end
