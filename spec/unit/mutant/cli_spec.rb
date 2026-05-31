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

    let(:default_matcher_config) do
      Mutant::Matcher::Config::DEFAULT
        .with(match_expressions: expressions.map(&method(:parse_expression)))
    end
    let(:help_message) do
      <<~MESSAGE
        usage: mutant [options] MATCH_EXPRESSION ...
        Environment:
                --zombie                     Run mutant zombified
            -I, --include DIRECTORY          Add DIRECTORY to $LOAD_PATH
            -r, --require NAME               Require file with NAME
            -j, --jobs NUMBER                Number of kill jobs. Defaults to MUTANT_JOBS or 1.

        Options:
                --use INTEGRATION            Use INTEGRATION to kill mutations
                --include-subject EXPRESSION Add EXPRESSION to the configured subject matcher list
                --ignore-subject EXPRESSION  Ignore subjects that match EXPRESSION as prefix
                --since REVISION             Only select subjects touched since REVISION
                --fail-fast                  Fail fast
                --version                    Print mutants version
            -h, --help                       Show this message
      MESSAGE
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

      let(:expected_message) { help_message }
    end

    context 'with invalid MUTANT_JOBS env variable and help flag' do
      let(:flags) { %w[--help] }

      around do |example|
        ENV.store('MUTANT_JOBS', 'nope')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      before do
        expect($stdout).to receive(:puts).with(expected_message)
        expect(Kernel).to receive(:exit)
      end

      it_should_behave_like 'a cli parser'

      let(:expected_message) { help_message }
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

    context 'with invalid MUTANT_JOBS env variable and version flag' do
      let(:flags) { %w[--version] }

      around do |example|
        ENV.store('MUTANT_JOBS', 'nope')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      before do
        expect(Kernel).to receive(:exit)
        expect($stdout).to receive(:puts).with("mutant-#{Mutant::VERSION}")
      end

      it_should_behave_like 'a cli parser'
    end

    context 'without jobs flag or env variable' do
      it 'defaults to 1 job' do
        expect(subject.config.jobs).to eql(1)
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with jobs flag' do
      let(:flags) { %w[--jobs 2] }

      it_should_behave_like 'a cli parser'

      it 'configures expected coverage' do
        expect(subject.config.jobs).to eql(2)
      end
    end

    context 'with invalid jobs flag' do
      let(:flags) { %w[--jobs nope] }

      let(:expected_message) { '--jobs must be an integer' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with jobs flag below minimum' do
      let(:flags) { %w[--jobs 0] }

      let(:expected_message) { '--jobs must be >= 1' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with negative jobs flag' do
      let(:flags) { %w[--jobs -1] }

      let(:expected_message) { '--jobs must be >= 1' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with invalid MUTANT_JOBS env variable' do
      around do |example|
        ENV.store('MUTANT_JOBS', 'nope')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      let(:expected_message) { 'MUTANT_JOBS must be an integer' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with MUTANT_JOBS env variable below minimum' do
      around do |example|
        ENV.store('MUTANT_JOBS', '0')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      let(:expected_message) { 'MUTANT_JOBS must be >= 1' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with negative MUTANT_JOBS env variable' do
      around do |example|
        ENV.store('MUTANT_JOBS', '-1')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      let(:expected_message) { 'MUTANT_JOBS must be >= 1' }

      it_should_behave_like 'an invalid cli run'
    end

    context 'with MUTANT_JOBS env variable' do
      around do |example|
        ENV.store('MUTANT_JOBS', '4')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      it 'uses MUTANT_JOBS as default jobs value' do
        expect(subject.config.jobs).to eql(4)
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with MUTANT_JOBS env variable and --jobs flag' do
      let(:flags) { %w[--jobs 2] }

      around do |example|
        ENV.store('MUTANT_JOBS', '4')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      it 'CLI --jobs overrides MUTANT_JOBS' do
        expect(subject.config.jobs).to eql(2)
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with invalid MUTANT_JOBS env variable and --jobs flag' do
      let(:flags) { %w[--jobs 2] }

      around do |example|
        ENV.store('MUTANT_JOBS', 'nope')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      it 'CLI --jobs ignores invalid MUTANT_JOBS defaults' do
        expect(subject.config.jobs).to eql(2)
      end

      it_should_behave_like 'a cli parser'
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

      let(:expected_matcher_config) do
        default_matcher_config.with(
          subject_filters: [
            Mutant::Repository::SubjectFilter.new(
              Mutant::Repository::Diff.new(
                config: Mutant::Config::DEFAULT,
                from:   'master',
                to:     'HEAD'
              )
            )
          ]
        )
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with subject-ignore flag' do
      let(:flags) { %w[--ignore-subject Foo::Bar] }

      let(:expected_matcher_config) do
        default_matcher_config.with(ignore_expressions: [parse_expression('Foo::Bar')])
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with include-subject flag' do
      let(:flags) { %w[--include-subject Foo::Bar] }
      let(:expressions) { [] }

      let(:expected_matcher_config) do
        Mutant::Matcher::Config::DEFAULT.with(match_expressions: [parse_expression('Foo::Bar')])
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with include-subject flag and preconfigured matcher expressions' do
      let(:flags) { %w[--include-subject Foo::Bar] }
      let(:expressions) { [] }

      let(:configured_default) do
        Mutant::Config::DEFAULT.with(
          matcher: Mutant::Matcher::Config::DEFAULT.with(
            match_expressions: [parse_expression('Configured::Subject')]
          )
        )
      end

      let(:expected_matcher_config) do
        Mutant::Matcher::Config::DEFAULT.with(
          match_expressions: [
            parse_expression('Configured::Subject'),
            parse_expression('Foo::Bar')
          ]
        )
      end

      before do
        stub_const('Mutant::Config::DEFAULT', configured_default)
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

  describe '#setup' do
    subject(:setup_cli) { cli.send(:setup, arguments) }

    let(:cli)       { described_class.allocate }
    let(:arguments) { %w[foo] }

    before do
      allow(cli).to receive(:parse)
    end

    it 'sets defaults and parses the provided arguments' do
      setup_cli

      expect(cli.config).to eql(Mutant::Config::DEFAULT)
      expect(cli.send(:state)).to eql(
        exit_requested: false,
        jobs_explicit: false
      )
      expect(cli.send(:apply_jobs_env_defaults?)).to be(true)
      expect(cli).to have_received(:parse).with(arguments)
    end
  end

  describe 'private helpers' do
    subject(:cli) do
      described_class.allocate.tap do |object|
        object.send(:initialize, [])
      end
    end

    describe '#add' do
      it 'appends the value to the selected configuration attribute' do
          expect { cli.send(:add, :includes, 'foo') }
          .to change { cli.config.includes }
          .from(Mutant::EMPTY_ARRAY)
          .to(%w[foo])
      end
    end

    describe '#add_debug_options' do
      let(:option_parser) { OptionParser.new }

      before do
        cli.send(:add_debug_options, option_parser)
      end

      it 'enables fail-fast via the configured option handler' do
        expect { option_parser.parse!(%w[--fail-fast]) }
          .to change { cli.config.fail_fast }
          .from(false)
          .to(true)
      end

      it 'uses the configured kernel for --version exits' do
        expect($stdout).to receive(:puts).with("mutant-#{Mutant::VERSION}")
        expect(cli.config.kernel).to receive(:exit)

        option_parser.parse!(%w[--version])
      end

      it 'uses the configured kernel for --help exits' do
        expect($stdout).to receive(:puts).with(option_parser.to_s)
        expect(cli.config.kernel).to receive(:exit)

        option_parser.parse!(%w[--help])
      end
    end
  end
end
