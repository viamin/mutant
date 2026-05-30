# frozen_string_literal: true

module Mutant
  module Repository
    # Error raised on repository interaction problems
    RepositoryError = Class.new(RuntimeError)

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
        return false unless within_working_directory?(path)

        relative_path = path.relative_path_from(config.pathname.pwd).to_s
        ranges = diff_hunks[relative_path]

        return false unless ranges
        return true if ranges.equal?(ParseState::ALL)

        ranges.any? { |range| range.begin <= line_range.end && line_range.begin <= range.end }
      end

    private

      # Pre-computed diff hunks from git diff
      #
      # @return [Hash{String => Array<Range<Integer>>}]
      #
      # @raise [RepositoryError]
      #   when git command failed
      def diff_hunks
        ParseState.parse(command_output(%W[git diff #{resolved_to}...#{resolved_from}]))
      end
      memoize :diff_hunks

      # Resolve "from" reference to SHA via git rev-parse
      #
      # @return [String]
      def resolved_from
        resolve_ref(from)
      end
      memoize :resolved_from

      # Resolve "to" reference to SHA via git rev-parse
      #
      # @return [String]
      def resolved_to
        resolve_ref(to)
      end
      memoize :resolved_to

      # Resolve a git reference to a SHA
      #
      # @param [String] ref
      #
      # @return [String]
      #
      # @raise [RepositoryError]
      #   when ref cannot be resolved
      def resolve_ref(ref)
        command_output(%W[git rev-parse --verify #{ref}]).strip
      end

      # Execute a git command and return stdout on success
      #
      # @param [Array<String>] command
      #
      # @return [String]
      #
      # @raise [RepositoryError]
      #   when command failed
      def command_output(command)
        stdout, status = config.open3.capture2(*command, binmode: true)

        fail RepositoryError, "Command #{command} failed!" unless status.success?

        stdout
      end

      # Mutable state for diff parsing
      ParseState = Struct.new(:files, :current_file, :file_type) do
        HUNK_HEADER = /\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/
        PARSERS     = [
          ->(state, line) { %r{\A--- /dev/null}.match?(line) && state.file_type = :new },
          ->(state, line) { %r{\A--- a/}.match?(line) && state.file_type = :normal },
          lambda do |state, line|
            next unless %r{\A\+\+\+ /dev/null}.match?(line)

            state.current_file = nil
            state.file_type = :deleted
          end,
          lambda do |state, line|
            file_match = %r{\A\+\+\+ b/(.*)}.match(line)
            next unless file_match

            state.current_file = file_match[1].strip
            state.files[state.current_file] = state.class::ALL if state.file_type.equal?(:new)
            state.file_type = :normal
          end,
          lambda do |state, line|
            hunk_match = HUNK_HEADER.match(line)
            next unless hunk_match
            next unless state.current_file
            next if state.files[state.current_file].equal?(state.class::ALL)

            count = hunk_match[2] ? hunk_match[2].to_i : 1
            next if count.zero?

            start_line = hunk_match[1].to_i
            (state.files[state.current_file] ||= []) << (start_line..(start_line + count - 1))
          end
        ].freeze

        def self.parse(output)
          new({}, nil, :normal).tap { |state| output.each_line(&state.method(:consume_line)) }.files
        end

        def consume_line(line)
          PARSERS.each do |parser|
            break if parser.call(self, line)
          end
        end
      end
      ParseState::ALL = :all
      private_constant :ParseState

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
