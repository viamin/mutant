# frozen_string_literal: true

require 'mutant/integration/rspec'

RSpec.describe Mutant::Integration::Rspec do
  let(:object) { described_class.new(Mutant::Config::DEFAULT) }

  let(:rspec_options) { Object.new }
  let(:rspec_runner)  { RSpec::Core::Runner.allocate }
  let(:example_collection) { Mutant::Integration::RspecSupport::Examples.allocate }
  let(:tests) do
    [
      Mutant::Test.new(
        id:         'rspec:0:spec/example.rb:1/spec',
        expression: parse_expression('*')
      )
    ]
  end
  let(:selected_examples)  { [double('selected example')] }
  let(:ordered_groups)     { [double('ordered example group')] }

  before do
    allow(RSpec::Core::ConfigurationOptions).to receive(:new)
      .with(%w[spec --fail-fast])
      .and_return(rspec_options)

    allow(RSpec::Core::Runner).to receive(:new)
      .with(rspec_options)
      .and_return(rspec_runner)

    allow(Mutant::Integration::RspecSupport::Examples).to receive(:build)
      .with(expression_parser: Mutant::Config::DEFAULT.expression_parser, world: RSpec.world)
      .and_return(example_collection)

    allow(Mutant::Timer).to receive_messages(now: Mutant::Timer.now)
  end

  describe '.new' do
    subject(:instance) { object }

    it 'initializes the collaborator cache' do
      instance
      expect(RSpec::Core::ConfigurationOptions).to have_received(:new).once
      expect(RSpec::Core::Runner).to have_received(:new).once
      expect(Mutant::Integration::RspecSupport::Examples).to have_received(:build).once
      state = instance.instance_variable_get(:@state)
      expect(state.fetch(:examples)).to be(example_collection)
      expect(state.fetch(:output)).to be_a(StringIO)
      expect(state.fetch(:runner)).to be(rspec_runner)
    end
  end

  describe 'fallback helpers' do
    let(:state) { object.instance_variable_get(:@state) }

    describe '#examples' do
      it 'rebuilds the collection when the cached collaborator is invalid' do
        state[:examples] = Object.new

        expect(object.send(:examples)).to be(example_collection)
        expect(Mutant::Integration::RspecSupport::Examples).to have_received(:build).twice
      end
    end

    describe '#output' do
      it 'creates a fresh StringIO when the cached output is invalid' do
        state[:output] = Object.new

        expect(object.send(:output)).to be_a(StringIO)
      end
    end

    describe '#runner' do
      it 'rebuilds the runner when the cached runner is invalid' do
        state[:runner] = Object.new

        expect(object.send(:runner)).to be(rspec_runner)
        expect(RSpec::Core::ConfigurationOptions).to have_received(:new).twice
        expect(RSpec::Core::Runner).to have_received(:new).twice
      end
    end
  end

  describe '#all_tests' do
    subject(:all_tests) { object.all_tests }

    before do
      expect(example_collection).to receive(:all_tests).and_return(tests)
    end

    it { should eql(tests) }
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
      expect(example_collection).to receive(:fetch).with(tests.fetch(0)).and_return(selected_examples.fetch(0))
      expect(example_collection).to receive(:filter).with(selected_examples)
      expect(example_collection).to receive(:ordered_groups).and_return(ordered_groups)
      expect(rspec_runner).to receive(:setup) do |_errors, output|
        output.write('the-test-output')
      end

      object.setup
    end

    before do
      expect(rspec_runner).to receive(:run_specs).with(ordered_groups).and_return(exit_status)
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

RSpec.describe Mutant::Integration::RspecSupport::Examples do
  subject(:examples) do
    described_class.build(
      expression_parser: Mutant::Config::DEFAULT.expression_parser,
      world:             world
    )
  end

  let(:source_lines) do
    [
      "RSpec.describe Example::Root do\n",
      "  it('example-a-full-description') do\n",
      "  end\n",
      "\n",
      "  it { is_expected.to cover('Example::CoveredByString') }\n",
      "  it('ignored because mutant false', mutant: false) do\n",
      "    is_expected.to cover('Example::IgnoredBecauseMutantFalse')\n",
      "  end\n",
      "  it('ignored by string annotation', mutant_expression: 'Example::ExplicitString') { }\n",
      "end\n",
      "\n",
      "RSpec.describe Example::CoveredByConstant do\n",
      "  it { is_expected.to cover(described_class) }\n",
      "  it('Example::ExplicitConstant', mutant_expression: Example::ExplicitConstant) { }\n",
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
        full_description:   'ignored by cover matcher'
      }
    )
  end

  let(:example_c) do
    double(
      'Example C',
      metadata: {
        absolute_file_path: source_path,
        line_number:        6,
        location:           "#{source_path}:6",
        full_description:   'ignored because mutant false',
        mutant:             false
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
        full_description:   'ignored by string annotation',
        mutant_expression:  'Example::ExplicitString'
      }
    )
  end

  let(:example_e) do
    double(
      'Example E',
      metadata: {
        absolute_file_path: source_path,
        line_number:        13,
        location:           "#{source_path}:13",
        full_description:   'ignored by cover matcher',
        described_class:    Example::CoveredByConstant
      }
    )
  end

  let(:example_f) do
    double(
      'Example F',
      metadata: {
        absolute_file_path: source_path,
        line_number:        14,
        location:           "#{source_path}:14",
        full_description:   'Example::ExplicitConstant',
        mutant_expression:  Example::ExplicitConstant
      }
    )
  end

  let(:root_group) do
    double(
      'root example group',
      examples:    [example_a, example_b, example_c, example_d],
      descendants: [nested_group]
    )
  end

  let(:nested_group) do
    double('nested example group', examples: [example_e, example_f])
  end

  let(:filtered_examples) do
    { double('Key') => [example_a, example_b, example_c, example_d, example_e, example_f] }
  end

  let(:world) do
    double(
      'world',
      example_groups:         [root_group],
      filtered_examples:      filtered_examples,
      ordered_example_groups: [example_a, example_b]
    )
  end

  before do
    stub_const('Example::CoveredByConstant', Class.new)
    stub_const('Example::ExplicitConstant', Class.new)
    stub_const('Example::ExplicitString', Class.new)
  end

  after do
    File.unlink(source_path) if File.exist?(source_path)
  end

  describe '#all_tests' do
    it 'derives expressions from annotations and skips mutant-disabled examples' do
      expect(examples.all_tests).to eql(
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
            id:         "rspec:2:#{source_path}:9/ignored by string annotation",
            expression: parse_expression('Example::ExplicitString')
          ),
          Mutant::Test.new(
            id:         "rspec:3:#{source_path}:13/ignored by cover matcher",
            expression: parse_expression('Example::CoveredByConstant')
          ),
          Mutant::Test.new(
            id:         "rspec:4:#{source_path}:14/Example::ExplicitConstant",
            expression: parse_expression('Example::ExplicitConstant')
          )
        ]
      )
    end
  end

  describe '#fetch' do
    it 'returns the example for a selected test' do
      expect(examples.fetch(examples.all_tests.fetch(0))).to be(example_a)
    end
  end

  describe '#filter' do
    it 'keeps only the selected examples in the filtered set' do
      examples.filter([example_b, example_e])

      expect(filtered_examples.values.flatten).to eql([example_b, example_e])
    end
  end

  describe '#ordered_groups' do
    it 'delegates to the rspec world' do
      expect(examples.ordered_groups).to eql([example_a, example_b])
    end
  end
