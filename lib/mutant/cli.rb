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
    include Adamantium::Flat, Equalizer.new(:config)

    Error = Class.new(RuntimeError)

    SUBCOMMANDS = %w[run environment session help].freeze

    DEPRECATION_WARNING = <<~MESSAGE
      WARNING: Invoking mutant without a subcommand is deprecated.
      Use `mutant run [args]` instead of `mutant [args]`.
      This compatibility alias will be removed in a future release.
    MESSAGE

    def self.run(arguments)
      Runner.call(Env::Bootstrap.call(call(arguments))).success?
    rescue Error => exception
      $stderr.puts(exception.message)
      false
    end

    def self.call(arguments)
      allocate.tap do |instance|
        instance.__send__(:setup, arguments)
      end.config
    end

    def config
      return instance_variable_get(:@config) if instance_variable_defined?(:@config)

      Config::DEFAULT
    end

  private

    GLOBAL_FLAGS = %w[--help -h --version].freeze
    HELP_FLAGS   = %w[--help -h].freeze

    attr_reader :state

    def apply_env_defaults = (env_jobs = ENV['MUTANT_JOBS']) && with(jobs: ParseJobs.(env_jobs, 'MUTANT_JOBS'))

    def normalize_arguments(arguments)
      return arguments if arguments.empty?

      first = arguments.first

      if SUBCOMMANDS.include?(first)
        arguments
      elsif arguments.one? && GLOBAL_FLAGS.include?(first)
        arguments
      else
        warn_deprecation
        ['run'] + arguments
      end
    end

    def warn_deprecation
      $stderr.puts(DEPRECATION_WARNING)
    end

    def puts(message = nil)
      $stdout.puts(message)
    end

    def cli_exit
      config.kernel.public_send(:exit)
    end

    def dispatch(arguments)
      subcommand, *subcommand_arguments = arguments

      if SUBCOMMANDS.include?(subcommand)
        __send__("handle_#{subcommand}", subcommand_arguments)
      elsif arguments.one? && HELP_FLAGS.include?(subcommand)
        puts(Help::MAIN_HELP)
        cli_exit
      elsif arguments.one? && subcommand == '--version'
        puts("mutant-#{VERSION}")
        cli_exit
      else
        parse(arguments)
      end
    end

    def process(arguments)
      dispatch(normalize_arguments(arguments))
    end

    def parse(arguments)
      sanitized_arguments = CLIArgumentSanitizer.call($stderr, arguments)

      parse_match_expressions(option_parser.parse!(sanitized_arguments))
      apply_env_defaults if apply_jobs_env_defaults?
    rescue OptionParser::ParseError => error
      raise(Error, error)
    end

    def option_parser
      OptionParser.new do |builder|
        builder.banner = 'usage: mutant run [options] MATCH_EXPRESSION ...'
        add_option_groups(builder)
      end
    end

    def add_option_groups(builder)
      %i[add_environment_options add_mutation_options add_filter_options add_debug_options].each do |name|
        __send__(name, builder)
      end
    end

    def parse_match_expressions(expressions)
      with(matcher: config.matcher.with(match_expressions: [])) if expressions.any?

      expressions.each do |expression|
        add_matcher(:match_expressions, config.expression_parser.(expression))
      end
    end

    def with(attributes)
      instance_variable_set(:@config, config.with(attributes))
    end

    def add(attribute, value)
      with(attribute => config.public_send(attribute) + [value])
    end

    def add_matcher(attribute, value)
      with(matcher: config.matcher.add(attribute, value))
    end

  end # CLI

  class CLI
  private

    def apply_jobs_env_defaults?
      !state.fetch(:jobs_configured) && !state.fetch(:jobs_explicit) && !state.fetch(:exit_requested)
    end

    def setup(arguments)
      @state = {
        exit_requested: false,
        jobs_configured: false,
        jobs_explicit: false
      }
      @config = load_config
      process(arguments)
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
