# frozen_string_literal: true

module Mutant
  class Mutator

    module ScopeDetection
    private

      def local_variable_used_in_scope?(name)
        local_variable_used_in_node?(scope_body_node, name)
      end

      def scope_body_node
        scope_owner_node&.children&.last
      end

      def local_variable_used_in_node?(candidate, name)
        return false unless candidate.is_a?(::Parser::AST::Node)
        return false if scope_shadows_name?(candidate, name)
        return true if n_lvar?(candidate) && candidate.children.eql?([name])

        candidate.children.any? { |child| local_variable_used_in_node?(child, name) }
      end

      def scope_shadows_name?(node, name)
        case node.type
        when :block, :def
          scope_argument_names(node.children[1]).include?(name)
        when :defs
          scope_argument_names(node.children[2]).include?(name)
        when :numblock
          name_str = name.to_s
          arity = node.children[1]
          name_str.match?(/\A_\d+\z/) && name_str[1..].to_i <= arity
        else
          false
        end
      end

      def scope_argument_names(args_node)
        return [] unless args_node.is_a?(::Parser::AST::Node) && n_args?(args_node)

        args_node.children.filter_map { |arg| extract_argument_name(arg) }
      end

      def extract_argument_name(node)
        return unless node.is_a?(::Parser::AST::Node)

        case node.type
        when :procarg0
          extract_argument_name(node.children.first)
        when :arg, :optarg, :kwarg, :kwoptarg, :restarg, :kwrestarg, :blockarg
          node.children.first
        end
      end

      def scope_owner_node
        current = self

        until current.nil?
          candidate = current.node
          return candidate if %i[block numblock def defs].include?(candidate.type)

          current = current.parent
        end
      end
    end
  end
end
