# unit tests for iedialog.dll and customized win32ole.so
# revision: $Revision$

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..') unless $SETUP_LOADED
require 'unittests/setup'
require 'Win32API'

class TC_IEDialog < Test::Unit::TestCase
  include Vapir 

  # this will find the IEDialog.dll file in its build location
  @@iedialog_file = (File.expand_path(File.dirname(__FILE__)) + "/../../lib/vapir-ie/IEDialog/Release/IEDialog.dll").gsub('/', '\\')

  def test_all
    goto_page "pass.html"

    fnFindWindow = Win32API.new('user32.dll', 'FindWindow', ['p', 'p'], 'l')
    hwnd = fnFindWindow.call(nil, "Pass Page - Microsoft Internet Explorer")
    if hwnd==0
      hwnd = fnFindWindow.call(nil, "Pass Page - Windows Internet Explorer")
    end

    fnGetUnknown = Win32API.new(@@iedialog_file, 'GetUnknown', ['l', 'p'], 'v')
    intPointer = " " * 4 # will contain the int value of the IUnknown*
    fnGetUnknown.call(hwnd, intPointer)
    
    intArray = intPointer.unpack('L')
    intUnknown = intArray.first

    assert(intUnknown > 0)
    
    htmlDoc = nil
    assert_nothing_raised{htmlDoc = WIN32OLE.connect_unknown(intUnknown)}
    scriptEngine = htmlDoc.Script
    
    # now we get the HTML DOM object!
    doc2 = scriptEngine.document
    body = doc2.body
    assert_match(/^PASS/, body.innerHTML.strip)
  end
end

