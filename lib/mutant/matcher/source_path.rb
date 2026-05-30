# frozen_string_literal: true

module Mutant
  class Matcher
    class SourcePath < self
      include Concord.new(:glob)

      FLAGS = File::FNM_EXTGLOB | File::FNM_PATHNAME
      INSTANCE_CANDIDATE_NAMES = IceNine.deep_freeze(%i[
        public_instance_methods
        private_instance_methods
        protected_instance_methods
      ])
      SINGLETON_CANDIDATE_NAMES = INSTANCE_CANDIDATE_NAMES

      def self.match?(glob, source_path)
        path = source_path.to_s

        File.fnmatch?(glob, path, FLAGS) || File.fnmatch?(glob, relative_path(path), FLAGS)
      end

      # Enumerate subjects
      #
      # @param [Env::Bootstrap] env
      #
      # @return [Enumerable<Subject>]
      def call(env)
        env.matchable_scopes.flat_map do |scope|
          methods(env, scope.raw)
        end
      end

      def self.relative_path(path)
        Pathname.new(path).relative_path_from(Pathname.pwd).to_s
      rescue ArgumentError
        path
      end
      private_class_method :relative_path

    private

      INSTANCE_MATCHER  = Matcher::Method::Instance
      SINGLETON_MATCHER = Matcher::Method::Singleton

      def methods(env, scope)
        singleton_methods(env, scope).concat(instance_methods(env, scope))
      end

      def singleton_methods(env, scope)
        subject_methods(
          env,
          scope,
          scope.singleton_class,
          SINGLETON_CANDIDATE_NAMES,
          SINGLETON_MATCHER
        ) { |method_name| scope.method(method_name) }
      end

      def instance_methods(env, scope)
        subject_methods(
          env,
          scope,
          scope,
          INSTANCE_CANDIDATE_NAMES,
          INSTANCE_MATCHER
        ) { |method_name| scope.instance_method(method_name) }
      end

      def subject_methods(env, scope, candidate_scope, candidate_names, matcher_class)
        candidate_method_names(candidate_scope, candidate_names).flat_map do |method_name|
          target_method = yield(method_name)

          next EMPTY_ARRAY unless target_method.owner.equal?(candidate_scope)

          source_location = target_method.source_location
          next EMPTY_ARRAY unless source_location && self.class.match?(glob, source_location.first)

          matcher_class.new(scope, target_method).call(env)
        end
      end

      def candidate_method_names(candidate_scope, candidate_names)
        candidate_names
          .map(&candidate_scope.method(:public_send))
          .reduce(:+)
          .sort
      end
    end
  end
end
