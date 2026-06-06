# frozen_string_literal: true

module Mutant
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

    def apply_jobs_env_defaults? = !state.fetch(:jobs_explicit) && !state.fetch(:exit_requested)

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
      parse_match_expressions(option_parser.parse!(arguments))
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

    def setup(arguments)
      @config = Config::DEFAULT
      @state = {
        exit_requested: false,
        jobs_explicit: false
      }
      process(arguments)
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
