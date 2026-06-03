# frozen_string_literal: true

require 'mutant/integration/rspec'

RSpec.describe Mutant::Integration::Rspec do
  let(:object) { described_class.new(Mutant::Config::DEFAULT) }
  let(:example_collection_class) { Mutant::Integration::RspecSupport::Examples }
  let(:runner_class)             { RSpec::Core::Runner }
  let(:output_class)             { StringIO }

  let(:rspec_options) { Object.new }
  let(:rspec_runner)  { RSpec::Core::Runner.allocate }
  let(:example_collection) { Mutant::Integration::RspecSupport::Examples.allocate }
  let(:expression_resolver) { instance_double(Mutant::Integration::RspecSupport::ExpressionResolver) }
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

    allow(Mutant::Integration::RspecSupport::ExpressionResolver).to receive(:build)
      .with(Mutant::Config::DEFAULT.expression_parser)
      .and_return(expression_resolver)

    allow(Mutant::Integration::RspecSupport::Examples).to receive(:build)
      .with(expression_parser: Mutant::Config::DEFAULT.expression_parser, world: RSpec.world)
      .and_return(example_collection)

    allow(Mutant::Timer).to receive_messages(now: Mutant::Timer.now)
  end

  describe '.new', mutant_expression: 'Mutant::Integration::Rspec#initialize' do
    subject(:instance) { object }

    it 'eagerly initializes collaborator state' do
      instance

      expect(RSpec::Core::ConfigurationOptions).to have_received(:new).once
      expect(RSpec::Core::Runner).to have_received(:new).once
      expect(Mutant::Integration::RspecSupport::Examples).to have_received(:build).once
    end
  end

  describe '#examples', mutant_expression: 'Mutant::Integration::Rspec#examples' do
    it 'memoizes the example collection' do
      expect(object.send(:examples)).to be(example_collection)
      expect(object.send(:examples)).to be(example_collection)
      expect(Mutant::Integration::RspecSupport::Examples).to have_received(:build).once
    end
  end

  describe '#output', mutant_expression: 'Mutant::Integration::Rspec#output' do
    it 'memoizes a StringIO output stream' do
      expect(object.send(:output)).to be_a(StringIO)
      expect(object.send(:output)).to be(object.send(:output))
    end
  end

  describe '#runner', mutant_expression: 'Mutant::Integration::Rspec#runner' do
    it 'memoizes the rspec runner' do
      expect(object.send(:runner)).to be(rspec_runner)
      expect(object.send(:runner)).to be(rspec_runner)
      expect(RSpec::Core::ConfigurationOptions).to have_received(:new).once
      expect(RSpec::Core::Runner).to have_received(:new).once
    end
  end

  describe '#run_specs', mutant_expression: 'Mutant::Integration::Rspec#run_specs' do
    before do
      expect(example_collection).to receive(:ordered_groups).and_return(ordered_groups)
    end

    context 'when the runner returns normally' do
      it 'returns the runner exit status' do
        expect(rspec_runner).to receive(:run_specs).with(ordered_groups).and_return(0)

        expect(object.send(:run_specs)).to eql(0)
      end
    end

    context 'when the runner exits via SystemExit' do
      it 'returns the exit status integer' do
        expect(rspec_runner).to receive(:run_specs).with(ordered_groups).and_raise(SystemExit.new(1))

        result = object.send(:run_specs)

        expect(result).to eql(1)
        expect(result).to be_instance_of(Integer)
      end
    end
  end

  describe '#all_tests', mutant_expression: 'Mutant::Integration::Rspec#all_tests' do
    subject(:all_tests) { object.all_tests }

    before do
      expect(example_collection).to receive(:all_tests).and_return(tests)
    end

    it { should eql(tests) }
  end

  describe '#setup', mutant_expression: 'Mutant::Integration::Rspec#setup' do
    subject { object.setup }

    before do
      expect(rspec_runner).to receive(:setup) do |error, output|
        expect(error).to be($stderr)
        output.write('foo')
      end
    end

    it { should be(object) }
  end

  describe '#call', mutant_expression: 'Mutant::Integration::Rspec#call' do
    subject { object.call(tests) }

    let(:run_specs_reaction) do
      {
        return: exit_status
      }
    end

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
      expectation = expect(rspec_runner).to receive(:run_specs).with(ordered_groups)

      if run_specs_reaction.key?(:exception)
        expectation.and_raise(run_specs_reaction.fetch(:exception))
      else
        expectation.and_return(run_specs_reaction.fetch(:return))
      end
    end

    context 'on unsuccessful exit' do
      let(:exit_status) { 1 }

      it 'should return failed result' do
        result = subject

        expect(result).to eql(
          Mutant::Result::Test.new(
            output:  'the-test-output',
            passed:  false,
            runtime: 0.0,
            tests:   tests
          )
        )
        expect(result).to be_instance_of(Mutant::Result::Test)
        expect(result).to be_frozen
        expect(result.output).to eql('the-test-output')
        expect(result.passed).to be(false)
        expect(result.runtime).to eql(0.0)
        expect(result.tests).to be(tests)
      end
    end

    context 'on successful exit' do
      let(:exit_status) { 0 }

      it 'should return passed result' do
        result = subject

        expect(result).to eql(
          Mutant::Result::Test.new(
            output:  'the-test-output',
            passed:  true,
            runtime: 0.0,
            tests:   tests
          )
        )
        expect(result).to be_instance_of(Mutant::Result::Test)
        expect(result).to be_frozen
        expect(result.output).to eql('the-test-output')
        expect(result.passed).to be(true)
        expect(result.runtime).to eql(0.0)
        expect(result.tests).to be(tests)
        expect(object.send(:output).pos).to eql('the-test-output'.length)
      end
    end

    context 'when rspec exits via SystemExit' do
      let(:exit_status) { nil }
      let(:run_specs_reaction) { { exception: SystemExit.new(1) } }

      it 'treats the suite as failed and returns a test result' do
        result = subject

        expect(result).to be_instance_of(Mutant::Result::Test)
        expect(result.passed).to be(false)
        expect(result.output).to eql('the-test-output')
        expect(result.tests).to be(tests)
      end
    end
  end
