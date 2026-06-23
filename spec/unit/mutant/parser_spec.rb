# frozen_string_literal: true

RSpec.describe Mutant::Parser do
  let(:object) { described_class.new }
  let(:modern_fixture_path) { Pathname.new(__dir__).join('../../fixtures/modern_syntax.rb').expand_path }

  describe '#call' do
    let(:path) { instance_double(Pathname) }

    subject { object.call(path) }

    before do
      expect(path).to receive(:read)
        .with(no_args)
        .and_return(':source')
    end

    it 'returns parsed source' do
      expect(subject).to eql(s(:sym, :source))
    end

    it 'is idempotent' do
      source = object.call(path)
      expect(subject).to be(source)
    end
  end

  describe 'modern Ruby syntax fixtures' do
    it 'parses without raising' do
      expect { object.call(modern_fixture_path) }.not_to raise_error
    end
  end
end
