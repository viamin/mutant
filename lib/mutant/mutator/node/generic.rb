# frozen_string_literal: true

module Mutant
  class Mutator
    class Node

      # Generic mutator
      class Generic < self

        unsupported_nodes = %i[
          ensure
          redo
          retry
          arg_expr
          blockarg
          kwrestarg
          undef
          module
          empty
          alias
          for
          xstr
          back_ref
          restarg
          sclass
          match_with_lvasgn
          while_post
          until_post
          preexe
          postexe
          iflipflop
          eflipflop
          kwsplat
          shadowarg
          rational
          complex
          array_pattern
          array_pattern_with_tail
          __FILE__
          __LINE__
          blockarg_expr
          blocknilarg
          case_match
          const_pattern
          empty_else
          find_pattern
          forward_arg
          forward_args
          forwarded_args
          forwarded_kwrestarg
          forwarded_restarg
          hash_pattern
          ident
          if_guard
          in_match
          in_pattern
          itarg
          itblock
          kwargs
          match_alt
          match_as
          match_nil_pattern
          match_pattern
          match_pattern_p
          match_rest
          match_var
          match_with_trailing_comma
          numargs
          objc_kwarg
          objc_restarg
          objc_varargs
          pin
          restarg_expr
          unless_guard
        ]

        unsupported_regexp_nodes = AST::Types::REGEXP.to_a - %i[
          regexp_alternation_meta
          regexp_bol_anchor
          regexp_capture_group
          regexp_digit_type
          regexp_eol_anchor
          regexp_eos_ob_eol_anchor
          regexp_greedy_zero_or_more
          regexp_hex_type
          regexp_linebreak_type
          regexp_nondigit_type
          regexp_nonhex_type
          regexp_nonspace_type
          regexp_nonword_boundary_anchor
          regexp_nonword_type
          regexp_root_expression
          regexp_space_type
          regexp_word_boundary_anchor
          regexp_word_type
          regexp_xgrapheme_type
        ]

        # These nodes still need a dedicated mutator,
        # your contribution is that close!
        handle(*(unsupported_nodes + unsupported_regexp_nodes))

      private

        # Emit mutations
        #
        # @return [undefined]
        def dispatch
          children.each_with_index do |child, index|
            mutate_child(index) if child.instance_of?(::Parser::AST::Node)
          end
        end

      end # Generic
    end # Node
  end # Mutator
end # Mutant
