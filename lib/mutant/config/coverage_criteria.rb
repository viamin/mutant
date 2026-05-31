# frozen_string_literal: true

module Mutant
  class Config
    # Mutation coverage classification criteria
    class CoverageCriteria
      THREAD_KEY = :mutant_coverage_criteria
      TIMEOUT_SIGNALS = %w[KILL TERM].filter_map { |name| Signal.list[name] }.freeze

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

      def self.current = Thread.current[THREAD_KEY] || DEFAULT

      def self.current=(value)
        Thread.current[THREAD_KEY] = value
      end

      def self.with_current(value)
        previous = Thread.current[THREAD_KEY]
        self.current = value
        yield
      ensure
        Thread.current[THREAD_KEY] = previous
      end

      # Determine if a mutation counts as killed
      #
      # @param [Mutation] mutation
      # @param [Isolation::Result] isolation_result
      #
      # @return [Boolean]
      def success?(mutation, isolation_result)
        if isolation_result.success?
          test_result && mutation.class.success?(isolation_result.value)
        elsif isolation_result.instance_of?(Isolation::Result::Exception)
          mutation.class.exception_success?(isolation_result.value)
        elsif timeout_result?(isolation_result)
          timeout
        else
          process_abort
        end
      end

    private

      def timeout_result?(result)
        case result
        when Isolation::Result::ErrorChain
          timeout_result?(result.value) || timeout_result?(result.next)
        when Isolation::Fork::ChildError
          timeout_status?(result.value)
        else
          false
        end
      end

      def timeout_status?(status)
        status.signaled? && TIMEOUT_SIGNALS.include?(status.termsig)
      end
    end # CoverageCriteria
  end # Config
end # Mutant
