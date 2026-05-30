# frozen_string_literal: true

RSpec.describe Mutant::Result::Mutation do
  class CoverageCriteriaSpy
    def initialize(expected_isolation_result, expected_mutation, result)
      @expected_isolation_result = expected_isolation_result
      @expected_mutation         = expected_mutation
      @result                    = result
    end

    def success?(mutation, isolation_result)
      mutation.equal?(@expected_mutation) &&
        isolation_result.equal?(@expected_isolation_result) &&
        @result
    end
  end

  let(:object) do
    described_class.new(
      coverage_criteria: coverage_criteria,
      isolation_result: isolation_result,
      mutation:         mutation,
      runtime:          2.0
    )
  end

  let(:mutation) { instance_double(Mutant::Mutation) }
  let(:success) { true }
  let(:coverage_criteria) do
    CoverageCriteriaSpy.new(isolation_result, mutation, success)
  end

  let(:test_result) do
    instance_double(
      Mutant::Result::Test,
      runtime: 1.0
    )
  end

  let(:isolation_result) do
    Mutant::Isolation::Result::Success.new(test_result)
  end

  shared_examples_for 'unsuccessful isolation' do
    let(:isolation_result) do
      Mutant::Isolation::Result::Exception.new(RuntimeError.new('foo'))
    end
  end

  describe '#killtime' do
    subject { object.killtime }

    context 'if isolation is successful' do
      it { should eql(1.0) }
    end

    context 'if isolation is not successful' do
      include_context 'unsuccessful isolation'

      it { should eql(0.0) }
    end
  end

  describe '#runtime' do
    subject { object.runtime }

    it { should eql(2.0) }
  end

  describe '#success?' do
    subject { object.success? }

    context 'if isolation is successful' do
      let(:success) { true }

      it { should eql(true) }
    end

    context 'if isolation is not successful' do
      include_context 'unsuccessful isolation'

      let(:success) { false }

      it { should eql(false) }
    end
  end
end
