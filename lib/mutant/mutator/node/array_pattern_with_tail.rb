# frozen_string_literal: true

module Mutant
  class Mutator
    class Node

      # Mutator for exact array-pattern nodes with trailing comma syntax
      class ArrayPatternWithTail < self

        handle(:array_pattern_with_tail)

      private

        def dispatch
          emit_array_pattern(*children)

          children.each_index do |index|
            mutate_child(index)
            emit_array_pattern(*children.dup.tap { |copy| copy.delete_at(index) })
          end
        end

        def emit_array_pattern(*children)
          emit(::Parser::AST::Node.new(:array_pattern, children))
        end

      end # ArrayPatternWithTail
    end # Node
  end # Mutator
end # Mutant
