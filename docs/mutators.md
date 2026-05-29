# Mutators

This page summarizes the currently shipped mutator families.

It is intentionally concise: each section shows the first `meta/` example for a given operator family and one representative diff. The `meta/` fixtures remain the exhaustive behavioral specification that the test suite verifies.

## special forms

Representative source from `meta/file.rb:3`:

```ruby
__FILE__
```

Representative diff:

```diff
@@ -1 +0,0 @@
-__FILE__

```

## and

Representative source from `meta/and.rb:3`:

```ruby
true && false
```

Representative diff:

```diff
@@ -1 +1 @@
-true && false
+true

```

## and_asgn

Representative source from `meta/and_asgn.rb:3`:

```ruby
a &&= 1
```

Representative diff:

```diff
@@ -1 +1 @@
-a &&= 1
+a__mutant__ &&= 1

```

## array

Representative source from `meta/array.rb:3`:

```ruby
[true]
```

Representative diff:

```diff
@@ -1 +1 @@
-[true]
+true

```

## array / lvasgn

Representative source from `meta/lvasgn.rb:12`:

```ruby
a = [*b]
```

Representative diff:

```diff
@@ -1 +1 @@
-a = [*b]
+a__mutant__ = [*b]

```

## begin

Representative source from `meta/begin.rb:3`:

```ruby
true
false

```

Representative diff:

```diff
@@ -1,2 +1,2 @@
 true
-false
+true

```

## block

Representative source from `meta/block.rb:3`:

```ruby
foo {
  a
  b
}
```

Representative diff:

```diff
@@ -1,4 +1,3 @@
 foo {
   a
-  b
 }

```

## block / lambda

Representative source from `meta/lambda.rb:3`:

```ruby
->() {
}
```

Representative diff:

```diff
@@ -1,2 +1,3 @@
 ->() {
+  raise
 }

```

## block_pass

Representative source from `meta/block_pass.rb:3`:

```ruby
foo(&bar)
```

Representative diff:

```diff
@@ -1 +1 @@
-foo(&bar)
+foo

```

## blockarg

Representative source from `meta/blockarg.rb:3`:

```ruby
foo { |&bar|
}
```

Representative diff:

```diff
@@ -1,2 +1,3 @@
 foo { |&bar|
+  raise
 }

```

## break

Representative source from `meta/break.rb:3`:

```ruby
break true
```

Representative diff:

```diff
@@ -1 +1 @@
-break true
+break false

```

## case

Representative source from `meta/case.rb:3`:

```ruby
case
when true
end
```

Representative diff:

```diff
@@ -1,3 +1,4 @@
 case
 when true
+  raise
 end

```

## casgn

Representative source from `meta/casgn.rb:3`:

```ruby
A = true
```

Representative diff:

```diff
@@ -1 +1 @@
-A = true
+A__MUTANT__ = true

```

## cbase

Representative source from `meta/cbase.rb:3`:

```ruby
::A
```

Representative diff:

```diff
@@ -1 +1 @@
-::A
+A

```

## class

Representative source from `meta/class.rb:3`:

```ruby
class Foo
  bar
end

```

Representative diff:

```diff
@@ -1,3 +1,3 @@
 class Foo
-  bar
+  nil
 end

```

## const

Representative source from `meta/const.rb:3`:

```ruby
A::B::C
```

Representative diff:

```diff
@@ -1 +1 @@
-A::B::C
+B::C

```

## csend

Representative source from `meta/csend.rb:3`:

```ruby
a&.b
```

Representative diff:

```diff
@@ -1 +1 @@
-a&.b
+a.b

```

## cvar

Representative source from `meta/cvar.rb:3`:

```ruby
@@a
```

Representative diff:

```diff
@@ -1 +1 @@
-@@a
+nil

```

## cvasgn

Representative source from `meta/cvasgn.rb:3`:

```ruby
@@a = true
```

Representative diff:

```diff
@@ -1 +1 @@
-@@a = true
+@@a__mutant__ = true

```

## def

Representative source from `meta/def.rb:3`:

