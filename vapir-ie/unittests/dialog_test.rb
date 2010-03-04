# Feature tests for Dialog class
# revision: $Revision$

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_Dialog_Test < Test::Unit::TestCase
  tags :must_be_visible
  include Vapir
  
  def setup
    goto_page 'JavascriptClick.html'
  end
  def teardown
  end
  
  def test_alert_without_bonus_script
    browser.button!(:id, 'btnAlert').click_no_wait
    browser.modal_dialog.click_button("OK")
    assert_match(/Alert button!/, browser.text_field!(:id, "testResult").value)
  end
  
  def test_button_name_not_found
    browser.button!(:id, 'btnAlert').click_no_wait
    assert_raises(WinWindow::NotExistsError) { browser.modal_dialog.click_button("Yes") }
    browser.modal_dialog.click_button("OK")
  end
  
  def test_exists
    assert_nil( browser.modal_dialog)
    browser.button!(:id, 'btnAlert').click_no_wait
    assert browser.modal_dialog.exists?
    browser.modal_dialog.click_button('OK')
  end
  
  def test_confirm_ok
    browser.button!(:value, 'confirm').click_no_wait
    assert browser.modal_dialog.exists?
    browser.modal_dialog.click_button('OK')
    assert_equal "You pressed the Confirm and OK button!", browser.text_field!(:id, 'testResult').value
  end
  
  def test_confirm_cancel
    browser.button!(:value, 'confirm').click_no_wait
    assert browser.modal_dialog.exists?
    browser.modal_dialog.click_button('Cancel')
    assert_equal "You pressed the Confirm and Cancel button!", browser.text_field!(:id, 'testResult').value
  end
  
  def test_dialog_close
    browser.button!(:id, 'btnAlert').click_no_wait
    browser.modal_dialog.close
    assert_nil browser.modal_dialog
  end
  
end