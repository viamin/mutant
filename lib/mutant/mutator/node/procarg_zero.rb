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
          return if argument.name.byteslice(0).eql?('_')

          emit_type(s(:arg, :"_#{argument}"))
        end

        def emit_argument_node_mutations
          emit_argument_mutations
          first = Mutant::Util.one(argument.children)
          emit_type(first) if first.is_a?(::Parser::AST::Node)
        end
      end
    end
  end
end # Mutant
