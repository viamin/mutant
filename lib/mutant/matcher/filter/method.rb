# frozen_string_literal: true

module Mutant
  class Matcher
    class Filter
      # Filter for an explicit method expression
      class Method < Matcher
        include Concord.new(:matcher, :expression)

        WARNING_FORMAT = '%s could not produce a subject'.freeze
        private_constant(*constants(false))

        # Enumerate matches and report an explicit expression that had none
        #
        # @param [Env::Bootstrap] env
        #
        # @return [Enumerable<Subject>]
        def call(env)
          matcher.call(env).select(&method(:match?)).tap do |subjects|
            env.warn(WARNING_FORMAT % expression.syntax) if subjects.empty?
          end
        end

      private

        # Test whether subject expression matches
        #
        # @param [Subject] subject
        #
        # @return [Boolean]
        def match?(subject)
          subject.expression.eql?(expression)
        end

      end # Method
    end # Filter
  end # Matcher
end
