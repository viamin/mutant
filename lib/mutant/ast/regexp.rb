# frozen_string_literal: true

module Mutant
  module AST
    # Regexp source mapper
    module Regexp
      # Parse regex string into expression
      #
      # @param regexp [String]
      #
      # @return [Regexp::Expression, nil]
      #
      # rubocop:disable Lint/HandleExceptions
      def self.parse(regexp)
        expression = ::Regexp::Parser.parse(regexp)
        warm_quantifier_cache(expression) if expression
        expression
      # regexp_parser is more strict than MRI
      rescue ::Regexp::Scanner::PrematureEndError
      end
      # rubocop:enable Lint/HandleExceptions

      # Convert expression into ast node
      #
      # @param expression [Regexp::Expression]
      #
      # @return [Parser::AST::Node]
      def self.to_ast(expression)
        ast_type = :"regexp_#{expression.token}_#{expression.type}"

        Transformer.lookup(ast_type).to_ast(expression)
      end

      # Convert node into expression
      #
      # @param node [Parser::AST::Node]
      #
      # @return [Regexp::Expression]
      def self.to_expression(node)
        expression = Transformer.lookup(node.type).to_expression(node)
        warm_quantifier_cache(expression)
        IceNine.deep_freeze(expression)
      end

      # Pre-populate `Regexp::Expression::Quantifier#derived_data` memos in the
      # expression tree
      #
      # `regexp_parser` 2.12.0 lazily derives `min`, `max`, and `mode` on
      # `Quantifier` via `@derived_data ||= ...`. Any downstream consumer that
      # deep-freezes the tree (e.g. `Adamantium` in the transformers) would
      # otherwise raise `FrozenError` the first time those accessors are read.
      # Walking the tree once after parse warms the memo so subsequent freezes
      # are safe.
      #
      # @param expression [Regexp::Expression]
      #
      # @return [undefined]
      def self.warm_quantifier_cache(expression)
        if expression.quantified?
          expression.quantifier.min
          expression.quantifier.max
          expression.quantifier.mode
        end

        return if expression.terminal?

        expression.expressions.each(&method(:warm_quantifier_cache))
      end
      private_class_method :warm_quantifier_cache
    end # Regexp
  end # AST
end # Mutant
