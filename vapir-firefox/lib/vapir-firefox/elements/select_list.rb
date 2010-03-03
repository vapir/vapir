require 'vapir-firefox/elements/input_element'
require 'vapir-common/elements/elements'

module Vapir
  #
  # Description:
  #   Class for SelectList element.
  #
  class Firefox::SelectList < Firefox::InputElement
    include Vapir::SelectList
  end # SelectList
end # Vapir
