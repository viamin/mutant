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
          results_dir: ".mutant/results"
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
        expect(subject.results_dir).to eql('.mutant/results')
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

    context 'when config contains an invalid value type' do
      before do
        config_path.write("jobs: nope\n")
      end

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          %r{\AInvalid value for jobs at .*/\.mutant\.yml:1: expected Integer\z}
        )
      end
    end
  end
end
