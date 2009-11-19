# feature tests for Tables
# revision: $Revision: 1.0 $

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_Tables < Test::Unit::TestCase
  
  
  def setup
    goto_page("table1.html")
  end
  
  def test_Table_Exists
    assert(!browser.table(:id, 'missingTable').exists?)
    assert(!browser.table(:index, 33).exists?)
    
    assert(browser.table(:id, 't1').exists?)
    assert(browser.table(:id, /t/).exists?)
    assert(!browser.table(:id, /missing_table/).exists?)
    
    assert(browser.table(:index, 1).exists?)
    assert(browser.table(:index, 2).exists?)
  end
  
  tag_method :test_rows, :fails_on_ie
  def test_rows
    assert_raises(UnknownObjectException){ browser.table(:id, 'missingTable').row_count }
    assert_raises(UnknownObjectException){ browser.table(:index, 66).row_count }
    assert_raises(UnknownObjectException){ browser.table(:bad_attribute, 99).row_count }
    
    assert_equal(2, browser.table!(:index, 1).row_count)
    assert_equal(2, browser.table!(:index, 1).rows.length)
    
    assert_equal(5, browser.table!(:id, 't1').row_count)  # 4 rows and a header 
    assert_equal(5, browser.table!(:index, 2).row_count)  # same table as above, just accessed by index 
    assert_equal(5, browser.table!(:id, 't1').rows.length)   
    
    # test the each iterator on rows - ie, go through each cell
    row = browser.table!(:index, 2)[2]
    count = 1
    row.each do |cell|
      if count == 1
        assert_equal('Row 1 Col1', cell.text.strip)
      elsif count==2
        assert_equal('Row 1 Col2', cell.text.strip)
      end
      count += 1
    end
    assert_equal(2, count -1)
    assert_equal(2, browser.table!(:index, 2)[2].column_count)        
  end
  
  def test_dynamic_tables
    t = browser.table!(:id, 't1')
    assert_equal(5, t.row_count)
    
    browser.button!(:value, 'add row').click
    assert_equal(6, t.row_count)
  end
  
  def test_columns
    assert_raises(UnknownObjectException){ browser.table(:id, 'missingTable').column_count }
    assert_raises(UnknownObjectException){ browser.table(:index, 77).column_count }
    assert_equal(2, browser.table!(:index, 1).column_count)
    assert_equal(2, browser.table!(:id, 't1').column_count)   # row one has 1 cell with a colspan of 2
  end
  
  def test_to_a
    table1Expected = [ ["Row 1 Col1" , "Row 1 Col2"] ,[ "Row 2 Col1" , "Row 2 Col2"] ]
    assert_equal(table1Expected, browser.table!(:index , 1).to_a )
  end
  
  def test_links_and_images_in_table
    table = browser.table!(:id, 'pic_table')
    image = table[1][2].image!(:index,1)
    assert_equal(106, image.width)
    
    link = table[2][2].link!(:index,1)
    assert_equal("Google", link.text)
  end
  
  def test_cell_directly
    assert( browser.table_cell(:id, 'cell1').exists? )
    assert(! browser.table_cell(:id, 'no_exist').exists?)
    assert_equal( "Row 1 Col1",  browser.table_cell!(:id, 'cell1').text.strip )
    
    # not really cell directly, but just to show another way of geting the cell
    assert_equal( "Row 1 Col1",  browser.table!(:index,1)[1][1].text.strip )
    assert_equal(2, browser.table_cell!(:id, "cell_with_colspan").colspan)
  end
  
  def test_row_directly
    assert( browser.table_row(:id, 'row1').exists? )
    assert(! browser.table_row(:id, 'no_exist').exists?)
    
    assert_equal('Row 2 Col1' ,  browser.table_row!(:id, 'row1')[1].text.strip )
  end
  
  def test_row_iterator
    t = browser.table!(:index, 1)
    count = 1 
    t.each do |row|
      if count == 1
        assert("Row 1 Col1", row[1].text)
        assert("Row 1 Col2", row[2].text)
      elsif count == 2
        assert("Row 2 Col1", row[1].text)
        assert("Row 2 Col2", row[2].text)
      end
      count += 1
    end
  end
  
  def test_row_collection
    t = browser.table!(:index,1)
    count = 1
    t.rows.each do |row|
      if count == 1
        assert("Row 1 Col1", row[1].text)
        assert("Row 1 Col2", row[2].text)
      elsif count == 2
        assert("Row 2 Col1", row[1].text)
        assert("Row 2 Col2", row[2].text)
      end
      count += 1
    end
  end 
  
  def test_table_body
    assert_equal( 1, browser.table!(:index,1).tbodies.length )
    assert_equal( 3, browser.table!(:id, 'body_test' ).tbodies.length )
    
    tbodies=browser.table!(:id, 'body_test').tbodies
    assert_equal("This text is in the FRST TBODY.", tbodies[1][1][1].text.strip)
    assert_equal("This text is in the SECOND TBODY.", tbodies[2][1][1].text.strip)
    assert_equal("This text is in the THIRD TBODY.", tbodies[3][1][1].text.strip)
    assert_equal( "This text is in the THIRD TBODY.",browser.table!(:id, 'body_test' ).tbody(:index,3)[1][1].text.strip ) 
    row_texts=[]
    browser.table!(:id, 'body_test').tbody(:index, 2).each do |row|
      row_texts << row.text.strip
    end
    assert_equal(['This text is in the SECOND TBODY.', 'This text is also in the SECOND TBODY.'], row_texts)
  end
  
  def test_table_container
    assert_nothing_raised { browser.table!(:id, 't1').outer_html }
  end
