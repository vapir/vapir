# feature tests for screen capture
# revision: $Revision:1338 $

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..') unless $SETUP_LOADED
require 'unittests/setup'

class TC_Capture< Test::Unit::TestCase
  tags :must_be_visible
  
  def setup
    delete_captured_files('capture_window.bmp', 'capture_client.bmp', 'capture_desktop.bmp')
    browser.goto($htmlRoot + 'buttons1.html')
    @file_list = []
  end
  
  def teardown
    delete_captured_files
  end
  
  def delete_captured_files(*files)
    files = @file_list if files.empty?
    files.each do |f|
      File.delete(f) if FileTest.exists?(f)
    end
  end
  
  def test_capture
    client_bmp_file= 'capture_client.bmp'
    @file_list << client_bmp_file
    browser.screen_capture(client_bmp_file, :client)   # just the active window's client area
    assert(FileTest.exist?(client_bmp_file))
    assert File.size(client_bmp_file) > 0

    window_bmp_file= 'capture_window.bmp'
    @file_list << window_bmp_file
    browser.screen_capture(window_bmp_file, :window)   # just the active window
    assert(FileTest.exist?(window_bmp_file))
    assert File.size(window_bmp_file) > File.size(client_bmp_file) # the window area should be bigger than the client area

    desktop_file= 'capture_desktop.bmp'
    @file_list << desktop_file
    browser.screen_capture(desktop_file, :desktop) # full desktop
    assert(FileTest.exist?(desktop_file))
    assert File.size(desktop_file) >= File.size(window_bmp_file) # the desktop area should be at least as big as the window area (same if it's maximized)
  end
  
end