```ruby
def foo
end
```

Representative diff:

```diff
@@ -1,2 +1,3 @@
 def foo
+  raise
 end

```

## defined?

Representative source from `meta/defined.rb:3`:

```ruby
defined?(foo)
```

Representative diff:

```diff
@@ -1 +1 @@
-defined?(foo)
+defined?(nil)

```

## dstr

Representative source from `meta/dstr.rb:3`:

```ruby
"foo#{bar}baz"
```

Representative diff:

```diff
@@ -1 +1 @@
-"foo#{bar}baz"
+"#{nil}#{bar}baz"

```

## dsym

Representative source from `meta/dsym.rb:3`:

```ruby
:"foo#{bar}baz"
```

Representative diff:

```diff
@@ -1 +1 @@
-:"foo#{bar}baz"
+:"#{nil}#{bar}baz"

```

## ensure

Representative source from `meta/ensure.rb:3`:

```ruby
begin
rescue
ensure
  true
end
```

Representative diff:

```diff
@@ -1,5 +1,5 @@
 begin
 rescue
 ensure
-  true
+  false
 end

```

## erange

Representative source from `meta/range.rb:22`:

```ruby
1...100
```

Representative diff:

```diff
@@ -1 +1 @@
-1...100
+1..100

```

## false

Representative source from `meta/false.rb:3`:

```ruby
false
```

Representative diff:

```diff
@@ -1 +1 @@
-false
+true

```

## float

Representative source from `meta/float.rb:3`:

```ruby
10.0
```

Representative diff:

```diff
@@ -1 +1 @@
-10.0
+0.0

```

## gvar

Representative source from `meta/gvar.rb:3`:

```ruby
$a
```

Representative diff:

```diff
@@ -1 +1 @@
-$a
+nil

```

## gvasgn

Representative source from `meta/gvasgn.rb:3`:

```ruby
$a = true
```

Representative diff:

```diff
@@ -1 +1 @@
-$a = true
+$a__mutant__ = true

```

## hash

Representative source from `meta/hash.rb:3`:

```ruby
{ true => true, false => false }
```

Representative diff:

```diff
@@ -1 +1 @@
-{ true => true, false => false }
+{ false => true, false => false }

```

## if

Representative source from `meta/if.rb:3`:

```ruby
if condition
  true
else
  false
end
```

Representative diff:

```diff
@@ -1,5 +1,5 @@
-if condition
+if !condition
   true
 else
   false
 end

```

## index

Representative source from `meta/index.rb:3`:

```ruby
self.foo[]
```

Representative diff:

```diff
@@ -1 +1 @@
-self.foo[]
+self.foo

```

## indexasgn

Representative source from `meta/indexasgn.rb:3`:

```ruby
foo[bar] = baz
```

Representative diff:

```diff
@@ -1 +1 @@
-foo[bar] = baz
+self[bar] = baz

```

## indexasgn / op_asgn

Representative source from `meta/indexasgn.rb:22`:

```ruby
self[foo] += bar
```

Representative diff:

```diff
@@ -1 +1 @@
-self[foo] += bar
+self[] += bar

```

## int

Representative source from `meta/int.rb:3`:

```ruby
10
```

Representative diff:

```diff
@@ -1 +1 @@
-10
+0

```

## irange

Representative source from `meta/range.rb:3`:

```ruby
1..100
```

Representative diff:

```diff
@@ -1 +1 @@
-1..100
+1...100

```

## ivar

Representative source from `meta/ivar.rb:3`:

```ruby
@foo
```

Representative diff:

```diff
@@ -1 +1 @@
-@foo
+foo

```

## ivasgn

Representative source from `meta/ivasgn.rb:3`:

```ruby
@a = true
```

Representative diff:

```diff
@@ -1 +1 @@
-@a = true
+@a__mutant__ = true

```

## kwarg

Representative source from `meta/kwarg.rb:3`:

```ruby
def foo(bar:)
end
```

Representative diff:

```diff
@@ -1,2 +1,2 @@
-def foo(bar:)
+def foo
 end

```

