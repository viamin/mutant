# frozen_string_literal: true

module Mutant
  class CLI
    # Subcommand handler methods
    module Subcommands
    private

      HELP_FLAGS = %w[--help -h].freeze
      VERSION_FLAG = '--version'

      def handle_run(arguments)
        return print_version_and_exit if arguments.include?(VERSION_FLAG)
        return print_run_help_and_exit if arguments.intersect?(HELP_FLAGS)

        parse(arguments)
      end

      def handle_environment(arguments)
        return print_version_and_exit if arguments.include?(VERSION_FLAG)
        return print_environment_help_and_exit if arguments.intersect?(HELP_FLAGS)

        parse(arguments)
        print_environment
        cli_exit
      end

      def handle_session(arguments)
        subcommand, session_id, *rest = arguments
        case subcommand
        when 'list'
          print_session_list([session_id, *rest].compact)
        when 'show'
          print_session_show(session_id, rest)
        else
          puts(Help::SESSION_HELP)
        end
        cli_exit
      end

      def handle_help(arguments)
        subcommand, *rest = arguments

        unless rest.empty?
          raise Error, "help does not accept arguments: #{rest.join(' ')}"
        end

        case subcommand
        when 'run'
          print_run_help
        when 'environment'
          puts(Help::ENVIRONMENT_HELP)
        when 'session'
          puts(Help::SESSION_HELP)
        else
          puts(Help::MAIN_HELP)
        end
        cli_exit
      end

      def print_environment
        puts 'Mutant environment:'
        puts "  Integration:     #{config.integration}"
        puts "  Jobs:            #{config.jobs}"
        puts "  Includes:        #{config.includes}"
        puts "  Requires:        #{config.requires}"
        puts "  Fail fast:       #{config.fail_fast?}"
        puts "  Zombie:          #{config.zombie?}"
        puts "  Matcher:         #{config.matcher.inspect}"
      end

      def print_run_help_and_exit
        print_run_help
        cli_exit
      end

      def print_environment_help_and_exit
        puts(Help::ENVIRONMENT_HELP)
        cli_exit
      end

      def print_version_and_exit
        puts("mutant-#{VERSION}")
        cli_exit
      end

      def print_run_help
        puts(
          OptionParser.new do |builder|
            builder.banner = 'usage: mutant run [options] MATCH_EXPRESSION ...'
            add_option_groups(builder)
          end.to_s
        )
      end
    end
  end
end
