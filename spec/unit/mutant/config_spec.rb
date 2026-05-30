# frozen_string_literal: true

RSpec.describe Mutant::Config do
  describe '#fail_fast?' do
    subject { described_class::DEFAULT.fail_fast? }

    it { should be(false) }
  end

  describe '#zombie?' do
    subject { described_class::DEFAULT.zombie? }

    it { should be(false) }
  end
end