## kwbegin

Representative source from `meta/kwbegin.rb:3`:

```ruby
begin
  true
end
```

Representative diff:

```diff
@@ -1,3 +1,3 @@
 begin
-  true
+  false
 end

```

## lvar

Representative source from `meta/lvar.rb:3`:

```ruby
a = nil
a

```

Representative diff:

```diff
@@ -1,2 +1,2 @@
 a = nil
-a
+nil

```

## lvasgn

Representative source from `meta/lvasgn.rb:3`:

```ruby
a = true
```

Representative diff:

```diff
@@ -1 +1 @@
-a = true
+a__mutant__ = true

```

## masgn

Representative source from `meta/masgn.rb:3`:

```ruby
(a, b) = [c, d]
```

Representative diff:

```diff
@@ -1 +1 @@
-(a, b) = [c, d]
+nil

```

## match_current_line

Representative source from `meta/match_current_line.rb:3`:

```ruby
if /foo/
  true
end
```

Representative diff:

```diff
@@ -1,3 +1,3 @@
 if /foo/
-  true
+  false
 end

```

## next

Representative source from `meta/next.rb:3`:

```ruby
next true
```

Representative diff:

```diff
@@ -1 +1 @@
-next true
+next false

```

## nil

Representative source from `meta/nil.rb:3`:

```ruby
nil
```

Representative diff:

```diff
@@ -1 +0,0 @@
-nil

```

## nth_ref

Representative source from `meta/nthref.rb:3`:

```ruby
$1
```

Representative diff:

```diff
@@ -1 +1 @@
-$1
+$2

```

## numblock

Representative source from `meta/numblock.rb:3`:

```ruby
foo {
  _1
}
```

Representative diff:

```diff
@@ -1,3 +1 @@
-foo {
-  _1
-}
+foo

```

## op_asgn

Representative source from `meta/op_assgn.rb:3`:

```ruby
@a.b += 1
```

Representative diff:

```diff
@@ -1 +1 @@
-@a.b += 1
+a.b += 1

```

## or

Representative source from `meta/or.rb:3`:

```ruby
true || false
```

Representative diff:

```diff
@@ -1 +1 @@
-true || false
+true

```

## or_asgn

Representative source from `meta/or_asgn.rb:3`:

```ruby
a ||= 1
```

Representative diff:

```diff
@@ -1 +1 @@
-a ||= 1
+a__mutant__ ||= 1

```

## redo

Representative source from `meta/redo.rb:3`:

```ruby
redo
```

Representative diff:

```diff
@@ -1 +0,0 @@
-redo

```

## regexp

Representative source from `meta/regexp.rb:3`:

```ruby
/foo/
```

Representative diff:

```diff
@@ -1 +1 @@
-/foo/
+//

```

## regexp / regexp_digit_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\d/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\d/
+//

```

## regexp / regexp_hex_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\h/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\h/
+//

```

## regexp / regexp_linebreak_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\R/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\R/
+//

```

## regexp / regexp_nondigit_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\D/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\D/
+//

```

## regexp / regexp_nonhex_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\H/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\H/
+//

```

## regexp / regexp_nonspace_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\S/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\S/
+//

```

## regexp / regexp_nonword_boundary_anchor

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\B/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\B/
+//

```

## regexp / regexp_nonword_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\W/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\W/
+//

```

## regexp / regexp_space_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\s/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\s/
+//

```

## regexp / regexp_word_boundary_anchor

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\b/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\b/
+//

```

## regexp / regexp_word_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\w/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\w/
+//

```

## regexp / regexp_xgrapheme_type

Representative source from `meta/regexp/character_types.rb:15`:

```ruby
/\X/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\X/
+//

```

## regexp_alternation_meta

Representative source from `meta/regexp/regexp_alternation_meta.rb:3`:

```ruby
/\A(foo|bar|baz)\z/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\A(foo|bar|baz)\z/
+//

```

## regexp_bol_anchor

Representative source from `meta/regexp/regexp_bol_anchor.rb:3`:

```ruby
/^/
```

Representative diff:

```diff
@@ -1 +1 @@
-/^/
+//

