require 'vapir-common/version'
require 'vapir-common/external/core_extensions.rb'
require 'vapir-common/browser'
require 'vapir-common/exceptions'
require 'vapir-common/config'
module Vapir
  def self.require_winwindow
    begin
      require 'winwindow'
    rescue LoadError
      message = if RUBY_PLATFORM =~ /mswin|windows|mingw32|cygwin/i
        "This may be resolved by installing the winwindow gem."
      else
        "You do not appear to be on Windows - this method is not likely to work."
      end
      raise LoadError, $!.message + "\n\n#{message}", $!.backtrace
    end
  end
end
