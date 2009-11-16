module Watir
  module Exception

    # Root class for all Watir Exceptions
    class WatirException < RuntimeError  
      def initialize(message="")
        super(message)
      end
    end
    
    class NoBrowserException < WatirException; end

    # This exception is thrown if an attempt is made to access an object that doesn't exist
    class UnknownObjectException < WatirException; end

    # This exception is raised if attempting to relocate an Element that was located in a way that does not support relocating 
    class UnableToRelocateException < UnknownObjectException; end

    # This exception is thrown if an attempt is made to access a frame that cannot be found 
    class UnknownFrameException< UnknownObjectException; end

    # This exception is thrown if an attempt is made to access an object that is in a disabled state
    class ObjectDisabledException   < WatirException; end

    # This exception is thrown if an attempt is made to access an object that is in a read only state
    class ObjectReadOnlyException  < WatirException; end

    # This exception is thrown if an attempt is made to access an object when the specified value cannot be found
    class NoValueFoundException < WatirException; end

    # This exception gets raised if part of finding an object is missing
    class MissingWayOfFindingObjectException < WatirException; end

    # This exception is thrown if the window cannot be found
    class NoMatchingWindowFoundException < WatirException; end

    # This exception is thrown if an attemp is made to acces the status bar of the browser when it doesnt exist
    class NoStatusBarException < WatirException; end

    # This exception is thrown if an http error, such as a 404, 500 etc is encountered while navigating
    class NavigationException < WatirException; end

    # This exception is raised if an element does not have a container defined, and needs one. 
    class MissingContainerException < WatirException; end

    # This exception is raised if a timeout is exceeded
    class TimeOutException < WatirException
      def initialize(duration, timeout)
        @duration, @timeout = duration, timeout
      end 
      attr_reader :duration, :timeout
    end
  end
end