# frozen_string_literal: true

RSpec.describe Mutant::Env, mutant: false do
  let(:object) do
    described_class.new(
      config:           config,
      integration:      integration,
      matchable_scopes: [],
      mutations:        [],
      selector:         selector,
      subjects:         [mutation_subject],
      parser:           Mutant::Parser.new
    )
  end

  let(:integration)       { double('integration')        }
  let(:test_a)            { double('test-a')             }
  let(:test_b)            { double('test-b')             }
  let(:tests)             { [test_a, test_b]             }
  let(:selector)          { double('selector')           }
  let(:integration_class) { Mutant::Integration::Null    }
  let(:isolation)         { Mutant::Isolation::None.new  }
  let(:mutation_subject)  { double('mutation-subject')   }

  let(:mutation) do
    double(
      'mutation',
      subject: mutation_subject
    )
  end

  let(:config) do
    Mutant::Config::DEFAULT.with(
      isolation:   isolation,
      integration: integration_class,
      kernel:      Kernel
    )
  end

  before do
    allow(selector).to receive(:call)
      .with(mutation_subject)
      .and_return(tests)

    timer_values = [2.0, 3.0].cycle

    allow(Mutant::Timer).to receive(:now) { timer_values.next }
  end

  describe '#kill', mutant_expression: 'Mutant::Env#kill' do
    def assert_mutation_result(result)
      expect(result).to be_instance_of(Mutant::Result::Mutation)
      expect(result.coverage_criteria).to eql(config.coverage_criteria)
      expect(result.isolation_result).to eql(isolation_result)
      expect(result.mutation).to be(mutation)
      expect(result.runtime).to eql(1.0)
    end

    context 'when isolation does not raise error' do
      let(:test_result) { double('test-result') }

      before do
        expect(mutation).to receive(:insert)
          .ordered
          .with(config.kernel)

        expect(integration).to receive(:call)
          .ordered
          .with(tests)
          .and_return(test_result)
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Success.new(test_result)
      end

      it 'returns the mutation result' do
        assert_mutation_result(object.kill(mutation))
      end
    end

    context 'when code does raise error' do
      let(:exception) { RuntimeError.new('foo') }

      before do
        expect(mutation).to receive(:insert).and_raise(exception)
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(exception)
      end

      it 'returns the mutation result' do
        assert_mutation_result(object.kill(mutation))
      end
    end

    context 'when environment variables are configured' do
      let(:config) do
        super().with(
          environment_variables: {
            'MUTANT_ENV_SPEC' => 'configured'
          }
        )
      end

      let(:test_result) { double('test-result') }

      before do
        ENV.delete('MUTANT_ENV_SPEC')

        expect(mutation).to receive(:insert)
          .ordered
          .with(config.kernel) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
          end

        expect(integration).to receive(:call)
          .ordered
          .with(tests) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
            test_result
          end
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Success.new(test_result)
      end

      after do
        expect(ENV.key?('MUTANT_ENV_SPEC')).to be(false)
      end

      it 'returns the mutation result' do
        assert_mutation_result(object.kill(mutation))
      end
    end

    context 'when environment variables are configured and integration raises' do
      let(:config) do
        super().with(
          environment_variables: {
            'MUTANT_ENV_SPEC' => 'configured'
          }
        )
      end

      let(:exception) { RuntimeError.new('integration failure') }

      before do
        ENV.delete('MUTANT_ENV_SPEC')

        expect(mutation).to receive(:insert)
          .ordered
          .with(config.kernel) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
          end

        expect(integration).to receive(:call)
          .ordered
          .with(tests) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
            raise exception
          end
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(exception)
      end

      after do
        expect(ENV.key?('MUTANT_ENV_SPEC')).to be(false)
      end

      it 'returns the mutation result' do
        assert_mutation_result(object.kill(mutation))
      end
    end

    context 'when environment variables override an existing value' do
      let(:config) do
        super().with(
          environment_variables: {
            'MUTANT_ENV_SPEC' => 'configured'
          }
        )
      end

      let(:test_result) { double('test-result') }

      before do
        ENV['MUTANT_ENV_SPEC'] = 'original'

        expect(mutation).to receive(:insert)
          .ordered
          .with(config.kernel) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
          end

        expect(integration).to receive(:call)
          .ordered
          .with(tests) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
            test_result
          end
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Success.new(test_result)
      end

      after do
        expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('original')
        ENV.delete('MUTANT_ENV_SPEC')
      end

      it 'returns the mutation result' do
        assert_mutation_result(object.kill(mutation))
      end
    end

    context 'when environment variables override an existing empty-string value' do
      let(:config) do
        super().with(
          environment_variables: {
            'MUTANT_ENV_SPEC' => 'configured'
          }
        )
      end

      let(:test_result) { double('test-result') }

      before do
        ENV['MUTANT_ENV_SPEC'] = ''

        expect(mutation).to receive(:insert)
          .ordered
          .with(config.kernel) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
          end

        expect(integration).to receive(:call)
          .ordered
          .with(tests) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
            test_result
          end
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Success.new(test_result)
      end

      after do
        expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('')
        ENV.delete('MUTANT_ENV_SPEC')
      end

      it 'returns the mutation result and restores the empty-string value' do
        assert_mutation_result(object.kill(mutation))
      end
    end
  end

  describe '#selections' do
    subject { object.selections }

    it 'returns expected selections' do
      expect(subject).to eql(mutation_subject => tests)
    end
  end
