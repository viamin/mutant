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
    end
  end
end
