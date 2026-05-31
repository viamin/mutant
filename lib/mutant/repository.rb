# frozen_string_literal: true

module Mutant
  module Repository
    # Error raised on repository interaction problems
    RepositoryError = Class.new(RuntimeError)

    class DiffCommandResult
      include Adamantium::Flat, Anima.new(:command, :stdout, :stderr, :status)

      def self.capture(open3_module, command)
        stdout, stderr, status = open3_module.capture3(*command, binmode: true)

        new(command: command, stdout: stdout, stderr: stderr, status: status)
      end

      def fetch_stdout
        return stdout if success?

        fail RepositoryError, "Command #{command} failed!"
      end

      def output? = success? && !stdout.empty?

      def invalid_line_range?
        Diff::INVALID_LINE_RANGE_PATTERN.match?(stderr)
      end

      def success? = status.success?
    end

    class DiffLocation
      include Adamantium::Flat, Anima.new(:path, :line_range)

      def line_argument = "#{line_range.begin},#{line_range.end}:#{path}"

      def touched_by_hunk?(start_line, line_count)
        return false if line_count.zero?

        hunk_end = start_line + line_count - 1

        line_range.begin <= hunk_end && start_line <= line_range.end
      end
    end

    # Subject filter based on repository diff
    class SubjectFilter
      include Adamantium, Concord.new(:diff)

      # Test if subject was touched in diff
      #
      # @param [Subject] subject
      #
      # @return [Boolean]
      def call(subject)
        diff.touches?(subject.source_path, subject.source_lines)
      end

    end # SubjectFilter

    # Diff between two objects in repository
    class Diff
      include Adamantium, Anima.new(:config, :from, :to)

      HEAD = 'HEAD'
      INVALID_LINE_RANGE_PATTERN = /has only \d+ lines/.freeze

      # Test if diff changes file at line range
      #
      # @param [Pathname] path
      # @param [Range<Integer>] line_range
      #
      # @return [Boolean]
      #
      # @raise [RepositoryError]
      #   when git command failed
      def touches?(path, line_range)
        location = DiffLocation.new(path: path, line_range: line_range)

        return false unless within_working_directory?(location.path) && tracks?(location.path)

        result = DiffCommandResult.capture(config.open3, log_command(location))

        return result.output? if result.success?
        return diff_touches?(location) if result.invalid_line_range?

        fail RepositoryError, "Command #{result.command} failed!"
      end

    private

      def log_command(location)
        %W[
          git log
          #{from}..#{to}
          --ignore-all-space
          -L #{location.line_argument}
        ]
      end

      def diff_touches?(location)
        DiffCommandResult
          .capture(config.open3, %W[git diff --unified=0 #{from}..#{to} -- #{location.path}])
          .fetch_stdout
          .each_line
          .grep(/\A@@/)
          .any? { |line| location.touched_by_hunk?(*parse_hunk(line)) }
      end

      def parse_hunk(line)
        match = /\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/.match(line)

        fail RepositoryError, "Cannot parse diff hunk: #{line.inspect}" unless match

        [Integer(match[1]), Integer(match[2] || 1)]
      end

      # Test if path is tracked in repository
      #
      # FIXME: Cache results, to avoid spending time on producing redundant results.
      #
      # @param [Pathname] path
      #
      # @return [Boolean]
      def tracks?(path)
        command = %W[git ls-files --error-unmatch -- #{path}]
        config.kernel.system(
          *command,
          out: File::NULL,
          err: File::NULL
        )
      end

      # Test if the path is within the current working directory
      #
      # @param [Pathname] path
      #
      # @return [TrueClass, nil]
      def within_working_directory?(path)
        working_directory = config.pathname.pwd
        path.ascend { |parent| return true if working_directory.eql?(parent) }
      end

    end # Diff
  end # Repository
end # Mutant