end

RSpec.describe Mutant::Integration::RspecSupport do
  describe '.cover_annotation?' do
  before do
    stub_const('Example::NamedTarget', Class.new)
  end

  it 'accepts named modules' do
    expect(described_class.cover_annotation?(Example::NamedTarget)).to be(true)
  end

  it 'accepts parsable string expressions' do
    expect(described_class.cover_annotation?('Example::NamedTarget')).to eql(
      parse_expression('Example::NamedTarget')
    )
  end

  it 'rejects anonymous modules' do
    expect(described_class.cover_annotation?(Class.new)).to be(false)
  end

  it 'rejects unsupported annotations' do
    expect(described_class.cover_annotation?(:symbol)).to be(false)
  end
  end
end

RSpec.describe Mutant::Integration::RspecSupport::Matchers do
  subject(:matcher_host) do
    Class.new do
      prepend Mutant::Integration::RspecSupport::Matchers

      def cover(expected)
        [:super, expected]
      end
    end.new
  end

  before do
    stub_const('Example::MatcherTarget', Class.new)
  end

  it 'returns a mutant cover matcher for supported annotations' do
    matcher = matcher_host.send(:cover, Example::MatcherTarget)

    expect(matcher).to be_a(Mutant::Integration::RspecSupport::CoverMatcher)
    expect(matcher.description).to eql("cover #{Example::MatcherTarget.inspect}")
  end

  it 'delegates unsupported annotations to the original matcher' do
    expect(matcher_host.send(:cover, :symbol)).to eql([:super, :symbol])
  end
end

