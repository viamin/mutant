# frozen_string_literal: true

module Mutant
  class CLI
    # Session subcommand helpers
    module Session
    private

      RESULTS_DIR = '.mutant/results'

      def print_session_list(arguments)
        unless arguments.empty?
          raise Error, "session list does not accept arguments: #{arguments.join(' ')}"
        end

        files = session_list_files
        if files.nil? || files.empty?
          puts 'No sessions found in .mutant/results/'
          return
        end

        puts "Sessions (#{files.size}):"
        files.each do |path|
          data = load_session_data(path)
          id = path.basename('.yml')
          status = session_success?(data) ? 'pass' : 'fail'
          coverage = session_coverage(data) || '?'
          puts "  #{id}  coverage: #{coverage}  status: #{status}"
        end
      end

      def print_session_show(id, arguments)
        unless arguments.empty?
          raise Error, "session show does not accept arguments: #{arguments.join(' ')}"
        end

        path = resolve_session_path(id)
        require 'yaml'
        data = YAML.safe_load(path.read, permitted_classes: [Symbol])
        unless data.is_a?(Hash)
          raise Error, "Could not load session '#{path.basename('.yml')}': expected a hash payload"
        end
        puts "Session: #{id}"
        puts "  Status:   #{session_success?(data) ? 'pass' : 'fail'}"
        puts "  Coverage: #{session_coverage(data) || 'unknown'}"

        subjects = session_subject_results(data)
        puts "  Subjects: #{subjects.size}"
        subjects.each do |subject|
          puts "    #{session_expression(subject)}"
        end
      rescue Psych::Exception => exception
        raise Error, "Could not load session '#{path.basename('.yml')}': #{exception.message}"
      end

      def session_results_dir
        config.pathname.new(RESULTS_DIR)
      end

      def session_list_files
        dir = session_results_dir

        return unless dir.directory?

        dir.glob('*.yml').sort
      end

      def resolve_session_path(id)
        raise Error, 'session show requires a session ID argument' unless id
        raise Error, "Invalid session ID '#{id}'" unless /\A[\w-]+\z/.match?(id)

        path = session_results_dir.join("#{id}.yml")
        unless path.file?
          raise Error, "Session '#{id}' not found in .mutant/results/"
        end

        path
      end

      def session_success?(data)
        session_value(data, :success)
      end

      def session_coverage(data)
        session_value(data, :coverage)
      end

      def session_subject_results(data)
        session_value(data, :subject_results) || EMPTY_ARRAY
      end

      def session_expression(data)
        session_value(data, :expression) || '<unknown>'
      end

      def load_session_data(path)
        require 'yaml'
        data = YAML.safe_load(path.read, permitted_classes: [Symbol])

        unless data.is_a?(Hash)
          raise Error, "Could not load session '#{path.basename('.yml')}': expected a hash payload"
        end

        data
      rescue Psych::Exception => exception
        raise Error, "Could not load session '#{path.basename('.yml')}': #{exception.message}"
      end

      def session_value(data, key)
        return unless data

        string_key = key.to_s

        return data[string_key] if data.key?(string_key)
        return data[key] if data.key?(key)

        nil
      end
    end
  end
end
