# frozen_string_literal: true

Mutant::Meta::Example.add :case_match do
  source(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      nil)
  )

  singleton_mutations

  mutation(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      nil)
  )

  mutation(
    s(:case_match,
      s(:self),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      nil)
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, s(:send, nil, :raise)),
      nil)
  )
end

Mutant::Meta::Example.add :case_match do
  source(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:send, nil, :e))
  )

  singleton_mutations

  mutation(
    s(:case_match,
      s(:nil),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:send, nil, :e))
  )

  mutation(
    s(:case_match,
      s(:self),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:send, nil, :e))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:send, nil, :e))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, s(:send, nil, :raise)),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:send, nil, :e))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, s(:send, nil, :raise)),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:send, nil, :e))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, s(:send, nil, :raise)),
      s(:send, nil, :e))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:nil))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:self))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      nil)
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :bar), nil, nil),
      s(:send, nil, :e))
  )

  mutation(
    s(:case_match,
      s(:send, nil, :x),
      s(:in_pattern, s(:match_var, :foo), nil, nil),
      s(:in_pattern, s(:match_var, :baz), nil, nil),
      s(:send, nil, :e))
  )
end
