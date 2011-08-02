# setup/options

module Vapir
  module UnitTest
    class Options
      def execute 
        Vapir::UnitTest.options
      end 
    end
    def self.options
      {:coverage => 'all'}
    end
  end
end
