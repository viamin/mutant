# frozen_string_literal: true

RSpec.describe Mutant::Mutator::Node::InPattern do
  describe '.call' do
    context 'without a guard or a body' do
      let(:node) { s(:in_pattern, s(:match_var, :foo), nil, nil) }

      it 'inserts a raise body' do
        expect(described_class.call(node)).to eql(Set[
          s(:in_pattern, s(:match_var, :foo), nil, s(:send, nil, :raise))
        ])
      end
    end

    context 'without a guard but with a body' do
      let(:node) { s(:in_pattern, s(:match_var, :foo), nil, s(:send, nil, :bar)) }

      it 'mutates the body' do
        expect(described_class.call(node)).to eql(Set[
          s(:in_pattern, s(:match_var, :foo), nil, s(:nil)),
          s(:in_pattern, s(:match_var, :foo), nil, s(:self))
        ])
      end
    end

    context 'with a guard and a body' do
      let(:node) do
        s(:in_pattern,
          s(:match_var, :foo),
          s(:if_guard, s(:send, nil, :cond)),
          s(:send, nil, :bar))
      end

      it 'drops and mutates the guard, and mutates the body' do
        expect(described_class.call(node)).to eql(Set[
          s(:in_pattern, s(:match_var, :foo), nil, s(:send, nil, :bar)),
          s(:in_pattern, s(:match_var, :foo), s(:if_guard, s(:nil)),  s(:send, nil, :bar)),
          s(:in_pattern, s(:match_var, :foo), s(:if_guard, s(:self)), s(:send, nil, :bar)),
          s(:in_pattern, s(:match_var, :foo), s(:if_guard, s(:send, nil, :cond)), s(:nil)),
          s(:in_pattern, s(:match_var, :foo), s(:if_guard, s(:send, nil, :cond)), s(:self))
        ])
      end
    end

    context 'with a guard but without a body' do
      let(:node) do
        s(:in_pattern,
          s(:match_var, :foo),
          s(:if_guard, s(:send, nil, :cond)),
          nil)
      end

      it 'drops and mutates the guard, and inserts a raise body' do
        expect(described_class.call(node)).to eql(Set[
          s(:in_pattern, s(:match_var, :foo), nil, nil),
          s(:in_pattern, s(:match_var, :foo), s(:if_guard, s(:send, nil, :cond)), s(:send, nil, :raise)),
          s(:in_pattern, s(:match_var, :foo), s(:if_guard, s(:nil)),  nil),
          s(:in_pattern, s(:match_var, :foo), s(:if_guard, s(:self)), nil)
        ])
      end
    end
  end
end
