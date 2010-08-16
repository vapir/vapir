$LOAD_PATH << 'lib'

require 'vapir-ie/version'

spec = Gem::Specification.new do |s|
  s.name = 'vapir-ie'
  s.version = Vapir::IE::VERSION
  s.summary = 'Library for automating the Internet Explorer browser in Ruby'
  s.description = <<-EOF
    Vapir-IE is a library to programatically drive the Internet Explorer 
    browser using the OLE interface, exposing a simple-to-use and powerful
    API to make automated testing a simple and joyous affair. 
    Forked from the Watir library. 
  EOF
  s.author = 'Ethan'
  s.email = 'vapir@googlegroups.com'
  s.homepage = 'http://www.vapir.org/'

  s.platform = Gem::Platform::RUBY 
    # should be windows specific? options are only RUBY or CURRENT, and CURRENT is 
    # specific to the compiled ruby (mingw32 or mswin32), not the operating system. 
  s.requirements = ['Microsoft Windows', 'Internet Explorer']
  s.require_path = 'lib'

  s.add_dependency 'win32-process', '>= 0.5.5' # TODO: check this
  s.add_dependency 'windows-pr', '>= 0.6.6'
  s.add_dependency 'vapir-common', '= ' + Vapir::IE::VERSION
  s.add_dependency 'nokogiri'
  s.add_dependency 'ffi', '>= 0.5.4'

  s.rdoc_options += [
    '--title', 'Vapir-IE',
    '--accessor', 'dom_attr=R', # TODO: fix this if at all possible 
    '--main', 'Vapir::IE',
  ]

#  s.test_files = 'unittests/*_tests.rb'

  s.files = [
    'History.txt', # TODO: update
    'LICENSE.txt',
    #'Manifest.txt', #TODO: generate this from this list
    'README.txt', # TODO, update this. 
    'lib/vapir-ie.rb', # does the work of requiring what is needed to load all of vapir-ie's environment 
    'lib/vapir/ie.rb', # lets you require 'vapir/ie' rather than require 'vapir-ie', in line with watir's require 'watir/ie' 
    'lib/vapir-ie/version.rb',
    'lib/vapir-ie/browser.rb', # the Vapir::IE class representing an IE browser. 
    'lib/vapir-ie/ie-process.rb', # todo: this might be merged into the browser class file. 
    'lib/vapir-ie/process.rb', # todo: merge with the previous file. not sure to where. 
    'lib/vapir-ie/close_all.rb', #TODO: this doesn't need its own file; move it into the ie class
    'lib/vapir-ie/container.rb', # the container module which defines methods for accessing contained elements. mostly in common. 
    'lib/vapir-ie/page_container.rb', # the page container module for stuff with a document 
    'lib/vapir-ie/modal_dialog.rb', # modal dialog class for interacting with IE modal dialogs (popups) and modal dialog documents. 
    'lib/vapir-ie/element.rb', # the base IE::Element class from which all elements for IE inherit 
    'lib/vapir-ie/elements.rb', # shortcut for requiring every element type 
    'lib/vapir-ie/frame.rb', # element classes. todo: these should move into lib/vapir-ie/elements directory. 
    'lib/vapir-ie/form.rb',
    'lib/vapir-ie/non_control_elements.rb',
    'lib/vapir-ie/input_elements.rb',
    'lib/vapir-ie/table.rb',
    'lib/vapir-ie/image.rb',
    'lib/vapir-ie/link.rb',
    'lib/vapir-ie/logger.rb', # logging. (needs much work) 
    'lib/vapir-ie/clear_tracks.rb', # code to clear cache, history, cookies, etc. 
    'lib/vapir-ie/scripts/select_file.rb', # standalone script to interact with a file upload selector dialog. 
    'lib/vapir-ie/autoit.rb', 'lib/vapir-ie/AutoItX.chm', 'lib/vapir-ie/AutoItX3.dll', # autoit crap. hopefully the last remnants of this will merge into WinWindow. 
    'lib/vapir-ie/IEDialog/Release/IEDialog.dll', # todo: write this in ruby 
    'lib/vapir-ie/win32ole.rb', # loads the correct win32ole and adds #respond_to?. todo: should be written in c. 
    'lib/vapir-ie/win32ole/win32ole.so', # todo: compile this for ruby 1.9 and include both versions 
    'lib/vapir-ie/screen_capture.rb', # this is gone. todo: file will be deleted at some point. 
    #'lib/vapir-ie/datahandler.rb', #todo: delete. this won't ever be supported by vapir. 
    #'lib/vapir-ie/contrib' # todo: merge what ought to be merged; delete the rest. 
    #'lib/vapir-ie/contrib/ie-new-process.rb', # TODO: maybe merge some of the ideas of this (OpenProcess, TerminateProcess) into WinWindow 
  ]
end
