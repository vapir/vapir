# rapidly open and close IE windows

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..', 'lib')
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..', '..', 'vapir-common', 'lib')
require 'test/unit'
require 'vapir-ie'
require 'vapir-ie/contrib/ie-new-process'

class ZZ_OpenClose < Test::Unit::TestCase
  20.times do | i |
    define_method "test_#{i}" do
      sleep 0.05
      sleep i * 0.01
      ie = Vapir::IE.new_process
      ie.goto 'http://blogs.dovetailsoftware.com/blogs/gsherman/default.aspx'
      ie.close
    end
  end
end