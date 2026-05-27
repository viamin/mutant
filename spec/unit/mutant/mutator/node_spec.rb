# frozen_string_literal: true

aggregate = Hash.new { |hash, key| hash[key] = [] }

Mutant::Meta::Example::ALL
  .each_with_object(aggregate) do |example, agg|
    example.types.each do |type|
      agg[Mutant::Mutator::REGISTRY.lookup(type)] << example
    end
  end

aggregate.each do |mutator, examples|
  RSpec.describe mutator do
    it 'generates expected mutations' do
      examples.each do |example|
        verification = example.verification
        fail verification.error_report unless verification.success?
      end
    end
  end
end

RSpec.describe Mutant::Mutator::Node do
  describe 'internal DSL' do
    let(:klass) do
      Class.new(described_class) do
        children(:left, :right)

        def dispatch
          left
          emit_left(s(:nil))
          emit_right_mutations do |node|
            node.eql?(s(:nil))
          end
        end
      end
    end

    def apply
      klass.call(s(:and, s(:true), s(:true)))
    end

    specify do
      expect(apply).to eql(
        [
          s(:and, s(:nil), s(:true)),
          s(:and, s(:true), s(:nil))
        ].to_set
      )
    end
  end

  describe '#mutate_child' do
    let(:klass) do
      Class.new(described_class) do
        def dispatch; end
      end
    end

    context 'when the selected child has mutations' do
      let(:input)   { s(:send, s(:true), :foo) }
      let(:mutator) { klass.send(:new, input, nil) }
      let(:child)   { input.children.fetch(0) }
      let(:result)  { s(:send, s(:false), :foo) }

      before do
        allow(Mutant::Mutator).to receive(:mutate).with(child, mutator).and_return([s(:false)].to_set)
      end

      it 'emits filtered child mutations' do
        returned = mutator.send(:mutate_child, 0) { |mutation| mutation.eql?(s(:false)) }

        expect(returned).to eql([s(:false)].to_set)
        expect(mutator.output).to eql([result].to_set)
      end
    end

    context 'when no block is provided' do
      let(:input)   { s(:send, s(:true), :foo) }
      let(:mutator) { klass.send(:new, input, nil) }
      let(:child)   { input.children.fetch(0) }
      let(:result)  { s(:send, s(:false), :foo) }

      before do
        allow(Mutant::Mutator).to receive(:mutate).with(child, mutator).and_return([s(:false)].to_set)
      end

      it 'uses the default tautology filter' do
        returned = mutator.send(:mutate_child, 0)

        expect(returned).to eql([s(:false)].to_set)
        expect(mutator.output).to eql([result].to_set)
      end
    end

    context 'when the filter rejects the first mutation' do
      let(:input)   { s(:send, s(:true), :foo) }
      let(:mutator) { klass.send(:new, input, nil) }
      let(:child)   { input.children.fetch(0) }

      before do
        allow(Mutant::Mutator)
          .to receive(:mutate)
          .with(child, mutator)
          .and_return([s(:true), s(:false)].to_set)
      end

      it 'continues to later mutations' do
        returned = mutator.send(:mutate_child, 0) { |mutation| mutation.eql?(s(:false)) }

        expect(returned).to eql([s(:true), s(:false)].to_set)
        expect(mutator.output).to eql([s(:send, s(:false), :foo)].to_set)
      end
    end

    context 'when the filter rejects every mutation' do
      let(:input)   { s(:send, s(:true), :foo) }
      let(:mutator) { klass.send(:new, input, nil) }
      let(:child)   { input.children.fetch(0) }
      let(:calls)   { [] }

      before do
        allow(Mutant::Mutator)
          .to receive(:mutate)
          .with(child, mutator)
          .and_return([s(:false)])
      end

      it 'does not emit rejected mutations and still evaluates the block' do
        returned = mutator.send(:mutate_child, 0) do |mutation|
          calls << mutation
          false
        end

        expect(returned).to eql([s(:false)])
        expect(calls).to eql([s(:false)])
        expect(mutator.output).to eql(Set.new)
      end
    end

    context 'when the selected child is nil' do
      let(:input)   { s(:send, nil, :foo) }
      let(:mutator) { klass.send(:new, input, nil) }

      it 'returns nil without mutating the child' do
        expect(Mutant::Mutator).not_to receive(:mutate)

        expect(mutator.send(:mutate_child, 0)).to be(nil)
        expect(mutator.output).to eql(Set.new)
      end
    end
  end
