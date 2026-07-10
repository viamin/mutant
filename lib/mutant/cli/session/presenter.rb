# frozen_string_literal: true

module Mutant
  class CLI
    module Session
      # Renders the enriched `mutant session show <id>` payload
      #
      # Surfaces data already present in the `.mutant/results/*.yml` files:
      # metadata (ran_at, git_ref), summary mutation counts, and the full
      # alive and errored mutation details (including diffs and errors).
      class Presenter
        include Concord.new(:data)

        RAN_AT_FORMAT = '%Y-%m-%d %H:%M:%S UTC'

        def render(out)
          render_metadata(out)
          render_summary(out)
          render_alive(out)
          render_errored(out)
        end

      private

        def render_metadata(out)
          out.puts("  Ran at:  #{ran_at}")
          out.puts("  Git ref: #{value(:git_ref) || 'unknown'}")
        end

        def render_summary(out)
          total = value(:total_mutations)
          return unless total

          out.puts(summary_line(total))
        end

        def summary_line(total)
          killed  = value(:killed)  || 0
          alive   = value(:alive)   || 0
          errored = value(:errored) || 0

          "  Mutations: total=#{total} killed=#{killed} alive=#{alive} errored=#{errored}"
        end

        def render_alive(out)
          mutations = list(:alive_mutations)
          return if mutations.empty?

          out.puts("  Alive mutations (#{mutations.size}):")
          mutations.each do |mutation|
            out.puts("    #{alive_label(mutation)}")
            value_of(mutation, :mutation_diff).to_s.each_line do |line|
              out.puts("      #{line.chomp}")
            end
          end
        end

        def render_errored(out)
          mutations = list(:errored_mutations)
          return if mutations.empty?

          out.puts("  Errored mutations (#{mutations.size}):")
          mutations.each do |mutation|
            out.puts("    #{value_of(mutation, :subject) || '<unknown>'}")
            out.puts("      #{value_of(mutation, :error) || '<unknown>'}")
          end
        end

        def alive_label(mutation)
          subject  = value_of(mutation, :subject) || '<unknown>'
          path     = value_of(mutation, :subject_path)
          line     = value_of(mutation, :source_line)
          location = [path, line].compact.join(':')

          location.empty? ? subject : "#{subject} (#{location})"
        end

        def ran_at
          timestamp = value(:ran_at)
          return 'unknown' unless timestamp

          timestamp.is_a?(Time) ? timestamp.utc.strftime(RAN_AT_FORMAT) : timestamp.to_s
        end

        def list(key)
          mutations = value(key)
          mutations.is_a?(Array) ? mutations : EMPTY_ARRAY
        end

        def value(key)
          string_key = key.to_s

          return data[string_key] if data.key?(string_key)
          return data[key] if data.key?(key)

          nil
        end

        def value_of(entry, key)
          return unless entry.is_a?(Hash)

          string_key = key.to_s

          return entry[string_key] if entry.key?(string_key)
          return entry[key] if entry.key?(key)

          nil
        end
      end
    end
  end
end
