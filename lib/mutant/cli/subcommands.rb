# frozen_string_literal: true

module Mutant
  class CLI
    # Subcommand handler methods
    module Subcommands
    private

      def handle_run(arguments)
        if arguments.include?('--version')
          puts("mutant-#{VERSION}")
          return cli_exit
        end

        if arguments.intersect?(%w[--help -h])
          puts(
            OptionParser.new do |builder|
              builder.banner = 'usage: mutant run [options] MATCH_EXPRESSION ...'
              %i[add_environment_options add_mutation_options add_filter_options add_debug_options].each do |name|
                __send__(name, builder)
              end
            end.to_s
          )
          return cli_exit
        end

        parse(arguments)
      end

      def handle_environment(arguments)
        if arguments.include?('--version')
          puts("mutant-#{VERSION}")
          return cli_exit
        end

        if arguments.intersect?(%w[--help -h])
          puts(Help::ENVIRONMENT_HELP)
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
          puts(
            OptionParser.new do |builder|
              builder.banner = 'usage: mutant run [options] MATCH_EXPRESSION ...'
              %i[add_environment_options add_mutation_options add_filter_options add_debug_options].each do |name|
                __send__(name, builder)
              end
            end.to_s
          )
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
    end
  end
end
