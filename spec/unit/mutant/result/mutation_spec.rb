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

  around do |example|
    original = Mutant::Config::CoverageCriteria.current
    example.run
  ensure
    Mutant::Config::CoverageCriteria.current = original
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

  describe '.new', mutant_expression: 'Mutant::Result::Mutation#initialize' do
    it 'falls back to the current coverage criteria when none is provided' do
      fallback_criteria = Mutant::Config::CoverageCriteria.new(
        process_abort: true,
        test_result:   false,
        timeout:       true
      )
      mutation = Object.new
      isolation_result = Mutant::Isolation::Result::Success.new(
        instance_double(Mutant::Result::Test, runtime: 1.0)
      )

      Mutant::Config::CoverageCriteria.current = fallback_criteria

      result = described_class.new(
        isolation_result: isolation_result,
        mutation:         mutation,
        runtime:          2.0
      )

      expect(result.coverage_criteria).to eql(fallback_criteria)
      expect(result.isolation_result).to eql(isolation_result)
      expect(result.mutation).to eql(mutation)
      expect(result.runtime).to eql(2.0)
    end
  end
end
