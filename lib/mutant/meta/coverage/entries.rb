# frozen_string_literal: true

module Mutant
  module Meta
    class Coverage
      Entry = Struct.new(
        :id, :title, :status, :source, :mutation, :assertion, :notes,
        keyword_init: true
      )

      COVERAGE_TABLE_HEADER = [
        '| Category | Status | Smoke fixture | Notes |',
        '| --- | --- | --- | --- |'
      ].freeze

      COVERAGE_ENTRIES = [
        Entry.new(
          id: 'pattern-matching', title: 'Pattern matching', status: 'gap',
          source: "case value\nin { foo: }\n  foo\nelse\n  nil\nend",
          mutation: nil, assertion: :generic,
          notes: 'Pattern-matching parser nodes are still routed through ' \
                 '`Mutant::Mutator::Node::Generic`; dedicated `case/in`, ' \
                 'guard, pin, array-pattern, and hash-pattern operators are not shipped yet.'
        ),
        Entry.new(
          id: 'compound-assignment', title: 'Compound assignment', status: 'covered',
          source: 'a ||= 1', mutation: 'a ||= nil', assertion: :include,
          notes: 'Dedicated mutators cover `or_asgn`, `and_asgn`, and `op_asgn` nodes.'
        ),
        Entry.new(
          id: 'enumerable-selectors', title: 'Enumerable selectors', status: 'partial',
          source: 'map', mutation: 'each', assertion: :include,
          notes: 'Selector replacement covers pairs such as `map` -> `each`, ' \
                 '`flat_map` -> `map`, `sample` -> `first/last`, and `first` <-> `last`, ' \
                 'but the modern selector set in the issue is not complete yet.'
        ),
        Entry.new(
          id: 'bang-reductions', title: 'Bang reductions', status: 'gap',
          source: 'array.map!(&:to_s)', mutation: 'array.map(&:to_s)', assertion: :exclude,
          notes: 'No dedicated bang-to-non-bang reduction operator is shipped for ' \
                 '`map!`, `compact!`, `sort!`, `uniq!`, and similar selectors.'
        ),
        Entry.new(
          id: 'boolean-control-flow', title: 'Boolean / control flow', status: 'covered',
          source: 'unless condition; true; end', mutation: 'if condition; true; end',
          assertion: :include,
          notes: 'Current coverage includes branch promotion, condition negation, ' \
                 '`unless` removal, and loop-body reductions for `if`, `while`, and `until`.'
        ),
        Entry.new(
          id: 'rescue-ensure', title: 'Rescue / ensure', status: 'covered',
          source: 'begin; rescue SomeException => error; true; end',
          mutation: 'begin; true; end', assertion: :include,
          notes: 'Current mutators can drop rescue handling and mutate rescue and ensure bodies.'
        ),
        Entry.new(
          id: 'empty-collection-returns', title: 'Empty-collection returns', status: 'gap',
          source: 'return value', mutation: 'return []', assertion: :exclude,
          notes: 'Mutant emits `[]` and `{}` in literal and assignment contexts, but it does ' \
                 'not ship a dedicated return-value operator that probes empty collection ' \
                 'assumptions across method exits.'
        ),
        Entry.new(
          id: 'bitwise-operators', title: 'Bitwise operators', status: 'gap',
          source: 'true & false', mutation: 'true | false', assertion: :exclude,
          notes: 'Bitwise sends are exercised as generic binary operators, but operator swaps ' \
                 'such as `&` <-> `|`, `^`, `<<`, and `>>` are not currently emitted.'
        ),
        Entry.new(
          id: 'integer-literal-boundary', title: 'Integer literal boundary', status: 'partial',
          source: '10', mutation: '11', assertion: :include,
          notes: 'Integer literals already cover `0`, `1`, negation, and `+/-1` boundaries, ' \
                 'but the broader category in the issue also mentions infinity-style ' \
                 'substitutions that are only present for floats today.'
        ),
        Entry.new(
          id: 'string-symbol-literal', title: 'String/symbol literal', status: 'partial',
          source: ':foo', mutation: ':foo__mutant__', assertion: :include,
          notes: 'Symbol literals already mutate to a sentinel suffix, but string literals ' \
                 'still only use singleton reductions and do not yet cover empty-string ' \
                 'or case-flip operators.'
        )
      ].freeze
    end
  end
end
