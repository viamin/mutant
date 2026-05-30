# frozen_string_literal: true

RSpec.describe Mutant do
  let(:object) { described_class }

  describe '.ci?' do
    subject { object.ci? }

    let(:value) { instance_double(Object, 'value') }

    before do
      expect(ENV).to receive(:key?).with('CI').and_return(value)
    end

    it { should be(value) }
  end

  describe 'boot' do
    it 'loads stringio on require' do
      expect(StringIO).to be(StringIO)
    end
  end

  describe 'warning filtering' do
    around do |example|
      original_stderr = $stderr
      $stderr = StringIO.new
      example.run
    ensure
      $stderr = original_stderr
    end

    it 'accepts ruby 3 warning keyword arguments' do
      expect { Warning.warn('x', category: :deprecated) }.not_to raise_error
    end
  end
end
