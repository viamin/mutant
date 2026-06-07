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
          children.each_with_index do |child, index|
            mutate_child(index) if child.is_a?(::Parser::AST::Node)
          end
        end
      end # Begin
    end # Node
  end # Mutator
end # Mutant
