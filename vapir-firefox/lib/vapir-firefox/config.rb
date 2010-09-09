require 'vapir-common/config'
require 'vapir-firefox' # need the class to be set first

module Vapir
  # add firefox-specific stuff to base, and then bring them in from env and yaml 
  
  class Firefox
    @configuration_parent = Vapir.config
    extend Configurable
  end
end
