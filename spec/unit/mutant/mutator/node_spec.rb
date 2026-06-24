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

  describe 'scope detection' do
    let(:klass) do
      Class.new(described_class) do
        def dispatch; end
      end
    end

    let(:mutator) { klass.send(:new, s(:self), nil) }

    describe '#hard_scope_boundary?' do
      it 'returns true for instance method definitions' do
        expect(mutator.send(:hard_scope_boundary?, parse('def test; value; end'))).to be(true)
      end

      it 'returns true for singleton method definitions' do
        expect(mutator.send(:hard_scope_boundary?, parse('def self.test; value; end'))).to be(true)
      end

      it 'returns false for non-method nodes' do
        expect(mutator.send(:hard_scope_boundary?, parse('foo { value }'))).to be(false)
      end
    end

    describe '#local_variable_used_in_node?' do
      it 'returns false for non-node candidates' do
        expect(mutator.send(:local_variable_used_in_node?, :value, :value)).to be(false)
      end

      it 'returns true for matching local-variable reads' do
        expect(mutator.send(:local_variable_used_in_node?, s(:lvar, :value), :value)).to be(true)
      end

      it 'accepts subclasses of Parser::AST::Node' do
        subclass = Class.new(Parser::AST::Node)

        expect(mutator.send(:local_variable_used_in_node?, subclass.new(:lvar, [:value]), :value)).to be(true)
      end

      it 'returns false for non-matching local-variable reads' do
        expect(mutator.send(:local_variable_used_in_node?, s(:lvar, :other), :value)).to be(false)
      end

      it 'returns false for non-local-variable nodes with matching children' do
        expect(mutator.send(:local_variable_used_in_node?, s(:sym, :value), :value)).to be(false)
      end

      it 'searches recursively through child nodes' do
        candidate = s(:array, s(:send, nil, :foo), s(:lvar, :value))

        expect(mutator.send(:local_variable_used_in_node?, candidate, :value)).to be(true)
      end

      it 'returns false when recursive children do not use the name' do
        candidate = s(:array, s(:send, nil, :foo))

        expect(mutator.send(:local_variable_used_in_node?, candidate, :value)).to be(false)
      end

      it 'stops at nested instance method boundaries' do
        expect(mutator.send(:local_variable_used_in_node?, parse('def test; value; end'), :value)).to be(false)
      end

      it 'stops at nested singleton method boundaries' do
        expect(mutator.send(:local_variable_used_in_node?, parse('def self.test; value; end'), :value)).to be(false)
      end

      it 'returns false when a block argument shadows the name' do
        expect(mutator.send(:local_variable_used_in_node?, parse('foo { |value| value }'), :value)).to be(false)
      end

      it 'still traverses a shadowing block send in the outer scope' do
        candidate = s(:block, s(:send, s(:lvar, :value), :each), s(:args, s(:arg, :value)), s(:lvar, :value))

        expect(mutator.send(:local_variable_used_in_node?, candidate, :value)).to be(true)
      end

      it 'returns false when a numblock parameter shadows the name' do
        expect(mutator.send(:local_variable_used_in_node?, parse('foo { _1 }'), :_1)).to be(false)
      end

      it 'still traverses a shadowing numblock send in the outer scope' do
        candidate = s(:numblock, s(:send, s(:lvar, :value), :then), 1, s(:lvar, :_1))

        expect(mutator.send(:local_variable_used_in_node?, candidate, :value)).to be(true)
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

