# frozen_string_literal: true

module Mutant
  class CLIArgumentSanitizer
    include Adamantium::Flat, Procto.call(:call)

    WARNING = '--usage is a no-op in viamin/mutant (MIT-licensed)'
    USAGE_VALUES = %w[opensource commercial].freeze

    def initialize(stderr, arguments)
      @stderr    = stderr
      @arguments = arguments
    end

    def call
      indices = usage_flag_indices
      stderr.puts(WARNING) unless indices.empty?
      arguments.reject.with_index { |_argument, index| indices.include?(index) }
    end

  private

    attr_reader :arguments, :stderr

    def usage_flag_indices
      arguments.each_with_index.with_object([]) do |(argument, index), indices|
        next unless argument.eql?('--usage') || argument.start_with?('--usage=')

        indices << index
        next unless argument.eql?('--usage') && USAGE_VALUES.include?(arguments.at(index + 1))

        indices << index + 1
      end
    end
  end

  # Commandline parser / runner
  class CLI
    include Adamantium::Flat, Equalizer.new(:config), Procto.call(:config)

    # Error failed when CLI argv is invalid
    Error = Class.new(RuntimeError)

    # Run cli with arguments
    #
    # @param [Array<String>] arguments
    #
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
      sanitized_arguments = CLIArgumentSanitizer.call($stderr, arguments)

      parse_match_expressions(option_parser.parse!(sanitized_arguments))
      apply_env_defaults if apply_jobs_env_defaults?
    rescue OptionParser::ParseError => error
      raise(Error, error)
    end

    def option_parser = OptionParser.new(&method(:configure_option_parser))

    def apply_jobs_env_defaults?
      !state.fetch(:jobs_configured) && !state.fetch(:jobs_explicit) && !state.fetch(:exit_requested)
    end

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
      with(matcher: config.matcher.with(match_expressions: [])) if expressions.any?

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

    def enable_zombie(*) = with(zombie: true)

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
      @state = {
        exit_requested: false,
        jobs_configured: false,
        jobs_explicit: false
      }
      @config = load_config
      parse(arguments)
    end

    def load_config
      loader = Config::Loader.new(Config::DEFAULT)
      config = loader.load
      state[:jobs_configured] = config_file_sets_jobs?
      config
    rescue Config::Loader::Error => exception
      raise Error, exception.message
    end

    def config_file_sets_jobs?
      path = Config::DEFAULT.pathname.pwd.join('.mutant.yml')
      return false unless path.file?

      document = Psych.parse_file(path)
      return false unless document.instance_of?(Psych::Nodes::Document)

      root = document.root
      return false unless root.instance_of?(Psych::Nodes::Mapping)

      root.children.each_slice(2).filter_map do |nodes|
        key_node, value_node = nodes

        key_node.value unless value_node.nil?
      end.include?('jobs')
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
