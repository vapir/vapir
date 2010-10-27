$LOAD_PATH << 'lib'

require 'vapir-common/version' # to get our version number 

Vapir::Common::GemSpec = Gem::Specification.new do |s|
  s.name = 'vapir-common'
  s.version = Vapir::Common::VERSION
  s.summary = 'Common basis for Vapir libraries for automating web browsers in Ruby'
  s.description = <<-EOF
    Vapir Common is a library containing common code shared among browser-specific
    Vapir implementations which programatically drive the web browsers,
    exposing a simple-to-use and powerful API to make automated testing a 
    simple and joyous affair. 
    Forked from the Watir library. 
  EOF
  s.author = 'Ethan'
  s.email = 'vapir@googlegroups.com'
  s.homepage = 'http://www.vapir.org/'

  s.platform = Gem::Platform::RUBY
  #s.requirements = []
  s.require_path = 'lib'

  s.add_dependency 'user-choices', '>= 0'

  s.rdoc_options += [
    '--title', 'Vapir-Common',
    '--accessor', 'dom_attr=R', # TODO: fix this if at all possible 
    '--main', 'Vapir::Browser',
  ]

#  s.test_files = 'unittests/*_tests.rb' # TODO: tests. 

  s.files = [
    'History.txt', #TODO
    #'Manifest.txt', #TODO: generate this from this list? 
    'README.txt', #TODO: write more in this 
    'lib/vapir-common.rb', # does the work of requiring what is needed for vapir-common's environment, in particular the autoloaded constants 
    'lib/vapir/common.rb', # lets you require 'vapir/common' rather than require 'vapir-common', if that's your preference. 
    'lib/vapir.rb', # does the same stuff as the above two files. nice so that you can just require 'vapir' and let autoloads deal with the rest. 
    'lib/watir-vapir.rb', # defines the Watir and FireWatir namespaces for compatibility with existing code using Watir 
    'lib/vapir-common/version.rb',
    'lib/vapir-common/config.rb', # defines Configurable module included in any configurable vapir object, and Configuration class that is returned by that method. 
    'lib/vapir-common/browser.rb', # the common browser class from which Firefox and IE classes inherit 
    'lib/vapir-common/browsers.rb', # defines stuff for the browsers that use this, most importantly, autoload stuff. todo: don't think this needs a file separate from browser.rb 
    'lib/vapir-common/container.rb', # the common module for all Containers; all common container methods (such as #div, #text_field) are defined on this module 
    'lib/vapir-common/page_container.rb', # the common page container module for stuff with a document 
    'lib/vapir-common/modal_dialog.rb', # common module for browser-specific ModalDialog classes. 
    'lib/vapir-common/specifier.rb', # various methods related to how vapir specifies elements and coding that on the DOM 
    'lib/vapir-common/element_class_and_module.rb', # module of methods to be defined on the metaclass of both common Element modules and and browser-specific Element classes 
    'lib/vapir-common/element.rb', # the common Element module, included by all browser specific Element classes. 
    'lib/vapir-common/elements/elements.rb', # defines the common element modules. todo: split this across more files. 
    'lib/vapir-common/element_collection.rb', # 
    'lib/vapir-common/elements.rb', # shortcut to load all of the common element modules 
    'lib/vapir-common/keycodes.rb', # keycodes for javascript events 
    'lib/vapir-common/exceptions.rb', # exceptions used by vapir 
    'lib/vapir-common/handle_options.rb', # todo: move to external lib stuff
    'lib/vapir-common/options.rb', # todo: 
    #'lib/vapir-common/testcase.rb', # todo: move to unittests? not needed for gem 
    'lib/vapir-common/waiter.rb', # todo: move to external
    'lib/vapir-common/external/core_extensions.rb',
  ]
end