end

RSpec.describe Mutant::Mutator::Node::Dstr do
  describe '.call' do
    context 'with legacy raw string children' do
      let(:input) { s(:dstr, 'foo', s(:begin, s(:send, nil, :bar)), 'baz') }
      let(:child) { input.children.fetch(1) }

      before do
        expect(Mutant::Mutator)
          .to receive(:mutate)
          .once
          .with(child, kind_of(described_class))
          .and_return([s(:nil)].to_set)
      end

      it 'mutates only AST children and keeps singleton mutations' do
        expect(described_class.call(input)).to eql(
          [
            s(:dstr, 'foo', s(:begin, s(:nil)), 'baz'),
            s(:nil),
            s(:self)
          ].to_set
        )
      end
    end

    context 'when a child mutation is not already wrapped' do
      let(:input) { parse('"foo#{bar}baz"') }
      let(:child) { input.children.fetch(1) }

      before do
        allow(Mutant::Mutator).to receive(:mutate).and_return(Set.new)
        allow(Mutant::Mutator)
          .to receive(:mutate)
          .with(child, kind_of(described_class))
          .and_return([s(:send, nil, :qux)].to_set)
      end

      it 'wraps the replacement in a begin node' do
        expect(described_class.call(input)).to include(
          s(:dstr, s(:str, 'foo'), s(:begin, s(:send, nil, :qux)), s(:str, 'baz'))
        )
      end
    end

    context 'when a child mutation is already a string node' do
      let(:input) { parse('"foo#{bar}baz"') }
      let(:child) { input.children.fetch(1) }

      before do
        allow(Mutant::Mutator).to receive(:mutate).and_return(Set.new)
        allow(Mutant::Mutator)
          .to receive(:mutate)
          .with(child, kind_of(described_class))
          .and_return([s(:str, 'qux')].to_set)
      end

      it 'does not wrap the replacement' do
        expect(described_class.call(input)).to include(
          s(:dstr, s(:str, 'foo'), s(:str, 'qux'), s(:str, 'baz'))
        )
      end
    end
  end
end

RSpec.describe Mutant::Mutator::Node::Dsym do
  describe '.call' do
    context 'with legacy raw string children' do
      let(:input) { s(:dsym, 'foo', s(:begin, s(:send, nil, :bar)), 'baz') }
      let(:child) { input.children.fetch(1) }

      before do
        expect(Mutant::Mutator)
          .to receive(:mutate)
          .once
          .with(child, kind_of(described_class))
          .and_return([s(:nil)].to_set)
      end

      it 'mutates only AST children and keeps singleton mutations' do
        expect(described_class.call(input)).to eql(
          [
            s(:dsym, 'foo', s(:begin, s(:nil)), 'baz'),
            s(:nil),
            s(:self)
          ].to_set
        )
      end
    end

    context 'when a child mutation is not already wrapped' do
      let(:input) { parse(':"foo#{bar}baz"') }
      let(:child) { input.children.fetch(1) }

      before do
        allow(Mutant::Mutator).to receive(:mutate).and_return(Set.new)
        allow(Mutant::Mutator)
          .to receive(:mutate)
          .with(child, kind_of(described_class))
          .and_return([s(:send, nil, :qux)].to_set)
      end

      it 'wraps the replacement in a begin node' do
        expect(described_class.call(input)).to include(
          s(:dsym, s(:str, 'foo'), s(:begin, s(:send, nil, :qux)), s(:str, 'baz'))
        )
      end
    end

    context 'when a child mutation is already a string node' do
      let(:input) { parse(':"foo#{bar}baz"') }
      let(:child) { input.children.fetch(1) }

      before do
        allow(Mutant::Mutator).to receive(:mutate).and_return(Set.new)
        allow(Mutant::Mutator)
          .to receive(:mutate)
          .with(child, kind_of(described_class))
          .and_return([s(:str, 'qux')].to_set)
      end

      it 'does not wrap the replacement' do
        expect(described_class.call(input)).to include(
          s(:dsym, s(:str, 'foo'), s(:str, 'qux'), s(:str, 'baz'))
        )
      end
    end
  end