RSpec.describe Mutant::Mutator::Node::Argument do
  describe '.call' do
    it 'does not rename used block arguments' do
      input  = parse('foo { |value| "#{value}" }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).not_to include(
        s(:block, s(:send, nil, :foo), s(:args, s(:arg, :_value)), body)
      )
    end

    it 'renames outer block argument when shadowed by inner block argument' do
      input  = parse('foo { |value| bar { |value| value } }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).to include(
        s(:block, s(:send, nil, :foo), s(:args, s(:procarg0, s(:arg, :_value))), body)
      )
    end

    it 'renames outer block argument when nested method body uses the same local name' do
      input  = parse('foo { |value| def inner; value = 1; value; end }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).to include(
        s(:block, s(:send, nil, :foo), s(:args, s(:procarg0, s(:arg, :_value))), body)
      )
    end

    it 'renames outer block argument when nested singleton method body uses the same local name' do
      input  = parse('foo { |value| def self.inner; value = 1; value; end }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).to include(
        s(:block, s(:send, nil, :foo), s(:args, s(:procarg0, s(:arg, :_value))), body)
      )
    end

    it 'does not rename a required argument used in a default expression' do
      expect(Mutant::Mutator.mutate(parse('def foo(a, b = a); end'))).not_to include(
        s(:def, :foo, s(:args, s(:arg, :_a), s(:optarg, :b, s(:lvar, :a))), nil)
      )
    end

    it 'does not rename an unused underscore argument' do
      input  = parse('foo { |_value| }')
      result = Mutant::Mutator.mutate(input)

      expect(result).not_to include(
        s(:block, s(:send, nil, :foo), s(:args, s(:procarg0, s(:arg, :__value))), nil)
      )
    end

    it 'renames a regular unused argument' do
      expect(Mutant::Mutator.mutate(parse('def foo(bar); end'))).to include(
        s(:def, :foo, s(:args, s(:arg, :_bar)), nil)
      )
    end
  end

  describe '#skip?' do
    it 'skips underscore-prefixed names' do
      mutator = described_class.send(:new, s(:arg, :_value), nil)

      expect(mutator.__send__(:skip?)).to be(true)
    end

    it 'does not skip regular unused names' do
      mutator = described_class.send(:new, s(:arg, :value), nil)

      expect(mutator.__send__(:skip?)).to be(false)
    end

    it 'coerces non-symbol names before checking the underscore prefix' do
      mutator = described_class.send(:new, s(:arg, 42), nil)

      expect(mutator.__send__(:skip?)).to be(false)
    end

    it 'skips regular names that are used in the parent scope' do
      parent = Class.new(Mutant::Mutator::Node) { def dispatch; end }
        .send(:new, s(:def, :foo, s(:args, s(:arg, :value)), s(:lvar, :value)), nil)
      mutator = described_class.send(:new, s(:arg, :value), parent)

      expect(mutator.__send__(:skip?)).to be(true)
    end
  end
end

