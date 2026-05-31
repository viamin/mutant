# frozen_string_literal: true

require "parser/ruby#{RUBY_VERSION[/\A\d+\.\d+/].delete('.')}"
require 'rspec/core'

module Mutant
  class Integration
    # Rspec integration
    class Rspec < self

      EXIT_SUCCESS         = 0
      CLI_OPTIONS          = IceNine.deep_freeze(%w[spec --fail-fast])

      private_constant(*constants(false))

      class State
        define_method(:initialize) do |examples:, output:, runner:|
          @examples = examples
          @output   = output
          @runner   = runner
        end

        attr_reader :examples, :output, :runner
      end
      private_constant :State

      define_method(:initialize) do |*arguments|
        super(*arguments)
        @state = State.new(
          examples: RspecSupport::Examples.build(expression_parser: expression_parser, world: RSpec.world),
          output:   StringIO.new,
          runner:   RSpec::Core::Runner.new(RSpec::Core::ConfigurationOptions.new(CLI_OPTIONS))
        )
      end

      def setup
        RSpec::Matchers.prepend(RspecSupport::Matchers)
        runner.setup($stderr, output)
        self
      end
      memoize :setup

      # rubocop:disable MethodLength
      def call(tests)
        selected_examples = tests.map(&examples.method(:fetch))
        examples.filter(selected_examples)
        start = Timer.now
        passed = run_specs.equal?(EXIT_SUCCESS)
        output.rewind

        result_attributes = {
          output:  output.read,
          passed:  passed,
          runtime: Timer.now - start,
          tests:   tests
        }

        Result::Test.new(result_attributes)
      end

      def all_tests
        examples.all_tests
      end
      memoize :all_tests

    private

      def output
        state.output
      end

      def runner
        state.runner
      end

      def examples
        state.examples
      end

      def run_specs
        runner.run_specs(examples.ordered_groups)
      rescue SystemExit => exception
        exception.status
      end

      attr_reader :state

    end # Rspec

    module RspecSupport
      DEFAULT_EXPRESSION = Expression::Namespace::Recursive.new(scope_name: nil)
      DESCRIPTION_CANDIDATE = /\A(?<expression>[^ ]+)(?: )?/.freeze
      EXAMPLE_METHODS     = IceNine.deep_freeze(%i[example it scenario specify])
      EXPECTATION_METHODS = IceNine.deep_freeze(%i[not_to to to_not])
      TEST_ID_FORMAT      = 'rspec:%<index>d:%<location>s/%<description>s'

      def self.cover_annotation?(expected)
        case expected
        when Module
          !expected.name.nil?
        when String
          Config::DEFAULT.expression_parser.try_parse(expected)
        else
          false
        end
      end

      module Matchers
        private

        def cover(expected)
          if RspecSupport.cover_annotation?(expected)
            CoverMatcher.new(expected)
          else
            super
          end
        end
      end

      class CoverMatcher
        include Concord.new(:expected)

        def matches?(*)
          true
        end

        def description
          "cover #{expected.inspect}"
        end

        def failure_message
          description
        end

        def failure_message_when_negated
          description
        end
      end

      class Examples
        include Concord.new(:resolver, :world)

        def self.build(expression_parser:, world:)
          new(ExpressionResolver.build(expression_parser), world)
        end

        def all_tests
          index.keys
        end

        def fetch(test)
          index.fetch(test)
        end

        def filter(selected_examples)
          world.filtered_examples.each_value do |examples|
            examples.keep_if(&selected_examples.method(:include?))
          end
        end

        def ordered_groups
          world.ordered_example_groups
        end

      private

        def available_examples
          world
            .example_groups
            .flat_map { |example_group| [example_group, *example_group.descendants] }
            .flat_map(&:examples)
            .select { |example| example.metadata.fetch(:mutant, true) }
        end

        def index
          @index ||= available_examples.each_with_index.each_with_object({}) do |(example, example_index), tests|
            tests[parse_test(example, example_index)] = example
          end
        end

        def parse_test(example, example_index)
          metadata = example.metadata

          test_attributes = {
            expression: resolver.(metadata),
            id:         TEST_ID_FORMAT % {
              index:       example_index,
              location:    metadata.fetch(:location),
              description: metadata.fetch(:full_description)
            }
          }

          Test.new(test_attributes)
        end
      end

      class ExpressionResolver
        include Concord.new(:annotation_parser, :expression_parser, :source_index)

        def self.build(expression_parser)
          new(
            AnnotationParser.new(expression_parser),
            expression_parser,
            SourceIndex.new(ExpressionParser.new(expression_parser))
          )
        end

        def call(metadata)
          return annotation_parser.call(metadata.fetch(:mutant_expression)) if metadata.key?(:mutant_expression)

          source_expression(metadata) || description_expression(metadata) || DEFAULT_EXPRESSION
        end

      private

        def description_expression(metadata)
          match = DESCRIPTION_CANDIDATE.match(metadata.fetch(:full_description))
          return unless match

          expression_parser.try_parse(match[:expression])
        end

        def source_expression(metadata)
          expressions = source_index.expressions(metadata)
          return if expressions.empty?
          return expressions.first if expressions.one?

          fail ArgumentError, "Multiple cover annotations found for RSpec example at #{metadata.fetch(:location)}"
        end
      end

      class AnnotationParser
        include Concord.new(:expression_parser)

        def call(annotation)
          expression_parser.(target(annotation))
        end

      private

        def target(annotation)
          case annotation
          when Module
            return annotation.name if annotation.name

            fail ArgumentError, 'Unsupported anonymous module/class mutant annotation'
          when String
            annotation
          else
            fail ArgumentError, "Unsupported RSpec mutant annotation: #{annotation.inspect}"
          end
        end
      end

      module Node
        def self.cover_argument(node)
          return unless node.type.equal?(:send)

          _receiver, method_name, matcher = *node
          return unless EXPECTATION_METHODS.include?(method_name)
          return unless cover_matcher?(matcher)

          matcher.children.fetch(2)
        end

        def self.cover_arguments(node)
          return EMPTY_ARRAY unless node.is_a?(::Parser::AST::Node)

          each(node).filter_map { |child| cover_argument(child) }
        end

        def self.each(node, &block)
          return enum_for(__method__, node) unless block

          yield node

          node.children.grep(::Parser::AST::Node) do |child|
            each(child, &block)
          end
        end

        def self.example_block?(node)
          return false unless node.type.equal?(:block)

          send_node = node.children.fetch(0)

          send_node.type.equal?(:send) && EXAMPLE_METHODS.include?(send_node.children.fetch(1))
        end

        def self.cover_matcher?(matcher)
          matcher.is_a?(::Parser::AST::Node) &&
            matcher.type.equal?(:send) &&
            matcher.children.fetch(0).nil? &&
            matcher.children.fetch(1).equal?(:cover)
        end
      end

      module Source
        def self.path(metadata)
          metadata.fetch(:absolute_file_path) do
            metadata.fetch(:file_path, nil)
          end
        end
      end

      class SourceIndex
        EMPTY_MAP = {}.freeze

        define_method(:initialize) do |parser|
          @cache  = {}
          @parser = parser
        end

        def expressions(metadata)
          path = Source.path(metadata)
          return EMPTY_ARRAY unless path && File.file?(path)

          indexed_expressions(path).fetch(metadata.fetch(:line_number), EMPTY_ARRAY).map do |argument|
            parser.(argument, metadata.fetch(:described_class, nil))
          end
        end

      private

        def indexed_expressions(path)
          cache.fetch(path) { cache[path] = index(path) }
        end

        attr_reader :cache, :parser

        def index(path)
          root = parse(path)
          return EMPTY_MAP unless root

          Node.each(root).with_object(Hash.new { |hash, key| hash[key] = [] }) do |node, indexed_nodes|
            next unless Node.example_block?(node)

            indexed_nodes[node.loc.expression.line].concat(Node.cover_arguments(node.children[2]))
          end
        end

        def parse(path)
          buffer        = ::Parser::Source::Buffer.new(path)
          buffer.source = File.read(path)
          ruby_parser.parse(buffer)
        rescue ::Parser::SyntaxError
          nil
        end

        def ruby_parser
          @ruby_parser ||= ::Parser.const_get("Ruby#{RUBY_VERSION[/\A\d+\.\d+/].delete('.')}").new
        end
      end

      class ExpressionParser
        include Concord.new(:expression_parser)

        def call(node, described_class)
          case node.type
          when :const
            expression_parser.(const_name(node))
          when :send
            parse_send(node, described_class)
          when :str
            value, = node.children

            expression_parser.(value)
          else
            fail(
              ArgumentError,
              "Cannot derive mutant expression from RSpec cover matcher node type #{node.type.inspect}"
            )
          end
        end

      private

        def const_name(node)
          parent, name = *node
          parent = parent_name(parent)

          return name.to_s unless parent

          "#{parent}::#{name}"
        end

        def parent_name(node)
          return unless node
          return if node.type.equal?(:cbase)
          return const_name(node) if node.type.equal?(:const)

          fail ArgumentError, "Cannot derive mutant expression from constant parent node type #{node.type.inspect}"
        end

        def parse_send(node, described_class)
          receiver, method_name, = *node
          return parse_described_class(described_class) if receiver.nil? && method_name.equal?(:described_class)

          fail ArgumentError, "Cannot derive mutant expression from RSpec cover matcher send #{method_name.inspect}"
        end

        def parse_described_class(described_class)
          return expression_parser.(described_class.name) if described_class.is_a?(Module) && described_class.name

          fail ArgumentError, 'Cannot derive mutant expression from anonymous or missing described_class'
        end
      end
    end

  end # Integration
end # Mutant
