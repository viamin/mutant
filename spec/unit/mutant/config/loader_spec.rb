# frozen_string_literal: true

RSpec.describe Mutant::Config::Loader do
  let(:object) { described_class }
  let(:pwd)    { Pathname.new(directory) }

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      Dir.chdir(directory) { example.run }
    end
  end

  let(:directory) { @directory }

  let(:base_config) do
    Mutant::Config::DEFAULT.with(
      reporter: Mutant::Reporter::Null.new
    )
  end

  let(:config_path) do
    Pathname.new(directory).join('.mutant.yml')
  end

  describe '.call' do
    subject { object.call(base_config) }

    context 'when config file is absent' do
      it { should eql(base_config) }
    end

    context 'when config file is empty' do
      before do
        config_path.write('')
      end

      it { should eql(base_config) }
    end

    context 'when yaml parsing returns a non-document node' do
      before do
        config_path.write("integration: rspec\n")
        allow(Psych).to receive(:parse_file).with(config_path).and_return(Psych::Nodes::Scalar.new('value'))
      end

      it 'ignores the config file contents' do
        expect(subject).to eql(base_config)
      end
    end

    context 'when config file has invalid yaml syntax' do
      before do
        config_path.write("integration: [\n")
      end

      it 'raises a syntax error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          /did not find expected node content/
        )
      end
    end

    context 'when yaml parsing raises a syntax error with a custom to_s' do
      before do
        config_path.write("integration: rspec\n")

        syntax_error_class = Class.new(Psych::SyntaxError) do
          def message = 'syntax-message'
          def to_s = 'other-string'
        end

        allow(Psych).to receive(:parse_file).with(config_path).and_raise(
          syntax_error_class.new(config_path.to_s, 1, 1, 0, 'problem', nil)
        )
      end

      it 'raises the syntax error message' do
        expect { subject }.to raise_error(Mutant::Config::Loader::Error, 'syntax-message')
      end
    end

    context 'when config file is present' do
      before do
        expect(Kernel).to receive(:require)
          .with('mutant/integration/rspec')
          .and_call_original

        config_path.write(<<~YAML)
          integration: rspec
          requires:
            - ./config/environment
          environment_variables:
            RAILS_ENV: test
            COVERAGE: "false"
          jobs: 4
          fail_fast: true
          coverage_criteria:
            timeout: false
            process_abort: true
            test_result: false
          matcher:
            subjects:
              - "MyApp::Critical*"
              - "MyApp::Secrets#fetch"
            ignore:
              - "app/admin/**/*.rb"
          results_dir: tmp/mutant
        YAML
      end

      it 'loads supported keys' do
        expect(subject.integration).to eql(Mutant::Integration::Rspec)
        expect(subject.requires).to eql(['./config/environment'])
        expect(subject.environment_variables).to eql(
          'RAILS_ENV' => 'test',
          'COVERAGE'  => 'false'
        )
        expect(subject.jobs).to eql(4)
        expect(subject.fail_fast).to be(true)
        expect(subject.coverage_criteria).to eql(
          Mutant::Config::CoverageCriteria.new(
            process_abort: true,
            test_result:   false,
            timeout:       false
          )
        )
        expect(subject.matcher.match_expressions.map(&:syntax)).to eql(
          ['MyApp::Critical*', 'MyApp::Secrets#fetch']
        )
        expect(subject.matcher.subject_filters).to eql(
          [
            Mutant::Matcher::SourcePathFilter.new(
              pathname: Pathname,
              pattern:  'app/admin/**/*.rb',
              root:     pwd
            )
          ]
        )
        expect(subject.results_dir).to eql('tmp/mutant')
      end
    end

    context 'when config contains an unknown nested key' do
      before do
        config_path.write(<<~YAML)
          matcher:
            subjects:
              - "MyApp::Critical*"
            unknown: true
        YAML
      end

      it 'raises a line-aware error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AUnknown config key "matcher\.unknown" at .*/\.mutant\.yml:4\z}
        )
      end
    end

    context 'when config contains an unknown top-level key' do
      before do
        config_path.write("unknown: true\n")
      end

      it 'raises a line-aware error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AUnknown config key "unknown" at .*/\.mutant\.yml:1\z}
        )
      end
    end

    context 'when config contains an invalid value type' do
      before do
        config_path.write("jobs: nope\n")
      end

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for jobs at .*/\.mutant\.yml:1: expected "Integer"\z}
        )
      end
    end

    context 'when fail_fast has an invalid value type' do
      before do
        config_path.write("fail_fast: nope\n")
      end

      it 'raises a validation error for fail_fast' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for fail_fast at .*/\.mutant\.yml:1: expected "Boolean"\z}
        )
      end
    end

    context 'when integration has an invalid value type' do
      before do
        config_path.write("integration: true\n")
      end

      it 'raises a validation error for integration' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for integration at .*/\.mutant\.yml:1: expected "String"\z}
        )
      end
    end

    context 'when requires has an invalid value type' do
      before do
        config_path.write("requires: true\n")
      end

      it 'raises a validation error for requires' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for requires at .*/\.mutant\.yml:1: expected sequence\z}
        )
      end
    end

    context 'when a requires entry has an invalid value type' do
      before do
        config_path.write(<<~YAML)
          requires:
            - 1
        YAML
      end

      it 'raises a validation error for the requires entry' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for requires at .*/\.mutant\.yml:2: expected "String"\z}
        )
      end
    end

    context 'when environment_variables has an invalid value type' do
      before do
        config_path.write("environment_variables: true\n")
      end

      it 'raises a validation error for the environment_variables mapping' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for environment_variables at .*/\.mutant\.yml:1: expected mapping\z}
        )
      end
    end

    context 'when an environment_variables entry has an invalid value type' do
      before do
        config_path.write(<<~YAML)
          environment_variables:
            RAILS_ENV: 1
        YAML
      end

      it 'raises a validation error for the nested environment_variables key' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for environment_variables\.RAILS_ENV at .*/\.mutant\.yml:2: expected "String"\z}
        )
      end
    end

    context 'when results_dir has an invalid value type' do
      before do
        config_path.write("results_dir: 1\n")
      end

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for results_dir at .*/\.mutant\.yml:1: expected "String"\z}
        )
      end
    end

    context 'when matcher has an invalid value type' do
      before do
        config_path.write("matcher: true\n")
      end

      it 'raises a validation error for matcher' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for matcher at .*/\.mutant\.yml:1: expected mapping\z}
        )
      end
    end

    context 'when matcher subjects has an invalid value type' do
      before do
        config_path.write(<<~YAML)
          matcher:
            subjects: true
        YAML
      end

      it 'raises a validation error for matcher.subjects' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for matcher\.subjects at .*/\.mutant\.yml:2: expected sequence\z}
        )
      end
    end

    context 'when matcher ignore has an invalid value type' do
      before do
        config_path.write(<<~YAML)
          matcher:
            ignore: true
        YAML
      end

      it 'raises a validation error for matcher.ignore' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for matcher\.ignore at .*/\.mutant\.yml:2: expected sequence\z}
        )
      end
    end

    context 'when config only overrides part of coverage criteria' do
      before do
        config_path.write(<<~YAML)
          coverage_criteria:
            process_abort: true
        YAML
      end

      it 'merges with defaults' do
        expect(subject.coverage_criteria).to eql(
          Mutant::Config::CoverageCriteria.new(
            process_abort: true,
            test_result:   true,
            timeout:       false
          )
        )
      end
    end

    context 'when config only overrides timeout criteria' do
      before do
        config_path.write(<<~YAML)
          coverage_criteria:
            timeout: true
        YAML
      end

      it 'merges with defaults' do
        expect(subject.coverage_criteria).to eql(
          Mutant::Config::CoverageCriteria.new(
            process_abort: false,
            test_result:   true,
            timeout:       true
          )
        )
      end
    end

    context 'when config only overrides test_result criteria' do
      before do
        config_path.write(<<~YAML)
          coverage_criteria:
            test_result: false
        YAML
      end

      it 'merges with defaults' do
        expect(subject.coverage_criteria).to eql(
          Mutant::Config::CoverageCriteria.new(
            process_abort: false,
            test_result:   false,
            timeout:       false
          )
        )
      end
    end

    context 'when coverage criteria contains an unknown nested key' do
      before do
        config_path.write(<<~YAML)
          coverage_criteria:
            invalid: true
        YAML
      end

      it 'raises a line-aware error for the nested coverage key' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AUnknown config key "coverage_criteria\.invalid" at .*/\.mutant\.yml:2\z}
        )
      end
    end

    context 'when coverage criteria has an invalid value type' do
      before do
        config_path.write("coverage_criteria: true\n")
      end

      it 'raises a validation error for the coverage_criteria mapping' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for coverage_criteria at .*/\.mutant\.yml:1: expected mapping\z}
        )
      end
    end

    context 'when a coverage criteria entry has an invalid value type' do
      before do
        config_path.write(<<~YAML)
          coverage_criteria:
            timeout: 1
        YAML
      end

      it 'raises a validation error for the nested coverage_criteria key' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for coverage_criteria\.timeout at .*/\.mutant\.yml:2: expected "Boolean"\z}
        )
      end
    end

    context 'when integration from config cannot be loaded' do
      before do
        config_path.write("integration: missing\n")
      end

      it 'raises a helpful error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Could not load integration "missing" (you may want to try installing the gem mutant-missing)'
        )
      end
    end
  end
end