RSpec.describe Mutant::Mutator::Node::Arguments do
  describe '.call' do
    it 'does not remove used block arguments' do
      input  = parse('foo { |unit, length| "#{unit}^#{length}" }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).not_to include(
        s(:block, s(:send, nil, :foo), s(:args), body),
        s(:block, s(:send, nil, :foo), s(:args, s(:arg, :unit)), body),
        s(:block, s(:send, nil, :foo), s(:args, s(:arg, :length)), body)
      )
    end

    it 'removes outer block argument when shadowed by inner block argument' do
      input  = parse('foo { |value| bar { |value| value } }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).to include(
        s(:block, s(:send, nil, :foo), s(:args), body)
      )
    end

    it 'removes outer block argument when nested method body uses the same local name' do
      input  = parse('foo { |value| def inner; value = 1; value; end }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).to include(
        s(:block, s(:send, nil, :foo), s(:args), body)
      )
    end

    it 'removes outer block argument when nested singleton method body uses the same local name' do
      input  = parse('foo { |value| def self.inner; value = 1; value; end }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).to include(
        s(:block, s(:send, nil, :foo), s(:args), body)
      )
    end

    it 'does not remove a required argument used in a default expression' do
      expect(Mutant::Mutator.mutate(parse('def foo(a, b = a); end'))).not_to include(
        s(:def, :foo, s(:args, s(:optarg, :b, s(:lvar, :a))), nil)
      )
    end

    it 'does not remove a destructured block argument used in the body' do
      input  = parse('foo { |(value)| value }')
      body   = input.children.fetch(2)
      result = Mutant::Mutator.mutate(input)

      expect(result).not_to include(
        s(:block, s(:send, nil, :foo), s(:args), body)
      )
    end

    it 'emits an empty argument list when no argument is used' do
      expect(Mutant::Mutator.mutate(parse('def foo(a, b); end'))).to include(
        s(:def, :foo, s(:args), nil)
      )
    end

    it 'does not rename an argument that follows an optional argument' do
      expect(Mutant::Mutator.mutate(parse('def foo(a = 1, b); end'))).not_to include(
        s(:def, :foo, s(:args, s(:optarg, :a, s(:int, 1)), s(:arg, :_b)), nil)
      )
    end

    it 'does not rename an argument used in the method body' do
      expect(Mutant::Mutator.mutate(parse('def foo(value); value; end'))).not_to include(
        s(:def, :foo, s(:args, s(:arg, :_value)), s(:lvar, :value))
      )
    end
  end

  def scope_parent(node)
    Class.new(Mutant::Mutator::Node) { def dispatch; end }.send(:new, node, nil)
  end

  describe '#emit_argument_mutations' do
    it 'emits rename mutations for regular arguments' do
      mutator = described_class.send(:new, s(:args, s(:arg, :a)), nil)

      mutator.__send__(:emit_argument_mutations)

      expect(mutator.output).to include(s(:args, s(:arg, :_a)))
    end

    it 'suppresses rename mutations for arguments used in scope' do
      parent   = scope_parent(s(:def, :foo, s(:args, s(:arg, :value)), s(:lvar, :value)))
      mutator  = described_class.send(:new, s(:args, s(:arg, :value)), parent)

      mutator.__send__(:emit_argument_mutations)

      expect(mutator.output).not_to include(s(:args, s(:arg, :_value)))
    end

    it 'skips invalid replacements that would place an argument after an optional argument' do
      mutator = described_class.send(:new, s(:args, s(:optarg, :a, s(:int, 1)), s(:arg, :b)), nil)

      mutator.__send__(:emit_argument_mutations)

      expect(mutator.output).not_to include(
        s(:args, s(:optarg, :a, s(:int, 1)), s(:arg, :_b))
      )
    end

    it 'emits the required form of an optional argument placed before other arguments' do
      mutator = described_class.send(:new, s(:args, s(:optarg, :a, s(:int, 1)), s(:arg, :b)), nil)

      mutator.__send__(:emit_argument_mutations)

      expect(mutator.output).to include(s(:args, s(:arg, :a), s(:arg, :b)))
    end

    it 'emits default mutations following a skipped invalid replacement' do
      mutator = described_class.send(
        :new,
        s(:args, s(:optarg, :a, s(:int, 1)), s(:optarg, :b, s(:int, 2))),
        nil
      )

      mutator.__send__(:emit_argument_mutations)

      expect(mutator.output).to include(
        s(:args, s(:optarg, :a, s(:int, 1)), s(:optarg, :b, s(:nil)))
      )
    end
  end

  describe '#emit_argument_presence' do
    it 'emits an empty arguments node when no argument is used' do
      mutator = described_class.send(:new, s(:args, s(:arg, :a), s(:arg, :b)), nil)

      mutator.__send__(:emit_argument_presence)

      expect(mutator.output).to include(s(:args))
    end

    it 'emits single argument removals' do
      mutator = described_class.send(:new, s(:args, s(:arg, :a), s(:arg, :b), s(:arg, :c)), nil)

      mutator.__send__(:emit_argument_presence)

      expect(mutator.output).to include(s(:args, s(:arg, :a), s(:arg, :b)))
    end

    it 'wraps a single remaining destructured argument in a procarg node' do
      mutator = described_class.send(:new, s(:args, s(:arg, :a), s(:mlhs, s(:arg, :b))), nil)

      mutator.__send__(:emit_argument_presence)

      expect(mutator.output).to include(s(:args, s(:procarg0, s(:arg, :b))))
    end

    it 'does not emit an empty arguments node when an argument is used in scope' do
      parent   = scope_parent(s(:def, :foo, s(:args, s(:arg, :value)), s(:lvar, :value)))
      mutator  = described_class.send(:new, s(:args, s(:arg, :value)), parent)

      mutator.__send__(:emit_argument_presence)

      expect(mutator.output).not_to include(s(:args))
    end

    it 'emits removals of unused arguments after skipping used argument removals' do
      parent = scope_parent(
        s(:def, :foo, s(:args, s(:arg, :value), s(:arg, :other)), s(:lvar, :value))
      )
      mutator = described_class.send(:new, s(:args, s(:arg, :value), s(:arg, :other)), parent)

      mutator.__send__(:emit_argument_presence)

      expect(mutator.output).to include(s(:args, s(:arg, :value)))
    end
  end

  describe '#invalid_argument_replacement?' do
    let(:with_optional) do
      described_class.send(:new, s(:args, s(:optarg, :a, s(:int, 1)), s(:arg, :b)), nil)
    end
    let(:without_optional) do
      described_class.send(:new, s(:args, s(:arg, :a), s(:arg, :b)), nil)
    end

    it 'rejects a required argument placed after an optional argument' do
      expect(with_optional.__send__(:invalid_argument_replacement?, s(:arg, :b), 1)).to be(true)
    end

    it 'allows a required argument placed before any optional argument' do
      expect(with_optional.__send__(:invalid_argument_replacement?, s(:arg, :a), 0)).to be(false)
    end

    it 'allows non-argument replacements placed after an optional argument' do
      expect(
        with_optional.__send__(:invalid_argument_replacement?, s(:optarg, :b, s(:int, 1)), 1)
      ).to be(false)
    end

    it 'allows a required argument placed after a required argument' do
      expect(without_optional.__send__(:invalid_argument_replacement?, s(:arg, :b), 1)).to be(false)
    end
  end

  describe '#invalid_argument_presence?' do
    let(:parent) do
      scope_parent(
        s(:def, :foo, s(:args, s(:arg, :value), s(:arg, :other)), s(:lvar, :value))
      )
    end
    let(:mutator) { described_class.send(:new, s(:args, s(:arg, :value), s(:arg, :other)), parent) }

    it 'is invalid when a used argument is removed' do
      expect(mutator.__send__(:invalid_argument_presence?, [s(:arg, :other)])).to be(true)
    end

    it 'is valid when only an unused argument is removed' do
      expect(mutator.__send__(:invalid_argument_presence?, [s(:arg, :value)])).to be(false)
    end

    it 'is valid when no argument is removed' do
      expect(
        mutator.__send__(:invalid_argument_presence?, [s(:arg, :value), s(:arg, :other)])
      ).to be(false)
    end
  end

  describe '#local_variable_used_argument?' do
    it 'returns true when the argument name is used in the parent scope' do
      parent  = scope_parent(s(:def, :foo, s(:args, s(:arg, :value)), s(:lvar, :value)))
      mutator = described_class.send(:new, s(:args, s(:arg, :value)), parent)

      expect(mutator.__send__(:local_variable_used_argument?, s(:arg, :value))).to be(true)
    end

    it 'returns false when the argument name is unused in the parent scope' do
      parent  = scope_parent(s(:def, :foo, s(:args, s(:arg, :value)), nil))
      mutator = described_class.send(:new, s(:args, s(:arg, :value)), parent)

      expect(mutator.__send__(:local_variable_used_argument?, s(:arg, :value))).to be(false)
    end
  end

  describe '#removed_argument_names' do
    let(:mutator) do
      described_class.send(:new, s(:args, s(:arg, :a), s(:arg, :b)), nil)
    end

    it 'returns the names of arguments absent from the mutated children' do
      expect(mutator.__send__(:removed_argument_names, [s(:arg, :a)])).to eql([:b])
    end

    it 'returns no names when no argument is removed' do
      expect(mutator.__send__(:removed_argument_names, [s(:arg, :a), s(:arg, :b)])).to eql([])
    end

    it 'returns all names when every argument is removed' do
      expect(mutator.__send__(:removed_argument_names, [])).to eql(%i[a b])
    end
  end
