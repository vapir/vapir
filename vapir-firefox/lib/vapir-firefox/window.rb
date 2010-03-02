module Vapir
  # this contains methods for an object that represnts a thing that has its own window. 
  # that includes a Browser and a ModalDialog. 
  # this assumes that #browser_window_object is defined on the includer. 
  module Firefox::Window
    # returns the hWnd of this window. 
    # (MS Windows-only) 
    def hwnd
      win_window.hwnd
    end
    # returns an instance of WinWindow representing this window. 
    # (MS Windows only)
    def win_window
      require 'vapir-common/win_window'
      @win_window||=begin
        orig_browser_window_title=browser_window_object.document.title
        browser_window_object.document.title=orig_browser_window_title+(rand(36**16).to_s(36))
        begin
          candidates=::Waiter.try_for(2, :condition => proc{|ret| ret.size > 0}, :exception => nil) do
            WinWindow::All.select do |win|
              [mozilla_window_class_name].include?(win.class_name) && win.text==browser_window_object.document.title
            end
          end
          unless candidates.size==1
            raise ::WinWindow::MatchError, "Found #{candidates.size} Mozilla windows titled #{browser_window_object.document.title}"
          end
          candidates.first
        ensure
          browser_window_object.document.title=orig_browser_window_title
        end
      end
    end
    # sets this window as the foreground window (MS Windows only)
    def bring_to_front
      win_window.set_foreground!
    end
  end
end
