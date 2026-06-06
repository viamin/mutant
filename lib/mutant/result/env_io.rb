# frozen_string_literal: true

module Mutant
  module Result
    class Env
      class IO
        include Concord.new(:env_result)

        def call
          ref = git_ref
          ts  = Time.now.utc
          dir = results_dir
          dir.mkpath
          dir.join("#{ts.strftime('%Y%m%dT%H%M%SZ')}-#{ref[0, 7]}.yml")
             .write(YAML.dump(build_hash(ref, ts)))
        end

      private

        def build_hash(ref, ts)
          mutation_results = all_mutation_results
          killed  = killed_results(mutation_results)
          alive   = alive_results(mutation_results)
          errored = errored_results(mutation_results)

          {
            'ran_at'            => ts,
            'git_ref'           => ref,
            'since'             => config.since_revision,
            'total_mutations'   => mutation_results.length,
            'killed'            => killed.length,
            'alive'             => alive.length,
            'errored'           => errored.length,
            'alive_mutations'   => alive.map(&method(:serialize_alive)),
            'errored_mutations' => errored.map(&method(:serialize_errored))
          }
        end

        def config
          env_result.env.config
        end

        def git_ref
          stdout, status = config.open3.capture2('git', 'rev-parse', 'HEAD', binmode: true)
          return stdout.strip if status.success?

          'unknown'
        end

        def results_dir
          config.results_dir
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
