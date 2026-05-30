# frozen_string_literal: true

require "parser/ruby#{RUBY_VERSION[/\A\d+\.\d+/].delete('.')}"
require 'rspec/core'

module Mutant
  class Integration
    # Rspec integration
    class Rspec < self

      ALL_EXPRESSION       = Expression::Namespace::Recursive.new(scope_name: nil)
      EXPRESSION_CANDIDATE = /\A([^ ]+)(?: )?/.freeze
      EXIT_SUCCESS         = 0
      CLI_OPTIONS          = IceNine.deep_freeze(%w[spec --fail-fast])
      TEST_ID_FORMAT       = 'rspec:%<index>d:%<location>s/%<description>s'

      private_constant(*constants(false))

      def initialize(*)
        super
        @output = StringIO.new
        @runner = RSpec::Core::Runner.new(RSpec::Core::ConfigurationOptions.new(CLI_OPTIONS))
        @world  = RSpec.world
        @source_index = RspecSupport::SourceIndex.new(RspecSupport::ExpressionParser.new(expression_parser))
      end

      def setup
        RSpec::Matchers.prepend(RspecSupport::Matchers)
        @runner.setup($stderr, @output)
        self
      end
      memoize :setup

      # rubocop:disable MethodLength
      def call(tests)
        examples = tests.map(&all_tests_index.method(:fetch))
        filter_examples(&examples.method(:include?))
        start = Timer.now
        passed = @runner.run_specs(@world.ordered_example_groups).equal?(EXIT_SUCCESS)
        @output.rewind
        Result::Test.new(
          output:  @output.read,
          passed:  passed,
          runtime: Timer.now - start,
          tests:   tests
        )
      end

      def all_tests
        all_tests_index.keys
      end
      memoize :all_tests

    private

      def all_tests_index
        all_examples.each_with_index.each_with_object({}) do |(example, example_index), index|
          index[parse_example(example, example_index)] = example
        end
      end
      memoize :all_tests_index

      def parse_example(example, index)
        metadata = example.metadata

        id = TEST_ID_FORMAT % {
          index:       index,
          location:    metadata.fetch(:location),
          description: metadata.fetch(:full_description)
        }

        Test.new(
          expression: parse_expression(metadata),
          id:         id
        )
      end

      def parse_expression(metadata)
        if metadata.key?(:mutant_expression)
          parse_annotation(metadata.fetch(:mutant_expression))
        else
          source_expression(metadata) || description_expression(metadata) || ALL_EXPRESSION
        end
      end

      def all_examples
        @world
          .example_groups
          .flat_map { |example_group| [example_group, *example_group.descendants] }
          .flat_map(&:examples)
          .select do |example|
          example.metadata.fetch(:mutant, true)
        end
      end

      def filter_examples(&predicate)
        @world.filtered_examples.each_value do |examples|
          examples.keep_if(&predicate)
        end
      end

      def description_expression(metadata)
        match = EXPRESSION_CANDIDATE.match(metadata.fetch(:full_description))

        expression_parser.try_parse(match.captures.first) if match
      end

      def parse_annotation(annotation)
        case annotation
        when Module
          return expression_parser.(annotation.name) if annotation.name

          fail ArgumentError, 'Unsupported anonymous module/class mutant annotation'
        when String
          expression_parser.(annotation)
        else
          fail ArgumentError, "Unsupported RSpec mutant annotation: #{annotation.inspect}"
        end
      end

      def source_expression(metadata)
        expressions = @source_index.expressions(metadata)
        return if expressions.empty?
        return expressions.first if expressions.one?

        fail ArgumentError, "Multiple cover annotations found for RSpec example at #{metadata.fetch(:location)}"
      end

    end # Rspec

    module RspecSupport
      EXAMPLE_METHODS     = IceNine.deep_freeze(%i[example it scenario specify])
      EXPECTATION_METHODS = IceNine.deep_freeze(%i[not_to to to_not])

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

      class SourceIndex
        include Concord.new(:parser)

        EMPTY_MAP = {}.freeze

        def expressions(metadata)
          fetch(source_path(metadata)).fetch(metadata.fetch(:line_number), EMPTY_ARRAY).map do |argument|
            parser.(argument, metadata.fetch(:described_class, nil))
          end
        end

      private

        def fetch(path)
          return EMPTY_MAP unless path && File.file?(path)

          @cache ||= {}
          @cache.fetch(path) { @cache[path] = index(path) }
        end

        def source_path(metadata)
          metadata.fetch(:absolute_file_path) do
            metadata.fetch(:file_path, nil)
          end
        end

        def index(path)
          buffer        = ::Parser::Source::Buffer.new(path)
          buffer.source = File.read(path)
          root          = ruby_parser.parse(buffer)
          return EMPTY_MAP unless root

          each_node(root).with_object(Hash.new { |hash, key| hash[key] = [] }) do |node, index|
            next unless example_block?(node)

            index[node.loc.expression.line].concat(cover_arguments(node.children.fetch(2, nil)))
          end
        end

        def each_node(node, &block)
          return enum_for(__method__, node) unless block

          yield node

          node.children.grep(::Parser::AST::Node) do |child|
            each_node(child, &block)
          end
        end

        def cover_arguments(node)
          return EMPTY_ARRAY unless node.is_a?(::Parser::AST::Node)

          each_node(node).each_with_object([]) do |child, arguments|
            argument = cover_argument(child)
            next unless argument

            arguments << argument
          end
        end

        def cover_argument(node)
          return unless node.type.equal?(:send)

          _receiver, method_name, matcher = *node
          return unless EXPECTATION_METHODS.include?(method_name)
          return unless matcher.is_a?(::Parser::AST::Node)
          return unless matcher.type.equal?(:send)
          return unless matcher.children.fetch(0).nil?
          return unless matcher.children.fetch(1).equal?(:cover)

          matcher.children.fetch(2)
        end

        def example_block?(node)
          return false unless node.type.equal?(:block)

          send_node = node.children.fetch(0)

          send_node.type.equal?(:send) && EXAMPLE_METHODS.include?(send_node.children.fetch(1))
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
            expression_parser.(node.children.fetch(0))
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

          [parent_name(parent), name.to_s].compact.join('::')
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
