# frozen_string_literal: true

module Mutant
  class Expression
    # Abstract base class for expressions matching namespaces
    class Namespace < self
      include AbstractType, Anima.new(:scope_name)
      private(*anima.attribute_names)

    private

      def prefix_match_length(expression)
        if expression.syntax.match?(/\A#{Regexp.escape(scope_name)}(?:(?:#{SCOPE_OPERATOR})|[.#]|\z)/)
          scope_name.length
        else
          0
        end
      end

      # Recursive namespace expression
      class Recursive < self
        REGEXP = /\A#{SCOPE_NAME_PATTERN}?\*\z/.freeze

        # Initialize object
        #
        # @return [undefined]
        def initialize(*)
          super
          @recursion_pattern = Regexp.union(
            /\A#{scope_name}\z/,
            /\A#{scope_name}::/,
            /\A#{scope_name}[.#]/
          )
        end

        # Syntax for expression
        #
        # @return [String]
        def syntax
          "#{scope_name}*"
        end
        memoize :syntax

        # Matcher for expression
        #
        # @return [Matcher]
        def matcher
          Matcher::Namespace.new(self)
        end

        # Length of match with other expression
        #
        # @param [Expression] expression
        #
        # @return [Integer]
        def match_length(expression)
          if eql?(expression)
            syntax.length
          elsif @recursion_pattern.match?(expression.syntax)
            scope_name.length
          else
            0
          end
        end

      end # Recursive

      # Exact namespace expression
      class Exact < self

        REGEXP = /\A#{SCOPE_NAME_PATTERN}\z/.freeze

        # Matcher matcher on expression
        #
        # @return [Matcher]
        def matcher
          Matcher::Namespace.new(self)
        end

        # Syntax for expression
        #
        # @return [String]
        alias_method :syntax, :scope_name
        public :syntax

        # Length of match with other expression
        #
        # @param [Expression] expression
        #
        # @return [Integer]
        def match_length(expression)
          if eql?(expression)
            syntax.length
          else
            prefix_match_length(expression)
          end
        end

      end # Exact
    end # Namespace
  end # Expression
end # Mutant
