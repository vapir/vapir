# vapir-common/browsers
# Define browsers supported by Vapir

Vapir::Browser.support :name => 'ie', :class => 'Vapir::IE', 
  :library => 'vapir-ie', :gem => 'vapir-ie', 
  :options => [:speed, :visible]

Vapir::Browser.support :name => 'firefox', :class => 'Vapir::Firefox',
  :library => 'vapir-firefox'
