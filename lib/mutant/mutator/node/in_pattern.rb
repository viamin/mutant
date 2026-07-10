# frozen_string_literal: true

module Mutant
  class Mutator
    class Node

      # Mutator for in-pattern nodes
      class InPattern < self

        handle(:in_pattern)

        children :match_pattern

      private

        def dispatch
          emit_match_pattern_mutations
          mutate_branch_guard
          mutate_branch_body
        end

        def mutate_branch_guard
          emit_child_update(1, nil)
          mutate_child(1)
        end

        def mutate_branch_body
          if branch_body
            mutate_child(2)
          else
            emit_child_update(2, N_RAISE)
          end
        end

        def branch_body
          children.fetch(2)
        end

      end # InPattern
    end # Node
  end # Mutator
end # Mutant
