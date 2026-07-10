# frozen_string_literal: true

RSpec.describe Mutant::Mutator::Node::InPattern do
  subject(:mutations) { described_class.call(node) }

  let(:node) do
    s(:in_pattern,
      s(:match_var, :foo),
      s(:if_guard, s(:nil)),
      nil)
  end

  it 'drops guards and inserts raise bodies for bodyless branches' do
    expect(mutations).to eql(
      Set[
        s(:in_pattern,
          s(:match_var, :foo),
          nil,
          nil),
        s(:in_pattern,
          s(:match_var, :foo),
          s(:if_guard, s(:nil)),
          s(:send, nil, :raise))
      ]
    )
  end
end
