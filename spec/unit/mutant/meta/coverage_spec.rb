# frozen_string_literal: true

RSpec.describe Mutant::Meta::Coverage do
  describe '.render' do
    subject(:render) { described_class.render }

    let(:path) { Pathname.new('docs/mutator-coverage.md') }

    it 'matches the checked-in coverage tracker' do
      expect(render).to eql(path.read)
    end
  end

  describe '.entries' do
    subject(:entries) { described_class.entries }

    def normalized_source(source)
      Unparser.unparse(Unparser.parse(source))
    end

    def generated_sources(source)
      Mutant::Mutator
        .mutate(Unparser.parse(source))
        .map { |node| Unparser.unparse(node) }
    end

    it 'tracks the requested category set' do
      expect(entries.map(&:id)).to eql(
        %w[
          pattern-matching
          compound-assignment
          enumerable-selectors
          bang-reductions
          boolean-control-flow
          rescue-ensure
          empty-collection-returns
          bitwise-operators
          integer-literal-boundary
          string-symbol-literal
        ]
      )
    end

    described_class.entries.each do |entry|
      context entry.title do
        let(:generated) { generated_sources(entry.source) }

        it 'exercises the category in a smoke fixture' do
          expect(generated).not_to be_empty
        end

        it 'matches the tracked coverage assertion' do
          case entry.assertion
          when :include
            expect(generated).to include(normalized_source(entry.mutation))
          when :exclude
            expect(generated).not_to include(normalized_source(entry.mutation))
          when :generic
            node_type = Unparser.parse(entry.source).type

            expect(Mutant::Mutator::REGISTRY.lookup(node_type)).to be(Mutant::Mutator::Node::Generic)
          else
            fail "Unknown assertion: #{entry.assertion.inspect}"
          end
        end
      end
    end
  end
end
