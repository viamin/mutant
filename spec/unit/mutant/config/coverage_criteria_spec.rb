# frozen_string_literal: true

RSpec.describe Mutant::Config::CoverageCriteria do
  let(:object) do
    described_class.new(
      process_abort: process_abort,
      test_result:   test_result,
      timeout:       false
    )
  end

  let(:process_abort) { false }
  let(:test_result)   { true  }
  let(:mutation)      { instance_double(Mutant::Mutation) }

  describe '#success?' do
    subject { object.success?(mutation: mutation, isolation_result: isolation_result) }

    context 'when isolation is successful' do
      let(:test_result_object) { instance_double(Mutant::Result::Test) }
      let(:isolation_result) do
        Mutant::Isolation::Result::Success.new(test_result_object)
      end

      context 'and test_result criteria is enabled' do
        let(:mutation_success) { true }

        before do
          expect(mutation.class).to receive(:success?)
            .with(test_result_object)
            .and_return(mutation_success)
        end

        it { should be(true) }
      end

      context 'and test_result criteria is disabled' do
        let(:test_result)      { false }

        it { should be(false) }
      end
    end

    context 'when isolation is unsuccessful' do
      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom'))
      end

      context 'and process_abort criteria is enabled' do
        let(:process_abort) { true }

        it { should be(true) }
      end

      context 'and process_abort criteria is disabled' do
        it { should be(false) }
      end
    end
  end
end
