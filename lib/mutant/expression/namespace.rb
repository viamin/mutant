# frozen_string_literal: true

module Mutant
  class Expression
    # Abstract base class for expressions matching namespaces
    class Namespace < self
      include AbstractType, Anima.new(:scope_name)
      private(*anima.attribute_names)

    private

      def prefix_match_length(expression)
        if expression.syntax.match?(/\A#{::Regexp.escape(scope_name)}(?:(?:#{SCOPE_OPERATOR})|[.#]|\z)/)
          scope_name.length
        else
          0
        end
      end

      # Recursive namespace expression
      class Recursive < self
        REGEXP = /\A#{SCOPE_NAME_PATTERN}?\*\z/.freeze

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
          elsif prefix_match_length(expression).positive?
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
          prefix_match_length(expression)
        end

      end # Exact
    end # Namespace
  end # Expression
end # Mutant