end

RSpec.describe 'Mutant::Env mutation coverage' do
  let(:build_env) do
    lambda do |config:, integration:, selector:, subjects:|
      Mutant::Env.new(
        config:           config,
        integration:      integration,
        matchable_scopes: [],
        mutations:        [],
        selector:         selector,
        subjects:         subjects,
        parser:           Mutant::Parser.new
      )
    end
  end

  describe 'Mutant::Env#run_mutation_tests', mutant_expression: 'Mutant::Env#run_mutation_tests' do
    let(:mutation_subject)      { double('mutation-subject') }
    let(:other_subject)         { double('other-subject') }
    let(:mutation_insert_calls) { [] }
    let(:integration_calls)     { [] }
    let(:selected_tests)        { [double('selected-test')] }
    let(:selector)              { double('selector') }
    let(:integration) do
      double('integration').tap do |object|
        allow(object).to receive(:call) do |tests|
          integration_calls << tests
          expect(Mutant::Config::CoverageCriteria.current).to eql(coverage_criteria)
          :selected_result
        end
      end
    end
    let(:mutation) do
      double('mutation', subject: mutation_subject).tap do |object|
        allow(object).to receive(:insert) do |argument|
          mutation_insert_calls << argument
          expect(Mutant::Config::CoverageCriteria.current).to eql(coverage_criteria)
        end
      end
    end
    let(:coverage_criteria) do
      Mutant::Config::CoverageCriteria.new(
        process_abort: true,
        test_result:   false,
        timeout:       true
      )
    end
    let(:config) do
      Mutant::Config::DEFAULT.with(
        coverage_criteria:     coverage_criteria,
        environment_variables: { 'MUTANT_ENV_SPEC' => 'configured' },
        isolation:             Mutant::Isolation::None.new,
        kernel:                Kernel
      )
    end

    before do
      allow(selector).to receive(:call).with(mutation_subject).and_return(selected_tests)
      allow(selector).to receive(:call).with(other_subject).and_return([double('other-test')])
    end

    it 'runs the mutation inside the configured coverage criteria scope' do
      result = build_env.call(
        config:      config,
        integration: integration,
        selector:    selector,
        subjects:    [other_subject, mutation_subject]
      ).__send__(:run_mutation_tests, mutation)

      expect(mutation_insert_calls).to eql([Kernel])
      expect(integration_calls).to eql([selected_tests])
      expect(result).to be_instance_of(Mutant::Isolation::Result::Success)
      expect(result.value).to eql(:selected_result)
      expect(ENV.key?('MUTANT_ENV_SPEC')).to be(false)
    end
  end

  describe 'Mutant::Env#kill', mutant_expression: 'Mutant::Env#kill' do
    let(:mutation_subject)      { double('mutation-subject') }
    let(:other_subject)         { double('other-subject') }
    let(:mutation_insert_calls) { [] }
    let(:integration_calls)     { [] }
    let(:selected_tests)        { [double('selected-test')] }
    let(:selector)              { double('selector') }
    let(:integration) do
      double('integration').tap do |object|
        allow(object).to receive(:call) do |tests|
          integration_calls << tests
          :selected_result
        end
      end
    end
    let(:mutation) do
      double('mutation', subject: mutation_subject).tap do |object|
        allow(object).to receive(:insert) do |argument|
          mutation_insert_calls << argument
        end
      end
    end
    let(:coverage_criteria) do
      Mutant::Config::CoverageCriteria.new(
        process_abort: true,
        test_result:   false,
        timeout:       true
      )
    end
    let(:config) do
      Mutant::Config::DEFAULT.with(
        coverage_criteria:     coverage_criteria,
        environment_variables: { 'MUTANT_ENV_SPEC' => 'configured' },
        isolation:             Mutant::Isolation::None.new,
        kernel:                Kernel
      )
    end

    before do
      allow(selector).to receive(:call).with(mutation_subject).and_return(selected_tests)
      allow(selector).to receive(:call).with(other_subject).and_return([double('other-test')])
    end

    it 'captures coverage criteria and runtime for the mutated subject' do
      result = build_env.call(
        config:      config,
        integration: integration,
        selector:    selector,
        subjects:    [other_subject, mutation_subject]
      ).kill(mutation)

      expect(result.coverage_criteria).to eql(coverage_criteria)
      expect(result.isolation_result).to eql(Mutant::Isolation::Result::Success.new(:selected_result))
      expect(result.mutation).to eql(mutation)
      expect(result.runtime).to be >= 0.0
      expect(mutation_insert_calls).to eql([Kernel])
      expect(integration_calls).to eql([selected_tests])
      expect(ENV.key?('MUTANT_ENV_SPEC')).to be(false)
    end
  end

  describe 'Mutant::Env#with_environment_variables', mutant_expression: 'Mutant::Env#with_environment_variables' do
    let(:selector)    { double('selector') }
    let(:integration) { double('integration') }
    let(:config) do
      Mutant::Config::DEFAULT.with(
        environment_variables: {
          'MUTANT_ENV_SPEC' => 'configured'
        }
      )
    end

    it 'restores missing and existing values after yielding' do
      yielded = false

      ENV['MUTANT_PERSISTENT_SPEC'] = 'original'

      env = build_env.call(
        config:      config.with(
          environment_variables: {
            'MUTANT_ENV_SPEC' => 'configured',
            'MUTANT_PERSISTENT_SPEC' => 'override'
          }
        ),
        integration: integration,
        selector:    selector,
        subjects:    []
      )

      result = env.__send__(:with_environment_variables) do
        yielded = true
        expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
        expect(ENV.fetch('MUTANT_PERSISTENT_SPEC')).to eql('override')
        :block_result
      end

      expect(yielded).to be(true)
      expect(result).to eql(:block_result)
      expect(ENV.key?('MUTANT_ENV_SPEC')).to be(false)
      expect(ENV.fetch('MUTANT_PERSISTENT_SPEC')).to eql('original')
    ensure
      ENV.delete('MUTANT_ENV_SPEC')
      ENV.delete('MUTANT_PERSISTENT_SPEC')
    end

    it 'serializes environment updates across concurrent calls' do
      queue = Queue.new
      release = Queue.new

      env_a = build_env.call(
        config:      config.with(environment_variables: { 'MUTANT_ENV_SPEC' => 'first' }),
        integration: integration,
        selector:    selector,
        subjects:    []
      )
      env_b = build_env.call(
        config:      config.with(environment_variables: { 'MUTANT_ENV_SPEC' => 'second' }),
        integration: integration,
        selector:    selector,
        subjects:    []
      )

      thread_a = Thread.new do
        env_a.__send__(:with_environment_variables) do
          queue << ENV.fetch('MUTANT_ENV_SPEC')
          release.pop
          queue << ENV.fetch('MUTANT_ENV_SPEC')
        end
      end

      expect(queue.pop).to eql('first')

      thread_b = Thread.new do
        env_b.__send__(:with_environment_variables) do
          queue << ENV.fetch('MUTANT_ENV_SPEC')
        end
      end

      expect(queue.empty?).to be(true)

      release << :continue

      expect(queue.pop).to eql('first')
      expect(queue.pop).to eql('second')

      thread_a.join
      thread_b.join
    ensure
      ENV.delete('MUTANT_ENV_SPEC')
    end
  end

  describe 'Mutant::Env#selections', mutant_expression: 'Mutant::Env#selections' do
    it 'maps each subject to the selected tests' do
      subject_a = double('subject-a')
      subject_b = double('subject-b')
      tests_a   = [double('test-a')]
      tests_b   = [double('test-b')]
      selector  = double('selector')

      allow(selector).to receive(:call).with(subject_a).and_return(tests_a)
      allow(selector).to receive(:call).with(subject_b).and_return(tests_b)

      env = build_env.call(
        config:      Mutant::Config::DEFAULT,
        integration: double('integration'),
        selector:    selector,
        subjects:    [subject_a, subject_b]
      )

      expect(env.selections).to eql(subject_a => tests_a, subject_b => tests_b)
    end
  end
end
