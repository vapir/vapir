$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_Dl < Test::Unit::TestCase
  include Watir::Exception
  location __FILE__

  def setup
    @html_dir = "#{File.dirname(__FILE__)}/html"
    uses_page "definition_lists.html"
  end
  
  def test_exists
    assert browser.dl(:id, "experience-list").exists?, "Could not find <dl> by :id"
    assert browser.dl(:class, "list").exists?, "Could not find <dl> by :class"
    assert browser.dl(:xpath, "//dl[@id='experience-list']").exists?, "Could not find <dl> by :xpath"
    assert browser.dl(:index, 1).exists?, "Could not find <dl> by :index"
  end
  
  def test_does_not_exist
    assert !browser.dl?(:id, 'no_such_id'), "Found non-existing <dl>"
  end
  
  def test_attribute_class_name
    assert_equal "list", browser.dl!(:id, "experience-list").class_name
    assert_equal "", browser.dl!(:id, 'noop').class_name
    assert_raises(UnknownObjectException) do
      browser.dl!(:id, 'no_such_id').class_name
    end
  end
  
  def test_attribute_id
    assert_equal "experience-list", browser.dl!(:class, 'list').id
    assert_equal "", browser.dl!(:class, 'personalia').id
    assert_raises(UnknownObjectException) do
      browser.dl!(:id, 'no_such_id').id
    end
  end
  
  def test_attribute_title
    assert_equal "experience", browser.dl!(:class, 'list').title
    assert_equal "", browser.dl!(:id, 'noop').title
    assert_raises(UnknownObjectException) do
      browser.dl!(:id, 'no_such_id').title
    end
  end
  
  def test_attribute_text
    assert_match /11 years/, browser.dl!(:id, "experience-list").text
    assert_match /\A\s*\z/, browser.dl!(:id, 'noop').text # check this contains only whitespace
    assert_raises(UnknownObjectException) do
      browser.dl!(:id, 'no_such_id').text
    end
  end
  
  def test_dls_iterator
    assert_equal(3, browser.dls.length)
    assert_equal("experience-list", browser.dls[1].id)
    
    browser.dls.each_with_index do |dl, idx|
      assert_equal(browser.dl!(:index,idx).text, dl.text)
      assert_equal(browser.dl!(:index,idx).id, dl.id)
      assert_equal(browser.dl!(:index,idx).class_name , dl.class_name)
      assert_equal(browser.dl!(:index,idx).title, dl.title)
    end
  end
    
end