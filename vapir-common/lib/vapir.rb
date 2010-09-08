base = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
['vapir-common','vapir-ie','vapir-firefox'].each do |lib|
  libdir = File.join(base, lib, 'lib')
  if File.directory?(libdir) && !$LOAD_PATH.any?{|lp| File.expand_path(lp) == File.expand_path(libdir) }
    $LOAD_PATH.unshift(libdir)
  end
end
require 'vapir-common'