RSpec.describe Mutant::Integration::RspecSupport::CoverMatcher do
  subject(:matcher) { described_class.new('Example::MatcherTarget') }

  it 'always matches' do
    expect(matcher.matches?(:anything)).to be(true)
  end

  it 'describes the expected cover annotation' do
    expect(matcher.description).to eql('cover "Example::MatcherTarget"')
    expect(matcher.failure_message).to eql('cover "Example::MatcherTarget"')
    expect(matcher.failure_message_when_negated).to eql('cover "Example::MatcherTarget"')
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

  describe '#parse_test' do
    it 'builds a mutant test with the resolved expression and formatted id' do
      example = double(
        'Example',
        metadata: {
          location:         'spec/example_spec.rb:12',
          full_description: 'Example description'
        }
      )

      expect(examples.send(:parse_test, example, 3)).to eql(
        Mutant::Test.new(
          expression: parse_expression('Example'),
          id:         'rspec:3:spec/example_spec.rb:12/Example description'
        )
      )
    end

    it 'returns a Mutant::Test instance' do
      example = double(
        'Example',
        metadata: {
          location:         'spec/example_spec.rb:12',
          full_description: 'Example description'
        }
      )

      expect(examples.send(:parse_test, example, 3)).to be_instance_of(Mutant::Test)
    end
  end
end

RSpec.describe Mutant::Integration::RspecSupport::Node do
  let(:parser) { ::Parser::CurrentRuby }

  describe '.cover_argument' do
    it 'extracts the cover matcher argument from expectation nodes' do
      node = parser.parse("is_expected.to cover('Example::Target')")

      expect(described_class.cover_argument(node)).to eql(
        parser.parse("'Example::Target'")
      )
    end

    it 'returns nil for non-cover matcher expectations' do
      node = parser.parse('is_expected.to eq(1)')

      expect(described_class.cover_argument(node)).to be(nil)
    end

    it 'returns nil for non-send nodes' do
      node = Class.new do
        def type
          :str
        end

        def to_a
          fail 'cover_argument should return before deconstructing non-send nodes'
        end
      end.new

      expect(described_class.cover_argument(node)).to be(nil)
    end

    it 'returns nil for non-expectation sends' do
      node = Parser::AST::Node.new(
        :send,
        [
          nil,
          :eq,
          parser.parse("cover('Example::Target')")
        ]
      )

      expect(described_class.cover_argument(node)).to be(nil)
    end
  end

  describe '.cover_arguments' do
    it 'returns an empty array for non-nodes' do
      expect(described_class).not_to receive(:each)

      expect(described_class.cover_arguments(Object.new)).to eql([])
    end

    it 'collects cover matcher arguments from descendant nodes' do
      node = parser.parse(
        <<~RUBY
          begin
            is_expected.to cover('Example::One')
            is_expected.to eq(1)
            expect(subject).to cover('Example::Two')
          end
        RUBY
      )

      expect(described_class.cover_arguments(node)).to eql(
        [
          parser.parse("'Example::One'"),
          parser.parse("'Example::Two'")
        ]
      )
    end

    it 'accepts parser ast node subclasses' do
      node_class = Class.new(Parser::AST::Node)
      node = node_class.new(:begin, [parser.parse("is_expected.to cover('Example::Target')")])

      expect(described_class.cover_arguments(node)).to eql([parser.parse("'Example::Target'")])
    end
  end

  describe '.each' do
    it 'returns an enumerator when no block is given' do
      node = parser.parse("cover('Example::Target')")

      expect(described_class.each(node).to_a).to include(node)
    end

    it 'visits descendant nodes in depth-first order' do
      node = parser.parse("expect(subject).to cover('Example::Target')")

      expect(described_class.each(node).map(&:type)).to eql(%i[send send send send str])
    end
  end

  describe '.example_block?' do
    it 'returns true for rspec example blocks' do
      node = parser.parse("it('works') { expect(true).to eql(true) }")

      expect(described_class.example_block?(node)).to be(true)
    end

    it 'returns false for non-example blocks' do
      node = parser.parse('foo { bar }')

      expect(described_class.example_block?(node)).to be(false)
    end

    it 'returns false for non-block nodes' do
      expect(described_class.example_block?(parser.parse("it('works')"))).to be(false)
    end

    it 'returns false when the block receiver is not a send node' do
      block_node = Parser::AST::Node.new(
        :block,
        [
          Parser::AST::Node.new(:lvar, [:it]),
          Parser::AST::Node.new(:args, []),
          nil
        ]
      )

      expect(described_class.example_block?(block_node)).to be(false)
    end
  end

  describe '.cover_matcher?' do
    it 'returns true for bare cover matcher sends' do
      matcher = parser.parse("cover('Example::Target')")

      expect(described_class.cover_matcher?(matcher)).to be(true)
    end

    it 'returns false for other sends' do
      matcher = parser.parse("other('Example::Target')")

      expect(described_class.cover_matcher?(matcher)).to be(false)
    end

    it 'returns false when the matcher has a receiver' do
      matcher = parser.parse("self.cover('Example::Target')")

      expect(described_class.cover_matcher?(matcher)).to be(false)
    end

    it 'returns false for non-send nodes' do
      expect(described_class.cover_matcher?(parser.parse("'Example::Target'"))).to be(false)
    end

    it 'returns false for non-ast objects that look send-like' do
      send_like_matcher = Struct.new(:type, :children).new(:send, [nil, :cover])

      expect(described_class.cover_matcher?(send_like_matcher)).to be(false)
    end

    it 'accepts parser ast node subclasses' do
      matcher_class = Class.new(Parser::AST::Node)
      matcher = matcher_class.new(:send, [nil, :cover, parser.parse("'Example::Target'")])

      expect(described_class.cover_matcher?(matcher)).to be(true)
    end

    it 'rejects send-like parser nodes with the wrong type' do
      matcher = Parser::AST::Node.new(:lvar, [nil, :cover, parser.parse("'Example::Target'")])

      expect(described_class.cover_matcher?(matcher)).to be(false)
    end
  end
