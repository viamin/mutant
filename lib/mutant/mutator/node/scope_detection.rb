# frozen_string_literal: true

module Mutant
  class Mutator

    module ScopeDetection
      LOCAL_VARIABLE_USAGE_CACHE = ObjectSpace::WeakMap.new

    private

      def local_variable_used_in_scope?(name)
        ScopeDetection.scope_nodes_for_local_variable_lookup(scope_owner_node).any? do |node|
          local_variable_used_in_node?(node, name)
        end
      end

      def local_variable_used_in_node?(candidate, name)
        local_variable_usage_cache.fetch([candidate, name]) do
          local_variable_usage_cache[[candidate, name]] = local_variable_used_in_node_uncached?(candidate, name)
        end
      end

      def local_variable_used_in_node_uncached?(candidate, name)
        return false unless candidate.is_a?(::Parser::AST::Node)
        return true if n_lvar?(candidate) && candidate.children.eql?([name])

        visible_children_for_local_variable_lookup(candidate, name).any? do |child|
          local_variable_used_in_node?(child, name)
        end
      end

      def local_variable_usage_cache
        LOCAL_VARIABLE_USAGE_CACHE[self] ||= {}
      end

      def self.scope_nodes_for_local_variable_lookup(node)
        return [] unless node.is_a?(::Parser::AST::Node)

        case node.type
        when :block
          [node.children[1], node.children[2]]
        when :numblock
          [node.children[2]]
        when :def
          [node.children[1], node.children[2]]
        when :defs
          [node.children[2], node.children[3]]
        else
          []
        end.compact
      end

      def visible_children_for_local_variable_lookup(node, name)
        return [] if hard_scope_boundary?(node)
        return node.children unless %i[block numblock].include?(node.type)
        return [node.children.first] if scope_shadows_name?(node, name)

        node.type.equal?(:block) ? node.children : [node.children[0], node.children[2]]
      end

      def hard_scope_boundary?(node)
        n_def?(node) || n_defs?(node)
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

        args_node.children.flat_map { |arg| extract_argument_names(arg) }
      end

      def extract_argument_names(node)
        return [] unless node.is_a?(::Parser::AST::Node)

        case node.type
        when :procarg0
          extract_argument_names(node.children.first)
        when :mlhs
          node.children.flat_map { |child| extract_argument_names(child) }
        when :arg, :optarg, :kwarg, :kwoptarg, :restarg, :kwrestarg, :blockarg
          [node.children.first]
        else
          []
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
