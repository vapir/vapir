require 'vapir-common'

# create stub class since everything is defined in Vapir::Firefox namespace - this needs to be defined before the real class.
require 'vapir-common/browser'
module Vapir
  Firefox = Class.new(Vapir::Browser)
end

require 'vapir-firefox/config'
require 'vapir-firefox/browser'
require 'vapir-firefox/elements'
require 'vapir-firefox/version'

# this only has an effect if firewatir is required before anyone invokes 
# Browser.new. Thus it has no effect when Browser.new itself autoloads this library.
Vapir::Browser.default = 'firefox'
