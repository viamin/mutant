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
        return true if ranges.equal?(ALL)

        ranges.any? { |range| ranges_overlap?(range, line_range) }
      end

    private

      ALL = :all

      # Pre-computed diff hunks from git diff
      #
      # @return [Hash{String => Array<Range<Integer>>}]
      #
      # @raise [RepositoryError]
      #   when git command failed
      def diff_hunks
        command = %W[git diff #{resolved_to}...#{resolved_from}]

        stdout, status = config.open3.capture2(*command, binmode: true)

        fail RepositoryError, "Command #{command} failed!" unless status.success?

        parse_diff(stdout)
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
        command = %W[git rev-parse --verify #{ref}]

        stdout, status = config.open3.capture2(*command, binmode: true)

        fail RepositoryError, "Command #{command} failed!" unless status.success?

        stdout.strip
      end

      NEW_FILE_HEADER    = %r{\A--- /dev/null}
      OLD_FILE_HEADER    = %r{\A--- a/}
      DELETE_FILE_HEADER = %r{\A\+\+\+ /dev/null}
      NEW_FILE_PATH      = %r{\A\+\+\+ b/(.*)}
      HUNK_HEADER        = /\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/

      # Parse unified diff output into file-to-ranges mapping
      #
      # @param [String] output
      #
      # @return [Hash{String => Array<Range<Integer>>}]
      def parse_diff(output)
        state = ParseState.new

        output.each_line do |line|
          parse_diff_line(state, line)
        end

        state.files
      end

      # Parse a single diff line and update state
      #
      # @param [ParseState] state
      # @param [String] line
      #
      # @return [undefined]
      def parse_diff_line(state, line)
        case line
        when NEW_FILE_HEADER
          state.file_type = :new
        when OLD_FILE_HEADER
          state.file_type = :normal
        when DELETE_FILE_HEADER
          state.current_file = nil
          state.file_type = :deleted
        when NEW_FILE_PATH
          state.current_file = Regexp.last_match(1).strip
          if state.file_type.equal?(:new)
            state.files[state.current_file] = ALL
          end
          state.file_type = :normal
        when HUNK_HEADER
          register_hunk(state, Regexp.last_match(1), Regexp.last_match(2))
        end
      end

      # Register a hunk range from captured match groups
      #
      # @param [ParseState] state
      # @param [String, nil] start_match
      # @param [String, nil] count_match
      #
      # @return [undefined]
      def register_hunk(state, start_match, count_match)
        return unless state.current_file
        return if state.files[state.current_file].equal?(ALL)

        start_line = start_match.to_i
        count = count_match ? count_match.to_i : 1
        return if count.zero?

        state.files[state.current_file] ||= []
        state.files[state.current_file] << (start_line..(start_line + count - 1))
      end

      # Mutable state for diff parsing
      class ParseState
        attr_accessor :current_file, :file_type
        attr_reader   :files

        def initialize
          @files = {}
          @current_file = nil
          @file_type = :normal
        end
      end
      private_constant :ParseState

      # Test if two ranges overlap
      #
      # @param [Range<Integer>] range_a
      # @param [Range<Integer>] range_b
      #
      # @return [Boolean]
      def ranges_overlap?(range_a, range_b)
        range_a.begin <= range_b.end && range_b.begin <= range_a.end
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
