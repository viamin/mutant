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
        include Concord.new(:output, :data)

        RAN_AT_FORMAT = '%Y-%m-%d %H:%M:%S UTC'

        def render
          print_metadata
          print_summary
          print_section(:alive_mutations, 'Alive mutations') do |mutation|
            render_alive(mutation)
          end
          print_section(:errored_mutations, 'Errored mutations') do |mutation|
            render_errored(mutation)
          end
        end

      private

        def print_metadata
          puts("  Ran at:  #{ran_at}")
          puts("  Git ref: #{value(:git_ref) || 'unknown'}")
        end

        def print_summary
          total = value(:total_mutations)
          return if total.nil?

          puts(
            "  Mutations: total=#{total} killed=#{value(:killed) || 0} " \
            "alive=#{value(:alive) || 0} errored=#{value(:errored) || 0}"
          )
        end

        def print_section(key, label)
          mutations = value(key)
          return unless mutations.is_a?(Array) && !mutations.empty?

          puts("  #{label} (#{mutations.size}):")
          mutations.each { |mutation| yield(mutation) }
        end

        def render_alive(mutation)
          subject = mutation.fetch('subject', '<unknown>')
          location = [mutation['subject_path'], mutation['source_line']].compact.join(':')
          label = location.empty? ? subject : "#{subject} (#{location})"

          puts("    #{label}")
          print_diff(mutation)
        end

        def print_diff(mutation)
          diff = mutation['mutation_diff']
          return unless diff

          diff.each_line { |line| puts("      #{line.chomp}") }
        end

        def render_errored(mutation)
          puts("    #{mutation.fetch('subject', '<unknown>')}")
          puts("      #{mutation.fetch('error', '<unknown>')}")
        end

        def ran_at
          timestamp = value(:ran_at)
          return 'unknown' unless timestamp

          timestamp.is_a?(Time) ? timestamp.utc.strftime(RAN_AT_FORMAT) : timestamp.to_s
        end

        def value(key)
          string_key = key.to_s

          return data[string_key] if data.key?(string_key)
          return data[key] if data.key?(key)

          nil
        end

        def puts(string)
          output.puts(string)
        end
      end
    end
  end
end
