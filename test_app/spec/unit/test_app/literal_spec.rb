require 'spec_helper'

RSpec.describe TestApp::Literal do
  subject(:object) { described_class.new }

  describe '#command' do
    it { is_expected.to cover('TestApp::Literal#command') }

    specify do
      expect(object.command(double)).to be(object)
    end
  end

  describe '#string' do
    it { is_expected.to cover('TestApp::Literal#string') }

    specify do
      expect(object.string).to eql('string')
    end
  end
end

RSpec.describe TestApp::Empty do
  it { is_expected.to cover(described_class) }
end
