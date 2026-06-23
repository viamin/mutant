# frozen_string_literal: true

RSpec.describe Mutant::AST::Regexp::Transformer do
  before do
    stub_const("#{described_class}::REGISTRY", Mutant::Registry.new)
  end

  it 'registers types to a given class' do
    klass = Class.new(described_class) { register(:regexp_bos_anchor) }

    expect(described_class.lookup(:regexp_bos_anchor)).to be(klass)
  end

  it 'rejects duplicate registrations' do
    Class.new(described_class) { register(:regexp_bos_anchor) }

    expect { Class.new(described_class) { register(:regexp_bos_anchor) } }
      .to raise_error(Mutant::Registry::RegistryError)
      .with_message('Duplicate type registration: :regexp_bos_anchor')
  end
end

RSpec.describe Mutant::AST::Regexp::Transformer::Quantifier::ASTToExpression do
  describe '#transform_nested_interval' do
    let(:node) do
      s(:regexp_possessive_interval, 1, 3, s(:regexp_dot_meta))
    end

    let(:object) { described_class.send(:new, node) }
    let(:expression) do
      Object.new.tap do |object|
        def object.to_s = '.'

        def object.to_str = raise 'unexpected to_str'
      end
    end
    let(:parsed_expression) { instance_double(::Regexp::Expression::Base) }
    let(:parsed_root)       { instance_double(::Regexp::Expression::Root, expressions: [parsed_expression]) }
    it 'builds nested interval sources from the subject string representation' do
      expect(Mutant::AST::Regexp)
        .to receive(:to_expression_unfrozen)
        .with(s(:regexp_dot_meta))
        .and_return(expression)

      expect(Mutant::AST::Regexp)
        .to receive(:parse)
        .with('.{1,3}+')
        .and_return(parsed_root)

      expect(object.send(:transform_nested_interval)).to be(parsed_expression)
    end
  end
end
