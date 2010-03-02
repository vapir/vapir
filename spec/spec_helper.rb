$LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/../vapir-common/lib")
$LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/../vapir-ie/lib")
$LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/../vapir-firefox/lib")

require "vapir"

case ENV['watir_browser']
when /firefox/
  Browser = Watir::Firefox
else
  Browser = Watir::IE
  WatirSpec.persistent_browser = true
end

include Watir::Exception
