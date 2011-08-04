# revision: $Revision$

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_PopUps < Test::Unit::TestCase
  tags :must_be_visible, :creates_windows, :unreliable

  def setup
    browser.goto("file://#{$myDir}/html/popups1.html")
  end
  
  def test_simple
    browser.button!("Alert").click_no_wait
    browser.modal_dialog.click_button('OK')
  end
  
  def test_confirm
    browser.button!("Confirm").click_no_wait
    browser.modal_dialog.click_button('OK')
    assert(browser.text_field!(:name , "confirmtext").verify_contains("OK"))
    
    browser.button!("Confirm").click_no_wait
    browser.modal_dialog.click_button('Cancel')
    assert(browser.text_field!(:name , "confirmtext").verify_contains("Cancel"))
  end
  
  def test_Prompt
    browser.button!("Prompt").click_no_wait
    browser.modal_dialog.click_button('OK')
  end
end