end    

class TC_Tables_Simple < Test::Unit::TestCase
  
  
  def setup
    goto_page("simple_table.html")
  end
  
  def test_simple_table_access
    table = browser.table!(:index,1)
    
    assert_equal("Row 3 Col1",table[3][1].text.strip)
    assert_equal("Row 1 Col1",table[1][1].text.strip)
    assert_equal("Row 3 Col2",table[3][2].text.strip)
    assert_equal(2,table.column_count)
  end
end

class TC_Tables_Buttons < Test::Unit::TestCase
  
  
  def setup
    goto_page("simple_table_buttons.html")
  end
  
  def test_simple_table_buttons
    table = browser.table!(:index,1)
    
    table[1][1].button!(:index,1).click
    assert(browser.text_field!(:name,"confirmtext").verify_contains(/CLICK1/i))
    table[2][1].button!(:index,1).click
    assert(browser.text_field!(:name,"confirmtext").verify_contains(/CLICK2/i))
    
    table[1][1].button!(:id,'b1').click
    assert(browser.text_field!(:name,"confirmtext").verify_contains(/CLICK1/i))
    
    assert_raises(UnknownObjectException) { table[1][1].button(:id,'b_missing').click }
    
    table[3][1].button!(:index,2).click
    assert(browser.text_field!(:name,"confirmtext").verify_contains(/TOO/i))
    
    table[3][1].button!(:value ,"Click too").click
    assert(browser.text_field!(:name,"confirmtext").verify_contains(/TOO/i))
    
    browser.table!(:index,1)[4][1].text_field!(:index,1).set("123")
    assert(browser.text_field!(:index,2).verify_contains("123"))
    
    # check when a cell contains 2 objects
    
    # if there were 2 different html objects in the same cell, some weird things happened ( button caption could change for example)
    assert_equal( 'Click ->' , browser.table!(:index,1)[5][1].text_field!(:index,1).value )
    browser.table!(:index,1)[5][1].text_field!(:index,1).click
    assert_equal( 'Click ->' , browser.table!(:index,1)[5][1].text_field!(:index,1).value )
    
    browser.table!(:index,1)[5][1].button!(:index,1).click
    assert_equal( '' , browser.table!(:index,1)[5][1].text_field!(:index,1).value )
  end
  
  def test_simple_table_gif
    table = browser.table!(:index,2)
    
    assert_match( /1\.gif/   , table[1][1].image!( :index,1).src  )
    assert_match( /2\.gif/   , table[1][2].image!( :index ,1).src )
    assert_match( /3\.gif/   , table[1][3].image!( :index ,1).src    )
    
    assert_match( /1\.gif/   , table[3][1].image!( :index ,1).src  )
    assert_match( /2\.gif/   , table[3][2].image!( :index ,1).src )
    assert_match( /3\.gif/   , table[3][3].image!( :index ,1).src  )
    
    table = browser.table!(:index,3)
    assert_match( /1\.gif/   , table[1][1].image!( :index ,1).src  )
    assert_match( /2\.gif/   , table[1][1].image!( :index ,2).src )
    assert_match( /3\.gif/   , table[1][1].image!( :index ,3).src )
   
    assert_match( /1\.gif/  , table[3][1].image!( :index ,1).src  )
    assert_match( /2\.gif/  , table[3][1].image!( :index ,2).src    )
    assert_match( /3\.gif/  , table[3][1].image!( :index ,3).src  )
  end
  
  def test_table_with_hidden_or_visible_rows
    t = browser.table!(:id , 'show_hide')
    
    # expand the table
    t.each do |r|
      r[1].image!(:src, /plus/).click if r[1].image(:src, /plus/).exists?
    end
    
    # shrink rows 1,2,3
    count=1
    t.each do |r|
      r[1].image!(:src, /minus/).click if r[1].image(:src, /minus/) and (1..3) === count 
      count=2
    end
  end
  
