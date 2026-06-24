# frozen_string_literal: true

module Mutant
  class Mutator
    class Node
      class Literal
        # Mutator for hash literals
        class Hash < self

          handle(:hash)

        private

          # Emit mutations
          #
          # @return [undefined]
          def dispatch
            emit_singletons
            emit_type
            mutate_body
          end

          # Mutate body
          #
          # @return [undefined]
          def mutate_body
            children.each_index do |index|
              mutate_child(index)
              dup_children = children.dup
              dup_children.delete_at(index)
              emit_type(*dup_children)
            end
          end

          # Mutator for hash pairs
          class Pair < Node

            handle(:pair)

            children :key, :value

            KEY_MUTATION_CONSTRAINTS = Set.new(%i[hash_pattern kwargs]).freeze

          private

            # Emit mutations
            #
            # @return [undefined]
            def dispatch
              emit_key_mutations unless constrained_key_mutations?
              emit_value_mutations
            end

            def constrained_key_mutations?
              KEY_MUTATION_CONSTRAINTS.include?(parent_type)
            end

          end # Pair
        end # Hash
      end # Literal
    end # Node
  end # Mutator
end # Mutant
