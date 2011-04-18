require 'vapir-common/config'
require 'vapir-ie' # need the class to be set first

module Vapir
  # if vapir-ie is required before any other browser-specific library, then set the default browser to ie
  @base_configuration.default_browser = :ie unless @base_configuration.locally_defined_key?(:default_browser)

  # add ie-specific stuff to base, and then bring them in from env and yaml 
  @base_configuration.create_update(:ie_launch_new_process, false, :validator => :boolean)
  @base_configuration.create_update(:browser_visible, true, :validator => :boolean)
  if defined?($HIDE_IE)
    if config.warn_deprecated
      Kernel.warn "WARNING: The $HIDE_IE global is gone. Please use the new config framework, and unset that global to silence this warning."
    end
    Vapir.config.browser_visible=false
  end
  @configurations.update_from_source
  class IE
    @configuration_parent = Vapir.config
    extend Configurable
  end
end
