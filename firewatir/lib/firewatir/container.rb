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
    
    private
    def extra_for_contained
      {:container => self, :browser => self.browser, :jssh_socket => self.jssh_socket}
    end

    public
    # Returns array of element objects that match the given XPath query.
    #   Refer: https://developer.mozilla.org/en/DOM/document.evaluate
    def element_objects_by_xpath(xpath)
      elements=[]
      result=document_object.evaluate(xpath, containing_object, nil, jssh_socket.Components.interfaces.nsIDOMXPathResult.ORDERED_NODE_ITERATOR_TYPE, nil)
      while element=result.iterateNext
        elements << element.store_rand_object_key(@browser_jssh_objects)
      end
      elements
    end

    # Returns the first element object that matches the given XPath query.
    #   Refer: http://developer.mozilla.org/en/docs/DOM:document.evaluate
    def element_object_by_xpath(xpath)
      document_object.evaluate(xpath, containing_object, nil, jssh_socket.Components.interfaces.nsIDOMXPathResult.FIRST_ORDERED_NODE_TYPE, nil).singleNodeValue
    end

    # Returns the first element that matches the given xpath expression or query.
    def element_by_xpath(xpath)
      base_element_class.factory(element_object_by_xpath(xpath))
    end

    # Returns the array of elements that match the given xpath query.
    def elements_by_xpath(xpath)
      # TODO/FIX: shouldn't this return an ElementCollection? tests seem to expect it not to, addressing it with 0-based indexing, but that seems insconsistent with everything else. 
      element_objects_by_xpath(xpath).map do |element_object|
        base_element_class.factory(element_object)
      end
    end

=begin    
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
      element_by_howwhat(FFFrame, how, what)
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
    #   ff.table_cell(:id, 'tb_cell')
    #   ff.table_cell(:index, 1)
    #
    # Output:
    #    TableCell Object
    #
    def table_cell(how, what=nil)
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
    def table_row(how, what=nil)
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
=end
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
#    def checkbox(how, what=nil, value=nil) 
#      element_by_howwhat(FFCheckBox, how, what, {:other_attributes => value ? {:value => value} : nil})
#    end
    
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
#    def radio(how, what=nil, value=nil)
#      element_by_howwhat(FFRadio, how, what, {:other_attributes => value ? {:value => value} : nil})
#    end
    
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
#    def link(how, what=nil) 
#      element_by_howwhat(FFLink, how, what)
#    end
    
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
 #   def image(how, what = nil)
 #     element_by_howwhat(FFImage, how, what)
 #   end    
    
    
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
#    def dl(how, what = nil)
#      element_by_howwhat(FFDl, how, what)
#    end

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
#    def dt(how, what = nil)
#      element_by_howwhat(FFDt, how, what)
#    end

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
#    def dd(how, what = nil)
#      element_by_howwhat(FFDd, how, what)
#    end

    # Description:
    #	Searching for Page Elements. Not for external consumption.
    #        
    # def ole_inner_elements
    # return document.body.all 
    # end
    # private :ole_inner_elements
  end
end # module 
