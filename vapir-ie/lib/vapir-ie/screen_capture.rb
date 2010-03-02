module Vapir
  module ScreenCapture
    def screen_capture(filename , active_window_only=false, save_as_bmp=false)
      raise NotImplementedError, "This method is gone. Please instead see IE#screen_capture(filename)"
    end
  end
end
