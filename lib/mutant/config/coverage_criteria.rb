# frozen_string_literal: true

module Mutant
  class Config
    # Mutation coverage classification criteria
    class CoverageCriteria
      include Adamantium, Anima.new(
        :process_abort,
        :test_result,
        :timeout
      )

      DEFAULT = new(
        process_abort: false,
        test_result:   true,
        timeout:       false
      )

      # Determine if a mutation counts as killed
      #
      # @param [Mutation] mutation
      # @param [Isolation::Result] isolation_result
      #
      # @return [Boolean]
      def success?(mutation:, isolation_result:)
        if isolation_result.success?
          test_result && mutation.class.success?(isolation_result.value)
        else
          process_abort
        end
      end
    end # CoverageCriteria
  end # Config
end # Mutant
