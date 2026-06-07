# frozen_string_literal: true

module Mutant
  class CLI
    # Option parsing methods
    module Options
    private

      FAIL_FAST_TOKEN = true

      def enable_zombie(*) = with(zombie: true)

      def add_environment_options(opts)
        opts.separator('Environment:')
        opts.on('--zombie', 'Run mutant zombified') { enable_zombie }
        opts.on('-I', '--include DIRECTORY', 'Add DIRECTORY to $LOAD_PATH') do |directory|
          add(:includes, directory)
        end
        opts.on('-r', '--require NAME', 'Require file with NAME') do |name|
          add(:requires, name)
        end
        opts.on('-j', '--jobs NUMBER', 'Number of kill jobs. Defaults to MUTANT_JOBS or 1.') do |number|
          state[:jobs_explicit] = true
          with(jobs: ParseJobs.(number, '--jobs'))
        end
      end

      def setup_integration(name)
        with(integration: Integration.setup(config.kernel, name))
      rescue LoadError
        msg = "Could not load integration #{name.inspect} " \
              "(you may want to try installing the gem mutant-#{name})"
        raise Error, msg
      end

      def add_mutation_options(opts)
        opts.separator(nil)
        opts.separator('Options:')

        opts.on('--use INTEGRATION', 'Use INTEGRATION to kill mutations', &method(:setup_integration))
      end

      def add_filter_options(opts)
        opts.on('--include-subject EXPRESSION', 'Add EXPRESSION to the configured subject matcher list') do |pattern|
          add_matcher(:match_expressions, config.expression_parser.(pattern))
        end
        opts.on('--ignore-subject EXPRESSION', 'Ignore subjects that match EXPRESSION as prefix') do |pattern|
          add_matcher(:ignore_expressions, config.expression_parser.(pattern))
        end
        opts.on('--since REVISION', 'Only select subjects touched since REVISION') do |revision|
          add_matcher(
            :subject_filters,
            Repository::SubjectFilter.new(
              Repository::Diff.new(
                config: config,
                from:   revision,
                to:     Repository::Diff::HEAD
              )
            )
          )
        end
      end

      def add_debug_options(opts)
        opts.on('--fail-fast', 'Fail fast') do
          enable_fail_fast(FAIL_FAST_TOKEN)
        end
      end

      def enable_fail_fast(token)
        raise Error, "Unexpected fail fast token: #{token.inspect}" unless token == FAIL_FAST_TOKEN

        with(fail_fast: true)
      end
    end
  end
end
