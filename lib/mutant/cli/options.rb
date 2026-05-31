# frozen_string_literal: true

module Mutant
  class CLI
    # Option parsing methods
    module Options
    private

      def add_environment_options(opts)
        opts.separator('Environment:')
        opts.on('--zombie', 'Run mutant zombified') do
          with(zombie: true)
        end
        opts.on('-I', '--include DIRECTORY', 'Add DIRECTORY to $LOAD_PATH') do |directory|
          add(:includes, directory)
        end
        opts.on('-r', '--require NAME', 'Require file with NAME') do |name|
          add(:requires, name)
        end
        opts.on('-j', '--jobs NUMBER', 'Number of kill jobs. Defaults to number of processors.') do |number|
          with(jobs: Integer(number))
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
        opts.on('--ignore-subject EXPRESSION', 'Ignore subjects that match EXPRESSION as prefix') do |pattern|
          add_matcher(:ignore_expressions, config.expression_parser.(pattern))
        end
        opts.on('--since REVISION', 'Only select subjects touched since REVISION') do |revision|
          add_matcher(
            :subject_filters,
            Repository::SubjectFilter.new(
              Repository::Diff.new(
                config: config,
                from:   Repository::Diff::HEAD,
                to:     revision
              )
            )
          )
        end
      end

      def add_debug_options(opts)
        opts.on('--fail-fast', 'Fail fast') do
          with(fail_fast: true)
        end
        opts.on('--version', 'Print mutants version') do
          puts("mutant-#{VERSION}")
          config.kernel.public_send(:exit)
        end
        opts.on_tail('-h', '--help', 'Show this message') do
          puts(opts.to_s)
          config.kernel.public_send(:exit)
        end
      end
    end
  end
end
