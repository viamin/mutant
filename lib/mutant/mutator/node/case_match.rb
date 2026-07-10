# frozen_string_literal: true

module Mutant
  class Mutator
    class Node

      # Mutator for case-match nodes
      class CaseMatch < self

        handle(:case_match)

        children :condition

      private

        def dispatch
          emit_singletons
          emit_condition_mutations
          emit_in_pattern_mutations
          emit_else_mutations
        end

        def emit_in_pattern_mutations
          indices = children.each_index.drop(1).take(children.length - 2)
          one = indices.one?

          indices.each do |index|
            mutate_child(index)
            delete_child(index) unless one
          end
        end

        def emit_else_mutations
          else_index = children.length - 1
          mutate_child(else_index)
          emit_child_update(else_index, nil)
        end

      end # CaseMatch
    end # Node
  end # Mutator
end # Mutant
