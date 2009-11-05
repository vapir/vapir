require 'dl/import'
require 'dl/struct'

require 'watir/handle_options'
require 'watir/waiter'

class WinWindow
  # Class that wraps useful methods of user32.dll involving windows in MS Windows (oh wonderful naming)
  #
  #--
  #
  # todo: 
  # * maybe use a class or module with include DL::Importable and extern 
  #   functions used instead of calling User32['whatever', '...'] every time
  #   (see win32screenshot.rb)
  # * make sure the signatures being used are correct with the letter codings (bools are chars in some places, pointers, voids may be wrong)
  # * GetTitleBarInfo http://msdn.microsoft.com/en-us/library/ms633513(VS.85).aspx
  # * GetWindowInfo http://msdn.microsoft.com/en-us/library/ms633516(VS.85).aspx http://msdn.microsoft.com/en-us/library/ms632610(VS.85).aspx
  # * ? ShowOwnedPopups http://msdn.microsoft.com/en-us/library/ms633547(VS.85).aspx
  # * FindWindow http://msdn.microsoft.com/en-us/library/ms633499(VS.85).aspx
  # * other useful stuff, see http://msdn.microsoft.com/en-us/library/ms632595(VS.85).aspx
  # * expand SendMessage / PostMessage http://msdn.microsoft.com/en-us/library/ms644950(VS.85).aspx http://msdn.microsoft.com/en-us/library/ms644944(VS.85).aspx
  
  class Error < StandardError;end
  class SystemError < Error;end
  class NotExistsError < Error;end
  class MatchError < Error;end
  
  User32 = DL.dlopen("user32")
  Kernel32 = DL.dlopen("kernel32")

  WM_CLOSE    = 0x0010
  WM_KEYDOWN  = 0x0100
  WM_KEYUP    = 0x0101
  WM_CHAR     = 0x0102
  BM_CLICK    = 0x00F5
  WM_COMMAND  = 0x0111
  WM_SETTEXT  = 0x000C
  WM_GETTEXT  = 0x000D
  WM_GETTEXTLENGTH = 0xE

  #--
  # GetWindows constants
  GW_HWNDFIRST = 0
  GW_HWNDLAST = 1
  GW_HWNDNEXT = 2
  GW_HWNDPREV = 3
  GW_OWNER = 4
  GW_CHILD = 5
  GW_ENABLEDPOPUP = 6
  GW_MAX = 6

  #--
  # GetAncestor constants
  GA_PARENT = 1
  GA_ROOT = 2
  GA_ROOTOWNER = 3 
  
  #--
  # ShowWindow constants - http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  SW_HIDE            = 0 # Hides the window and activates another window.
  SW_SHOWNORMAL      = 1 # Activates and displays a window. If the window is minimized or maximized, the system restores it to its original size and position. An application should specify this flag when displaying the window for the first time.
  SW_SHOWMINIMIZED   = 2 # Activates the window and displays it as a minimized window.
  SW_SHOWMAXIMIZED   = 3 # Activates the window and displays it as a maximized window.
  SW_MAXIMIZE        = 3 # Maximizes the specified window. 
                         #--
                         # there seems to be no distinct SW_MAXIMIZE (but there is a distinct SW_MINIMIZE), just the same as SW_SHOWMAXIMIZED
                         # some references define SW_MAXIMIZE as 11, which seems to just be wrong; that is correctly SW_FORCEMINIMIZE
  SW_SHOWNOACTIVATE  = 4 # Displays a window in its most recent size and position. This value is similar to SW_SHOWNORMAL, except the window is not actived.
  SW_SHOW            = 5 # Activates the window and displays it in its current size and position. 
  SW_MINIMIZE        = 6 # Minimizes the specified window and activates the next top-level window in the Z order.
  SW_SHOWMINNOACTIVE = 7 # Displays the window as a minimized window. This value is similar to SW_SHOWMINIMIZED, except the window is not activated.
  SW_SHOWNA          = 8 # Displays the window in its current size and position. This value is similar to SW_SHOW, except the window is not activated.
  SW_RESTORE         = 9 # Activates and displays the window. If the window is minimized or maximized, the system restores it to its original size and position. An application should specify this flag when restoring a minimized window.
  SW_SHOWDEFAULT    = 10 # Sets the show state based on the SW_ value specified in the STARTUPINFO structure passed to the CreateProcess function by the program that started the application. 
  SW_FORCEMINIMIZE  = 11 # Windows 2000/XP: Minimizes a window, even if the thread that owns the window is not responding. This flag should only be used when minimizing windows from a different thread.

  WIN_TRUE=-1
  WIN_FALSE=0

  attr_reader :hwnd

  # creates a WinWindow from a given hWnd handle (integer) 
  #
  # raises ArgumentError if the hWnd is not a Fixnum greater than 0
  def initialize(hwnd)
    raise ArgumentError, "hwnd must be an integer greater than 0" unless hwnd.is_a?(Fixnum) && hwnd > 0
    @hwnd=hwnd
  end
  
  def inspect
    retrieve_text
    class_name
    Object.instance_method(:inspect).bind(self).call
  end
  
  def pretty_print(pp)
    retrieve_text
    class_name
    pp.pp_object(self)
  end

  # retrieves the text of this window's title bar (if it has one). If this is a control, the text of the control is retrieved. 
  # However, #text cannot retrieve the text of a control in another application (see #retrieve_text) 
  #
  # http://msdn.microsoft.com/en-us/library/ms633520(VS.85).aspx
  def text
    buff_size=text_length+1
    buff="\000"*buff_size
    len,(passed_hwnd,buff,buff_size)= User32['GetWindowText' , 'ILSI'].call(hwnd, buff, buff_size)
    @text=buff[0...len]
  end

  # length of the window text, see #text
  # similar to #text, cannot retrieve the text of a control in another application - see #retrieve_text, #retrieve_text_length
  #
  # http://msdn.microsoft.com/en-us/library/ms633521(VS.85).aspx
  def text_length
    len, args= User32['GetWindowTextLength', 'LL'].call(hwnd)
    len
  end

  # This is similar to #text
  # that one is GetWindowText(hwnd) 
  # this one is SendMessage(hwnd, WM_GETTEXT)
  # differences are documented here: http://msdn.microsoft.com/en-us/magazine/cc301438.aspx
  # and here: http://blogs.msdn.com/oldnewthing/archive/2003/08/21/54675.aspx
  def retrieve_text
    buff_size=retrieve_text_length+1
    buff="\000"*buff_size
    len, (passed_hwnd, passed_thing, buff_size, buff)= User32['SendMessage', 'ILIIS'].call(hwnd, WM_GETTEXT, buff_size, buff)
    @text=buff[0...len]
  end
  
  # similar to #text_length; differences between that and this are the same as between #text and #retrieve_text 
  def retrieve_text_length
    len, args= User32['SendMessage', 'LLIII'].call(hwnd, WM_GETTEXTLENGTH, 0, 0)
    len
  end

  # changes the text of the specified window's title bar (if it has one). If the specified window is a control, the text of the control is changed. 
  # However, #set_text! cannot change the text of a control in another application (see #send_set_text!) 
  #
  # http://msdn.microsoft.com/en-us/library/ms633546(VS.85).aspx
  def set_text!(text)
    set, args= User32['SetWindowText', 'CLS'].call(hwnd, text)
    set != WIN_FALSE
  end

  # sets text by sending WM_SETTEXT message. this different than #set_text! in the same way that
  # #retrieve_text is different than #text
  def send_set_text!(text)
    ret, args= User32['SendMessage', 'ILISS'].call(hwnd, WM_SETTEXT, '', text)
    nil
  end

  # The retrieved handle identifies the enabled popup window owned by the specified window 
  # (the search uses the first such window found using GW_HWNDNEXT); otherwise, if there 
  # are no enabled popup windows, nil is returned. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633515(VS.85).aspx
  def enabled_popup
    popup_hwnd, args=User32['GetWindow', 'LLL'].call(hwnd, GW_ENABLEDPOPUP)
    @enabled_popup= popup_hwnd > 0 && popup_hwnd != self.hwnd ? self.class.new(popup_hwnd) : nil
  end

  # The retrieved handle identifies the specified window's owner window, if any. 
  # 
  # http://msdn.microsoft.com/en-us/library/ms633515(VS.85).aspx
  def owner
    owner_hwnd, args=User32['GetWindow', 'LLL'].call(hwnd, GW_OWNER)
    @owner= owner_hwnd > 0 ? self.class.new(owner_hwnd) : nil
  end
  
  # Retrieves the parent window. This does not include the owner, as it does with #parent
  # 
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  def ancestor_parent
    ret_hwnd, args=User32['GetAncestor', 'LLI'].call(hwnd, GA_PARENT)
    @ancestor_parent= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # Retrieves the root window by walking the chain of parent windows.
  #
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  def ancestor_root
    ret_hwnd, args=User32['GetAncestor', 'LLI'].call(hwnd, GA_ROOT)
    @ancestor_root= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # Retrieves the owned root window by walking the chain of parent and owner windows returned by GetParent. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  def ancestor_root_owner
    ret_hwnd, args=User32['GetAncestor', 'LLI'].call(hwnd, GA_ROOTOWNER)
    @ancestor_root_owner= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # determines which pop-up window owned by this window was most recently active
  #
  # http://msdn.microsoft.com/en-us/library/ms633507(VS.85).aspx
  def last_active_popup
    ret_hwnd, args=User32['GetLastActivePopup', 'LL'].call(hwnd)
    @last_active_popup= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # examines the Z order of the child windows associated with self and retrieves a handle to the child window at the top of the Z order
  #
  # http://msdn.microsoft.com/en-us/library/ms633514(VS.85).aspx
  def top_window
    ret_hwnd, args=User32['GetTopWindow', 'LL'].call(hwnd)
    @top_window= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end

  # retrieves a handle to this window's parent or owner
  #
  # http://msdn.microsoft.com/en-us/library/ms633510(VS.85).aspx
  def parent
    parent_hwnd,args=User32['GetParent', 'LL'].call(hwnd)
    @parent= parent_hwnd > 0 ? self.class.new(parent_hwnd) : nil
  end

  # changes the parent window of this child window
  #
  # http://msdn.microsoft.com/en-us/library/ms633541(VS.85).aspx
  def set_parent!(parent)
    parent_hwnd= parent.is_a?(self.class) ? parent.hwnd : parent
    new_parent, args=User32['SetParent', 'LLL'].call(hwnd, parent_hwnd)
    new_parent > 0 ? self.class.new(new_parent) : nil
  end

  # tests whether a window is a child window or descendant window of a specified parent window. A child window is the direct descendant of a specified parent window if that parent window is in the chain of parent windows; the chain of parent windows leads from the original overlapped or pop-up window to the child window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633524(VS.85).aspx
  def child_of?(parent)
    parent_hwnd= parent.is_a?(self.class) ? parent.hwnd : parent
    child, args=User32['IsChild', 'CLL'].call(parent_hwnd, hwnd)
    child!=WIN_FALSE
  end

  # determine if Microsoft Windows considers that a specified application is not responding. An application is considered to be not responding if it is not waiting for input, is not in startup processing, and has not called PeekMessage within the internal timeout period of 5 seconds. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633526.aspx
  def hung_app?
    hung,args= User32['IsHungAppWindow','CL'].call(hwnd)
    hung != WIN_FALSE
  end

  # retrieves the name of the class to which this window belongs
  #
  # http://msdn.microsoft.com/en-us/library/ms633582(VS.85).aspx
  def class_name
    buff_size=256
    buff="\000"*buff_size
    len, (passed_hwnd, buff, buff_size)=User32['GetClassName', 'ILpI'].call(hwnd, buff, buff_size)
    @class_name=buff.to_s[0...len]
  end
  
  # retrieves a string that specifies the window type
  #
  # http://msdn.microsoft.com/en-us/library/ms633538(VS.85).aspx
  def real_class_name
    buff_size=256
    buff="\000"*buff_size
    len, (passed_hwnd, buff, buff_size)=User32['RealGetWindowClass', 'ILpI'].call(hwnd, buff, buff_size)
    @real_class_name=buff.to_s[0...len]
  end
  
  # determines whether the specified window handle identifies an existing window
  #
  # http://msdn.microsoft.com/en-us/library/ms633528(VS.85).aspx
  def exists?
    ret, args=User32['IsWindow', 'CL'].call(hwnd)
    ret != WIN_FALSE
  end

  # visibility state of the specified window
  #
  # http://msdn.microsoft.com/en-us/library/ms633530(VS.85).aspx
  def visible?
    ret, args=User32['IsWindowVisible', 'CL'].call(hwnd)
    ret != WIN_FALSE
  end

  # whether the window is minimized (iconic).
  #
  # http://msdn.microsoft.com/en-us/library/ms633527(VS.85).aspx
  def iconic?
    ret, args=User32['IsIconic', 'CL'].call(hwnd)
    ret != WIN_FALSE
  end
  alias minimized? iconic?
  
  # switch focus and bring to the foreground
  # the argument alt_tab, if true, indicates that the window is being switched to using the Alt/Ctl+Tab key sequence. This argument should be false otherwise.
  #
  # http://msdn.microsoft.com/en-us/library/ms633553(VS.85).aspx
  def switch_to!(alt_tab=false)
    void, args=User32['SwitchToThisWindow','pLC'].call(hwnd, alt_tab ? WIN_TRUE : WIN_FALSE)
    nil
  end

  # puts the thread that created the specified window into the foreground and activates the window. Keyboard input is directed to the window, and various visual cues are changed for the user. The system assigns a slightly higher priority to the thread that created the foreground window than it does to other threads.
  # If the window was brought to the foreground, the return value is true.
  # If the window was not brought to the foreground, the return value is false.
  #
  # http://msdn.microsoft.com/en-us/library/ms633539(VS.85).aspx
  def set_foreground!
    ret, args=User32['SetForegroundWindow','CL'].call(hwnd)
    ret != WIN_FALSE
  end

  
  LSFW_LOCK = 1
  LSFW_UNLOCK = 2
  def self.lock_set_foreground_window
    ret, args=User32['LockSetForegroundWindow', 'CI'].call(LSFW_LOCK)
    ret != WIN_FALSE
  end
  def self.unlock_set_foreground_window
    ret, args=User32['LockSetForegroundWindow', 'CI'].call(LSFW_UNLOCK)
    ret != WIN_FALSE
  end

  VK_MENU=0x12
  KEYEVENTF_KEYDOWN=0x0
  KEYEVENTF_KEYUP=0x2
  # attempts to circumvent a lock disabling calls made by set_foreground!
  # then call set_foreground! and hopefully that will work. 
  def really_set_foreground!
    # Simulate two single ALT keystrokes in order to deactivate lock on SetForeGroundWindow before we call it.
    # See LockSetForegroundWindow, http://msdn.microsoft.com/en-us/library/ms633532(VS.85).aspx
    # also keybd_event, see http://msdn.microsoft.com/en-us/library/ms646304(VS.85).aspx
    #
    # this idea is taken from AutoIt's setforegroundwinex.cpp in SetForegroundWinEx::Activate(HWND hWnd)
    # keybd_event((BYTE)VK_MENU, MapVirtualKey(VK_MENU, 0), 0, 0);
    # keybd_event((BYTE)VK_MENU, MapVirtualKey(VK_MENU, 0), KEYEVENTF_KEYUP, 0);

    mapped_vk_menu, args=User32['MapVirtualKey', 'III'].call(VK_MENU, 0)
    2.times do
      ret, args=User32['keybd_event','CCCCC'].call(VK_MENU, mapped_vk_menu, KEYEVENTF_KEYDOWN, 0)
      ret, args=User32['keybd_event','CCCCC'].call(VK_MENU, mapped_vk_menu, KEYEVENTF_KEYUP, 0)
    end
    set_foreground!
  end

  # brings the window to the top of the Z order. If the window is a top-level window, it is activated. If the window is a child window, the top-level parent window associated with the child window is activated.
  #
  # http://msdn.microsoft.com/en-us/library/ms632673(VS.85).aspx
  def bring_to_top!
    ret, args=User32['BringWindowToTop','CL'].call(hwnd)
    ret != WIN_FALSE
  end
  
  # minimizes this window (but does not destroy it)
  # (why is it called close? I don't know)
  #
  # http://msdn.microsoft.com/en-us/library/ms632678(VS.85).aspx
  def close!
    ret, args= User32['CloseWindow', 'CL'].call(hwnd)
    ret != WIN_FALSE
  end

  # Hides the window and activates another window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def hide!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_HIDE)
    ret != WIN_FALSE
  end

  # Activates and displays a window. If the window is minimized or maximized, the system restores it to its original size and position. An application should specify this flag when displaying the window for the first time.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_normal!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOWNORMAL)
    ret != WIN_FALSE
  end

  # Activates the window and displays it as a minimized window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_minimized!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOWMINIMIZED)
    ret != WIN_FALSE
  end

  # Activates the window and displays it as a maximized window. (note: exact same as maximize!)
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_maximized!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOWMAXIMIZED)
    ret != WIN_FALSE
  end

  # Maximizes this window. (note: exact same as show_maximized!)
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def maximize!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_MAXIMIZE)
    ret != WIN_FALSE
  end

  # Displays the window in its most recent size and position. This is similar to show_normal!, except the window is not actived.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_no_activate!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOWNOACTIVATE)
    ret != WIN_FALSE
  end

  # Activates the window and displays it in its current size and position. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOW)
    ret != WIN_FALSE
  end

  # Minimizes this window and activates the next top-level window in the Z order.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def minimize!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_MINIMIZE)
    ret != WIN_FALSE
  end

  # Displays the window as a minimized window. This is similar to show_minimized!, except the window is not activated.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_min_no_active!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOWMINNOACTIVE)
    ret != WIN_FALSE
  end

  # Displays the window in its current size and position. This is similar to show!, except the window is not activated.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_na!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOWNA)
    ret != WIN_FALSE
  end

  # Activates and displays the window. If the window is minimized or maximized, the system restores it to its original size and position. An application should use this when restoring a minimized window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def restore!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_RESTORE)
    ret != WIN_FALSE
  end

  # Sets the show state based on the SW_ value specified in the STARTUPINFO structure passed to the CreateProcess function by the program that started the application. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_default!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_SHOWDEFAULT)
    ret != WIN_FALSE
  end

  # Windows 2000/XP: Minimizes the window, even if the thread that owns the window is not responding. This should only be used when minimizing windows from a different thread.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def force_minimize!
    ret, args= User32['ShowWindow', 'CLI'].call(hwnd, SW_FORCEMINIMIZE)
    ret != WIN_FALSE
  end

  # destroy! destroys the window. #destroy! sends WM_DESTROY and WM_NCDESTROY messages to the window to deactivate it and remove the keyboard focus from it. #destroy! also destroys the window's menu, flushes the thread message queue, destroys timers, removes clipboard ownership, and breaks the clipboard viewer chain (if the window is at the top of the viewer chain).
  # If the specified window is a parent or owner window, #destroy! automatically destroys the associated child or owned windows when it destroys the parent or owner window. #destroy! first destroys child or owned windows, and then it destroys the parent or owner window.
  # #destroy! also destroys modeless dialog boxes.
  #
  # http://msdn.microsoft.com/en-us/library/ms632682(VS.85).aspx
  def destroy!
    ret, args= User32['DestroyWindow', 'CI'].call(hwnd)
    ret != WIN_FALSE
  end

  # called to forcibly close the window. 
  # the argument force, if true, will force the destruction of the window if an initial attempt fails to gently close the window using WM_CLOSE. 
  # if false, only the close with WM_CLOSE is attempted
  #
  # http://msdn.microsoft.com/en-us/library/ms633492(VS.85).aspx
  def end_task!(force=false)
    ret, args= User32['EndTask', 'CICC'].call(hwnd, 0, force ? WIN_TRUE : WIN_FALSE)
    ret != WIN_FALSE
  end

  # tries to click on this Window
  # Clicking might not always work! Especially if the window is not focused (frontmost application). 
  # The BM_CLICK message might just be ignored, or maybe it will just focus the hwnd but not really click.
  def click!
    User32['PostMessage', 'ILILL'].call(hwnd, BM_CLICK, 0, 0)
    nil
  end

  # iterates over each child, yielding a WinWindow object. 
  # raises a WinWindow::NotExistsError if the window does not exist, or a WinWindow::SystemError if a System Error errors.
  # use #children to get an Enumerable object. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633494(VS.85).aspx
  #
  # For System Error Codes see http://msdn.microsoft.com/en-us/library/ms681381(VS.85).aspx
  def each_child
    raise WinWindow::NotExistsError, "Window does not exist! Cannot enumerate children." unless exists?
    enum_child_windows_callback= DL.callback('ILL') do |chwnd, lparam|
      yield WinWindow.new(chwnd)
      WIN_TRUE
    end
    begin
      ret, args= User32['EnumChildWindows', 'IIPL'].call(hwnd, enum_child_windows_callback, 0)
    ensure
      DL.remove_callback(enum_child_windows_callback)
    end
    if ret==0
      code, args=Kernel32['GetLastError','I'].call
      raise WinWindow::SystemError, "EnumChildWindows encountered an error (System Error Code #{code})"
      # actually, EnumChildWindows doesn't say anything about return value indicating error encountered.
      # Although EnumWindows does, so it seems sort of safe to assume that would apply here too. 
      # but, maybe not - so, should we raise an error here? 
    end
    nil
  end
  
  # returns an Enumerable object that can iterate over each child of this window, 
  # yielding a WinWindow object 
  #
  # may raise a WinWindow::SystemError from #each_child 
  def children
    Children.new self
  end

  # true if comparing an object of the same class with the same hwnd (integer) 
  def eql?(oth)
    oth.class==self.class && oth.hwnd==self.hwnd
  end
  alias == eql?
