$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED

require 'vapir-ie/WindowHelper'


helper = WindowHelper.new
helper.logon('Connect to clio.lyris.com')