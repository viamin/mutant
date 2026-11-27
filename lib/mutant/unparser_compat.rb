# frozen_string_literal: true

module Mutant
  module UnparserCompat
    module Builder
      def string_value(token)
        return super if token.fetch(0).valid_encoding?

        super([token.fetch(0).dup.force_encoding(Encoding::BINARY), token.fetch(1)])
      end
    end
  end
end

Unparser.const_get(:Builder).prepend(Mutant::UnparserCompat::Builder)
