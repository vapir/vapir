require 'vapir-ie/browser'

module Vapir
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
      # start a new IE process and return a new Vapir::IE::Process object representing it. 
      def self.start
        require 'win32/process'
        program_files = ENV['ProgramFiles'] || "c:\\Program Files"
        startup_command = "#{program_files}\\Internet Explorer\\iexplore.exe"
        startup_command << " -nomerge" if ::Vapir::IE.version_parts.first==8
        # maybe raise an error here if it's > 8, as not-yet-supported? who knows what incompatibilities the future will hold 
        process_info = ::Process.create('app_name' => "#{startup_command} about:blank")
        process_id = process_info.process_id
        new process_id
      end
      
      # takes a process id 
      def initialize process_id
        @process_id = process_id
      end
      attr_reader :process_id
      
      # returns the browser object corresponding to the process id 
      def browser_object(options={})
        options=handle_options(options, :timeout => 32)
        ::Waiter.try_for(options[:timeout], :exception => RuntimeError.new("Could not find a browser for process #{self.inspect}")) do
          Vapir::IE.browser_objects.detect do |browser_object|
            @process_id == Process.process_id_from_hwnd(browser_object.hwnd)
          end
        end
      end
      
      # Returns the process id for the specifed hWnd.
      def self.process_id_from_hwnd hwnd
        require 'Win32API'
        pid_info = ' ' * 32
        Win32API.new('user32', 'GetWindowThreadProcessId', 'ip', 'i').
        call(hwnd, pid_info)
        process_id =  pid_info.unpack("L")[0]
      end
      
    end
  end
end