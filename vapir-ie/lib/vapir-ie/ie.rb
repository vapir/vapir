=begin
  license
  ---------------------------------------------------------------------------
  Copyright (c) 2004 - 2005, Paul Rogers and Bret Pettichord
  Copyright (c) 2006 - 2008, Bret Pettichord
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

  3. Neither the names Paul Rogers, nor Bret Pettichord nor the names of any
  other contributors to this software may be used to endorse or promote
  products derived from this software without specific prior written
  permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS
  IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  --------------------------------------------------------------------------
  (based on BSD Open Source License)
=end

require 'vapir-ie/win32ole'

# necessary extension of win32ole 
class WIN32OLE
  def respond_to?(method)
    super || object_respond_to?(method)
  end
  
  # checks if WIN32OLE#ole_method returns an WIN32OLE_METHOD, or errors. 
  # WARNING: #ole_method is pretty slow, and consequently so is this. you are likely to be better
  # off just calling a method you are not sure exists, and rescuing the WIN32OLERuntimeError
  # that is raised if it doesn't exist. 
  def object_respond_to?(method)
    method=method.to_s
    # strip assignment = from methods. going to assume that if it has a getter method, it will take assignment, too. this may not be correct, but will have to do. 
    if method =~ /=\z/
      method=$`
    end
    respond_to_cache[method]
  end
  
  private
  def respond_to_cache
    @respond_to_cache||=Hash.new do |hash, key|
      hash[key]=begin
        !!self.ole_method(key)
      rescue WIN32OLERuntimeError
        false
      end
    end
  end
end

# create stub class since everything is defined in Vapir::IE namespace - this needs to be defined before the real class.
require 'vapir-common/browser'
module Vapir
#  class IE < Vapir::Browser
#  end
  # above somehow triggers autoload on Vapir::IE, which
  # calls to a require that then requires this file, which
  # already being loaded returns without defining Vapir::IE,
  # causing NameError: uninitialized constant Vapir::IE
  # very strange. 
  IE= Class.new(Vapir::Browser)
  #const_set('IE', Class.new(Vapir::Browser))
end

require 'logger'
require 'vapir-common/common_elements'
require 'vapir-common/exceptions'
require 'vapir-ie/close_all'
require 'vapir-ie/ie-process'

require 'dl/import'
require 'dl/struct'
require 'Win32API'

require 'vapir-common/matches'

# these switches need to be deleted from ARGV to enable the Test::Unit
# functionality that grabs
# the remaining ARGV as a filter on what tests to run.
# Note: this means that watir must be require'd BEFORE test/unit.
# (Alternatively, you could require test/unit first and then put the Vapir::IE
# arguments after the '--'.)

# Make Internet Explorer invisible. -b stands for background
$HIDE_IE ||= ARGV.delete('-b')

# Run fast
$FAST_SPEED = ARGV.delete('-f')

# Eat the -s command line switch (deprecated)
ARGV.delete('-s')

require 'vapir-ie/ie-class'
require 'vapir-ie/logger'
require 'vapir-ie/win32'
require 'vapir-ie/container'
require 'vapir-ie/page-container'
require 'vapir-ie/version'
require 'vapir-ie/element'
require 'vapir-ie/frame'
require 'vapir-ie/modal_dialog'
require 'vapir-ie/form'
require 'vapir-ie/non_control_elements'
require 'vapir-ie/input_elements'
require 'vapir-ie/table'
require 'vapir-ie/image'
require 'vapir-ie/link'

module Vapir
  include Vapir::Exception

  # Directory containing the watir.rb file
  @@dir = File.expand_path(File.dirname(__FILE__))

  ATTACHER = Waiter.new
  # Like regular Ruby "until", except that a TimeOutException is raised
  # if the timeout is exceeded. Timeout is IE.attach_timeout.
  def self.until_with_timeout # block
    ATTACHER.timeout = IE.attach_timeout
    ATTACHER.wait_until { yield }
  end
end
