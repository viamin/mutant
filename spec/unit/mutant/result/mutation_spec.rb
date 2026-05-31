# frozen_string_literal: true

RSpec.describe Mutant::Result::Mutation do
  let(:object) do
    described_class.new(
      isolation_result: isolation_result,
      mutation:         mutation,
      runtime:          2.0
    )
  end

  let(:mutation) { instance_double(Mutant::Mutation) }

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
  end

  describe '#runtime' do
    subject { object.runtime }

    it { should eql(2.0) }
  end

  describe '#success?' do
    subject { object.success? }

    context 'if isolation is successful' do
      before do
        expect(mutation.class).to receive(:success?)
          .with(test_result)
          .and_return(true)
      end

      it { should be(true) }
    end

    context 'if isolation is not successful' do
      include_context 'unsuccessful isolation'

      before do
        expect(mutation.class).to receive(:exception_success?)
          .with(isolation_result.value)
          .and_return(false)
      end

      it { should be(false) }
    end

    context 'if isolation is a non-exception failure' do
      let(:status) { instance_double(Process::Status) }
      let(:isolation_result) { Mutant::Isolation::Fork::ChildError.new(status) }

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

      it { should be(true) }
    end
  end
end
