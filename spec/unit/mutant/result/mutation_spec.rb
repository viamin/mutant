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
  let(:success)  { true }
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

  shared_examples_for 'mutation exception isolation' do
    let(:isolation_result) do
      Mutant::Isolation::Result::Exception.new(exception)
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

    context 'if isolation is a child error' do
      let(:status) { instance_double(Process::Status) }
      let(:isolation_result) { Mutant::Isolation::Fork::ChildError.new(status) }

      it { should eql(0.0) }
    end
  end

  describe '#runtime' do
    subject { object.runtime }

    it { should eql(2.0) }
  end

  describe '#coverage_criteria', mutant_expression: 'Mutant::Result::Mutation#coverage_criteria' do
    subject { object.coverage_criteria }

    it { should eql(coverage_criteria) }
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

    context 'if isolation is a non-exception failure' do
      let(:status) { instance_double(Process::Status) }
      let(:isolation_result) { Mutant::Isolation::Fork::ChildError.new(status) }
      let(:success) { false }

      it { should be(false) }
    end

    context 'if isolation raises a mutation-induced exception on evil mutations' do
      let(:mutation) do
        instance_double(
          Class.new(Mutant::Mutation::Evil),
          class: Mutant::Mutation::Evil
        )
      end
      let(:exception) { SyntaxError.new('broken mutation') }

      include_context 'mutation exception isolation'

      let(:success) { true }

      it { should be(true) }
    end

    context 'if isolation raises a serialized mutation-induced exception on evil mutations' do
      let(:mutation) do
        instance_double(
          Class.new(Mutant::Mutation::Evil),
          class: Mutant::Mutation::Evil
        )
      end
      let(:exception) do
        Mutant::Isolation::Result::SerializedException.new(
          Mutant::EMPTY_ARRAY,
          'SyntaxError',
          '#<SyntaxError: broken mutation>'
        )
      end

      include_context 'mutation exception isolation'

      let(:success) { true }

      it { should be(true) }
    end

    context 'if process_abort criteria is enabled for a mutation exception' do
      let(:success) { true }
      let(:mutation) do
        instance_double(
          Class.new(Mutant::Mutation::Evil),
          class: Mutant::Mutation::Evil
        )
      end
      let(:exception) { SyntaxError.new('broken mutation') }

      include_context 'mutation exception isolation'

      it { should be(true) }
    end
  end

end
