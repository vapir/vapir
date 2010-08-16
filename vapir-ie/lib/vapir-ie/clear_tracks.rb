require 'vapir-ie/browser.rb'

module Vapir
  class IE
    module ClearTracks
      History = 1
      Cookies = 2
      # ?? = 4
      TemporaryFiles = 8
      FormData = 16
      StoredPasswords = 32
      All = 255
      FilesAndSettingsStoredByAddOns = 4096
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
