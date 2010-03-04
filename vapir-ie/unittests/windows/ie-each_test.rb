# Not intended to be run as part of a larger suite.

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..') unless $SETUP_LOADED
require 'test/unit'
require 'vapir'
require 'vapir-ie/process'
require 'vapir-common/waiter'

class TC_IE_Each < Test::Unit::TestCase
  def setup
    assert_equal 0, Vapir::IE.process_count
    @hits = 0
    @ie = []
  end
  
  def hit_me
    @hits += 1
  end

  def test_zero_windows
    Vapir::IE.each {hit_me}
    assert_equal 0, @hits
  end
  
  def test_one_window
    @ie << Vapir::IE.new_process
    Vapir::IE.each {hit_me}
    assert_equal 1, @hits
  end
  
  def test_two_windows
    @ie << Vapir::IE.new_process
    @ie << Vapir::IE.new_process
    Vapir::IE.each {hit_me}
    assert_equal 2, @hits
  end
  
  def test_return_type
    @ie << Vapir::IE.new_process
    Vapir::IE.each {|ie| assert_equal(Vapir::IE, ie.class)}
  end
  
  include Vapir
  def teardown
    @ie.each {|ie| ie.close }
    wait_until {Vapir::IE.process_count == 0}
  end
end