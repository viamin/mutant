# frozen_string_literal: true

module Mutant
  class Config
    class Loader
      include Adamantium::Flat, Concord.new(:config), Procto.call(:load)

      Error = Class.new(RuntimeError)

      FILE_NAME      = '.mutant.yml'
      ROOT_KEYS      = %w[
        coverage_criteria
        environment_variables
        fail_fast
        integration
        jobs
        matcher
        results_dir
        requires
      ].freeze
      MATCHER_KEYS   = %w[ignore subjects].freeze
      COVERAGE_KEYS  = %w[process_abort test_result timeout].freeze

      private_constant :FILE_NAME, :ROOT_KEYS, :MATCHER_KEYS, :COVERAGE_KEYS

      def load
        return config unless path.file?

        config.with(attributes)
      end

    private

      def path = config.pathname.pwd.join(FILE_NAME)
      memoize :path

      def reader = NodeReader.new(path)
      memoize :reader

      def document
        Psych.parse_file(path)
      rescue Psych::SyntaxError => exception
        fail Error, exception.message
      end
      memoize :document

      def attributes
        root = document_root or return EMPTY_HASH

        reader.mapping(root, [], ROOT_KEYS).each_with_object({}) do |(key, value_node), result|
          result[attribute_name(key)] = __send__(:"attribute_#{key}", value_node)
        end
      end

      def document_root = document.instance_of?(Psych::Nodes::Document) ? document.root : nil

      def attribute_name(key)
        key.to_sym
      end

      def attribute_coverage_criteria(node)
        defaults = config.coverage_criteria.to_h

        reader.mapping(node, ['coverage_criteria'], COVERAGE_KEYS).each do |key, value_node|
          defaults[key.to_sym] = reader.boolean(value_node, ['coverage_criteria', key])
        end

        CoverageCriteria.new(defaults)
      end

      def attribute_environment_variables(node)
        reader.string_hash(node, ['environment_variables'])
      end

      def attribute_fail_fast(node)
        reader.boolean(node, ['fail_fast'])
      end

      def attribute_integration(node)
        name = reader.string(node, ['integration'])

        Integration.setup(config.kernel, name)
      rescue LoadError
        fail Error, "Could not load integration #{name.inspect} (you may want to try installing the gem mutant-#{name})"
      end

      def attribute_jobs(node)
        reader.integer(node, ['jobs'])
      end

      def attribute_matcher(node)
        reader.mapping(node, ['matcher'], MATCHER_KEYS).reduce(config.matcher) do |matcher, (key, value_node)|
          __send__(:"matcher_#{key}", matcher, value_node)
        end
      end

      def attribute_results_dir(node)
        reader.string(node, ['results_dir'])
      end

      def attribute_requires(node)
        reader.string_list(node, ['requires'])
      end

      def matcher_ignore(matcher, node)
        reader.string_list(node, ['matcher', 'ignore']).reduce(matcher) do |current, pattern|
          current.add(
            :subject_filters,
            Matcher::SourcePathFilter.new(
              pathname: config.pathname,
              pattern:  pattern,
              root:     config.pathname.pwd
            )
          )
        end
      end

      def matcher_subjects(matcher, node)
        reader.string_list(node, ['matcher', 'subjects']).reduce(matcher) do |current, expression|
          current.add(:match_expressions, config.expression_parser.(expression))
        end
      end
    end
  end
end
