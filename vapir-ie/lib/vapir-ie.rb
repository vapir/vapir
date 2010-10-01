require 'vapir-common'

# create stub class since everything is defined in Vapir::IE namespace - this needs to be defined before the real class.
require 'vapir-common/browser'
module Vapir
  IE= Class.new(Vapir::Browser)
end

# these switches need to be deleted from ARGV to enable the Test::Unit
# functionality that grabs
# the remaining ARGV as a filter on what tests to run.
# Note: this means that watir must be require'd BEFORE test/unit.
# (Alternatively, you could require test/unit first and then put the Vapir::IE
# arguments after the '--'.)

# Make Internet Explorer invisible. -b stands for background
$HIDE_IE ||= ARGV.delete('-b')

# Eat the -s command line switch (deprecated)
ARGV.delete('-s')

require 'vapir-ie/config'
require 'vapir-ie/browser'
require 'vapir-ie/elements'
require 'vapir-ie/version'

require 'vapir-common/waiter'

module Vapir
  include Vapir::Exception

  # Directory containing the watir.rb file
  @@dir = File.expand_path(File.dirname(__FILE__))

end
