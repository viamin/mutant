# frozen_string_literal: true

module Mutant
  class Mutator
    class Node
      class ProcargZero < self

        handle :procarg0

        children :argument

      private

        def dispatch
          case argument
          when ::Parser::AST::Node
            emit_argument_node_mutations
          when Symbol
            emit_argument_symbol_mutations
          end
        end

        def emit_argument_symbol_mutations
          emit_type(s(:arg, :"_#{argument}")) unless argument.to_s.start_with?('_')
        end

        def emit_argument_node_mutations
          emit_argument_mutations
          first = Mutant::Util.one(argument.children)
          emit_type(first)
        end
      end
    end
  end
end # Mutant
