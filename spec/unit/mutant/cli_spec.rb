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
              -j, --jobs NUMBER                Number of kill jobs. Defaults to 1.

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
          let(:flags) { %w[--jobs 0] }

          it_should_behave_like 'a cli parser'

          it 'prefers cli flags over config file values' do
            expect(subject.config.jobs).to eql(0)
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

      before do
        expect(Mutant::Config::Loader).to receive(:call)
          .with(Mutant::Config::DEFAULT)
          .and_raise(error)
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
  end

  describe '#add_environment_options' do
    subject { cli.__send__(:add_environment_options, options) }

    let(:cli) do
      object.allocate.tap do |instance|
        instance.instance_variable_set(:@config, Mutant::Config::DEFAULT)
      end
    end
    let(:options)   { instance_double(OptionParser) }
    let(:handlers)  { {} }

    before do
      allow(options).to receive(:separator)
      allow(options).to receive(:on) do |*arguments, &block|
        handlers[arguments.fetch(0)] = [arguments, block]
      end
    end

    it 'adds the environment section header' do
      expect(options).to receive(:separator).with('Environment:')

      subject
    end

    it 'registers a zombie handler that updates config' do
      subject

      arguments, handler = handlers.fetch('--zombie')

      expect(arguments).to eql(['--zombie', 'Run mutant zombified'])

      handler.call

      expect(cli.config.zombie).to be(true)
    end

    it 'registers the remaining environment options with exact help text' do
      subject

      include_arguments, = handlers.fetch('-I')
      require_arguments, = handlers.fetch('-r')
      jobs_arguments,    = handlers.fetch('-j')

      expect(include_arguments).to eql(['-I', '--include DIRECTORY', 'Add DIRECTORY to $LOAD_PATH'])
      expect(require_arguments).to eql(['-r', '--require NAME', 'Require file with NAME'])
      expect(jobs_arguments).to eql(['-j', '--jobs NUMBER', 'Number of kill jobs. Defaults to 1.'])
    end
  end

  describe '#enable_zombie' do
    subject { cli.__send__(:enable_zombie) }

    let(:cli) do
      object.allocate.tap do |instance|
        instance.instance_variable_set(:@config, Mutant::Config::DEFAULT)
      end
    end

    it 'updates config through with' do
      expect(cli).to receive(:with).with(zombie: true)

      subject
    end
  end
end
