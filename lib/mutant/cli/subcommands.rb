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
          config.kernel.exit
        end
        parse(arguments)
        print_environment
        config.kernel.exit
      end

      def handle_session(arguments)
        sub = arguments.first
        case sub
        when 'list'
          print_session_list(arguments[1..] || [])
        when 'show'
          print_session_show(arguments[1], arguments[2..] || [])
        else
          print_session_help
        end
        config.kernel.exit
      end

      def handle_help(arguments)
        sub = arguments.first
        case sub
        when 'run'
          print_run_help
        when 'environment'
          print_environment_help
        when 'session'
          print_session_help
        else
          print_main_help
        end
        config.kernel.exit
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
