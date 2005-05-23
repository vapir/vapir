# feature tests for Radio Buttons
# revision: $Revision$

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') if $0 == __FILE__
require 'unittests/setup'

class TC_Radios < Test::Unit::TestCase
    include Watir

    def setup()
        $ie.goto($htmlRoot + "radioButtons1.html")
    end
   

    def test_default_attribute_for_all
        $ie.set_default_attribute( :id)
        assert_equal('id' , $ie.get_default_attribute)
        assert_raises(UnknownObjectException ) { $ie.radio('missing_id').id }
        assert_equal("on"  , $ie.radio('box5').value  ) 
        $ie.set_default_attribute( nil )
    end

    def test_default_attribute_for_radio

        $ie.set_default_attribute_for_element( :radio, :id)
        assert_equal('id' , $ie.get_default_attribute_for( :radio) )
        assert_equal("on"  , $ie.radio('box5').value  ) 

        $ie.set_default_attribute_for_element(:radio, :name)
        assert_equal('name' , $ie.get_default_attribute_for( :radio) )
        assert_raises(UnknownObjectException ) { $ie.radio('missing_name').value }
        assert_equal(false  , $ie.radio('box1').checked?) 

     
        # make sure that setting the default for a radio directly, overrides the all setting
        # we are still using the name attribute, set a few lines up
        $ie.set_default_attribute( :id)
        assert_equal(false  , $ie.radio('box1').checked?)  #box1 is a name 


        # delete the text_field type
        $ie.set_default_attribute_for_element( :radio, nil)

        # make sure the global attribute (id)  is used
        assert_equal(false  , $ie.radio('box5').checked?)   # box5 is an id

    end


    def test_Radio_Exists
       assert($ie.radio(:name, "box1").exists?)   
       assert($ie.radio(:id, "box5").exists?)   

       assert_false($ie.radio(:name, "missingname").exists?)   
       assert_false($ie.radio(:id, "missingid").exists?)   
    end

    def test_Radio_Enabled
       assert_raises(UnknownObjectException , "UnknownObjectException was supposed to be thrown" ) {   $ie.radio(:name, "noName").enabled?  }  
       assert_raises(UnknownObjectException , "UnknownObjectException was supposed to be thrown" ) {   $ie.radio(:id, "noName").enabled?  }  
       assert_raises(UnknownObjectException , "UnknownObjectException was supposed to be thrown" ) {   $ie.radio(:name, "box4" , 6).enabled?  }  

       assert_false($ie.radio(:name, "box2").enabled?)   
       assert($ie.radio(:id, "box5").enabled?)   
       assert($ie.radio(:name, "box1").enabled?)   
    end

   def test_little
       assert_false($ie.button(:value , "foo").enabled?)
   end

   def test_onClick
       assert_false($ie.button(:value , "foo").enabled?)
       $ie.radio(:name, "box5" , 1).set
       assert($ie.button(:value , "foo").enabled?)

       $ie.radio(:name, "box5", 2).set
       assert_false($ie.button(:value , "foo").enabled?)
    end

    def test_Radio_isSet
       assert_raises(UnknownObjectException , "UnknownObjectException was supposed to be thrown" ) {   $ie.radio(:name, "noName").isSet?  }  

       puts "radio 1 is set : #{ $ie.radio(:name, 'box1').isSet? } "
       assert_false($ie.radio(:name, "box1").isSet?)   

       assert( $ie.radio(:name, "box3").isSet?)   
       assert_false($ie.radio(:name, "box2").isSet?)   

       assert( $ie.radio(:name, "box4" , 1 ).isSet?)   
       assert_false($ie.radio(:name, "box4" , 2 ).isSet?)   
    end

    def test_radio_clear
       assert_raises(UnknownObjectException , "UnknownObjectException was supposed to be thrown" ) {   $ie.radio(:name, "noName").clear  }  

       $ie.radio(:name, "box1").clear
       assert_false($ie.radio(:name, "box1").isSet?)   

       assert_raises(ObjectDisabledException, "ObjectDisabledException was supposed to be thrown" ) {   $ie.radio(:name, "box2").clear  } 
       assert_false($ie.radio(:name, "box2").isSet?)   

       $ie.radio(:name, "box3").clear
       assert_false($ie.radio(:name, "box3").isSet?)   

       $ie.radio(:name, "box4" , 1).clear
       assert_false($ie.radio(:name, "box4" , 1).isSet?)   
    end

    def test_radio_getState
       assert_raises(UnknownObjectException , "UnknownObjectException was supposed to be thrown" ) {   $ie.radio(:name, "noName").getState  }  

       assert_equal( false , $ie.radio(:name, "box1").getState )   
       assert_equal( true , $ie.radio(:name, "box3").getState)   

       # radioes that have the same name but different values
       assert_equal( false , $ie.radio(:name, "box4" , 2).getState )   
       assert_equal( true , $ie.radio(:name, "box4" , 1).getState)   
    end

    def test_radio_set
       assert_raises(UnknownObjectException , "UnknownObjectException was supposed to be thrown" ) {   $ie.radio(:name, "noName").set  }  
       $ie.radio(:name, "box1").set
       assert($ie.radio(:name, "box1").isSet?)   

       assert_raises(ObjectDisabledException, "ObjectDisabledException was supposed to be thrown" ) {   $ie.radio(:name, "box2").set  }  

       $ie.radio(:name, "box3").set
       assert($ie.radio(:name, "box3").isSet?)   

       # radioes that have the same name but different values
       $ie.radio(:name, "box4" , 3).set
       assert($ie.radio(:name, "box4" , 3).isSet?)   
    end

    def test_radio_properties

        assert_raises(UnknownObjectException  , "UnknownObjectException  was supposed to be thrown" ) {   $ie.radio(:index, 199).value}  
        assert_raises(UnknownObjectException  , "UnknownObjectException  was supposed to be thrown" ) {   $ie.radio(:index, 199).name }  
        assert_raises(UnknownObjectException  , "UnknownObjectException  was supposed to be thrown" ) {   $ie.radio(:index, 199).id }  
        assert_raises(UnknownObjectException  , "UnknownObjectException  was supposed to be thrown" ) {   $ie.radio(:index, 199).disabled }  
        assert_raises(UnknownObjectException  , "UnknownObjectException  was supposed to be thrown" ) {   $ie.radio(:index, 199).type }  

        assert_equal("on"   ,    $ie.radio(:index, 1).value)  
        assert_equal("box1" ,    $ie.radio(:index, 1).name )  
        assert_equal(""     ,    $ie.radio(:index, 1).id )  
        assert_equal("radio",    $ie.radio(:index, 1).type )  

        assert_equal( false, $ie.radio(:index, 1).disabled )
        assert_equal( true,  $ie.radio(:index, 3).disabled )

        assert_equal("box5"  ,    $ie.radio(:index, 2).id )  
        assert_equal(""      ,    $ie.radio(:index, 2).name )  

        assert_equal("box4-value5", $ie.radio(:name , "box4" , 5 ).title  )
        assert_equal("", $ie.radio(:name , "box4" , 4 ).title  )


    end

    def test_radio_iterators

        assert_equal(11, $ie.radios.length)
        assert_equal("box5" , $ie.radios[2].id )
        assert_equal(true ,  $ie.radios[3].disabled )
        assert_equal(false ,  $ie.radios[1].disabled )

        index = 1
        $ie.radios.each do |r|
            assert_equal( $ie.radio(:index, index).name , r.name )
            assert_equal( $ie.radio(:index, index).id , r.id )
            assert_equal( $ie.radio(:index, index).value, r.value)
            assert_equal( $ie.radio(:index, index).disabled , r.disabled )
            index+=1
        end
        assert_equal(index -1, $ie.radios.length)
    end


end