#  def test_table_from_element
#    button = browser.button!(:id, "b1")
#    table = Table.create_from_element(browser, button)
    
#    table[2][1].button!(:index, 1).click
#    assert(browser.textField(:name, "confirmtext").verify_contains(/CLICK2/i))
#  end
end

class TC_Table_Columns < Test::Unit::TestCase
  
  def setup
    goto_page("simple_table_columns.html")
  end
  
  def test_get_columnvalues_single_column
    assert_equal(["R1C1", "R2C1", "R3C1"], browser.table!(:index, 1).column_texts_at(1))
  end

  def test_colspan
    assert_equal(2, browser.table!(:index, 3)[2][1].colspan)
    assert_equal(1, browser.table!(:index, 3)[1][1].colspan)
    assert_equal(3, browser.table!(:index, 3)[4][1].colspan)
  end

  def test_get_columnvalues_multiple_column
    assert_equal(["R1C1", "R2C1", "R3C1"], browser.table!(:index, 2).column_texts_at(1))
    assert_equal(["R1C3", "R2C3", "R3C3"], browser.table!(:index, 2).column_texts_at(3))
  end

  def test_get_columnvalues_with_colspan
    assert_equal(["R1C1", "R2C1", "R3C1", "R4C1", "R5C1", "R6C2"], browser.table!(:index, 3).column_texts_at(1))
  end

  def test_get_rowvalues_full_row
    assert_equal(["R1C1", "R1C2", "R1C3"], browser.table!(:index, 3).row_texts_at(1))
  end

  def test_get_rowvalues_with_colspan
    assert_equal(["R2C1", "R2C2"], browser.table!(:index, 3).row_texts_at(2))
  end

  def test_getrowvalues_with_rowspan
    assert_equal(["R5C1", "R5C2", "R5C3"], browser.table!(:index, 3).row_texts_at(5))
    assert_equal(["R6C2", "R6C3"], browser.table!(:index, 3).row_texts_at(6))
  end
end

class TC_Tables_Complex < Test::Unit::TestCase
  
  def setup
    goto_page("complex_table.html")
  end

  def test_complex_table_access
    table = browser.table!(:index,1)
    
    assert_equal("subtable1 Row 1 Col1",table[1][1].table!(:index,1)[1][1].text.strip)
    assert_equal("subtable1 Row 1 Col2",table[1][1].table!(:index,1)[1][2].text.strip)
    assert_equal("subtable2 Row 1 Col2",table[2][1].table!(:index,1)[1][2].text.strip)
    assert_equal("subtable2 Row 1 Col1",table[2][1].table!(:index,1)[1][1].text.strip)
  end
end

class TC_Tables_Display < Test::Unit::TestCase
  include CaptureIOHelper

  #tag_method :test_showTables, :fails_on_ie
  def test_showTables
    goto_page("table1.html")
    assert_match(/There are 7 tables(\nWatir::\w*Table.*?){7}/m, capture_stdout { browser.show_tables })
  end
end
