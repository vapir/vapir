require 'vapir-common'

# create stub class since everything is defined in Vapir::IE namespace - this needs to be defined before the real class.
require 'vapir-common/browser'
module Vapir
  IE= Class.new(Vapir::Browser)
end

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
