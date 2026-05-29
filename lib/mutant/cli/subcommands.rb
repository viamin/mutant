# frozen_string_literal: true

module Mutant
  class CLI
    # Subcommand handler methods
    module Subcommands
      def handle_run(arguments)
        parse(arguments)
      end

      def handle_environment(arguments)
        parse(arguments)
        print_environment
        config.kernel.exit
      end

      def handle_session(arguments)
        sub = arguments.first
        case sub
        when 'list'
          print_session_list
        when 'show'
          print_session_show(arguments[1])
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

    private

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

      def print_session_list
        puts 'mutant session list - no sessions found'
      end

      def print_session_show(id)
        raise Error, 'session show requires a session ID argument' unless id

        puts "mutant session show #{id} - session not found"
      end

      def print_run_help
        opts = OptionParser.new do |builder|
          builder.banner = 'usage: mutant run [options] MATCH_EXPRESSION ...'
          %i[add_environment_options add_mutation_options add_filter_options add_debug_options].each do |name|
            __send__(name, builder)
          end
        end
        puts opts.to_s
      end
    end
  end
end