end

RSpec.describe Mutant::Integration::RspecSupport::AnnotationParser do
  subject(:annotation_parser) { described_class.new(Mutant::Config::DEFAULT.expression_parser) }

  before do
    stub_const('Example::AnnotationTarget', Class.new)
  end

  it 'parses string annotations' do
    expect(annotation_parser.call('Example::AnnotationTarget')).to eql(
      parse_expression('Example::AnnotationTarget')
    )
  end

  it 'parses constant annotations' do
    expect(annotation_parser.call(Example::AnnotationTarget)).to eql(
      parse_expression('Example::AnnotationTarget')
    )
  end

  it 'rejects anonymous modules' do
    expect { annotation_parser.call(Class.new) }.to raise_error(
      ArgumentError,
      'Unsupported anonymous module/class mutant annotation'
    )
  end

  it 'rejects unsupported annotations' do
    expect { annotation_parser.call(:symbol) }.to raise_error(
      ArgumentError,
      'Unsupported RSpec mutant annotation: :symbol'
    )
  end
end

RSpec.describe Mutant::Integration::RspecSupport::ExpressionParser do
  subject(:expression_parser) { described_class.new(Mutant::Config::DEFAULT.expression_parser) }

  before do
    stub_const('Example::DescribedClass', Class.new)
  end

  let(:parser) { ::Parser::CurrentRuby }

  it 'parses described_class cover annotations' do
    node = parser.parse('cover(described_class)').children.fetch(2)

    expect(expression_parser.call(node, Example::DescribedClass)).to eql(
      parse_expression('Example::DescribedClass')
    )
  end

  it 'rejects missing described_class names' do
    node = parser.parse('cover(described_class)').children.fetch(2)

    expect { expression_parser.call(node, Class.new) }.to raise_error(
      ArgumentError,
      'Cannot derive mutant expression from anonymous or missing described_class'
    )
  end
end

RSpec.describe Mutant::Integration::RspecSupport::ExpressionResolver do
  subject(:expression_resolver) { described_class.build(Mutant::Config::DEFAULT.expression_parser) }

  let(:source_file) do
    file = Tempfile.new(['mutant-rspec-multi-cover', '.rb'])
    file.write(
      <<~RUBY
        RSpec.describe Example::Root do
          it do
            is_expected.to cover('Example::One')
            is_expected.to cover('Example::Two')
          end
        end
      RUBY
    )
    file.close
    file.path
  end

  after do
    File.unlink(source_file) if File.exist?(source_file)
  end

  it 'rejects multiple cover annotations on one example' do
    metadata = {
      absolute_file_path: source_file,
      line_number:        2,
      location:           "#{source_file}:2",
      full_description:   'ignored by cover matcher'
    }

    expect { expression_resolver.call(metadata) }.to raise_error(
      ArgumentError,
      "Multiple cover annotations found for RSpec example at #{source_file}:2"
    )
  end
end

RSpec.describe Mutant::Integration::RspecSupport::SourceIndex do
  subject(:source_index) do
    described_class.new(
      Mutant::Integration::RspecSupport::ExpressionParser.new(Mutant::Config::DEFAULT.expression_parser)
    )
  end

  let(:source_file) do
    file = Tempfile.new(['mutant-rspec-invalid', '.rb'])
    file.write("it { is_expected.to cover('unterminated)\n")
    file.close
    file.path
  end

  after do
    File.unlink(source_file) if File.exist?(source_file)
  end

  it 'returns no expressions for invalid ruby source' do
    expect(source_index.expressions(absolute_file_path: source_file, line_number: 1)).to eql([])
  end
end
