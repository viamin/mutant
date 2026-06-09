# frozen_string_literal: true

module Mutant
  module Result
    class Env
      class IO
        include Concord.new(:env_result)

        def call
          ref = git_ref
          ts  = Time.now.utc
          dir = config.results_dir
          dir.mkpath
          dir.join("#{ts.strftime('%Y%m%dT%H%M%SZ')}-#{ref[0, 7]}.yml")
             .write(YAML.dump(build_hash(ref, ts)))
        end

      private

        def classify_mutations
          mutation_results = all_mutation_results
          killed, rest = mutation_results.partition(&:success?)
          alive, errored = rest.partition { |result| result.isolation_result.success? }
          [killed, alive, errored]
        end

        def build_hash(ref, ts)
          killed, alive, errored = classify_mutations

          {
            'ran_at'            => ts,
            'git_ref'           => ref,
            'since'             => config.since_revision,
            'total_mutations'   => killed.length + alive.length + errored.length,
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

        def all_mutation_results
          env_result.subject_results.flat_map(&:mutation_results)
        end

        def serialize_alive(mutation_result)
          mutation = mutation_result.mutation
          subject  = mutation.subject
          diff     = Diff.build(subject.source, mutation.source)

          {
            'subject'       => subject.identification,
            'subject_path'  => subject.source_path.to_s,
            'source_line'   => subject.source_line,
            'mutation_diff' => diff.diff || ''
          }
        end

        def serialize_errored(mutation_result)
          isolation = mutation_result.isolation_result
          {
            'subject' => mutation_result.mutation.subject.identification,
            'error'   => isolation_error(isolation)
          }
        end

        def isolation_error(isolation)
          if isolation.is_a?(Isolation::Fork::ForkError)
            isolation.class.name
          else
            format_error(isolation.value)
          end
        end

        def format_error(exception)
          case exception
          when Isolation::Result::SerializedException
            "#{exception.exception_class_name}: #{exception.inspection}"
          else
            exception.inspect
          end
        end

      end
    end
  end
end
