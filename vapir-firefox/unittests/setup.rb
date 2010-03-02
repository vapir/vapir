$SETUP_LOADED = true

$myDir = File.expand_path(File.dirname(__FILE__))

topdir = File.join(File.dirname(__FILE__), '..')
$firewatir_dev_lib = File.join(topdir, 'lib')
$watir_dev_lib = File.join(topdir, '..', 'vapir-ie', 'lib')
libs = []
libs << File.join(topdir, '..', 'vapir-common', 'lib')
libs << File.join(topdir, '..', 'vapir-common') # for the unit tests
libs.each { |lib| $LOAD_PATH.unshift File.expand_path(lib) }

require 'vapir'
Watir::Browser.default = 'firefox'
require 'unittests/setup/lib'
module Watir::UnitTest
  alias :uses_page :goto_page
end

require 'unittests/setup/testUnitAddons'

commondir = File.join(topdir, '..', 'vapir-common')
$all_tests = []
Dir.chdir topdir do
  $all_tests += Dir["unittests/*_test.rb"]
end
Dir.chdir commondir do
  $all_tests += Dir["unittests/*_test.rb"]
end
