# frozen_string_literal: true

module Mutant
  class CLI
    # Subcommand handler methods
    module Subcommands
    private

      def handle_run(arguments)
        parse(arguments)
      end

      def handle_environment(arguments)
        if arguments.intersect?(%w[--help -h])
          print_environment_help
          return cli_exit
        end
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
          print_session_help
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
          print_environment_help
        when 'session'
          print_session_help
        else
          print_main_help
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
    end
  end
end
