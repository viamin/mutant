# frozen_string_literal: true

RSpec.describe Mutant::CLI do
  let(:object) { described_class }

  shared_examples_for 'an invalid cli run' do
    it 'raises error' do
      expect do
        subject
      end.to raise_error(Mutant::CLI::Error, expected_message)
    end
  end

  shared_examples_for 'a cli parser' do
    it { expect(subject.config.integration).to eql(expected_integration) }
    it { expect(subject.config.reporter).to eql(expected_reporter)       }
    it { expect(subject.config.matcher).to eql(expected_matcher_config)  }
    it { expect(subject.config.results_dir).to eql(expected_results_dir) }
    it { expect(subject.config.since).to eql(expected_since)             }
  end

  describe '.run' do
    subject { object.run(arguments) }

    let(:arguments) { instance_double(Array)                                         }
    let(:report)    { instance_double(Mutant::Result::Env, success?: report_success) }
    let(:config)    { instance_double(Mutant::Config)                                }
    let(:env)       { instance_double(Mutant::Env)                                   }

    before do
      expect(Mutant::CLI).to receive(:call).with(arguments).and_return(config)
      expect(Mutant::Env::Bootstrap).to receive(:call).with(config).and_return(env)
      expect(Mutant::Runner).to receive(:call).with(env).and_return(report)
    end

    context 'when report signals success' do
      let(:report_success) { true }

      it 'exits failure' do
        expect(subject).to be(true)
      end
    end

    context 'when report signals error' do
      let(:report_success) { false }

      it 'exits failure' do
        expect(subject).to be(false)
      end
    end

    context 'when execution raises an Mutant::CLI::Error' do
      let(:exception) { Mutant::CLI::Error.new('test-error') }
      let(:report_success) { nil }

      before do
        expect(report).to receive(:success?).and_raise(exception)
      end

      it 'exits failure' do
        expect($stderr).to receive(:puts).with('test-error')
        expect(subject).to be(false)
      end
    end
  end

  describe '.new' do
    let(:object) { described_class }

    subject { object.new(arguments) }

    # Defaults
    let(:expected_integration)    { Mutant::Integration::Null        }
    let(:expected_reporter)       { Mutant::Config::DEFAULT.reporter }
    let(:expected_matcher_config) { default_matcher_config           }
    let(:expected_results_dir)    { '.mutant/results'                }
    let(:expected_since)          { nil                              }

    let(:default_matcher_config) do
      Mutant::Matcher::Config::DEFAULT
        .with(match_expressions: expressions.map(&method(:parse_expression)))
    end

    let(:flags)       { []           }
    let(:expressions) { %w[TestApp*] }

    let(:arguments) { flags + expressions }

    context 'with unknown flag' do
      let(:flags) { %w[--invalid] }

      let(:expected_message) { 'invalid option: --invalid' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with unknown option' do
      let(:flags) { %w[--invalid Foo] }

      let(:expected_message) { 'invalid option: --invalid' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with include help flag' do
      let(:flags) { %w[--help] }

      before do
        expect($stdout).to receive(:puts).with(expected_message)
        expect(Kernel).to receive(:exit)
      end

      it_should_behave_like 'a cli parser'

      let(:expected_message) do
        <<~MESSAGE
          usage: mutant [options] MATCH_EXPRESSION ...
          Environment:
                  --zombie                     Run mutant zombified
              -I, --include DIRECTORY          Add DIRECTORY to $LOAD_PATH
              -r, --require NAME               Require file with NAME
              -j, --jobs NUMBER                Number of kill jobs. Defaults to number of processors.

          Options:
                  --use INTEGRATION            Use INTEGRATION to kill mutations
                  --results-dir DIRECTORY      Write machine-readable results to DIRECTORY
                  --ignore-subject EXPRESSION  Ignore subjects that match EXPRESSION as prefix
                  --since REVISION             Only select subjects touched since REVISION
                  --fail-fast                  Fail fast
                  --version                    Print mutants version
              -h, --help                       Show this message
        MESSAGE
      end
    end

    context 'with include flag' do
      let(:flags) { %w[--include foo] }

      it_should_behave_like 'a cli parser'

      it 'configures includes' do
        expect(subject.config.includes).to eql(%w[foo])
      end
    end

    context 'with use flag' do
      context 'when integration exists' do
        let(:flags) { %w[--use rspec] }

        before do
          expect(Kernel).to receive(:require)
            .with('mutant/integration/rspec')
            .and_call_original
        end

        it_should_behave_like 'a cli parser'

        let(:expected_integration) { Mutant::Integration::Rspec }
      end

      context 'when integration does NOT exist' do
        let(:flags) { %w[--use other] }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            'Could not load integration "other" (you may want to try installing the gem mutant-other)'
          )
        end
      end
    end

    context 'with version flag' do
      let(:flags) { %w[--version] }

      before do
        expect(Kernel).to receive(:exit)
        expect($stdout).to receive(:puts).with("mutant-#{Mutant::VERSION}")
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with jobs flag' do
      let(:flags) { %w[--jobs 0] }

      it_should_behave_like 'a cli parser'

      it 'configures expected coverage' do
        expect(subject.config.jobs).to eql(0)
      end
    end

    context 'with require flags' do
      let(:flags) { %w[--require foo --require bar] }

      it_should_behave_like 'a cli parser'

      it 'configures requires' do
        expect(subject.config.requires).to eql(%w[foo bar])
      end
    end

    context 'with --since flag' do
      let(:flags) { %w[--since master] }
      let(:expected_since) { 'master' }

      let(:expected_matcher_config) do
        default_matcher_config.with(
          subject_filters: [
            Mutant::Repository::SubjectFilter.new(
              Mutant::Repository::Diff.new(
                config: Mutant::Config::DEFAULT.with(since: 'master'),
                from:   'HEAD',
                to:     'master'
              )
            )
          ]
        )
      end

      it_should_behave_like 'a cli parser'

      it 'propagates the since revision into the repository diff config' do
        diff = subject.config.matcher.subject_filters.fetch(0).send(:diff)

        aggregate_failures do
          expect(subject.config.since).to eql('master')
          expect(diff.to).to eql('master')
          expect(diff.config.since).to eql('master')
        end
      end
    end

    context 'with results dir flag' do
      let(:flags) { %w[--results-dir tmp/results] }
      let(:expected_results_dir) { 'tmp/results' }

      it_should_behave_like 'a cli parser'

      it 'persists the configured results directory' do
        expect(subject.config.results_dir).to eql('tmp/results')
      end
    end

    context 'with subject-ignore flag' do
      let(:flags) { %w[--ignore-subject Foo::Bar] }

      let(:expected_matcher_config) do
        default_matcher_config.with(ignore_expressions: [parse_expression('Foo::Bar')])
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with fail-fast flag' do
      let(:flags) { %w[--fail-fast] }

      it_should_behave_like 'a cli parser'

      it 'sets the fail fast option' do
        expect(subject.config.fail_fast).to be(true)
      end
    end

    context 'with zombie flag' do
      let(:flags) { %w[--zombie] }

      it_should_behave_like 'a cli parser'

      it 'sets the zombie option' do
        expect(subject.config.zombie).to be(true)
      end
    end
  end

  describe 'private option builders' do
    let(:cli) do
      described_class.allocate.tap do |object|
        object.instance_variable_set(:@config, Mutant::Config::DEFAULT)
      end
    end

    it 'applies the results dir option block to the config' do
      opts = instance_double(OptionParser)
      block = nil

      allow(opts).to receive(:separator)
      expect(opts).to receive(:on)
        .with('--use INTEGRATION', 'Use INTEGRATION to kill mutations')
      expect(opts).to receive(:on)
        .with('--results-dir DIRECTORY', 'Write machine-readable results to DIRECTORY') do |*_, &captured|
          block = captured
        end

      cli.send(:add_mutation_options, opts)
      block.call('tmp/results')

      expect(cli.config.results_dir).to eql('tmp/results')
    end

    it 'applies the since option block before building the diff filter' do
      opts = instance_double(OptionParser)
      ignore_block = nil
      since_block = nil

      expect(opts).to receive(:on)
        .with('--ignore-subject EXPRESSION', 'Ignore subjects that match EXPRESSION as prefix') do |*_, &captured|
          ignore_block = captured
        end
      expect(opts).to receive(:on)
        .with('--since REVISION', 'Only select subjects touched since REVISION') do |*_, &captured|
          since_block = captured
        end

      cli.send(:add_filter_options, opts)
      ignore_block.call('Foo::Bar')
      since_block.call('master')

      diff = cli.config.matcher.subject_filters.fetch(0).send(:diff)

      aggregate_failures do
        expect(cli.config.since).to eql('master')
        expect(diff.to).to eql('master')
        expect(diff.config.since).to eql('master')
      end
    end
  end
end