end

RSpec.describe Mutant::Mutator::Node::ProcargZero do
  describe '.call' do
    context 'with a symbol argument' do
      it 'prefixes the argument name once' do
        expect(described_class.call(s(:procarg0, :a))).to eql(
          [s(:procarg0, s(:arg, :_a))].to_set
        )
      end

      it 'does not emit a mutation for ignored arguments' do
        expect(described_class.call(s(:procarg0, :_a))).to eql(Set.new)
      end
    end

    context 'with an arg node argument' do
      it 'emits the nested arg mutation' do
        expect(described_class.call(s(:procarg0, s(:arg, :a)))).to eql(
          [s(:procarg0, s(:arg, :_a))].to_set
        )
      end

      it 'unwraps nested node children when present' do
        expect(described_class.call(s(:procarg0, s(:mlhs, s(:arg, :a))))).to eql(
          [
            s(:procarg0, s(:mlhs, s(:arg, :_a))),
            s(:procarg0, s(:arg, :a))
          ].to_set
        )
      end

      it 'unwraps subclasses of Parser::AST::Node' do
        subclass     = Class.new(Parser::AST::Node)
        inner        = subclass.new(:arg, [:a])
        input        = s(:procarg0, Parser::AST::Node.new(:mlhs, [inner]))
        result       = described_class.call(input)

        expect(result).to include(s(:procarg0, inner))
      end
    end
  end
end

