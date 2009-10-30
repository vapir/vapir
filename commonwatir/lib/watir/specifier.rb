module Watir
  module Specifier
    # this is a list of what users can specify (there are additional possible hows that may be given
    # to the Element constructor, but not generally for use by users, such as :element_object or :label
    HowList=[:attributes, :xpath, :custom]
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

      # TODO/FIX: account for IE's getElementById / getElementsByName bug? 
      # - http://www.romantika.name/v2/javascripts-getelementsbyname-ie-vs-firefox/
      # - http://jszen.blogspot.com/2004/07/whats-in-name.html
      # - http://webbugtrack.blogspot.com/2007/08/bug-411-getelementsbyname-doesnt-work.html
      # - http://webbugtrack.blogspot.com/2007/08/bug-152-getelementbyid-returns.html

      # we can only use getElementById if:
      # - id is a string, as getElementById doesn't do regexp
      # - index is 1 or nil; otherwise even though it's not really valid, other identical ids won't get searched
      # - id is the _only_ specifier, otherwise if the same id is used multiple times but the first one doesn't match 
      #   the given specifiers, the element won't be found
      # - container has getElementById defined (that is, it's a Browser or a Frame), otherwise if we called 
      #   container.containing_object.getElementById we wouldn't know if what's returned is below container in the DOM heirarchy or not
      # since this is almost always called with specifiers including tag name, input type, etc, getElementById is basically never used. 
      # TODO: have a user-settable flag somewhere that specifies that IDs are unique in pages they use. then getElementById 
      # could be used a lot more than it is limited to here, and stuff would be faster. 
      if ids.size==1 && ids.first.is_a?(String) && (!@index || @index==1) && !specifiers.any?{|s| s.keys.any?{|k|k!=:id}} && container.containing_object.object_respond_to?(:getElementById)
        candidates= if by_id=container.containing_object.getElementById(ids.first)
          [by_id]
        else
          []
        end
      elsif names.size==1 && names.first.is_a?(String) && container.containing_object.object_respond_to?(:getElementsByName)
        candidates=container.containing_object.getElementsByName(names.first)#.to_array
      elsif classNames.size==1 && classNames.first.is_a?(String) && container.containing_object.object_respond_to?(:getElementsByClassName)
        candidates=container.containing_object.getElementsByClassName(classNames.first)
      elsif tags.size==1 && tags.first.is_a?(String)
        candidates=container.containing_object.getElementsByTagName(tags.first)
      else # would be nice to use getElementsByTagName for each tag name, but we can't because then we don't know the ordering for index
        candidates=container.containing_object.getElementsByTagName('*')
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
      unless specifiers_list.is_a?(Enumerable) && specifiers_list.all?{|spec| spec.is_a?(Hash)}
        raise ArgumentError, "specifiers_list should be a list of Hashes!"
      end
      if candidates.length != 0 && Object.const_defined?('JsshObject') && (candidates.is_a?(JsshObject) || candidates.all?{|c| c.is_a?(JsshObject)})
        # optimize for JSSH by moving code to the other side of the socket, rather than talking across it a whole lot
        # this javascript should be exactly the same as the ruby in the else (minus WIN32OLE optimization) - 
        # just written in javascript instead of ruby. 
        #
        # Note that the else block works perfectly fine, but is much much slower due to the amount of 
        # socket activity. 
        jssh_socket= candidates.is_a?(JsshObject) ? candidates.jssh_socket : candidates.first.jssh_socket
        match_candidates_js=JsshObject.new("
          (function(candidates, specifiers_list, LocateAliases)
          { candidates=$A(candidates);
            specifiers_list=$A(specifiers_list);
            var matched_candidates=[];
            var fuzzy_match=function(attr, what)
            { if(typeof what=='string')
              { if(typeof attr=='string')
                { return attr.toLowerCase().strip()==what.toLowerCase().strip();
                }
                else
                { return attr==what;
                }
              }
              else if(typeof what=='number')
              { return attr==what || attr==what.toString();
              }
              else
              { if(typeof attr=='string')
                { return attr.match(what);
                }
                else
                { return attr==what;
                }
              }
            };
            candidates.each(function(candidate)
            { var candidate_attributes=function(attr)
              { var attrs=[];
                if(candidate.hasAttribute && candidate.hasAttribute(attr))
                { attrs.push(candidate.getAttributeNode(attr).value);
                }
                if(candidate[attr])
                { attrs.push(candidate[attr]);
                }
                return $A(attrs);
              };
              var match= specifiers_list.any(function(specifier)
              { return $H(specifier).all(function(howwhat)
                { how=howwhat.key;
                  what=howwhat.value;
                  if(how=='types')
                  { return what.any(function(type)
                    { return candidate_attributes('type').any(function(attr){ return fuzzy_match(attr, type); });
                    });
                  }
                  else
                  { return $A([how].concat(LocateAliases[how] || [])).any(function(how_alias)
                    { return candidate_attributes(how_alias).any(function(attr){ return fuzzy_match(attr, what); });
                    });
                  }
                })
              });
              if(match)
              { matched_candidates.push(candidate);
              }
            });
            return matched_candidates;
          })
        ", jssh_socket, :debug_name => 'match_candidates_function')
        matched_candidates=match_candidates_js.call(candidates, specifiers_list, LocateAliases)
        if block_given?
          matched_candidates.to_array.each do |matched_candidate|
            yield matched_candidate
          end
        end
        return matched_candidates.to_array
      else
        # IF YOU CHANGE THIS CODE CHANGE THE CORRESPONDING JAVASCRIPT ABOVE TOO 
        matched_candidates=[]
        candidates.each do |candidate|
          candidate_attributes=proc do |attr|
            attrs=[]
            if Object.const_defined?('WIN32OLE') && candidate.is_a?(WIN32OLE)
              # ie & WIN32OLE optimization: hasAttribute does not exist on IE, and also avoid respond_to? on WIN32OLE; it is slow. 
              begin
                attr_node=candidate.getAttributeNode(attr.to_s)
                attrs << attr_node.value if attr_node
              rescue WIN32OLERuntimeError
              end
              begin
                attrs << candidate.invoke(attr.to_s)
              rescue WIN32OLERuntimeError
              end
            else 
              # this doesn't actually get called anymore, since there are optimizations for both IE and firefox. 
              # leaving it here anyway - maybe someday a different browser will have an object this code can use, 
              # or maybe someday IE or firefox or both will not need the optimizations above. 
              if candidate.object_respond_to?(:hasAttribute) && candidate.hasAttribute(attr)
                attrs << candidate.getAttributeNode(attr.to_s).value
              end
              if candidate.object_respond_to?(attr)
                attrs << candidate.invoke(attr.to_s)
              end
            end
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
            if block_given?
              yield candidate
            end
            matched_candidates << candidate
          end
        end
        return matched_candidates
      end
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
