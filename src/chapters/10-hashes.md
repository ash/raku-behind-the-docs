---
title: Hashes, Maps and Pairs
part: Collections
summary: A hash turns its keys into strings unless told otherwise, keeps its pairs in no order, answers questions through subscript adverbs, and is filled from and read back as Pairs, which have rules of their own.
---

A Hash maps keys to values. Unless it is declared otherwise, its keys are
strings, whatever they were when they went in; each value sits in a container
of its own; and the pairs come out in no particular order. A Map is a Hash
that cannot change after it is built, and a Pair is one key with its value.
Hashes are filled from Pairs and hand Pairs back out, so the three types are
best learnt together.

This chapter covers how a hash is filled, what becomes of a key, what a
missing key reads as, the adverbs that turn a subscript into a question, and
the methods that merge, list and compare hashes. The containers inside a hash
and the binding of its elements are in [Containers and
Binding](#ch:containers); when a pair of braces is a hash and when it is a
block is in [Whitespace, Terms and
Blocks](#ch:whitespace:is-a-hash-only-when-it-looks-like-one); sets and bags
are in [Sets, Bags and Mixes](#ch:sets).

Rakudo shuffles the order of a hash's pairs anew in every run. `say` prints a
hash sorted by key, as [a corner below](#ch:hashes:iteration-order-is-random-but-printing-sorts)
shows, so the examples print hashes with `say`, or sort them first.

## Hash assignment takes pairs, keys and values, or a mix

A list assigned to a hash is read from left to right. A Pair stores its key
and its value; any other item is a key, and the item after it is its value.
The two styles can be mixed in one list, and a Hash or a Map in the list
contributes all of its pairs. When a key comes twice, the later value wins.

```raku
my %a = a => 1, b => 2;
say %a;
my %b = "a", 1, "b", 2;
say %b;
my %c = a => 1, "b", 2;
say %c;
my %d = %a, c => 3;
say %d;
my %e = a => 1, a => 2;
say %e;
```
```output
{a => 1, b => 2}
{a => 1, b => 2}
{a => 1, b => 2}
{a => 1, b => 2, c => 3}
{a => 2}
```

Assigning `()` or `Empty` empties the hash.

## A nested array or list becomes one key
tags: trap

A Hash or a Map in the list is spread into its pairs, but nothing else is. An
Array, a parenthesised List, a Seq or a hash in a `$` container is one item
like any other, so it becomes a key, turned into a string, and the item after
it becomes its value. Only a list that is the whole right side is iterated,
by the same single-argument rule that makes `my @b = @a` copy the elements. A
slip, `|@pairs`, spreads an array wherever it stands.

```raku
my @pairs = a => 1, b => 2;
my %whole = @pairs;
say %whole;
my %mixed = @pairs, c => 3;
say %mixed.keys.raku;
say %mixed.values.raku;
my %listed = (a => 1, b => 2), c => 3;
say %listed.keys.raku;
my %slipped = |@pairs, c => 3;
say %slipped;
```
```output
{a => 1, b => 2}
("a\t1 b\t2",).Seq
(:c(3),).Seq
("a\t1 b\t2",).Seq
{a => 1, b => 2, c => 3}
```

The key is the list's string form: each Pair becomes `key\tvalue`, and the
Pairs are joined with a space.

## An odd number of items dies

Items that are not Pairs must come in twos. An odd count throws
`X::Hash::Store::OddNumber`, whose `.found` is the number of items and whose
`.last` is the one left over. A single value is an odd count too, and the
message then shows only that value.

```raku
try { my %h = 1, 2, 3 };
say $!.^name;
say "$!.found() $!.last()";
say $!.message;
try { my %h = 1 };
say $!.message;
```
```output
X::Hash::Store::OddNumber
3 3
Odd number of elements found where hash initializer expected:
Found 3 (implicit) elements:
Last element seen: 3
Odd number of elements found where hash initializer expected:
Only saw: 1
```

The failed assignment leaves the hash as it was. `push`, below, is more
lenient: it warns about a trailing key and drops it.

## `%h = %h, …` adds to the hash

The right side is turned into pairs before the hash is emptied, and a hash in
the list is spread, so assigning a hash and some new pairs to itself adds the
pairs. The same line with an array puts the array inside itself
([`@a = @a, 3`](#ch:containers:a-a-3-puts-the-array-inside-itself)).

The copy is one level deep. Each value gets a new container, but a value that
is an Array is the same Array in both hashes, as it is for [array
assignment](#ch:containers:gives-an-array-new-containers-but-shares-what-they-hold):

```raku
my %h = a => 1;
%h = %h, b => 2;
say %h;
my %g = x => [1, 2];
my %copy = %g;
%copy<x>.push(3);
%copy<y> = 0;
say %g;
```
```output
{a => 1, b => 2}
{x => [1 2 3]}
```

## `my %h = { … }` works, with a warning

Braces that hold pairs are a hash composer, so `my %h = { a => 1 }` builds an
anonymous hash and then copies its pairs into `%h`. The result is right, but
the compiler points out the hash that was built only to be thrown away:

```raku
my %h = { a => 1 };
say %h;
```
```output
{a => 1}
```
```stderr
Potential difficulties:
    Useless use of hash composer on right side of hash assignment; did you mean := instead?
    at example.raku:1
    ------> my %h = { a => 1 }<HERE>;
```

Leaving out the braces gives the same hash; `:=`, as the message suggests,
makes `%h` a name for the anonymous hash. Braces that turn out to be a Block
cannot be stored at all, and the message lists why braces become one:

```raku
my %h = { $_ };
```
```output
```
```stderr
Cannot use a Callable as the only argument to store in a Hash.  If the
intent was to store the contents of a Hash, one should probably use the
%( ) hash constructor instead of { }.  Causes of { } misinterpretation:
- using ';' instead of ',' to separate values, as these imply statements
- using '$_' or any placeholder variable, as they imply a block scope
  in block <unit> at example.raku line 1

```

## `Hash.new` and `Map.new` drop named arguments beside positional ones
tags: trap

In an argument list, `a => 1` with a bare identifier on the left is a named
argument, not a Pair. `hash` takes named arguments along with its list, and
`Hash.new` and `Map.new` accept them when there is nothing else. Given a
positional list as well, the two constructors ignore the named arguments
without a word. A quoted key makes a positional Pair.

```raku
say hash("a", 1, b => 2);
say Hash.new(a => 1);
say Hash.new("a", 1, b => 2);
say Map.new("a", 1, b => 2);
say Map.new("a", 1, "b" => 2);
```
```output
{a => 1, b => 2}
{a => 1}
{a => 1}
Map.new((a => 1))
Map.new((a => 1, b => 2))
```

`%h.push` has the same problem, without even the named-only exception, as
[shown below](#ch:hashes:hpusha-1-pushes-nothing).

## Iteration order is random, but printing sorts

A hash keeps no order. Rakudo picks a different order in every process, and
the order changes when keys are added, so `.keys`, `.values`, `.pairs`, `.kv`
and a `for` loop visit the pairs in an order that no program should rely on.
Within one unchanged hash the methods agree with each other: the first key
belongs to the first value, and so on.

The printing methods sort. `say` (the gist), `.Str` (one `key\tvalue` line
per pair, which is what `put` and interpolation print) and `.raku` all order
the pairs by key:

```raku
my %h = c => 3, a => 1, b => 2;
say %h.keys.map({ %h{$_} }).List eqv %h.values.List;
say %h.keys.sort;
say %h;
say %h.Str.raku;
say %h.raku;
```
```output
True
(a b c)
{a => 1, b => 2, c => 3}
"a\t1\nb\t2\nc\t3"
{:a(1), :b(2), :c(3)}
```

Anything else that walks the pairs, such as `.fmt` or `.map`, goes in the
hash's own order.

## `say` sorts keys as strings and stops after 100 pairs

The gist sorts by the keys' string forms, even in an object hash whose keys
are numbers, so 10 comes before 9. A hash with more than 100 pairs is cut off
after the first hundred with `...`; `.raku` and `.Str` print every pair.

```raku
say :{ 10 => "a", 9 => "b", 100 => "c" };
my %big = (1..150).map({ $_ => 1 });
say %big.gist.comb("=>").elems;
say %big.gist.ends-with(", ...}");
say %big.Str.lines.elems;
```
```output
{10 => a, 100 => c, 9 => b}
100
True
150
```

## A key is a string, so `%h{1}` and `%h<1>` are one slot

A plain hash converts every key to a Str on the way in: its key type is
`Str(Any)`, a coercion type. `%h{1}`, `%h{"1"}` and `%h<1>` name the same
slot, and `.keys` hands back strings. The value type is `Mu`, and the default
for a missing key is `Any`.

```raku
my %h;
%h{1} = "one";
say %h<1>;
say %h{"1"};
say %h.keys[0].^name;
%h{1.5} = "rat";
say %h{"1.5"};
say %h.keyof.raku;
say %h.of.raku, " ", %h.default.raku;
```
```output
one
one
Str
rat
Str(Any)
Mu Any
```

## Numbers become keys through their printed form
tags: trap

The conversion is `.Str`, the same that `say` uses, and a Rat prints rounded
to six decimals ([Numbers](#ch:numbers:a-rat-prints-at-most-six-decimals-but-raku-is-exact)).
So `1/3` and `0.333333` are one key, and `1`, `1.0` and `1e0`, which all
print as `1`, are one key too:

```raku
my %h;
%h{1/3} = "third";
%h{0.333333} = "close";
say %h;
my %n;
%n{1} = "Int";
%n{1.0} = "Rat";
%n{1e0} = "Num";
say %n;
```
```output
{0.333333 => close}
{1 => Num}
```

An object hash, [below](#ch:hashes:my-hany-keeps-keys-as-objects), keeps the
numbers themselves.

## An undefined key becomes the empty string, with a warning

An undefined value turns into the empty string when it is used as a key, and
Rakudo warns, naming the variable when there is one:

```raku
my %h;
my $key;
%h{$key} = 1;
say %h.raku;
```
```output
{"" => 1}
```
```stderr
Use of uninitialized value $key of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 3
```

## A bareword before `=>` is a string, even a type name
tags: trap

The left side of `=>` is quoted when it is an identifier, whatever the
identifier means elsewhere. `Int => 1` has the string `"Int"` as its key, and
`True => 1` the string `"True"`; the Pair's `.raku`, `:Int(1)`, is the form of
any other string key. Parentheses make the left side an expression, and
`(Int) => 1` holds the type object. A variable is not a bareword, so its
value is the key.

```raku
say (Int => 1).key.^name;
say (True => 1).key.^name;
say (Int => 1).raku;
say ((Int) => 1).key.^name;
say ((Int) => 1).raku;
my $k = "x";
say ($k => 1).raku;
```
```output
Str
Str
:Int(1)
Int
(Int) => 1
:x(1)
```

A type object stored as a key in a plain hash is undefined, so it becomes the
empty string with the warning of the previous corner.

## A list inside the braces is a slice, not one key

`%h{…}` with a list inside looks up every element, and so does `%h<a b>`.
Assigning a single value to a slice fills the first key and leaves the others
`Any`. To use a list as one key, itemize it; the key is then its string form.

```raku
my %h;
%h{(1, 2)} = "x", "y";
say %h;
my %j;
%j<a b> = 1;
say %j.raku;
my %g;
%g{$(1, 2)} = "z";
say %g.keys.raku;
```
```output
{1 => x, 2 => y}
{:a(1), :b(Any)}
("1 2",).Seq
```

## `my %h{Any}` keeps keys as objects

Braces after the name declare a key type, and the hash then keeps each key as
the object it was given. `1`, `"1"` and `1.0` are three different keys, and
`.keys` returns them with their types. `:{ … }` is the literal form of such
an *object hash*, with `Mu` as its key type.

```raku
my %h{Any};
%h{1} = "Int";
%h{"1"} = "Str";
%h{1.0} = "Rat";
say %h.elems;
say %h.keys.map(*.^name).sort;
say :{ 1 => "a" }.raku;
say :{ 1 => "a" }.keys[0].^name;
```
```output
3
(Int Rat Str)
(my Mu %{Mu} = 1 => "a")
Int
```

To keep an object hash in a `%` variable, declare it with braces or bind it.
Assigning `:{ … }` to a plain `%h` copies the pairs into a plain hash, where
the keys become strings, with the hash composer warning [shown
above](#ch:hashes:my-h-works-with-a-warning):

```raku
my %bound := :{ 1 => "a" };
say %bound.keys[0].^name;
my %assigned = :{ 1 => "a" };
say %assigned.keys[0].^name;
```
```output
Int
Str
```
```stderr
Potential difficulties:
    Useless use of hash composer on right side of hash assignment; did you mean := instead?
    at example.raku:3
    ------> my %assigned = :{ 1 => "a" }<HERE>;
```

## An object hash finds a key by identity

An object hash matches keys by identity. For value types, such as numbers,
strings and Pairs made of them, identity is equality, so `2/4` finds the key
`1/2`. An Array is a key only as that very Array: another Array with the same
elements is a different key. An Array must also be itemized to count as one
key, or the braces take it as a slice.

```raku
my %h{Any};
%h{1/2} = "half";
say %h{2/4};
%h{(a => 1)} = "pair";
say %h{(a => 1)};
my @k = 1, 2;
%h{$@k} = "array";
say %h{$@k};
say %h{$[1, 2]}.raku;
```
```output
half
pair
array
Any
```

## `my %h{Int}` checks every key

A key type other than `Any` or `Mu` is enforced: a key of the wrong type dies
before anything is stored, with a binding error that names the parameter
`key`. The hash's type is `Hash[Any,Int]`, the value type first.

```raku
my %h{Int} = 1 => "a", 2 => "b";
say %h.keys.sort.raku;
say %h.^name;
try { %h<x> = 1 };
say $!.^name;
say $!.message;
```
```output
(1, 2).Seq
Hash[Any,Int]
X::TypeCheck::Binding::Parameter
Type check failed in binding to parameter 'key'; expected Int but got Str ("x")
```

## `%h<1>` is a third key in an object hash
tags: trap

Angle brackets pass their words through `val`, so `<1>` is the allomorph
`IntStr` ([Quotes](#ch:quotes:numbers-in-a-word-list-become-allomorphs)):
neither the Int 1 nor the Str `"1"`. A plain hash turns it into the string
`"1"` and finds the key. An object hash keeps it as it is, and it matches
neither key. It even passes an `Int` key constraint, because an IntStr is an
Int.

```raku
my %h{Any};
%h{1} = "Int";
%h{"1"} = "Str";
say %h<1>.raku;
%h<1> = "IntStr";
say %h.elems;
my %i{Int};
%i{2} = "two";
say %i<2>.raku;
```
```output
Any
3
Any
```

In an object hash, write `%h{1}` or `%h{"1"}`, whichever type the keys have.

## `my Int %h` checks values; Nil restores the type object

A type before the name constrains the values. A value of another type dies
with `X::TypeCheck::Assignment`. Assigning `Nil` resets a slot to the
default, which for a typed hash is the type object, here `Int`; a missing key
reads as the same default. An empty typed hash's `.raku` shows its
declaration. `is Hash[Int, Str]` names both types, the value type first.

```raku
my Int %h = a => 1;
try { %h<b> = "x" };
say $!.message;
%h<a> = Nil;
say %h.raku;
say %h<missing>.raku;
my Int %e;
say %e.raku;
my %p is Hash[Int, Str];
say %p.^name;
```
```output
Type check failed for an element of %h; expected Int but got Str ("x")
(my Int % = :a(Int))
Int
(my Int %)
Hash[Int,Str]
```

`is default(0)` gives a typed hash a defined default, which both a missing key
and `Nil` then produce.

## A missing key reads as Any and is not created

Reading a key that is not there returns the hash's default, `Any`, and leaves
the hash as it was, even through a chain of subscripts. Writing is different:
assignment, `++`, `~=` and `push` on a missing key create it, and assigning
through a chain creates every level, as [for an undefined
variable](#ch:nil-any:assigning-through-a-subscript-builds-the-missing-array-or-hash).

```raku
my %h = a => 1;
say %h<b>.raku;
my $v = %h<x><y>;
say %h.elems;
%h<c>++;
%h<d> ~= "s";
%h<e>.push(1);
%h<f><g> = 1;
say %h.raku;
```
```output
Any
1
{:a(1), :c(1), :d("s"), :e($[1]), :f(${:g(1)})}
```

None of these warn about the undefined value they start from, which is what
lets `%count{$_}++ for @words` count words without setting anything up.

## `:exists` asks about a key, `:delete` removes it

A subscript takes adverbs that change what it returns. `:exists` returns
whether a key is present, and `:!exists` the opposite; a key that holds `Any`
is present. `:delete` removes the key and returns its value, or the default
when the key was not there. On a slice, each gives one answer per key.

```raku
my %h = a => 1, b => 2, c => 3;
say %h<a>:exists;
say %h<a z>:exists;
say %h<z>:!exists;
say %h<a>:delete;
say (%h<b z>:delete).raku;
say %h;
```
```output
True
(True False)
True
1
(2, Any)
{c => 3}
```

## Assigning Nil to a key does not remove it
tags: trap

Assigning `Nil` resets the value to the default, but the key stays, and
`:exists` still finds it; only `:delete` removes a key. `is default` changes
what a missing key reads as, but the key does not exist because of it.

```raku
my %h = a => 1;
%h<a> = Nil;
say %h.raku;
say %h<a>:exists;
%h<a>:delete;
say %h<a>:exists;
my %z is default(0);
say %z<n>;
say %z<n>:exists;
```
```output
{:a(Any)}
True
False
0
False
```

## `:k`, `:v`, `:kv` and `:p` skip missing keys unless negated

`:k` returns keys, `:v` values, `:kv` keys and values interleaved, and `:p`
Pairs. All four leave out keys that do not exist, so a slice with one of
them answers only for the keys that are there. Negated, as `:!k`, `:!kv` or
`:!p`, they keep the missing keys; `:!v` is the same as no adverb.

```raku
my %h = a => 1;
say (%h<a z>:k).raku;
say (%h<a z>:v).raku;
say (%h<a z>:kv).raku;
say (%h<a z>:p).raku;
say (%h<a z>:!kv).raku;
say (%h<a z>:!p).raku;
say (%h<z>:p).raku;
```
```output
("a",)
(1,)
("a", 1)
(:a(1),)
("a", 1, "z", Any)
(:a(1), :z(Any))
()
```

On a single key, the adverbs return a single value, such as `:a(1)` for
`%h<a>:p`, and the empty list for a key that is not there.

## `:exists` and `:delete` combine with `:kv` and `:p`, not `:k`

`:exists` and `:delete` combine with `:kv` and `:p`, and each answer then
comes paired with its key, for the keys that exist. With `:exists` the Bool
takes the value's place. Missing keys are left out even under `:!exists`,
which therefore pairs every key it lists with False. `:delete:exists` deletes
and reports whether the key was there. `:exists:k` is refused: the subscript
returns a Failure of type `X::Adverb`.

```raku
my %h = a => 1, b => 2, c => 3;
say %h<a z>:exists:kv;
say %h<a z>:!exists:p;
say %h<a>:delete:exists;
say %h<a>:delete:exists;
say (%h<b z>:delete:p).raku;
my $f = %h<c>:exists:k;
say $f.exception.message;
```
```output
(a True)
(a => False)
True
False
(:b(2),)
Unsupported combination of adverbs ('exists', 'k') passed to slice on
'%h'.
```

An adverb that subscripts do not know, such as `%h<a>:foo`, throws the same
`X::Adverb`, with the message *Unexpected adverb 'foo' passed to slice on
'%h'*.

## An adverb after an operator belongs to the operator
tags: trap

An adverb is not part of the subscript. Rakudo attaches it to the loosest
operator on its left that binds tighter than item assignment, and gives it to
the subscript only when there is no such operator. `%h<a>:exists` alone is
fine, and so is `my $e = %h<a>:exists`. After `1 +`, the `+` receives
`:exists` as a named argument and finds no candidate that takes it; a leading
`!` gets a run-time hint. Parentheses give the adverb back to the subscript:

```raku
my %h = a => 1;
say (try 1 + %h<a>:exists) // $!.^name;
say (try !%h<a>:exists) // $!.message;
say 1 + (%h<a>:exists);
say !(%h<a>:exists), " ", %h<a>:!exists;
```
```output
X::Multi::NoMatch
Precedence issue with ! and :exists, perhaps you meant :!exists?
2
False False
```

Comparisons, `&&`, `||`, `//` and the ternary refuse an adverb at compile
time. The comma, `=>`, assignment and the word operators `and`, `or` and
`not` are looser, so `%h<a>:exists and %h<z>:exists` works as written.

```raku
my %h = a => 1;
say %h<a>:exists && %h<z>:exists;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
You can't adverb &infix:<&&>
at example.raku:2
------> say %h<a>:exists && %h<z>:exists<HERE>;
    expecting any of:
        pair value
```

## `%h{*}` is every value, and `%h{}` is the hash itself

A slice returns one value per key, `Any` for a missing one, and it can be
assigned to as a list. `*` in the braces selects every key, so `%h{*}` is all
the values, in the hash's own order. Empty braces or angle brackets, the *zen
slice*, return the hash itself, and they take adverbs like any other
subscript, as does `%h{*}`: `%h{*}:k` is every key, and `%h{*}:delete`
empties the hash.

```raku
my %h = a => 1, b => 2;
my @k = <b z>;
say %h{@k}.raku;
%h<x y> = 10, 20;
say %h{*}.sort;
say %h{} =:= %h;
say (%h{*}:k).sort;
%h{*}:delete;
say %h.elems;
```
```output
(2, Any)
(1 2 10 20)
True
(a b x y)
0
```

## `%h{'a';'b'}` reaches into nested hashes and returns a list
tags: quirk

`%h{'a';'b'}` is a subscript in two dimensions: it looks up `'a'` and then
`'b'` in the hash it finds, like `%h<a><b>`. A `*` in a dimension collects
from every nested hash. With one key per dimension, though, the result is
still a list of one element, where the array form `@a[0;1]` returns the
element itself. The list numifies to its length, and `++` refuses it;
assignment works, because it is a list assignment.

```raku
my %h = a => { b => 5 }, c => { b => 6 };
say %h{'a';'b'}.raku;
say %h{*;'b'}.sort;
say %h{'a';'b'} + 1;
say %h<a><b> + 1;
my @a = [1, 2], [3, 4];
say @a[0;1].raku;
say (try %h{'a';'b'}++) // $!.^name;
```
```output
(5,)
(5 6)
2
6
2
X::Multi::NoMatch
```

`%h<a;b>` is not the same thing: the word quote holds one word, so it is the
key `"a;b"`.

## `%h.push(a => 1)` pushes nothing
tags: trap

`a => 1` in an argument list is a named argument. `Hash.push` has no use for
named arguments and ignores them, so the first two pushes below change
nothing and say nothing; the colon form of a method call does not help.
Parentheses, a quoted key or a Pair in a variable make a positional Pair.

```raku
my %h;
%h.push(a => 1);
%h.push: b => 2;
say %h.elems;
%h.push((a => 1));
%h.push("b" => 2);
say %h;
```
```output
0
{a => 1, b => 2}
```

`%h.append` behaves the same way. So does slipping a hash into the call,
`%h.push(|%other)`, which turns every pair into a named argument ([see
below](#ch:hashes:h-passes-the-pairs-as-named-arguments)).

## `push` stacks the values of a repeated key into an Array

`push` does not replace an existing value. The first push of a key stores the
value; a second turns the slot into an Array holding both, and later values
are added to that Array. `append` does the same, but spreads a list value into
the Array, where `push` adds the list as one element.

```raku
my %h;
%h.push((a => $_)) for 1..3;
say %h.raku;
my %p = a => 1;
%p.push((a => (2, 3)));
say %p.raku;
my %q = a => 1;
%q.append((a => (2, 3)));
say %q.raku;
```
```output
{:a($[1, 2, 3])}
{:a($[1, (2, 3)])}
{:a($[1, 2, 3])}
```

`push` cannot tell an Array that it built from an Array that was already the
value. It pushes onto whatever Array it finds, and since hash assignment
shares a value that is an Array, it can reach an array outside the hash:

```raku
my @list = 1, 2;
my %h = a => @list;
%h.push((a => 3));
say @list;
```
```output
[1 2 3]
```

## Assignment merges hashes by replacing, `push` by stacking

Both can combine two hashes. List assignment keeps the last value of a
repeated key; `push` keeps them all. `push` returns the hash, so calls can be
chained.

```raku
my %a = x => 1, y => 2;
my %b = y => 20, z => 30;
my %replaced = %a, %b;
say %replaced;
my %stacked = %a;
%stacked.push(%b);
say %stacked;
```
```output
{x => 1, y => 20, z => 30}
{x => 1, y => [2 20], z => 30}
```

A key without a value is fatal to assignment. `push` only warns, and drops
it; a lazy list it refuses with `X::Cannot::Lazy`.

```raku
my %h;
%h.push("a", 1, "b");
say %h;
```
```output
{a => 1}
```
```stderr
Trailing item in Hash.push
  in block <unit> at example.raku line 2
```

## `|%h` passes the pairs as named arguments

A hash slipped into an argument list with `|` becomes named arguments, one per
pair, and `.Capture` makes the same named arguments into a Capture. This is
the usual way to pass options collected in a hash, and the reason
`%h.push(|%other)` pushes nothing. A single Pair slips the same way, but its
own `.Capture` is different: it holds the Pair's two attributes, `key` and
`value`.

```raku
sub f(:$a = 0, :$b = 0) { "a=$a b=$b" }
my %args = a => 1, b => 2;
say f(|%args);
say f(|(a => 5));
say %(a => 1).Capture.raku;
say (a => 1).Capture.raku;
my %h;
%h.push(|%args);
say %h.elems;
```
```output
a=1 b=2
a=5 b=0
\(:a(1))
\(:key("a"), :value(1))
0
```

## `.invert` spreads list values; `.antipairs` does not

Both swap keys and values. `.antipairs` makes one Pair for each pair, whatever
the value; `.invert` makes one Pair for each element of a list value. Neither
returns a hash. Turning the result into one with `.hash` keeps one pair per
value, so when two keys share a value, only one of them survives; `push`
keeps them all.

```raku
my %h = a => (1, 2), b => 3;
say %h.antipairs.sort(*.value).raku;
say %h.invert.sort.raku;
my %dup = a => 1, b => 1;
say %dup.invert.hash.elems;
my %all;
%all.push($_) for %dup.invert;
say %all<1>.sort;
```
```output
((1, 2) => "a", 3 => "b").Seq
(1 => "a", 2 => "a", 3 => "b").Seq
1
(a b)
```

A Pair held in a variable, like `$_` here, is a positional argument, so
`push` receives it.

## List methods see pairs, and pairs compare by key

`.sort`, `.max`, `.grep`, `.map` and the other list methods treat a hash as
its list of Pairs. Pairs compare by key first, so `.sort` orders a hash by
key, and `.max` returns the pair with the greatest key, not the greatest
value. The results are Pairs, not a hash; `.hash` makes one again.

```raku
my %h = a => 10, b => 1, c => 5;
say %h.max;
say %h.max(*.value);
say %h.sort(-*.value);
say %h.grep(*.value > 2).^name;
say %h.grep(*.value > 2).hash;
```
```output
c => 5
a => 10
(a => 10 c => 5 b => 1)
Seq
{a => 10, c => 5}
```

The keys of a plain hash are strings, so a hash with numbers for keys sorts
them as strings unless told otherwise:

```raku
my %n = 10 => "x", 9 => "y";
say %n.sort;
say %n.sort(*.key.Int);
```
```output
(10 => x 9 => y)
(9 => y 10 => x)
```

## `.fmt` formats each pair, and `.roll` and `.pick` return Pairs

`.fmt` formats every pair with a format that takes the key and then the
value, `"%s\t%s"` by default, and joins the results with a newline or with
the separator given. A format with a single directive gets only the keys.
Like every walk through a hash, it follows the hash's own order, so sort
first when the order matters. `.roll` and `.pick` choose Pairs, and `.roll`
on an empty hash returns `Nil`.

```raku
my %h = a => 1, b => 2;
say %h.sort.fmt("%s=%s", ", ");
say %h.fmt("%s").lines.sort;
say %h.roll.^name;
say %h.pick(*).sort;
say %().roll.raku;
```
```output
a=1, b=2
(a b)
Pair
(a => 1 b => 2)
Nil
```

## A hash in numeric context is its size
tags: trap

`+%h` and `.Int` give the number of pairs, and `?%h` whether there are any.
`==` compares numbers, so two hashes with the same number of pairs are `==`
whatever they hold. `eqv` compares the contents: the same type, the same keys
and equivalent values, in any order. 1 and 1.0 are not equivalent, and a
Hash is never `eqv` to a Map or to an object hash. `===` is identity.

```raku
my %h = a => 1;
say %h == %(b => 5);
say +%h, " ", ?%h, " ", ?%();
say %h eqv %(a => 1);
say %h eqv %(a => 1.0);
say %h eqv Map.new((a => 1));
say %h eqv :{ a => 1 };
say %(a => 1) === %(a => 1);
```
```output
True
1 True False
True
False
False
False
False
```

## Smartmatching against a hash asks about its keys
tags: trap

With a hash on the right of `~~`, a string asks whether it is a key, a list
whether any of its elements is, and a regex whether any key matches. A hash
on the left is compared with `eqv`, so a Map with the same pairs does not
match. A Pair on the left is not taken apart: its string form, `key\tvalue`,
is looked up as a key.

```raku
my %h = a => 1, b => 2;
say "a" ~~ %h;
say <z a> ~~ %h;
say /^b/ ~~ %h;
say %(b => 2, a => 1) ~~ %h;
say Map.new((a => 1, b => 2)) ~~ %h;
say (a => 1) ~~ %h;
say (a => 1) ~~ %("a\t1" => 0);
```
```output
True
True
True
True
False
False
True
```

String methods reach a hash through its Str form, which holds the values as
well as the keys. `.contains` warns about it:

```raku
my %h = a => 1;
say %h.contains("1");
```
```output
True
```
```stderr
Applying '.contains' to a Hash will look at its .Str representation.
Did you mean 'Hash{needle}:exists'?
  in block <unit> at example.raku line 2
```

## `.Set`, `.Bag` and `.Mix` read the values as weights

Coercing a hash to a set type keeps its keys and reads each value as a
weight. A Set keeps the keys whose values are true, a Bag those with a
positive count, and a Mix every non-zero weight, negative ones included.

```raku
my %h = a => 2, b => 0, c => -1;
say %h.Set.keys.sort;
say %h.Bag.pairs.sort;
say %h.Mix.pairs.sort;
```
```output
(a c)
(a => 2)
(a => 2 c => -1)
```

The set types themselves are in [Sets, Bags and Mixes](#ch:sets).

## A Map prints as `Map.new`, and converts to and from a Hash

`Map.new` takes a list of pairs, or of keys and values, and its `.raku` is a
call to itself, with no space after the commas between pairs; an empty Map is
just `Map.new`. `say` prints the same call with each pair in its gist form. A
`%` variable declared `is Map` holds a Map, filled by its initial assignment.
`.Hash` and `.Map` convert between the two.

```raku
say Map.new((a => 1, b => 2)).raku;
say Map.new.raku;
my %m is Map = a => 1, b => 2;
say %m.^name;
say %m;
say %m.Hash.^name;
say %(a => 1).Map.^name;
```
```output
Map.new((:a(1),:b(2)))
Map.new
Map
Map.new((a => 1, b => 2))
Hash
Map
```

## A Map refuses new keys and deletions; missing keys are Nil

A Map is fixed once built. Adding a key dies, deleting one dies, and assigning
to a `%` variable that holds a Map throws `X::Assignment::RO`. Assigning to an
existing key dies too, unless the value is a container, as [Containers and
Binding](#ch:containers:a-map-is-immutable-but-the-containers-inside-it-are-not)
shows. A Map has no default, so a missing key reads as `Nil`, not `Any`. Its
`.clone` returns the Map itself.

```raku
my %m is Map = a => 1;
try { %m<b> = 2 };
say $!.message;
try { %m<a>:delete };
say $!.message;
try { %m = b => 2 };
say $!.^name;
say %m<z>.raku;
say %m.clone === %m;
```
```output
Cannot add key 'b' to an immutable Map
Can not remove values from a Map
X::Assignment::RO
Nil
True
```

Binding a key, `%m<a> := 2`, throws `X::Bind`, and calling `.default` on a Map
is `X::Method::NotFound`.

## A Pair's `.raku` uses the colon form only for identifier keys

`.raku` writes `:key(value)` when the key is a string that could be an
identifier, which includes an inner hyphen or apostrophe and non-ASCII
letters. Any other key gets the arrow form, quoted if it is a string. A true
or false value shortens to `:key` or `:!key`. A hash's `.raku` uses the same
forms for its keys, but writes Bool values in full.

```raku
say (a => 1).raku;
say ("a-b" => 1).raku;
say ("a b" => 1).raku;
say ("1" => 1).raku;
say (1 => "a").raku;
say (a => True).raku, " ", (a => False).raku;
say %(a => True, "b c" => 1).raku;
```
```output
:a(1)
:a-b(1)
"a b" => 1
"1" => 1
1 => "a"
:a :!a
{:a(Bool::True), "b c" => 1}
```

The gist is `a => 1`, and the Str form `a`, a tab and `1`.

## A Pair is a hash of one pair, and always true

A Pair answers the hash methods as a one-element hash: `.keys`, `.values`,
`.kv`, `.pairs` and `.elems` work, and so does a subscript with its key. Any
other key returns `Nil`, as in a Map. As a Bool, a Pair is always `True`,
even when its value is false.

```raku
my $p = a => 0;
say $p.kv.raku;
say $p.elems;
say $p<a>;
say $p<b>.raku;
say $p<a>:exists;
say $p.Bool;
say $p.value.Bool;
```
```output
("a", 0).Seq
1
0
Nil
True
True
False
```

`.antipair` swaps the key and the value, and `Pair.new("a", 1)` and
`pair("a", 1)` build a Pair from a key that need not be a bareword.

## `cmp` orders pairs by key, then by value

Two Pairs compare with `cmp` by key, and by value when the keys are the same.
Keys compare as `cmp` would compare them on their own, so numbers compare as
numbers and strings as strings. `eqv` wants equal types as well, so 1 and 1.0
differ. There is no numeric comparison: a Pair does not numify, and `==` dies.

```raku
say (a => 1) cmp (a => 2);
say (a => 9) cmp (b => 0);
say (10 => "x") cmp (9 => "y");
say ("10" => "x") cmp ("9" => "y");
say (b => 1, a => 2, a => 1).sort;
say (a => 1) eqv (a => 1.0);
say (try (a => 1) == (a => 1)) // $!.^name;
```
```output
Less
Less
More
Less
(a => 1 a => 2 b => 1)
False
X::Multi::NoMatch
```

## `$x ~~ :method` calls the method and compares truthiness
tags: trap

A Pair on the right of `~~`, with anything but a Pair on the left, is a
method test. The key names a method, which is called on the topic, and the
match succeeds when the result and the Pair's value are both true or both
false. The result is not compared with the value: `"abc" ~~ (chars => 5)` is
True, because 3 and 5 are both true. The colonpair forms read well for
methods that answer yes or no, as in `when :is-prime`. A method the topic does
not have throws.

```raku
say 7 ~~ :is-prime;
say 42 ~~ :is-prime;
say "" ~~ :!chars;
say "abc" ~~ (chars => 3);
say "abc" ~~ (chars => 5);
say (try 42 ~~ :even) // $!.^name;
```
```output
True
False
True
True
True
X::Method::NotFound
```

## A Pair on both sides smartmatches key and value

With Pairs on both sides, the right Pair's key and value each smartmatch
against the left Pair's. A type on the right therefore accepts any value of
that type, but a type on the left is not matched by a value. The key on the
right follows the bareword rule: `(Str => 1)` wants the key `"Str"`, and the
type needs parentheses.

```raku
say (a => 1) ~~ (a => 1);
say (a => 1) ~~ (a => Int);
say (a => Int) ~~ (a => 1);
say (a => 1) ~~ (Str => 1);
say (a => 1) ~~ ((Str) => 1);
say (a => 1) ~~ (/a/ => 1);
```
```output
True
True
False
False
True
True
```