#  def ==(oth)
#    self.eql?(oth)
#  end

  def hash
    [self.class, self.hwnd].hash
  end

  

  # more specialized methods
  
  # Give the name of a button, or a Regexp to match it (see #child_button).
  # keeps clicking the button until the button no longer exists, or until 
  # the given block is true (ie, not false or nil)
  # Options:
  # * :interval is the length of time in seconds between each attempt (default 0.05)
  # * :set_foreground is whether the window should be activated first, since button-clicking is much more likely to fail if the window isn't focused (default true)
  # * :exception is the exception class or instance that will be raised if we can't click the button (default nil, no exception is raised, the return value indicates success/failure)
  #
  # Raises ArgumentError if invalid options are given. 
  # Raises a WinWindow::NotExistsError if the button doesn't exist, or if this window doesn't exist, or a WinWindow::SystemError if a System Error occurs (from #each_child)
  def click_child_button_try_for!(button_text, time, options={})
    handle_options!(options, {:set_foreground => true, :exception => nil, :interval => 0.05})
    button=child_button(button_text) || (raise WinWindow::NotExistsError, "Button #{button_text.inspect} not found")
    waiter_options={}
    waiter_options[:condition]=proc{!button.exists? || (block_given? && yield)}
    waiter_options.merge!(options.reject{|k,v| ![:exception, :interval].include?(k)})
    Waiter.try_for(time, waiter_options) do
      if options[:set_foreground]
        show_normal!
        really_set_foreground!
      end
      button.click!
    end
    return waiter_options[:condition].call
  end

  # returns a WinWindow that is a child of this that matches the given button_text (Regexp or #to_s-able) 
  # or nil if no such child exists. 
  # & is stripped when matching so don't include it. String comparison is case-insensitive. 
  #
  # May raise a WinWindow::SystemError from #each_child
  def child_button(button_text)
    children.detect do |child|
      child.class_name=='Button' && button_text.is_a?(Regexp) ? child.text.tr('&', '') =~ button_text : child.text.tr('&', '').downcase==button_text.to_s.tr('&', '').downcase
    end
  end
  
  # Finds a child of this window which follows a label with the given text. 
  #
  # Options:
  # - :control_class_name is the class name of the control you are looking for. Defaults to nil, which accepts any class name. 
  # - :label_class_name is the class name of the label preceding the control you are looking for. Defaults to 'Static'
  def child_control_with_preceding_label(preceding_label_text, options={})
    handle_options!(options, :control_class_name => nil, :label_class_name => "Static")
    
    prev_was_label=false
    control=self.children.detect do |child|
      ret=prev_was_label && (!options[:control_class_name] || child.class_name==options[:control_class_name])
      prev_was_label= child.class_name==options[:label_class_name] && preceding_label_text===child.text
      ret
    end
  end



  # Class methods:
  
  # Iterates over every window yielding a WinWindow object. 
  # use WinWindow::All if you want an Enumerable object. 
  #
  # Raises a WinWindow::SystemError if a System Error occurs. 
  # 
  # http://msdn.microsoft.com/en-us/library/ms633497.aspx
  #
  # For System Error Codes see http://msdn.microsoft.com/en-us/library/ms681381(VS.85).aspx
  def self.each_window
    enum_windows_callback= DL.callback('ILL') do |hwnd,lparam|
      yield WinWindow.new(hwnd)
      WIN_TRUE
    end
    begin
      ret, args=User32['EnumWindows', 'IPL'].call(enum_windows_callback, 0)
    ensure
      DL.remove_callback(enum_windows_callback)
    end
    if ret==WIN_FALSE
      code, args=Kernel32['GetLastError','I'].call
      raise WinWindow::SystemError, "EnumWindows ecountered an error (System Error Code #{code})"
    end
    nil
  end


  # returns the first window found whose text matches what is given
  #
  # May raise a WinWindow::SystemError from WinWindow.each_window
  def self.find_first_by_text(text)
    WinWindow::All.detect do |window|
      text===window.text # use triple-equals so regexps try to match, strings see if equal 
    end
  end

  # returns all WinWindow objects found whose text matches what is given
  #
  # May raise a WinWindow::SystemError from WinWindow.each_hwnd
  def self.find_all_by_text(text)
    WinWindow::All.select do |window|
      text===window.text # use triple-equals so regexps try to match, strings see if equal 
    end
  end

  # raises a WinWindow::MatchError if more than one window matching given text is found, 
  # so that you can be sure you are attaching to the right one (because it's the only one)
  #
  # May also raise a WinWindow::SystemError from WinWindow.each_window
 def self.find_only_by_text(text)
    matched=WinWindow::All.select do |window|
      text===window.text
    end
