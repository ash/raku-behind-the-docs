---
title: Nil, Any and the Undefined
part: Nothing and numbers
summary: Nil is the absence of a value and answers almost any question with itself, while Any, the parent of nearly every class, lets a single value or a type object act as a list of one element.
---

Raku has more than one way to say *nothing*. `Nil` is the absence of a value:
it is what an empty block returns, and what `first` returns when nothing
matches. A *type object*, such as `Int` or `Any`, is an undefined value that
still has a type; a variable that was never assigned holds one. `Empty` is a
list with no elements. The three behave differently, and most surprises come
from taking one for another.

Two rules explain most of this chapter. Nil answers every method it does not
have, and every subscript, with Nil; yet it is also a `Cool` and an `Any`, so
the methods it inherits from them are real and run as usual. And `Any`, the
parent of nearly every class, treats a value that is not a list, and a type
object as well, as a list of one element, so the whole list API applies to
`42` and to `Int`.

What assigning Nil to a variable does is covered in [Containers and
Binding](#ch:containers); throwing and handling Failures in [Exceptions and
Failures](#ch:exceptions); the list methods in general in [Lists, Arrays, Seqs
and Slips](#ch:lists). This chapter is about nothing, and about lists of one.

## Nil answers every method it does not have with Nil

Call a method that Nil does not define, with or without arguments, and the
answer is Nil rather than an exception. Subscripts do the same, so a chain of
calls and lookups that starts from Nil stays Nil to the end:

```raku
say Nil.foo.raku;
say Nil.foo(1, "a", :x).raku;
say Nil.foo.bar.baz.raku;
say (Nil)[100].raku;
say (Nil){100}.raku;
say Nil<a><b>[3].raku;
```
```output
Nil
Nil
Nil
Nil
Nil
Nil
```

Asking whether an element exists breaks the pattern: `:exists` answers
`False`, a real Bool, while `:delete` returns Nil again.

```raku
say ((Nil)[0]:exists).raku;
say (Nil<a>:exists).raku;
say ((Nil)[0]:delete).raku;
```
```output
Bool::False
Bool::False
Nil
```

The parentheses around `Nil` before `[` and `{` are not decoration, as the
next corner shows.

## A type name followed by `[` is a parameterization, not a subscript
tags: trap quirk

`Array[Int]` makes a new type out of `Array`: square brackets after a type
name hold type parameters. The rule holds for every type name, `Nil`
included, so `Nil[0]` asks to parameterize Nil, and the program does not
compile. The message names `Any`, not `Nil`:

```raku
say Nil[0];
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Any cannot be parameterized
at example.raku:1
------> say Nil[0]<HERE>;
```

A brace after a type name is taken for something else too (Rakudo answers
*Autovivifying object closures not yet implemented*). Angle brackets are read
as a subscript. A type name in parentheses is an ordinary term, and every
subscript works on it:

```raku
say (Nil)[0].raku;
say Nil<a>.raku;
say (Int)[0].raku;
say Int<a>.raku;
```
```output
Nil
Nil
Int
Any
```

Why `(Int)[0]` is `Int` itself is explained
[below](#ch:nil-any:index-0-of-a-single-value-is-the-value-itself).

## Nil is undefined, false, and its own only instance

Nil is a type, and it is also the only value of that type: `Nil.new`, with
any arguments, returns Nil itself. It is undefined and false. Its parents are
`Cool`, `Any` and `Mu`, which is where the list and string methods of the
following corners come from. `say` shows a type object such as `Int` in
parentheses, but prints Nil as the bare word.

```raku
say Nil.new === Nil;
say Nil.defined;
say Nil.so;
say Nil.^mro.map(*.^name);
say Nil;
say Int;
```
```output
True
False
False
(Nil Cool Any Mu)
Nil
(Int)
```

## `for Nil` runs once: Nil fills one slot in a list
tags: trap

Nil means *no value*, but it is not an empty list. As a list it has one
element, itself: a loop over it runs once, it takes a slot in a list literal,
and its `.elems` is 1. The empty list is `Empty`, which vanishes from a list
and makes a loop run zero times.

```raku
my $n = 0;
$n++ for Nil;
say $n;
say (1, Nil, 3).elems;
say (1, Empty, 3).elems;
say Nil.elems;
say Nil.list.raku;
```
```output
1
3
2
1
(Nil,)
```

## List methods on Nil see the one-element list `(Nil,)`
tags: undocumented unasserted

Nil's habit of answering Nil covers only the methods it does not have. The
list methods are defined in `Any`, Nil inherits them, and they run on the list
`(Nil,)`. The block of a `map` is called once, with Nil in `$_`; `grep` tests
Nil and rejects it; `combinations` finds the empty combination and the one
that holds Nil:

```raku
say Nil.map({ .raku }).raku;
say Nil.grep(*.defined).raku;
say Nil.sort.raku;
say Nil.reverse.raku;
say Nil.head.raku;
say Nil.roll(2).raku;
say Nil.combinations.raku;
```
```output
("Nil",).Seq
().Seq
(Nil,).Seq
(Nil,).Seq
Nil
(Nil, Nil).Seq
((), (Nil,)).Seq
```

The results are real lists that contain Nil, so `Nil.map({ $_ }).elems` is
1, not Nil.

## Nil takes the type-object answer of the list methods
tags: undocumented unasserted

Several list methods treat an undefined invocant differently from a defined
one, and Nil is undefined. Those that have an answer for a type object give
it: `keys`, `values` and `pairs` are empty, `reduce` and `produce` are Nil,
and `tree` and `are` return the invocant.

```raku
say Nil.keys.raku;
say Nil.values.raku;
say Nil.pairs.raku;
say Nil.reduce(&[+]).raku;
say Nil.tree.raku;
say Nil.are.raku;
```
```output
()
()
()
Nil
Nil
Nil
```

Those that accept only a defined invocant have no candidate for Nil and die
with `X::Multi::NoMatch`. `Nil.Map` dies as well, because a lone Nil is an odd
number of elements for a Map:

```raku
try Nil.sum;           say $!.^name;
try Nil.min;           say $!.^name;
try Nil.batch(2);      say $!.^name;
try Nil.rotor(2);      say $!.^name;
try Nil.toggle(* > 1); say $!.^name;
try Nil.Map;           say $!.^name;
```
```output
X::Multi::NoMatch
X::Multi::NoMatch
X::Multi::NoMatch
X::Multi::NoMatch
X::Multi::NoMatch
X::Hash::Store::OddNumber
```

## An Array or a Hash slot turns Nil into its default

An Array keeps each element in a Scalar container, and assigning Nil to a
container puts its default back, as [Containers and
Binding](#ch:containers:a-variable-keeps-its-value-in-a-scalar-container)
shows. So Nil can be an element of a List but not of an Array: in an Array it
becomes `Any`, or the element type of a typed array. A Hash value does the
same. Binding skips the container, and a name bound to Nil keeps it.

```raku
say Nil.List.raku;
say [Nil].raku;
my @a = Nil;
say @a.raku;
my Int @typed = 1, Nil;
say @typed.raku;
my %h = a => Nil;
say %h.raku;
my $bound := Nil;
say $bound.raku;
```
```output
(Nil,)
[Any]
[Any]
Array[Int].new(1, Int)
{:a(Any)}
Nil
```

`my @a = Nil` does not leave the array empty: it gives it one element.
Assigning `Empty`, or `()`, empties an array.

## `%h = Nil`, `Int:D` and native variables refuse Nil
tags: trap

Three kinds of variable cannot take Nil. A hash assignment reads Nil as a list
of one element, and a hash needs its keys and values in pairs. A variable
declared `Int:D` with no default has nothing to go back to: Nil turns into the
type object `Int`, which the `:D` then refuses, and the message says as much.
A native `int` cannot hold a type object at all.

```raku
my %h = a => 1;
try { %h = Nil };
say $!.message;
say %h.raku;
my Int:D $d = 5;
try { $d = Nil };
say $!.message;
my int $n = 5;
try { $n = Nil };
say $!.message;
```
```output
Odd number of elements found where hash initializer expected:
Only saw: Nil
{:a(1)}
Type check failed in assignment to $d; expected Int:D but got Int (Int) (perhaps Nil was assigned to a :D which had no default?)
Cannot unbox a type object (Nil) to int.
```

The failed assignment leaves the hash as it was; `%h = Empty` empties it. An
`Int:D` variable declared with `is default(0)` takes Nil and becomes 0.

## Nil refuses every change
tags: quirk

Nil is not a container, and nothing about it can be changed. The methods that
grow a list die with a message that names the method; assigning to an element
dies as for any immutable value; binding to an element returns a Failure,
which dies when it is sunk. Binding a key gives a different exception from
binding an index, and its message talks about `(Any)`:

```raku
try Nil.push(1);
say $!.message;
try { (Nil)[0] = 1 };
say $!.message;
try { (Nil)[0] := 1 };
say $!.^name, ": ", $!.message;
try { Nil<a> := 1 };
say $!.^name, ": ", $!.message;
```
```output
Use of Nil.push not allowed
Cannot modify an immutable Nil value
X::Bind: Cannot bind to Nil
X::Parameter::RW: Parameter 'self' expects a writable container (variable) as an
argument, but got '(Any)' (Any) as a value without a container.
```

`append`, `unshift` and `prepend` die in the same way as `push`.

## String methods on Nil return an empty string, even `.chars`
tags: undocumented unasserted

Nil is a `Cool`, so it has Cool's string methods, and it overrides the common
ones (`chars`, `uc`, `lc`, `substr`, `contains`, `index`, `words`, `comb`,
`lines` and a dozen more) to return the empty string, with a warning that
names the method. That includes the methods that answer a number or a Bool on
a real string: `Nil.chars` is `""`, not 0, and `Nil.contains` is `""`, which
is false even for a needle that every string contains. A type object such as
`Str` is turned into an empty string first, and `.chars` of that is 0.

```raku
say Nil.chars.raku;
say Nil.uc.raku;
say Nil.contains("").raku;
say Nil.index("a").raku;
say Str.chars;
```
```output
""
""
""
""
0
```
```stderr
Use of Nil.chars coerced to empty string
  in block <unit> at example.raku line 1
Use of Nil.uc coerced to empty string
  in block <unit> at example.raku line 2
Use of Nil.contains coerced to empty string
  in block <unit> at example.raku line 3
Use of Nil.index coerced to empty string
  in block <unit> at example.raku line 4
Use of uninitialized value of type Str in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 5
```

The methods Nil does not override behave as on any undefined `Cool`: `split`
turns Nil into a string with the general *Use of Nil in string context*
warning and returns `("",)`, and `trim`, which has no candidate for an
undefined invocant, dies with `X::Multi::NoMatch`.

## Nil is 0 in arithmetic and empty in a string, with a warning

Where a number is needed, Nil counts as 0. Every such use warns, and the
warning names Nil, where an undefined type object gets a longer message about
an *uninitialized value*. `.chrs` numifies too, so it turns Nil into the
character with code 0:

```raku
say Nil.Int.raku;
say (Nil + 1).raku;
say Nil == 0;
say Nil.chrs.raku;
say (Any + 1).raku;
```
```output
0
1
True
"\0"
1
```
```stderr
Use of Nil in numeric context
  in block <unit> at example.raku line 1
Use of Nil in numeric context
  in block <unit> at example.raku line 2
Use of Nil in numeric context
  in block <unit> at example.raku line 3
Use of Nil in numeric context
  in block <unit> at example.raku line 4
Use of uninitialized value of type Any in numeric context
  in block <unit> at example.raku line 5
```

Where a string is needed, Nil is the empty string, again with a warning:
`.Str`, `~`, `eq` and interpolation all issue it. `.gist` and `.raku` are the
silent ways to show a Nil; `say` uses `.gist`, which is why `say Nil` prints
the word and does not warn.

```raku
say Nil.Str.raku;
say "<{Nil}>";
say Nil eq "";
say Nil.gist;
say Nil.raku;
```
```output
""
<>
True
Nil
Nil
```
```stderr
Use of Nil in string context
  in block <unit> at example.raku line 1
Use of Nil in string context
  in block <unit> at example.raku line 2
Use of Nil in string context
  in block <unit> at example.raku line 3
```

## A Failure is a Nil, so it smartmatches `Nil`
tags: quirk undocumented

`Failure`, the value that `fail` returns, is a subclass of Nil. Smartmatching
against Nil accepts Nil and every Failure, but no other undefined value. Nil
matches `Any`, being one.

```raku
say Failure.^mro.map(*.^name);
say Nil ~~ Nil;
say Failure.new("x") ~~ Nil;
say Any ~~ Nil;
say Nil ~~ Any;
say Nil.ACCEPTS(Any).raku;
```
```output
(Failure Nil Cool Any Mu)
True
True
False
True
Bool::False
```

The last line is the quirk: `Nil.ACCEPTS` answers a Bool. Roast has a test
that expects Nil there, marked as a known failure for Rakudo, so the intended
answer is not settled. The type test itself is useful: `when Nil` catches an
absent value and a failed one alike.

```raku
sub lookup { fail "not found" }
given lookup() {
    when Nil { say "nothing: ", .^name }
}
```
```output
nothing: Failure
```

## A default value does not replace a Nil argument
tags: trap

A parameter's default is used only when the argument is missing. Passing Nil
is passing an argument, so an untyped parameter receives Nil itself, default
or not:

```raku
sub nothing { Nil }
sub plain($x) { $x.raku }
sub fallback($x = 5) { $x.raku }
say plain(nothing);
say fallback(nothing);
say fallback();
```
```output
Nil
Nil
5
```

A typed parameter refuses Nil, even an optional one, because Nil is not an
`Int`. When the Nil arrives from a call, the refusal comes at run time:

```raku
sub nothing { Nil }
sub typed(Int $x?) { $x.raku }
try typed(nothing);
say $!.^name;
say $!.message;
```
```output
X::TypeCheck::Binding::Parameter
Type check failed in binding to parameter '$x'; expected Int but got Nil (Nil)
```

When the literal `Nil` is written in the call, the compiler sees that the
call can never work and rejects the whole program:

```raku
sub typed(Int $x) { $x.raku }
say typed(Nil);
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Calling typed(Nil) will never work with declared signature (Int $x)
at example.raku:2
------> say <HERE>typed(Nil);
```

## Nil is what code returns when it has nothing to return

An empty routine returns Nil, and so do a bare `return`, a block that ran but
produced nothing, and `EVAL` of an empty string. A condition that was false
is different: an `if` without an `else` that did not run gives `Empty`, the
empty list. Reading past the end of an array gives neither: it gives the
element default, `Any`.

```raku
sub empty { }
sub bare { return }
say empty().raku;
say bare().raku;
say (if 1 { }).raku;
say (EVAL "").raku;
say (if 0 { 1 }).raku;
my @a;
say @a[5].raku;
```
```output
Nil
Nil
Nil
Nil
Empty
Any
```

## A return type, even `:D`, lets Nil and Failures through
tags: trap

A return constraint such as `--> Int:D` checks what a routine returns, but Nil
is exempt from it, and so is a Failure, being a Nil. A routine declared to
return a defined Int can therefore return nothing, or fail, without breaking
its signature. An undefined `Int` gets no such pass:

```raku
sub strict(--> Int:D) { return Nil }
say strict().raku;
sub failing(--> Int:D) { fail "no number" }
say failing().^name;
sub undefined(--> Int:D) { Int }
try undefined();
say $!.^name;
```
```output
Nil
Failure
X::TypeCheck::Return
```

Code that calls such a routine still has to be ready for an undefined result.

## A single value is a list of one element

Raku deliberately blurs the line between an item and a list of one. `Any`
defines the list methods for everything that is not a list itself, and they
see the value as a one-element list. A string is one element too, not a list
of characters, and so is a Pair.

```raku
say 42.list.raku;
say 42.elems;
say 42.end;
say "abc".elems;
say (a => 1).elems;
say 42.Array.raku;
say 42.Seq.raku;
```
```output
(42,)
1
0
1
1
[42]
(42,).Seq
```

## A type object is a list of one element too
tags: trap

A type object is not an empty list. `Int.elems` is 1, a loop over `Int` runs
once, and a variable that was never assigned, which holds the type object
`Any`, has one element:

```raku
say Int.list.raku;
say Str.elems;
say Int.Array.raku;
my $n = 0;
$n++ for Int;
say $n;
my $x;
say $x.elems;
```
```output
(Int,)
1
[Int]
1
1
```

A test such as `if $x.elems` is therefore true for a variable that was never
assigned; `$x.defined` is the test that tells.

## `42.keys` is `(0,)`, and `Int.keys` is empty

As a one-element list, `42` has one key, 0, and one value, itself. A type
object has neither: for these methods it is the empty list, not a list of
one.

```raku
say 42.keys.raku;
say 42.values.raku;
say 42.kv.raku;
say 42.pairs.raku;
say 42.antipairs.raku;
say Any.keys.raku;
say Any.kv.raku;
```
```output
(0,).Seq
(42,)
(0, 42).Seq
(0 => 42,).Seq
(42 => 0,).Seq
()
()
```

`values` returns a List where the others return a Seq. `invert` wants Pairs;
on a single value it fails, but only when its result is read, since the Seq
it returns is lazy:

```raku
say (a => 1).invert.raku;
say Any.invert.raku;
my $inverted = 42.invert;
say "not yet";
try $inverted.eager;
say $!.message;
```
```output
(1 => "a",).Seq
()
not yet
Type check failed in invert; expected Pair but got Int
```

## `.keys` on an enum value lists the whole enumeration
tags: quirk

An enumeration answers `keys`, `values` and `pairs` from its table of names,
whether it is asked through the type or through one of its values. The table
has no order, so the example sorts it. `.elems` still says 1. `.kv` on a
value of a user-defined enum gives that value's own name and number, while on
`True` it gives the whole table of `Bool`:

```raku
enum Colour <Red Green Blue>;
say Green.keys.sort;
say Green.values.sort;
say Colour.keys.sort;
say Green.elems;
say Green.kv;
say True.keys.sort;
say True.kv.elems;
```
```output
(Blue Green Red)
(0 1 2)
(Blue Green Red)
1
(Green 1)
(False True)
4
```

## `.hash` and `.pairup` want pairs, and a single value is odd
tags: undocumented unasserted

`.hash`, `.Map` and `.pairup` read their invocant as a list of keys and
values. A Pair is a key and a value already. Any other single value is one
element, and one is an odd count:

```raku
say (a => 1).hash.raku;
try 42.hash;
say $!.message;
try 42.pairup.eager;
say $!.^name;
say Any.hash.raku;
say Any.pairup.raku;
try Any.Map;
say $!.message;
```
```output
{:a(1)}
Odd number of elements found where hash initializer expected:
Only saw: 42
X::Pairup::OddNumber
{}
().Seq
Odd number of elements found where hash initializer expected:
Only saw: type object 'Any'
```

A type object gets two different answers: `.hash` and `.pairup` treat it as
empty, `.Map` as one odd element. `Nil.Map` dies like `Any.Map`. `pairup`
returns a lazy Seq, so on `42` it dies only when read, here by `.eager`.

## `map` calls its block once for a single value

`42.map` runs its block once, with 42 in `$_`; a string is mapped whole, not
character by character; a type object is mapped as itself. A block that takes
two arguments per call finds only one, and dies unless its second parameter
has a default:

```raku
say 42.map({ $_ * 2 }).raku;
say "ab".map(*.uc).raku;
say Any.map({ $_ }).raku;
say 42.map(-> $a, $b = "none" { "$a and $b" }).raku;
try 42.map(-> $a, $b { $a + $b }).eager;
say $!.message;
```
```output
(84,).Seq
("AB",).Seq
(Any,).Seq
("42 and none",).Seq
Too few positionals passed; expected 2 arguments but got 1
```

## `grep` smartmatches a single value, and a type object is one

`grep` given a type, a regex or a value smartmatches each element against it,
and given a block it calls the block. A single value is kept or dropped whole.
A type object is an element like any other: it matches its own type and fails
a definedness test.

```raku
say 42.grep(Int).raku;
say 42.grep(Str).raku;
say 42.grep(/4/).raku;
say 42.grep(* > 40).raku;
say Any.grep(Any).raku;
say Any.grep(*.defined).raku;
```
```output
(42,).Seq
().Seq
(42,).Seq
(42,).Seq
(Any,).Seq
().Seq
```

## `first` answers Nil when nothing matches

Without a test, `first` returns the first element, whatever its truth, so
`42.first` is 42 and `Any.first` is `Any`. When the test matches nothing, or
the list is empty, the answer is Nil. With type objects the two cases can look
alike: `Any.first` returned an element, `Any.first(*.defined)` found none.

```raku
say 42.first.raku;
say 42.first(* > 1).raku;
say 42.first(* > 100).raku;
say Any.first.raku;
say Any.first(*.defined).raku;
say ().first.raku;
say (0, "", 2).first.raku;
```
```output
42
42
Nil
Any
Nil
Nil
0
```

Giving a Bool to `first` or `grep` is almost always a mistake, such as
`.grep($_ > 1)` without braces, where the comparison runs once, before the
call. Both refuse it with `X::Match::Bool`, in different ways: `first`
returns a Failure, while `grep` throws at once.

```raku
my $found = (1, 2, 3).first(True);
say $found.^name;
say $found.exception.^name;
try (1, 2, 3).grep(True);
say $!.^name;
```
```output
Failure
X::Match::Bool
X::Match::Bool
```

## Without a count, `head`, `tail` and `pick` return the value itself
tags: trap

`head` with no argument returns the first element, not a list of one, so on a
single value it returns the value. With a count it returns a Seq. `tail`,
`pick` and `roll` work the same way, and a type object is returned like any
value. An empty list has no element to return, and the answer is Nil.

```raku
say 42.head.raku;
say 42.head(1).raku;
say Any.tail.raku;
say ().head.raku;
say 42.pick.raku;
say 42.roll(3).raku;
say 42.pick(**).head(3).raku;
say ().pick.raku;
```
```output
42
(42,).Seq
Any
Nil
42
(42, 42, 42).Seq
(42, 42, 42).Seq
Nil
```

`pick(n)` never repeats an element, so `42.pick(2)` is `(42,)`. `pick(**)`
starts again whenever the elements run out, and on a single value it repeats
that value for ever.

## `reduce` on one element calls the reducer with one argument
tags: trap

A reduction of a one-element list does not hand the element back untouched:
it calls the reducer with that element alone. An operator such as `&[+]` or
`&[-]` has a one-argument form that returns its argument, so the result is the
element. A block that needs two arguments dies, unless its second parameter
has a default:

```raku
say 42.reduce(&[+]);
say 42.reduce(&[-]);
say 42.reduce(-> $a, $b = 0 { $a - $b });
try 42.reduce(-> $a, $b { $a - $b });
say $!.message;
say Any.reduce(&[+]).raku;
say 42.produce(&[+]).raku;
```
```output
42
42
42
Too few positionals passed; expected 2 arguments but got 1
Nil
(42,).Seq
```

A type object reduces to Nil. An empty list gives the operator's identity,
as the [reduction metaoperator](#ch:precedence:an-empty-reduction-answers-the-operators-identity)
does, and a plain block dies with *expected 2 arguments but got 0*.

## `sum`, `min`, `batch` and `rotor` refuse a type object

On a defined single value these methods see a one-element list, as every
other list method does:

```raku
say 42.sum;
say 42.minmax.raku;
say 42.batch(2).raku;
say 42.rotor(1).raku;
say 42.toggle(* > 1).raku;
```
```output
42
42..42
((42,),).Seq
((42,),).Seq
(42,).Seq
```

For a type object they have no candidate at all, so `Int.sum` is not 0 but a
dispatch failure, `X::Multi::NoMatch`:

```raku
say Int.sum;
```
```output
```
```stderr
Cannot resolve caller sum(Int:U: ); none of these signatures matches:
    (Any:D $:: *%_)
  in block <unit> at example.raku line 1

```

The signature in the message, `Any:D`, says it all: the method wants a
defined invocant. `min`, `minmax`, `batch`, `rotor`, `toggle` and `slice`
refuse a type object in the same way, and `splice` has no candidate for any
single value, defined or not.

## `min` and `max` let an undefined operand lose
tags: trap

The infix `min` and `max`, and the subs of the same names, pass over undefined
operands: a defined operand always wins. When nothing defined is left, `min`
answers `Inf` and `max` answers `-Inf`, the values that any number beats, and
an empty `minmax` is the backwards range `Inf..-Inf`.

```raku
say Int min 5;
say 5 max Int;
say (3, Any, 1).min;
say min(Int, Str);
say max(Int, Str);
say min();
say ().minmax.raku;
```
```output
5
5
1
Inf
-Inf
Inf
Inf..-Inf
```

The sub and the method part ways on a type object: `min(Int)` is `Inf`, while
`Int.min` dies, as the previous corner showed.

## The sub forms take a list or separate values, `sort` excepted
tags: quirk

Most list methods have a sub form, which takes a callable first where the
method takes one, and then the values. A single argument that is a list is the
list, several arguments are the elements, and a single value is a list of one.

```raku
say elems(42);
say elems((1, 2));
say keys(42).raku;
say map({ $_ * 2 }, 1, 2).raku;
say map({ $_ * 2 }, (1, 2)).raku;
```
```output
1
2
(0,).Seq
(2, 4).Seq
(2, 4).Seq
```

`sort` cannot take its values that way. It has one candidate for a comparator
followed by values and one for values alone, and since a callable is a value
too, a comparator followed by separate values fits both. Rakudo refuses to
choose. Passing the values as one list works:

```raku
say sort(3, 1, 2).raku;
say sort(-*, (3, 1, 2)).raku;
try sort(-*, 3, 1, 2);
say $!.^name;
```
```output
(1, 2, 3).Seq
(3, 2, 1).Seq
X::Multi::Ambiguous
```

A block written without parentheses, `sort { $^b <=> $^a }, 3, 1, 2`, is
ambiguous in the same way.

## The other list methods treat a value as a list of one

Everything else in the list API follows from the one-element view. Sorting,
reversing or de-duplicating one element changes nothing; `repeated` finds no
repeats; `combinations` has the empty combination and the whole. The mapping
methods return a one-element List, except `tree`, which returns a single value
as it is:

```raku
say 42.sort.raku;
say 42.unique.raku;
say 42.repeated.raku;
say 42.combinations.raku;
say 42.permutations.raku;
say 42.deepmap(* + 1).raku;
say 42.tree.raku;
say Any.sort.raku;
```
```output
(42,).Seq
(42,).Seq
().Seq
((), (42,)).Seq
((42,),).Seq
(43,)
42
(Any,).Seq
```

## A classified Nil keeps its key and loses its value
tags: undocumented unasserted

`classify` puts each element into a bucket named by the result of its test,
and returns an *object hash*, whose keys keep their type. On `42` the key is
the Int 42. On Nil the key is Nil, but each bucket is an Array, and an Array
element cannot hold Nil, so the element becomes `Any`:

```raku
say 42.classify({ $_ }).raku;
say 42.classify({ $_ }).keys[0].^name;
my $by = Nil.classify({ $_ });
say $by.keys[0].raku;
say $by.values.raku;
say (1, 2, 3).classify(* %% 2).^name;
```
```output
(my Mu %{Mu} = 42 => $[42])
Int
Nil
($[Any],).Seq
Hash[Mu,Mu,Any]
```

`categorize` behaves the same: `Nil.categorize({ ($_,) })` has the single key
Nil.

## `are` names the type of one value, or of a type object

`are` returns the narrowest type that every element of a list matches, and
with a type argument it checks every element against that type. A single
value answers its own type, a type object answers itself, and an empty list
answers Nil. A failed check is a Failure whose message names the first element
that did not match; for a type object there is no element number to name:

```raku
say 42.are;
say Any.are;
say ().are.raku;
say (1, 2.5).are;
say 42.are(Int);
say (1, "a").are(Int).exception.message;
say Any.are(Int).exception.message;
```
```output
(Int)
(Any)
Nil
(Real)
True
Expected 'Int' but got 'Str' in element 1
Expected 'Int' but got 'Any'
```

## Index 0 of a single value is the value itself

A positional subscript on a value that is not a list sees the one-element
list. Index 0 returns the value, however it is written, and so does any chain
of `[0]`; a slice repeats it. Any other index is a Failure, `X::OutOfRange`,
with the range `0..0`. A type object follows the same rule, and a string is
one element, not a list of characters:

```raku
say 42[0];
say 42[0][0][0];
say 42[*-1];
say 42[0, 0].raku;
say "abc"[0];
say (Int)[0].raku;
say 42[1].exception.message;
```
```output
42
42
42
(42, 42)
abc
Int
Index out of range. Is: 1, should be in 0..0
```

`:exists` agrees, and `:delete` refuses, since a value holds no elements to
remove. An index is truncated to an integer, so `0.9` reads the value:

```raku
say 42[0]:exists;
say 42[1]:exists;
say 42[0.9];
say (42[0]:delete).exception.message;
```
```output
True
False
42
Can not remove elements from a Int
```

## An index that is not a number dies, and `42[Int]` also warns
tags: quirk

NaN and Inf cannot become an integer index, and the subscript dies with
`X::Numeric::CannotConvert`. A type object as an index dies with a message that
asks for a defined object. On a literal there is no variable name to put in
that message, which leaves a gap where the name would be, and Rakudo warns
about Nil in string context while building it:

```raku
try 42[NaN];
say $!.message;
try 42[Inf];
say $!.^name;
try 42[Int];
say $!.message.lines[0];
```
```output
Cannot convert NaN to Int
X::Numeric::CannotConvert
Unable to call postcircumfix [ (Int) ] with a type object
```
```stderr
Use of Nil in string context
  in code  at example.raku line 5
```

On an array variable the message names the variable, `@a[ (Int) ]`, and there
is no warning.

## Assigning through a subscript builds the missing Array or Hash

An undefined variable can be assigned to as if it held an Array or a Hash:
the assignment creates the structure, and a chain of subscripts creates every
level. Reading creates nothing, even through several levels:

```raku
my $a;
$a[2] = 5;
say $a.raku;
my $h;
$h<x><y> = 3;
say $h.raku;
my $m;
$m[0]<k> = 4;
say $m.raku;
my $r;
my $v = $r<a><b>;
say $r.raku;
```
```output
$[Any, Any, 5]
${:x(${:y(3)})}
$[{:k(4)},]
Any
```

The `$` in front of each result shows that the new Array or Hash sits in the
variable's Scalar. A defined value is never replaced this way. Index 0 of
`42` is `42` itself, which cannot be assigned to; any other index is out of
range; and a key is not supported at all:

```raku
my $y = 42;
try { $y[0] = 1 };
say $!.^name;
try { $y[1] = 1 };
say $!.^name;
try { $y<a> = 1 };
say $!.message;
```
```output
X::Assignment::RO
X::OutOfRange
Type Int does not support associative indexing.
```

## `<key>` on a value that is not a hash is a Failure

An associative subscript on a defined value that is not a hash returns a
Failure rather than dying at once; `:exists` answers False, and `:delete`
fails too. Binding a key into an undefined variable creates a Hash, as
assignment does, while binding one into a defined value dies with `X::Bind`:

```raku
my $f = 42<a>;
say $f.^name;
say $f.exception.message;
say 42<a>:exists;
say (42<a>:delete).exception.message;
my $x;
$x<a> := 1;
say $x.raku;
try { 42<a> := 1 };
say $!.^name;
```
```output
Failure
Type Int does not support associative indexing.
False
Can not remove values from a Int
${:a(1)}
X::Bind
```

A type object is treated differently: a key lookup on it returns `Any`, as a
lookup in an empty hash does, so `Int<a>` is `Any` and not a Failure.

## `push` on an undefined variable creates an Array

`push`, `append`, `unshift` and `prepend` called on an undefined variable
create an Array, store it in the variable and add to it. This is what lets a
hash of arrays grow without setting up each array first:

```raku
my $x;
$x.push(1, 2);
say $x.raku;
my $y;
$y.unshift(0);
say $y.raku;
my %groups;
%groups{.chars}.push($_) for <a bb c>;
say %groups.sort.raku;
```
```output
$[1, 2]
$[0]
("1" => $["a", "c"], "2" => $["bb"]).Seq
```

The new Array has to fit the variable. An `Int` variable refuses it. A `List`
variable finds List's own `push`, which refuses because a List cannot change.
A defined value that is not a list has no `push` at all:

```raku
my Int $i;
try $i.push(1);
say $!.message;
my List $l;
try $l.push(1);
say $!.message;
try 42.push(1);
say $!.^name;
```
```output
Type check failed in assignment to $i; expected Int but got Array ([])
Cannot call 'push' on an immutable 'List'
X::Multi::NoMatch
```

## `++` on an undefined variable counts from 0

Incrementing an undefined variable treats it as 0: `$x++` returns 0 and
leaves 1, and `--$x` gives -1. That is what makes `%count{$_}++` work on keys
never seen before. The result is an Int, which a variable typed `Str` refuses;
a `Num` variable, on the other hand, ends up holding the Num `1e0`:

```raku
my $a;
say $a++;
say $a;
my $b;
say --$b;
my %count;
%count{$_}++ for <a b a>;
say %count.sort;
my Str $s;
try $s++;
say $!.message;
my Num $n;
$n++;
say $n.raku;
```
```output
0
1
-1
(a => 2 b => 1)
Type check failed in assignment to $s; expected Str but got Int (1)
1e0
```

A `Rat` variable refuses the Int as a `Str` one does.

## A Set or junction of one value holds it, even Nil
tags: undocumented unasserted

The Set, Bag and Mix coercers, and the junction methods, see a single value as
a one-element list, and Nil is no exception: `Nil.Set` is a set with one
element, Nil, not the empty set. A type object is an element in the same way.

```raku
say 42.Set.raku;
say Any.Set.raku;
say Nil.Set.raku;
say Nil.Set.elems;
say Nil.Bag.raku;
say 42.any.raku;
say Nil.all.raku;
say so 42.any == 42;
```
```output
Set.new(42)
Set.new(Any)
Set.new(Nil)
1
(Nil=>1).Bag
any(42)
all(Nil)
True
```

## `.match` stringifies its invocant and sets the caller's `$/`
tags: undocumented

`.match` works on any value by matching against its string form: `42` becomes
`"42"`, and a list becomes its elements joined with spaces. Like `~~`, it sets
the caller's `$/`, and a failed match sets `$/` to Nil, replacing any earlier
match. A type object becomes the empty string, with the usual warning:

```raku
say 42.match(/4/).raku;
say $/.raku;
42.match(/9/);
say $/.raku;
say (1..3).match(/2/).raku;
say Int.match(/Int/).raku;
```
```output
Match.new(:orig("42"), :from(0), :pos(1))
Match.new(:orig("42"), :from(0), :pos(1))
Nil
Match.new(:orig("1 2 3"), :from(2), :pos(3))
Nil
```
```stderr
Use of uninitialized value of type Int in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 6
```

## `join` of one value is its string; undefined joins as empty

`join` on a single value returns its string, and the sub with nothing to join
returns the empty string. An undefined element joins as the empty string with
a warning: the short *Use of Nil* for Nil, the longer message for a type
object.

```raku
say 42.join("-").raku;
say join("-").raku;
say Any.join.raku;
say (1, Nil, 3).join(",").raku;
say (1, Any, 3).join(",").raku;
```
```output
"42"
""
""
"1,,3"
"1,,3"
```
```stderr
Use of uninitialized value of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 3
Use of Nil in string context
  in block <unit> at example.raku line 4
Use of uninitialized value of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 5
```

## Smartmatching against a plain object tests identity

For a class that does not define its own `ACCEPTS`, `$x ~~ $obj` is true only
when `$x` is that very object; two objects with the same attributes do not
match. A type object on the left never matches an instance on the right,
while a type on the right checks the type, as usual. Value types such as
numbers and strings define their own `ACCEPTS` and compare by value:

```raku
class Point { has $.x }
my $p = Point.new(x => 1);
say $p ~~ $p;
say $p ~~ Point.new(x => 1);
say Point ~~ $p;
say $p ~~ Point;
say 42 ~~ 42.0;
say Int ~~ 42;
```
```output
True
False
False
True
True
False
```

## `===` compares value types by value and other objects by identity

`===` asks whether two values are the same object. For a value type, whose
objects are defined by their contents, that means the same type and the same
value: two `1`s, two `"a"`s and two equal Ranges are identical, but `1` and
`1.0` are not, being an Int and a Rat. Lists and Arrays are compared by
identity, however equal their contents; `eqv` is the operator that compares
contents. A type object is identical only to itself, and Nil to Nil:

```raku
say 1 === 1;
say 1 === 1.0;
say "a" === "a";
say 1..2 === 1..2;
say (1, 2) === (1, 2);
say [1] === [1];
say (1, 2) eqv (1, 2);
say Any === Mu;
say Nil === Nil;
```
```output
True
False
True
True
False
False
True
False
True
```

`⩶` is another spelling of `===`, and a reduction over a single value,
`[===] 5`, is `True`. Pairs follow the value rule unless they hold a container, as
[Containers and
Binding](#ch:containers:pairs-that-hold-the-same-variable-are-not-identical)
shows.
