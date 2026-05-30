# frozen_string_literal: true

module Mutant
  module Results
    class Document
      include Adamantium::Flat, Concord.new(:result, :git_ref, :ran_at), Procto.call(:to_h)

      class ErrorMessage
        include Adamantium::Flat, Concord.new(:isolation_result), Procto.call(:to_s)

        def to_s
          value = isolation_result.value

          if isolation_result.instance_of?(Mutant::Isolation::Result::ErrorChain)
            self.class.call(value)
          elsif value.is_a?(Exception)
            "#{value.class}: #{value.message}"
          else
            value.inspect
          end
        end
      end

      class MutationDiff
        include Adamantium::Flat, Concord.new(:mutation), Procto.call(:to_s)

        def to_s
          diff = Diff.build(mutation.original_source, mutation.source).diff
          return EMPTY_STRING unless diff

          lines = diff.each_line.reject { |line| /\A[-+]{3} /.match?(line) }.select { |line| /\A[+-]/.match?(line) }
          lines.join
        end
      end

      def to_h
        {
          'ran_at'            => ran_at,
          'git_ref'           => git_ref,
          'since'             => config.since,
          'total_mutations'   => result.amount_mutations,
          'killed'            => mutation_results.count(&:success?),
          'alive'             => alive_mutation_results.length,
          'errored'           => errored_mutation_results.length,
          'alive_mutations'   => alive_mutations,
          'errored_mutations' => errored_mutations
        }
      end

    private

      def alive_mutations
        alive_mutation_results.map do |mutation_result|
          mutation = mutation_result.mutation
          subject  = mutation.subject

          {
            'subject'       => subject.expression.syntax,
            'subject_path'  => subject_path(subject),
            'source_line'   => subject.source_line,
            'mutation_diff' => MutationDiff.call(mutation)
          }
        end
      end

      def errored_mutations
        errored_mutation_results.map do |mutation_result|
          {
            'subject' => mutation_result.mutation.subject.expression.syntax,
            'error'   => ErrorMessage.call(mutation_result.isolation_result)
          }
        end
      end

      def alive_mutation_results
        mutation_results.select do |mutation_result|
          mutation_result.isolation_result.success? && !mutation_result.success?
        end
      end
      memoize :alive_mutation_results

      def errored_mutation_results
        mutation_results.reject { |mutation_result| mutation_result.isolation_result.success? }
      end
      memoize :errored_mutation_results

      def mutation_results
        result.subject_results.flat_map(&:mutation_results)
      end
      memoize :mutation_results

      def subject_path(subject)
        path = subject.source_path
        path = path.relative_path_from(repo_root) if path.absolute?
        path.cleanpath.to_s
      end

      def config
        result.env.config
      end

      def repo_root
        stdout, status = config.open3.capture2('git', 'rev-parse', '--show-toplevel', binmode: true)
        repository_error('Command ["git", "rev-parse", "--show-toplevel"] failed!') unless status.success?

        config.pathname.new(stdout.chomp)
      end
      memoize :repo_root

      def repository_error(message)
        fail Repository::RepositoryError, message
      end
    end
  end
end
