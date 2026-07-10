# frozen_string_literal: true

Mutant::Meta::Example.add :case_match do
  source(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:nil))
  )

  singleton_mutations

  mutation(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :foo), nil, s(:send, nil, :raise)),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:nil))
  )

  mutation(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:nil))
  )

  mutation(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, s(:send, nil, :raise)),
      s(:nil))
  )

  mutation(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:nil))
  )

  mutation(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      nil)
  )
end
