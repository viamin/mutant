# frozen_string_literal: true

module Mutant
  # Abstract base class for mutant environments
  class Env
    include Adamantium::Flat, Anima.new(
      :config,
      :integration,
      :matchable_scopes,
      :mutations,
      :parser,
      :selector,
      :subjects
    )

    SEMANTICS_MESSAGE =
      "Fix your lib to follow normal ruby semantics!\n" \
      '{Module,Class}#name should return resolvable constant name as String or nil'

    # Kill mutation
    #
    # @param [Mutation] mutation
    #
    # @return [Result::Mutation]
    def kill(mutation)
      start = Timer.now

      Result::Mutation.new(
        coverage_criteria: config.coverage_criteria,
        isolation_result: run_mutation_tests(mutation),
        mutation:         mutation,
        runtime:          Timer.now - start
      )
    end

    # The test selections
    #
    # @return Hash{Mutation => Enumerable<Test>}
    def selections
      subjects.map do |subject|
        [subject, selector.call(subject)]
      end.to_h
    end
    memoize :selections

  private

    ENVIRONMENT_VARIABLE_MUTEX = Mutex.new

    # Kill mutation under isolation with integration
    #
    # @param [Isolation] isolation
    # @param [Integration] integration
    #
    # @return [Result::Isolation]
    def run_mutation_tests(mutation)
      Config::CoverageCriteria.with_current(config.coverage_criteria) do
        config.isolation.call do
          with_environment_variables do
            mutation.insert(config.kernel)
            integration.call(selections.fetch(mutation.subject))
          end
        end
      end
    end

    # Run block with configured environment variables
    #
    # @return [Object]
    def with_environment_variables
      ENVIRONMENT_VARIABLE_MUTEX.synchronize do
        original = config.environment_variables.each_with_object(
          missing: [],
          present: {}
        ) do |(key, _value), state|
          value = ENV[key]

          if value.nil?
            state[:missing] << key
          else
            state[:present][key] = value
          end
        end

        config.environment_variables.each do |key, value|
          ENV[key] = value
        end

        yield
      ensure
        original.fetch(:missing).each do |key|
          ENV.delete(key)
        end

        original.fetch(:present).each do |key, value|
          ENV[key] = value
        end
      end
    end

  end # Env
end # Mutant
