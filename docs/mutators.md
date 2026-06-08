# Mutators

This page summarizes the currently shipped mutator families.

It is intentionally concise: each section shows the first `meta/` example for a given operator family and one representative diff. The `meta/` fixtures remain the exhaustive behavioral specification that the test suite verifies.

## special forms

Representative source from `meta/file.rb`:

```ruby
__FILE__
```

Representative diff:

```diff
@@ -1 +0,0 @@
-__FILE__

```

## and

Representative source from `meta/and.rb`:

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

Representative source from `meta/and_asgn.rb`:

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

Representative source from `meta/array.rb`:

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

Representative source from `meta/lvasgn.rb`:

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

Representative source from `meta/begin.rb`:

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

Representative source from `meta/block.rb`:

```ruby
foo {
  a
  b
}
```

Representative diff:

```diff
@@ -1,4 +1,2 @@
 foo {
-  a
-  b
 }

```

## block / lambda

Representative source from `meta/lambda.rb`:

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

Representative source from `meta/block_pass.rb`:

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

Representative source from `meta/blockarg.rb`:

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

Representative source from `meta/break.rb`:

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

Representative source from `meta/case.rb`:

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

Representative source from `meta/casgn.rb`:

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

Representative source from `meta/cbase.rb`:

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

Representative source from `meta/class.rb`:

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

Representative source from `meta/const.rb`:

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

Representative source from `meta/csend.rb`:

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

Representative source from `meta/cvar.rb`:

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

Representative source from `meta/cvasgn.rb`:

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

Representative source from `meta/def.rb`:

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

Representative source from `meta/defined.rb`:

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

Representative source from `meta/dstr.rb`:

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

Representative source from `meta/dsym.rb`:

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

Representative source from `meta/ensure.rb`:

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

Representative source from `meta/range.rb`:

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

Representative source from `meta/false.rb`:

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

Representative source from `meta/float.rb`:

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

Representative source from `meta/gvar.rb`:

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

Representative source from `meta/gvasgn.rb`:

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

Representative source from `meta/hash.rb`:

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

Representative source from `meta/if.rb`:

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

Representative source from `meta/index.rb`:

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

Representative source from `meta/indexasgn.rb`:

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

Representative source from `meta/indexasgn.rb`:

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

Representative source from `meta/int.rb`:

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

Representative source from `meta/range.rb`:

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

Representative source from `meta/ivar.rb`:

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

Representative source from `meta/ivasgn.rb`:

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

Representative source from `meta/kwarg.rb`:

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

Representative source from `meta/kwbegin.rb`:

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

Representative source from `meta/lvar.rb`:

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

Representative source from `meta/lvasgn.rb`:

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

Representative source from `meta/masgn.rb`:

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

Representative source from `meta/match_current_line.rb`:

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

Representative source from `meta/next.rb`:

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

Representative source from `meta/nil.rb`:

```ruby
nil
```

Representative diff:

```diff
@@ -1 +0,0 @@
-nil

```

## nth_ref

Representative source from `meta/nthref.rb`:

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

Representative source from `meta/numblock.rb`:

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

Representative source from `meta/op_assgn.rb`:

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

Representative source from `meta/or.rb`:

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

Representative source from `meta/or_asgn.rb`:

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

Representative source from `meta/redo.rb`:

```ruby
redo
```

Representative diff:

```diff
@@ -1 +0,0 @@
-redo

```

## regexp

Representative source from `meta/regexp.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/character_types.rb`:

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

Representative source from `meta/regexp/regexp_alternation_meta.rb`:

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

Representative source from `meta/regexp/regexp_bol_anchor.rb`:

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

Representative source from `meta/regexp/regexp_bos_anchor.rb`:

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

Representative source from `meta/regexp/regexp_capture_group.rb`:

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

Representative source from `meta/regexp/regexp_eol_anchor.rb`:

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

Representative source from `meta/regexp/regexp_eos_anchor.rb`:

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

Representative source from `meta/regexp/regexp_eos_ob_eol_anchor.rb`:

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

Representative source from `meta/regexp/regexp_greedy_zero_or_more.rb`:

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

Representative source from `meta/regexp/regexp_root_expression.rb`:

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

Representative source from `meta/regopt.rb`:

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

Representative source from `meta/rescue.rb`:

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

Representative source from `meta/restarg.rb`:

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

Representative source from `meta/return.rb`:

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

Representative source from `meta/self.rb`:

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

Representative source from `meta/date.rb`:

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

Representative source from `meta/str.rb`:

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

Representative source from `meta/super.rb`:

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

Representative source from `meta/sym.rb`:

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

Representative source from `meta/true.rb`:

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

Representative source from `meta/until.rb`:

```ruby
until true
  foo
  bar
end
```

Representative diff:

```diff
@@ -1,4 +1,2 @@
 until true
-  foo
-  bar
 end

```

## while

Representative source from `meta/while.rb`:

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

Representative source from `meta/yield.rb`:

```ruby
yield(true)
```

Representative diff:

```diff
@@ -1 +1 @@
-yield(true)
+yield(false)

```
