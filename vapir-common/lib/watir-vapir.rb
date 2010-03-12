require 'vapir'
if Object.const_defined?('Watir')
  if Watir != Vapir
    raise "Watir is already defined! Cannot load Vapir in its place."
  end
else
  Watir=Vapir
end
if Object.const_defined?('FireWatir')
  if FireWatir != Vapir
    raise "FireWatir is already defined! Cannot load Vapir in its place."
  end
else
  FireWatir=Vapir
end
