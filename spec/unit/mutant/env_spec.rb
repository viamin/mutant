# frozen_string_literal: true

RSpec.describe Mutant::Env do
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

  let(:integration)       { instance_double(Mutant::Integration) }
  let(:test_a)            { instance_double(Mutant::Test)        }
  let(:test_b)            { instance_double(Mutant::Test)        }
  let(:tests)             { [test_a, test_b]                     }
  let(:selector)          { instance_double(Mutant::Selector)    }
  let(:integration_class) { Mutant::Integration::Null            }
  let(:isolation)         { Mutant::Isolation::None.new          }
  let(:mutation_subject)  { instance_double(Mutant::Subject)     }

  let(:mutation) do
    instance_double(
      Mutant::Mutation,
      subject: mutation_subject
    )
  end

  let(:config) do
    Mutant::Config::DEFAULT.with(
      isolation:   isolation,
      integration: integration_class,
      kernel:      class_double(Kernel)
    )
  end

  before do
    allow(selector).to receive(:call)
      .with(mutation_subject)
      .and_return(tests)

    allow(Mutant::Timer).to receive(:now).and_return(2.0, 3.0)
  end

  describe '#kill' do
    subject { object.kill(mutation) }

    shared_examples_for 'mutation kill' do
      specify do
        should eql(
          Mutant::Result::Mutation.new(
            coverage_criteria: config.coverage_criteria,
            isolation_result: isolation_result,
            mutation:         mutation,
            runtime:          1.0
          )
        )
      end
    end

    context 'when isolation does not raise error' do
      let(:test_result) { instance_double(Mutant::Result::Test) }

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

      include_examples 'mutation kill'
    end

    context 'when code does raise error' do
      let(:exception) { RuntimeError.new('foo') }

      before do
        expect(mutation).to receive(:insert).and_raise(exception)
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Exception.new(exception)
      end

      include_examples 'mutation kill'
    end

    context 'when environment variables are configured' do
      let(:config) do
        super().with(
          environment_variables: {
            'MUTANT_ENV_SPEC' => 'configured'
          }
        )
      end

      let(:test_result) { instance_double(Mutant::Result::Test) }

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

      include_examples 'mutation kill'
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

      include_examples 'mutation kill'
    end

    context 'when environment variables override an existing value' do
      let(:config) do
        super().with(
          environment_variables: {
            'MUTANT_ENV_SPEC' => 'configured'
          }
        )
      end

      let(:test_result) { instance_double(Mutant::Result::Test) }

      before do
        ENV['MUTANT_ENV_SPEC'] = 'original'

        expect(mutation).to receive(:insert)
          .ordered
          .with(config.kernel) do
            expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('configured')
          end

        expect(integration).to receive(:call)
          .ordered
          .with(tests)
          .and_return(test_result)
      end

      let(:isolation_result) do
        Mutant::Isolation::Result::Success.new(test_result)
      end

      after do
        expect(ENV.fetch('MUTANT_ENV_SPEC')).to eql('original')
        ENV.delete('MUTANT_ENV_SPEC')
      end

      include_examples 'mutation kill'
    end
  end

  describe '#selections' do
    subject { object.selections }

    it 'returns expected selections' do
      expect(subject).to eql(mutation_subject => tests)
    end
  end
end
