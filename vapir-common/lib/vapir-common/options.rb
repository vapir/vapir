module Vapir
  class << self
    def options_file=(file) # :nodoc:
      raise NotImplementedError, "this method of specifying options is deprecated and gone. see documentation for Vapir.config"
    end
    def options_file
      raise NotImplementedError, "this method of specifying options is deprecated and gone. see documentation for Vapir.config"
    end
    def options= x
      raise NotImplementedError, "this method of specifying options is deprecated and gone. see documentation for Vapir.config"
    end
    def options
      raise NotImplementedError, "this method of specifying options is deprecated and gone. see documentation for Vapir.config"
    end
  end
end
