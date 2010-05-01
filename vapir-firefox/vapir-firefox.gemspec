$LOAD_PATH << 'lib'

require 'vapir-firefox/version.rb'

spec = Gem::Specification.new do |s|
  s.name = 'vapir-firefox'
  s.version = Vapir::Firefox::VERSION
  s.summary = 'Library for automating the Firefox browser in Ruby'
  s.description = <<-EOF
    Vapir-Firefox is a library to programatically drive the Firefox
    browser over the JSSH Firefox extension, exposing a simple-to-use 
    and powerful API to make automated testing a simple and joyous affair. 
    Forked from the Watir library. 
  EOF
  s.author = 'Ethan'
  s.email = 'vapir@googlegroups.com'
  s.homepage = 'http://www.vapir.org/'

  s.platform = Gem::Platform::RUBY
  s.requirements = ['Firefox browser with JSSH extension installed']
  s.require_path = 'lib'

  s.add_dependency 'vapir-common', '= ' + Vapir::Firefox::VERSION
  s.add_dependency 'json', '>= 0' # TODO: put the right min version here 
  s.add_dependency 'activesupport', '>= 0' # TODO: put the right min version here 

  s.rdoc_options += [
    '--title', 'Vapir-Firefox',
    '--accessor', 'dom_attr=R', # TODO: fix this if at all possible 
    '--main', 'Vapir::Firefox',
  ]

#  s.test_files = 'unittests/*_tests.rb' # TODO: get test files in here 

  s.files = [
    'LICENSE.txt',
    'History.txt', # todo: update 
    #'Manifest.txt', #TODO: generate this from this list? 
    'README.txt', #TODO: write this 
    'lib/vapir-firefox.rb', # does the actual work of requiring the browser and element classes 
    'lib/vapir/firefox.rb', # same as the above file 
    'lib/vapir/ff.rb', # shortcut so you can require 'vapir/ff', for the lazy people 
    'lib/vapir-firefox/version.rb', 
    'lib/vapir-firefox/firefox.rb', # defines the browser class. todo: move to browser.rb 
    'lib/vapir-firefox/container.rb', # the container module which defines methods for accessing contained elements. mostly in common. 
    'lib/vapir-firefox/page_container.rb', # the page container module for stuff with a document 
    'lib/vapir-firefox/window.rb', # 
    'lib/vapir-firefox/modal_dialog.rb', # modal dialog class for interacting with Firefox modal dialogs (popups) and modal dialog documents. 
    'lib/vapir-firefox/element.rb', # the base Firefox::Element class from which all elements for Firefox inherit 
    'lib/vapir-firefox/elements/button.rb', # element classes for each element type. TODO: too many files, mostly very sparse. combine into fewer files. 
    'lib/vapir-firefox/elements/file_field.rb', # 
    'lib/vapir-firefox/elements/form.rb', # 
    'lib/vapir-firefox/elements/frame.rb', # 
    'lib/vapir-firefox/elements/hidden.rb', # 
    'lib/vapir-firefox/elements/image.rb', # 
    'lib/vapir-firefox/elements/input_element.rb', # 
    'lib/vapir-firefox/elements/link.rb', # 
    'lib/vapir-firefox/elements/non_control_elements.rb', # 
    'lib/vapir-firefox/elements/option.rb', # 
    'lib/vapir-firefox/elements/radio_check_common.rb', # 
    'lib/vapir-firefox/elements/select_list.rb', # 
    'lib/vapir-firefox/elements/table.rb', # 
    'lib/vapir-firefox/elements/table_cell.rb', # 
    'lib/vapir-firefox/elements/table_row.rb', # 
    'lib/vapir-firefox/elements/text_field.rb', # 
    'lib/vapir-firefox/elements.rb', # shortcut for requiring every element type 
    'lib/vapir-firefox/jssh_socket.rb', # class for talking over a JSSH socket to Firefox. todo: move to externals
    'lib/vapir-firefox/prototype.functional.js', # javascript extensions to make writing javascript more pleasant
    #'lib/vapir-firefox/x11.rb', # todo: figure this out. make something useful of it? delete? 
  ]
end
