# frozen_string_literal: true

module Mutant
  module Result
    class Env
      class IO
        include Concord.new(:env_result)

        def call
          config.pathname.new(results_dir.to_s).mkpath
          config.pathname.new(results_dir.to_s).join(filename).write(YAML.dump(to_h))
        end

      private

        def config
          env_result.env.config
        end

        def filename
          "#{timestamp}-#{git_ref}.yml"
        end

        def git_ref
          stdout, status = config.open3.capture2('git', 'rev-parse', 'HEAD', binmode: true)
          return stdout.strip[0, 7] if status.success?

          'unknown'
        end

        def results_dir
          config.results_dir
        end

        def timestamp
          Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        end

        def to_h
          mutation_results = all_mutation_results

          {
            'ran_at'            => Time.now.utc,
            'git_ref'           => git_ref,
            'since'             => config.since_revision,
            'total_mutations'   => mutation_results.length,
            'killed'            => killed_results(mutation_results).length,
            'alive'             => alive_results(mutation_results).length,
            'errored'           => errored_results(mutation_results).length,
            'alive_mutations'   => alive_results(mutation_results).map(&method(:serialize_alive)),
            'errored_mutations' => errored_results(mutation_results).map(&method(:serialize_errored))
          }
        end

        def all_mutation_results
          env_result.subject_results.flat_map(&:mutation_results)
        end

        def alive_results(mutation_results)
          mutation_results.select { |r| !r.success? && r.isolation_result.success? }
        end

        def killed_results(mutation_results)
          mutation_results.select(&:success?)
        end

        def errored_results(mutation_results)
          mutation_results.select { |r| !r.success? && !r.isolation_result.success? }
        end

        def serialize_alive(mutation_result)
          mutation = mutation_result.mutation
          subject  = mutation.subject
          diff     = Mutant::Diff.build(subject.source, mutation.source)

          {
            'subject'       => subject.identification,
            'subject_path'  => subject.source_path.to_s,
            'source_line'   => subject.source_line,
            'mutation_diff' => diff.diff || ''
          }
        end

        def serialize_errored(mutation_result)
          {
            'subject' => mutation_result.mutation.subject.identification,
            'error'   => format_error(mutation_result.isolation_result.value)
          }
        end

        def format_error(exception)
          case exception
          when Mutant::Isolation::Result::SerializedException
            "#{exception.exception_class_name}: #{exception.inspection}"
          else
            exception.inspect
          end
        end

      end
    end
  end
end