```

## regexp_bos_anchor

Representative source from `meta/regexp/regexp_bos_anchor.rb:3`:

```ruby
/\A/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\A/
+//

```

## regexp_capture_group

Representative source from `meta/regexp/regexp_capture_group.rb:3`:

```ruby
/()/
```

Representative diff:

```diff
@@ -1 +1 @@
-/()/
+//

```

## regexp_eol_anchor

Representative source from `meta/regexp/regexp_eol_anchor.rb:3`:

```ruby
/$/
```

Representative diff:

```diff
@@ -1 +1 @@
-/$/
+//

```

## regexp_eos_anchor

Representative source from `meta/regexp/regexp_eos_anchor.rb:3`:

```ruby
/\z/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\z/
+//

```

## regexp_eos_ob_eol_anchor

Representative source from `meta/regexp/regexp_eos_ob_eol_anchor.rb:3`:

```ruby
/\Z/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\Z/
+//

```

## regexp_greedy_zero_or_more

Representative source from `meta/regexp/regexp_greedy_zero_or_more.rb:3`:

```ruby
/\d*/
```

Representative diff:

```diff
@@ -1 +1 @@
-/\d*/
+//

```

## regexp_root_expression

Representative source from `meta/regexp/regexp_root_expression.rb:3`:

```ruby
/^/
```

Representative diff:

```diff
@@ -1 +1 @@
-/^/
+//

```

## regopt

Representative source from `meta/regopt.rb:3`:

```ruby
/foo/imox
```

Representative diff:

```diff
@@ -1 +1 @@
-/foo/imox
+//imox

```

## rescue

Representative source from `meta/rescue.rb:3`:

```ruby
begin
rescue ExceptionA, ExceptionB => error
  true
end
```

Representative diff:

```diff
@@ -1,4 +1,4 @@
 begin
-rescue ExceptionA, ExceptionB => error
+rescue ExceptionA, ExceptionB
   true
 end

```

## restarg

Representative source from `meta/restarg.rb:3`:

```ruby
def foo(*bar)
end
```

Representative diff:

```diff
@@ -1,2 +1,2 @@
-def foo(*bar)
+def foo
 end

```

## return

Representative source from `meta/return.rb:3`:

```ruby
return
```

Representative diff:

```diff
@@ -1 +1 @@
-return
+nil

```

## self

Representative source from `meta/self.rb:3`:

```ruby
self
```

Representative diff:

```diff
@@ -1 +1 @@
-self
+nil

```

## send

Representative source from `meta/date.rb:3`:

```ruby
Date.parse(nil)
```

Representative diff:

```diff
@@ -1 +1 @@
-Date.parse(nil)
+Date.parse

```

## str

Representative source from `meta/str.rb:3`:

```ruby
"foo"
```

Representative diff:

```diff
@@ -1 +1 @@
-"foo"
+nil

```

## super

Representative source from `meta/super.rb:3`:

```ruby
super
```

Representative diff:

```diff
@@ -1 +1 @@
-super
+super()

```

## sym

Representative source from `meta/sym.rb:3`:

```ruby
:foo
```

Representative diff:

```diff
@@ -1 +1 @@
-:foo
+:foo__mutant__

```

## true

Representative source from `meta/true.rb:3`:

```ruby
true
```

Representative diff:

```diff
@@ -1 +1 @@
-true
+false

```

## until

Representative source from `meta/until.rb:3`:

```ruby
until true
  foo
  bar
end
```

Representative diff:

```diff
@@ -1,4 +1,3 @@
 until true
-  foo
   bar
 end

```

## while

Representative source from `meta/while.rb:3`:

```ruby
while true
  foo
  bar
end
```

Representative diff:

```diff
@@ -1,4 +1,4 @@
 while true
-  foo
+  self
   bar
 end

```

## yield

Representative source from `meta/yield.rb:3`:

```ruby
yield(true)
```

Representative diff:

```diff
@@ -1 +1 @@
-yield(true)
+yield(false)

```
