=begin
    #
    # This module contains the factory methods that are used to access most html objects
    #
    # For example, to access a button on a web page that has the following html
    #  <input type = button name= 'b1' value='Click Me' onClick='javascript:doSomething()'>
    #
    # the following Firewatir code could be used
    #
    #  ff.button(:name, 'b1').click
    #
    # or
    #
    #  ff.button(:value, 'Click Me').to_s
    # 
    # One can use any attribute to uniquely identify an element including the user defined attributes
    # that is rendered on the HTML screen. Though, Attribute used to access an element depends on the type of element,
    # attributes used frequently to address an element are listed below
    #
    #    :index      - find the item using the index in the container ( a container can be a document, 
    #    		a TableCell, a Span, a Div or a P)
    #                  index is 1 based
    #    :name       - find the item using the name attribute
    #    :id         - find the item using the id attribute
    #    :value      - find the item using the value attribute
    #    :caption    - same as value
    #    :xpath      - finds the item using xpath query
    #
    # Typical Usage
    #
    #    ff.button(:id,    'b_1')                       # access the button with an ID of b_1
    #    ff.button(:name,  'verify_data')               # access the button with a name of verify_data
    #    ff.button(:value, 'Login')                     # access the button with a value (the text displayed on the button) of Login
    #    ff.button(:caption, 'Login')                   # same as above
    #    ff.button(:value, /Log/)                       # access the button that has text matching /Log/
    #    ff.button(:index, 2)                           # access the second button on the page ( 1 based, so the first button is accessed with :index,1)
    #
=end

require 'firewatir/exceptions'

module Watir
  module FFContainer 
    include Container
    #include FireWatir
    #include Watir::Exception
    
    # The default color for highlighting objects as they are accessed.
    DEFAULT_HIGHLIGHT_COLOR = "yellow"
    
    LocateAliases=Hash.new{|hash,key| [key]}.merge!(:text => [:text, :textContent])
    
    private
    # locates the element specified. 
    # specifiers_list is a list of specifiers, where a specifier is a hash of the javascript object to match. 
    # For example, the specifier_list
    #   [ {:tagName => 'textarea'},
    #     {:tagName => 'input', :types => ['text', 'textarea','password']},
    #   ]
    # (used by FFTextField) will match all text input fields. 
    # if ANY of the specifiers in the list match (not ALL), a given element is considered a match. 
    # but ALL of the attributes specified must match. 
    # regexps can be used to match attributes to regexp; if both are strings, then the match is 
    # case-insensitive. 
    # The only specifier attribute that doesn't match directly to an element attribute is 
    # :types, which will match any of a list of types. 
    def locate_first_specified(specifiers_list, index=nil)
      #STDERR.puts specifiers_list.inspect#+caller.map{|c|"\n\t#{c}"}.join('')
#debugger
#      ids=specifiers_list.map{|s| s[:id] }.compact.uniq
      tags=specifiers_list.map{|s| s[:tagName] }.compact.uniq

