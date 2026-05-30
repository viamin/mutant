# frozen_string_literal: true

class Regexp
  module Expression
    module MutantQuantifierCompat
      def min
        mutant_derived_data.fetch(:min)
      end

      def max
        mutant_derived_data.fetch(:max)
      end

      def mode
        mutant_derived_data.fetch(:mode)
      end

    private

      def mutant_derived_data
        return @derived_data if instance_variable_defined?(:@derived_data) && @derived_data
        return mutant_derive_data if frozen?

        @derived_data = mutant_derive_data
      end

      def mutant_derive_data
        min, max = mutant_quantifier_bounds

        { min: min, max: max, mode: mutant_quantifier_mode }
      end

      def mutant_quantifier_bounds
        case text[0]
        when '?'
          [0, 1]
        when '*'
          [0, -1]
        when '+'
          [1, -1]
        else
          mutant_interval_bounds
        end
      end

      def mutant_interval_bounds
        int_min = text[/\{(\d*)/, 1]
        int_max = text[/,?(\d*)\}/, 1]

        [int_min.to_i, int_max.empty? ? -1 : int_max.to_i]
      end

      def mutant_quantifier_mode
        case text[/.([?+])/, 1]
        when '?'
          :reluctant
        when '+'
          :possessive
        else
          :greedy
        end
      end
    end

    ::Regexp::Expression::Quantifier.prepend(MutantQuantifierCompat)
  end
end