end

RSpec.describe Mutant::Integration::RspecSupport::Source do
  it 'prefers the absolute file path' do
    expect(
      described_class.path(absolute_file_path: '/tmp/absolute.rb', file_path: 'relative.rb')
    ).to eql('/tmp/absolute.rb')
  end

  it 'falls back to the relative file path' do
    expect(described_class.path(file_path: 'relative.rb')).to eql('relative.rb')
  end

  it 'returns nil when no path metadata is present' do
    expect(described_class.path({})).to be(nil)
  end
end

RSpec.describe Mutant::Integration::RspecSupport::AnnotationParser do
  subject(:annotation_parser) { described_class.new(expression_parser) }

  let(:expression_parser) { instance_double(Mutant::Expression::Parser) }

  before do
    stub_const('Example::AnnotationTarget', Class.new)
    allow(expression_parser).to receive(:call) do |input|
      parse_expression(input)
    end
  end

  it 'parses string annotations' do
    expect(annotation_parser.call('Example::AnnotationTarget')).to eql(
      parse_expression('Example::AnnotationTarget')
    )
    expect(expression_parser).to have_received(:call).with('Example::AnnotationTarget').once
  end

  it 'parses constant annotations' do
    expect(annotation_parser.call(Example::AnnotationTarget)).to eql(
      parse_expression('Example::AnnotationTarget')
    )
    expect(expression_parser).to have_received(:call).with('Example::AnnotationTarget').once
  end

  describe '#target', mutant_expression: 'Mutant::Integration::RspecSupport::AnnotationParser#target' do
    it 'returns the constant name string for named modules' do
      expect(annotation_parser.send(:target, Example::AnnotationTarget)).to eql('Example::AnnotationTarget')
    end

    it 'returns string annotations unchanged' do
      expect(annotation_parser.send(:target, 'Example::AnnotationTarget')).to eql('Example::AnnotationTarget')
    end

    it 'rejects anonymous modules' do
      expect { annotation_parser.send(:target, Class.new) }.to raise_error(
        ArgumentError,
        'Unsupported anonymous module/class mutant annotation'
      )
    end

    it 'rejects unsupported annotations' do
      expect { annotation_parser.send(:target, :symbol) }.to raise_error(
        ArgumentError,
        'Unsupported RSpec mutant annotation: :symbol'
      )
    end
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
    stub_const('Example::Outer::Inner', Class.new)
  end

  let(:parser) { ::Parser::CurrentRuby }

  it 'parses constant cover annotations' do
    node = parser.parse('cover(Example::Outer::Inner)').children.fetch(2)

    expect(expression_parser.call(node, nil)).to eql(
      parse_expression('Example::Outer::Inner')
    )
  end

  it 'parses top-level constant cover annotations' do
    node = parser.parse('cover(::Example::Outer::Inner)').children.fetch(2)

    expect(expression_parser.call(node, nil)).to eql(
      parse_expression('Example::Outer::Inner')
    )
  end

  it 'parses string cover annotations' do
    node = parser.parse("cover('Example::Outer::Inner')").children.fetch(2)

    expect(expression_parser.call(node, nil)).to eql(
      parse_expression('Example::Outer::Inner')
    )
  end

  it 'passes the literal string value through to the expression parser' do
    parser_spy = instance_double(Mutant::Expression::Parser)
    custom_parser = described_class.new(parser_spy)
    node = parser.parse("cover('Example::Outer::Inner')").children.fetch(2)

    expect(parser_spy).to receive(:call).with('Example::Outer::Inner').and_return(:parsed)

    expect(custom_parser.call(node, nil)).to eql(:parsed)
  end

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

  it 'rejects unsupported matcher node types' do
    node = parser.parse('cover(1)').children.fetch(2)

    expect { expression_parser.call(node, nil) }.to raise_error(
      ArgumentError,
      'Cannot derive mutant expression from RSpec cover matcher node type :int'
    )
  end

  it 'rejects unsupported constant parent node types' do
    node = parser.parse('cover(foo::Bar)').children.fetch(2)

    expect { expression_parser.call(node, nil) }.to raise_error(
      ArgumentError,
      'Cannot derive mutant expression from constant parent node type :send'
    )
  end

  it 'rejects unsupported matcher sends' do
    node = parser.parse('cover(subject)').children.fetch(2)

    expect { expression_parser.call(node, nil) }.to raise_error(
      ArgumentError,
      'Cannot derive mutant expression from RSpec cover matcher send :subject'
    )
  end

  describe '#const_name', mutant_expression: 'Mutant::Integration::RspecSupport::ExpressionParser#const_name' do
    it 'returns nested constant names as strings' do
      node = parser.parse('cover(Example::Outer::Inner)').children.fetch(2)

      expect(expression_parser.send(:const_name, node)).to eql('Example::Outer::Inner')
    end

    it 'converts non-string constant names via to_s before joining' do
      name = instance_double(Object, to_s: 'Inner')

      expect(expression_parser.send(:const_name, [nil, name])).to eql('Inner')
    end
  end

  describe '#parse_described_class',
           mutant_expression: 'Mutant::Integration::RspecSupport::ExpressionParser#parse_described_class' do
    it 'returns the described class name string before parsing' do
      expect(expression_parser.send(:parse_described_class, Example::DescribedClass)).to eql(
        parse_expression('Example::DescribedClass')
      )
    end

    it 'rejects anonymous described classes before calling the parser' do
      parser_spy = instance_double(Mutant::Expression::Parser)
      custom_parser = described_class.new(parser_spy)

      expect(parser_spy).not_to receive(:call)

      expect { custom_parser.send(:parse_described_class, Class.new) }.to raise_error(
        ArgumentError,
        'Cannot derive mutant expression from anonymous or missing described_class'
      )
    end

    it 'rejects named non-module described classes before calling the parser' do
      parser_spy = instance_double(Mutant::Expression::Parser)
      custom_parser = described_class.new(parser_spy)
      described_class_like = double('described class', name: 'Example::Pretender')

      expect(parser_spy).not_to receive(:call)

      expect { custom_parser.send(:parse_described_class, described_class_like) }.to raise_error(
        ArgumentError,
        'Cannot derive mutant expression from anonymous or missing described_class'
      )
    end
  end
