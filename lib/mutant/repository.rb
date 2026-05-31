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

        ranges = diff_hunks.fetch(path.relative_path_from(config.pathname.pwd).to_s, nil)

        return false unless ranges
        return true if ranges.equal?(ParseState::ALL)

        ranges.any? { |range| ranges_overlap?(range, line_range) }
      end

    private

      def diff_hunks
        ParseState.parse(command_output(%W[git diff #{resolved_from}...#{resolved_to}]))
      end
      memoize :diff_hunks

      def resolved_from
        resolve_ref(from)
      end
      memoize :resolved_from

      def resolved_to
        resolve_ref(to)
      end
      memoize :resolved_to

      def resolve_ref(ref)
        command_output(%W[git rev-parse --verify #{ref}]).strip
      end

      def command_output(command)
        stdout, status = config.open3.capture2(*command, binmode: true)

        fail RepositoryError, "Command #{command} failed!" unless status.success?

        stdout
      end

      def ranges_overlap?(left, right)
        left.begin <= right.end && right.begin <= left.end
      end

      ParseState = Struct.new(:files, :current_file, :file_type) do
        HUNK_HEADER = /\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/

        def self.parse(output)
          new({}, nil, :normal).tap do |state|
            output.each_line { |line| state.parse_diff_line(line) }
          end.files
        end

        def parse_diff_line(line)
          case line
          when %r{\A--- /dev/null}
            self.file_type = :new
          when %r{\A--- a/}
            self.file_type = :normal
          when %r{\A\+\+\+ /dev/null}
            self.current_file = nil
            self.file_type    = :deleted
          when %r{\A\+\+\+ b/(.*)}
            self.current_file = Regexp.last_match(1).strip
            files[current_file] = self.class::ALL if file_type.equal?(:new)
            self.file_type = :normal
          else
            register_hunk(line)
          end
        end

        def register_hunk(line)
          return unless current_file
          return if files[current_file].equal?(self.class::ALL)

          match = HUNK_HEADER.match(line)
          return unless match

          count = Integer(match[2] || 1)
          return if count.zero?

          start_line = Integer(match[1])
          (files[current_file] ||= []) << (start_line..(start_line + count - 1))
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
