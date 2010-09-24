require 'vapir-common/config'
require 'vapir-ie' # need the class to be set first

module Vapir
  # if vapir-ie is required before any other browser-specific library, then set the default browser to ie
  @base_configuration.default_browser = :ie unless @base_configuration.locally_defined_key?(:default_browser)

  # add ie-specific stuff to base, and then bring them in from env and yaml 
  @base_configuration.create_update(:ie_launch_new_process, false, :validator => :boolean)
  @env_configuration.update_env
  class IE
    @configuration_parent = Vapir.config
    extend Configurable
  end
end
