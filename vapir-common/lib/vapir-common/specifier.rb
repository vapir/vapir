module Vapir
  # This module is included in ElementCollection and Element. it 
  # it expects the includer to have defined:
  # - @container
  # - @extra
  module ElementObjectCandidates
    private
    
    # raises an error unless @container is set 
    def assert_container
      unless @container
        raise Vapir::Exception::MissingContainerException, "No container is defined for this #{self.class.inspect}"
      end
    end
    
    # raises an error unless @container is set and exists 
    def assert_container_exists
      assert_container
      @container.locate!
    end

    # this returns an Enumerable of element objects that _may_ (not necessarily do) match the
    # the given specifier. sometimes specifier is completely ignored. behavor depends on
    # @extra[:candidates]. when the value of @extra[:candidates] is:
    # - nil (default), this uses #get_elements_by_specifiers which uses one of getElementById, 
    #   getElementsByTagName, getElementsByName, getElementsByClassName. 
    # - a symbol - this is assumed to be a method of the containing_object (@container.containing_object). 
    #   this is called, made to be an enumerable, and returned. 
    # - a proc - this is yielded @container and the proc is trusted to return an enumerable
    #   of whatever candidate element objects are desired. 
    # this is used by #locate in Element, and by ElementCollection. 
    def element_object_candidates(specifiers, aliases)
      @container.assert_exists(:force => true) do
        case @extra[:candidates]
        when nil
          get_elements_by_specifiers(@container, specifiers, aliases, respond_to?(:index_is_first) ? index_is_first : false)
        when Symbol
          Vapir::Element.object_collection_to_enumerable(@container.containing_object.send(@extra[:candidates]))
        when Proc
          @extra[:candidates].call(@container)
        else
          raise Vapir::Exception::MissingWayOfFindingObjectException, "Unknown method of specifying candidates: #{@extra[:candidates].inspect} (#{@extra[:candidates].class})"
        end
      end
    end
    # returns an enumerable of 
    def matched_candidates(specifiers, aliases, &block)
      match_candidates(element_object_candidates(specifiers, aliases), specifiers, aliases, &block)
    end
    
    # this is a list of what users can specify (there are additional possible hows that may be given
    # to the Element constructor, but not generally for use by users, such as :element_object or :label
    HowList=[:attributes, :xpath, :custom, :element_object, :label]

    # returns an Enumerable of element objects that _may_ match (note, not do match, necessarily)
    # the given specifiers on the given container. these are obtained from the container's containing_object
    # using one of getElementById, getElementsByName, getElementsByClassName, or getElementsByTagName. 
    def get_elements_by_specifiers(container, specifiers, aliases, want_first=false)
      if container.nil?
        raise ArgumentError, "no container specified!"
      end
      unless specifiers.is_a?(Enumerable) && specifiers.all?{|spec| spec.is_a?(Hash)}
        raise ArgumentError, "specifiers should be a list of Hashes!"
      end
      attributes_in_specifiers=proc do |attr|
        specifiers.inject([]) do |arr, spec|
          spec.each_pair do |spec_attr, spec_val|
            if (aliases[attr] || []).include?(spec_attr) && !arr.include?(spec_val)
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
      #   container.containing_object.getElementById we wouldn't know if what's returned is below container in the DOM heirarchy or not
      # since this is almost always called with specifiers including tag name, input type, etc, getElementById is basically never used. 
      # TODO: have a user-settable flag somewhere that specifies that IDs are unique in pages they use. then getElementById 
      # could be used a lot more than it is limited to here, and stuff would be faster. 
      can_use_getElementById= ids.size==1 && 
                                ids.first.is_a?(String) && 
                                want_first && 
                                !specifiers.any?{|s| s.keys.any?{|k|k!=:id}} && 
                                container.containing_object.object_respond_to?(:getElementById)

      # we can only use getElementsByName if:
      # - name is a string; getElementsByName doesn't do regexp
      # - we're only looking for elements that have a valid name attribute. those are BUTTON TEXTAREA APPLET SELECT FORM FRAME IFRAME IMG A INPUT OBJECT MAP PARAM META
      #   getElementsByTagName doesn't return elements that have a name attribute if name isn't supported on that type of element; 
      #   it's treated as expando. see http://jszen.blogspot.com/2004/07/whats-in-name.html
      #   and http://www.w3.org/TR/html401/index/attributes.html
      #   this only applies to IE, and firefox could use getElementsByName more liberally, but not going to bother detecting that here. 
      #
      # TODO/FIX: account for other bugginess in IE's getElementById / getElementsByName ? 
      # - http://www.romantika.name/v2/javascripts-getelementsbyname-ie-vs-firefox/
      # - http://webbugtrack.blogspot.com/2007/08/bug-411-getelementsbyname-doesnt-work.html
      # - http://webbugtrack.blogspot.com/2007/08/bug-152-getelementbyid-returns.html
      can_use_getElementsByName=names.size==1 && 
                                  names.first.is_a?(String) && 
                                  container.containing_object.object_respond_to?(:getElementsByName) &&
                                  specifiers.all?{|specifier| specifier[:tagName].is_a?(String) && %w(BUTTON TEXTAREA APPLET SELECT FORM FRAME IFRAME IMG A INPUT OBJECT MAP PARAM META).include?(specifier[:tagName].upcase) }
      if can_use_getElementById
        candidates= if by_id=container.containing_object.getElementById(ids.first)
          [by_id]
        else
          []
        end
      elsif can_use_getElementsByName
        candidates=container.containing_object.getElementsByName(names.first)#.to_array
      elsif classNames.size==1 && classNames.first.is_a?(String) && container.containing_object.object_respond_to?(:getElementsByClassName)
        candidates=container.containing_object.getElementsByClassName(classNames.first)
      elsif tags.size==1 && tags.first.is_a?(String)
        candidates=container.containing_object.getElementsByTagName(tags.first)
      else # would be nice to use getElementsByTagName for each tag name, but we can't because then we don't know the ordering for index
        candidates=container.containing_object.getElementsByTagName('*')
      end
      # return:
      if candidates.is_a?(Array)
        candidates
      elsif Object.const_defined?('JsshObject') && candidates.is_a?(JsshObject)
        candidates.to_array
      elsif Object.const_defined?('WIN32OLE') && candidates.is_a?(WIN32OLE)
        candidates.send :extend, Enumerable
      else
        raise RuntimeError, "candidates ended up unexpectedly being #{candidates.inspect} (#{candidates.class}) - don't know what to do with this" # this shouldn't happen
      end
    end
    
    module_function
    def match_candidates(candidates, specifiers_list, aliases)
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
          (function(candidates, specifiers_list, aliases)
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
              var match=true;
              match= match && candidate.nodeType==1;
              match= match && specifiers_list.any(function(specifier)
              { return $H(specifier).all(function(howwhat)
                { how=howwhat.key;
                  what=howwhat.value;
                  if(how=='types')
                  { return what.any(function(type)
                    { return candidate_attributes('type').any(function(attr){ return fuzzy_match(attr, type); });
                    });
                  }
                  else
                  { var matched_aliases=$H(aliases).reject(function(dom_attr_alias_list)
                    { var alias_list=$A(dom_attr_alias_list.value);
                      return !alias_list.include(how);
                    }).pluck('key');
                    return $A([how].concat(matched_aliases)).any(function(how_alias)
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
        matched_candidates=match_candidates_js.call(candidates, specifiers_list, aliases)
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
          # this bit isn't reflected in the javascript above because firefox doesn't behave this way, returning nil 
          if candidate==nil
            raise Exception::ExistenceFailureException, "when searching for an element, a candidate was nil. (this tends to happen when a page is changing and things stop existing.)\nspecifiers are: #{specifiers_list.inspect}"
          end
          
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
          match=true
          if Object.const_defined?('WIN32OLE') && candidate.is_a?(WIN32OLE)
            begin
              match &&= candidate.nodeType==1
            rescue WIN32OLERuntimeError
              match=false
            end
          else
            if candidate.object_respond_to?(:nodeType)
              match &&= candidate.nodeType==1
            else
              match=false
            end
          end
          match &&= specifiers_list.any? do |specifier|
            specifier.all? do |(how, what)|
              if how==:types
                what.any? do |type|
                  candidate_attributes.call(:type).any?{|attr| Vapir::fuzzy_match(attr, type)}
                end
              else
                matched_aliases = aliases.reject do |dom_attr, alias_list|
                  !alias_list.include?(how)
                end.keys
                (matched_aliases+[how]).any? do |how_alias|
                  candidate_attributes.call(how_alias).any?{|attr| Vapir::fuzzy_match(attr, what)}
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
  end

  # This is on the Vapir module itself because it's used in a number of other places, should be in a broad namespace. 
  module_function
  def fuzzy_match(attr, what)
    # IF YOU CHANGE THIS, CHANGE THE JAVASCRIPT REIMPLEMENTATION IN match_candidates
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
