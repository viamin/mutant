# frozen_string_literal: true

module Mutant
  class Mutator
    class Node

      class Dsym < Generic

        handle(:dsym)

      private

        def dispatch
          children.each_with_index do |child, index|
            mutate_child(index) if child.instance_of?(::Parser::AST::Node)
          end
          emit_singletons
        end

        def emit_child_update(index, node)
          wrapped = case node.type
                    when :str, :begin
                      node
                    else
                      s(:begin, node)
                    end
          super(index, wrapped)
        end
      end
    end
  end
end # Mutant
