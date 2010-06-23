module Vapir
  module Exception

    # Root class for all Vapir Exceptions
    class VapirException < StandardError; end
    
    # Base class for variouss sorts of errors when a thing does not exist 
    class ExistenceFailureException < VapirException; end

    class NoBrowserException < ExistenceFailureException; end
    
    # This exception is thrown if an attempt is made to access an object that doesn't exist
    class UnknownObjectException < ExistenceFailureException; end

    # This exception is raised if attempting to relocate an Element that was located in a way that does not support relocating 
    class UnableToRelocateException < UnknownObjectException; end

    # This exception is thrown if an attempt is made to access a frame that cannot be found 
    class UnknownFrameException< UnknownObjectException; end

    # This exception is thrown if an attempt is made to access an object that is in a disabled state
    class ObjectDisabledException   < VapirException; end

    # This exception is thrown if an attempt is made to access an object that is in a read only state
    class ObjectReadOnlyException  < VapirException; end

    # This exception is thrown if an attempt is made to access an object when the specified value cannot be found
    class NoValueFoundException < VapirException; end

    # This exception gets raised if part of finding an object is missing
    class MissingWayOfFindingObjectException < VapirException; end

    class WindowException < VapirException; end
    # This exception is thrown if the window cannot be found
    class NoMatchingWindowFoundException < WindowException; end
    class WindowFailedToCloseException < WindowException; end

    # This exception is thrown if an attemp is made to acces the status bar of the browser when it doesnt exist
    class NoStatusBarException < VapirException; end

    # This exception is thrown if an http error, such as a 404, 500 etc is encountered while navigating
    class NavigationException < VapirException; end

    # This exception is raised if an element does not have a container defined, and needs one. 
    class MissingContainerException < VapirException; end

    # This exception is raised if a timeout is exceeded
    class TimeOutException < VapirException
      def initialize(duration, timeout)
        @duration, @timeout = duration, timeout
      end 
      attr_reader :duration, :timeout
    end
  end
end