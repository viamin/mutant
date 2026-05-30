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

      RESULTS_DIR = '.mutant/results'

      def session_results_dir
        config.pathname.new(RESULTS_DIR)
      end

      def find_session_files
        dir = session_results_dir
        return EMPTY_ARRAY unless dir.directory?

        dir.glob('*.yml').sort
      end

      def load_session(path)
        require 'yaml'
        YAML.safe_load(path.read, permitted_classes: [Symbol])
      end

      def print_session_list
        files = find_session_files

        if files.empty?
          puts 'No sessions found in .mutant/results/'
          return
        end

        puts "Sessions (#{files.size}):"
        files.each do |path|
          data = load_session(path)
          id = path.basename('.yml').to_s
          status = data&.dig('success') ? 'pass' : 'fail'
          coverage = data&.dig('coverage') || '?'
          puts "  #{id}  coverage: #{coverage}  status: #{status}"
        end
      end

      def resolve_session_path(id)
        raise Error, 'session show requires a session ID argument' unless id

        path = session_results_dir.join("#{id}.yml")
        unless path.file?
          raise Error, "Session '#{id}' not found in .mutant/results/"
        end

        path
      end

      def print_session_show(id)
        path = resolve_session_path(id)
        data = load_session(path)
        puts "Session: #{id}"
        puts "  Status:   #{data&.dig('success') ? 'pass' : 'fail'}"
        puts "  Coverage: #{data&.dig('coverage') || 'unknown'}"

        subjects = data&.dig('subject_results') || []
        puts "  Subjects: #{subjects.size}"
        subjects.each do |subject|
          puts "    #{subject['expression']}"
        end
      end
    end
  end
end
