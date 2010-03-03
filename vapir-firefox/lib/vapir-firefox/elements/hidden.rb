require 'vapir-firefox/elements/text_field'
require 'vapir-common/elements/elements'

module Vapir
  #
  # Description:
  #   Class for Hidden Field element.
  #
  class Firefox::Hidden < Firefox::TextField
    include Vapir::Hidden
  end # Hidden
end # Vapir
