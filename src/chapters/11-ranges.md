---
title: Ranges
part: Collections
summary: A Range is two endpoints and two flags, and almost everything it does, from counting and smartmatching to arithmetic and printing, is worked out from those four facts rather than from its elements.
---

A Range such as `1..10` stores very little: a start, an end, and whether
each of them is excluded. It does not hold its elements. It computes them
when it is iterated, counts them with arithmetic when it can, and answers
most questions (is a value inside? is one range inside another? what is the
smallest element?) from the endpoints alone. Most of the surprises in this
chapter come from the gap between those endpoints and the elements a
reader pictures.

The precedence of `..` and the reason `1..2..3` does not compile are in
[Who Takes the Operand](#ch:precedence:structural-operators-refuse-to-chain).
The sequence operator `...`, which looks similar but deduces a step and
takes a list of seeds, is in [The Sequence Operator](#ch:sequences). The list
methods that a Range shares with every other list, `map`, `grep`, `head` and
the rest, are in [Lists, Arrays, Seqs and Slips](#ch:lists). This chapter is
about what is particular to ranges.

## Four operators and a prefix build a range

`..` includes both endpoints. A caret beside the dots excludes the endpoint
on its side: `^..` drops the start, `..^` the end, `^..^` both. The prefix
`^` builds a range from 0 up to, but not including, its operand, which it
first turns into a number: a string is read as one, and an array counts its
elements. A `*` at either end stands for infinity.

```raku
say (1^..5).list;
say (1..^5).list;
say (1^..^5).list;
say (^5).raku;
my @names = <x y z>;
say (^@names).raku;
say (^"4").raku;
say (1..*).raku;
say (*..1).raku;
```
```output
(2 3 4 5)
(1 2 3 4)
(2 3 4)
^5
^3
^4
1..Inf
-Inf..1
```

`^@names` is the idiom for the indices of an array. The `*` is not kept:
`1..*` is stored as `1..Inf`, and the two are the same value.

## `.Str` lists the elements, while `say` shows the endpoints

A Range has two printed forms. `.raku`, and `.gist`, which `say` uses, write
the endpoints joined by the operator. `.Str`, used by `put`, by `~` and by
interpolation into a string, writes the elements joined by spaces, so an
empty range becomes an empty string. An endless range cannot list its
elements, and its `.Str` writes `*` for the open end instead.

```raku
my $r = 1..5;
say $r;
put $r;
say "[$r]";
say "[{3..2}]";
say "a".."c";
say (1..*).Str;
say (1^..^*).Str;
```
```output
1..5
1 2 3 4 5
[1 2 3 4 5]
[]
"a".."c"
1..*
1^..^*
```

`.raku` writes each endpoint in its own `.raku` form, so the types stay
visible. The short form `^N` is used only for an Int range from 0 with its
end excluded:

```raku
say (0..^5).raku;
say (0..^5.0).raku;
say (0e0..^5).raku;
say (1.5..2).raku;
say (^4.5).raku;
```
```output
^5
0..^5.0
0e0..^5
1.5..2
0..^4.5
```

## A Range, a Seq or a Complex cannot be an endpoint

Building a range checks its endpoints. Another Range, a Seq or a Complex
number is refused with `X::Range::InvalidArg`, whose `.got` attribute holds
the offending endpoint; for a Seq it holds the type object `Seq`, not the
sequence. `Range.new` refuses the same values.

```raku
my $inner = ^20;
try 10 .. $inner;
say $!.^name;
say $!.message;
try 1 .. (1, 2).Seq;
say $!.got.raku;
my $z = 5i;
try 1 .. $z;
say $!.message;
```
```output
X::Range::InvalidArg
Range objects are not valid endpoints for Ranges
Seq
Complex objects are not valid endpoints for Ranges
```

A Seq endpoint turns up more often than it seems, through precedence: see
[below](#ch:ranges:xx-and-bind-tighter-than-and-a-prefix-warns).

## `1 .. * + 1` is code that makes a range, not a range
tags: trap

A bare `*` at an end means infinity. A `*` with an operator attached is a
*Whatever* expression, and the whole range expression becomes a
`WhateverCode`: a small function that builds the range when it is called.
That is what makes `@a[1 .. *-2]` work, since a subscript calls such code
with the number of elements. `^*` is code as well.

```raku
my $make = 1 .. * + 1;
say $make.^name;
say $make(4).raku;
say (^*)(3).raku;
my @l = <a b c d e>;
say @l[1 .. *-2];
say (1 .. * + 1).^name;
```
```output
WhateverCode
1..5
^3
(b c d)
WhateverCode.new
```

The last line is not a misprint. Parentheses do not end the Whatever
expression, so the `.^name` call becomes part of the code too, and `say`
prints the gist of yet another WhateverCode. Assign the expression to a
variable first, as on the first line, to ask what it is.

## A numeric start converts the end; a string start converts nothing

When the start of a range is a real number, the end is turned into one as
well: a numeric string becomes its number, and an array or list becomes its
number of elements. An array or a match on the left is turned into a number
too. A string on the left converts nothing, so `"1"..9` is a range of
strings, iterated by characters.

```raku
my @items = <a b c d e>;
say (1 .. @items).raku;
my $ten = "10";
say (1 .. $ten).raku;
my @one = 7;
say (@one .. 3).raku;
say ("1" .. 9).raku;
say ("1" .. 9).list.head(3).raku;
my $word = "abc";
try 1 .. $word;
say $!.^name;
```
```output
1..5
1..10
1..3
"1"..9
("1", "2", "3").Seq
X::Str::Numeric
```

`@one` has one element, so it becomes 1. A string that is not a number
fails at once, when the range is built. An undefined right endpoint is
accepted: `Any` stays as it is and makes an empty range, `Nil` becomes 0
with a warning, and `True` is 1.

```raku
say (1 .. Any).raku;
say (1 .. True).raku;
say (1 .. True).elems;
my $r = 1 .. Nil;
say $r.raku;
```
```output
1..Any
1..Bool::True
1
1..0
```
```stderr
Use of Nil in numeric context
  in block <unit> at example.raku line 4
```

## `min` and `max` are the endpoints as written, exclusions ignored

`min`, `max` and `bounds` return the stored endpoints, whether or not they
are excluded and whether or not the range is empty. `(^3).max` is 3, which
is not an element; `(5..1).min` is 5. The exclusions are separate:
`excludes-min` and `excludes-max`. `Range.new` takes the two endpoints and
the two exclusions as named arguments.

```raku
say (^3).min, " ", (^3).max;
say (^3).bounds.raku;
say (5..1).min, " ", (5..1).max;
say (1..*).max.^name;
say (1^..^5).excludes-min, " ", (^5).excludes-min;
say Range.new(1, 5, :excludes-min).raku;
say Range.new(*, 5).raku;
```
```output
0 3
(0, 3)
5 1
Num
True False
1^..5
-Inf..5
```

The end of `1..*` is the Num `Inf`, not an Int.

## `is-int` and `infinite` judge the endpoints, not the elements

`is-int` is True when both endpoints are Int objects. `1..5.0` and `1..1e0`
hold the same elements as `1..5` and `1..1`, but they are not integer
ranges, and neither is `1..Inf`. A string end that was converted to an Int,
as in `1 .. "5"`, counts as one.

`infinite` is True when the start is `-Inf`, when the end is `Inf`, and when
either endpoint is NaN. An infinity at the other end does not count:
`Inf..1` and `1..-Inf` are empty, not infinite. `is-lazy` gives the same
answer as `infinite`.

```raku
say (1..5).is-int, " ", (1..2**70).is-int;
say (1..5.0).is-int, " ", (1..1e0).is-int, " ", (1..Inf).is-int;
say (1 .. "5").is-int;
say (1..*).infinite, " ", (1..NaN).infinite;
say (Inf..1).infinite, " ", (1..-Inf).infinite;
```
```output
True True
False False False
True
True True
False False
```

## Every range is true, even an empty one
tags: quirk

A defined Range is always true, whatever it contains. `1..0`, `1^..1` and
`"b".."a"` have no elements, and each of them passes an `if`. Only the type
object `Range` is false.

```raku
say ?(1..0), " ", ?(1^..1), " ", ?("b".."a");
say (1..0).elems;
say "empty, but true" if 5..1;
say ?Range;
```
```output
True True True
0
empty, but true
False
```

Test `.elems` to ask whether a range has elements. The next language
version changes this: under `use v6.e.PREVIEW`, an empty range is false.

```raku
use v6.e.PREVIEW;
say ?(1..0), " ", ?(1..5);
```
```output
False True
```

## Two ranges are the same value when their endpoints are

A Range is a value type: two ranges with the same endpoints, of the same
types, and the same exclusions are `===` and `eqv`, and `unique` treats
them as one. A difference in the endpoints' types, or in an exclusion,
makes them different even when their elements agree. A role mixed in with
`but` changes the type, and with it the answer.

```raku
say (1..2) === (1..2);
say (1..2) eqv (1.0..2);
say (1..2) eqv (1..^2);
say ((1..3), (1..3)).unique.elems;
my $tagged = (1..2) but role { };
say (1..2) eqv $tagged;
say (1..2) == (5..6);
```
```output
True
False
False
1
False
True
```

`==` is not a comparison of ranges at all: it turns each side into a number,
which for a range is [its number of
elements](#ch:ranges:an-endless-range-is-inf-as-a-number-though-elems-fails),
and `1..2` and `5..6` both have two.

## `xx` and `~` bind tighter than `..`, and a prefix `|` warns
tags: trap

`..` is looser than every arithmetic and string operator, `xx` included, and
tighter than the comparisons (the table is in [Who Takes the
Operand](#ch:precedence)). `1..5 xx 2` is therefore `1..(5 xx 2)`, a range
ending in a Seq, and `1..3 ~ "x"` tries to end a range at the string
`"3x"`. Both fail when the line runs.

```raku
try { my $r = 1..5 xx 2 };
say $!.message;
try { my $r = 1..3 ~ "x" };
say $!.^name;
say ((1..5) xx 2).raku;
say (1..3 X~ "a").raku;
```
```output
Seq objects are not valid endpoints for Ranges
X::Str::Numeric
(1..5, 1..5).Seq
("1a", "2a", "3a").Seq
```

A prefix operator binds tighter still, so `|4..5` applies the slip to the 4
alone, and a one-element slip counts as 1. The compiler suspects a mistake
and says so, but compiles the code; under `use fatal` the warning becomes a
compile-time error. `~4..5` gets the same treatment, and builds the range
`"4"..5`.

```raku
my @a = |4..5;
say @a;
```
```output
[1 2 3 4 5]
```
```stderr
Potential difficulties:
    To apply a Slip flattener to a range, parenthesize the whole range.
    (Or parenthesize the whole endpoint expression, if you meant that.)
    at example.raku:1
    ------> my @a = <HERE>|4..5;
```

`cmp`, `leg` and `but` share the level of `..` and cannot sit beside it
without parentheses: `(1..2) cmp 1..2` fails to compile until the second
range is in parentheses too.

## `elems` counts without iterating, and an endless range fails

An Int range counts its elements with a subtraction, however large it is.
A range of other numbers counts the values it would step through, and the
excluded end only removes an element that lands exactly on it: `^5.5` has
six elements, 0 to 5. A range that starts after its end has none, even
`Inf..0`. An endless range has no count, and `elems` returns a Failure of
`X::Cannot::Lazy`.

```raku
say (1^..^10).elems;
say (^5.5).elems;
say (1.1..5).elems;
say (Inf..0).elems;
say (1..*).elems.^name;
try say (1..*).elems;
say $!.message;
```
```output
8
6
4
0
Failure
Cannot .elems a lazy list
```

## An endless range is Inf as a number, though `elems` fails
tags: undocumented quirk

A Range used as a number, with prefix `+`, `==` or `<`, is its number of
elements, computed from the endpoints. The difference from `elems` shows at
the edges: an endless range is `Inf` rather than a Failure, and an endpoint
of NaN makes NaN. `Inf..Inf` shows how far the rule goes: it yields no
elements at all, yet `elems` fails and the number is `Inf`. A range of
strings counts its list. `.Int` of an endless range is a Failure.

```raku
say +(1..10), " ", +(1.2..4);
say +(1..*), " ", (1..*) == Inf;
say (Inf..Inf).head(5).raku;
say (Inf..Inf).elems.^name;
say +(Inf..Inf);
say +(1..NaN);
say +("aa".."ab");
say (1..*).Int.^name;
```
```output
10 3
Inf True
().Seq
Failure
Inf
NaN
2
Failure
```

## A numeric range steps by one from its start

The elements of a numeric range are its start, then the start plus one, and
so on while they do not pass the end. The end need not be an element: `1.1..4`
is 1.1, 2.1 and 3.1, and `1..4.9` stops at 4. The type of the elements
follows the start, so `1..3.0` gives Ints and `1.0..3` gives Rats.

```raku
say (1.1..4).list.raku;
say (1..4.9).list.raku;
say (1.1^..^4.9).list.raku;
say (1..3.0).list.raku;
say (1.0..3).list.raku;
say (1e0..3e0).list.raku;
say (1/3..2).list.raku;
```
```output
(1.1, 2.1, 3.1)
(1, 2, 3, 4)
(2.1, 3.1, 4.1)
(1, 2, 3)
(1.0, 2.0, 3.0)
(1e0, 2e0, 3e0)
(<1/3>, <4/3>)
```

The third line drops the excluded start, 1.1, but keeps 4.1: an excluded
end removes only a value equal to it, and no step lands on 4.9. For any
other step than one, the sequence operator `...` is the tool; see [The
Sequence Operator](#ch:sequences).

## A range of single characters walks the code points

When both endpoints are strings of one character, the range holds every
code point from the first to the second, punctuation included. An Int on the
right of a one-character string counts as its digit. A start after the end
gives an empty range.

```raku
say ('Y'..'d').Str;
say ("A".."z").elems;
say ("é".."ë").list.raku;
say ('!'^..^'&').list.raku;
say ("b".."a").list.raku;
say ("a"..*).head(3).raku;
```
```output
Y Z [ \ ] ^ _ ` a b c d
58
("é", "ê", "ë")
("\"", "#", "\$", "\%")
()
("a", "b", "c").Seq
```

Between `Z` and `a` lie six punctuation characters, which is why `"A".."z"`
has 58 elements and not 52.

## A range of longer strings counts each position separately
tags: undocumented quirk

A reader who knows [how `succ` counts
strings](#ch:strings:succ-increments-the-last-run-of-letters-or-digits)
expects `"aa".."bb"` to hold `aa` to `az` and then `ba` and `bb`. It does
not. When the endpoints are longer than one character, Rakudo pairs the
characters position by position and takes every combination of the
per-position ranges, the first position changing slowest. Each position may
count down as well as up.

```raku
say ("aa".."bb").list;
say ("a1".."b2").list;
say ("ab".."ba").list;
say ("08".."11").list;
say ("aa".."zz").elems;
```
```output
(aa ab ba bb)
(a1 a2 b1 b2)
(ab aa bb ba)
(08 07 06 05 04 03 02 01 18 17 16 15 14 13 12 11)
676
```

`"aa".."zz"` has 676 elements under either reading, which is why the
difference often goes unnoticed. Endpoints of different lengths give
answers that follow no simple rule:

```raku
say ("a".."ad").list;
say ("1".."10").list;
say ("a".."bb").list;
say ("x".."ab").elems;
say ("a".."zz").elems;
say ("aa".."b").head(4).raku;
```
```output
(a)
(1)
(a b)
0
702
("aa",).Seq
```

The sequence operator gives the same answers: `"aa" ... "bb"` is the same
four strings. [Membership](#ch:ranges:a-string-range-compares-in-string-order-not-by-its-elements)
does not go through this list at all.

## `*..1` yields minus infinity forever
tags: quirk

An endless range is lazy. `1..*` counts up forever, `1.5..*` steps from 1.5,
and `"a"..*` walks the letters and beyond. A range that starts at `-Inf`
yields `-Inf` forever, because one more than minus infinity is still minus
infinity, and `NaN..NaN` yields NaN forever. A range from `Inf` yields
nothing. Assigning an endless range to an array keeps it lazy.

```raku
say (1.5..*).head(3).raku;
say (*..1).head(3).raku;
say (NaN..NaN).head(2).raku;
say (Inf..Inf).head(2).raku;
say (1..*)[10];
my @a = 1..*;
say @a.is-lazy, " ", @a[3];
```
```output
(1.5, 2.5, 3.5).Seq
(-Inf, -Inf, -Inf).Seq
(NaN, NaN).Seq
().Seq
11
True 4
```

A method that needs every element does not, as a rule, refuse an endless
range: it starts and never returns, [as `.eager`
does](#ch:lists:array-copies-and-eager-returns-the-list-itself). `.elems`,
[as shown above](#ch:ranges:elems-counts-without-iterating-and-an-endless-range-fails),
and `.reverse`, just below, return a Failure instead.

## `reverse` of a fractional range counts down from its end
tags: bug

`reverse` returns a Seq. The documentation says that it holds "all elements
that the Range represents", reversed. For an Int range, or a range of single
characters, it is the elements in the opposite order, exclusions honoured.
For any other range, Rakudo 2026.08 starts at the end point (or one below
it, when the end is excluded) and counts down by one while it stays at or
above the start. The result is not the reversed list, and can hold values
the range never yields:

```raku
say (1^..5).reverse.raku;
say (1.1..4).list.raku;
say (1.1..4).reverse.raku;
say (1..4.5).list.raku;
say (1..4.5).reverse.raku;
say (0.5..^3).list.raku;
say (0.5..^3).reverse.raku;
```
```output
(5, 4, 3, 2).Seq
(1.1, 2.1, 3.1)
(4, 3, 2).Seq
(1, 2, 3, 4)
(4.5, 3.5, 2.5, 1.5).Seq
(0.5, 1.5, 2.5)
(2, 1).Seq
```

`.list.reverse` gives the elements reversed for any finite range. An endless
range returns a Failure of `X::Cannot::Lazy`, while `-Inf..3` counts down
from 3 forever.

## `first(:end, :kv)` counts its index from the end
tags: bug

`first` with `:end` [searches from the last element
backwards](#ch:lists:firstend-searches-from-the-end-and-refuses-a-lazy-list).
The documentation says that the index "is always counted from the beginning
of the list", and shows `:kv` with `:end` doing so; Roast asserts the same
for lists and arrays (`S32-list/first-end-kv.t`). On a Range, `:k` returns
the position counted from the front, and `:p` pairs that position with the
value. With `:kv` a Range in Rakudo 2026.08 returns the position counted
from the *end* instead, so the adverbs disagree. The same call on an Array
gives the position from the front.

```raku
my $r = 1..10;
say $r.first(* %% 3, :end);
say $r.first(* %% 3, :end, :k);
say $r.first(* %% 3, :end, :p).raku;
say $r.first(* %% 3, :end, :kv).raku;
my @a = 1..10;
say @a.first(* %% 3, :end, :kv).raku;
```
```output
9
8
8 => 9
(1, 9)
(8, 9)
```

The last two results differ only in the invocant. Without `:end`, `first` on
a range agrees with every other list; what it returns when nothing
matches is in [Nil, Any and the
Undefined](#ch:nil-any:first-answers-nil-when-nothing-matches).

## A loop over a range gets values, not containers
tags: undocumented

A range computes its elements; it does not store them, so there is nothing
to write back to. Changing `$_` in a `for` over a range dies, each way with
a different exception, and an `is rw` parameter is refused. `is copy` gives
the block its own variable. An array assigned from the range holds real
containers.

```raku
try { for 1..3 { $_++ } };
say $!.^name;
try { for 1..3 { $_ = 5 } };
say $!.message;
try { for 1..3 -> $x is rw { $x++ } };
say $!.^name;
my $total = 0;
for 1..3 -> $x is copy { $x *= 10; $total += $x }
say $total;
my @a = 1..3;
$_++ for @a;
say @a;
```
```output
X::Multi::NoMatch
Cannot assign to an immutable value
X::Parameter::RW
60
[2 3 4]
```

## A range in a list is one element
tags: trap

A Range is not flattened by the comma. `for 1..3, 7..8` has two elements to
iterate, the two ranges, and adding `$_` to a number adds each range's
count. `flat` or a slip opens them. Binding a range to an `@` variable keeps
it a Range, which cannot grow; assigning copies it into an Array.

```raku
for 1..3, 7..8 { say .raku }
my $s = 0;
$s += $_ for 1..3, 7..8;
say $s;
say (flat 1..3, 7..8).elems;
my @bound := 1..3;
say @bound.^name;
my @copied = 1..3;
say @copied.^name;
```
```output
1..3
7..8
5
5
Range
Array
```

The first sum is 3 + 2: each range counts as [its number of
elements](#ch:ranges:an-endless-range-is-inf-as-a-number-though-elems-fails).

## Indexing a range computes the element

`$r[$i]` on an Int range is worked out with an addition, so a position far
into an endless range costs nothing. Past the end the answer is `Nil`, not
`Any` as for an array. A fractional index is truncated and a string is
read as a number. `[*-1]` works on a finite range and dies with
`X::Cannot::Lazy` on an endless one, and a position that works out as
negative fails with `X::OutOfRange`.

```raku
my $r = 1..5;
say $r[1], " ", $r[*-1];
say $r[10].raku;
say $r[2.7], " ", $r["2"];
say (1..*)[1000000];
say (1.5..4)[1];
try (^5)[*-9].Str;
say $!.^name, ": ", $!.what, " ", $!.got;
try (1..*)[*-1];
say $!.^name;
```
```output
2 5
Nil
3 3
1000001
2.5
X::OutOfRange: Effective index -4
X::Cannot::Lazy
```

`EXISTS-POS`, the method behind `:exists`, is False for a negative, a
fractional or a string position, although indexing accepts the last two:

```raku
my $r = 1..5;
say $r.EXISTS-POS(4), " ", $r.EXISTS-POS(5);
say $r.EXISTS-POS(2.5), " ", $r.EXISTS-POS("1");
```
```output
True False
False False
```

## A range subscript selects its elements, and cannot go below zero

A range inside `[ ]` selects the positions that the range iterates, so the
exclusions count, and a range whose start is after its end selects nothing;
a reversed range selects backwards. A range of fractions selects by its own
elements:
`1.5..3` is the positions 1.5 and 2.5, which truncate to 1 and 2. Whether
the slice stops at the end of the array depends on how the range ends, [a
rule of the subscript](#ch:lists:an-endless-range-stops-at-the-end-of-the-array-a-finite-one-does-not)
rather than of the range. A range that reaches below zero dies, and in
`*..2` the `*` is `-Inf`, which is not a position at all.

```raku
my @l = <a b c d e>;
say @l[1.5..3];
say @l[1^..^4];
say @l[3..1].raku;
say @l[(1..3).reverse];
say @l[3..^*];
try @l[-1..1];
say $!.^name;
try @l[*..2];
say $!.^name;
```
```output
(b c)
(c d)
()
(d c b)
(d e)
X::OutOfRange
X::Numeric::CannotConvert
```

A hash subscript takes a range too, and looks up each element as a key:
`%h{1..2}` asks for the keys `"1"` and `"2"`. Strings take ranges with
[`substr` and `comb`](#ch:strings:substr-takes-a-range-or-code-but-not-3).

## A Range is immutable
tags: undocumented

A Range cannot be changed in place. `push`, `pop`, `shift`, `unshift`,
`append` and `prepend` throw `X::Immutable`, whose attributes name the type
and the method. `splice` has no candidate for a Range at all. Assigning to
an element or to an attribute fails, and so does binding an element. `.Array`
makes a copy that can change.

```raku
my $r = 1..5;
try $r.push(6);
say $!.^name, " ", $!.typename, " ", $!.method;
say $!.message;
try $r.splice(0, 1);
say $!.^name;
try $r[0] = 9;
say $!.^name;
try $r[0] := 9;
say $!.^name;
try $r.min = 2;
say $!.^name;
say $r.Array.push(6);
```
```output
X::Immutable Range push
Cannot call 'push' on an immutable 'Range'
X::Multi::NoMatch
X::Assignment::RO
X::Bind
X::Assignment::RO
[1 2 3 4 5 6]
```

## A number matches a numeric range by value, strings included

`$x ~~ $range` asks whether `$x` lies between the endpoints, not whether it
is one of the elements: 2.5 is inside `1..5`, and an excluded end is
compared exactly, however close the value. When both endpoints are numbers,
a string topic is read as a number first, so `"42"` and `" 3 "` match; a
string that is not a number simply does not match. Big Ints match an open
end, NaN matches nothing, and `True` is 1.

```raku
say 2.5 ~~ 1..5;
say 5 ~~ 1..^5;
say 4.9999999999999999999999 ~~ 0..^5;
say "42" ~~ 20..50;
say " 3 " ~~ 1..5;
say "abc" ~~ 1..10;
say 2**70 ~~ 1..*;
say NaN ~~ *..*;
say True ~~ 0..1;
```
```output
True
False
True
True
True
False
True
False
True
```

The third value is a Rat just below 5, so it is inside `0..^5`. The same
test is how `grep` and `when` use a range: `(1, 2, 3, 10).grep(2..5)` keeps
2 and 3. A list as the topic is a number too, its length, which [surprises
anyone expecting a pattern](#ch:lists:a-range-on-the-right-of-checks-a-lists-length).

## `'raku' ~~ -∞..∞` is False
tags: quirk

The documentation says that a string such as `'raku'` smartmatches an
infinite range, `1..*` and `-∞..∞` among them. In Rakudo 2026.08 it does
not: both endpoints are numbers, so the string is read as a number, and a
word is not one. When only one endpoint is a number, as in `*.."5"`, the
comparison is by string order instead, so 42 is below `"5"` but not below
`"3"`.

```raku
say "raku" ~~ 1..*;
say "raku" ~~ -∞..∞;
say 42 ~~ *..5;
say 42 ~~ *.."5";
say 42 ~~ *.."3";
say "5" ~~ *..10;
```
```output
False
False
False
True
False
True
```

The documentation also gives `'5' ~~ *..10` as False; since both endpoints
of `*..10` are numbers, `"5"` is read as 5, and it matches.

## A string range compares in string order, not by its elements
tags: trap

With string endpoints, membership is string order: a topic is inside when
it sorts at or after the start and at or before the end. That is not the
same as being an element. `"abc"` sorts between `"a"` and `"b"`, and `"ab"`
between `"a"` and `"ad"`, although neither range holds it. A number is
turned into a string, and capitals sort before small letters, [as in any
string
comparison](#ch:strings:lt-and-cmp-compare-code-points-so-capitals-sort-first).

```raku
say "abc" ~~ "a".."b";
say ("a".."b").list;
say "ab" ~~ "a".."ad";
say "B" ~~ "a".."z";
say "" ~~ "a".."z";
say 42 ~~ "3".."9";
say "d" ~~ "c"..*;
```
```output
True
(a b)
True
False
False
True
True
```

`42 ~~ "3".."9"` is True because `"42"` sorts between `"3"` and `"9"`.

## One range is inside another when its endpoints are

A range on the left of `~~` matches a range on the right when its start is
not before the other's start and its end not after the other's end, with the
exclusions taken into account. Only the endpoints are compared. `^5` holds
the same integers as `0..4`, but its end, 5, is beyond 4; the empty range
`5..1` is inside `1..5` because both its endpoints are. The types of the
endpoints do not matter.

```raku
say 2..3 ~~ 1..12;
say 1^..5 ~~ 1..5;
say 1..5 ~~ 1^..5;
say ^5 ~~ 0..4;
say 0..4 ~~ ^5;
say 5..1 ~~ 1..5;
say 1..2 ~~ 1e0..2e0;
say 1..10 ~~ -∞..∞;
say "a".."c" ~~ 1..5;
```
```output
True
True
False
False
True
True
True
True
False
```

A string range never fits in a numeric one. A numeric range is compared as
strings against a string range, so `1..2 ~~ "1".."2"` is True.

## Anything comparable can be a topic, and a Date range walks days

A range accepts any topic that can be compared with its endpoints. A
junction is tested value by value. A Complex number matches when its
imaginary part is zero or too small to matter. A Version is inside a
Version range, and a Date inside a Date range, which also iterates day by
day. A type object such as `Any` does not match, and warns; an object that
cannot be compared at all throws `X::Range::Incomparable`.

```raku
say <42+0i> ~~ 10..50;
say so (3|20) ~~ 1..9;
say so (3&20) ~~ 1..9;
say v1.5 ~~ v1.0..v2.0;
my $from = Date.new("2020-01-30");
my $to = Date.new("2020-02-02");
say Date.new("2020-02-01") ~~ $from..$to;
say ($from..$to).list;
try (1..3).ACCEPTS(Mu);
say $!.message;
```
```output
True
True
False
True
True
(2020-01-30 2020-01-31 2020-02-01 2020-02-02)
Value of type 'Mu' cannot be compared with range minimum of type 'Int'
```

Dates themselves are the subject of [Dates and Times](#ch:dates).

## `in-range` returns True or throws

`$range.in-range($value)` is a check that fails loudly: True when the value
is inside, an `X::OutOfRange` exception otherwise. An optional second
argument names the value in the message, in place of the word "Value".

```raku
say (1..5).in-range(3);
say (1..5).in-range(2.5);
try (1..5).in-range(7);
say $!.^name;
say $!.message;
try ("a".."c").in-range("d", "Letter");
say $!.message;
```
```output
True
True
X::OutOfRange
Value out of range. Is: 7, should be in 1..5
Letter out of range. Is: "d", should be in "a".."c"
```

## Arithmetic with a number moves the endpoints, not the elements
tags: trap

`+`, `-`, `*` and `/` between a Range and a number do not act on each
element. They build a new range from the endpoints, keeping the exclusions
and the type, so a role mixed into the range survives. Multiplying a range
therefore scales its endpoints and leaves the step at one, and multiplying
by a negative number makes an empty range.

```raku
my $r = 1..^10;
say ($r + 1).raku;
say ($r - 1).raku;
say ($r / 2).raku;
say ($r * 2).raku;
say ($r * 2).list;
say ((1..10) * -1).raku, " ", ((1..10) * -1).elems;
my $tagged = (2..^5) but role Tagged { };
say ($tagged + 5).^name;
```
```output
2..^11
^9
0.5..^5.0
2..^20
(2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19)
-1..-10 0
Range+{Tagged}
```

`$r.map(* * 2)` doubles each element. Only a real number on the left of `+`
and `*`, or on the right of any of the four, gets the Range treatment. Any
other combination turns the range into a number, its count:

```raku
my $r = 1..10;
say 1 - $r;
say 2 / $r;
say $r + "1";
say $r + 1i;
```
```output
-9
0.2
11
10+1i
```

## A string range plus a number gets Failure endpoints
tags: quirk

Arithmetic on a range works on its endpoints even when they are strings. The
letters do not convert to numbers, so the new range is built from two
Failures, and nothing complains until the range is used.

```raku
my $letters = "a".."c";
my $shifted = $letters + 1;
say $shifted.^name;
say $shifted.min.^name;
say $shifted.max.exception.message;
say $shifted.elems;
```
```output
Range
Failure
Cannot convert string to number: base-10 number must begin with valid digits or '.' in '<HERE>c' (indicated by <HERE>)
```
```stderr
Cannot convert string to number: base-10 number must begin with valid digits or '.' in '<HERE>a' (indicated by <HERE>)
  in block <unit> at example.raku line 2

Actually thrown at:
  in block <unit> at example.raku line 6

```

A Failure keeps its exception until it is used, [as in any arithmetic on a
string](#ch:numbers:a-string-that-is-not-a-number-makes-arithmetic-return-a-failure);
here `.elems` is the first use of the start.

## Ranges sort by start, then by end
tags: unasserted

`cmp` compares two ranges by their starts first, and an excluded start
counts as later than an included one. When the starts are equal, it
compares the ends, and an excluded end counts as earlier. A number on one
side is treated as a range from that number to itself, and a list is
compared with the range's elements. `sort` uses these rules.

```raku
say (1..2) cmp (1..3);
say (1^..2) cmp (1..2);
say (1..2) cmp 1;
say (1..2) cmp 2;
say (1..2) cmp [1, 2];
say ((1..3), (1..2), (0..5)).sort.raku;
say ((0..1), (0..^1), (0^..1)).sort.raku;
```
```output
Less
More
More
Less
Same
(0..5, 1..2, 1..3).Seq
(^1, 0..1, 0^..1).Seq
```

`<=>` and `leg` do not compare ranges: they turn both sides into numbers or
strings first. `(1..2) <=> (5..6)` is `Same`, two elements against two, and
`leg` compares `"5 6"` with `"1 2 3 4 5 6 7 8 9"`.

```raku
say (1..2) <=> (5..6);
say (5..6) leg (1..9);
```
```output
Same
More
```

## `sum` uses a formula, and answers an Int for a Num range
tags: unasserted

When a range starts at a whole number, `sum` does not add the elements up:
it uses the formula for an arithmetic series, so the sum of a range of
10**20 numbers is immediate. A fractional end is fine, since the elements
are still whole. The formula works with Ints, which gives an Int even when
the endpoints are Nums or Rats, where adding the elements would not. An
open end gives an infinity, and a range of letters fails.

```raku
say (1..10**20).sum;
say (0..5.5).sum;
say (1e0..3e0).sum.raku;
say (1e0..3e0).list.sum.raku;
say (1.0..3).sum.raku;
say (1..*).sum, " ", (*..5).sum, " ", (*..*).sum;
say (1.5..4).sum;
```
```output
5000000000000000000050000000000000000000
15
6
6e0
6
Inf -Inf NaN
7.5
```

A fractional start, as in the last line, sums the list: 1.5 + 2.5 + 3.5.

## `int-bounds` and `minmax` refuse what they cannot state

`int-bounds` returns the first and last integer that the range iterates. It
needs a whole-number start, of any numeric type, and a finite end; for
anything else it returns a Failure. With two variables as arguments it
stores the bounds in them and returns True or False. `minmax` is the same
list for an Int range and the two endpoints for any other, but it refuses a
non-Int range with an excluded end, as there is no last element to name.

```raku
say (2..^5).int-bounds;
say (0..5.5).int-bounds;
say (5..1).int-bounds;
say (1..5).int-bounds(my $lo, my $hi), " $lo $hi";
say (1.5..3).int-bounds.exception.message;
say (1^..^5).minmax;
say (3.5..4.5).minmax;
say ("a".."z").minmax;
say (1.5..^3).minmax.exception.message;
```
```output
(2 4)
(0 5)
(5 1)
True 1 5
Cannot determine integer bounds
(2 4)
(3.5 4.5)
(a z)
Cannot return minmax on Range with excluded ends
```

An empty range gives its bounds in reverse order, first above last. `^Inf`
counts as a non-Int range, since `Inf` is a Num, and its `minmax` fails too.

## `max(:k)` of an open range names an element that is not there
tags: undocumented quirk

`min` and `max` accept the adverbs `:k`, `:kv` and `:p`, to return the
position of the smallest or largest element. A Range answers from its
endpoints: the position is 0 for `min` and `.end`, the last position, for
`max`, which is `Inf` for an endless range and -1 for an empty one. The value
is the raw endpoint, excluded or not. For `2^..^6`, whose elements
are 3, 4 and 5, `max(:kv)` says position 2 holds 6. The list gives the
consistent answer.

```raku
my $open = 2^..^6;
say $open.list;
say $open.max(:kv).raku;
say $open.min(:kv).raku;
say $open.list.max(:kv).raku;
say (2..Inf).max(:k);
say (1..0).max(:k);
```
```output
(3 4 5)
(2, 6)
(0, 2)
(2, 5)
Inf
-1
```

## `pick` and `roll` choose without building the list

`pick` and `roll` without a count return one element; with a count they
return a Seq. On an Int range they choose by arithmetic, so a range of
2**125 numbers is no harder than a range of ten. `pick` never returns more
elements than the range has. An empty range gives Nil or an empty Seq, and
an endless range gives Nil.

```raku
say (1..100).pick.^name;
say (1..100).pick(1).^name;
say (1..100).pick(*).elems;
say (1..100).pick(200).elems;
say ((1 +< 125) .. (1 +< 126)).pick(3).elems;
say (1..0).pick.raku, " ", (1..0).pick(3).raku;
say (1..*).pick.raku, " ", (1..*).roll.raku;
say (1.5..3.5).pick(*).sort.raku;
```
```output
Int
Seq
100
100
3
Nil ().Seq
Nil Nil
(1.5, 2.5, 3.5).Seq
```

The rules for the count are [those of any
list](#ch:lists:pick-stops-at-the-size-of-the-list-roll-can-go-on-for-ever),
and a string count is converted. The answers at the edges are the Range's
own: an empty range gives an empty Seq where an empty List gives `()`, and
the endless range's `Nil` is where a lazy list returns a Failure of
`X::Cannot::Lazy`.

## After `srand`, the first `pick` from a range differs
tags: quirk

`srand` seeds the draws that follow. For `pick` and `roll` on a range, as
for `rand`, Rakudo 2026.08 replays them only from the second time:
the first `pick` that follows an `srand` draws differently from every later
`pick` after the same seed, whichever line the later call is on.

```raku
my @draws;
for ^3 {
    srand(42);
    @draws.push: (1..100).pick(3).join(",");
}
say @draws[0] eq @draws[1];
say @draws[1] eq @draws[2];
srand(42);
say (1..100).pick(3).join(",") eq @draws[2];
```
```output
False
True
True
```

The general rule, with `rand` and `roll`, is in
[Numbers](#ch:numbers:srand-repeats-a-sequence-only-from-its-second-run).

## `rand` returns a real number, and refuses an empty span

`.rand` on a range returns a random Num between the endpoints, never equal
to an excluded one. It needs two real endpoints with room between them. A
range whose start is not below its end, or that has an infinite or NaN
endpoint, gives a Failure of `X::Range::Rand::InvalidEndpoints`, and a
range of strings a Failure that suggests `pick`.

```raku
my $x = (1..10).rand;
say $x.^name, " ", 1 <= $x <= 10;
say (1..1).rand.exception.^name;
say (1..1).rand.exception.message;
say (1..Inf).rand.exception.^name;
say ("a".."z").rand.exception.message;
```
```output
Num True
X::Range::Rand::InvalidEndpoints
Impossible to generate random numbers for a range where endpoints are equal
X::Range::Rand::InvalidEndpoints
Can only get a random value on Real values, did you mean .pick?
```

## A Range converts to lists and hashes; its Capture has six names

`.list` is a List, and `.flat` and `.Seq` are Seqs; for an endless range all
of them, and `.Array`, stay lazy. `keys`, `kv` and `pairs` number the
elements from 0. `.Map` and `.Hash` pair up the elements, and an odd count
throws `X::Hash::Store::OddNumber`.

```raku
my $r = 1..4;
say $r.list.^name, " ", $r.Seq.^name, " ", $r.Array.^name;
say $r.kv;
say $r.antipairs;
say $r.Hash.raku;
try (1..3).Hash;
say $!.^name;
say (1..*).Array.is-lazy;
```
```output
List Seq Array
(0 1 1 2 2 3 3 4)
(1 => 0 2 => 1 3 => 2 4 => 3)
{"1" => 2, "3" => 4}
X::Hash::Store::OddNumber
True
```

`.Capture` holds no elements at all: it is six named arguments describing
the range. A sub-signature can unpack a range through it, but it must accept
the names it does not want, with `*%`:

```raku
say (1..^3).Capture.raku;
sub span((:$min, :$max, *%)) { "$min to $max" }
say span(3..7);
sub strict((:$min, :$max)) { "$min to $max" }
try strict(3..7);
say $!.^name;
```
```output
\(:excludes-max, :!excludes-min, :!infinite, :is-int, :max(3), :min(1))
3 to 7
X::AdHoc
```

## String methods see the range's text
tags: quirk undocumented

A Range is a `Cool`, so the string methods work on it, and they work on its
`.Str`: the elements joined by spaces. `.chars` of `1..3` is 5 and `.flip`
reverses the text. Numeric methods see its count. `succ` and `pred` do not
exist for a range. `contains` and `index` answer from the text but first
warn that they do, since a search among the elements was more likely meant.

```raku
my $r = 1..3;
say $r.chars;
say $r.flip;
say $r.sqrt;
say $r ~ "!";
try $r.succ;
say $!.^name;
say (10..12).contains("0 1");
```
```output
5
3 2 1
1.7320508075688772
1 2 3!
X::Method::NotFound
True
```
```stderr
Applying '.contains' to a Range will look at its .Str representation.
Did you mean 'needle (elem) Range'?
  in block <unit> at example.raku line 8
```

`"0 1"` is found across the space between 10 and 11. Lists behave
[the same way](#ch:strings:contains-on-a-list-searches-the-lists-text),
with a warning of their own.

## Each numeric type has a Range, and a native type its exact bounds

`.Range` on a numeric type returns the values it can hold. `Int` gives
`-Inf^..^Inf` and `UInt` `0..^Inf`; `Num` and `Rat` include the
infinities. The native integer types give their exact limits. Being ranges,
they test magnitude only: 1.5 is inside `Int.Range`. `Str` has no `.Range`,
and an instance such as `42` is refused.

```raku
say Int.Range.raku, " ", UInt.Range.raku;
say Num.Range.raku;
say int8.Range.raku, " ", byte.Range.raku;
say uint64.Range.raku;
say 200 ~~ int8.Range, " ", 2**70 ~~ UInt.Range;
say 1.5 ~~ Int.Range;
say Inf ~~ Int.Range, " ", Inf ~~ Num.Range;
try 42.Range;
say $!.^name;
```
```output
-Inf^..^Inf 0..^Inf
-Inf..Inf
-128..127 0..255
0..18446744073709551615
False True
True
False True
X::Parameter::InvalidConcreteness
```

## The Range type object is a list of one undefined element
tags: undocumented unasserted

`Range` itself behaves like any type object in a list: [one
element](#ch:nil-any:a-type-object-is-a-list-of-one-element-too), itself. It
is false and undefined, and as a number it is 0 with a warning. The methods
that need endpoints refuse it. `5 ~~ Range` is a type check, and a Range is
a Positional and an Iterable but not a List.

```raku
say Range.elems;
say Range.list.raku;
say ?Range, " ", Range.defined;
try Range.min;
say $!.^name;
say 5 ~~ Range, " ", (1..2) ~~ Range;
say Range.^mro.map(*.^name);
say (1..2) ~~ Positional, " ", (1..2) ~~ List;
say +Range;
```
```output
1
(Range,)
False False
X::AdHoc
False True
(Range Cool Any Mu)
True False
0
```
```stderr
Use of uninitialized value of type Range in numeric context
  in block <unit> at example.raku line 9
```
