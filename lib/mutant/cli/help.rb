# frozen_string_literal: true

module Mutant
  class CLI
    # Subcommand help text and printing methods
    module Help
      MAIN_HELP = <<~MESSAGE
        usage: mutant <subcommand> [options] [args]

        Subcommands:
          run           Run mutation testing (default)
          environment   Print resolved configuration and exit
          session       Inspect mutation testing sessions
          help          Show help for a subcommand

        Global options:
          --version     Print mutant version
          -h, --help    Show this message

        Run `mutant help <subcommand>` for details on a specific subcommand.
      MESSAGE

      SESSION_HELP = <<~MESSAGE
        usage: mutant session <subcommand>

        Subcommands:
          list          List mutation testing sessions
          show <id>     Show details of a specific session
      MESSAGE

      ENVIRONMENT_HELP = <<~MESSAGE
        usage: mutant environment [options] MATCH_EXPRESSION ...

        Print the resolved mutant configuration and exit.
        Useful for debugging which settings are active.

        All options accepted by `mutant run` are also accepted here,
        since they influence the resolved configuration.
      MESSAGE

    private

      def print_main_help
        puts MAIN_HELP
      end

      def print_session_help
        puts SESSION_HELP
      end

      def print_environment_help
        puts ENVIRONMENT_HELP
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
