# frozen_string_literal: true

module Mutant
  class Mutator
    class Node

      # Mutator for begin nodes
      class Begin < self

        handle(:begin)

      private

        # Emit mutations
        #
        # @return [undefined]
        def dispatch
          if children.one?
            mutate_single_child do |child|
              emit(child)
            end
          else
            children.each_with_index do |child, index|
              mutate_child(index) if child.instance_of?(::Parser::AST::Node)
            end
          end
        end
      end # Begin
    end # Node
  end # Mutator
end # Mutant
