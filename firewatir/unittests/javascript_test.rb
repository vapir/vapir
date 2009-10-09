$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_JavaScript_Test < Test::Unit::TestCase
    
#    include FireWatir::Dialog
    
    def setup
        goto_page 'JavascriptClick.html'
    end
    
    tag_method :test_alert, :fails_on_ie
    def test_alert
        browser.button!(:id, "btnAlert").click_no_wait
        assert_equal("Press OK", browser.get_popup_text)
        browser.click_modal_button('OK')
        assert_equal(browser.text_field!(:id, "testResult").value , "You pressed the Alert button!")
        
        #browser.startClicker("ok")
        browser.button!(:id, "btnAlert").click_no_wait
        assert_equal("Press OK", browser.get_popup_text)
        browser.click_modal_button('OK')
        assert_equal(browser.text_field!(:id, "testResult").value , "You pressed the Alert button!")
    end
    
    tag_method :test_confirm_ok, :fails_on_ie
    def test_confirm_ok
        browser.button!(:id, "btnConfirm").click_no_wait
        assert_equal("Press a button", browser.get_popup_text)
        browser.click_modal_button('OK')
        assert_equal(browser.text_field!(:id, "testResult").value , "You pressed the Confirm and OK button!")

        browser.button!(:id, "btnConfirm").click_no_wait
        assert_equal("Press a button", browser.get_popup_text)
        browser.click_modal_button('OK')
        assert_equal(browser.text_field!(:id, "testResult").value , "You pressed the Confirm and OK button!")
    end
    
    tag_method :test_confirm_cancel, :fails_on_ie
    def test_confirm_cancel
        browser.button!(:id, "btnConfirm").click_no_wait
        assert_equal("Press a button", browser.get_popup_text)
        browser.click_modal_button('Cancel')
        assert_equal(browser.text_field!(:id, "testResult").value, "You pressed the Confirm and Cancel button!")

        browser.button!(:id, "btnConfirm").click_no_wait
        assert_equal("Press a button", browser.get_popup_text)
        browser.click_modal_button('Cancel')
        assert_equal(browser.text_field!(:id, "testResult").value, "You pressed the Confirm and Cancel button!")
    end

    tag_method :test_ok_selectbox, :fails_on_ie
    def test_ok_selectbox
        goto_page("selectboxes1.html")
        browser.select_list!(:id , "selectbox_5").select_value(/2/)
        assert_equal("Press OK", browser.get_popup_text)
        browser.click_modal_button('OK')
        assert_equal(browser.text_field!(:id, "txtAlert").value , "You pressed OK button")
    end
end
