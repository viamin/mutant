# frozen_string_literal: true

Mutant::Meta::Example.add :array_pattern do
  source(
    s(:array_pattern,
      s(:match_var, :head),
      s(:match_rest, s(:match_var, :rest)),
      s(:match_var, :tail))
  )

  mutation(
    s(:array_pattern,
      s(:match_rest, s(:match_var, :rest)),
      s(:match_var, :tail))
  )

  mutation(
    s(:array_pattern,
      s(:match_var, :head),
      s(:match_var, :tail))
  )

  mutation(
    s(:array_pattern,
      s(:match_var, :head),
      s(:match_rest, s(:match_var, :rest)))
  )
end