end

RSpec.describe Mutant::Integration::RspecSupport::ExpressionResolver do
  subject(:expression_resolver) do
    described_class.new(annotation_parser, expression_parser, source_index)
  end

  let(:annotation_parser) { instance_double(Mutant::Integration::RspecSupport::AnnotationParser) }
  let(:expression_parser) { instance_double(Mutant::Expression::Parser) }
  let(:source_index)      { instance_double(Mutant::Integration::RspecSupport::SourceIndex) }
  let(:metadata) do
    {
      absolute_file_path: source_file,
      line_number:        2,
      location:           "#{source_file}:2",
      full_description:   'Example::Description extra words'
    }
  end

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

  describe '.build' do
    subject(:built_resolver) { described_class.build(Mutant::Config::DEFAULT.expression_parser) }

    it 'builds the annotation parser and source index collaborators' do
      expect(
        built_resolver.send(:annotation_parser)
      ).to be_a(Mutant::Integration::RspecSupport::AnnotationParser)
      expect(built_resolver.send(:expression_parser)).to be(Mutant::Config::DEFAULT.expression_parser)
      expect(
        built_resolver.send(:source_index)
      ).to be_a(Mutant::Integration::RspecSupport::SourceIndex)
    end

    it 'wires the expression parser into each collaborator constructor' do
      annotation_parser = instance_double(Mutant::Integration::RspecSupport::AnnotationParser)
      expression_parser = Mutant::Config::DEFAULT.expression_parser
      expression_resolver = instance_double(Mutant::Integration::RspecSupport::ExpressionResolver)
      parser_wrapper = instance_double(Mutant::Integration::RspecSupport::ExpressionParser)
      source_index = instance_double(Mutant::Integration::RspecSupport::SourceIndex)

      expect(Mutant::Integration::RspecSupport::AnnotationParser).to receive(:new)
        .with(expression_parser)
        .and_return(annotation_parser)
      expect(Mutant::Integration::RspecSupport::ExpressionParser).to receive(:new)
        .with(expression_parser)
        .and_return(parser_wrapper)
      expect(Mutant::Integration::RspecSupport::SourceIndex).to receive(:new)
        .with(parser_wrapper)
        .and_return(source_index)
      expect(described_class).to receive(:new)
        .with(annotation_parser, expression_parser, source_index)
        .and_return(expression_resolver)

      expect(described_class.build(expression_parser)).to be(expression_resolver)
    end
  end

  describe '#source_expression',
           mutant_expression: 'Mutant::Integration::RspecSupport::ExpressionResolver#source_expression' do
    let(:single_expression) { parse_expression('Example::One') }

    it 'returns nil when no cover annotations are indexed for the example' do
      allow(source_index).to receive(:expressions).with(metadata).and_return([])

      expect(expression_resolver.send(:source_expression, metadata)).to be(nil)
    end

    it 'returns the indexed expression when exactly one exists' do
      allow(source_index).to receive(:expressions).with(metadata).and_return([single_expression])

      expect(expression_resolver.send(:source_expression, metadata)).to be(single_expression)
    end

    it 'returns the collection first value when exactly one expression is reported' do
      expressions = double(
        'SingleExpressionCollection',
        empty?: false,
        one?:   true,
        first:  :first_expression,
        last:   :last_expression
      )
      allow(source_index).to receive(:expressions).with(metadata).and_return(expressions)

      expect(expression_resolver.send(:source_expression, metadata)).to eql(:first_expression)
    end

    it 'includes the example location in the multiple-annotation error' do
      allow(source_index).to receive(:expressions).with(metadata).and_return(%i[first second])

      expect { expression_resolver.send(:source_expression, metadata) }.to raise_error(
        ArgumentError,
        "Multiple cover annotations found for RSpec example at #{source_file}:2"
      )
    end
  end

  it 'prefers explicit mutant_expression annotations' do
    expect(annotation_parser).to receive(:call).with('Example::Annotated').and_return(:annotation_expression)
    expect(source_index).not_to receive(:expressions)
    expect(expression_parser).not_to receive(:try_parse)

    expect(
      expression_resolver.call(metadata.merge(mutant_expression: 'Example::Annotated'))
    ).to be(:annotation_expression)
  end

  it 'uses a single source-derived expression before falling back to the description' do
    allow(source_index).to receive(:expressions).with(metadata).and_return([:source_expression])
    expect(expression_parser).not_to receive(:try_parse)

    expect(expression_resolver.call(metadata)).to be(:source_expression)
  end

  it 'rejects multiple cover annotations on one example' do
    allow(source_index).to receive(:expressions).with(metadata).and_return(%i[first second])
    expect(expression_parser).not_to receive(:try_parse)

    expect { expression_resolver.call(metadata) }.to raise_error(
      ArgumentError,
      "Multiple cover annotations found for RSpec example at #{source_file}:2"
    )
  end

  it 'falls back to the description-derived expression when no source annotation exists' do
    allow(source_index).to receive(:expressions).with(metadata).and_return([])
    expect(expression_parser).to receive(:try_parse).with('Example::Description').and_return(:description_expression)

    expect(expression_resolver.call(metadata)).to be(:description_expression)
  end

  it 'extracts only the first token from the description' do
    allow(source_index).to receive(:expressions).with(metadata).and_return([])
    expect(expression_parser).to receive(:try_parse).with('Example::Description').and_return(nil)

    expression_resolver.call(metadata)
  end

  it 'returns nil for empty descriptions before asking the expression parser' do
    empty_description_metadata = metadata.merge(full_description: '')

    allow(source_index).to receive(:expressions).with(empty_description_metadata).and_return([])
    expect(expression_parser).not_to receive(:try_parse)

    expect(expression_resolver.send(:description_expression, empty_description_metadata)).to be(nil)
  end

  it 'falls back to the default expression when source and description parsing do not resolve an expression' do
    allow(source_index).to receive(:expressions)
      .with(metadata.merge(full_description: 'not-an-expression'))
      .and_return([])
    expect(expression_parser).to receive(:try_parse).with('not-an-expression').and_return(nil)

    expect(expression_resolver.call(metadata.merge(full_description: 'not-an-expression'))).to eql(
      Mutant::Integration::RspecSupport::DEFAULT_EXPRESSION
    )
  end

  it 'returns nil from source_expression when there are no source expressions' do
    allow(source_index).to receive(:expressions).with(metadata).and_return([])

    expect(expression_resolver.send(:source_expression, metadata)).to be(nil)
  end

  it 'returns the single source expression from source_expression' do
    allow(source_index).to receive(:expressions).with(metadata).and_return([:source_expression])

    expect(expression_resolver.send(:source_expression, metadata)).to be(:source_expression)
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

  it 'stores the parser collaborator during initialization' do
    parser = Mutant::Integration::RspecSupport::ExpressionParser.new(Mutant::Config::DEFAULT.expression_parser)
    index = described_class.new(parser)

    expect(index.instance_variable_get(:@parser)).to be(parser)
    expect(index.instance_variable_get(:@cache)).to eql({})
  end

  it 'returns no expressions when the requested line is not indexed' do
    file = Tempfile.new(['mutant-rspec-unindexed', '.rb'])
    file.write(
      <<~RUBY
        RSpec.describe Example::Root do
          it('ignored by cover matcher') do
            is_expected.to cover('Example::Covered')
          end
        end
      RUBY
    )
    file.close

    expect(source_index.expressions(absolute_file_path: file.path, line_number: 99)).to eql([])
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  it 'returns no expressions when the source file is missing' do
    expect(source_index.expressions(absolute_file_path: '/tmp/does-not-exist.rb', line_number: 1)).to eql([])
  end

  it 'returns no expressions when no source path metadata is present' do
    expect(source_index.expressions(line_number: 1)).to eql([])
  end

  it 'returns cover expressions indexed by the example line number' do
    file = Tempfile.new(['mutant-rspec-valid', '.rb'])
    file.write(
      <<~RUBY
        RSpec.describe Example::Root do
          it('ignored by cover matcher') do
            is_expected.to cover('Example::Covered')
          end
        end
      RUBY
    )
    file.close

    expect(
      source_index.expressions(absolute_file_path: file.path, line_number: 2)
    ).to eql([parse_expression('Example::Covered')])
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  it 'passes described_class metadata to the expression parser' do
    file = Tempfile.new(['mutant-rspec-described-class', '.rb'])
    file.write(
      <<~RUBY
        RSpec.describe Example::DescribedClass do
          it('ignored by cover matcher') do
            is_expected.to cover(described_class)
          end
        end
      RUBY
    )
    file.close

    parser = instance_double(Mutant::Integration::RspecSupport::ExpressionParser)
    index = described_class.new(parser)
    described_class_constant = Class.new
    stub_const('Example::DescribedClass', described_class_constant)

    expect(parser).to receive(:call).with(instance_of(Parser::AST::Node), described_class_constant)
      .and_return(parse_expression('Example::DescribedClass'))

    expect(
      index.expressions(
        absolute_file_path: file.path,
        described_class:    described_class_constant,
        line_number:        2
      )
    ).to eql([parse_expression('Example::DescribedClass')])
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  it 'preserves the parsed buffer path for downstream location handling' do
    file = Tempfile.new(['mutant-rspec-buffer', '.rb'])
    file.write(
      <<~RUBY
        RSpec.describe Example::Root do
          it('ignored by cover matcher') do
            is_expected.to cover('Example::Covered')
          end
        end
      RUBY
    )
    file.close

    node = source_index.send(:parse, file.path)

    expect(node.loc.expression.source_buffer.name).to eql(file.path)
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  it 'caches parsed source indexes by path' do
    file = Tempfile.new(['mutant-rspec-cache', '.rb'])
    file.write(
      <<~RUBY
        RSpec.describe Example::Root do
          it('ignored by cover matcher') do
            is_expected.to cover('Example::Covered')
          end
        end
      RUBY
    )
    file.close

    parser = instance_double(
      Mutant::Integration::RspecSupport::ExpressionParser,
      call: parse_expression('Example::Covered')
    )
    indexed_source = described_class.new(parser)

    allow(File).to receive(:read).and_call_original

    2.times do
      indexed_source.expressions(absolute_file_path: file.path, line_number: 2)
    end

    expect(File).to have_received(:read).with(file.path).once
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  it 'indexes cover annotations by the example expression line' do
    index = described_class.new(
      Mutant::Integration::RspecSupport::ExpressionParser.new(Mutant::Config::DEFAULT.expression_parser)
    )
    cover_node = Parser::AST::Node.new(:str, ['Example::Covered'])
    example_body = Parser::AST::Node.new(:begin, [])
    example_node = instance_double(
      Parser::AST::Node,
      loc: Struct.new(:line, :expression).new(nil, Struct.new(:line).new(7)),
      children: [nil, nil, example_body]
    )
    parsed_root = Parser::AST::Node.new(:begin, [])

    allow(index).to receive(:parse).with('/tmp/example.rb').and_return(parsed_root)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:each)
      .with(parsed_root)
      .and_return([example_node].to_enum)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:example_block?).with(example_node).and_return(true)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:cover_arguments)
      .with(example_body)
      .and_return([cover_node])

    expect(index.send(:index, '/tmp/example.rb')).to eql({ 7 => [cover_node] })
  end

  it 'treats missing example bodies as having no cover annotations' do
    index = described_class.new(
      Mutant::Integration::RspecSupport::ExpressionParser.new(Mutant::Config::DEFAULT.expression_parser)
    )
    example_node = instance_double(
      Parser::AST::Node,
      loc: Struct.new(:line, :expression).new(nil, Struct.new(:line).new(7)),
      children: [nil, nil]
    )
    parsed_root = Parser::AST::Node.new(:begin, [])

    allow(index).to receive(:parse).with('/tmp/example.rb').and_return(parsed_root)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:each)
      .with(parsed_root)
      .and_return([example_node].to_enum)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:example_block?).with(example_node).and_return(true)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:cover_arguments).with(nil).and_return([])

    expect(index.send(:index, '/tmp/example.rb')).to eql({ 7 => [] })
  end

  it 'reads the example body via index access on the children collection' do
    index = described_class.new(
      Mutant::Integration::RspecSupport::ExpressionParser.new(Mutant::Config::DEFAULT.expression_parser)
    )
    children = Class.new do
      def initialize(values)
        @values = values
      end

      def [](index)
        @values[index]
      end
    end.new([nil, nil, nil])
    example_node = instance_double(
      Parser::AST::Node,
      loc: Struct.new(:line, :expression).new(nil, Struct.new(:line).new(7)),
      children: children
    )
    parsed_root = Parser::AST::Node.new(:begin, [])

    allow(index).to receive(:parse).with('/tmp/example.rb').and_return(parsed_root)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:each)
      .with(parsed_root)
      .and_return([example_node].to_enum)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:example_block?).with(example_node).and_return(true)
    allow(Mutant::Integration::RspecSupport::Node).to receive(:cover_arguments).with(nil).and_return([])

    expect(index.send(:index, '/tmp/example.rb')).to eql({ 7 => [] })
  end
end