# TODO/FIX: getElementById uses document_object, not dom_object, and doesn't check that candidates are below self in the dom heirarchy. 
#      if ids.size==1 && ids.first.is_a?(String) && (!index || index==1) # if index is > 1, then even though it's not really valid, we should search beyond the one result returned by getElementById
#        candidates= if by_id=document_object.getElementById(ids.first)
#          [by_id]
#        else
#          []
#        end
#      els
      if tags.size==1 && tags.first.is_a?(String)
        candidates=dom_object.getElementsByTagName(tags.first).to_array
      else # would be nice to use getElementsByTagName for each tag name, but we can't because then we don't know the ordering for index
        candidates=dom_object.getElementsByTagName('*').to_array
      end
      
      matched=0
      match_candidates(candidates, specifiers_list) do |match|
        matched+=1
        if !index || index==matched
          return match.store_rand_prefix("firewatir_elements")
        end
      end
      return nil
    end
    def match_candidates(candidates, specifiers_list)
      candidates.each do |candidate|
        match=true
        match&&= specifiers_list.any? do |specifier|
          specifier.all? do |(how, what)|
            if how==:types
              what.any? do |type|
                Watir.fuzzy_match(candidate[:type], type)
              end
            else
              LocateAliases[how].any? do |how_alias|
                Watir.fuzzy_match(candidate[how_alias], what)
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
    module_function :match_candidates
    
    def extra
      {:container => self, :browser => self.browser, :jssh_socket => self.jssh_socket}
    end

    public
    #
    # Description:
    #    Used to access a frame element. Usually an <frame> or <iframe> HTML tag.
    #
    # Input:
    #   - how - The attribute used to identify the framet.
    #   - what - The value of that attribute. 
    #   If only one parameter is supplied, "how" is by default taken as name and the 
    #   parameter supplied becomes the value of the name attribute.
    #
    # Typical usage:
    #
    #   ff.frame(:index, 1) 
    #   ff.frame(:name , 'main_frame')
    #   ff.frame('main_frame')        # in this case, just a name is supplied.
    #
    # Output:
    #   Frame object or nil if the specified frame does not exist. 
    #
    def frame(how, what = nil)
      if self.is_a?(Firefox) || self.is_a?(FFFrame)
        candidates=content_window_object.frames.to_array.map{|c|c.frameElement}
      else
        raise NotImplementedError, "frame called on #{self.class} - not yet implemented to deal with locating frames on classes other than Watir::Firefox and Watir::FFFrame"
      end

      specifiers, index=*howwhat_to_specifiers_index(how, what, :default_how => :name)
      match_candidates(candidates, specifiers, index) do |match|
        match=match.store_rand_prefix('firewatir_frames')
        return FFFrame.new(match, extra.merge(:how => how, :what => what))
      end
      return nil
    end
    def frames
      unless self.is_a?(Firefox) || self.is_a?(FFFrame)
        raise NotImplementedError, "frames called on #{self.class} - not yet implemented to deal with locating frames on classes other than Watir::Firefox and Watir::FFFrame"
      end
      
      content_window_object.frames.to_array.map do |c|
        FFFrame.new(c.frameElement.store_rand_prefix('firewatir_frames'), extra)
      end
    end
    
    def howwhat_to_specifier(how, what, default_how=nil)
      spec=if what.nil?
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
#        hash[LocateAliases[how.to_sym]]=what
#        hash
#      end
    end
    def howwhat_to_specifiers_index(how, what, options={})
      default_how=options[:default_how] || options[:klass] && options[:klass].respond_to?(:default_how) && options[:klass].default_how
      hwspecifier=howwhat_to_specifier(how, what, default_how=nil)
      index=hwspecifier.delete :index
      if options[:klass]
        [options[:klass].specifiers.map{|s|s.merge(hwspecifier)}, index]
      else
        [[hwspecifier], index]
      end
    end
    module_function :howwhat_to_specifier, :howwhat_to_specifiers_index
    def element_by_howwhat(klass, how, what)
      if dom_object=locate_first_specified(*howwhat_to_specifiers_index(how, what, :klass => klass))
        klass.new(dom_object, extra.merge(:how => how, :what => what))
      end
    end
    
    #
    # Description:
    #   Used to access a form element. Usually an <form> HTML tag.
    #
    # Input:
    #   - how - The attribute used to identify the form.
    #   - what - The value of that attribute. 
    #   If only one parameter is supplied, "how" is by default taken as name and the 
    #   parameter supplied becomes the value of the name attribute.
    #
    # Typical usage:
    #
    #   ff.form(:index, 1) 
    #   ff.form(:name , 'main_form')
    #   ff.form('main_form')        # in this case, just a name is supplied.
    #
    # Output:
    #   Form object.
    #
    def form(how, what=nil)
      element_by_howwhat(FFForm, how, what)
    end
    
    #
    # Description:
    #   Used to access a table. Usually an <table> HTML tag. 
    #
    # Input:
    #   - how - The attribute used to identify the table.
    #   - what - The value of that attribute. 
    #
    # Typical usage:
    #
    #   ff.table(:index, 1) #index starts from 1.
    #   ff.table(:id, 'main_table')
    #
    # Output:
    #   Table object.
    #
    def table(how, what=nil)
      element_by_howwhat(FFTable, how, what)
    end
    
    #
    # Description:
    #   Used to access a table cell. Usually an <td> HTML tag. 
    #
    # Input:
    #   - how - The attribute used to identify the cell.
    #   - what - The value of that attribute. 
    # 
    # Typical Usage:
    #   ff.cell(:id, 'tb_cell')
    #   ff.cell(:index, 1)
    #
    # Output:
    #    TableCell Object
    #
    def cell(how, what=nil)
      element_by_howwhat(FFTableCell, how, what)
    end
    
    # 
    # Description:
    #   Used to access a table row. Usually an <tr> HTML tag. 
    # 
    # Input:
    #   - how - The attribute used to identify the row.
    #   - what - The value of that attribute. 
    #
    # Typical Usage:
    #   ff.row(:id, 'tb_row')
    #   ff.row(:index, 1)
    #
    # Output: 
    #   TableRow object
    #
    def row(how, what=nil)
      element_by_howwhat(FFTableRow, how, what)
    end
    
    # 
    # Description:
    #   Used to access a button element. Usually an <input type = "button"> HTML tag.
    # 
    # Input:
    #   - how - The attribute used to identify the row.
    #   - what - The value of that attribute. 
    # 
    # Typical Usage:
    #    ff.button(:id,    'b_1')                       # access the button with an ID of b_1
    #    ff.button(:name,  'verify_data')               # access the button with a name of verify_data
    #
    #    if only a single parameter is supplied,  then :value is used as 'how' and parameter supplied is used as what. 
    #
    #    ff.button('Click Me')                          # access the button with a value of Click Me
    #
    # Output:
    #   Button element.
    #
    def button(how, what=nil)
      element_by_howwhat(FFButton, how, what)
    end    
    
    # 
    # Description:
    #   Used for accessing a file field. Usually an <input type = file> HTML tag.  
    #  
    # Input:
    #   - how - Attribute used to identify the file field element
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #    ff.file_field(:id,   'up_1')                     # access the file upload fff.d with an ID of up_1
    #    ff.file_field(:name, 'upload')                   # access the file upload fff.d with a name of upload
    #
    # Output:
    #   FileField object
    #
    def file_field(how, what = nil)
      element_by_howwhat(FFFileField, how, what)
    end    
    
    #
    # Description:
    #   Used for accessing a text field. Usually an <input type = text> HTML tag. or a text area - a  <textarea> tag
    #
    # Input:
    #   - how - Attribute used to identify the text field element.
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #
    #    ff.text_field(:id,   'user_name')                 # access the text field with an ID of user_name
    #    ff.text_field(:name, 'address')                   # access the text field with a name of address
    #
    # Output:
    #   TextField object.
    #
    def text_field(how, what = nil)
      element_by_howwhat(FFTextField, how, what)
    end    
    
    # 
    # Description:
    #   Used to access hidden field element. Usually an <input type = hidden> HTML tag
    #
    # Input:
    #   - how - Attribute used to identify the hidden element.
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #
    #    ff.hidden(:id,   'user_name')                 # access the hidden element with an ID of user_name
    #    ff.hidden(:name, 'address')                   # access the hidden element with a name of address
    #
    # Output:
    #   Hidden object.
    #
    def hidden(how, what=nil)
      element_by_howwhat(FFHidden, how, what)
    end
    
    #
    # Description:
    #   Used to access select list element. Usually an <select> HTML tag.
    #
    # Input:
    #   - how - Attribute used to identify the select element.
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #
    #    ff.select_list(:id,   'user_name')                 # access the select list with an ID of user_name
    #    ff.select_list(:name, 'address')                   # access the select list with a name of address
    #
    # Output:
    #   Select List object.
    #
    def select_list(how, what=nil) 
      element_by_howwhat(FFSelectList, how, what)
    end
    def option(how, what=nil) 
      element_by_howwhat(FFOption, how, what)
    end
    
    #
    # Description:
    #   Used to access checkbox element. Usually an <input type = checkbox> HTML tag.
    #
    # Input:
    #   - how - Attribute used to identify the check box element.
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #
    #   ff.checkbox(:id,   'user_name')                 # access the checkbox element with an ID of user_name
    #   ff.checkbox(:name, 'address')                   # access the checkbox element with a name of address
    #   In many instances, checkboxes on an html page have the same name, but are identified by different values. An example is shown next.
    #
    #   <input type = checkbox name = email_frequency value = 'daily' > Daily Email
    #   <input type = checkbox name = email_frequency value = 'Weekly'> Weekly Email
    #   <input type = checkbox name = email_frequency value = 'monthly'>Monthly Email
    #
    #   FireWatir can access these using the following:
    #
    #   ff.checkbox(:id, 'day_to_send' , 'monday' )         # access the check box with an id of day_to_send and a value of monday
    #   ff.checkbox(:name ,'email_frequency', 'weekly')     # access the check box with a name of email_frequency and a value of 'weekly'
    #
    # Output:
    #   Checkbox object.
    #
    def checkbox(how, what=nil, value=nil) 
      howwhat=howwhat_to_specifier(how, what, FFCheckBox.default_how)
      howwhat[:value]=value unless value.nil?
      element_by_howwhat(FFCheckBox, howwhat, nil)
    end
    
    #
    # Description:
    #   Used to access radio button element. Usually an <input type = radio> HTML tag.
    #
    # Input:
    #   - how - Attribute used to identify the radio button element.
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #
    #   ff.radio(:id,   'user_name')                 # access the radio button element with an ID of user_name
    #   ff.radio(:name, 'address')                   # access the radio button element with a name of address
    #   In many instances, radio buttons on an html page have the same name, but are identified by different values. An example is shown next.
    #
    #   <input type = radio name = email_frequency value = 'daily' > Daily Email
    #   <input type = radio name = email_frequency value = 'Weekly'> Weekly Email
    #   <input type = radio name = email_frequency value = 'monthly'>Monthly Email
    #
    #   FireWatir can access these using the following:
    #
    #   ff.radio(:id, 'day_to_send' , 'monday' )         # access the radio button with an id of day_to_send and a value of monday
    #   ff.radio(:name ,'email_frequency', 'weekly')     # access the radio button with a name of email_frequency and a value of 'weekly'
    #
    # Output:
    #   Radio button object.
    #
    def radio(how, what=nil, value=nil)
      howwhat=howwhat_to_specifier(how, what, FFRadio.default_how)
      howwhat[:value]=value unless value.nil?
      element_by_howwhat(FFRadio, howwhat, nil)
    end
    
    #
    # Description:
    #   Used to access link element. Usually an <a> HTML tag.
    #
    # Input:
    #   - how - Attribute used to identify the link element.
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #
    #    ff.link(:id,   'user_name')                 # access the link element with an ID of user_name
    #    ff.link(:name, 'address')                   # access the link element with a name of address
    #
    # Output:
    #   Link object.
    #
    def link(how, what=nil) 
      element_by_howwhat(FFLink, how, what)
    end
    
    #
    # Description:
    #   Used to access image element. Usually an <img> HTML tag.
    #
    # Input:
    #   - how - Attribute used to identify the image element.
    #   - what - Value of that attribute. 
    #
    # Typical Usage:
    #
    #    ff.image(:id,   'user_name')                 # access the image element with an ID of user_name
    #    ff.image(:name, 'address')                   # access the image element with a name of address
    #
    # Output:
    #   Image object.
    #
    def image(how, what = nil)
      element_by_howwhat(FFImage, how, what)
    end    
    
    
    #
    # Description:
    #   Used to access a definition list element - a <dl> HTML tag.
    #
    # Input:
    #   - how - Attribute used to identify the definition list element.
    #   - what - Value of that attribute.
    #
    # Typical Usage:
    #
    #    ff.dl(:id, 'user_name')                    # access the dl element with an ID of user_name
    #    ff.dl(:title, 'address')                   # access the dl element with a title of address
    #
    # Returns:
    #   Dl object.
    #
    def dl(how, what = nil)
      element_by_howwhat(FFDl, how, what)
    end

    #
    # Description:
    #   Used to access a definition term element - a <dt> HTML tag.
    #
    # Input:
    #   - how  - Attribute used to identify the image element.
    #   - what - Value of that attribute.
    #
    # Typical Usage:
    #
    #    ff.dt(:id, 'user_name')                    # access the dt element with an ID of user_name
    #    ff.dt(:title, 'address')                   # access the dt element with a title of address
    #
    # Returns:
    #   Dt object.
    #
    def dt(how, what = nil)
      element_by_howwhat(FFDt, how, what)
    end

    #
    # Description:
    #   Used to access a definition description element - a <dd> HTML tag.
    #
    # Input:
    #   - how  - Attribute used to identify the image element.
    #   - what - Value of that attribute.
    #
    # Typical Usage:
    #
    #    ff.dd(:id, 'user_name')                    # access the dd element with an ID of user_name
    #    ff.dd(:title, 'address')                   # access the dd element with a title of address
    #
    # Returns:
    #   Dd object.
    #
    def dd(how, what = nil)
      element_by_howwhat(FFDd, how, what)
    end

    # Description:
    #	Searching for Page Elements. Not for external consumption.
    #        
    # def ole_inner_elements
    # return document.body.all 
    # end
    # private :ole_inner_elements
    
    
    # 
    # Description:
    #   This method shows the available objects on the current page.
    #   This is usually only used for debugging or writing new test scripts.
    #   This is a nice feature to help find out what HTML objects are on a page
    #   when developing a test case using FireWatir.
    #
    # Typical Usage:
    #   ff.show_all_objects
    #
    # Output:
    #   Prints all the available elements on the page.
    #
    def show_all_objects
      #puts "-----------Objects in the current context-------------" 
      locate if respond_to?(:locate)
      elements = FFDocument.new(self).all
      #puts elements.length
      elements.each  do |n|
        break
        puts n.tagName
        puts n.to_s
        puts "------------------------------------------" 
      end
      #puts "Total number of objects in the current context :	#{elements.length}"
      return elements
      # Test the index access. 
      # puts doc[35].to_s
    end
    
  end
end # module 

