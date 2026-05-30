# frozen_string_literal: true

Mutant::Meta::Example.add :numblock do
  source 'foo { _1 }'

  singleton_mutations
  mutation 'foo'
  mutation 'foo { }'
  mutation 'foo { nil }'
  mutation 'foo { self }'
  mutation 'foo { raise }'
end
