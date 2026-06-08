# Mutator Coverage

This page tracks the requested modern-Ruby mutator categories against
the currently shipped operator set.

Status values:

* `covered` means the repository already ships a representative operator for the category.
* `partial` means related operators exist, but the category in the meta-issue is only partly covered.
* `gap` means the category still needs a dedicated operator issue or an
  explicit decision not to implement it.

| Category | Status | Smoke fixture | Notes |
| --- | --- | --- | --- |
| Pattern matching | `gap` | `"case value\nin { foo: }\n  foo\nelse\n  nil\nend"` | Pattern-matching parser nodes are still routed through `Mutant::Mutator::Node::Generic`; dedicated `case/in`, guard, pin, array-pattern, and hash-pattern operators are not shipped yet. |
| Compound assignment | `covered` | `"a \|\|= 1" -> a \|\|= nil` | Dedicated mutators cover `or_asgn`, `and_asgn`, and `op_asgn` nodes. |
| Enumerable selectors | `partial` | `"map" -> each` | Selector replacement covers pairs such as `map` -> `each`, `flat_map` -> `map`, `sample` -> `first/last`, and `first` <-> `last`, but the modern selector set in the issue is not complete yet. |
| Bang reductions | `gap` | `"array.map!(&:to_s)" -> array.map(&:to_s)` | No dedicated bang-to-non-bang reduction operator is shipped for `map!`, `compact!`, `sort!`, `uniq!`, and similar selectors. |
| Boolean / control flow | `covered` | `"unless condition; true; end" -> if condition; true; end` | Current coverage includes branch promotion, condition negation, `unless` removal, and loop-body reductions for `if`, `while`, and `until`. |
| Rescue / ensure | `covered` | `"begin; rescue SomeException => error; true; end" -> begin; true; end` | Current mutators can drop rescue handling and mutate rescue and ensure bodies. |
| Empty-collection returns | `gap` | `"return value" -> return []` | Mutant emits `[]` and `{}` in literal and assignment contexts, but it does not ship a dedicated return-value operator that probes empty collection assumptions across method exits. |
| Bitwise operators | `gap` | `"true & false" -> true \| false` | Bitwise sends are exercised as generic binary operators, but operator swaps such as `&` <-> `\|`, `^`, `<<`, and `>>` are not currently emitted. |
| Integer literal boundary | `partial` | `"10" -> 11` | Integer literals already cover `0`, `1`, negation, and `+/-1` boundaries, but the broader category in the issue also mentions infinity-style substitutions that are only present for floats today. |
| String/symbol literal | `partial` | `":foo" -> :foo__mutant__` | Symbol literals already mutate to a sentinel suffix, but string literals still only use singleton reductions and do not yet cover empty-string or case-flip operators. |
