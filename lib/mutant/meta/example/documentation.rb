# frozen_string_literal: true

module Mutant
  module Meta
    class Example
      # Renders documentation for shipped mutator families
      class Documentation
        META_DIRECTORY_NAME = 'meta'
        ROOT_PATH           = Pathname.new(__dir__).join('../../../../').expand_path.freeze
        META_PATH           = ROOT_PATH.join(META_DIRECTORY_NAME).freeze

        HEADER = <<~MARKDOWN.freeze
          # Mutators

          This page summarizes the currently shipped mutator families.

          It is intentionally concise: each section shows the first `meta/` example for a given operator family and one representative diff. The `meta/` fixtures remain the exhaustive behavioral specification that the test suite verifies.
        MARKDOWN

        def self.render(examples = Example::ALL)
          new(examples).render
        end

        def initialize(examples)
          @examples = examples
        end

        def render
          ([HEADER.chomp] + sections).join("\n\n") + "\n"
        end

      private

        attr_reader :examples

        def groups
          examples.group_by { |example| example.types.to_a.sort }
        end

        def sections
          groups
            .sort_by { |types, _examples| types.join('/') }
            .map { |types, examples| section(types, examples.first) }
        end

        def section(types, example)
          [
            "## #{self.class.type_label(types)}",
            "Representative source from `#{self.class.relative_meta_path(example)}`:",
            self.class.fenced('ruby', example.source),
            'Representative diff:',
            self.class.fenced('diff', representative_diff(example))
          ].join("\n\n")
        end

        def representative_diff(example)
          source = Unparser.unparse(representative_mutation(example))

          Mutant::Diff.build(example.source, source).diff || source
        end

        def representative_mutation(example)
          example.expected.find do |node|
            !self.class.singleton_mutation?(node)
          end || example.expected.first
        end

        def self.type_label(types)
          return 'special forms' if types.empty?

          types.map(&:to_s).join(' / ')
        end

        def self.relative_meta_path(example)
          path      = canonical_path(Pathname.new(example.file))
          meta_path = canonical_path(META_PATH)

          unless within_directory?(path, meta_path)
            fail ArgumentError, "Example file is outside #{meta_path}: #{path}"
          end

          "#{META_DIRECTORY_NAME}/#{path.relative_path_from(meta_path)}"
        end

        def self.singleton_mutation?(node)
          [[:nil, []], [:self, []]].include?([node.type, node.children])
        end

        def self.fenced(language, source)
          ["```#{language}", source, '```'].join("\n")
        end

        def self.canonical_path(path)
          path.exist? ? path.realpath : path.expand_path.cleanpath
        end

        def self.within_directory?(path, directory)
          path.ascend.any?(&directory.method(:eql?))
        end
      end
    end
  end
end
