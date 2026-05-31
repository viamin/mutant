# frozen_string_literal: true

module Mutant
  # Commandline parser / runner
  class CLI
    include Adamantium::Flat, Equalizer.new(:config), Procto.call(:config)

    # Error failed when CLI argv is invalid
    Error = Class.new(RuntimeError)
    # Run cli with arguments
    # @param [Array<String>] arguments
    # @return [Boolean]
    def self.run(arguments)
      Runner.call(Env::Bootstrap.call(call(arguments))).success?
    rescue Error => exception
      $stderr.puts(exception.message)
      false
    end

    attr_reader :config

  private

    attr_reader :state

    def apply_env_defaults = (env_jobs = ENV['MUTANT_JOBS']) && with(jobs: ParseJobs.(env_jobs, 'MUTANT_JOBS'))

    # Parse the command-line options
    #
    # @param [Array<String>] arguments
    #   Command-line options and arguments to be parsed.
    #
    # @fail [Error]
    #   An error occurred while parsing the options.
    #
    # @return [undefined]
    def parse(arguments)
      parse_match_expressions(option_parser.parse!(arguments))
      apply_env_defaults if apply_jobs_env_defaults?
    rescue OptionParser::ParseError => error
      raise(Error, error)
    end

    def option_parser = OptionParser.new(&method(:configure_option_parser))

    def apply_jobs_env_defaults? = !state.fetch(:jobs_explicit) && !state.fetch(:exit_requested)

    def configure_option_parser(builder)
      builder.banner = 'usage: mutant [options] MATCH_EXPRESSION ...'
      %i[add_environment_options add_mutation_options add_filter_options add_debug_options].each do |name|
        __send__(name, builder)
      end
    end

    # Parse matchers
    #
    # @param [Array<String>] expressions
    #
    # @return [undefined]
    def parse_match_expressions(expressions)
      expressions.each do |expression|
        add_matcher(:match_expressions, config.expression_parser.(expression))
      end
    end

    # Add environmental options
    #
    # @param [Object] opts
    # rubocop:disable MethodLength
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
      opts.on('-j', '--jobs NUMBER', 'Number of kill jobs. Defaults to MUTANT_JOBS or 1.') do |number|
        state[:jobs_explicit] = true
        with(jobs: ParseJobs.(number, '--jobs'))
      end
    end

    # Use integration
    #
    # @param [String] name
    #
    # @return [undefined]
    def setup_integration(name)
      with(integration: Integration.setup(config.kernel, name))
    rescue LoadError
      raise Error, "Could not load integration #{name.inspect} (you may want to try installing the gem mutant-#{name})"
    end

    # Add mutation options
    #
    # @param [OptionParser] opts
    #
    # @return [undefined]
    def add_mutation_options(opts)
      opts.separator(nil)
      opts.separator('Options:')

      opts.on('--use INTEGRATION', 'Use INTEGRATION to kill mutations', &method(:setup_integration))
    end

    # Add filter options
    #
    # @param [OptionParser] opts
    #
    # @return [undefined]
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
              from:   revision,
              to:     Repository::Diff::HEAD
            )
          )
        )
      end
    end

    # Add debug options
    #
    # @param [OptionParser] opts
    #
    # @return [undefined]
    def add_debug_options(opts)
      opts.on('--fail-fast', 'Fail fast') do
        with(fail_fast: true)
      end
      opts.on('--version', 'Print mutants version') do
        state[:exit_requested] = true
        puts("mutant-#{VERSION}")
        config.kernel.exit
      end
      opts.on_tail('-h', '--help', 'Show this message') do
        state[:exit_requested] = true
        puts(opts.to_s)
        config.kernel.exit
      end
    end

    # With configuration
    #
    # @param [Hash<Symbol, Object>] attributes
    #
    # @return [undefined]
    def with(attributes) = @config = config.with(attributes)

    # Add configuration
    #
    # @param [Symbol] attribute
    #   the attribute to add to
    #
    # @param [Object] value
    #   the value to add
    #
    # @return [undefined]
    def add(attribute, value) = with(attribute => config.public_send(attribute) + [value])

    # Add matcher configuration
    #
    # @param [Symbol] attribute
    #   the attribute to add to
    #
    # @param [Object] value
    #   the value to add
    #
    # @return [undefined]
    def add_matcher(attribute, value) = with(matcher: config.matcher.add(attribute, value))

  end # CLI

  class CLI
  private

    def setup(arguments)
      @config = Config::DEFAULT
      @state = {
        exit_requested: false,
        jobs_explicit: false
      }
      parse(arguments)
    end

    alias_method :initialize, :setup
    private :initialize, :setup
  end

  class CLI
    ParseJobs = lambda do |input, source|
      jobs = Integer(input)
      raise Error, "#{source} must be >= 1" if jobs < 1
      jobs
    rescue ArgumentError
      raise Error, "#{source} must be an integer"
    end
  end
end # Mutant
