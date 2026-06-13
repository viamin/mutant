# frozen_string_literal: true

module Mutant
  module Repository
    RepositoryError = Class.new(RuntimeError)

    class SubjectFilter
      include Adamantium, Concord.new(:diff)

      def call(subject)
        diff.touches?(SubjectLocation.from_subject(subject))
      end

    end # SubjectFilter

    SubjectLocation = Struct.new(:path, :line_range) do
      def self.from_subject(subject)
        new(subject.source_path, subject.source_lines)
      end
    end

    ChangedLineRanges = Struct.new(:all, :ranges) do
      def self.empty
        new(false, [])
      end

      def add(range)
        ranges << range
      end

      def touches?(line_range)
        all || ranges.any? { |range| range.begin <= line_range.end && line_range.begin <= range.end }
      end
    end
    ChangedLineRanges::ALL = ChangedLineRanges.new(true, EMPTY_ARRAY).freeze

    class DiffHunkParser
      HUNK_HEADER = /\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/

      def self.call(output)
        State.new(files: {}).tap do |state|
          output.each_line { |line| state.parse_line(line) }
        end.files
      end

      State = Struct.new(:files, :current_file, :file_type, keyword_init: true) do
        def parse_line(line)
          handle_new_file(line) ||
            handle_existing_file(line) ||
            handle_deleted_file(line) ||
            handle_current_file(line) ||
            register_hunk(line)
        end

        def register_hunk(line)
          match = HUNK_HEADER.match(line)
          return unless match && current_file && !all_subjects_file?

          range = hunk_range(match)
          file_ranges << range if range
        end

        def handle_new_file(line)
          self.file_type = :new if line.start_with?('--- /dev/null')
        end

        def handle_existing_file(line)
          self.file_type = :normal if line.start_with?('--- a/')
        end

        def handle_deleted_file(line)
          return unless line.start_with?('+++ /dev/null')

          self.current_file = nil
          self.file_type    = :deleted
        end

        def handle_current_file(line)
          match = %r{\A\+\+\+ b/(.*)}.match(line)
          return unless match

          self.current_file = match[1].strip
          files[current_file] = Repository::ChangedLineRanges::ALL if file_type.equal?(:new)
          self.file_type = :normal
        end

        def all_subjects_file?
          files[current_file].equal?(Repository::ChangedLineRanges::ALL)
        end

        def hunk_range(match)
          count = Integer(match[2] || 1)
          return if count.zero?

          start_line = Integer(match[1])
          start_line..(start_line + count - 1)
        end

        def file_ranges
          (files[current_file] ||= Repository::ChangedLineRanges.empty).ranges
        end
      end
    end

    class Diff
      include Adamantium, Anima.new(:config, :from, :to)

      HEAD = 'HEAD'

      def touches?(location)
        touched_ranges(location.path)&.touches?(location.line_range) || false
      end

      def diff_hunks
        DiffHunkParser.call(command_output(%W[git diff #{resolved_from}...#{resolved_to}]))
      end
      memoize :diff_hunks

      def touched_ranges(path)
        return unless within_working_directory?(path)

        diff_hunks.fetch(path.relative_path_from(config.pathname.pwd).to_s, nil)
      end

    private

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

      def within_working_directory?(path)
        working_directory = config.pathname.pwd
        path.ascend { |parent| return true if working_directory.eql?(parent) }
      end

    end # Diff
  end # Repository
end # Mutant
