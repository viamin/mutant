# frozen_string_literal: true

RSpec.describe Mutant::Config do
  describe '#fail_fast?' do
    context 'when fail_fast is false' do
      subject { described_class::DEFAULT.fail_fast? }

      it { should be(false) }
    end

    context 'when fail_fast is true' do
      subject { described_class::DEFAULT.with(fail_fast: true).fail_fast? }

      it { should be(true) }
    end
  end

  describe '#zombie?' do
    context 'when zombie is false' do
      subject { described_class::DEFAULT.zombie? }

      it { should be(false) }
    end

    context 'when zombie is true' do
      subject { described_class::DEFAULT.with(zombie: true).zombie? }

      it { should be(true) }
    end
  end
end