end

RSpec.describe Mutant::Mutator::Node::Block do
  describe '.call' do
    it 'does not emit a standalone body that still uses block arguments' do
      input  = parse('foo { |value| "#{value}" }')
      body   = input.children.fetch(2)
      result = described_class.call(input)

      expect(result).not_to include(body)
    end

    it 'emits standalone body when block argument is only used in a shadowing inner block' do
      input  = parse('foo { |value| bar { |value| value } }')
      body   = input.children.fetch(2)
      result = described_class.call(input)

      expect(result).to include(body)
    end

    it 'emits standalone body when nested method body uses the same local name' do
      input  = parse('foo { |value| def inner; value = 1; value; end }')
      body   = input.children.fetch(2)
      result = described_class.call(input)

      expect(result).to include(body)
    end

    it 'emits standalone body when nested singleton method body uses the same local name' do
      input  = parse('foo { |value| def self.inner; value = 1; value; end }')
      body   = input.children.fetch(2)
      result = described_class.call(input)

      expect(result).to include(body)
    end

    it 'does not emit a standalone body when a shadowing inner block send still uses the argument' do
      input  = parse('foo { |value| value.each { |value| value } }')
      body   = input.children.fetch(2)
      result = described_class.call(input)

      expect(result).not_to include(body)
    end

    it 'does not emit a standalone body when a shadowing inner numblock send still uses the argument' do
      input  = parse('foo { |value| value.then { _1 } }')
      body   = input.children.fetch(2)
      result = described_class.call(input)

      expect(result).not_to include(body)
    end

    it 'does not emit a standalone body that still uses a destructured block argument' do
      input  = parse('foo { |(value)| value }')
      body   = input.children.fetch(2)
      result = described_class.call(input)

      expect(result).not_to include(body)
    end
  end
