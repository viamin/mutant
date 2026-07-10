# frozen_string_literal: true

module Mutant
  class Mutator
    class Node

      # Mutator for array-pattern nodes
      class ArrayPattern < self

        handle(:array_pattern)

      private

        def dispatch
          children.each_index do |index|
            mutate_child(index)
            delete_child(index)
          end
        end

      end # ArrayPattern
    end # Node
  end # Mutator
end # Mutant
