# feature tests for Radio Buttons
# revision: $Revision$

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_Radios_XPath < Test::Unit::TestCase
  include Watir::Exception
  
  def setup
    goto_page "radioButtons1.html"
  end
  
  def test_Radio_Exists
    assert(browser.radio!(:xpath, "//input[@name='box1']/").exists?)   
    assert(browser.radio!(:xpath, "//input[@id='box5']/").exists?)   
    
    assert_nil(browser.radio(:xpath, "//input[@name='missingname']/"))   
    assert_nil(browser.radio(:xpath, "//input[@id='missingid']/"))   
  end
  
  def test_Radio_Enabled
    assert_raises(UnknownObjectException) {   browser.radio!(:xpath, "//input[@name='noName']/").enabled?  }  
    assert_raises(UnknownObjectException) {   browser.radio!(:xpath, "//input[@id='noName']/").enabled?  }  
    assert_raises(UnknownObjectException) {   browser.radio!(:xpath, "//input[@name='box4' and @value='6']/").enabled?  }  
    
    assert_false(browser.radio!(:xpath, "//input[@name='box2']/").enabled?)   
    assert(browser.radio!(:xpath, "//input[@id='box5']/").enabled?)   
    assert(browser.radio!(:xpath, "//input[@name='box1']/").enabled?)   
  end
  
  def test_little
    assert_false(browser.button!(:xpath,"//input[@name='foo']/").enabled?)
  end
  
  def test_onClick
    assert_false(browser.button!(:xpath,"//input[@name='foo']/").enabled?)          
    browser.radio!(:xpath, "//input[@name='box5' and @value='1']/").set
    assert(browser.button!(:xpath,"//input[@name='foo']/").enabled?)        
    
    browser.radio!(:xpath, "//input[@name='box5' and @value='2']/").set
    assert_false(browser.button!(:xpath,"//input[@name='foo']/").enabled?)
  end
  
  def test_Radio_isSet
    assert_raises(UnknownObjectException) {   browser.radio!(:xpath, "//input[@name='noName']/").checked?  }  
    
    #puts "radio 1 is set : #{ browser.radio!(:xpath, "//input[@name='box1']/").checked? } "
    assert_false(browser.radio!(:xpath, "//input[@name='box1']/").checked?)   
    
    assert(browser.radio!(:xpath, "//input[@name='box3']/").checked?)   
    assert_false(browser.radio!(:xpath, "//input[@name='box2']/").checked?)   
    
    assert( browser.radio!(:xpath, "//input[@name='box4' and @value='1']/").checked?)   
    assert_false(browser.radio!(:xpath, "//input[@name='box4' and @value='2']/").checked?)   
  end
  
  def test_radio_clear
    assert_raises(UnknownObjectException) {   browser.radio!(:xpath, "//input[@name='noName']/").clear  }  
    
    browser.radio!(:xpath, "//input[@name='box1']/").clear
    assert_false(browser.radio!(:xpath, "//input[@name='box1']/").checked?)   
    
    assert_raises(ObjectDisabledException, "ObjectDisabledException was supposed to be thrown" ) {   browser.radio!(:xpath, "//input[@name='box2']/").clear  } 
    assert_false(browser.radio!(:xpath, "//input[@name='box2']/").checked?)   
    
    browser.radio!(:xpath, "//input[@name='box3']/").clear
    assert_false(browser.radio!(:xpath, "//input[@name='box3']/").checked?)   
    
    browser.radio!(:xpath, "//input[@name='box4' and @value='1']/").clear
    assert_false(browser.radio!(:xpath, "//input[@name='box4' and @value='1']/").checked?)   
  end
  
  def test_radio_checked?
    assert_raises(UnknownObjectException) {   browser.radio!(:xpath, "//input[@name='noName']/").checked?  }  
    
    assert_equal( false , browser.radio!(:xpath, "//input[@name='box1']/").checked? )   
    assert_equal( true , browser.radio!(:xpath, "//input[@name='box3']/").checked?)   
    
    # radioes that have the same name but different values
    assert_equal( false , browser.radio!(:xpath, "//input[@name='box4' and @value='2']/").checked? )   
    assert_equal( true , browser.radio!(:xpath, "//input[@name='box4' and @value='1']/").checked?)   
  end
  
  def test_radio_set
    assert_raises(UnknownObjectException) {   browser.radio!(:xpath, "//input[@name='noName']/").set  }  
    browser.radio!(:xpath, "//input[@name='box1']/").set
    assert(browser.radio!(:xpath, "//input[@name='box1']/").checked?)   
    
    assert_raises(ObjectDisabledException, "ObjectDisabledException was supposed to be thrown" ) {   browser.radio!(:xpath, "//input[@name='box2']/").set  }  
    
    browser.radio!(:xpath, "//input[@name='box3']/").set
    assert(browser.radio!(:xpath, "//input[@name='box3']/").checked?)   
    
    # radioes that have the same name but different values
    browser.radio!(:xpath, "//input[@name='box4' and @value='3']/").set
    assert(browser.radio!(:xpath, "//input[@name='box4' and @value='3']/").checked?)   
  end
  
end

