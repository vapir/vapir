# feature tests for AutoIt wrapper
# revision: $Revision$

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..') unless $SETUP_LOADED
require 'unittests/setup'
require 'vapir-ie/process'

$mydir = File.expand_path(File.dirname(__FILE__)).gsub('/', '\\')

class TC_JavaScript_Test < Test::Unit::TestCase
  def ruby_process_count
    Watir::Process::count('rubyw.exe')
  end
  
  def teardown
    assert_equal @background_ruby_process_count, ruby_process_count
  end
  
  def setup
    @background_ruby_process_count = ruby_process_count
    browser.goto($htmlRoot  + 'JavascriptClick.html')
  end
  
  def check_dialog(button_text, expected_result, &block)
    block.call
    browser.modal_dialog!.click_button(button_text)
    testResult = browser.text_field!(:id, "testResult").value
    assert_match( expected_result, testResult )  
  end
  
  def test_alert_button
    check_dialog('OK', /Alert button!/) do
      browser.button!(:id, 'btnAlert').click_no_wait
    end
    
  end
  def test_confirm_button_ok
    check_dialog('OK', /Confirm and OK button!/) do 
      browser.button!(:id, 'btnConfirm').click_no_wait
    end
  end
  def test_confirm_button_Cancel
    check_dialog('Cancel', /Confirm and Cancel button!/) do
      browser.button!(:id, 'btnConfirm').click_no_wait
    end
  end
  
end