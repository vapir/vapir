require 'vapir-common/config'
require 'vapir-firefox' # need the class to be set first

module Vapir
  # if vapir-firefox is required before any other browser-specific library, then set the default browser to firefox 
  @base_configuration.default_browser = :firefox unless @base_configuration.locally_defined_key?(:default_browser)

  # add firefox-specific stuff to base, and then bring them in from env and yaml 
  @base_configuration.create(:firefox_profile)
  @base_configuration.create(:firefox_binary_path)
  @base_configuration.create_update(:firefox_extension, 'jssh')
  @base_configuration.create(:firefox_mozrepl_port)
  @base_configuration.create(:firefox_mozrepl_host)
  @base_configuration.create(:firefox_jssh_port)
  @base_configuration.create(:firefox_jssh_host)
  @base_configuration.create_update(:firefox_quit_sleep_time, 4, :validator => :numeric)
  @configurations.update_from_source
  class Firefox
    @configuration_parent = Vapir.config
    extend Configurable
  end
end
