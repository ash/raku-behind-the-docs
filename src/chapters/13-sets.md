---
title: Sets, Bags and Mixes
part: Collections
summary: A Set, a Bag and a Mix weigh their elements as a truth value, a count and a real number; elements are compared by identity, the hash forms can change, and every set operator picks its result type from the richer of its operands.
---

Raku has six types for collections in which each element counts. A **Set**
says whether an element is there. A **Bag** says how many times it is there,
as a positive whole number. A **Mix** gives it a *weight*, any real number,
fractional or negative. Each is immutable and has a mutable twin: a
**SetHash**, a **BagHash** and a **MixHash**, called the *hash forms* in this
chapter. The six together are the *QuantHash* types.

Unlike a hash, these types keep their elements as objects and compare them by
identity, so the number 1 and the string "1" are two elements. The set
operators, `∈`, `∪`, `∩`, `⊆` and the rest, accept all six and ordinary
lists and hashes as well, and choose the type of their result from their
operands.

Hashes, and what their coercion to a Set does with the values, are in
[Hashes, Maps and Pairs](#ch:hashes); where the set operators sit among the
others is in [Who Takes the Operand](#ch:precedence). A Set keeps its elements
in no particular order, and the order changes from one run to the next: `say`
sorts them ([below](#ch:sets:say-sorts-the-elements-str-and-raku-do-not)),
and every other list of elements in this chapter is sorted before it is
printed.

## A Set holds an element once; a Bag and a Mix weigh it

The subs `set`, `bag` and `mix` build the immutable types from their
arguments. A subscript asks for an element's weight: `True` or `False` in a
Set, a count in a Bag, a number in a Mix. A missing element answers the zero
of that kind, and `.of` names the kind.

```raku
my $s = set <b a b>;
my $b = bag <b a b>;
my $m = ("a" => 1.5, "b" => -2).Mix;
say $s;
say $b;
say $m;
say $s<b>, " ", $b<b>, " ", $m<b>;
say $s<z>, " ", $b<z>, " ", $m<z>;
say Set.of.^name, " ", Bag.of.^name, " ", Mix.of.^name;
```
```output
Set(a b)
Bag(a b(2))
Mix(a(1.5) b(-2))
True 2 -2
False 0 0
Bool UInt Real
```

`say` writes a weight in parentheses after its element and leaves it out
when it is 1.

## Elements are the same only when they are identical
tags: trap

Two values are one element when they are identical, the test that `===`
makes, not when they print alike or are numerically equal. The Int 1, the Str
"1", the Rat 1.0, the Num 1e0 and the allomorph `<1>` are five elements.
`1/1` is the same Rat as 1.0, and `True` is not 1. Exact numbers that are
equal are identical, while two floating-point numbers that differ in the last
bit are not:

```raku
my $s = Set.new(1, "1", 1.0, 1e0, <1>);
say $s.elems;
say $s.keys.map(*.^name).sort;
say 1/1 ∈ $s;
say set(True, 1, "True").elems;
say set(0.1 + 0.2, 0.3).elems;
say set(0.1e0 + 0.2e0, 0.3e0).elems;
```
```output
5
(Int IntStr Num Rat Str)
True
3
1
2
```

The allomorph is the one that catches people. A word list such as `<1 2 3>`
holds `IntStr` values, so `1 ∈ <1 2 3>` is False: the list becomes a set of
three allomorphs, and the Int 1 is not among them ([Quotes and
Interpolation](#ch:quotes:numbers-in-a-word-list-become-allomorphs)).
[Strings](#ch:strings:smartmatch-reads-one-half-of-an-allomorph-sets-want-both)
shows how to numify the words first.

## Arrays and Lists are elements by identity; Pairs, Ranges and Sets by value

An Array, a List or a SetHash is an object with an identity of its own. Two
that look alike are two elements, and only the very object that went in finds
its element again. A Pair, a Range, a Set, a Bag or a Date is a *value type*:
its identity is its contents, so equal ones are one element.

```raku
say Set.new([1], [1]).elems;
say Set.new((1, 2), (1, 2)).elems;
say Set.new("a" => 1, "a" => 1).elems;
say Set.new(1..2, 1..2).elems;
say Set.new(set(<a>), set(<a>)).elems;
say Set.new(SetHash.new(<a>), SetHash.new(<a>)).elems;
my @a = 1;
my $s = Set.new(@a, @a);
say @a ∈ $s, " ", [1] ∈ $s;
```
```output
2
2
1
1
1
2
True False
```

## Every empty Set is the same object

However an empty Set, Bag or Mix comes about, from a constructor, a
coercion, a conversion or an operator, it is one and the same object, which
`.raku` writes as `set()`, `bag()` or `mix()`. A hash form is a fresh object
every time, since it may be changed later.

```raku
say Set.new =:= set();
say ().Set =:= set();
say SetHash.new.Set =:= set();
say (set(<a>) ∩ set(<b>)) =:= set();
say bag() =:= ().Bag;
say SetHash.new =:= SetHash.new;
say set().raku, " ", bag().raku, " ", mix().raku;
```
```output
True
True
True
True
True
False
set() bag() mix()
```

## `set` flattens one level; `.new` keeps several arguments whole

`.new` follows the single-argument rule of lists ([Lists, Arrays, Seqs and
Slips](#ch:lists:one-list-argument-is-the-list-several-are-its-elements)): a
single iterable argument gives its elements, and several arguments are one
element each. The subs `set`, `bag` and `mix` go one step further and flatten
every argument one level, so two lists give four elements. Neither looks
inside an itemized argument, `$[1, 2]`, nor inside another Set, Bag or Mix,
which is always one element:

```raku
say Set.new([1, 2]).elems;
say Set.new($[1, 2]).elems;
say Set.new((1, 2), (3, 4)).elems;
say set((1, 2), (3, 4)).elems;
say set([1, 2], [3, 4]).elems;
say set($[1, 2]).elems;
say set(set(<a b>)).keys[0].^name;
```
```output
2
1
2
4
4
1
Set
```

## A Pair given to `set` is an element, not a weight
tags: trap

The constructors do not read a Pair as an element with a weight. A Pair
passed as a positional argument, which is any Pair whose key is quoted or not
an identifier, becomes an element of type Pair: `bag(10 => 1, 9 => 2)` is a
bag of two Pairs. A Pair written with a bare identifier key, `a => 1` or
`:a`, is a *named* argument. The subs refuse it, and `.new` drops it without
a word.

```raku
say set("a" => 1).keys[0].raku;
say bag(10 => 1, 9 => 2).keys.map(*.^name);
say Bag.new("a" => 3).pairs.raku;
try { set(a => 1) };
say $!.^name;
say Set.new(a => 1).elems;
say Bag.new(a => 3, "b");
```
```output
:a(1)
(Pair Pair)
((:a(3)) => 1,).Seq
X::Multi::NoMatch
0
Bag(b)
```

To read Pairs as weights, use a coercer or `new-from-pairs`
([below](#ch:sets:set-bag-and-mix-read-a-pairs-value-in-three-ways)).

## The coercers flatten all the way down and read Pairs as weights

`.Set`, `.Bag`, `.Mix` and their hash-form twins flatten a list at every
depth, except for an itemized list, which stays one element. Each Pair in the
list is read as an element with its weight, and so is a lone Pair. A Hash
gives its keys, weighted by its values ([Hashes, Maps and
Pairs](#ch:hashes:set-bag-and-mix-read-the-values-as-weights)); since those
keys are strings, a Pair and a Hash with the "same" key give elements of
different types. Anything else is one element, a string included.

```raku
say (1, (2, (3, 4))).Set.elems;
say ($[1, 2], 3).Set.elems;
say ("a" => 2, "b" => 0, "c", "a").Bag;
say (a => 0).Set;
say (1 => 2).Bag.keys[0].^name;
say { 1 => 2 }.Bag.keys[0].^name;
say "ab".Set;
try { Mu.Set };
say $!.^name;
```
```output
4
2
Bag(a(3) c)
Set()
Int
Str
Set(ab)
X::Method::NotFound
```

A single value, a type object or even Nil becomes a set of one element
([Nil, Any and the Undefined](#ch:nil-any:a-set-or-junction-of-one-value-holds-it-even-nil));
only `Mu` has no coercer.

## Set, Bag and Mix read a Pair's value in three ways

When a coercer or `new-from-pairs` reads `element => value`, each type does
something different with the value. A Set includes the element when the
value is true. A Bag takes the value's `.Int`, so 2.9 counts 2, the string
"3" counts 3 and `True` counts 1, and a repeated element adds up. A Mix takes
the value's `.Real`, so "3" becomes the Int 3 and a Num stays a Num. Anything
that is not a Pair weighs 1.

```raku
say ("a" => 1, "b" => 0, "c" => "", "d" => "x").Set;
say ("a" => 2.9, "b" => "3", "c" => True, "a" => 1).Bag;
say ("a" => 2.9e0, "b" => "3", "c" => 1/3).Mix;
say ("b" => "3").Mix<b>.^name;
say Bag.new-from-pairs("a" => 2, "b").pairs.sort;
```
```output
Set(a d)
Bag(a(3) b(3) c)
Mix(a(2.9) b(3) c(0.333333))
Int
(a => 2 b => 1)
```

## A negative weight is skipped by a Bag and subtracted by a Mix
tags: quirk

When the same element comes with several weights, a Bag adds the positive
ones and skips any that are zero or negative; it never subtracts. A Mix adds
them all, negative ones included, and removes an element whose sum is zero.

```raku
say (a => 3, a => -2).Bag;
say (a => 2, a => -2).Bag;
say (a => 3, a => -2).Mix;
say (a => 2, a => -2).Mix;
say (a => -2, "b").Mix;
```
```output
Bag(a(3))
Bag(a(2))
Mix(a)
Mix()
Mix(a(-2) b)
```

## A weight that is not a finite real number throws
tags: undocumented

A Bag refuses a string that is not a number with `X::Str::Numeric`, an
infinity or NaN with `X::Numeric::CannotConvert` (neither has an `.Int`),
and a Complex number with `X::Numeric::Real`. A Mix refuses the same values,
but reports an infinity or NaN as `X::OutOfRange`. The refusal is thrown at
once, not returned as a Failure.

```raku
for "x", Inf, NaN, 3i -> $w {
    try { ("a" => $w).Bag };
    say "Bag {$w.raku}: ", $!.^name;
}
for "x", Inf, NaN, 3i -> $w {
    try { ("a" => $w).Mix };
    say "Mix {$w.raku}: ", $!.^name;
}
try { ("a" => Inf).Mix };
say $!.message;
```
```output
Bag "x": X::Str::Numeric
Bag Inf: X::Numeric::CannotConvert
Bag NaN: X::Numeric::CannotConvert
Bag <0+3i>: X::Numeric::Real
Mix "x": X::Str::Numeric
Mix Inf: X::OutOfRange
Mix NaN: X::OutOfRange
Mix <0+3i>: X::Numeric::Real
Value out of range. Is: Inf, should be in -Inf^..^Inf
```

## The string `"Inf"` slips into a Mix
tags: quirk undocumented

A Mix tests for an infinite weight only when the weight arrives as a
floating-point number. The string "Inf" is converted after that test, and
the Mix accepts the infinity it turns into. A Bag converts first and refuses
it. A Range as a Bag weight counts its elements, because that is a Range's
`.Int`.

```raku
say ("a" => "Inf").Mix;
try { ("a" => Inf).Mix };
say $!.^name;
try { ("a" => "Inf").Bag };
say $!.^name;
say ("a" => 1..3).Bag;
```
```output
Mix(a(Inf))
X::OutOfRange
X::Numeric::CannotConvert
Bag(a(3))
```

## A lazy list cannot become a Set, and an infinite Range is lazy
tags: undocumented

The constructors and coercers need every element, so given a lazy list they
return a Failure carrying `X::Cannot::Lazy`. `∈` with a lazy right side fails
the same way, and an infinite Range counts as lazy; only a finite Int Range is
tested by arithmetic, so even a huge one answers at once. The operators that
build a new collection throw instead of failing.

```raku
my $s = (1..*).Set;
say $s.^name;
say $s.exception.message;
say (1 ∈ 1..*).exception.message;
say 10**42 ∈ 0..10**42;
try { set(1) ∪ (1..*).map(* * 2) };
say $!.^name;
```
```output
Failure
Cannot coerce a lazy list onto a Set
Cannot (elem) a lazy list
True
X::Cannot::Lazy
```

The methods that change a hash form, `.set`, `.unset`, `.add` and `.remove`,
make no such check. Given an infinite list they never return:

```raku nocheck
my $s = SetHash.new;
$s.set(1..*);
say "never printed";
```

## `⊆`, `≡` and `⊂` call a lazy operand ambiguous
tags: quirk undocumented

The Boolean set operators coerce a lazy operand to a Set, get the Failure of
the previous corner, and then find that two of their own candidates accept a
Failure. What reaches the program is `X::Multi::Ambiguous`, with the real
reason listed under "Earlier failures" in its message. The operators that
build a result report `X::Cannot::Lazy`:

```raku
try { set(1) ⊆ (1..*) };
say $!.^name;
try { set(1) ≡ (1..*) };
say $!.^name;
try { set(1) ⊂ (1..*) };
say $!.^name;
try { set(1) ∖ (1..*) };
say $!.^name;
```
```output
X::Multi::Ambiguous
X::Multi::Ambiguous
X::Multi::Ambiguous
X::Cannot::Lazy
```

## Converting to a narrower type drops weights that do not fit

A conversion keeps what the target type can hold. `.Set` of a Bag or a Mix
keeps the elements with a positive weight, so a Mix loses its negative
elements and keeps its fractional ones. `.Bag` of a Mix keeps each weight's
`.Int` and drops the elements that truncate to zero or less (but see [what
it does to the Mix](#ch:sets:bag-of-a-mix-truncates-the-mix-itself)). A
Set's elements weigh 1 in a Bag or a Mix.

```raku
my $m = ("a" => 2.7, "b" => -1, "c" => 0.4).Mix;
say $m.Set;
say $m.MixHash;
say <a a b>.Bag.Mix;
say set(<a b>).Bag;
say Set.Baggy.^name, " ", SetHash.Baggy.^name, " ", Mix.Setty.^name;
my \b = <a a b>.Bag;
say b.Bag =:= b, " ", b.Baggy =:= b;
```
```output
Set(a c)
MixHash(a(2.7) b(-1) c(0.4))
Mix(a(2) b)
Bag(a b)
Bag BagHash Set
True True
```

`.Setty`, `.Baggy` and `.Mixy` pick the type of the named kind with the same
mutability; on an instance, a conversion to its own type returns the
instance itself.

## A conversion from a hash form is a snapshot

`.Set` of a SetHash copies the elements: changing the SetHash afterwards does
not change the Set. `.SetHash` of a Set is a new SetHash every time, and
`.clone` of a hash form is independent of the original.

```raku
my $sh = SetHash.new(<a>);
my $s = $sh.Set;
my $c = $sh.clone;
$sh<b> = True;
say $s;
say $c;
say $sh;
my $s2 = set(<a>);
say $s2.SetHash =:= $s2.SetHash;
```
```output
Set(a)
SetHash(a)
SetHash(a b)
False
```

## `.Bag` of a Mix truncates the Mix itself
tags: bug unasserted

The documentation calls a Mix immutable and describes `.Bag` as a coercion
to a Bag. In Rakudo 2026.08, `.Bag` and `.BagHash` of a Mix or a MixHash also
rewrite the *source*: every weight of 1 or more becomes its `.Int`. Weights
below 1 are left as they were, and `.Set` and `.MixHash` do not touch the
source. A total computed before the conversion is remembered, so afterwards
the Mix no longer adds up:

```raku
my $m = ("a" => 2.7, "b" => 0.5).Mix;
say $m.total;
say $m.Bag;
say $m;
say $m.total;
say $m.values.sum;
```
```output
3.2
Bag(a(2))
Mix(a(2) b(0.5))
3.2
2.5
```

`$m.clone.Bag`, or `.Bag` of a Mix built for the purpose, keeps the original
intact.

## `Set[Str]` checks its elements and keeps its name

A parameterized type, `Set[Str]`, `Bag[Int]` and so on, accepts only
elements of the given type, without coercing them unless the parameter is a
coercion type such as `Int()`. The parameter shows in `.gist` and `.raku`,
and `.keyof` returns it; a plain Set's `.keyof` is Mu.

```raku
my $s = Set[Str].new(<a>);
say $s;
say $s.raku;
say $s.keyof.^name, " ", Set.keyof.^name;
try { Set[Int].new("1") };
say $!.^name;
say Set[Int()].new("3").keys[0].^name;
```
```output
Set[Str](a)
Set[Str].new("a")
Str Mu
X::TypeCheck::Binding
Int
```

A parameterized Set is never identical to a plain one with the same
elements. A set operator keeps the parameter of its *left* operand, and
checks the right operand's elements against it; a conversion drops it.

```raku
say Set[Int].new(1) === set(1);
say set(1) ~~ Set[Int];
say (Set[Int].new(1) ∪ set(2)).^name;
say (set(2) ∪ Set[Int].new(1)).^name;
try { Set[Int].new(1) ∪ set("x") };
say $!.^name;
say Set[Int].new(1).Bag.raku;
```
```output
False
False
Set[Int]
Set
X::TypeCheck::Binding
(1=>1).Bag
```

## `is Set` makes the variable a Set; `is SetHash` makes it assignable

A `%` variable declared `is Set` holds a Set, filled once by its initializer
and read-only afterwards. `is SetHash` and `is BagHash` variables can be
assigned again, which replaces their contents. The initializer is read like a
coercion, Pairs as weights:

```raku
my %s is Set = <a b a>;
say %s.^name, " ", %s<a>, " ", %s<z>;
try { %s = <c> };
say $!.^name;
my %h is SetHash = <a b>;
%h = <c d>;
say %h;
my %b is Bag = a => 2, b => 0;
say %b;
```
```output
Set True False
X::Assignment::RO
SetHash(c d)
Bag(a(2))
```

Assignment to a hash form calls its `STORE` method, which can also be called
with two lists, elements and weights. Repeated elements add up, and a short
list of weights is refused:

```raku
say BagHash.new.STORE(<a b c>, (1, 2, 4));
say BagHash.new.STORE(<a a>, (1, 2));
try { BagHash.new.STORE(<a b>, (2,)) };
say $!.^name;
```
```output
BagHash(a b(2) c(4))
BagHash(a(3))
X::Multi::NoMatch
```

## `my %h is Set;` without a value is unusable
tags: bug

The documentation lists `my %set is Set;`, with no initializer, as the way to
declare a Set variable. In Rakudo 2026.08 such a variable holds an object
that claims to be a Set but throws `X::AdHoc` from `.elems`, `.gist` and
`.raku`, with a message about a Scalar, while its `.keys` is empty. Being
immutable, it cannot be assigned afterwards either. `is Bag` behaves the
same, and `is SetHash` works:

```raku
my %h is Set;
say %h.^name;
try { %h.elems };
say $!.message;
try { %h = <a> };
say $!.^name;
my %e is Set = ();
say %e.elems;
my %sh is SetHash;
%sh<a> = True;
say %sh;
```
```output
Set
This type (Scalar) does not support elems
X::Assignment::RO
0
SetHash(a)
```

An initializer, even an empty list, gives a working empty Set.

## A Set's values are all True, and its total is its size

`.keys` returns the elements, `.values` a `True` for each, and `.pairs` the
two together. `.elems` and `.total` are both the number of elements, and so is
the Set in numeric context. `.default`, what a missing element reads as, is
`False`. `.minpairs` and `.maxpairs` return every pair, since all the weights
are equal.

```raku
my $s = set <b a>;
say $s.keys.sort;
say $s.values.raku;
say $s.pairs.sort;
say $s.elems, " ", $s.total, " ", +$s;
say $s.default;
say $s.minpairs.sort;
```
```output
(a b)
(Bool::True, Bool::True).Seq
(a => True b => True)
2 2 2
False
(a => True b => True)
```

## A Bag's total is the sum of its weights, and `.kxxv` repeats each key

In a Bag, `.elems` counts the distinct elements and `.total` adds up their
weights. `.kxxv` lists every element as many times as its weight.
`.minpairs` and `.maxpairs` return a List of the pairs with the smallest or
largest weight, ties included. `.default` is 0.

```raku
my $b = bag <b a a c c c>;
say $b.pairs.sort;
say $b.elems, " ", $b.total, " ", +$b;
say $b.kxxv.sort;
say $b.minpairs.raku;
say $b.maxpairs.raku;
say bag(<a a b b>).maxpairs.sort;
say $b.default;
```
```output
(a => 2 b => 1 c => 3)
3 6 6
(a a b c c c)
(:b(1),)
(:c(3),)
(a => 2 b => 2)
0
```

## A Mix's total is exact, may be negative, and has no `.kxxv`

A Mix keeps each weight as it was given, Int, Rat or Num, and adds them up
exactly: the total of 1.5, -2 and 1/3 is the Rat -1/6, and 0.1 plus 0.2 is
exactly 0.3. One Num weight makes the total a Num. A Mix is true whenever it
has an element, even when its total is negative. Repeating an element a
fractional number of times makes no sense, so `.kxxv` returns a Failure.

```raku
my $m = ("a" => 1.5, "b" => -2, "c" => 1/3).Mix;
say $m.total.raku;
say $m.Int;
say $m.minpairs, " ", $m.maxpairs;
say ("a" => 0.1, "b" => 0.2).Mix.total == 0.3;
say ("a" => -1).Mix.Bool;
say ("a" => 1e0, "b" => 1).Mix.total.^name;
say $m.kxxv.exception.message;
```
```output
<-1/6>
0
(b => -2) (a => 1.5)
True
True
Num
.kxxv is not supported on a Mix
```

## `say` sorts the elements; `.Str` and `.raku` do not
tags: trap

`.gist`, which `say` uses, writes each element with its weight and sorts the
results as strings, so 10 comes before 2 and capitals before lower case. A
weight is shown with its own `.gist`, so a third is rounded. `.raku` writes
weights exactly.

```raku
say set(1, 2, 10);
say set(<b B a A>);
say bag(<b a a>);
say set(Nil, Int, "x");
say ("a" => 1/3).Mix;
say ("a" => 1/3).Mix.raku;
```
```output
Set(1 10 2)
Set(A B a b)
Bag(a(2) b)
Set((Int) Nil x)
Mix(a(0.333333))
("a"=><1/3>).Mix
```

`.Str`, which `~`, `put` and interpolation use, and `.raku` list the elements
in storage order, which is different in every run, so only a collection of
one element prints the same way twice. `.Str` separates the elements with
spaces, which makes an element containing a space impossible to tell apart.
The empty immutable types print as their constructor subs:

```raku
say set(<a>).raku, " ", bag(<a a>).raku;
say SetHash.new.raku, " ", BagHash.new.raku, " ", MixHash.new.raku;
say set(<a>).Str, "|", bag(<a a>).Str, "|", ("a" => 2.5).Mix.Str;
say set("a b", "c").Str.chars;
say Set.gist, " ", Set.raku;
```
```output
Set.new("a") ("a"=>2).Bag
SetHash.new() ().BagHash ().MixHash
a|a(2)|a(2.5)
5
(Set) Set
```

## `.hash` keeps the elements as objects; `.Map` makes them strings

`.hash` returns a copy as an object hash ([Hashes, Maps and
Pairs](#ch:hashes:my-hany-keeps-keys-as-objects)) whose values are typed by
the kind of weight: Bool for a Set, UInt for a Bag, Real for a Mix. A value
outside that type cannot be stored in it. `.Hash` leaves the values
untyped. `.Map` turns every element into its string, so elements that print
alike collide, and which of their weights survives varies from run to run.

```raku
my $s = set(1, "1");
say $s.hash.^name;
say $s.hash.keys.map(*.^name).sort;
say $s.Map.elems, " ", $s.Map.keys;
my $b = bag <a a b>;
try { $b.hash<a> = -1 };
say $!.^name;
say $b.Capture.raku;
say $b.fmt("%s:%s", ";").split(";").sort;
```
```output
Hash[Bool,Mu,Any]
(Int Str)
1 (1)
X::TypeCheck::Assignment
\(:a(2), :b(1))
(a:2 b:1)
```

`.Capture` turns the pairs into named arguments, and `.fmt` formats each
pair, by default as the element and the weight separated by a tab.

## Set, Bag and Mix are values; the hash forms are objects
tags: undocumented

The immutable types are value types: two of them are identical, `===`, when
they have the same type, the same elements and the same weights, however they
were built. A weight of 1.0 is the same as 1. Two hash forms are identical
only when they are the same object, so `.unique` keeps both of two equal
SetHashes. A subclass of Set is a different type, and its instances are never
identical to a Set.

```raku
say set(<a b>) === set(<b a>);
say bag(<a a b>) === bag(<a b b>);
say mix(<a>) === ("a" => 1.0).Mix;
say set(<a>) === bag(<a>);
say SetHash.new(<a>) === SetHash.new(<a>);
say (set(<a>), set(<a>)).unique.elems;
say (SetHash.new(<a>), SetHash.new(<a>)).unique.elems;
class MySet is Set {}
say MySet.new(<a>) === set(<a>);
```
```output
True
False
True
False
False
1
2
False
```

## `eqv` wants the same type, `==` compares sizes and `cmp` the sorted pairs
tags: undocumented

`eqv` is True for two collections of the same type with the same contents,
two equal SetHashes included, and False across types. `==` is numeric
equality, and a QuantHash is a number by its total, so two Sets of the same
size are `==`. `cmp` compares the sorted pairs one by one, and since `True cmp
1` is `Same`, a Set and a Bag with the same elements of weight 1 are `Same`.
`<=>` compares the totals.

```raku
say set(<a>) eqv SetHash.new(<a>);
say SetHash.new(<a>) eqv SetHash.new(<a>);
say set(<a>) eqv bag(<a>);
say set(<a b>) == set(<c d>);
say bag(<a a>) == 2;
say set(<a b>) cmp set(<a c>);
say set(<a>) cmp bag(<a>);
say bag(<a a>) <=> bag(<b>);
```
```output
False
True
False
True
True
Less
Same
More
```

Use `≡` ([below](#ch:sets:compares-in-the-richer-type-of-its-two-operands))
to ask whether two collections have the same elements.

## Smartmatching against a Set converts the left side to a Set

A Set, Bag or Mix on the right of `~~` converts the left side to its own
type and tests the two for equality. Against a Set, a list with repeated
elements matches, and so does a Bag whatever its weights, and a string
matches a set of that one string. Against a Bag the weights count. A Hash is
converted by its values, as always.

```raku
say <b a b> ~~ set(<a b>);
say bag(<a a b>) ~~ set(<a b>);
say set(<a b>) ~~ bag(<a a b>);
say { a => 1, b => 0 } ~~ set(<a>);
say { a => 2 } ~~ bag(<a a>);
say "a" ~~ set(<a>);
say "a" ~~ set(<a b>);
say "42" ~~ set(42);
```
```output
True
True
False
True
True
True
False
False
```

A type object on the right tests the type, as usual. A Set does the roles
`Setty`, `QuantHash` and `Associative`, and a Bag is not `Setty`. None of the
six is `Iterable` or `Positional`. The type object `Set` on the left becomes
a set holding itself, so it does not match the empty set:

```raku
say set(<a>) ~~ Setty;
say bag(<a>) ~~ Setty;
say mix(<a>) ~~ Baggy;
say set(<a>) ~~ Associative;
say set(<a>) ~~ Iterable;
say Set ~~ set();
say Set.^roles.map(*.^name);
```
```output
True
False
True
True
False
False
(Setty QuantHash Associative)
```

## A Bag in a `$` variable is one item; a bare Bag gives its Pairs

A QuantHash is not `Iterable`, but `for` and array assignment ask it for its
list, which is its Pairs. Held in a `$` variable it is an item, and an item
is one element: `for $b` runs once, with the Bag itself, and `my @a = $b`
makes an array of one Bag ([Containers and
Binding](#ch:containers:for-iterates-an-item-once)). The zen slice `$b<>`, or
a Bag written directly, gives the Pairs.

```raku
my $b = bag <b a a>;
for $b { say .^name }
for $b<> { say .^name }
my @a = $b;
say @a.elems;
my @p = bag <b a a>;
say @p.sort;
```
```output
Bag
Pair
Pair
1
(a => 2 b => 1)
```

The list methods work on the Pairs too. `.sort` orders them by element and
then by weight, `.max` and `.min` take a key function, and `.sum` refuses to
add Pairs. A positional subscript treats the Bag as a single value: index 0
is the Bag itself, and anything beyond is out of range.

```raku
my $b = bag <b a a>;
say $b.sort;
say $b.map(*.key).sort;
say $b.grep(*.value > 1);
say $b.max(*.value);
say $b[0].^name;
try { $b[1] };
say $!.^name;
try { $b.sum };
say $!.^name;
```
```output
(a => 2 b => 1)
(a b)
(a => 2)
a => 2
Bag
X::OutOfRange
X::Multi::NoMatch
```

## In numeric context a QuantHash is its total, and it is not Cool
tags: undocumented

`+`, `==`, `<` and the other numeric operators use the total, and smartmatch
against a number compares it too. `~` uses `.Str`. A QuantHash is true when
it has at least one element, even a Mix whose weights are all negative. It is
not `Cool`, so the string and number methods that `Cool` provides, `.chars`,
`.succ`, `.abs` and the rest, do not exist on it.

```raku
say set(<a b>) + 1;
say bag(<a a>) * 2;
say +("a" => 0.5, "b" => -2).Mix;
say set(<a b>) ~~ 2;
say ~bag(<a a>);
say ?("a" => -1).Mix;
say set() || "empty";
try { set(<a>).chars };
say $!.^name;
```
```output
3
4
-1.5
True
a(2)
True
empty
X::Method::NotFound
```

## The type object `Set` counts as one element of itself
tags: undocumented

Called on the type object, the methods that any single value answers treat
`Set` as one value: `.elems` is 1, `.list` holds `Set`, and `.Set` is a set
containing the type object. The methods that need an actual collection
refuse, with `X::Parameter::InvalidConcreteness` or `X::Multi::NoMatch`.
`.pick` is the one every value has, and returns the type object.

```raku
say Set.elems;
say Set.Bool;
say Set.list.raku;
say Set.keys.raku;
say Set.Set;
try { Set.total };
say $!.^name;
try { Set.roll };
say $!.^name;
say Set.pick.raku;
```
```output
1
False
(Set,)
()
Set((Set))
X::Parameter::InvalidConcreteness
X::Multi::NoMatch
Set
```

## A subscript on a Set answers a Bool, and assigning to it dies

A subscript on an immutable type returns the weight as a plain value, not a
container. Several keys return a List of weights, and the adverbs `:exists`,
`:p` and the rest work as on a hash.

```raku
my $s = set <a b>;
my $b = bag <a a b>;
my $m = ("a" => 0.5).Mix;
say $s<a>, " ", $s<z>;
say $b<a>, " ", $b<z>;
say $m<a>, " ", $m<z>;
say $s<a b z>;
say $b<z>:exists;
say $s<a>:p;
```
```output
True False
2 0
0.5 0
(True True False)
False
a => True
```

Assigning to an element, deleting it, or binding to it is refused. `++`
fails in a different way: with no container to increment, no candidate of
`++` accepts the value.

```raku
my $s = set <a b>;
my $b = bag <a a b>;
try { $s<a> = False };
say $!.^name;
try { $s<a>:delete };
say $!.^name;
try { $b<a>++ };
say $!.^name;
try { $b<a> := 3 };
say $!.^name;
```
```output
X::Assignment::RO
X::Assignment::RO
X::Multi::NoMatch
X::Bind
```

## Assigning to a SetHash key stores its truth

A SetHash key can be assigned any value: a true value adds the element, a
false one removes it, and the assignment returns the Bool, not the value.
`++` adds and `--` removes, each returning the old Bool, and `--` on a
missing element adds nothing. `:delete` returns whether the element was
there.

```raku
my $s = SetHash.new(<a b>);
say ($s<c> = 2).raku;
say ($s<a> = 0).raku;
say ($s<n>++).raku;
say ($s<b>--).raku;
say ($s<z>--).raku;
say $s;
say ($s<c>:delete).raku, " ", ($s<c>:delete).raku;
```
```output
Bool::True
Bool::False
Bool::False
Bool::True
Bool::False
SetHash(c n)
Bool::True Bool::False
```

`.set` and `.unset` add and remove elements and return Nil. Each takes one
argument and iterates it: a string is one element, a list adds each item, a
Range its numbers. `.add` and `.remove` belong to the BagHash, and a SetHash
does not have them.

```raku
my $s = SetHash.new;
say $s.set(<a b>).raku;
$s.set("xyz");
$s.set(1..3);
say $s.keys.sort;
$s.unset(<xyz a>);
$s.unset(1);
say $s.keys.sort;
try { $s.add("q") };
say $!.^name;
```
```output
Nil
(1 2 3 a b xyz)
(2 3 b)
X::Method::NotFound
```

## `.set` of a Set adds its Pairs, not its elements
tags: quirk

Given a Set, Bag or Mix, `.set` iterates it like any other argument, and
iterating a QuantHash gives its Pairs. The SetHash gains the Pairs `a =>
True` and `b => True` as elements. `.add` on a BagHash does the same. Pass
`.keys` to add the elements themselves.

```raku
my $s = SetHash.new;
$s.set(set(<a b>));
say $s.keys.map(*.raku).sort;
my $t = SetHash.new;
$t.set(set(<a b>).keys);
say $t.keys.sort;
my $b = BagHash.new;
$b.add(bag(<t t>));
say $b.keys.map(*.raku);
```
```output
(:a :b)
(a b)
(:t(2))
```

## A BagHash truncates weights, and zero or less removes the key

Assigning to a BagHash key stores the value's `.Int` and returns it. Zero or
a negative number removes the element, and the assignment then returns what
was assigned. A value that has no integer refuses with the same
exceptions as a Bag. `--` on a missing element returns 0 and creates nothing,
and `:delete` returns the weight, or 0.

```raku
my $b = BagHash.new(<a a b>);
say ($b<c> = 2.9).raku;
say ($b<d> = "3").raku;
say ($b<a> = -3).raku;
say $b;
say ($b<z>--).raku, " ", ($b<z>:exists);
say ($b<c>:delete).raku, " ", ($b<c>:delete).raku;
try { $b<x> = "x" };
say $!.^name;
```
```output
2
3
-3
BagHash(b c(2) d(3))
0 False
2 0
X::Str::Numeric
```

`.add` and `.remove` change a weight by one for each item of their argument,
return Nil, delete an element that reaches zero, and ignore an element that
is not there:

```raku
my $b = BagHash.new;
say $b.add(<q r q>).raku;
say $b;
$b.remove(<q r z>);
say $b;
```
```output
Nil
BagHash(q(2) r)
BagHash(q)
```

## A MixHash keeps negative weights, and accepts Inf and NaN
tags: quirk

A MixHash stores the value's `.Real`, so the string "1/3" becomes a Rat, and
keeps negative weights. Zero removes the element. `--` on a missing element
stores -1, since every real weight is allowed.

```raku
my $m = MixHash.new;
say ($m<a> = "1/3").raku;
say ($m<b> = -1).raku;
say ($m<c> = 0.0).raku, " ", ($m<c>:exists);
say ($m<z>--).raku, " ", $m<z>;
say $m.pairs.sort;
```
```output
<1/3>
-1
0.0 False
0 -1
(a => 0.333333 b => -1 z => -1)
```

A Mix refuses an infinite or NaN weight when it is built. Assignment to a
MixHash does not check, and the total follows the stored value until the
element is deleted:

```raku
my $m = MixHash.new(<a>);
$m<b> = Inf;
say $m<b>, " ", $m.total;
$m<c> = NaN;
say $m.total;
$m<b>:delete;
$m<c>:delete;
say $m.total;
try { MixHash.new-from-pairs("b" => Inf) };
say $!.^name;
```
```output
Inf Inf
NaN
1
X::OutOfRange
```

## An undefined SetHash variable comes to life when used
tags: undocumented

A `my SetHash $s` variable with no value becomes a SetHash as soon as an
element is assigned or incremented, as an undefined `$` variable becomes a
Hash when a key is assigned. Unlike a Hash, it also comes to life when an
element is only read. `:exists` leaves it undefined. The immutable types
cannot come to life this way, because the new object could never be
changed: assigning to, or reading from, an undefined `Set` variable dies.

```raku
my SetHash $s;
say ($s<a>++).raku;
say $s;
my BagHash $b;
say $b<x>.raku, " ", $b.defined;
my SetHash $e;
say ($e<a>:exists), " ", $e.defined;
my Set $f;
try { $f<a> = True };
say $!.^name, " ", $f.defined;
```
```output
Bool::False
SetHash(a)
0 True
False False
X::Assignment::RO False
```

## The values of a hash form are live
tags: trap undocumented

The values that `.values`, `.pairs` and `.kv` hand out from a hash form are
not copies but stand-ins for the weights. Assigning through them changes the
weight, and a weight of zero removes the element.

```raku
my $b = BagHash.new(<a a a b>);
$_-- for $b.values;
say $b;
.value = 10 for $b.pairs;
say $b;
my $s = SetHash.new(<a b>);
for $s.kv -> $k, $v is rw { $v = False if $k eq "a" }
say $s;
```
```output
BagHash(a(2))
BagHash(a(10))
SetHash(b)
```

A subscript returns such a stand-in too. Bound with `\`, it stays live;
assigned to a variable or an array, it is copied. The immutable types hand
out plain values, which cannot be assigned to.

```raku
my $b = BagHash.new(<a a>);
my $copy = $b<a>;
my \alias = $b<a>;
alias = 5;
say $copy, " ", $b<a>;
my @v = $b.values;
@v[0] = 0;
say $b;
try { $_ = 5 for bag(<a>).values };
say $!.^name;
```
```output
2 5
BagHash(a(5))
X::AdHoc
```

The stand-in is read only when its value is needed. Put in a List, it is read
when the List is used, so it reports a value assigned later, even one
assigned later on the same line. Take the value out with `.Int` or
`.so` where it is meant to be read:

```raku
my $b = BagHash.new(<a a>);
my $l = ($b<a>, $b<a>.Int);
$b<a> = 7;
say $l;
my $s = SetHash.new(<a>);
say ($s<a>, ($s<a> = False), $s<a>).raku;
```
```output
(7 2)
(Bool::False, Bool::False, Bool::False)
```

## `>>` maps the weights, and truncates them on a Mix
tags: quirk

A hyper postfix, prefix or method call on a QuantHash applies to the weights
and returns a new collection of the same type; an element whose new weight
is zero or false is left out. On a hash form the values passed are the live
stand-ins of the previous corner, so an operator that changes its operand,
like `--`, changes the original as well, and postfix `--` returns the old
weights to build the result from. On a Mix, the new weights are truncated to
integers, which a MixHash does not do, and neither does an infix hyper:

```raku
my $d = <a a b>.BagHash;
say $d>>--;
say $d;
my $m = ("a" => 1.5, "b" => -2.5).Mix;
say $m>>.&{ $_ + 1 };
say -<<$m;
say $m >>+>> 1;
say ("a" => 1.5, "b" => -2.5).MixHash>>.&{ $_ + 1 };
```
```output
BagHash(a(2) b)
BagHash(a)
Mix(a(2) b(-1))
Mix(a(-1) b(2))
Mix(a(2.5) b(-1.5))
MixHash(a(2.5) b(-1.5))
```

## `pick` draws without replacement, `roll` with

`pick` with no count returns one element. `pick(n)` returns up to n
different draws, and on a Bag each element can be drawn as many times as its
weight, so `pick(*)` lists every element weight times. `roll(n)` draws n
times with replacement, and `roll(*)` never ends. `pickpairs` returns
element-weight pairs, once per element. None of them changes the invocant.

```raku
my $s = set <a b c>;
my $b = bag <a a b>;
say $s.pick.^name;
say $s.pick(10).elems;
say $b.pick(*).sort;
say $b.pick(5).elems;
say $b.roll(5).elems;
say bag(<a a a>).roll(3);
say $b.pickpairs(*).sort;
say $s.roll(*).head(7).elems;
```
```output
Str
3
(a a b)
3
5
(a a a)
(a => 2 b => 1)
7
```

The count is truncated to an integer, and a negative one draws nothing. A
block receives the number of elements (the total, for a Bag) and returns the
count. On an empty collection `pick` and `roll` return Nil, and NaN is
refused:

```raku
my $s = set <a b c>;
say $s.pick(-1).elems, " ", $s.pick(2.9).elems;
say $s.pick({ $_ - 1 }).elems;
say bag(<a a a b>).pick({ $_ }).elems;
say set().pick.raku, " ", set().roll.raku, " ", set().roll(3).raku;
try { $s.pick(NaN) };
say $!.^name;
```
```output
0 2
2
4
Nil Nil ().Seq
X::Numeric::CannotConvert
```

## `grab` needs a hash form, and a Mix cannot `pick`

`grab` and `grabpairs` draw like `pick` and `pickpairs` and also remove what
they draw, so the immutable types throw `X::Immutable`, which names the
method and the type. Picking without replacement needs whole-number
weights, so `pick` on a Mix or a MixHash, and `grab` on a MixHash,
return a Failure with a hint. `roll` and `pickpairs` work on a Mix, and
`grabpairs` on a MixHash.

```raku
try { set(<a>).grab };
say $!.^name, " ", $!.method, " ", $!.typename;
try { mix(<a>).grabpairs };
say $!.^name;
my $p = mix(<a>).pick;
say $p.^name;
say $p.exception.message;
say MixHash.new(<a>).grab.exception.message;
say mix(<a>).roll, " ", mix(<a>).pickpairs.raku;
say ("a" => 0.5).MixHash.grabpairs.raku;
```
```output
X::Immutable grab Set
X::Immutable
Failure
.pick is not supported on a Mix, maybe use .roll instead?
.grab is not supported on a MixHash
a :a(1)
:a(0.5)
```

## `classify-list` counts into a BagHash

`classify-list` and `categorize-list` on a BagHash or MixHash add 1 to the
weight of each category the mapper returns, and return the invocant.
`categorize-list` accepts a list of categories from the mapper;
`classify-list` refuses one with `X::Invalid::ComputedValue`. The immutable
types throw `X::Immutable`.

```raku
my $b = BagHash.new;
my $r = $b.classify-list({ $_ %% 2 ?? "even" !! "odd" }, ^5);
say $r === $b;
say $b.pairs.sort;
my $m = MixHash.new;
$m.categorize-list({ ($_, "all") }, <a b>);
say $m.pairs.sort;
try { bag(<a>).classify-list({ $_ }, <a>) };
say $!.^name;
try { BagHash.new.classify-list({ ($_, $_) }, <a>) };
say $!.^name;
```
```output
True
(even => 3 odd => 2)
(a => 1 all => 2 b => 1)
X::Immutable
X::Invalid::ComputedValue
```

## `grab(*)` removes each element only as it is read
tags: trap quirk

`grab(n)` removes n weighted draws, and `grab(*)` all of them. The result is
a lazy Seq, and an element leaves the collection only when the Seq reaches
it: right after `grab(*)` returns, the invocant is still full.

```raku
my $b = BagHash.new(<a a a b>);
my @g = $b.grab(2);
say @g.elems, " ", $b.total;
my $seq = $b.grab(*);
say $b.total;
say $seq.elems, " ", $b.total;
```
```output
2 2
2
2 0
```

`grabpairs` removes whole elements and returns them with their weights, and
`grab` and `grabpairs` on an empty collection return Nil. The exception is
`grabpairs` on an empty SetHash, which returns a Pair of Nil and True:

```raku
my $b = BagHash.new(<a a a>);
say $b.grabpairs.raku;
say $b.grabpairs.raku;
my $s = SetHash.new;
say $s.grab.raku;
say $s.grabpairs.raku;
```
```output
:a(3)
Nil
Nil
(Nil) => Bool::True
```

## A Mix rolls by its positive weights only

`roll` on a Mix draws in proportion to the positive weights and never draws
an element whose weight is negative. A Mix with no positive weight rolls Nil,
or an empty Seq for a count. A block count receives the sum of the positive
weights, not the total.

```raku
my $m = ("a" => 2, "b" => -5).Mix;
say $m.roll(4);
say $m.total;
say $m.roll({ $_ * 2 }).elems;
say ("a" => -1).Mix.roll.raku;
say ("a" => -1).Mix.roll(2).raku;
say ("a" => 0.5).Mix.roll;
```
```output
(a a a a)
-3
4
Nil
().Seq
a
```

## `∈` sees a string as one element and a Hash by its values

`∈`, written `(elem)` in ASCII, looks for its left operand among the elements
of the right one. What counts as the elements depends on the right side. In a
QuantHash, every key is an element, a Mix key with a negative weight
included. In a Hash, a key is an element only when its value is true, and a
plain Hash has string keys, so the number 1 is not among them. A list is
searched by identity. A finite Int Range is tested arithmetically, so a Rat
is never in it. Anything else becomes a Set first, which makes a string one
element and a Pair a weight.

```raku
say "a" ∈ "ab";
say "ab" ∈ "ab";
say "a" ∈ { a => 0 };
say 1 ∈ { 1 => 1 };
say 1 ∈ :{ 1 => 1 };
say 2 ∈ 1.5..4;
say 1.0 ∈ 1..3;
say "a" ∈ ("a" => -1).Mix;
say 1 ∈ (1 => 2);
```
```output
False
True
False
False
True
False
False
True
True
```

`∉`, like `!(elem)`, negates `∈`; `∋`, or `(cont)`, and `∌` take the operands
the other way round. `∊` and `∍` are other spellings of `∈` and `∋`.

```raku
say 1 ∈ (1, 2), " ", 3 ∉ (1, 2);
say (1, 2) ∋ 2, " ", (1, 2) ∌ 3;
say 1 !(elem) (1, 2);
say 1 ∊ (1, 2), " ", (1, 2) ∍ 2;
say [1] ∈ [[1], [2]];
say Nil ∈ (Nil,);
say Set ∈ Set;
```
```output
True True
True True
False
True True
False
True
True
```

`Set ∈ Set` is True because the type object becomes a set that holds itself.

## `∪` takes the larger weight; the left operand decides mutability

`∪`, or `(|)`, keeps every element of either side. Its result is a Set when
both sides are Sets, a Bag when either is a Bag, a Mix when either is a Mix,
with each element's weight the larger of its two. A list is converted with
the rules of the coercers, and a Hash by its values.

```raku
say set(<a b>) (|) set(<b c>);
say set(<a b>) ∪ bag(<b b c>);
say bag(<a a b>) ∪ ("b" => 0.5).Mix;
say (("a" => -10).Mix ∪ ("a" => -20, "b" => -5).Mix).pairs.sort;
say <a b c> ∪ <c d>;
say "ab" ∪ "cd";
say { a => 1, b => 0 } ∪ <c>;
say bag(<a>) ∪ { a => 3 };
```
```output
Set(a b c)
Bag(a b(2) c)
Mix(a(2) b)
(a => -10 b => -5)
Set(a b c d)
Set(ab cd)
Set(a c)
Bag(a(3))
```

The result is a hash form when the left operand is one, and immutable
otherwise; with a plain list on the left it takes the immutable type of the
right. An empty result is the shared empty object.

```raku
say (SetHash.new(<a>) ∪ bag(<b>)).^name;
say (bag(<a>) ∪ SetHash.new(<b>)).^name;
say (BagHash.new(<a>) ∪ mix(<b>)).^name;
say (<a> ∪ BagHash.new(<b>)).^name;
say (set() ∪ set()) =:= set();
```
```output
BagHash
Bag
MixHash
Bag
True
```

The operators of the following corners choose their type and mutability the
same way, except that `⊎` and `⊍` never return a Set.

## `∩` takes the smaller weight

`∩`, or `(&)`, keeps the elements present on both sides, with the smaller of
the two weights; for a negative Mix weight that is the more negative one. A
list on the right of a Bag is counted as a Bag.

```raku
say set(<a b c>) (&) set(<b c d>);
say bag(<a a b>) ∩ bag(<a b b c>);
say bag(<a a>) ∩ ("a" => 0.5).Mix;
say ("a" => 2).Mix ∩ ("a" => -3).Mix;
say bag(<a a a>) ∩ <a a>;
say set(<a b>) ∩ bag(<a b b>);
say (set(<a>) ∩ set(<b>)) =:= set();
```
```output
Set(b c)
Bag(a b)
Mix(a(0.5))
Mix(a(-3))
Bag(a(2))
Bag(a b)
True
```

## `∩` of two Hashes ignores false values
tags: bug

The documentation says a set operator treats an operand as if it called
`.Set` on it, and that `.Set` of a Hash skips the keys whose values are
false. Every operator does so, except in one case: when both operands of `∩`
are plain Hashes, Rakudo 2026.08 compares only the keys, so a key whose value
is false is an element after all. Converting either side first, or any other
operand, leaves the false key out:

```raku
say { a => 1, b => 0 } ∩ { a => 1, b => 1 };
say { b => 0 } ∩ { b => 0 };
say { a => 1, b => 0 }.Set ∩ { a => 1, b => 1 }.Set;
say { a => 1, b => 0 } ∩ <a b>;
say { b => 0 } ∪ { b => 0 };
say "b" ∈ { b => 0 };
```
```output
Set(a b)
Set(b)
Set(a)
Set(a)
Set()
False
```

## `∖` subtracts weights, and a Mix keeps what goes negative

`∖`, or `(-)`, removes from the left side what is on the right. With Sets
that removes elements. With a Bag it subtracts weights and drops an element
that reaches zero; a Set on the right subtracts 1 per element, and a list on
the right counts as a Bag. With a Mix on either side it subtracts and keeps
negative results. A Set on the left of a Bag makes a Bag, which is empty
here because every weight on the left is 1.

```raku
say set(<a b c>) (-) set(<b>);
say set(<a b c>) ∖ <b c d>;
say bag(<a a a b>) (-) bag(<a b>);
say bag(<a a a b>) (-) <a a>;
say bag(<a a b>) (-) set(<a b>);
say mix() (-) mix(<a b>);
say set(<a b>) (-) bag(<a b b>);
```
```output
Set(a c)
Set(a)
Bag(a(2))
Bag(a b)
Bag(a)
Mix(a(-1) b(-1))
Bag()
```

## A Hash on the right of a Mix difference counts as a Set
tags: quirk

A Hash or a Pair on the right of a Bag difference is read with its values as
weights. On the right of a Mix difference, the values are ignored: the Hash
or Pair counts as a Set, and subtracts 1 from each of its keys.

```raku
say ("a" => 2.5).Mix (-) { a => 2 };
say ("a" => 2.5).Mix (-) ("a" => 2).Mix;
say mix(<a>) (-) (a => 0.5);
say bag(<a a a>) (-) { a => 2 };
say bag(<a a a>) (-) (a => 2);
```
```output
Mix(a(1.5))
Mix(a(0.5))
Mix()
Bag(a)
Bag(a)
```

## `⊖` keeps the difference of the weights

`⊖`, or `(^)`, the symmetric difference, keeps the elements that are on one
side only. With weights, it keeps the absolute difference of the two weights
and drops an element where they are equal.

```raku
say set(<a b c>) (^) set(<b c d>);
say bag(<a b b c>) ⊖ bag(<b c d>);
say bag(<a b b b>) ⊖ bag(<a b>);
say ("a" => -3.5).Mix ⊖ mix();
say set(<a b>) ⊖ ("b" => -1).Mix;
```
```output
Set(a d)
Bag(a b d)
Bag(b(2))
Mix(a(3.5))
Mix(a b(2))
```

## `⊖` of three operands is not two `⊖` in a row
tags: quirk trap

A chain of `⊖`, like a reduction `[⊖]`, is computed as one operation over
all its operands, not as a series of binary ones, and it answers a different
question. An element of a Set survives when it is in exactly one operand; in
a Bag or a Mix its weight is the largest weight minus the second largest.
Parentheses turn the chain into the binary operations:

```raku
say <a> (^) <a> (^) <a>;
say (<a> (^) <a>) (^) <a>;
say <a b> (^) <b c> (^) <c d>;
say [(^)] bag(<a a a>), bag(<a>), bag(<a>);
say (bag(<a a a>) (^) bag(<a>)) (^) bag(<a>);
say (a => 3).Bag (^) (a => 1).Bag (^) (a => 2).Bag;
```
```output
Set()
Set(a)
Set(a d)
Bag(a(2))
Bag(a)
Bag(a)
```

`[(^)] bag(<a a a>), bag(<a>), bag(<a>)` is 3 − 1; the binary form first
makes `Bag(a(2))` and then takes 1 from it.

## `⊎` adds weights and `⊍` multiplies them; neither makes a Set

`⊎`, or `(+)`, adds the weights of both sides, and `⊍`, or `(.)`, multiplies
the weights of the elements on both sides. Both return at least a Bag, even
for two Sets. With a Mix the sum may reach zero, which removes the element.
A Pair on the right is a weight, and a negative one is skipped by a Bag as in
construction, while a Mix subtracts it.

```raku
say set(<a b>) (+) set(<b c>);
say <a b> ⊎ <b c>;
say bag(<a a>) (+) ("a" => 0.5).Mix;
say (("a" => -42).Mix (+) ("a" => 42).Mix) =:= mix();
say bag(<a>) (+) (a => -2);
say mix(<a>) (+) (a => -2);
say 1 (+) (foo => 42,);
say Nil (+) Nil;
```
```output
Bag(a b(2) c)
Bag(a b(2) c)
Mix(a(2.5))
True
Bag(a)
Mix(a(-1))
Bag(1 foo(42))
Bag(Nil(2))
```

For `⊍`, a Pair on the right of a Bag is truncated like any Bag weight, so a
weight of 0.5 removes the element, while on the right of a Mix it stays:

```raku
say bag(<a a b>) (.) bag(<a a a c>);
say set(<a b>) (.) set(<b c>);
say ("a" => -2).Mix ⊍ ("a" => -3).Mix;
say bag(<a a>) ⊍ (a => 0.5);
say mix(<a>) ⊍ (a => 0.5);
say 42 ⊍ 666;
say (SetHash.new(<a>) (+) set()).^name, " ", (SetHash.new(<a>) (.) set()).^name;
```
```output
Bag(a(6))
Bag(b)
Mix(a(6))
Bag()
Mix(a(0.5))
Bag()
BagHash BagHash
```

## A reduction with no operands gives an empty Set or Bag

Reduced over nothing, `∪`, `∩`, `∖` and `⊖` give the empty Set, and `⊎` and
`⊍` the empty Bag. With a single operand, the rules differ from one operator
to the next: `∪` returns a hash form unchanged, `∖` and `⊎` make it
immutable, and `⊍` keeps it mutable but makes it a Bag.

```raku
say [(|)]();
say [(&)]();
say [(+)]();
say [(.)]();
say ([(|)] SetHash.new(<a>)).^name;
say ([(-)] SetHash.new(<a>)).^name;
say ([(+)] SetHash.new(<a>)).^name;
say ([(.)] SetHash.new(<a>)).^name;
```
```output
Set()
Set()
Bag()
Bag()
SetHash
Set
Bag
BagHash
```

A single list after the reduction is spread into its elements, as for any
reduction, so `[∩] <a b>` intersects `"a"` with `"b"`. With three operands or
more, the type rises to the richest operand and the first operand decides
mutability:

```raku
say [(|)] <a b>;
say [(&)] <a b>;
say [(|)] bag(<a a>), bag(<a>), <a a a>;
say ([(-)] SetHash.new(<a b>), <a>, <c>).^name;
```
```output
Set(a b)
Set()
Bag(a(3))
SetHash
```

## `⊆` compares weights, and a negative weight is less than none

`⊆`, or `(<=)`, asks whether every element of the left side is in the right
one; with weights, whether each weight on the left is at most the weight on
the right. `⊂`, or `(<)`, also wants the two to differ. `⊇` and `⊃` look the
other way, and `⊈`, `⊄`, `⊉` and `⊅` negate. The comparison happens in the
richer type of the two, so a Set is not a subset of a Bag whose weights are
smaller, and a list with a repeated element can be too big for a Bag.

```raku
say set(<a>) ⊆ set(<a b>);
say set(<a b>) ⊂ set(<a b>);
say set(<a b>) ⊇ <a>;
say set(<a>) ⊈ set(<b>);
say bag(<a a>) ⊆ bag(<a>);
say bag(<a a>) ⊆ set(<a>);
say set(<a>) ⊆ bag(<a a>);
say <a a> ⊆ <a>;
say <a a> ⊆ bag(<a>);
```
```output
True
False
True
True
False
False
True
True
False
```

In a Mix, a missing element weighs 0, so an element with a negative weight is
*below* the empty Mix. A Hash counts by its true values. The operators chain,
and `!` negates them:

```raku
say ("a" => -1).Mix ⊆ mix();
say mix() ⊆ ("a" => -1).Mix;
say ("a" => -1).Mix ⊂ mix();
say ("a" => -2).Mix ⊂ ("a" => -1).Mix;
say { a => 0 } ⊆ { a => 1 };
say set(<a>) ⊂ set(<a b>) ⊂ set(<a b c>);
say set(<a>) !(<=) set(<b>);
```
```output
True
False
True
True
True
True
True
```

## `(<+)` and `≼` were removed in 6.d

Raku 6.c had `(<+)` and `≼` for "is a sub-bag of", and `(>+)` and `≽` for the
reverse. Version 6.d replaced them with `⊆` and `⊇`, which compare weights
by themselves. The old operators still exist, but throw:

```raku
try { bag(<a>) (<+) bag(<a a>) };
say $!.^name;
say $!.message;
say &infix:<≼>.^name;
```
```output
X::AdHoc
(<+) was removed in v6.d, please use (<=) operator instead
  or compile your code with 'use v6.c'
Sub
```

A program that starts with `use v6.c` gets them back, with a deprecation
report when it ends. A `use v6.c` inside an `EVAL` does not.

```raku
use v6.c;
say bag(<a>) (<+) bag(<a a>);
```
```output
True
```
```stderr
Saw 1 occurrence of deprecated code.
================================================================================
Set operator (<+) seen at:
  example.raku, line 2
Will be removed with release v6.d!
Please use set operator (<=) instead.
--------------------------------------------------------------------------------
Please contact the author to have these occurrences of deprecated code
adapted, so that this message will disappear!
```

## `≡` compares in the richer type of its two operands

`≡`, or `(==)`, is True when the two sides have the same elements with the
same weights, compared in the richer of their two types. A Set equals a Bag
whose weights are all 1, a Bag equals a Mix with the same whole weights, and
every empty collection equals every other. Lists are compared as sets. A
number and a string are different elements, and `≢` negates.

```raku
say set(<a>) (==) bag(<a>);
say bag(<a a>) ≡ set(<a>);
say bag(<a>) (==) ("a" => 1.0).Mix;
say set() (==) mix();
say (1, 2, 3) (==) (3, 2, 1, 1);
say 42 (==) "42";
say set(<a>) ≢ set(<b>);
```
```output
True
False
True
True
True
False
True
```

## Two Hashes compare their sizes before their truth
tags: quirk

When both operands of `≡` are hashes, Rakudo compares their numbers of keys
first, false values included, and only then which keys are true. So a Hash
with one false value equals the empty Set but not the empty Hash, and the
values are compared only for truth:

```raku
say { a => 0 } (==) set();
say { a => 0 } (==) {};
say {} (==) { a => 0 };
say { a => 1 } (==) { a => 2 };
say { a => 0, b => 1 } (==) { b => 1, c => 0 };
say { a => 0, b => 1 } (==) { b => 1 };
```
```output
True
False
False
True
True
False
```

## Set operators sit on the junction levels, and different ones do not mix

`∪`, `⊖`, `⊎` and `∖` share the precedence level of the junction `|`, and `∩`
and `⊍` that of `&` ([Who Takes the
Operand](#ch:precedence:junctions-bind-looser-than-arithmetic-and-concatenation)).
They are looser than arithmetic and than `..`, and tighter than every
comparison, so `<a b> ∩ <b c> == 1` compares the size of the intersection.

```raku
say 1 + 2 (|) 4;
say 1 (|) 2 + 3;
say <a b> (&) <b c> == 1;
say (1 .. 3 (|) 4).max.^name;
say (<a> (&) <b> | <c>).^name;
```
```output
Set(3 4)
Set(1 5)
True
Set
Junction
```

`1 .. 3 (|) 4` is a Range whose end is a Set. As with the junction operators
([Who Takes the
Operand](#ch:precedence:different-junction-operators-do-not-mix-without-parentheses)),
a chain may repeat one operator but not mix two of the same level:

```raku
say <a> (|) <b> (-) <b>;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Only identical operators may be list associative; since '(|)' and '(-)' differ, they are non-associative and you need to clarify with parentheses
at example.raku:1
------> say <a> (|) <b><HERE> (-) <b>;
    expecting any of:
        infix
        infix stopper
```

## The Boolean set operators chain like comparisons
tags: trap

`∈`, `⊆`, `≡` and the other operators that answer yes or no are on the
chaining level with `==` and `<`, so a comparison written after one of them
takes its right operand as a new link in the chain ([Who Takes the
Operand](#ch:precedence:true-at-the-end-of-a-chain-compares-the-last-operand-not-the-result)):

```raku
say 1 (elem) (1, 2) == True;
say (1 (elem) (1, 2)) == True;
say 1 (elem) 1..3 && "yes";
say set(<a>) (<=) set(<a>) (==) set(<a>);
```
```output
False
True
yes
True
```

The first line is `1 ∈ (1, 2)` and `(1, 2) == True`, and a two-element list
is not equal to 1. `&&` is looser than the chain, so the third line works as
it reads.

## `∪=` builds a new collection instead of changing the old one
tags: trap

Every set operator has an assignment form, `(|)=`, `(&)=`, `(-)=` and so on.
Like `+=`, it computes a new value and assigns it to the variable. A SetHash
in the variable is replaced by a new SetHash, and another reference to the
old one does not see the change; `.set` changes the SetHash in place. An `is
Set` variable is the Set itself, and refuses the assignment.

```raku
my $s = set(<a>);
$s (|)= <b>;
$s (-)= <a>;
say $s;
my $h = SetHash.new(<a>);
my $before = $h;
$h (|)= <b>;
say $h.^name, " ", $h.keys.sort, " ", $before.keys.sort;
my %f is Set = <a>;
try { %f (|)= <b> };
say $!.^name;
```
```output
Set(b)
SetHash (a b) (a)
X::Assignment::RO
```

## A Junction operand makes four operators hang
tags: bug unasserted

The Boolean operators autothread over a Junction like any other operator
that is not written for Junctions: `1 ∈ any(1, 2)` is a Junction of two
answers. A Junction *inside* a list is just one element.

```raku
say (1 (elem) any(1, 2)).^name;
say so 1 (elem) all(1, 2);
say so all(<a b>) (elem) set(<a b c>);
say so set(1) (==) (1 | 2);
say 1 (elem) (1 | 2,);
say set(1 | 2).keys[0].^name;
try { set(1) (-) any(2, 3) };
say $!.^name;
```
```output
Junction
False
True
True
False
Junction
X::AdHoc
```

The operators that build a collection do not autothread. In Rakudo 2026.08,
`∖` and `⊖` die with "Cannot iterate object with P6opaque representation
(Junction)", a message that names the virtual machine's representation of
the object, and `∪`, `∩`, `⊎` and `⊍` with a Junction on either side never
return. Each of these lines runs until it is killed:

```raku nocheck
say set(1) (|) any(2, 3);
say any(2, 3) (&) set(1);
say set(1) (+) any(2, 3);
say set(1) (.) any(2, 3);
```

## A Failure operand throws, even one already handled
tags: undocumented

A Failure on either side of a set operator throws its exception at once, and
so does a Failure given to a constructor or a coercer. This happens even when
the Failure has been handled, by testing it with `.so` or `.defined`,
although such a Failure can still become an element through `.Set`:

```raku
my $f = "x".Int;
try { set(1) (|) $f };
say $!.^name;
my $g = "y".Int;
$g.so;
try { 1 (elem) $g };
say $!.^name;
say $g.Set.keys[0].^name;
try { set(Failure.new) };
say $!.^name;
```
```output
X::Str::Numeric
X::Str::Numeric
Failure
X::AdHoc
```
