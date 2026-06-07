# frozen_string_literal: true

RSpec.describe Mutant::CLI do
  let(:object) { described_class }

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

  describe '.new', mutant_expression: 'Mutant::CLI#parse' do
    subject { object.new(arguments) }

    let(:expected_integration)    { Mutant::Integration::Null        }
    let(:expected_reporter)       { Mutant::Config::DEFAULT.reporter }
    let(:expected_matcher_config) { default_matcher_config           }

    let(:default_matcher_config) do
      Mutant::Matcher::Config::DEFAULT
        .with(match_expressions: expressions.map(&method(:parse_expression)))
    end
    let(:help_message) do
      [
        'usage: mutant [options] MATCH_EXPRESSION ...',
        'Environment:',
        '        --zombie                     Run mutant zombified',
        '    -I, --include DIRECTORY          Add DIRECTORY to $LOAD_PATH',
        '    -r, --require NAME               Require file with NAME',
        '    -j, --jobs NUMBER                Number of kill jobs. Defaults to MUTANT_JOBS or 1.',
        '',
        'Options:',
        '        --use INTEGRATION            Use INTEGRATION to kill mutations',
        '        --include-subject EXPRESSION Add EXPRESSION to the configured subject matcher list',
        '        --ignore-subject EXPRESSION  Ignore subjects that match EXPRESSION as prefix',
        '        --since REVISION             Only select subjects touched since REVISION',
        '        --fail-fast                  Fail fast',
        '        --version                    Print mutants version',
        '    -h, --help                       Show this message'
      ].join("\n") + "\n"
    end

    let(:flags)       { []           }
    let(:expressions) { %w[TestApp*] }
    let(:arguments)   { flags + expressions }

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
        expect(help_message).not_to include('--usage')
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

      context 'when passed before another option' do
        let(:flags) { %w[--usage --help] }

        before do
          expect(help_message).not_to include('--usage')
          expect($stdout).to receive(:puts).with(help_message)
          expect(Kernel).to receive(:exit)
        end

        it_should_behave_like 'a cli parser'
      end

      context 'when passed before a match expression' do
        let(:flags) { %w[--usage] }

        it_should_behave_like 'a cli parser'
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
      allow(cli).to receive(:parse)
    end

    it 'loads config and parses the provided arguments' do
      setup_cli

      expect(cli.config).to eql(loaded_config)
      expect(cli.send(:state)).to eql(
        exit_requested: false,
        jobs_configured: true,
        jobs_explicit: false
      )
      expect(cli.send(:apply_jobs_env_defaults?)).to be(false)
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

    describe '#enable_zombie', mutant_expression: 'Mutant::CLI#enable_zombie' do
      it 'updates the config even when invoked with an unused argument' do
        cli.__send__(:enable_zombie, :ignored)

        expect(cli.config.zombie).to be(true)
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