RSpec.describe Mutant::Mutator::Node::Numblock do
  let(:klass) { described_class }

  describe '.call' do
    it 'emits the receiver send for non-lambda numblocks' do
      expect(described_class.call(parse('foo { _1 }'))).to include(s(:send, nil, :foo))
    end

    it 'does not emit the lambda node directly' do
      expect(described_class.call(parse('-> { _1 }'))).not_to include(s(:lambda))
    end

    it 'emits standalone body mutations when the body has no control flow or numbered parameter' do
      expect(described_class.call(parse('foo { bar }'))).to include(s(:send, nil, :bar))
    end

    it 'does not emit standalone body mutations for control flow' do
      expect(described_class.call(parse('foo { break }'))).not_to include(s(:break))
    end

    it 'downgrades to a regular block when a mutation removes numbered parameter usage' do
      expect(described_class.call(parse('foo { _1 }'))).to include(
        s(:block, s(:send, nil, :foo), s(:args), nil),
        s(:block, s(:send, nil, :foo), s(:args), s(:send, nil, :raise))
      )
    end

    it 'preserves numblock output when a nested numbered parameter remains in use' do
      expect(described_class.call(parse('foo { [_1] }'))).to include(
        s(:numblock, s(:send, nil, :foo), 1, s(:lvar, :_1))
      )
    end
  end

  describe '#mutate_body' do
    context 'when the numblock has no body' do
      let(:mutator) { klass.send(:new, s(:numblock, s(:send, nil, :foo), 1, nil), nil) }

      it 'emits the standard body replacements and returns nil' do
        expect(mutator.__send__(:mutate_body)).to be(nil)
        expect(mutator.output).to include(
          s(:block, s(:send, nil, :foo), s(:args), nil),
          s(:block, s(:send, nil, :foo), s(:args), s(:send, nil, :raise))
        )
        expect(mutator.output).not_to include(s(:send, nil, :bar))
      end
    end

    context 'when the numblock body has no control flow or numbered parameter usage' do
      let(:body)    { s(:send, nil, :bar) }
      let(:mutator) { klass.send(:new, s(:numblock, s(:send, nil, :foo), 1, body), nil) }

      it 'emits the body, body mutations and receiver mutations' do
        returned = mutator.__send__(:mutate_body)

        expect(returned).to eql(mutator.output)
        expect(mutator.output).to include(
          s(:send, nil, :bar),
          s(:block, s(:send, nil, :foo), s(:args), nil),
          s(:block, s(:send, nil, :foo), s(:args), s(:send, nil, :raise)),
          s(:block, s(:send, nil, :foo), s(:args), s(:nil)),
          s(:block, s(:send, nil, :foo), s(:args), s(:self)),
          s(:send, s(:send, nil, :foo), :bar)
        )
      end
    end

    context 'when the numblock body has control flow' do
      let(:body)    { s(:break) }
      let(:mutator) { klass.send(:new, s(:numblock, s(:send, nil, :foo), 1, body), nil) }

      it 'skips emitting the standalone body' do
        expect(mutator.__send__(:mutate_body)).to be(nil)
        expect(mutator.output).to include(
          s(:block, s(:send, nil, :foo), s(:args), nil),
          s(:block, s(:send, nil, :foo), s(:args), s(:send, nil, :raise)),
          s(:block, s(:send, nil, :foo), s(:args), s(:nil)),
          s(:block, s(:send, nil, :foo), s(:args), s(:self))
        )
        expect(mutator.output).not_to include(s(:break))
      end
    end

    context 'when the numblock body still uses numbered parameters' do
      let(:body)    { s(:lvar, :_1) }
      let(:mutator) { klass.send(:new, s(:numblock, s(:send, nil, :foo), 1, body), nil) }

      it 'skips emitting the standalone body' do
        expect(mutator.__send__(:mutate_body)).to be(nil)
        expect(mutator.output).to include(
          s(:block, s(:send, nil, :foo), s(:args), nil),
          s(:block, s(:send, nil, :foo), s(:args), s(:send, nil, :raise)),
          s(:block, s(:send, nil, :foo), s(:args), s(:nil)),
          s(:block, s(:send, nil, :foo), s(:args), s(:self))
        )
        expect(mutator.output).not_to include(s(:lvar, :_1))
      end
    end
  end

  describe '#numbered_parameter?' do
    let(:mutator) { klass.send(:new, parse('foo { _1 }'), nil) }

    it 'accepts numbered parameters' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, :_1))).to be(true)
    end

    it 'rejects regular local variables' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, :value))).to be(false)
    end

    it 'rejects nil candidates' do
      expect(mutator.__send__(:numbered_parameter?, nil)).to be(false)
    end

    it 'rejects truthy non-node candidates' do
      expect(mutator.__send__(:numbered_parameter?, :_1)).to be(false)
    end

    it 'rejects non-local-variable nodes' do
      expect(mutator.__send__(:numbered_parameter?, s(:send, nil, :_1))).to be(false)
    end

    it 'rejects non-local-variable nodes even when their child looks numbered' do
      expect(mutator.__send__(:numbered_parameter?, s(:procarg0, :_1))).to be(false)
    end

    it 'accepts multi-digit numbered parameters' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, :_12))).to be(true)
    end

    it 'rejects underscore-prefixed names without digits only' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, :_value))).to be(false)
    end

    it 'rejects digit-only names without a leading underscore' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, :"12"))).to be(false)
    end

    it 'rejects names with trailing non-digit characters' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, :_1value))).to be(false)
    end

    it 'rejects names with trailing digits after non-digit characters' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, :_a1))).to be(false)
    end

    it 'rejects local variables whose name is not string-coercible to a numbered parameter' do
      expect(mutator.__send__(:numbered_parameter?, s(:lvar, 1))).to be(false)
    end

    it 'recognizes subclasses of Parser::AST::Node' do
      subclass = Class.new(Parser::AST::Node)
      node = subclass.new(:lvar, [:_1])
      expect(mutator.__send__(:numbered_parameter?, node)).to be(true)
    end
  end

  describe '#numbered_parameter_used?' do
    let(:mutator) { klass.send(:new, parse('foo { _1 }'), nil) }

    it 'returns false for non-node candidates' do
      expect(mutator.__send__(:numbered_parameter_used?, :_1)).to be(false)
    end

    it 'finds nested numbered parameters' do
      expect(mutator.__send__(:numbered_parameter_used?, s(:array, s(:lvar, :_1)))).to be(true)
    end

    it 'returns true for direct numbered parameters' do
      expect(mutator.__send__(:numbered_parameter_used?, s(:lvar, :_1))).to be(true)
    end

    it 'returns false when no numbered parameters are present' do
      expect(mutator.__send__(:numbered_parameter_used?, s(:array, s(:lvar, :value)))).to be(false)
    end

    it 'recognizes subclasses of Parser::AST::Node' do
      subclass = Class.new(Parser::AST::Node)
      node = subclass.new(:lvar, [:_1])
      expect(mutator.__send__(:numbered_parameter_used?, node)).to be(true)
    end
  end
end
