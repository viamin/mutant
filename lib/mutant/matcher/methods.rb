# frozen_string_literal: true

module Mutant
  class Matcher
    # Abstract base class for matcher that returns method subjects from scope
    class Methods < self
      include AbstractType, Concord.new(:scope)

      CANDIDATE_NAMES = IceNine.deep_freeze(%i[
        public_instance_methods
        private_instance_methods
        protected_instance_methods
      ])

      private_constant(*constants(false))

      # Enumerate subjects
      #
      # @param [Env::Bootstrap] env
      #
      # @return [Enumerable<Subject>]
      def call(env)
        Chain.new(
          methods.map { |method| matcher.new(scope, method) }
        ).call(env)
      end

    private

      # method matcher class
      #
      # @return [Class:Matcher::Method]
      def matcher
        self.class::MATCHER
      end

      # Available methods scope
      #
      # @return [Enumerable<Method, UnboundMethod>]
      def methods
        candidate_names.each_with_object([]) do |name, methods|
          method = method_defined_on_candidate_scope(name)
          methods << method if method
        end
      end
      memoize :methods

      # Method defined directly on candidate scope
      #
      # A prepended module shadows the method returned by reflection. Walk its
      # super chain so a class implementation remains a candidate without
      # treating the wrapper as owned by the class.
      #
      # @param [Symbol] method_name
      #
      # @return [Method, UnboundMethod, nil]
      def method_defined_on_candidate_scope(method_name)
        method = access(method_name)
        method = method.super_method until method.nil? || method.owner.equal?(candidate_scope)
        method
      end

      # Candidate method names on target scope
      #
      # @return [Enumerable<Symbol>]
      def candidate_names
        CANDIDATE_NAMES
          .map(&candidate_scope.method(:public_send))
          .reduce(:+)
          .sort
      end

      # Candidate scope
      #
      # @return [Class, Module]
      abstract_method :candidate_scope

      # Matcher for singleton methods
      class Singleton < self
        MATCHER = Matcher::Method::Singleton

      private

        # Method object on scope
        #
        # @param [Symbol] method_name
        #
        # @return [Method]
        def access(method_name)
          scope.method(method_name)
        end

        # Candidate scope
        #
        # @return [Class]
        def candidate_scope
          scope.singleton_class
        end
        memoize :candidate_scope, freezer: :noop

      end # Singleton

      # Matcher for instance methods
      class Instance < self
        MATCHER = Matcher::Method::Instance

      private

        # Method object on scope
        #
        # @param [Symbol] method_name
        #
        # @return [UnboundMethod]
        def access(method_name)
          scope.instance_method(method_name)
        end

        # Candidate scope
        #
        # @return [Class, Module]
        def candidate_scope
          scope
        end

      end # Instance
    end # Methods
  end # Matcher
end # Mutant
