$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_SelectLists < Test::Unit::TestCase
  location __FILE__

  def setup
    uses_page "select_lists.html"
  end 

  def test_select_by_numeric
    # make sure we don't find an option if passed a number
    #  as matching goes by equality and the number 2011 is not the same as the string '2011'.
    browser.select_list!(:id, 'year').select('2011')
    assert_raises(NoValueFoundException) { browser.select_list!(:id, "year").select(2011) }  
    assert_equal(['2011'], browser.select_list!(:id, 'year').selected_option_texts)
  end

end


