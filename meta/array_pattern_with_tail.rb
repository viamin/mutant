# frozen_string_literal: true

Mutant::Meta::Example.add :array_pattern_with_tail do
  source(
    s(:array_pattern_with_tail,
      s(:match_var, :foo),
      s(:match_var, :bar))
  )

  mutation(
    s(:array_pattern,
      s(:match_var, :foo),
      s(:match_var, :bar))
  )

  mutation(
    s(:array_pattern,
      s(:match_var, :bar))
  )

  mutation(
    s(:array_pattern,
      s(:match_var, :foo))
  )
end
