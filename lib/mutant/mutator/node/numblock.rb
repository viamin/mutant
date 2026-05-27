# frozen_string_literal: true

module Mutant
  class Mutator
    class Node
      class Numblock < Block

        handle(:numblock)

        children :send, :arity, :body

      private

        def dispatch
          emit_singletons
          emit(send) unless n_lambda?(send)
          emit_send_mutations(&method(:valid_send_mutation?))

          mutate_body
        end

        def mutate_body
          emit_body(nil)
          emit_body(N_RAISE)

          return unless body
          emit(body) unless body_has_control? || numbered_parameter_used?(body)
          emit_body_mutations

          mutate_body_receiver
        end

        def emit_type(*children)
          send_node, arity, body_node = children

          if numbered_parameter_used?(body_node)
            emit(::Parser::AST::Node.new(:numblock, [send_node, arity, body_node]))
          else
            emit(::Parser::AST::Node.new(:block, [send_node, s(:args), body_node]))
          end
        end

        def numbered_parameter_used?(candidate)
          return false unless candidate.is_a?(::Parser::AST::Node)
          return true if numbered_parameter?(candidate)

          candidate.children.any?(&method(:numbered_parameter_used?))
        end

        def numbered_parameter?(candidate)
          return false unless candidate.is_a?(::Parser::AST::Node) && n_lvar?(candidate)

          name, = candidate.children

          name.to_s.match?(/\A_\d+\z/)
        end
      end # Numblock
    end # Node
  end # Mutator
end # Mutant
