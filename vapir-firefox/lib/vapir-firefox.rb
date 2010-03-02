$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'vapir'
require 'vapir-common/common_elements'

# create stub class since everything is defined in Watir::Firefox namespace - this needs to be defined before the real class.
module Watir
  class Firefox < Watir::Browser
  end
end

require 'vapir-firefox/exceptions'
require 'vapir-firefox/jssh_socket'
require 'vapir-firefox/container'
require 'vapir-firefox/page_container'
require "vapir-firefox/element"
require 'vapir-firefox/modal_dialog'

require "vapir-firefox/elements/form"
require "vapir-firefox/elements/frame"
require "vapir-firefox/elements/non_control_element"
require "vapir-firefox/elements/non_control_elements"
require "vapir-firefox/elements/table"
require "vapir-firefox/elements/table_row"
require "vapir-firefox/elements/table_cell"
require "vapir-firefox/elements/image"
require "vapir-firefox/elements/link"
require "vapir-firefox/elements/input_element"
require "vapir-firefox/elements/select_list"
require "vapir-firefox/elements/option"
require "vapir-firefox/elements/button"
require "vapir-firefox/elements/text_field"
require "vapir-firefox/elements/hidden"
require "vapir-firefox/elements/file_field"
require "vapir-firefox/elements/radio_check_common"
require "vapir-firefox/element_collections"

require 'vapir-common/matches'
require 'vapir-firefox/firefox'
require 'vapir-firefox/version'



# this only has an effect if firewatir is required before anyone invokes 
# Browser.new. Thus it has no effect when Browser.new itself autoloads this library.
Watir::Browser.default = 'firefox'
