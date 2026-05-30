# frozen_string_literal: true

module Mutant
  # Runner baseclass
  class Runner
    include Adamantium::Flat, Concord.new(:env)

    # Run mutation analysis for an environment before freezing the runner
    def self.call(env)
      build(env).freeze.result
    end

    def self.build(env)
      runner = allocate
      runner.__send__(:initialize, env)
      runner.__send__(:run)
    end
    private_class_method :build

    attr_reader :result

  private

    # Execute analysis and cache the final result before freezing the runner
    def run
      reporter.start(env)
      @result = run_mutation_analysis
      self
    end

    def run_mutation_analysis
      result = nil
      driver = Parallel.async(mutation_test_config)

      result = with_signal_handlers { run_driver(driver) }
    rescue Interrupt
      result = driver&.stop&.payload
      raise
    ensure
      final_result = result || mutation_sink.status
      reporter.report(final_result)
    end

    def with_signal_handlers
      old_int  = Signal.trap('INT')  { raise Interrupt }
      old_term = Signal.trap('TERM') { raise Interrupt }
      yield
    ensure
      Signal.trap('INT', old_int) if old_int
      Signal.trap('TERM', old_term) if old_term
    end

    def run_driver(driver)
      loop do
        status = driver.wait_timeout(reporter.delay)
        break status.payload if status.done?
        reporter.progress(status)
      end
    end

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

    def mutation_sink
      @mutation_sink ||= Sink.new(env)
    end

    def reporter
      env.config.reporter
    end

    def config
      env.config
    end

  end # Runner
end # Mutant
