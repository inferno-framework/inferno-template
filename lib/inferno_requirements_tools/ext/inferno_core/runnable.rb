module Inferno
  module DSL
    # This module contains the DSL for defining child entities in the test
    # definition framework.
    module Runnable
      # Set/Get the IDs of requirements verifed by this runnable
      # Set with [] to clear the list
      #
      # @param requirements [Array<String>]
      # @return [Array<String>] the requirement IDs
      def verifies_requirements(*requirement_ids)
        if requirement_ids.empty?
          @requirement_ids || []
        elsif requirement_ids == [[]]
          @requirement_ids = []
        else
          @requirement_ids = requirement_ids
        end
      end
    end
  end
end
