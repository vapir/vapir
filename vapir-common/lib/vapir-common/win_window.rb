require 'vapir-common/handle_options'
require 'vapir-common/waiter'

class WinWindow
  # Class that wraps useful methods of user32.dll involving windows in MS Windows (oh wonderful naming)
  #
  #--
  #
  # todo: 
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
  
  # this module exists because I've implemented this library for DL, for FFI, and for Win32::API.
  # Getting tired of changing everything everywhere, now it just takes changes to Types, 
  # and a few methods (use_lib, attach, callback) to switch to another library. 
  module AttachLib
    IsWin64=nil # TODO/FIX: detect this! 

#=begin
    # here begins the FFI version. this one needs to hack improperly into FFI's internals, bypassing its
    # broken API for #callback which doesn't set the calling convention, causing segfaults. 
    require 'ffi'

    # types that FFI recognizes
    Types=[:char, :uchar, :int, :uint, :short, :ushort, :long, :ulong, :void, :pointer, :string].inject({}) do |type_hash, type|
      type_hash[type]=type
      type_hash
    end

    def self.extended(extender)
      ffi_module=Module.new
      ffi_module.send(:extend, FFI::Library)
      extender.send(:instance_variable_set, '@ffi_module', ffi_module)
    end
    def use_lib(lib)
      @ffi_module.ffi_lib lib
      @ffi_module.ffi_convention :stdcall
    end
    # this takes arguments in the order that they're given in c/c++ so that signatures look kind of like the source
    def attach(return_type, function_name, *arg_types)
      @ffi_module.attach_function(function_name, arg_types.map{|arg_type| Types[arg_type] }, Types[return_type])
      metaclass=class << self;self;end
      ffi_module=@ffi_module
      metaclass.send(:define_method, function_name) do |*args|
        ffi_module.send(function_name, *args)
      end
      nil
    end
    # this takes arguments like #attach, but with a name for the callback's type on the front. 
    def callback(callback_type_name, return_type, callback_method_name, *arg_types)
      
      Types[callback_type_name]=callback_type_name
      
      #@ffi_module.callback(callback_type_name, arg_types.map{|type| Types[type]}, Types[return_type])
      
      # we do not call @ffi_module.callback here, because it is broken. we need to pass the convention ourselves in the options hash. 
      # this is adapted from: http://gist.github.com/256660
      options={}
      types=Types
      @ffi_module.instance_eval do
        options[:convention] = defined?(@ffi_convention) ? @ffi_convention : :default
        options[:enums] = @ffi_enums if defined?(@ffi_enums)

        cb = FFI::CallbackInfo.new(find_type(types[return_type]), arg_types.map{|e| find_type(types[e]) }, options)

        @ffi_callbacks = Hash.new unless defined?(@ffi_callbacks)
        @ffi_callbacks[callback_type_name] = cb
      end
      #options[:convention] = @ffi_module.instance_variable_defined?('@ffi_convention') ? @ffi_module.instance_variable_get('@ffi_convention') : :default
      #options[:enums] = @ffi_module.instance_variable_get('@ffi_enums') if @ffi_module.instance_variable_defined?('@ffi_enums')
      #unless @ffi_module.instance_variable_defined?('@ffi_callbacks')
      #  @ffi_module.instance_variable_set('@ffi_callbacks', cb)
      #end
      
      # perform some hideous class_eval'ing to dynamically define the callback method such that it will take a block 
      metaclass=class << self;self;end

      # FFI just takes the block itself. don't need anything fancy here. 
      metaclass.class_eval("def #{callback_method_name}(&block)
        block
      end
      def remove_#{callback_method_name}(callback_method)
        # FFI has no support for removing callbacks? 
        nil
      end")
      # don't use define_method as this will be called from an ensure block which segfaults ruby 1.9.1. see http://redmine.ruby-lang.org/issues/show/2728
      #metaclass.send(:define_method, "remove_"+callback_method_name.to_s) do |callback_method|
      #  nil
      #end
      nil
    end
#=end
=begin
    # here begins the Win32::API version. this one doesn't work because of a hard-coded limit on 
    # callbacks in win32/api.c combined with a lack of any capacity to remove any callbacks. 
    require 'win32/api'

    # basic types that Win32::API recognizes
    Types={ :char => 'I', # no 8-bit type in Win32::API?
            :uchar => 'I', # no unsigned types in Win32::API?
            :int => 'I',
            :uint => 'I',
            :long => 'L',
            :ulong => 'L',
            :void => 'V',
            :pointer => 'P',
            :callback => 'K',
            :string => 'P', # 'S' works here on mingw32, but not on mswin32 
          }
    
    def use_lib(lib)
      @lib=lib
    end
    # this takes arguments in the order that they're given in c/c++ so that signatures look kind of like the source
    def attach(return_type, function_name, *arg_types)
      the_function=Win32::API.new(function_name.to_s, arg_types.map{|arg_type| Types[arg_type] }.join(''), Types[return_type], @lib)
      metaclass=class << self;self;end
      metaclass.send(:define_method, function_name) do |*args|
        the_function.call(*args)
      end
      nil
    end
    # this takes arguments like #attach, but with a name for the callback's type on the front. 
    def callback(callback_type_name, return_type, callback_method_name, *arg_types)
      Types[callback_type_name]=Types[:callback]
      
      # perform some hideous class_eval'ing to dynamically define the callback method such that it will take a block 
      metaclass=class << self;self;end
      metaclass.class_eval("def #{callback_method_name}(&block)
        #{callback_method_name}_with_arg_stuff_in_scope(block)
      end")
      types=Types
      metaclass.send(:define_method, callback_method_name.to_s+"_with_arg_stuff_in_scope") do |block|
        return Win32::API::Callback.new(arg_types.map{|t| types[t]}.join(''), types[return_type], &block)
      end
      def remove_#{callback_method_name}(callback_method)
        # Win32::API has no support for removing callbacks? 
        nil
      end")
      # don't use define_method as this will be called from an ensure block which segfaults ruby 1.9.1. see http://redmine.ruby-lang.org/issues/show/2728
      #metaclass.send(:define_method, "remove_"+callback_method_name.to_s) do |callback_method|
      #  nil
      #end
      nil
    end
=end
    def self.add_type(hash)
      hash.each_pair do |key, value|
        unless Types.key?(value)
          raise "unrecognized type #{value.inspect}"
        end
        Types[key]=Types[value]
      end
    end

  end
  Types=AttachLib::Types
  # types from http://msdn.microsoft.com/en-us/library/aa383751%28VS.85%29.aspx
  AttachLib.add_type :buffer_in => :string
  AttachLib.add_type :buffer_out => :pointer
  AttachLib.add_type :HWND     => :ulong # this is a lie. really void*, but easier to deal with as a long. 
  AttachLib.add_type :HDC      => :pointer
  AttachLib.add_type :LPSTR    => :pointer # char*
  AttachLib.add_type :LPWSTR   => :pointer # wchar_t*
  AttachLib.add_type :LPCSTR   => :buffer_in # const char*
  AttachLib.add_type :LPCWSTR  => :pointer # const wchar_t*
  AttachLib.add_type :LONG_PTR => (AttachLib::IsWin64 ? :int64 : :long) # TODO/FIX: there is no :int64 type defined on Win32::API
  AttachLib.add_type :LRESULT  => :LONG_PTR
  AttachLib.add_type :WPARAM   => (AttachLib::IsWin64 ? :uint64 : :uint) # TODO/FIX: no :uint64 on Win3::API
  AttachLib.add_type :LPARAM   => :pointer #:LONG_PTR # this is supposed to be a LONG_PTR (a long type for pointer precision), but casting around is annoying - just going to use it as a pointer. 
  AttachLib.add_type :BOOL     => :int
  AttachLib.add_type :BYTE     => :uchar
  AttachLib.add_type :WORD     => :ushort
  AttachLib.add_type :DWORD    => :ulong
  AttachLib.add_type :LPRECT   => :pointer
  module WinUser
    extend AttachLib
    use_lib 'user32'

    attach :int, :GetWindowTextA, :HWND, :LPSTR, :int
    attach :int, :GetWindowTextW, :HWND, :LPWSTR, :int
    attach :int, :GetWindowTextLengthA, :HWND
    attach :int, :GetWindowTextLengthW, :HWND
    attach :LRESULT, :SendMessageA, :HWND, :uint, :WPARAM, :LPARAM
    attach :LRESULT, :SendMessageW, :HWND, :uint, :WPARAM, :LPARAM
    attach :BOOL, :PostMessageA, :HWND, :uint, :WPARAM, :LPARAM
    attach :BOOL, :PostMessageW, :HWND, :uint, :WPARAM, :LPARAM
    attach :BOOL, :SetWindowTextA, :HWND, :LPCSTR
    attach :BOOL, :SetWindowTextW, :HWND, :LPCWSTR
    attach :HWND, :GetWindow, :HWND, :uint
    attach :HWND, :GetLastActivePopup, :HWND
    attach :HWND, :GetTopWindow, :HWND
    attach :HWND, :GetParent, :HWND
    attach :HWND, :SetParent, :HWND, :HWND
    attach :BOOL, :IsChild, :HWND, :HWND
    attach :BOOL, :IsHungAppWindow, :HWND
    attach :BOOL, :IsWindow, :HWND
    attach :BOOL, :IsWindowVisible, :HWND
    attach :BOOL, :IsIconic, :HWND
    attach :BOOL, :SetForegroundWindow, :HWND
    attach :BOOL, :BringWindowToTop, :HWND
    attach :BOOL, :CloseWindow, :HWND
    attach :BOOL, :DestroyWindow, :HWND
    attach :int, :GetClassNameA, :HWND, :LPSTR, :int
    attach :int, :GetClassNameW, :HWND, :LPWSTR, :int
    attach :uint, :RealGetWindowClassA, :HWND, :LPSTR, :uint
    attach :uint, :RealGetWindowClassW, :HWND, :LPWSTR, :uint
    attach :void, :SwitchToThisWindow, :HWND, :BOOL
    attach :BOOL, :LockSetForegroundWindow, :uint
    attach :uint, :MapVirtualKeyA, :uint, :uint
    attach :uint, :MapVirtualKeyW, :uint, :uint
    attach :void, :keybd_event, :BYTE, :BYTE, :DWORD, :pointer
    attach :BOOL, :ShowWindow, :HWND, :int
    attach :BOOL, :EndTask, :HWND, :BOOL, :BOOL
    attach :HWND, :GetForegroundWindow
    attach :HWND, :GetDesktopWindow
    attach :HDC, :GetDC, :HWND
    attach :HDC, :GetWindowDC, :HWND
    attach :int, :ReleaseDC, :HWND, :HDC
    
    class Rect < FFI::Struct
      layout :left, :long,
        :top, :long,
        :right, :long,
        :bottom, :long
    end
    attach :BOOL, :GetWindowRect, :HWND, :LPRECT
    attach :BOOL, :GetClientRect, :HWND, :LPRECT
    
    callback :WNDENUMPROC, :BOOL, :window_enum_callback, :HWND, :LPARAM
    attach :BOOL, :EnumWindows, :WNDENUMPROC, :LPARAM
    attach :BOOL, :EnumChildWindows, :HWND, :WNDENUMPROC, :LPARAM
  end
  AttachLib.add_type :SIZE_T => (AttachLib::IsWin64 ? :uint64 : :ulong)

  module WinKernel
    extend AttachLib
    use_lib 'kernel32'
    attach :DWORD, :GetLastError
    attach :DWORD, :FormatMessageA, :DWORD, :pointer, :DWORD, :DWORD, :LPSTR, :DWORD
    attach :DWORD, :FormatMessageW, :DWORD, :pointer, :DWORD, :DWORD, :LPWSTR, :DWORD

    attach :pointer, :GlobalAlloc, :uint, :SIZE_T
    attach :pointer, :GlobalFree, :pointer
    attach :pointer, :GlobalLock, :pointer
    attach :pointer, :GlobalUnlock, :pointer
  end
  AttachLib.add_type :HGDIOBJ => :pointer
  AttachLib.add_type :HBITMAP => :pointer
  AttachLib.add_type :LPBITMAPINFO => :pointer
  module WinGDI
    extend AttachLib
    use_lib 'gdi32'
    attach :HDC, :CreateCompatibleDC, :HDC
    attach :BOOL, :DeleteDC, :HDC
    attach :int, :GetDeviceCaps, :HDC, :int
    attach :HBITMAP, :CreateCompatibleBitmap, :HDC, :int, :int
    attach :HGDIOBJ, :SelectObject, :HDC, :HGDIOBJ
    attach :BOOL, :DeleteObject, :HGDIOBJ
    attach :BOOL, :BitBlt, :HDC, :int, :int, :int, :int, :HDC, :int, :int, :DWORD
    attach :int, :GetDIBits, :HDC, :HBITMAP, :uint, :uint, :pointer, :LPBITMAPINFO, :uint

    class BITMAPINFOHEADER < FFI::Struct
      layout(
        :Size, :int32,
        :Width, :int32,
        :Height, :int32,
        :Planes, :int16,
        :BitCount, :int16,
        :Compression, :int32,
        :SizeImage, :int32,
        :XPelsPerMeter, :int32,
        :YPelsPerMeter, :int32,
        :ClrUsed, :int32,
        :ClrImportant, :int32
      )
    end
    class BITMAPFILEHEADER < FFI::Struct
      layout(
        :Type, :int16, 0,
        :Size, :int32, 2,
        :Reserved1, :int16, 6,
        :Reserved2, :int16, 8,
        :OffBits, :int32, 10
      )
    end
    # for some reason size is returned as 16; should be 14
    class << FFI::Struct
      def real_size
        layout.fields.inject(0) do |sum, field|
          sum+field.size
        end
      end
    end
  end

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
    raise ArgumentError, "hwnd must be an integer greater than 0; got #{hwnd.inspect} (#{hwnd.class})" unless hwnd.is_a?(Fixnum) && hwnd > 0
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
    buff="\001"*buff_size
    len= WinUser.GetWindowTextA(hwnd, buff, buff_size)
    @text=buff[0...len]
  end

  # length of the window text, see #text
  # similar to #text, cannot retrieve the text of a control in another application - see #retrieve_text, #retrieve_text_length
  #
  # http://msdn.microsoft.com/en-us/library/ms633521(VS.85).aspx
  def text_length
    len= WinUser.GetWindowTextLengthA(hwnd)
    len
  end

  # This is similar to #text
  # that one is GetWindowText(hwnd) 
  # this one is SendMessage(hwnd, WM_GETTEXT)
  # differences are documented here: http://msdn.microsoft.com/en-us/magazine/cc301438.aspx
  # and here: http://blogs.msdn.com/oldnewthing/archive/2003/08/21/54675.aspx
  def retrieve_text
    buff_size=retrieve_text_length+1
    buff=" "*buff_size
    len= WinUser.SendMessageA(hwnd, WM_GETTEXT, buff_size, buff)
    @text=buff[0...len]
  end
  
  # similar to #text_length; differences between that and this are the same as between #text and #retrieve_text 
  def retrieve_text_length
    len= WinUser.SendMessageA(hwnd, WM_GETTEXTLENGTH, 0, nil)
    len
  end

  # changes the text of the specified window's title bar (if it has one). If the specified window is a control, the text of the control is changed. 
  # However, #set_text! cannot change the text of a control in another application (see #send_set_text!) 
  #
  # http://msdn.microsoft.com/en-us/library/ms633546(VS.85).aspx
  def set_text!(text)
    set=WinUser.SetWindowTextA(hwnd, text)
    set != WIN_FALSE
  end

  # sets text by sending WM_SETTEXT message. this different than #set_text! in the same way that
  # #retrieve_text is different than #text
  def send_set_text!(text)
    ret=WinUser.SendMessageA(hwnd, WM_SETTEXT, 0, text.dup)
    nil
  end

  # The retrieved handle identifies the enabled popup window owned by the specified window 
  # (the search uses the first such window found using GW_HWNDNEXT); otherwise, if there 
  # are no enabled popup windows, nil is returned. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633515(VS.85).aspx
  def enabled_popup
    popup_hwnd=WinUser.GetWindow(hwnd, GW_ENABLEDPOPUP)
    @enabled_popup= popup_hwnd > 0 && popup_hwnd != self.hwnd ? self.class.new(popup_hwnd) : nil
  end

  # The retrieved handle identifies the specified window's owner window, if any. 
  # 
  # http://msdn.microsoft.com/en-us/library/ms633515(VS.85).aspx
  def owner
    owner_hwnd=WinUser.GetWindow(hwnd, GW_OWNER)
    @owner= owner_hwnd > 0 ? self.class.new(owner_hwnd) : nil
  end
  
  # Retrieves the parent window. This does not include the owner, as it does with #parent
  # 
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  def ancestor_parent
    ret_hwnd=WinUser.GetAncestor(hwnd, GA_PARENT)
    @ancestor_parent= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # Retrieves the root window by walking the chain of parent windows.
  #
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  def ancestor_root
    ret_hwnd=WinUser.GetAncestor(hwnd, GA_ROOT)
    @ancestor_root= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # Retrieves the owned root window by walking the chain of parent and owner windows returned by GetParent. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  def ancestor_root_owner
    ret_hwnd=WinUser.GetAncestor(hwnd, GA_ROOTOWNER)
    @ancestor_root_owner= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # determines which pop-up window owned by this window was most recently active
  #
  # http://msdn.microsoft.com/en-us/library/ms633507(VS.85).aspx
  def last_active_popup
    ret_hwnd=WinUser.GetLastActivePopup(hwnd)
    @last_active_popup= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end
  
  # examines the Z order of the child windows associated with self and retrieves a handle to the child window at the top of the Z order
  #
  # http://msdn.microsoft.com/en-us/library/ms633514(VS.85).aspx
  def top_window
    ret_hwnd= WinUser.GetTopWindow(hwnd)
    @top_window= ret_hwnd > 0 ? self.class.new(ret_hwnd) : nil
  end

  # retrieves a handle to this window's parent or owner
  #
  # http://msdn.microsoft.com/en-us/library/ms633510(VS.85).aspx
  def parent
    parent_hwnd=WinUser.GetParent(hwnd)
    @parent= parent_hwnd > 0 ? self.class.new(parent_hwnd) : nil
  end

  # changes the parent window of this child window
  #
  # http://msdn.microsoft.com/en-us/library/ms633541(VS.85).aspx
  def set_parent!(parent)
    parent_hwnd= parent.is_a?(self.class) ? parent.hwnd : parent
    new_parent=WinUser.SetParent(hwnd, parent_hwnd)
    new_parent > 0 ? self.class.new(new_parent) : nil
  end

  # tests whether a window is a child window or descendant window of a specified parent window. A child window is the direct descendant of a specified parent window if that parent window is in the chain of parent windows; the chain of parent windows leads from the original overlapped or pop-up window to the child window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633524(VS.85).aspx
  def child_of?(parent)
    parent_hwnd= parent.is_a?(self.class) ? parent.hwnd : parent
    child=WinUser.IsChild(parent_hwnd, hwnd)
    child!=WIN_FALSE
  end

  # determine if Microsoft Windows considers that a specified application is not responding. An application is considered to be not responding if it is not waiting for input, is not in startup processing, and has not called PeekMessage within the internal timeout period of 5 seconds. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633526.aspx
  def hung_app?
    hung=WinUser.IsHungAppWindow(hwnd)
    hung != WIN_FALSE
  end

  # retrieves the name of the class to which this window belongs
  #
  # http://msdn.microsoft.com/en-us/library/ms633582(VS.85).aspx
  def class_name
    buff_size=256
    buff=" "*buff_size
    len=WinUser.GetClassNameA(hwnd, buff, buff_size)
    @class_name=buff.to_s[0...len]
  end
  
  # retrieves a string that specifies the window type
  #
  # http://msdn.microsoft.com/en-us/library/ms633538(VS.85).aspx
  def real_class_name
    buff_size=256
    buff=" "*buff_size
    len=RealGetWindowClassA(hwnd, buff, buff_size)
    @real_class_name=buff.to_s[0...len]
  end
  
  # determines whether the specified window handle identifies an existing window
  #
  # http://msdn.microsoft.com/en-us/library/ms633528(VS.85).aspx
  def exists?
    ret=WinUser.IsWindow(hwnd)
    ret != WIN_FALSE
  end

  # visibility state of the specified window
  #
  # http://msdn.microsoft.com/en-us/library/ms633530(VS.85).aspx
  def visible?
    ret=WinUser.IsWindowVisible(hwnd)
    ret != WIN_FALSE
  end

  # whether the window is minimized (iconic).
  #
  # http://msdn.microsoft.com/en-us/library/ms633527(VS.85).aspx
  def iconic?
    ret=WinUser.IsIconic(hwnd)
    ret != WIN_FALSE
  end
  alias minimized? iconic?
  
  # switch focus and bring to the foreground
  # the argument alt_tab, if true, indicates that the window is being switched to using the Alt/Ctl+Tab key sequence. This argument should be false otherwise.
  #
  # http://msdn.microsoft.com/en-us/library/ms633553(VS.85).aspx
  def switch_to!(alt_tab=false)
    WinUser.SwitchToThisWindow(hwnd, alt_tab ? WIN_TRUE : WIN_FALSE)
  end

  # puts the thread that created the specified window into the foreground and activates the window. Keyboard input is directed to the window, and various visual cues are changed for the user. The system assigns a slightly higher priority to the thread that created the foreground window than it does to other threads.
  # If the window was brought to the foreground, the return value is true.
  # If the window was not brought to the foreground, the return value is false.
  #
  # http://msdn.microsoft.com/en-us/library/ms633539(VS.85).aspx
  def set_foreground!
    ret= WinUser.SetForegroundWindow(hwnd)
    ret != WIN_FALSE
  end
  
  def foreground?
    self==self.class.foreground_window
  end

  
  LSFW_LOCK = 1
  LSFW_UNLOCK = 2
  def self.lock_set_foreground_window
    ret= WinUser.LockSetForegroundWindow(LSFW_LOCK)
    ret != WIN_FALSE
  end
  def self.unlock_set_foreground_window
    ret= WinUser.LockSetForegroundWindow(LSFW_UNLOCK)
    ret != WIN_FALSE
  end

  VK_MENU=0x12
  KEYEVENTF_KEYDOWN=0x0
  KEYEVENTF_KEYUP=0x2
  # really sets this to be the foreground window. 
  # restores the window if it's iconic. 
  # attempts to circumvent a lock disabling calls made by set_foreground!
  # then calls set_foreground!, which should then work with that lock disabled. 
  # tries this for a few seconds, checking if it was successful.
  #
  # if you want it to raise an exception if it can't set the foreground window, 
  # pass :error => true (default is false) 
  def really_set_foreground!(options={})
    options=handle_options(options, :error => false)
    try_harder=false
    mapped_vk_menu=WinUser.MapVirtualKeyA(VK_MENU, 0)
    ::Waiter.try_for(2, :exception => (options[:error] && WinWindow::Error.new("Failed to set foreground window"))) do
      if iconic?
        restore!
      end
      if try_harder
        # Simulate two single ALT keystrokes in order to deactivate lock on SetForeGroundWindow before we call it.
        # See LockSetForegroundWindow, http://msdn.microsoft.com/en-us/library/ms633532(VS.85).aspx
        # also keybd_event, see http://msdn.microsoft.com/en-us/library/ms646304(VS.85).aspx
        #
        # this idea is taken from AutoIt's setforegroundwinex.cpp in SetForegroundWinEx::Activate(HWND hWnd)
        # keybd_event((BYTE)VK_MENU, MapVirtualKey(VK_MENU, 0), 0, 0);
        # keybd_event((BYTE)VK_MENU, MapVirtualKey(VK_MENU, 0), KEYEVENTF_KEYUP, 0);
        2.times do
          ret=WinUser.keybd_event(VK_MENU, mapped_vk_menu, KEYEVENTF_KEYDOWN, nil)
          ret=WinUser.keybd_event(VK_MENU, mapped_vk_menu, KEYEVENTF_KEYUP, nil)
        end
      else
        try_harder=true
      end
      set_foreground!
      foreground?
    end
  end

  # brings the window to the top of the Z order. If the window is a top-level window, it is activated. If the window is a child window, the top-level parent window associated with the child window is activated.
  #
  # http://msdn.microsoft.com/en-us/library/ms632673(VS.85).aspx
  def bring_to_top!
    ret=WinUser.BringWindowToTop(hwnd)
    ret != WIN_FALSE
  end
  
  # minimizes this window (but does not destroy it)
  # (why is it called close? I don't know)
  #
  # http://msdn.microsoft.com/en-us/library/ms632678(VS.85).aspx
  def close!
    ret=WinUser.CloseWindow(hwnd)
    ret != WIN_FALSE
  end

  # Hides the window and activates another window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def hide!
    ret=WinUser.ShowWindow(hwnd, SW_HIDE)
    ret != WIN_FALSE
  end

  # Activates and displays a window. If the window is minimized or maximized, the system restores it to its original size and position. An application should specify this flag when displaying the window for the first time.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_normal!
    ret=WinUser.ShowWindow(hwnd, SW_SHOWNORMAL)
    ret != WIN_FALSE
  end

  # Activates the window and displays it as a minimized window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_minimized!
    ret=WinUser.ShowWindow(hwnd, SW_SHOWMINIMIZED)
    ret != WIN_FALSE
  end

  # Activates the window and displays it as a maximized window. (note: exact same as maximize!)
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_maximized!
    ret=WinUser.ShowWindow(hwnd, SW_SHOWMAXIMIZED)
    ret != WIN_FALSE
  end

  # Maximizes this window. (note: exact same as show_maximized!)
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def maximize!
    ret=WinUser.ShowWindow(hwnd, SW_MAXIMIZE)
    ret != WIN_FALSE
  end

  # Displays the window in its most recent size and position. This is similar to show_normal!, except the window is not actived.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_no_activate!
    ret=WinUser.ShowWindow(hwnd, SW_SHOWNOACTIVATE)
    ret != WIN_FALSE
  end

  # Activates the window and displays it in its current size and position. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show!
    ret=WinUser.ShowWindow(hwnd, SW_SHOW)
    ret != WIN_FALSE
  end

  # Minimizes this window and activates the next top-level window in the Z order.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def minimize!
    ret=WinUser.ShowWindow(hwnd, SW_MINIMIZE)
    ret != WIN_FALSE
  end

  # Displays the window as a minimized window. This is similar to show_minimized!, except the window is not activated.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_min_no_active!
    ret=WinUser.ShowWindow(hwnd, SW_SHOWMINNOACTIVE)
    ret != WIN_FALSE
  end

  # Displays the window in its current size and position. This is similar to show!, except the window is not activated.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_na!
    ret=WinUser.ShowWindow(hwnd, SW_SHOWNA)
    ret != WIN_FALSE
  end

  # Activates and displays the window. If the window is minimized or maximized, the system restores it to its original size and position. An application should use this when restoring a minimized window.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def restore!
    ret=WinUser.ShowWindow(hwnd, SW_RESTORE)
    ret != WIN_FALSE
  end

  # Sets the show state based on the SW_ value specified in the STARTUPINFO structure passed to the CreateProcess function by the program that started the application. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def show_default!
    ret=WinUser.ShowWindow(hwnd, SW_SHOWDEFAULT)
    ret != WIN_FALSE
  end

  # Windows 2000/XP: Minimizes the window, even if the thread that owns the window is not responding. This should only be used when minimizing windows from a different thread.
  #
  # http://msdn.microsoft.com/en-us/library/ms633548(VS.85).aspx
  def force_minimize!
    ret=WinUser.ShowWindow(hwnd, SW_FORCEMINIMIZE)
    ret != WIN_FALSE
  end

  # destroy! destroys the window. #destroy! sends WM_DESTROY and WM_NCDESTROY messages to the window to deactivate it and remove the keyboard focus from it. #destroy! also destroys the window's menu, flushes the thread message queue, destroys timers, removes clipboard ownership, and breaks the clipboard viewer chain (if the window is at the top of the viewer chain).
  # If the specified window is a parent or owner window, #destroy! automatically destroys the associated child or owned windows when it destroys the parent or owner window. #destroy! first destroys child or owned windows, and then it destroys the parent or owner window.
  # #destroy! also destroys modeless dialog boxes.
  #
  # http://msdn.microsoft.com/en-us/library/ms632682(VS.85).aspx
  def destroy!
    ret=WinUser.DestroyWindow(hwnd)
    ret != WIN_FALSE
  end

  # called to forcibly close the window. 
  # the argument force, if true, will force the destruction of the window if an initial attempt fails to gently close the window using WM_CLOSE. 
  # if false, only the close with WM_CLOSE is attempted
  #
  # http://msdn.microsoft.com/en-us/library/ms633492(VS.85).aspx
  def end_task!(force=false)
    ret=WinUser.EndTask(hwnd, 0, force ? WIN_TRUE : WIN_FALSE)
    ret != WIN_FALSE
  end
  
  # sends notification that the window should close. 
  # returns nil (we get no indication of success or failure). 
  #
  # http://msdn.microsoft.com/en-us/library/ms632617%28VS.85%29.aspx
  def send_close!
    buff_size=0
    buff=""
    len=WinUser.SendMessageA(hwnd, WM_CLOSE, buff_size, buff)
    nil
  end

  # tries to click on this Window
  # Clicking might not always work! Especially if the window is not focused (frontmost application). 
  # The BM_CLICK message might just be ignored, or maybe it will just focus the hwnd but not really click.
  def click!
    WinUser.PostMessageA(hwnd, BM_CLICK, 0, nil)
  end

  # Returns a Rect struct with members left, top, right, and bottom indicating the dimensions of the bounding rectangle of the specified window. The dimensions are given in screen coordinates that are relative to the upper-left corner of the screen.
  #
  # http://msdn.microsoft.com/en-us/library/ms633519%28VS.85%29.aspx
  def window_rect
    rect=WinUser::Rect.new
    ret=WinUser.GetWindowRect(hwnd, rect)
    if ret==WIN_FALSE
      self.class.system_error "GetWindowRect"
    else
      rect
    end
  end
  # Returns a Rect struct with members left, top, right, and bottom indicating the coordinates of a window's client area. The client coordinates specify the upper-left and lower-right corners of the client area. Because client coordinates are relative to the upper-left corner of a window's client area, the coordinates of the upper-left corner are (0,0).
  #
  # http://msdn.microsoft.com/en-us/library/ms633503%28VS.85%29.aspx
  def client_rect
    rect=WinUser::Rect.new
    ret=WinUser.GetClientRect(hwnd, rect)
    if ret==WIN_FALSE
      self.class.system_error "GetClientRect"
    else
      rect
    end
  end
  
  SRCCOPY = 0xCC0020
  DIB_RGB_COLORS = 0x0
  GMEM_FIXED = 0x0
  SM_CXSCREEN=
  SM_CYSCREEN=
  
  # Creates a bitmap image of this window (a screenshot). 
  # Returns the bitmap as represented by three FFI objects: a BITMAPFILEHEADER, a BITMAPINFOHEADER, and a
  # pointer to actual bitmap data. 
  # See also #capture_to_bmp_blob and #capture_to_bmp_file - probably more useful to the user than this method. 
  #
  # takes an options hash:
  # - :dc => what device context to use 
  #     :client - captures the client area, which excludes window trimmings like title bar, resize bars, etc.
  #     :window (default) - capturse the window area, including window trimmings. 
  # - :set_foreground => whether to try to set this to be the foreground 
  #     true - calls to #set_foreground
  #     false - doesn't call to any functions to set this to be the foreground
  #     :really (default) - calls to #really_set_foreground. this is the default because really being 
  #       in the foreground is rather important when taking a screenshot. 
  def capture_to_bmp_structs(options={})
    options=handle_options(options, :dc => :window, :set_foreground => :really)
    case options[:set_foreground]
    when :really
      really_set_foreground!
    when true
      set_foreground!
    when false,nil
    else
      raise ArgumentError, ":set_foreground option is invalid. expected values are :really, true, or false/nil. received #{options[:set_foreground]} (#{options[:set_foreground].class})"
    end
    if options[:set_foreground]
      sleep 0.2 # if setting foreground, sleep a tick - sometimes it still hasn't show up even when it is the foreground window; sometimes it's still only partway-drawn 
    end
    case options[:dc]
    when :client
      rect=self.client_rect
      dc=WinUser.GetDC(hwnd) || system_error("GetDC")
    when :window
      rect=self.window_rect
      dc=WinUser.GetWindowDC(hwnd) || system_error("GetWindowDC")
    else
      raise ArgumentError, ":dc option is invalid. expected values are :client or :window; received #{options[:dc]} (#{options[:dc].class})"
    end
    width=rect[:right]-rect[:left]
    height=rect[:bottom]-rect[:top]
    begin
      dc_mem = WinGDI.CreateCompatibleDC(dc) || system_error("CreateCompatibleDC")
      begin
        bmp = WinGDI.CreateCompatibleBitmap(dc, width, height) || system_error("CreateCompatibleBitmap")
        begin
          WinGDI.SelectObject(dc_mem, bmp) || system_error("SelectObject")
          WinGDI.BitBlt(dc_mem, 0, 0, width, height, dc, 0, 0, SRCCOPY) || system_error("BitBlt")
          
          bytes_per_pixel=3
          
          bmp_info=WinGDI::BITMAPINFOHEADER.new
          { :Size => WinGDI::BITMAPINFOHEADER.real_size, # 40
            :Width => width,
            :Height => height,
            :Planes => 1,
            :BitCount => bytes_per_pixel*8,
            :Compression => 0,
            :SizeImage => 0,
            :XPelsPerMeter => 0,
            :YPelsPerMeter => 0,
            :ClrUsed => 0,
            :ClrImportant => 0,
          }.each_pair do |key,val|
            bmp_info[key]=val
          end
          bmp_row_size=width*bytes_per_pixel
          bmp_row_size+=bmp_row_size%4 # row size must be a multiple of 4 (size of a dword)
          bmp_size=bmp_row_size*height
          
          bits=FFI::MemoryPointer.new(1, bmp_size)
          
          WinGDI.GetDIBits(dc_mem, bmp, 0, height, bits, bmp_info, DIB_RGB_COLORS) || system_error("GetDIBits")
          
          bmp_file_header=WinGDI::BITMAPFILEHEADER.new
          { :Type => 'BM'.unpack('S').first, # must be 'BM'
            :Size => WinGDI::BITMAPFILEHEADER.real_size + WinGDI::BITMAPINFOHEADER.real_size + bmp_size,
            :Reserved1 => 0,
            :Reserved2 => 0,
            :OffBits => WinGDI::BITMAPFILEHEADER.real_size + WinGDI::BITMAPINFOHEADER.real_size
          }.each_pair do |key,val|
            bmp_file_header[key]=val
          end
          return [bmp_file_header, bmp_info, bits]
        ensure
          WinGDI.DeleteObject(bmp)
        end
      ensure
        WinGDI.DeleteDC(dc_mem)
      end
    ensure
      WinUser.ReleaseDC(hwnd, dc)
    end
  end
  # captures this window to a bitmap image (a screenshot). 
  # Returns the bitmap as represented by a blob (a string) of bitmap data, including the BITMAPFILEHEADER, 
  # BITMAPINFOHEADER, and data. This can be written directly to a file (though if you want that, 
  # #capture_to_bmp_file is probably what you want), or passed to ImageMagick, or whatever you like. 
  #
  # takes an options hash. see the documentation on #capture_to_bmp_structs for what options are accepted. 
  def capture_to_bmp_blob(options={})
    capture_to_bmp_structs(options).map do |struct|
      if struct.is_a?(FFI::Pointer)
        ptr=struct
        size=ptr.size
      else
        ptr=struct.to_ptr
        size=struct.class.real_size
      end
      ptr.get_bytes(0, size)
    end.join("")
  end
  
  # captures this window to a bitmap image (a screenshot). 
  # stores the bitmap to a filename specified in the first argument. 
  #
  # takes an options hash. see the documentation on #capture_to_bmp_structs for what options are accepted. 
  def capture_to_bmp_file(filename, options={})
    File.open(filename, 'wb') do |file|
      file.write(capture_to_bmp_blob(options))
    end
  end

  private
  FORMAT_MESSAGE_FROM_SYSTEM=0x00001000
  # get the last error from GetLastError, format an error message with FormatMessage, and raise a WinWindow::SystemError 
  def self.system_error(function)
    code=WinKernel.GetLastError
    
    dwFlags=FORMAT_MESSAGE_FROM_SYSTEM
    buff_size=65535
    buff="\1"*buff_size
    len=WinKernel.FormatMessageA(dwFlags, nil, code, 0, buff, buff_size)
    system_error_message=buff[0...len]
    raise WinWindow::SystemError, "#{function} encountered an error\nSystem Error Code #{code}\n"+system_error_message
  end
  public
    
  # iterates over each child, yielding a WinWindow object. 
  # raises a WinWindow::NotExistsError if the window does not exist, or a WinWindow::SystemError if a System Error errors.
  # use #children to get an Enumerable object. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633494(VS.85).aspx
  #
  # For System Error Codes see http://msdn.microsoft.com/en-us/library/ms681381(VS.85).aspx
  def each_child
    raise WinWindow::NotExistsError, "Window does not exist! Cannot enumerate children." unless exists?
    enum_child_windows_callback= WinUser.window_enum_callback do |chwnd, lparam|
      yield WinWindow.new(chwnd)
      WIN_TRUE
    end
    begin
      ret=WinUser.EnumChildWindows(hwnd, enum_child_windows_callback, nil)
    ensure
      WinUser.remove_window_enum_callback(enum_child_windows_callback)
    end
    if ret==0
      self.class.system_error("EnumChildWindows")
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
    options=handle_options(options, {:set_foreground => true, :exception => nil, :interval => 0.05})
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
    options=handle_options(options, :control_class_name => nil, :label_class_name => "Static")
    
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
    enum_windows_callback= WinUser.window_enum_callback do |hwnd,lparam|
      yield WinWindow.new(hwnd)
      WIN_TRUE
    end
    begin
      ret=WinUser.EnumWindows(enum_windows_callback, nil)
    ensure
      WinUser.remove_window_enum_callback(enum_windows_callback)
    end
    if ret==WIN_FALSE
      system_error "EnumWindows"
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
  
  # Returns a WinWindow representing the current foreground window (the window with which the user is currently working).
  #
  # http://msdn.microsoft.com/en-us/library/ms633505%28VS.85%29.aspx
  def self.foreground_window
    hwnd=WinUser.GetForegroundWindow
    if hwnd == 0
      nil
    else
      self.new(hwnd)
    end
  end
  
  # Returns a WinWindow representing the desktop window. The desktop window covers the entire screen. The desktop window is the area on top of which other windows are painted. 
  #
  # http://msdn.microsoft.com/en-us/library/ms633504%28VS.85%29.aspx
  def self.desktop_window
    hwnd=WinUser.GetDesktopWindow
    if hwnd == 0
      nil
    else
      self.new(hwnd)
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