end

RSpec.describe Mutant::Mutator::Node::Begin do
  describe '.call' do
    it 'does not emit standalone children from multi-statement begin nodes' do
      input = s(
        :begin,
        s(:lvasgn, :value, s(:int, 1)),
        s(:lvar, :value)
      )

      result = described_class.call(input)

      expect(result).not_to include(s(:lvasgn, :value, s(:int, 1)), s(:lvar, :value))
      expect(result).to include(
        s(:begin, s(:lvasgn, :value, s(:int, 1)), s(:nil)),
        s(:begin, s(:lvasgn, :value, s(:int, 1)), s(:self))
      )
    end

    it 'skips non-node children when mutating a begin body' do
      input = s(:begin, :__sentinel__, s(:true))

      expect(Mutant::Mutator).to receive(:mutate)
        .once
        .with(s(:true), kind_of(described_class))
        .and_return([s(:false)].to_set)

      expect(described_class.call(input)).to eql(
        [s(:begin, :__sentinel__, s(:false))].to_set
      )
    end

    it 'mutates Parser::AST::Node subclasses in begin bodies' do
      subclass = Class.new(Parser::AST::Node)
      input    = s(:begin, subclass.new(:true, []))

      expect(Mutant::Mutator).to receive(:mutate)
        .once
        .with(instance_of(subclass), kind_of(described_class))
        .and_return([s(:false)].to_set)

      expect(described_class.call(input)).to eql(
        [s(:begin, s(:false))].to_set
      )
    end
  end
end

RSpec.describe Mutant::Mutator::Node::Literal::Regex do
  describe '.call' do
    it 'skips body mutations when regexp_parser cannot build an expression tree' do
      input = parse('/foo/')
      token = Struct.new(:token).new(:condition_open)
      error = ::Regexp::Parser::UnknownTokenError.new(:conditional, token)

      allow(Mutant::AST::Regexp)
        .to receive(:parse)
        .and_raise(error)

      expect { described_class.call(input) }.not_to raise_error
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

RSpec.describe Mutant::Mutator::Node::Literal::Hash::Pair do
  describe '.call' do
    let(:parent_class) do
      Class.new(Mutant::Mutator::Node) do
        def dispatch; end
      end
    end

    it 'does not mutate label keys inside hash patterns' do
      result = described_class.call(
        s(:pair, s(:sym, :foo), s(:int, 1)),
        parent_class.send(:new, s(:hash_pattern), nil)
      )

      expect(result).to include(s(:pair, s(:sym, :foo), s(:nil)))
      expect(result).not_to include(s(:pair, s(:nil), s(:int, 1)))
    end

    it 'does not mutate keyword argument labels' do
      result = described_class.call(
        s(:pair, s(:sym, :foo), s(:int, 1)),
        parent_class.send(:new, s(:kwargs), nil)
      )

      expect(result).to include(s(:pair, s(:sym, :foo), s(:nil)))
      expect(result).not_to include(s(:pair, s(:nil), s(:int, 1)))
    end

    it 'mutates keys in an unconstrained hash context' do
      result = described_class.call(
        s(:pair, s(:sym, :foo), s(:int, 1)),
        parent_class.send(:new, s(:hash), nil)
      )

      expect(result).to include(s(:pair, s(:nil), s(:int, 1)))
      expect(result).to include(s(:pair, s(:sym, :foo), s(:nil)))
    end
  end
end

RSpec.describe Mutant::AST::Types do
  describe 'NOT_STANDALONE' do
    it 'treats kwargs as non-standalone' do
      expect(described_class::NOT_STANDALONE).to include(:kwargs)
    end
  end
end
