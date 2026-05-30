# frozen_string_literal: true

require 'mutant/integration/rspec'

RSpec.describe Mutant::Integration::Rspec do
  let(:object) { described_class.new(Mutant::Config::DEFAULT) }

  let(:rspec_options) { instance_double(RSpec::Core::ConfigurationOptions) }
  let(:rspec_runner)  { instance_double(RSpec::Core::Runner) }

  let(:source_lines) do
    [
      "RSpec.describe Example::Root do\n",
      "  it('example-a-full-description') do\n",
      "  end\n",
      "\n",
      "  it { is_expected.to cover('Example::CoveredByString') }\n",
      "end\n",
      "\n",
      "RSpec.describe Example::CoveredByConstant do\n",
      "  it { is_expected.to cover(described_class) }\n",
      "end\n"
    ]
  end

  let(:source_path) do
    file = Tempfile.new(['mutant-rspec', '.rb'])
    file.write(source_lines.join)
    file.close
    file.path
  end

  let(:example_a) do
    double(
      'Example A',
      metadata: {
        absolute_file_path: source_path,
        line_number:        2,
        location:           "#{source_path}:2",
        full_description:   'example-a-full-description'
      }
    )
  end

  let(:example_b) do
    double(
      'Example B',
      metadata: {
        absolute_file_path: source_path,
        line_number:        5,
        location:           "#{source_path}:5",
        full_description:   'ignored by cover matcher',
        mutant:             false
      }
    )
  end

  let(:example_c) do
    double(
      'Example C',
      metadata: {
        absolute_file_path: source_path,
        line_number:        5,
        location:           "#{source_path}:5",
        full_description:   'ignored by cover matcher'
      }
    )
  end

  let(:example_d) do
    double(
      'Example D',
      metadata: {
        absolute_file_path: source_path,
        line_number:        9,
        location:           "#{source_path}:9",
        full_description:   'ignored by cover matcher',
        described_class:    Example::CoveredByConstant
      }
    )
  end

  let(:example_e) do
    double(
      'Example E',
      metadata: {
        absolute_file_path: source_path,
        line_number:        9,
        location:           "#{source_path}:9",
        full_description:   'Example::ExplicitConstant',
        mutant_expression:  Example::ExplicitConstant
      }
    )
  end

  let(:root_group) do
    double(
      'root example group',
      examples:     [example_a, example_b, example_c],
      descendants:  [nested_group]
    )
  end

  let(:nested_group) do
    double(
      'nested example group',
      examples: [example_d, example_e]
    )
  end

  let(:filtered_examples) do
    {
      double('Key') => [example_a, example_b, example_c, example_d, example_e]
    }
  end

  let(:world) do
    double(
      'world',
      example_groups:    [root_group],
      filtered_examples: filtered_examples
    )
  end

  let(:all_tests) do
    [
      Mutant::Test.new(
        id:         "rspec:0:#{source_path}:2/example-a-full-description",
        expression: parse_expression('*')
      ),
      Mutant::Test.new(
        id:         "rspec:1:#{source_path}:5/ignored by cover matcher",
        expression: parse_expression('Example::CoveredByString')
      ),
      Mutant::Test.new(
        id:         "rspec:2:#{source_path}:9/ignored by cover matcher",
        expression: parse_expression('Example::CoveredByConstant')
      ),
      Mutant::Test.new(
        id:         "rspec:3:#{source_path}:9/Example::ExplicitConstant",
        expression: parse_expression('Example::ExplicitConstant')
      )
    ]
  end

  before do
    stub_const('Example::CoveredByConstant', Class.new)
    stub_const('Example::ExplicitConstant', Class.new)

    expect(RSpec::Core::ConfigurationOptions).to receive(:new)
      .with(%w[spec --fail-fast])
      .and_return(rspec_options)

    expect(RSpec::Core::Runner).to receive(:new)
      .with(rspec_options)
      .and_return(rspec_runner)

    expect(RSpec).to receive_messages(world: world)
    allow(Mutant::Timer).to receive_messages(now: Mutant::Timer.now)
  end

  after do
    File.unlink(source_path) if File.exist?(source_path)
  end

  describe '#all_tests' do
    subject { object.all_tests }

    it { should eql(all_tests) }
  end

  describe '#setup' do
    subject { object.setup }

    before do
      expect(rspec_runner).to receive(:setup) do |error, output|
        expect(error).to be($stderr)
        output.write('foo')
      end
    end

    it { should be(object) }
  end

  describe '#call' do
    subject { object.call(tests) }

    before do
      expect(rspec_runner).to receive(:setup) do |_errors, output|
        output.write('the-test-output')
      end

      object.setup
    end

    let(:tests) { [all_tests.fetch(0)] }

    before do
      expect(world).to receive(:ordered_example_groups) do
        filtered_examples.values.flatten
      end
      expect(rspec_runner).to receive(:run_specs).with([example_a]).and_return(exit_status)
    end

    context 'on unsuccessful exit' do
      let(:exit_status) { 1 }

      it 'should return failed result' do
        expect(subject).to eql(
          Mutant::Result::Test.new(
            output:  'the-test-output',
            passed:  false,
            runtime: 0.0,
            tests:   tests
          )
        )
      end
    end

    context 'on successful exit' do
      let(:exit_status) { 0 }

      it 'should return passed result' do
        expect(subject).to eql(
          Mutant::Result::Test.new(
            output:  'the-test-output',
            passed:  true,
            runtime: 0.0,
            tests:   tests
          )
        )
      end
    end
  end
end
