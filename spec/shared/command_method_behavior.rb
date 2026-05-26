# frozen_string_literal: true

RSpec.shared_examples_for 'a command method' do
  it 'returns self' do
    should equal(object)
  end
end
