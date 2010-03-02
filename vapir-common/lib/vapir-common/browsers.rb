# vapir-common/browsers
# Define browsers supported by Watir

Watir::Browser.support :name => 'ie', :class => 'Watir::IE', 
  :library => 'vapir-ie', :gem => 'vapir-ie', 
  :options => [:speed, :visible]

Watir::Browser.support :name => 'firefox', :class => 'Watir::Firefox',
  :library => 'vapir-firefox'
