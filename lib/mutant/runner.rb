# frozen_string_literal: true

module Mutant
  # Runner baseclass
  class Runner
    include Adamantium::Flat, Concord.new(:env), Procto.call(:result)

    # Initialize object
    #
    # @return [undefined]
    def initialize(*)
      super

      reporter.start(env)

      run_mutation_analysis
    end

    # Final result
    #
    # @return [Result::Env]
    attr_reader :result

  private

    # Run mutation analysis
    #
    # @return [undefined]
    def run_mutation_analysis
      driver = Parallel.async(mutation_test_config)

      @result = with_signal_handlers { run_driver(driver) }
    rescue Interrupt
      @result = driver.stop.payload
      raise
    ensure
      reporter.report(@result || mutation_sink.status)
    end

    # Run with signal handlers for graceful shutdown
    #
    # @return [Object]
    def with_signal_handlers
      old_int  = Signal.trap('INT')  { raise Interrupt }
      old_term = Signal.trap('TERM') { raise Interrupt }
      yield
    ensure
      Signal.trap('INT', old_int) if old_int
      Signal.trap('TERM', old_term) if old_term
    end

    # Run driver
    #
    # @param [Driver] driver
    #
    # @return [Object]
    #   the last returned status payload
    def run_driver(driver)
      loop do
        status = driver.wait_timeout(reporter.delay)
        break status.payload if status.done?
        reporter.progress(status)
      end
    end

    # Configuration for parallel execution engine
    #
    # @return [Parallel::Config]
    def mutation_test_config
      Parallel::Config.new(
        condition_variable: config.condition_variable,
        jobs:               config.jobs,
        mutex:              config.mutex,
        processor:          env.method(:kill),
        sink:               mutation_sink,
        source:             Parallel::Source::Array.new(env.mutations),
        thread:             config.thread
      )
    end

    # Sink used to collect intermediate and final results
    #
    # @return [Sink]
    def mutation_sink
      @mutation_sink ||= Sink.new(env)
    end

    # Reporter to use
    #
    # @return [Reporter]
    def reporter
      env.config.reporter
    end

    # Config for this mutant execution
    #
    # @return [Config]
    def config
      env.config
    end

  end # Runner
end # Mutant
