require 'vapir-ie/browser.rb'

module Vapir
  class IE
    module ClearTracks
      History =         1 << 0
      Cookies =         1 << 1
      # ?? =             1 << 2
      TemporaryFiles =  1 << 3
      FormData =        1 << 4
      StoredPasswords = 1 << 5
      # ?? =             1 << 6
      # ?? =             1 << 7
      All = (1 << 8)-1 # this is called 'All' by such references as exist, despite higher bits being meaningful too. 
      FilesAndSettingsStoredByAddOns = 1 << 12 # don't know what happened to any of bits 6 through 11. also this only seems to be documented anywhere as 4351 = 1000011111111 (= All | FilesAndSettingsStoredByAddOns)
      # apparently 1 << 13 is also meaningful, but I have no idea what it is. I have seen ClearMyTracksByProcess called with the argument 8651 = 10000111001011 (so bits 0, 1, 3, 6, 7, 8, 13)
      
      def self.clear_tracks(what)
        unless const_defined?('InetCpl')
          require 'ffi'
          define_const('InetCpl', Module.new)
          InetCpl.extend(FFI::Library)
          InetCpl.ffi_lib 'InetCpl.cpl'
          InetCpl.ffi_convention :stdcall
          InetCpl.attach_function :ClearMyTracksByProcess, :ClearMyTracksByProcessW, [:int], :void
        end
        InetCpl.ClearMyTracksByProcess(what)
      end
    end
    module ClearTracksMethods
      def clear_history
        ClearTracks.clear_tracks(ClearTracks::History)
      end
      def clear_cookies
        ClearTracks.clear_tracks(ClearTracks::Cookies)
      end
      def clear_temporary_files
        ClearTracks.clear_tracks(ClearTracks::TemporaryFiles)
      end
      def clear_all_tracks
        ClearTracks.clear_tracks(ClearTracks::All)
      end
    end
    include ClearTracksMethods
    extend ClearTracksMethods
  end
end
