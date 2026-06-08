# frozen_string_literal: true

module Mutant
  module Meta
    # Tracks mutator coverage for modern Ruby operator categories
    class Coverage
      def self.entries
        COVERAGE_ENTRIES
      end

      def self.render(entries = COVERAGE_ENTRIES)
        new(entries).render
      end

      def initialize(entries)
        @entries = entries
      end

      def render
        [
          '# Mutator Coverage',
          '',
          'This page tracks the requested modern-Ruby mutator categories against',
          'the currently shipped operator set.',
          '',
          'Status values:',
          '',
          '* `covered` means the repository already ships a representative operator for the category.',
          '* `partial` means related operators exist, but the category in the meta-issue is only partly covered.',
          '* `gap` means the category still needs a dedicated operator issue or an',
          '  explicit decision not to implement it.',
          '',
          *COVERAGE_TABLE_HEADER,
          *rows
        ].join("\n") + "\n"
      end

    private

      attr_reader :entries

      def rows
        entries.map do |entry|
          smoke = [entry.source.inspect, entry.mutation].compact.join(' -> ')

          [
            '|',
            self.class.escape(entry.title),
            "| `#{entry.status}` |",
            "`#{self.class.escape(smoke)}` |",
            "#{self.class.escape(entry.notes)} |"
          ].join(' ')
        end
      end

      def self.escape(value)
        value.gsub('\\', '\\\\').gsub('|', '\|')
      end
    end
  end
end
