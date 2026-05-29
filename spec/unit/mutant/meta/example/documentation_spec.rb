# frozen_string_literal: true

RSpec.describe Mutant::Meta::Example::Documentation do
  describe '.render' do
    subject(:render) { described_class.render }

    let(:path) { Pathname.new('docs/mutators.md') }

    it 'matches the checked-in mutator documentation' do
      expect(render).to eql(path.read)
    end
  end
end
