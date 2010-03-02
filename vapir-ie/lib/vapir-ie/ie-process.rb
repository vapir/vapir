require 'win32/process'
require 'vapir-ie/ie-class'

module Watir
  class IE
    # the version string, from the registry key HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Internet Explorer\Version
    def self.version
      @@ie_version ||= begin
        require 'win32/registry'
        ::Win32::Registry::HKEY_LOCAL_MACHINE.open("SOFTWARE\\Microsoft\\Internet Explorer") do |ie_key|
          ie_key.read('Version').last
        end
        # OR: ::WIN32OLE.new("WScript.Shell").RegRead("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Internet Explorer\\Version")
      end
    end
    # the version string divided into its numeric parts returned as an array of integers 
    def self.version_parts
      @@ie_version_parts ||= IE.version.split('.').map{|part| part.to_i }
    end
    class Process
      # Watir::IE::Process.start is called by Watir::IE.new_process and does not start a new process correctly in IE8. 
      # Calling IE8 with the -nomerge option correctly starts a new process, so call Process.create with this option if 
      # IE's version is 8 
      def self.start
        program_files = ENV['ProgramFiles'] || "c:\\Program Files"
        startup_command = "#{program_files}\\Internet Explorer\\iexplore.exe"
        startup_command << " -nomerge" if ::Watir::IE.version_parts.first==8
        # maybe raise an error here if it's > 8, as not-yet-supported? who knows what incompatibilities the future will hold 
        process_info = ::Process.create('app_name' => "#{startup_command} about:blank")
        process_id = process_info.process_id
        new process_id
      end
      
      def initialize process_id
        @process_id = process_id
      end
      attr_reader :process_id
      
      def window
        Waiter.wait_until do
          IE.each do | ie |
            window = ie.ie
            hwnd = ie.hwnd
            process_id = Process.process_id_from_hwnd hwnd        
            return window if process_id == @process_id
          end
        end
      end
      
      # Returns the process id for the specifed hWnd.
      def self.process_id_from_hwnd hwnd
        pid_info = ' ' * 32
        Win32API.new('user32', 'GetWindowThreadProcessId', 'ip', 'i').
        call(hwnd, pid_info)
        process_id =  pid_info.unpack("L")[0]
      end
      
    end
  end
end