require 'vapir-common/exceptions'

module Vapir
  class Waiter # :nodoc:all
    # How long to wait between each iteration through the wait_until
    # loop. In seconds.
    attr_accessor :polling_interval
  
    # Timeout for wait_until.
    attr_accessor :timeout
    
    @@default_polling_interval = 0.5
    @@default_timeout = 60.0
  
    def initialize(timeout=@@default_timeout, polling_interval=@@default_polling_interval)
      @timeout = timeout
      @polling_interval = polling_interval
    end
  
    module WaitUntil
      public
      # Execute the provided block until either (1) it returns true, or
      # (2) the timeout (in seconds) has been reached. If the timeout is reached,
      # a TimeOutException will be raised. The block will always
      # execute at least once.
      # 
      # waiter = Waiter.new(5)
      # waiter.wait_until {puts 'hello'}
      # 
      # This code will print out "hello" for five seconds, and then raise a 
      # Vapir::TimeOutException.
      def wait_until(timeout=::Vapir::Waiter.send(:class_variable_get, '@@default_timeout'), polling_interval=::Vapir::Waiter.send(:class_variable_get, '@@default_polling_interval'), &block)
        ::Waiter.try_for(timeout, :interval => polling_interval, &block)
      end
    end
    include ::Vapir::Waiter::WaitUntil
    extend ::Vapir::Waiter::WaitUntil
  end
  include ::Vapir::Waiter::WaitUntil
  extend ::Vapir::Waiter::WaitUntil
  class Browser
    include ::Vapir::Waiter::WaitUntil
    extend ::Vapir::Waiter::WaitUntil
  end
end # module

require 'vapir-common/handle_options'

class WaiterError < StandardError; end
class Waiter
  # Tries for +time+ seconds to get the desired result from the given block. Stops when either:
  # 1. The :condition option (which should be a proc) returns true (that is, not false or nil)
  # 2. The block returns true (that is, anything but false or nil) if no :condition option is given
  # 3. The specified amount of time has passed. By default a WaiterError is raised. 
  #    If :exception option is given, then if it is nil, no exception is raised; otherwise it should be
  #    an exception class or an exception instance which will be raised instead of WaiterError
  #
  # Returns the value of the block, which can be handy for things that return nil on failure and some 
  # other object on success, like Enumerable#detect for example: 
  # found_thing=Waiter.try_for(30) { all_things().detect {|thing| thing.name=="Bill" } }
  #
  # Examples:
  # Waiter.try_for(30) do
  #   Time.now.year == 2015
  # end
  # Raises a WaiterError unless it is called between the last 30 seconds of December 31, 2014 and the end of 2015
  #
  # Waiter.try_for(365.242199*24*60*60, :interval => 0.1, :exception => nil, :condition => proc{ 2+2==5 }) do
  #   STDERR.puts "any decisecond now ..."
  # end
  # Complains to STDERR for one year, every tenth of a second, as long as 2+2 does not equal 5. Does not 
  # raise an exception if 2+2 does not become equal to 5. 
  def self.try_for(time, options={})
    unless time.is_a?(Numeric) && options.is_a?(Hash)
      raise TypeError, "expected arguments are time (a numeric) and, optionally, options (a Hash). received arguments #{time.inspect} (#{time.class}), #{options.inspect} (#{options.class})"
    end
    options=handle_options(options, {:interval => 0.5, :condition => proc{|_ret| _ret}, :exception => WaiterError})
    started=Time.now
    begin
      ret=yield
      break if options[:condition].call(ret)
      sleep options[:interval]
    end while Time.now < started+time && !options[:condition].call(ret)
    if options[:exception] && !options[:condition].call(ret)
      ex=if options[:exception].is_a?(Class)
        options[:exception].new("Waiter waited #{time} seconds and condition was not met")
      else
        options[:exception]
      end
      raise ex
    end
    ret
  end
end
