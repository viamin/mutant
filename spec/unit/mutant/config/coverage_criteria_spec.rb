# frozen_string_literal: true

RSpec.describe Mutant::Config::CoverageCriteria do
  around do |example|
    original = Thread.current[described_class::THREAD_KEY]
    example.run
  ensure
    Thread.current[described_class::THREAD_KEY] = original
  end

  let(:object) do
    described_class.new(
      process_abort: process_abort,
      test_result:   test_result,
      timeout:       timeout
    )
  end

  let(:process_abort) { false }
  let(:test_result)   { true  }
  let(:timeout)       { false }
  let(:mutation)      { instance_double(Mutant::Mutation) }

  describe '.current' do
    subject(:current) { described_class.current }

    context 'when no thread-local value is configured' do
      before do
        Thread.current[described_class::THREAD_KEY] = nil
      end

      it { should eql(described_class::DEFAULT) }
    end

    context 'when a thread-local value is configured' do
      let(:object) do
        described_class.new(
          process_abort: true,
          test_result:   false,
          timeout:       true
        )
      end

      before do
        described_class.current = object
      end

      it { should eql(object) }
    end
  end

  describe '.current=' do
    let(:current_value) do
      described_class.new(
        process_abort: true,
        test_result:   false,
        timeout:       true
      )
    end

    it 'stores the value in the current thread' do
      Thread.current[described_class::THREAD_KEY] = nil

      result = described_class.send(:current=, current_value)

      expect(result).to eql(current_value)
      expect(described_class.current).to eql(current_value)
      expect(Thread.current[described_class::THREAD_KEY]).to eql(current_value)
    end
  end

  describe '.with_current' do
    let(:original) do
      described_class.new(
        process_abort: true,
        test_result:   true,
        timeout:       true
      )
    end

    let(:other) do
      described_class.new(
        process_abort: true,
        test_result:   false,
        timeout:       true
      )
    end

    it 'sets and restores the value in the current thread' do
      described_class.current = original

      result = described_class.with_current(other) do
        expect(described_class.current).to eql(other)
        :block_result
      end

      expect(result).to eql(:block_result)
      expect(described_class.current).to eql(original)
    end

    it 'restores the original value after an exception' do
      described_class.current = original

      expect do
        described_class.with_current(other) do
          raise 'boom'
        end
      end.to raise_error(RuntimeError, 'boom')

      expect(described_class.current).to eql(original)
    end

    it 'restores a missing original value after yielding' do
      Thread.current[described_class::THREAD_KEY] = nil

      described_class.with_current(other) do
        expect(described_class.current).to eql(other)
      end

      expect(Thread.current[described_class::THREAD_KEY]).to be(nil)
      expect(described_class.current).to eql(described_class::DEFAULT)
    end
  end

  describe 'TIMEOUT_SIGNALS' do
    subject { described_class::TIMEOUT_SIGNALS }

    it 'contains signal numbers for KILL and TERM' do
      expect(subject).to include(Signal.list.fetch('KILL'))
      expect(subject).to include(Signal.list.fetch('TERM'))
      expect(subject.length).to eql(2)
    end
  end

  describe '#success?' do
    subject { object.success?(mutation, isolation_result) }

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

      context 'and the mutation test result is unsuccessful' do
        let(:mutation_success) { false }

        before do
          expect(mutation.class).to receive(:success?)
            .with(test_result_object)
            .and_return(mutation_success)
        end

        it { should be(false) }
      end

      context 'and test_result criteria is disabled' do
        let(:test_result)      { false }

        it 'does not consult mutation success and returns false' do
          expect(mutation.class).not_to receive(:success?)

          expect(subject).to be(false)
        end
      end
    end

    context 'when isolation raises a non-mutation exception' do
      let(:mutation) do
        instance_double(
          Class.new(Mutant::Mutation::Neutral),
          class: Mutant::Mutation::Neutral
        )
      end
      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom'))
      end

      it { should be(false) }
    end

    context 'when isolation raises a mutation-induced exception on an evil mutation' do
      let(:mutation) do
        instance_double(
          Class.new(Mutant::Mutation::Evil),
          class: Mutant::Mutation::Evil
        )
      end
      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(SyntaxError.new('broken mutation'))
      end

      it { should be(true) }
    end

    context 'when isolation raises a serialized mutation-induced exception on an evil mutation' do
      let(:mutation) do
        instance_double(
          Class.new(Mutant::Mutation::Evil),
          class: Mutant::Mutation::Evil
        )
      end
      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(
          Mutant::Isolation::Result::SerializedException.new(
            Mutant::EMPTY_ARRAY,
            'SyntaxError',
            '#<SyntaxError: broken mutation>'
          )
        )
      end

      it { should be(true) }
    end

    context 'when isolation timed out' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('TERM')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Fork::ChildError.new(status)
      end

      context 'and timeout criteria is enabled' do
        let(:timeout) { true }

        it { should be(true) }
      end

      context 'and timeout criteria is disabled' do
        let(:process_abort) { true }

        it { should be(false) }
      end
    end

    context 'when timeout is wrapped in an error chain' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('KILL')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Fork::ChildError.new(status),
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom'))
        )
      end

      let(:timeout) { true }

      it { should be(true) }
    end

    context 'when timeout is wrapped in the next error chain entry' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('KILL')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')),
          Mutant::Isolation::Fork::ChildError.new(status)
        )
      end

      let(:timeout) { true }

      it { should be(true) }
    end

    context 'when child exit was signaled with a non-timeout signal' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('INT')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Fork::ChildError.new(status)
      end

      let(:process_abort) { true }

      it { should be(true) }
    end

    context 'when child exit was signaled with a non-timeout signal and process_abort is disabled' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('INT')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Fork::ChildError.new(status)
      end

      it { should be(false) }
    end

    context 'when child exit was not signaled' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: false,
          termsig:   Signal.list.fetch('TERM')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Fork::ChildError.new(status)
      end

      let(:process_abort) { true }

      it { should be(true) }
    end

    context 'when error chain contains no timeout entries' do
      let(:isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')),
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('other'))
        )
      end

      let(:process_abort) { true }

      it { should be(true) }
    end

    context 'when error chain contains no timeout entries and process_abort is disabled' do
      let(:isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')),
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('other'))
        )
      end

      it { should be(false) }
    end
  end

  describe '#timeout_result?' do
    subject { object.__send__(:timeout_result?, isolation_result) }

    context 'when the result is a timeout child error' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('TERM')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Fork::ChildError.new(status)
      end

      it { should be(true) }
    end

    context 'when the result is a non-timeout child error' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('INT')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Fork::ChildError.new(status)
      end

      it { should be(false) }
    end

    context 'when the timeout is in the first error chain entry' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('KILL')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Fork::ChildError.new(status),
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom'))
        )
      end

      it { should be(true) }
    end

    context 'when the timeout is in the second error chain entry' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('KILL')
        )
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')),
          Mutant::Isolation::Fork::ChildError.new(status)
        )
      end

      it { should be(true) }
    end

    context 'when the result is an error chain with no timeout entries' do
      let(:isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')),
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('other'))
        )
      end

      it { should be(false) }
    end

    context 'when the result is not a child error or error chain' do
      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom'))
      end

      it 'returns false as a boolean' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#timeout_status?' do
    subject { object.__send__(:timeout_status?, status) }

    context 'when the status is signaled with a timeout signal' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('TERM')
        )
      end

      it { should be(true) }
    end

    context 'when the status is signaled with a non-timeout signal' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: true,
          termsig:   Signal.list.fetch('INT')
        )
      end

      it { should be(false) }
    end

    context 'when the status is not signaled' do
      let(:status) do
        instance_double(
          Process::Status,
          signaled?: false,
          termsig:   Signal.list.fetch('TERM')
        )
      end

      it { should be(false) }
    end
  end
end
