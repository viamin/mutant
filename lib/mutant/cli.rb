# frozen_string_literal: true

module Mutant
  # Commandline parser / runner
  class CLI
    include Adamantium::Flat, Equalizer.new(:config), Procto.call(:config)

    # Error failed when CLI argv is invalid
    Error = Class.new(RuntimeError)

    SUBCOMMANDS = %w[run environment session help].freeze

    DEPRECATION_WARNING = <<~MESSAGE
      WARNING: Invoking mutant without a subcommand is deprecated.
      Use `mutant run [args]` instead of `mutant [args]`.
      This compatibility alias will be removed in a future release.
    MESSAGE

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

    # Initialize object
    #
    # @param [Array<String>]
    #
    # @return [undefined]
    def initialize(arguments)
      @config = Config::DEFAULT

      arguments = normalize_arguments(arguments)
      subcommand = arguments.first

      if subcommand && respond_to?("handle_#{subcommand}", true)
        __send__("handle_#{subcommand}", subcommand_arguments(arguments))
      elsif arguments.one? && %w[--help -h].include?(subcommand)
        print_main_help
        exit
      else
        parse(arguments)
      end
    end

    # Config parsed from CLI
    #
    # @return [Config]
    attr_reader :config

  private

    GLOBAL_FLAGS = %w[--help -h --version].freeze

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

    def exit
      config.kernel.exit
    end

    def subcommand_arguments(arguments)
      arguments.drop(1)
    end

    def parse(arguments)
      opts = OptionParser.new do |builder|
        builder.banner = 'usage: mutant run [options] MATCH_EXPRESSION ...'
        %i[add_environment_options add_mutation_options add_filter_options add_debug_options].each do |name|
          __send__(name, builder)
        end
      end

      parse_match_expressions(opts.parse!(arguments))
    rescue OptionParser::ParseError => error
      raise(Error, error)
    end

    def parse_match_expressions(expressions)
      expressions.each do |expression|
        add_matcher(:match_expressions, config.expression_parser.(expression))
      end
    end

    def with(attributes)
      @config = config.with(attributes)
    end

    def add(attribute, value)
      with(attribute => config.public_send(attribute) + [value])
    end

    def add_matcher(attribute, value)
      with(matcher: config.matcher.add(attribute, value))
    end

  end # CLI
end # Mutant
