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

      before do
        expect($stdout).to receive(:puts).with(expected_message)
        expect(Kernel).to receive(:exit)
      end

      it_should_behave_like 'a cli parser'

      let(:expected_message) do
        <<~MESSAGE
          usage: mutant run [options] MATCH_EXPRESSION ...
          Environment:
                  --zombie                     Run mutant zombified
              -I, --include DIRECTORY          Add DIRECTORY to $LOAD_PATH
              -r, --require NAME               Require file with NAME
              -j, --jobs NUMBER                Number of kill jobs. Defaults to number of processors.

          Options:
                  --use INTEGRATION            Use INTEGRATION to kill mutations
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

      let(:expected_matcher_config) do
        default_matcher_config.with(
          subject_filters: [
            Mutant::Repository::SubjectFilter.new(
              Mutant::Repository::Diff.new(
                config: Mutant::Config::DEFAULT,
                from:   'HEAD',
                to:     'master'
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
        expect(Kernel).to receive(:exit)
      end

      it 'prints main help without deprecation warning' do
        expect($stderr).not_to receive(:puts)
        subject
      end
    end

    context 'bare --version without subcommand' do
      let(:arguments) { %w[--version] }

      before do
        expect(Kernel).to receive(:exit)
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
          expect(Kernel).to receive(:exit)
        end

        it 'prints main help' do
          subject
        end
      end

      context 'with run argument' do
        let(:arguments) { %w[help run] }

        before do
          expect($stdout).to receive(:puts).with(expected_message)
          expect(Kernel).to receive(:exit)
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
                -j, --jobs NUMBER                Number of kill jobs. Defaults to number of processors.

            Options:
                    --use INTEGRATION            Use INTEGRATION to kill mutations
                    --ignore-subject EXPRESSION  Ignore subjects that match EXPRESSION as prefix
                    --since REVISION             Only select subjects touched since REVISION
                    --fail-fast                  Fail fast
                    --version                    Print mutants version
                -h, --help                       Show this message
          MESSAGE
        end
      end

      context 'with environment argument' do
        let(:arguments) { %w[help environment] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
          expect(Kernel).to receive(:exit)
        end

        it 'prints environment help' do
          subject
        end
      end

      context 'with session argument' do
        let(:arguments) { %w[help session] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect(Kernel).to receive(:exit)
        end

        it 'prints session help' do
          subject
        end
      end

      context 'with unknown subcommand' do
        let(:arguments) { %w[help unknown] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::MAIN_HELP)
          expect(Kernel).to receive(:exit)
        end

        it 'falls back to main help' do
          subject
        end
      end

      context 'with extra arguments' do
        let(:arguments) { %w[help run extra] }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            'help does not accept arguments: extra'
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
        expect(Kernel).to receive(:exit)
      end

      it 'parses config options' do
        subject
      end
    end

    context 'environment subcommand with help flag' do
      let(:arguments) { %w[environment --help] }

      before do
        expect($stdout).to receive(:puts).with(Mutant::CLI::Help::ENVIRONMENT_HELP)
        expect(Kernel).to receive(:exit)
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
          expect(Kernel).to receive(:exit)
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
          expect(Kernel).to receive(:exit)
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
          expect(Kernel).to receive(:exit)
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
        let(:arguments) { %w[session list extra] }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::CLI::Error,
            'session list does not accept arguments: extra'
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
          expect(Kernel).to receive(:exit)
        end

        it 'prints session help' do
          subject
        end
      end

      context 'with unknown sub-subcommand' do
        let(:arguments) { %w[session unknown] }

        before do
          expect($stdout).to receive(:puts).with(Mutant::CLI::Help::SESSION_HELP)
          expect(Kernel).to receive(:exit)
        end

        it 'prints session help' do
          subject
        end
      end
    end
  end

  describe 'dispatch internals' do
    let(:config) { Mutant::Config::DEFAULT }

    def build_cli
      described_class.allocate.tap do |cli|
        cli.instance_variable_set(:@config, config)
      end
    end

    describe 'subcommand dispatch from initialize' do
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

        cli.send(:initialize, %w[run])

        expect(cli.dispatched).to eql([:run, []])
      end

      it 'dispatches environment with an empty argument array' do
        cli = build_dispatch_probe.allocate

        cli.send(:initialize, %w[environment])

        expect(cli.dispatched).to eql([:environment, []])
      end

      it 'dispatches session with an empty argument array' do
        cli = build_dispatch_probe.allocate

        cli.send(:initialize, %w[session])

        expect(cli.dispatched).to eql([:session, []])
      end

      it 'dispatches help with an empty argument array' do
        cli = build_dispatch_probe.allocate

        cli.send(:initialize, %w[help])

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
    end

    describe '#handle_session' do
      subject(:handle_session) { cli.send(:handle_session, arguments) }

      let(:cli) { build_cli }

      before do
        expect(Kernel).to receive(:exit)
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
    end
  end
end
