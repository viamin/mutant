# frozen_string_literal: true

Mutant::Meta::Example.add :hash_pattern do
  source(
    s(:hash_pattern,
      s(:pair, s(:sym, :foo), s(:match_var, :bar)),
      s(:match_var, :baz))
  )

  mutation(
    s(:hash_pattern,
      s(:match_var, :baz))
  )

  mutation(
    s(:hash_pattern,
      s(:pair, s(:sym, :foo), s(:match_var, :bar)))
  )
end