#    matched.reject! do |win|          # reject win where
#      matched.any? do |other_win|     # exists any other_win 
#        parent=other_win.parent
#        win_is_parent=false
#        while parent && !win_is_parent
#          win_is_parent ||= win==parent
#          parent=parent.parent
#        end
#        win_is_parent                  # such that win is parent of other_win
#      end
#    end
    matched.reject! do |win|           # reject any win where
      matched.any? do |other_win|      # any other_win
        parent=win.parent
        other_is_parent=false
        while parent && !other_is_parent
          other_is_parent ||= other_win==parent
          parent=parent.parent
        end
        other_is_parent                 # is its parent
      end
    end

    if matched.size != 1
      raise MatchError, "Found #{matched.size} windows matching #{text.inspect}; there should be one"
    else
      return matched.first
    end
  end

  # Enumerable object that iterates over every available window 
  #
  # May raise a WinWindow::SystemError from WinWindow.each_window
  module All
    def self.each
      WinWindow.each_window do |window|
        yield window
      end
    end
    extend Enumerable
  end

  # instantiates Enumerable objects that iterate over a WinWindow's children. 
  #
  # May raise a WinWindow::SystemError from WinWindow#each_child
  class Children
    attr_reader :parentwindow
    def initialize(parentwindow)
      @parentwindow=parentwindow
    end
    def each
      parentwindow.each_child do |cwindow|
        yield cwindow
      end
    end
    include Enumerable
  end

end
