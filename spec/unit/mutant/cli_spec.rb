# frozen_string_literal: true

RSpec.describe Mutant::CLI do
  let(:object) { described_class }

  def build_processed_cli(arguments)
    described_class.allocate.tap do |cli|
      cli.send(:initialize, arguments)
    end
  end

  describe Mutant::CLIArgumentSanitizer, mutant_expression: 'Mutant::CLIArgumentSanitizer*' do
    subject(:sanitize_arguments) { described_class.call($stderr, arguments) }

    let(:arguments) { original_arguments.dup }

    context 'when usage is passed as separate option and value' do
      let(:original_arguments) { %w[--usage opensource TestApp*] }

      it 'removes both arguments and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[TestApp*])
      end
    end

    context 'when usage is passed as inline assignment' do
      let(:original_arguments) { %w[--usage=commercial TestApp*] }

      it 'removes the option and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[TestApp*])
      end
    end

    context 'when inline usage is followed by a known value' do
      let(:original_arguments) { %w[--usage=commercial opensource TestApp*] }

      it 'removes only the inline flag and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[opensource TestApp*])
      end
    end

    context 'when usage commercial is passed as separate option and value' do
      let(:original_arguments) { %w[--usage commercial TestApp*] }

      it 'removes both arguments and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[TestApp*])
      end
    end

    context 'when usage is passed with another value' do
      let(:original_arguments) { %w[--usage proprietary TestApp*] }

      it 'removes only the flag and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[proprietary TestApp*])
      end
    end

    context 'when usage is passed before another option' do
      let(:original_arguments) { %w[--usage --help] }

      it 'removes only the usage flag and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[--help])
      end
    end

    context 'when usage is passed multiple times' do
      let(:original_arguments) { %w[--usage opensource --usage=commercial TestApp*] }

      it 'removes every usage flag and warns once' do
        expect($stderr).to receive(:puts).with(described_class::WARNING).once

        expect(sanitize_arguments).to eql(%w[TestApp*])
      end
    end

    context 'when usage is absent' do
      let(:original_arguments) { %w[TestApp*] }

      it 'returns arguments unchanged without warning' do
        expect($stderr).not_to receive(:puts)

        expect(sanitize_arguments).to eql(%w[TestApp*])
      end
    end

    context 'when usage with a known value appears after other arguments' do
      let(:original_arguments) { %w[--include lib --usage opensource TestApp*] }

      it 'removes the flag and its value regardless of position' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[--include lib TestApp*])
      end
    end

    context 'when usage is the last argument' do
      let(:original_arguments) { %w[TestApp* --usage] }

      it 'removes only the flag and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[TestApp*])
      end
    end

    context 'when usage flag is a non-interned string' do
      let(:original_arguments) { [String.new('--usage'), 'opensource', 'TestApp*'] }

      it 'removes both arguments and warns' do
        expect($stderr).to receive(:puts).with(described_class::WARNING)

        expect(sanitize_arguments).to eql(%w[TestApp*])
      end
    end

    context 'when an argument resembles but does not match usage' do
      let(:original_arguments) { %w[--usageother TestApp*] }

      it 'returns arguments unchanged without warning' do
        expect($stderr).not_to receive(:puts)

        expect(sanitize_arguments).to eql(%w[--usageother TestApp*])
      end
    end
  end

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

  describe '.run', mutant: false do
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

  describe '.call', mutant: false do
    subject(:call) { object.call(arguments) }

    let(:arguments) { %w[run TestApp*] }
    let(:cli)       { described_class.allocate }
    let(:config)    { instance_double(Mutant::Config) }

    it 'returns the config from the constructed cli instance' do
      expect(object).to receive(:allocate).and_return(cli)
      expect(cli).to receive(:process).with(arguments)
      expect(cli).to receive(:config).and_return(config)

      expect(call).to eql(config)
    end

  end

  describe 'processed cli', mutant: false do
    subject { build_processed_cli(arguments) }

    before do
      allow_any_instance_of(described_class).to receive(:cli_exit)
    end

    let(:expected_integration)    { Mutant::Integration::Null        }
    let(:expected_reporter)       { Mutant::Config::DEFAULT.reporter }
    let(:expected_matcher_config) { default_matcher_config           }

    let(:default_matcher_config) do
      Mutant::Matcher::Config::DEFAULT
        .with(match_expressions: expressions.map(&method(:parse_expression)))
    end
    let(:help_message) do
      <<~MESSAGE
        usage: mutant run [options] MATCH_EXPRESSION ...
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
                --results-dir DIR            Write YAML results to DIR
                --fail-fast                  Fail fast
      MESSAGE
    end

    let(:flags)       { []           }
    let(:expressions) { %w[TestApp*] }

    let(:arguments) { %w[run] + flags + expressions }

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
      let(:expected_matcher_config) { Mutant::Matcher::Config::DEFAULT }

      before do
        expect(help_message).not_to include('--usage')
        expect($stdout).to receive(:puts).with(expected_message)
        expect_any_instance_of(described_class).to receive(:cli_exit)
      end

      it_should_behave_like 'a cli parser'

      let(:expected_message) { help_message }
    end

    context 'with invalid MUTANT_JOBS env variable and help flag' do
      let(:flags) { %w[--help] }
      let(:expected_matcher_config) { Mutant::Matcher::Config::DEFAULT }

      around do |example|
        ENV.store('MUTANT_JOBS', 'nope')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      before do
        expect($stdout).to receive(:puts).with(expected_message)
        expect_any_instance_of(described_class).to receive(:cli_exit)
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

    context 'with usage flag' do
      before do
        expect($stderr).to receive(:puts).with(Mutant::CLIArgumentSanitizer::WARNING)
      end

      context 'when passed as separate option and value' do
        let(:flags) { %w[--usage opensource] }

        it_should_behave_like 'a cli parser'
      end

      context 'when passed as inline option assignment' do
        let(:flags) { %w[--usage=commercial] }

        it_should_behave_like 'a cli parser'
      end

      context 'when passed commercial as separate option and value' do
        let(:flags) { %w[--usage commercial] }

        it_should_behave_like 'a cli parser'
      end

      context 'when passed with another value' do
        let(:flags) { %w[--usage proprietary] }

        let(:expected_matcher_config) do
          Mutant::Matcher::Config::DEFAULT.with(
            match_expressions: [
              parse_expression('proprietary'),
              parse_expression('TestApp*')
            ]
          )
        end

        it_should_behave_like 'a cli parser'
      end

      context 'when passed before a match expression' do
        let(:flags) { %w[--usage] }

        it_should_behave_like 'a cli parser'
      end
    end

    context 'with usage flag before help flag' do
      let(:flags) { %w[--usage --help] }
      let(:expected_matcher_config) { Mutant::Matcher::Config::DEFAULT }

      before do
        expect(help_message).not_to include('--usage')
        expect($stdout).to receive(:puts).with(help_message)
        expect_any_instance_of(described_class).to receive(:cli_exit)
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with version flag' do
      let(:flags) { %w[--version] }
      let(:expected_matcher_config) { Mutant::Matcher::Config::DEFAULT }

      before do
        expect_any_instance_of(described_class).to receive(:cli_exit)
        expect($stdout).to receive(:puts).with("mutant-#{Mutant::VERSION}")
      end

      it_should_behave_like 'a cli parser'
    end

    context 'with invalid MUTANT_JOBS env variable and version flag' do
      let(:flags) { %w[--version] }
      let(:expected_matcher_config) { Mutant::Matcher::Config::DEFAULT }

      around do |example|
        ENV.store('MUTANT_JOBS', 'nope')
        example.run
      ensure
        ENV.delete('MUTANT_JOBS')
      end

      before do
        expect_any_instance_of(described_class).to receive(:cli_exit)
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

    context 'with config file' do
      around do |example|
        Dir.mktmpdir do |directory|
          Dir.chdir(directory) do
            Pathname.new(directory).join('.mutant.yml').write(yaml_content)
            example.run
          end
        end
      end

      context 'with jobs only' do
        let(:yaml_content) { "jobs: 4\n" }

        context 'without overriding flags' do
          it_should_behave_like 'a cli parser'

          it 'loads jobs from config file' do
            expect(subject.config.jobs).to eql(4)
          end
        end

        context 'with overriding jobs flag' do
          let(:flags) { %w[--jobs 2] }

          it_should_behave_like 'a cli parser'

          it 'prefers cli flags over config file values' do
            expect(subject.config.jobs).to eql(2)
          end
        end

        context 'with MUTANT_JOBS env variable' do
          around do |example|
            ENV.store('MUTANT_JOBS', '6')
            example.run
          ensure
            ENV.delete('MUTANT_JOBS')
          end

          it 'prefers config file values over MUTANT_JOBS' do
            expect(subject.config.jobs).to eql(4)
          end
        end

        context 'with invalid MUTANT_JOBS env variable' do
          around do |example|
            ENV.store('MUTANT_JOBS', 'nope')
            example.run
          ensure
            ENV.delete('MUTANT_JOBS')
          end

          it 'still uses the config file jobs value' do
            expect(subject.config.jobs).to eql(4)
          end
        end
      end

      context 'with matcher subjects' do
        let(:yaml_content) { "matcher:\n  subjects:\n    - YAMLApp*\n" }
        let(:expressions) { [] }

        it 'uses yaml matcher subjects when no cli expressions' do
          expect(subject.config.matcher.match_expressions.map(&:syntax)).to eql(%w[YAMLApp*])
        end

        context 'with cli positional expressions' do
          let(:expressions) { %w[CLIApp*] }

          it 'overrides yaml matcher subjects with cli expressions' do
            expect(subject.config.matcher.match_expressions.map(&:syntax)).to eql(%w[CLIApp*])
          end
        end
      end
    end

    context 'when config file is invalid' do
      let(:arguments) { [] }
      let(:error)     { Mutant::Config::Loader::Error.new('invalid yaml') }
      let(:loader)    { instance_double(Mutant::Config::Loader) }

      before do
        expect(Mutant::Config::Loader).to receive(:new)
          .with(Mutant::Config::DEFAULT)
          .and_return(loader)
        expect(loader).to receive(:load).and_raise(error)
      end

      it 'wraps the loader error as a cli error' do
        expect { object.new(arguments) }.to raise_error(Mutant::CLI::Error, 'invalid yaml')
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

      let(:expected_matcher_config) do
        default_matcher_config.with(
          subject_filters: [
            Mutant::Repository::SubjectFilter.new(
              Mutant::Repository::Diff.new(
                config: Mutant::Config::DEFAULT.with(since_revision: 'master'),
                from:   'master',
                to:     'HEAD'
              )
            )
          ]
        )
      end

      it_should_behave_like 'a cli parser'

      it 'sets since_revision on config' do
        expect(subject.config.since_revision).to eql('master')
      end
    end

    context 'with --results-dir flag' do
      let(:flags) { %w[--results-dir /tmp/custom-results] }

      it 'sets results_dir to a Pathname with the given path' do
        expect(subject.config.results_dir).to eql(Pathname.new('/tmp/custom-results'))
      end
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

    context 'backward compatibility without subcommand' do
      let(:arguments) { flags + expressions }
      let(:flags)     { %w[--zombie] }

      it 'prints deprecation warning to stderr' do
        expect($stderr).to receive(:puts).with(Mutant::CLI::DEPRECATION_WARNING)
        subject
      end

      it 'still parses arguments correctly' do
        allow($stderr).to receive(:puts)
        expect(subject.config.zombie).to be(true)
      end
    end

    context 'backward compatibility with flags but no subcommand' do
      let(:arguments) { %w[--fail-fast TestApp*] }

      it 'prints deprecation warning and processes args as run' do
        expect($stderr).to receive(:puts).with(Mutant::CLI::DEPRECATION_WARNING)
        expect(subject.config.fail_fast).to be(true)
      end
    end

    context 'bare --help without subcommand' do
      let(:arguments) { %w[--help] }

      before do
        expect($stdout).to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
        expect_any_instance_of(described_class).to receive(:cli_exit)
      end

      it 'prints main help without deprecation warning' do
        expect($stderr).not_to receive(:puts)
        subject
      end
    end

    context 'bare --version without subcommand' do
      let(:arguments) { %w[--version] }

      before do
        expect_any_instance_of(described_class).to receive(:cli_exit)
        expect($stdout).to receive(:puts).with("mutant-#{Mutant::VERSION}")
      end

      it 'prints version without deprecation warning' do
        expect($stderr).not_to receive(:puts)
        subject
      end
    end

    context 'help subcommand' do
      context 'with no argument' do
        let(:arguments) { %w[help] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'prints main help' do
          subject
        end
      end

      context 'with run argument' do
        let(:arguments) { %w[help run] }

        before do
          expect($stdout).to receive(:puts).with(expected_message)
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'prints run help' do
          subject
        end

        let(:expected_message) do
          <<~MESSAGE
            usage: mutant run [options] MATCH_EXPRESSION ...
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
                    --results-dir DIR            Write YAML results to DIR
                    --fail-fast                  Fail fast
          MESSAGE
        end
      end

      context 'with environment argument' do
        let(:arguments) { %w[help environment] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'prints environment help' do
          subject
        end
      end

      context 'with session argument' do
        let(:arguments) { %w[help session] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'prints session help' do
          subject
        end
      end

      context 'with unknown subcommand' do
        let(:arguments) { %w[help unknown] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'falls back to main help' do
          subject
        end
      end

      context 'with extra arguments' do
        let(:arguments) { %w[help run extra another] }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            'help does not accept arguments: extra another'
          )
        end
      end
    end

    context 'environment subcommand' do
      let(:arguments) { %w[environment --zombie TestApp*] }
      let(:expected_matcher) do
        Mutant::Matcher::Config::DEFAULT.with(
          match_expressions: [parse_expression('TestApp*')]
        )
      end

      before do
        expect($stdout).to receive(:puts).with('Mutant environment:')
        expect($stdout).to receive(:puts).with("  Integration:     #{Mutant::Integration::Null}")
        expect($stdout).to receive(:puts).with("  Jobs:            #{Mutant::Config::DEFAULT.jobs}")
        expect($stdout).to receive(:puts).with('  Includes:        []')
        expect($stdout).to receive(:puts).with('  Requires:        []')
        expect($stdout).to receive(:puts).with('  Fail fast:       false')
        expect($stdout).to receive(:puts).with('  Zombie:          true')
        expect($stdout).to receive(:puts).with("  Matcher:         #{expected_matcher.inspect}")
        expect_any_instance_of(described_class).to receive(:cli_exit)
      end

      it 'parses config options' do
        subject
      end
    end

    context 'environment subcommand with help flag' do
      let(:arguments) { %w[environment --help] }

      before do
        expect($stdout).to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
        expect_any_instance_of(described_class).to receive(:cli_exit)
      end

      it 'prints environment help' do
        subject
      end
    end

    context 'session subcommand' do
      let(:tmpdir) { Dir.mktmpdir }

      around do |example|
        Dir.chdir(tmpdir) { example.run }
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      def create_result_file(name, data)
        results_dir = File.join(tmpdir, '.mutant', 'results')
        FileUtils.mkdir_p(results_dir)
        File.write(File.join(results_dir, "#{name}.yml"), YAML.dump(data))
      end

      context 'list with no sessions' do
        let(:arguments) { %w[session list] }

        before do
          expect($stdout).to receive(:puts).with('No sessions found in .mutant/results/')
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'reports no sessions' do
          subject
        end
      end

      context 'list with sessions' do
        let(:arguments) { %w[session list] }

        before do
          create_result_file('abc123', { success: true, coverage: '100%' })
          create_result_file('def456', { 'success' => false, 'coverage' => '75%' })
          expect($stdout).to receive(:puts).with('Sessions (2):')
          expect($stdout).to receive(:puts).with('  abc123  coverage: 100%  status: pass')
          expect($stdout).to receive(:puts).with('  def456  coverage: 75%  status: fail')
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'lists sessions from .mutant/results' do
          subject
        end
      end

      context 'show with existing id' do
        let(:arguments) { %w[session show abc123] }

        before do
          create_result_file('abc123', {
                               success: true,
                               coverage: '100%',
                               subject_results: [
                                 { expression: 'Foo#bar' },
                                 { 'expression' => 'Foo#baz' }
                               ]
                             })
          expect($stdout).to receive(:puts).with('Session: abc123')
          expect($stdout).to receive(:puts).with('  Status:   pass')
          expect($stdout).to receive(:puts).with('  Coverage: 100%')
          expect($stdout).to receive(:puts).with('  Subjects: 2')
          expect($stdout).to receive(:puts).with('    Foo#bar')
          expect($stdout).to receive(:puts).with('    Foo#baz')
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'shows session details from .mutant/results' do
          subject
        end
      end

      context 'show with missing id' do
        let(:arguments) { %w[session show missing] }

        it 'raises not found error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            "Session 'missing' not found in .mutant/results/"
          )
        end
      end

      context 'show with invalid id' do
        let(:arguments) { %w[session show ../secrets] }

        it 'raises invalid id error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            "Invalid session ID '../secrets'"
          )
        end
      end

      context 'show without id' do
        let(:arguments) { %w[session show] }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            'session show requires a session ID argument'
          )
        end
      end

      context 'show with extra arguments' do
        let(:arguments) { %w[session show abc123 extra] }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            'session show does not accept arguments: extra'
          )
        end
      end

      context 'list with extra arguments' do
        let(:arguments) { %w[session list extra another] }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            'session list does not accept arguments: extra another'
          )
        end
      end

      context 'show with invalid yaml' do
        let(:arguments) { %w[session show abc123] }

        before do
          results_dir = File.join(tmpdir, '.mutant', 'results')
          FileUtils.mkdir_p(results_dir)
          File.write(File.join(results_dir, 'abc123.yml'), ": foo\n")
        end

        it 'raises a session load error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            /Could not load session 'abc123':/
          )
        end
      end

      context 'show with non-hash yaml' do
        let(:arguments) { %w[session show abc123] }

        before do
          results_dir = File.join(tmpdir, '.mutant', 'results')
          FileUtils.mkdir_p(results_dir)
          File.write(File.join(results_dir, 'abc123.yml'), YAML.dump(['not-a-hash']))
        end

        it 'raises a session load error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            "Could not load session 'abc123': expected a hash payload"
          )
        end
      end

      context 'with no sub-subcommand' do
        let(:arguments) { %w[session] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'prints session help' do
          subject
        end
      end

      context 'with unknown sub-subcommand' do
        let(:arguments) { %w[session unknown] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect_any_instance_of(described_class).to receive(:cli_exit)
        end

        it 'prints session help' do
          subject
        end
      end
    end
  end

  describe 'dispatch internals' do
    let(:config) { Mutant::Config::DEFAULT }

    before do
      allow_any_instance_of(described_class).to receive(:cli_exit)
    end

    def build_cli
      described_class.allocate.tap do |cli|
        cli.instance_variable_set(:@config, config)
      end
    end

    describe '#process' do
      it 'dispatches normalized arguments on the instance' do
        arguments = %w[run --fail-fast TestApp*]
        normalized_arguments = %w[run TestApp*]
        cli = described_class.allocate

        expect(cli).to receive(:normalize_arguments).with(arguments).and_return(normalized_arguments)
        expect(cli).to receive(:dispatch).with(normalized_arguments)

        cli.send(:process, arguments)
      end

      it 'leaves config at the default before any configuration changes' do
        expect(described_class.allocate.config).to eql(Mutant::Config::DEFAULT)
      end
    end

    describe 'subcommand dispatch from process' do
      def build_dispatch_probe
        Class.new(described_class) do
          attr_reader :dispatched

        private

          def handle_run(arguments)
            @dispatched = [:run, arguments]
          end

          def handle_environment(arguments)
            @dispatched = [:environment, arguments]
          end

          def handle_session(arguments)
            @dispatched = [:session, arguments]
          end

          def handle_help(arguments)
            @dispatched = [:help, arguments]
          end
        end
      end

      it 'dispatches run with an empty argument array' do
        cli = build_dispatch_probe.allocate
        cli.send(:process, %w[run])

        expect(cli.dispatched).to eql([:run, []])
      end

      it 'dispatches environment with an empty argument array' do
        cli = build_dispatch_probe.allocate
        cli.send(:process, %w[environment])

        expect(cli.dispatched).to eql([:environment, []])
      end

      it 'dispatches session with an empty argument array' do
        cli = build_dispatch_probe.allocate
        cli.send(:process, %w[session])

        expect(cli.dispatched).to eql([:session, []])
      end

      it 'dispatches help with an empty argument array' do
        cli = build_dispatch_probe.allocate
        cli.send(:process, %w[help])

        expect(cli.dispatched).to eql([:help, []])
      end
    end

    describe '#normalize_arguments' do
      subject(:normalized_arguments) { cli.send(:normalize_arguments, arguments) }

      let(:cli) { build_cli }

      context 'with no arguments' do
        let(:arguments) { [] }

        it 'returns the same empty array' do
          expect(normalized_arguments).to eql([])
        end
      end

      context 'with an explicit subcommand' do
        let(:arguments) { %w[session list] }

        it 'does not add the run alias' do
          expect(normalized_arguments).to eql(%w[session list])
        end
      end

      context 'with the run subcommand' do
        let(:arguments) { %w[run TestApp*] }

        it 'does not warn or rewrite arguments' do
          expect(cli).not_to receive(:warn_deprecation)

          expect(normalized_arguments).to eql(%w[run TestApp*])
        end
      end

      context 'with a single global help flag' do
        let(:arguments) { %w[--help] }

        it 'does not warn or rewrite arguments' do
          expect(cli).not_to receive(:warn_deprecation)

          expect(normalized_arguments).to eql(%w[--help])
        end
      end

      context 'with a single global short help flag' do
        let(:arguments) { %w[-h] }

        it 'does not warn or rewrite arguments' do
          expect(cli).not_to receive(:warn_deprecation)

          expect(normalized_arguments).to eql(%w[-h])
        end
      end

      context 'with a single global version flag' do
        let(:arguments) { %w[--version] }

        it 'does not warn or rewrite arguments' do
          expect(cli).not_to receive(:warn_deprecation)

          expect(normalized_arguments).to eql(%w[--version])
        end
      end

      context 'without a subcommand' do
        let(:arguments) { %w[TestApp* --fail-fast] }

        it 'warns and prefixes the run subcommand' do
          expect(cli).to receive(:warn_deprecation)

          expect(normalized_arguments).to eql(%w[run TestApp* --fail-fast])
        end
      end
    end

    describe '#puts' do
      let(:cli) { build_cli }

      it 'writes explicit messages to stdout' do
        expect($stdout).to receive(:puts).with('hello')

        cli.send(:puts, 'hello')
      end

      it 'accepts a missing message and forwards nil to stdout' do
        expect($stdout).to receive(:puts).with(nil)

        cli.send(:puts)
      end
    end

    describe '#cli_exit' do
      let(:kernel) { class_double(Kernel) }
      let(:config) { instance_double(Mutant::Config, kernel: kernel) }
      let(:cli) do
        described_class.allocate.tap do |instance|
          instance.instance_variable_set(:@config, config)
        end
      end

      it 'delegates to the configured kernel exit via public_send' do
        allow(cli).to receive(:cli_exit).and_call_original
        expect(kernel).to receive(:public_send).with(:exit)

        cli.send(:cli_exit)
      end
    end

    describe '#dispatch' do
      subject(:dispatch) { cli.send(:dispatch, arguments) }

      let(:cli) { build_cli }

      context 'with the run subcommand' do
        let(:arguments) { %w[run TestApp*] }

        it 'forwards the remaining arguments to the run handler' do
          expect(cli).to receive(:handle_run).with(%w[TestApp*])
          expect(cli).not_to receive(:parse)

          dispatch
        end
      end

      context 'with the environment subcommand' do
        let(:arguments) { %w[environment --zombie] }

        it 'forwards the remaining arguments to the environment handler' do
          expect(cli).to receive(:handle_environment).with(%w[--zombie])
          expect(cli).not_to receive(:parse)

          dispatch
        end
      end

      context 'with the session subcommand' do
        let(:arguments) { %w[session list] }

        it 'forwards the remaining arguments to the session handler' do
          expect(cli).to receive(:handle_session).with(%w[list])
          expect(cli).not_to receive(:parse)

          dispatch
        end
      end

      context 'with the help subcommand' do
        let(:arguments) { %w[help run] }

        it 'forwards the remaining arguments to the help handler' do
          expect(cli).to receive(:handle_help).with(%w[run])
          expect(cli).not_to receive(:parse)

          dispatch
        end
      end

      context 'with a bare help flag' do
        let(:arguments) { %w[--help] }

        it 'prints main help and exits' do
          expect(cli).to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect(cli).not_to receive(:parse)
          expect(cli).to receive(:cli_exit)

          dispatch
        end
      end

      context 'without a subcommand' do
        let(:arguments) { %w[TestApp*] }

        it 'falls back to parse' do
          expect(cli).to receive(:parse).with(%w[TestApp*])

          dispatch
        end
      end

      context 'with a help flag and additional arguments' do
        let(:arguments) { %w[--help extra] }

        it 'parses instead of printing main help' do
          expect(cli).to receive(:parse).with(%w[--help extra])
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect(cli).not_to receive(:cli_exit)

          dispatch
        end
      end
    end

    describe '#handle_session' do
      subject(:handle_session) { cli.send(:handle_session, arguments) }

      let(:cli) { build_cli }

      before do
        expect(cli).to receive(:cli_exit)
      end

      context 'for list without extra arguments' do
        let(:arguments) { ['list'] }

        it 'forwards an empty array to the list handler' do
          expect(cli).to receive(:print_session_list).with([])
          handle_session
        end
      end

      context 'for show without extra arguments' do
        let(:arguments) { %w[show abc123] }

        it 'forwards an empty array to the show handler' do
          expect(cli).to receive(:print_session_show).with('abc123', [])
          handle_session
        end
      end

      context 'for list with extra arguments' do
        let(:arguments) { %w[list first second] }

        it 'forwards all extra arguments to the list handler' do
          expect(cli).to receive(:print_session_list).with(%w[first second])
          handle_session
        end
      end

      context 'for an unknown subcommand' do
        let(:arguments) { %w[unknown] }

        it 'prints session help before exiting' do
          expect(cli).to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          handle_session
        end
      end
    end

    describe '#handle_run' do
      subject(:handle_run) { cli.send(:handle_run, arguments) }

      let(:cli) { build_cli }
      let(:arguments) { %w[TestApp* --fail-fast] }

      it 'delegates directly to parse' do
        expect(cli).to receive(:parse).with(arguments)

        handle_run
      end
    end

    describe '#handle_environment' do
      subject(:handle_environment) { cli.send(:handle_environment, arguments) }

      let(:cli) { build_cli }

      context 'when help appears after other arguments' do
        let(:arguments) { %w[TestApp* --help] }

        it 'prints environment help and skips parsing' do
          expect(cli).to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect(cli).not_to receive(:parse)
          expect(cli).not_to receive(:print_environment)
          expect(cli).to receive(:cli_exit)

          handle_environment
        end
      end

      context 'when short help flag is used' do
        let(:arguments) { %w[-h] }

        it 'prints environment help and skips parsing' do
          expect(cli).to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect(cli).not_to receive(:parse)
          expect(cli).not_to receive(:print_environment)
          expect(cli).to receive(:cli_exit)

          handle_environment
        end
      end

      context 'when help is not requested' do
        let(:arguments) { %w[TestApp*] }

        it 'parses arguments, prints the environment and exits' do
          expect(cli).to receive(:parse).with(arguments)
          expect(cli).to receive(:print_environment)
          expect(cli).to receive(:cli_exit)

          handle_environment
        end
      end
    end

    describe '#handle_help' do
      subject(:handle_help) { cli.send(:handle_help, arguments) }

      let(:cli) { build_cli }

      context 'with the run subcommand' do
        let(:arguments) { %w[run] }

        it 'prints run help and exits' do
          expect(cli).to receive(:puts).with(a_string_starting_with('usage: mutant run [options] MATCH_EXPRESSION ...'))
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect(cli).to receive(:cli_exit)

          handle_help
        end
      end

      context 'with the environment subcommand' do
        let(:arguments) { %w[environment] }

        it 'prints environment help and exits' do
          expect(cli).to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect(cli).to receive(:cli_exit)

          handle_help
        end
      end

      context 'with the session subcommand' do
        let(:arguments) { %w[session] }

        it 'prints session help and exits' do
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect(cli).to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect(cli).to receive(:cli_exit)

          handle_help
        end
      end

      context 'with an unknown subcommand' do
        let(:arguments) { %w[unknown] }

        it 'prints main help and exits' do
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect(cli).not_to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect(cli).to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect(cli).to receive(:cli_exit)

          handle_help
        end
      end

      context 'with extra arguments' do
        let(:arguments) { %w[run extra another] }

        it 'raises the original error with the full argument list' do
          expect { handle_help }.to raise_error(
            Mutant::CLI::Error,
            'help does not accept arguments: extra another'
          )
        end
      end
    end
  end

  describe 'option helpers' do
    let(:cli) { described_class.allocate.tap { |o| o.send(:setup, []) } }

    before do
      allow(cli).to receive(:cli_exit)
    end

    describe '#add_environment_options' do
      let(:parser) { OptionParser.new }

      before do
        cli.send(:add_environment_options, parser)
      end

      it 'registers the expected option signatures' do
        parser_double = instance_double(OptionParser)

        expect(parser_double).to receive(:separator).with('Environment:').ordered
        expect(parser_double).to receive(:on).with('--zombie', 'Run mutant zombified').ordered
        expect(parser_double).to receive(:on).with('-I', '--include DIRECTORY', 'Add DIRECTORY to $LOAD_PATH').ordered
        expect(parser_double).to receive(:on).with('-r', '--require NAME', 'Require file with NAME').ordered
        expect(parser_double)
          .to receive(:on)
          .with('-j', '--jobs NUMBER', 'Number of kill jobs. Defaults to MUTANT_JOBS or 1.')
          .ordered

        cli.send(:add_environment_options, parser_double)
      end

      it 'adds the environment section header to the parser output' do
        expect(parser.to_s).to include('Environment:')
      end

      it 'describes the zombie option in the parser output' do
        parser_help = parser.to_s

        expect(parser_help).to include('--zombie')
        expect(parser_help).to include('Run mutant zombified')
      end

      it 'describes the include option in the parser output' do
        parser_help = parser.to_s

        expect(parser_help).to include('-I')
        expect(parser_help).to include('--include DIRECTORY')
        expect(parser_help).to include('Add DIRECTORY to $LOAD_PATH')
      end

      it 'describes the require option in the parser output' do
        parser_help = parser.to_s

        expect(parser_help).to include('-r')
        expect(parser_help).to include('--require NAME')
        expect(parser_help).to include('Require file with NAME')
      end

      it 'sets zombie when the zombie option is parsed' do
        parser.parse!(%w[--zombie])

        expect(cli.config.zombie).to be(true)
      end

      it 'adds includes when the short include option is parsed' do
        parser.parse!(%w[-I lib/custom])

        expect(cli.config.includes).to include('lib/custom')
      end

      it 'adds includes when the long include option is parsed' do
        parser.parse!(%w[--include lib/alt])

        expect(cli.config.includes).to include('lib/alt')
      end

      it 'adds requires when the short require option is parsed' do
        parser.parse!(%w[-r mutant_helper])

        expect(cli.config.requires).to include('mutant_helper')
      end

      it 'adds requires when the long require option is parsed' do
        parser.parse!(%w[--require mutant/extra])

        expect(cli.config.requires).to include('mutant/extra')
      end

      it 'sets jobs when the jobs option is parsed' do
        parser.parse!(%w[--jobs 2])

        expect(cli.config.jobs).to eql(2)
      end

      it 'marks jobs as explicitly configured when the jobs option is parsed' do
        parser.parse!(%w[--jobs 2])

        expect(cli.send(:state).fetch(:jobs_explicit)).to be(true)
      end

      it 'uses the jobs flag name in parse errors' do
        expect do
          parser.parse!(%w[--jobs nope])
        end.to raise_error(Mutant::CLI::Error, '--jobs must be an integer')
      end
    end

    describe '#add_debug_options' do
      let(:parser) { instance_double(OptionParser, to_s: 'parser help') }

      before do
        allow(parser).to receive(:on)
        allow(parser).to receive(:on_tail)
        cli.send(:add_debug_options, parser)
      end

      it 'registers the fail fast option on the parser' do
        expect(parser).to have_received(:on).with('--fail-fast', 'Fail fast')
      end

      it 'registers the version option on the parser' do
        expect(parser).not_to have_received(:on).with('--version', 'Print mutants version')
      end

      it 'sets fail fast when the flag is parsed' do
        block = nil
        expect(parser).to receive(:on).with('--fail-fast', 'Fail fast') { |*_, &captured| block = captured }
        cli.send(:add_debug_options, parser)

        block.call

        expect(cli.config.fail_fast).to be(true)
      end

      it 'routes the fail fast callback through the expected token' do
        block = nil
        expect(parser).to receive(:on).with('--fail-fast', 'Fail fast') { |*_, &captured| block = captured }
        cli.send(:add_debug_options, parser)

        expect(cli).to receive(:enable_fail_fast).with(true)

        block.call
      end

    end

    describe '#enable_fail_fast' do
      it 'updates the config to enable fail fast' do
        cli.send(:enable_fail_fast, true)

        expect(cli.config.fail_fast).to be(true)
      end

      it 'rejects unexpected tokens' do
        expect do
          cli.send(:enable_fail_fast, false)
        end.to raise_error(Mutant::CLI::Error, 'Unexpected fail fast token: false')
      end
    end

    describe '#setup_integration' do
      let(:resolved_integration) { Class.new }

      it 'updates config with the resolved integration' do
        expect(Mutant::Integration).to receive(:setup)
          .with(Kernel, 'rspec')
          .and_return(resolved_integration)

        cli.send(:setup_integration, 'rspec')

        expect(cli.config.integration).to eql(resolved_integration)
      end
    end
  end

  describe '#setup' do
    subject(:setup_cli) { cli.send(:setup, arguments) }

    let(:cli)       { described_class.allocate }
    let(:arguments) { %w[foo] }
    let(:loaded_config) { Mutant::Config::DEFAULT.with(jobs: 4) }

    before do
      allow(cli).to receive(:load_config) do
        expect(cli.send(:state)).to eql(
          exit_requested: false,
          jobs_configured: false,
          jobs_explicit: false
        )
        cli.send(:state)[:jobs_configured] = true
        loaded_config
      end
      allow(cli).to receive(:process)
    end

    it 'loads config and processes the provided arguments' do
      setup_cli

      expect(cli.config).to eql(loaded_config)
      expect(cli.send(:state)).to eql(
        exit_requested: false,
        jobs_configured: true,
        jobs_explicit: false
      )
      expect(cli.send(:apply_jobs_env_defaults?)).to be(false)
      expect(cli).to have_received(:process).with(arguments)
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

      it 'preserves existing values when appending' do
        cli.send(:add, :includes, 'foo')

        expect { cli.send(:add, :includes, 'bar') }
          .to change { cli.config.includes }
          .from(%w[foo])
          .to(%w[foo bar])
      end
    end

    describe '#add_matcher' do
      let(:matcher) { instance_double(Mutant::Matcher::Config) }
      let(:updated_matcher) { instance_double(Mutant::Matcher::Config) }

      subject(:cli) do
        described_class.allocate.tap do |object|
          object.instance_variable_set(
            :@config,
            Mutant::Config::DEFAULT.with(matcher: matcher)
          )
        end
      end

      it 'updates the matcher using the provided attribute and value' do
        expect(matcher).to receive(:add).with(:match_expressions, 'expression').and_return(updated_matcher)

        cli.send(:add_matcher, :match_expressions, 'expression')

        expect(cli.config.matcher).to eql(updated_matcher)
      end

      it 'requires both the matcher attribute and value' do
        expect { cli.send(:add_matcher) }.to raise_error(ArgumentError)
      end
    end

    describe '#with' do
      subject(:cli) do
        described_class.allocate.tap do |object|
          object.instance_variable_set(:@config, Mutant::Config::DEFAULT)
        end
      end

      it 'applies the provided attributes to the current config' do
        cli.send(:with, jobs: 2)

        expect(cli.config.jobs).to eql(2)
      end

      it 'requires attributes' do
        expect { cli.send(:with) }.to raise_error(ArgumentError)
      end
    end

    describe '#parse_match_expressions' do
      let(:expression_a) { instance_double(Mutant::Expression) }
      let(:expression_b) { instance_double(Mutant::Expression) }
      let(:parser)       { instance_double(Mutant::Expression::Parser) }

      subject(:cli) do
        described_class.allocate.tap do |object|
          object.instance_variable_set(
            :@config,
            Mutant::Config::DEFAULT.with(expression_parser: parser)
          )
        end
      end

      it 'parses and adds each expression in order' do
        expect(parser).to receive(:call).with('Foo*').and_return(expression_a)
        expect(parser).to receive(:call).with('Bar*').and_return(expression_b)
        expect(cli).to receive(:add_matcher).with(:match_expressions, expression_a).ordered
        expect(cli).to receive(:add_matcher).with(:match_expressions, expression_b).ordered

        cli.send(:parse_match_expressions, %w[Foo* Bar*])
      end

      it 'requires the expressions argument' do
        expect { cli.send(:parse_match_expressions) }.to raise_error(ArgumentError)
      end
    end

    describe '#add_option_groups' do
      let(:builder) { instance_double(OptionParser) }

      it 'adds each expected option group to the builder' do
        expect(cli).to receive(:add_environment_options).with(builder).ordered
        expect(cli).to receive(:add_mutation_options).with(builder).ordered
        expect(cli).to receive(:add_filter_options).with(builder).ordered
        expect(cli).to receive(:add_debug_options).with(builder).ordered

        cli.send(:add_option_groups, builder)
      end

      it 'requires the builder argument' do
        expect { cli.send(:add_option_groups) }.to raise_error(ArgumentError)
      end
    end

    describe '#print_environment' do
      let(:matcher) { instance_double(Mutant::Matcher::Config, inspect: 'matcher-inspect') }
      let(:integration) { Class.new }
      let(:config) do
        Mutant::Config::DEFAULT.with(
          integration: integration,
          jobs:        4,
          includes:    %w[lib spec],
          requires:    %w[mutant test_app],
          fail_fast:   true,
          zombie:      true,
          matcher:     matcher
        )
      end

      subject(:cli) do
        described_class.allocate.tap do |object|
          object.instance_variable_set(:@config, config)
        end
      end

      it 'prints each resolved configuration field' do
        expect($stdout).to receive(:puts).with('Mutant environment:')
        expect($stdout).to receive(:puts).with("  Integration:     #{integration}")
        expect($stdout).to receive(:puts).with('  Jobs:            4')
        expect($stdout).to receive(:puts).with('  Includes:        ["lib", "spec"]')
        expect($stdout).to receive(:puts).with('  Requires:        ["mutant", "test_app"]')
        expect($stdout).to receive(:puts).with('  Fail fast:       true')
        expect($stdout).to receive(:puts).with('  Zombie:          true')
        expect($stdout).to receive(:puts).with('  Matcher:         matcher-inspect')

        cli.send(:print_environment)
      end
    end

    describe '#print_session_list' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:results_dir) { File.join(tmpdir, '.mutant', 'results') }

      around do |example|
        Dir.chdir(tmpdir) { example.run }
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      it 'raises on unexpected arguments' do
        expect do
          cli.send(:print_session_list, %w[extra another])
        end.to raise_error(Mutant::CLI::Error, 'session list does not accept arguments: extra another')
      end

      it 'prints a message when no session files exist' do
        expect($stdout).to receive(:puts).with('No sessions found in .mutant/results/')

        cli.send(:print_session_list, [])
      end

      it 'treats a non-directory results path as missing sessions' do
        results_dir_path = instance_double(Pathname, directory?: false)

        expect(cli).to receive(:session_results_dir).and_return(results_dir_path)
        expect(results_dir_path).not_to receive(:glob)
        expect($stdout).to receive(:puts).with('No sessions found in .mutant/results/')

        cli.send(:print_session_list, [])
      end

      it 'prints a message when the results directory contains no session files' do
        results_dir_path = instance_double(Pathname, directory?: true)

        expect(cli).to receive(:session_results_dir).and_return(results_dir_path)
        expect(results_dir_path).to receive(:glob).with('*.yml').and_return([])
        expect($stdout).to receive(:puts).with('No sessions found in .mutant/results/')

        cli.send(:print_session_list, [])
      end

      it 'sorts discovered sessions before printing fallback coverage and status' do
        FileUtils.mkdir_p(results_dir)
        first_path = Pathname(File.join(results_dir, 'zzz999.yml'))
        second_path = Pathname(File.join(results_dir, 'aaa111.yml'))
        results_dir_path = instance_double(Pathname, directory?: true)

        first_path.write(YAML.dump({ success: true, coverage: '100%' }))
        second_path.write(YAML.dump({ 'success' => false }))

        expect(cli).to receive(:session_results_dir).and_return(results_dir_path)
        expect(results_dir_path).to receive(:glob).with('*.yml').and_return([first_path, second_path])
        expect($stdout).to receive(:puts).with('Sessions (2):')
        expect($stdout).to receive(:puts).with('  aaa111  coverage: ?  status: fail').ordered
        expect($stdout).to receive(:puts).with('  zzz999  coverage: 100%  status: pass').ordered

        cli.send(:print_session_list, [])
      end

      it 'accepts hash subclasses when loading session payloads' do
        FileUtils.mkdir_p(results_dir)
        path = Pathname(File.join(results_dir, 'session.yml'))
        payload_class = Class.new(Hash)
        results_dir_path = instance_double(Pathname, directory?: true)

        path.write('ignored')

        expect(cli).to receive(:session_results_dir).and_return(results_dir_path)
        expect(results_dir_path).to receive(:glob).with('*.yml').and_return([path])
        allow(YAML).to receive(:safe_load).and_return(payload_class['success' => true, 'coverage' => '88%'])
        expect($stdout).to receive(:puts).with('Sessions (1):')
        expect($stdout).to receive(:puts).with('  session  coverage: 88%  status: pass')

        cli.send(:print_session_list, [])
      end

      it 'raises when a session payload is not a hash' do
        FileUtils.mkdir_p(results_dir)
        path = Pathname(File.join(results_dir, 'broken.yml'))
        results_dir_path = instance_double(Pathname, directory?: true)

        path.write('ignored')

        expect(cli).to receive(:session_results_dir).and_return(results_dir_path)
        expect(results_dir_path).to receive(:glob).with('*.yml').and_return([path])
        allow(YAML).to receive(:safe_load).and_return(true)

        expect do
          cli.send(:print_session_list, [])
        end.to raise_error(Mutant::CLI::Error, "Could not load session 'broken': expected a hash payload")
      end
    end

    describe '#print_session_show' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:results_dir) { File.join(tmpdir, '.mutant', 'results') }

      around do |example|
        Dir.chdir(tmpdir) { example.run }
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      it 'raises on unexpected arguments' do
        expect do
          cli.send(:print_session_show, 'abc123', %w[extra])
        end.to raise_error(Mutant::CLI::Error, 'session show does not accept arguments: extra')
      end

      it 'prints session details with fallback expression and coverage' do
        FileUtils.mkdir_p(results_dir)
        File.write(
          File.join(results_dir, 'abc123.yml'),
          YAML.dump(
            success: false,
            subject_results: [
              { expression: 'Foo#bar' },
              {}
            ]
          )
        )

        expect($stdout).to receive(:puts).with('Session: abc123')
        expect($stdout).to receive(:puts).with('  Status:   fail')
        expect($stdout).to receive(:puts).with('  Coverage: unknown')
        expect($stdout).to receive(:puts).with('  Subjects: 2')
        expect($stdout).to receive(:puts).with('    Foo#bar')
        expect($stdout).to receive(:puts).with('    <unknown>')

        cli.send(:print_session_show, 'abc123', [])
      end
    end

    describe '#session_value' do
      let(:key) { :coverage }

      it 'uses hash access instead of fetch for string keys' do
        data = instance_double('SessionData')

        expect(data).to receive(:key?).with('coverage').and_return(true)
        expect(data).to receive(:[]).with('coverage').and_return('100%')
        expect(data).not_to receive(:fetch)

        expect(cli.send(:session_value, data, key)).to eql('100%')
      end

      it 'uses hash access instead of fetch for symbol keys' do
        data = instance_double('SessionData')

        expect(data).to receive(:key?).with('coverage').and_return(false)
        expect(data).to receive(:key?).with(:coverage).and_return(true)
        expect(data).to receive(:[]).with(:coverage).and_return('75%')
        expect(data).not_to receive(:fetch)

        expect(cli.send(:session_value, data, key)).to eql('75%')
      end

      it 'returns nil when the string key is present with a nil value' do
        expect(cli.send(:session_value, { 'coverage' => nil, coverage: '75%' }, :coverage)).to be_nil
      end

      it 'returns a value stored under the string key first' do
        expect(cli.send(:session_value, { 'coverage' => '100%', coverage: '75%' }, :coverage)).to eql('100%')
      end

      it 'falls back to the symbol key when needed' do
        expect(cli.send(:session_value, { coverage: '75%' }, :coverage)).to eql('75%')
      end

      it 'returns nil without using the hash default when the key is missing' do
        data = Hash.new { |_hash, missing_key| "default-for-#{missing_key}" }

        expect(cli.send(:session_value, data, key)).to be_nil
      end

      it 'returns nil when data is nil' do
        expect(cli.send(:session_value, nil, :coverage)).to be_nil
      end

      it 'returns nil when the key is missing' do
        expect(cli.send(:session_value, {}, :coverage)).to be_nil
      end
    end

    describe '#session_subject_results' do
      it 'returns subject results when present' do
        expect(cli.send(:session_subject_results, { subject_results: %w[a b] })).to eql(%w[a b])
      end

      it 'returns an empty array when subject results are missing' do
        expect(cli.send(:session_subject_results, {})).to eql(Mutant::EMPTY_ARRAY)
      end
    end

    describe '#session_expression' do
      it 'returns the stored expression when present' do
        expect(cli.send(:session_expression, { expression: 'Foo#bar' })).to eql('Foo#bar')
      end

      it 'returns a fallback when the expression is missing' do
        expect(cli.send(:session_expression, {})).to eql('<unknown>')
      end
    end

    describe '#resolve_session_path' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:results_dir) { File.join(tmpdir, '.mutant', 'results') }

      subject(:cli) do
        described_class.allocate.tap do |object|
          object.send(:initialize, [])
        end
      end

      around do |example|
        Dir.chdir(tmpdir) { example.run }
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      it 'returns the matching yaml path for a valid session id' do
        FileUtils.mkdir_p(results_dir)
        File.write(File.join(results_dir, 'abc123.yml'), YAML.dump({ success: true }))

        expect(cli.send(:resolve_session_path, 'abc123').to_s).to eql('.mutant/results/abc123.yml')
      end
    end

    describe '#add_debug_options' do
      let(:option_parser) { OptionParser.new }

      before do
        cli.send(:add_debug_options, option_parser)
      end

      it 'registers the expected option signatures' do
        parser = instance_double(OptionParser)

        expect(parser).to receive(:on).with('--fail-fast', 'Fail fast')

        cli.send(:add_debug_options, parser)
      end

      it 'registers version and help flags on the parser output' do
        parser_help = option_parser.to_s

        expect(parser_help).not_to include('--version')
        expect(parser_help).not_to include('--help')
      end

      it 'enables fail-fast via the configured option handler' do
        expect { option_parser.parse!(%w[--fail-fast]) }
          .to change { cli.config.fail_fast }
          .from(false)
          .to(true)
      end

    end
  end

  describe '.call' do
    let(:arguments) { %w[run TestApp*] }
    let(:cli)       { described_class.allocate }
    let(:config)    { instance_double(Mutant::Config) }

    it 'requires arguments' do
      expect { described_class.call }.to raise_error(ArgumentError)
    end

    it 'processes the provided arguments on the constructed instance' do
      expect(described_class).to receive(:allocate).and_return(cli)
      expect(cli).to receive(:process).with(arguments)
      expect(cli).to receive(:config).and_return(config)

      expect(described_class.call(arguments)).to eql(config)
    end
  end

  describe '.run' do
    let(:arguments) { %w[run TestApp*] }
    let(:config)    { instance_double(Mutant::Config) }
    let(:env)       { instance_double(Mutant::Env) }
    let(:report)    { instance_double(Mutant::Result::Env, success?: true) }

    it 'requires arguments' do
      expect { described_class.run }.to raise_error(ArgumentError)
    end

    it 'passes the provided arguments through the execution pipeline' do
      expect(described_class).to receive(:call).with(arguments).and_return(config)
      expect(Mutant::Env::Bootstrap).to receive(:call).with(config).and_return(env)
      expect(Mutant::Runner).to receive(:call).with(env).and_return(report)

      expect(described_class.run(arguments)).to be(true)
    end

    it 'prints CLI errors and returns false' do
      error = described_class::Error.new('test-error')

      expect(described_class).to receive(:call).with(arguments).and_return(config)
      expect(Mutant::Env::Bootstrap).to receive(:call).with(config).and_return(env)
      expect(Mutant::Runner).to receive(:call).with(env).and_return(report)
      expect(report).to receive(:success?).and_raise(error)
      expect($stderr).to receive(:puts).with('test-error')

      expect(described_class.run(arguments)).to be(false)
    end

  end

  describe 'merged private helpers' do
    subject(:cli) do
      described_class.allocate.tap do |object|
        object.send(:initialize, [])
      end
    end

    before do
      allow(cli).to receive(:cli_exit)
    end

    describe '#add_environment_options', mutant_expression: 'Mutant::CLI#add_environment_options' do
      class OptionCollector
        attr_reader :handlers, :separators

        def initialize
          @handlers   = {}
          @separators = []
        end

        def separator(value)
          separators << value
        end

        def on(*arguments, &block)
          handlers[arguments.fetch(0)] = [arguments, block]
        end
      end

      it 'registers and applies the environment option handlers' do
        options = OptionCollector.new

        cli.__send__(:add_environment_options, options)

        expect(options.separators).to eql(['Environment:'])

        include_arguments, include_handler = options.handlers.fetch('-I')
        require_arguments, require_handler = options.handlers.fetch('-r')
        jobs_arguments, jobs_handler       = options.handlers.fetch('-j')
        zombie_arguments, zombie_handler   = options.handlers.fetch('--zombie')

        expect(include_arguments).to eql(['-I', '--include DIRECTORY', 'Add DIRECTORY to $LOAD_PATH'])
        expect(require_arguments).to eql(['-r', '--require NAME', 'Require file with NAME'])
        expect(jobs_arguments).to eql(['-j', '--jobs NUMBER', 'Number of kill jobs. Defaults to MUTANT_JOBS or 1.'])
        expect(zombie_arguments).to eql(['--zombie', 'Run mutant zombified'])

        include_handler.call('lib/foo')
        require_handler.call('foo/bar')
        jobs_handler.call('3')
        zombie_handler.call

        expect(cli.config.includes).to eql(['lib/foo'])
        expect(cli.config.requires).to eql(['foo/bar'])
        expect(cli.config.jobs).to eql(3)
        expect(cli.send(:state)).to include(jobs_explicit: true)
        expect(cli.config.zombie).to be(true)
      end

      it 'uses the --jobs source name for parse errors' do
        options = OptionCollector.new

        cli.__send__(:add_environment_options, options)

        _arguments, jobs_handler = options.handlers.fetch('-j')

        expect { jobs_handler.call('invalid') }
          .to raise_error(Mutant::CLI::Error, '--jobs must be an integer')
      end
    end

    describe '#apply_env_defaults', mutant_expression: 'Mutant::CLI#apply_env_defaults' do
      it 'sets jobs from the MUTANT_JOBS environment variable' do
        ENV.store('MUTANT_JOBS', '7')

        begin
          cli.__send__(:apply_env_defaults)

          expect(cli.config.jobs).to eql(7)
        ensure
          ENV.delete('MUTANT_JOBS')
        end
      end

      it 'does not change jobs when MUTANT_JOBS is not set' do
        ENV.delete('MUTANT_JOBS')

        cli.__send__(:apply_env_defaults)

        expect(cli.config.jobs).to eql(1)
      end

      it 'raises with MUTANT_JOBS as the source when the value is not an integer' do
        ENV.store('MUTANT_JOBS', 'nope')

        begin
          expect { cli.__send__(:apply_env_defaults) }.to raise_error(
            Mutant::CLI::Error,
            'MUTANT_JOBS must be an integer'
          )
        ensure
          ENV.delete('MUTANT_JOBS')
        end
      end

      it 'raises with MUTANT_JOBS as the source when the value is below minimum' do
        ENV.store('MUTANT_JOBS', '0')

        begin
          expect { cli.__send__(:apply_env_defaults) }.to raise_error(
            Mutant::CLI::Error,
            'MUTANT_JOBS must be >= 1'
          )
        ensure
          ENV.delete('MUTANT_JOBS')
        end
      end
    end

    describe '#enable_zombie', mutant_expression: 'Mutant::CLI#enable_zombie' do
      it 'updates the config even when invoked with an unused argument' do
        cli.__send__(:enable_zombie, :ignored)

        expect(cli.config.zombie).to be(true)
      end
    end

    describe '#apply_jobs_env_defaults?', mutant_expression: 'Mutant::CLI#apply_jobs_env_defaults?' do
      it 'returns true when no jobs source has been configured' do
        cli.instance_variable_set(:@state, exit_requested: false, jobs_configured: false, jobs_explicit: false)

        expect(cli.__send__(:apply_jobs_env_defaults?)).to be(true)
      end

      it 'returns false when jobs are configured via config file' do
        cli.instance_variable_set(:@state, exit_requested: false, jobs_configured: true, jobs_explicit: false)

        expect(cli.__send__(:apply_jobs_env_defaults?)).to be(false)
      end

      it 'returns false when jobs are explicitly set via flag' do
        cli.instance_variable_set(:@state, exit_requested: false, jobs_configured: false, jobs_explicit: true)

        expect(cli.__send__(:apply_jobs_env_defaults?)).to be(false)
      end

      it 'returns false when an exit has been requested' do
        cli.instance_variable_set(:@state, exit_requested: true, jobs_configured: false, jobs_explicit: false)

        expect(cli.__send__(:apply_jobs_env_defaults?)).to be(false)
      end
    end

    describe '#load_config', mutant_expression: 'Mutant::CLI#load_config' do
      let(:loader) { instance_double(Mutant::Config::Loader, load: loaded_config) }
      let(:loaded_config) { Mutant::Config::DEFAULT.with(jobs: 4) }

      before do
        cli.instance_variable_set(
          :@state,
          { exit_requested: false, jobs_configured: false, jobs_explicit: false }
        )
      end

      it 'returns the loaded default config and tracks configured jobs' do
        expect(Mutant::Config::Loader).to receive(:new)
          .with(Mutant::Config::DEFAULT)
          .and_return(loader)
        expect(cli).to receive(:config_file_sets_jobs?).and_return(true)

        expect(cli.__send__(:load_config)).to eql(loaded_config)
        expect(cli.send(:state)).to include(jobs_configured: true)
      end

      it 'wraps loader failures with the original message' do
        error = Class.new(Mutant::Config::Loader::Error) do
          def message = 'invalid yaml'
          def to_s = 'different to_s'
        end.new
        failing_loader = instance_double(Mutant::Config::Loader)

        expect(Mutant::Config::Loader).to receive(:new)
          .with(Mutant::Config::DEFAULT)
          .and_return(failing_loader)
        expect(failing_loader).to receive(:load).and_raise(error)

        expect { cli.__send__(:load_config) }.to raise_error(Mutant::CLI::Error, 'invalid yaml')
      end
    end

    describe '#config_file_sets_jobs?', mutant_expression: 'Mutant::CLI#config_file_sets_jobs?' do
      subject(:config_file_sets_jobs?) { cli.__send__(:config_file_sets_jobs?) }

      let(:cli) { described_class.allocate }

      around do |example|
        Dir.mktmpdir do |directory|
          Dir.chdir(directory) do
            @config_path = Pathname.new(directory).join('.mutant.yml')
            example.run
          end
        end
      end

      let(:config_path) { @config_path }

      context 'when the config file is absent' do
        it { should be(false) }
      end

      context 'when the config file is empty' do
        before do
          config_path.write('')
        end

        it { should be(false) }
      end

      context 'when the config root is not a mapping' do
        before do
          config_path.write(<<~YAML)
            - jobs
          YAML
        end

        it { should be(false) }
      end

      context 'when a sequence root could be misread as a key value pair' do
        before do
          config_path.write(<<~YAML)
            - jobs
            - 4
          YAML
        end

        it { should be(false) }
      end

      context 'when yaml parsing returns a non-document object' do
        before do
          config_path.write("jobs: 4\n")
          allow(Psych).to receive(:parse_file).with(config_path).and_return(Object.new)
        end

        it { should be(false) }
      end

      context 'when yaml parsing raises a syntax error' do
        before do
          config_path.write("jobs: [\n")
        end

        it 'propagates the parser failure' do
          expect { config_file_sets_jobs? }.to raise_error(Psych::SyntaxError)
        end
      end

      context 'when the config file contains jobs among other keys' do
        before do
          config_path.write(<<~YAML)
            fail_fast: true
            matcher:
              subjects:
                - TestApp*
            jobs: 4
          YAML
        end

        it { should be(true) }
      end

      context 'when the config file does not contain jobs' do
        before do
          config_path.write(<<~YAML)
            fail_fast: true
            requires:
              - ./config/environment
          YAML
        end

        it { should be(false) }
      end

      context 'when a non-jobs key has the string value jobs' do
        before do
          config_path.write("integration: jobs\n")
        end

        it { should be(false) }
      end
    end

    describe '#parse_match_expressions', mutant_expression: 'Mutant::CLI#parse_match_expressions' do
      before do
        cli.instance_variable_set(
          :@config,
          Mutant::Config::DEFAULT.with(
            matcher: Mutant::Matcher::Config::DEFAULT.with(
              match_expressions: [parse_expression('YAMLApp*')]
            )
          )
        )
      end

      context 'when no cli expressions are provided' do
        it 'preserves configured matcher expressions' do
          cli.__send__(:parse_match_expressions, [])

          expect(cli.config.matcher.match_expressions.map(&:syntax)).to eql(%w[YAMLApp*])
        end
      end

      context 'when cli expressions are provided' do
        it 'replaces configured matcher expressions with parsed cli expressions' do
          cli.__send__(:parse_match_expressions, %w[CLIApp* CLIApp::Thing#call])

          expect(cli.config.matcher.match_expressions.map(&:syntax)).to eql(
            ['CLIApp*', 'CLIApp::Thing#call']
          )
        end
      end
    end
  end
end
