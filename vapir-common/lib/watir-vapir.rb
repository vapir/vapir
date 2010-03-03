require 'vapir'
if Object.const_defined?('Watir')
  raise "Watir is already defined! Cannot load Vapir in its place."
end
Watir=Vapir
