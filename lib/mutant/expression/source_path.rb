# frozen_string_literal: true

module Mutant
  class Expression
    class SourcePath < self
      include Anima.new(:glob)

      private(*anima.attribute_names)

      REGEXP = /\Asource:(?<glob>.+)\z/.freeze

      class Predicate
        include Concord.new(:glob)

        def call(subject)
          Matcher::SourcePath.match?(glob, subject.source_path)
        end
      end

      # Matcher for expression
      #
      # @return [Matcher]
      def matcher
        Matcher::SourcePath.new(glob)
      end

      # Syntax of expression
      #
      # @return [String]
      def syntax
        "source:#{glob}"
      end
      memoize :syntax

      # Predicate for ignored subjects
      #
      # @return [#call]
      def subject_predicate
        Predicate.new(glob)
      end
    end
  end
end
