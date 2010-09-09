require 'vapir-common/config'
require 'vapir-ie' # need the class to be set first

module Vapir
  # add ie-specific stuff to base, and then bring them in from env and yaml 
  
  class IE
    @configuration_parent = Vapir.config
    extend Configurable
  end
end
