---
title: The Sequence Operator
part: Collections
summary: How `...` turns a few seeds and an endpoint into a sequence, deducing a step or calling a generator, and the places where its endpoint, its seeds and its chains behave unlike the examples suggest.
---

The sequence operator `...` builds a list from a few starting values, the
*seeds*, and a description of where to stop, the *endpoint*. Between the
two, it either deduces how to get from one element to the next, or calls a
*generator*, a piece of code placed after the seeds. `1, 3 ... 9` gives the
odd numbers up to nine; `1, 1, * + * ... *` gives the Fibonacci numbers
without end.

The rules behind those two lines are more intricate than they look: which
values count as seeds and which as the endpoint, how many seeds a step is
deduced from, when a number stops the sequence and when it has to be hit
exactly, how strings are walked, and how several `...` in a row join up.
This chapter goes through them.

The operator's precedence, just below the comma, is in [Who Takes the
Operand](#ch:precedence:the-comma-binds-tighter-than-z-x-and). Ranges,
built with `..`, follow different rules and have [their own
chapter](#ch:ranges). The Seq that `...` returns, and what can be done with
it, is in [Lists, Arrays, Seqs and Slips](#ch:lists).

## `...` has four spellings, and `…` is the same operator

`...` returns a Seq holding the seeds and everything generated after them, up
to and including the element that matched the endpoint. A caret after the
operator, `...^`, leaves out that last element; a caret before it, `^...`,
leaves out the first element of the result; `^...^` leaves out both. Each
form can also be written with the single character `…`, which is the very
same routine.

```raku
say (1 ... 5).raku;
say (1 ...^ 5).raku;
say (1 ^... 5).raku;
say (1 ^...^ 5).raku;
say (5 … 1).raku;
say &infix:<…> === &infix:<...>;
```
```output
(1, 2, 3, 4, 5).Seq
(1, 2, 3, 4).Seq
(2, 3, 4, 5).Seq
(2, 3, 4).Seq
(5, 4, 3, 2, 1).Seq
True
```

When the seed is the endpoint, the sequence has one element, and either
exclusion leaves it empty:

```raku
say (1 ... 1).raku;
say (1 ...^ 1).raku;
say (1 ^... 1).raku;
```
```output
(1,).Seq
().Seq
().Seq
```

## Only `*` and `Inf` make a sequence lazy
tags: trap

A lazy sequence computes its elements only when they are asked for. `...`
returns one when the endpoint is `*`, `Inf` or `∞`, whether written as such
or held in a variable. Any other endpoint gives a sequence that is not lazy,
even a code endpoint, which cannot know in advance where it will stop, and
even an endpoint that the sequence never reaches.

```raku
say (1 ... *).is-lazy;
my $end = Inf;
say (1 ... $end).is-lazy;
say (1, * * 2 ... *).is-lazy;
say (1 ... 5).is-lazy;
say (1, * * 2 ... 64).is-lazy;
say (1 ... { $_ > 3 }).is-lazy;
```
```output
True
True
True
False
False
False
```

The difference shows when the sequence is printed or stored. A lazy sequence
[prints as `(...)`](#ch:lists:gist-stops-at-100-elements-and-a-lazy-list-prints),
and an array assigned from it stays lazy, computing only the elements that
are indexed. [It cannot be
counted](#ch:lists:a-lazy-list-can-be-indexed-but-not-counted).

```raku
say (1 ... *).gist;
my @a = 1 ... *;
say @a.is-lazy;
say @a[4];
say (1 ... *)[^4];
```
```output
(...)
True
5
(1 2 3 4)
```

A sequence that is not lazy is computed in full as soon as it is assigned to
an array, counted or printed with `.raku`. If it never ends, as in the
corners below where an endpoint cannot match, the program never returns.

## The first element on the right is the endpoint; the rest is appended
tags: undocumented

The right operand of `...` is read as a list. Its first element is the
endpoint, and any further elements are added after the sequence, unchanged
and whatever their type, whether the endpoint was reached or not. Because
the comma binds tighter than `...`, a comma list after the operator is all
on its right.

```raku
say (1 ... 3, 10, 20).raku;
say (1 ... 3, 'x').raku;
say (1 ... 10, 4).raku;
say (1 ... 2.5, 10).raku;
my $l = (3, 9);
say (1 ... $l).raku;
say (1 ... (3, 9)).raku;
```
```output
(1, 2, 3, 10, 20).Seq
(1, 2, 3, "x").Seq
(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 4).Seq
(1, 2, 10).Seq
(1, 2, 3, 9).Seq
(1, 2, 3, 9).Seq
```

A list in a scalar or in parentheses is read in the same way, and so is a
Range when it is the whole right side: `1 ... 3..5` has the endpoint 3,
followed by 4 and 5, and `1 ... ^3` counts down to 0 and then appends 1 and
2. Inside a longer list, a Range is one element, as it is [anywhere
else](#ch:ranges:a-range-in-a-list-is-one-element); it is then the
endpoint, and a value inside it ends the sequence.

```raku
say (1 ... 3..5).raku;
say (1 ... ^3).raku;
say (1 ... 5..6, 8).raku;
say (1 ... 1.5..2.5, 8).raku;
```
```output
(1, 2, 3, 4, 5).Seq
(1, 0, 1, 2).Seq
(1, 2, 3, 4, 5, 8).Seq
(1, 2, 8).Seq
```

## An empty right side fails at once; an empty left side fails later
tags: undocumented

A sequence needs at least one seed and an endpoint. Without an endpoint,
`...` throws `X::Cannot::Empty` as soon as it runs. Without seeds, it
returns a Seq, and the same exception comes when an element is asked for.

```raku
my $s = (() ... 5);
say $s.^name;
try $s.eager;
say $!.message;
try my $t = (1 ... ());
say $!.message;
```
```output
Seq
Cannot get sequence start value from an empty list
Cannot get sequence endpoint from an empty list (use * or :!elems instead?)
```

A Failure as the endpoint throws its exception when `...` runs, before any
element is computed:

```raku
sub endpoint { fail "no endpoint today" }
my $f = endpoint();
my $s = (1 ... $f);
```
```output
```
```stderr
no endpoint today
  in sub endpoint at example.raku line 1
  in block <unit> at example.raku line 2

Actually thrown at:
  in block <unit> at example.raku line 3

```

## The seeds are checked against the endpoint before anything else

Every seed is compared with the endpoint, one after another, before any step
is deduced. The first seed that matches ends the sequence, and the seeds
after it are dropped; with `...^` the matching seed goes too. A step is
deduced only when no seed matches, so seeds that fit no pattern at all are
harmless as long as the endpoint is among them.

```raku
say (1, 2, 3 ... 2).raku;
say (1, 2, 3 ...^ 2).raku;
say (1, 2, 4, 7 ... 2).raku;
say (1, 2, 4, 7 ... 7).raku;
say (1, 1, 1 ... 1).raku;
```
```output
(1, 2).Seq
(1,).Seq
(1, 2).Seq
(1, 2, 4, 7).Seq
(1,).Seq
```

With 8 as the endpoint, the same seeds `1, 2, 4, 7` have to be continued,
and the sequence fails, as [a later
corner](#ch:sequences:a-failed-deduction-throws-when-the-sequence-is-read-not-when-it-is-built)
shows.

## A numeric endpoint is a limit, not a target
tags: trap

When the seeds are numbers and no generator is given, a numeric endpoint
does not have to be hit. The sequence stops before the first value that
would pass it, in the direction of travel. The endpoint's type has no
influence on the elements: an Int sequence stays Int up to a Num endpoint.

```raku
say (1, 3 ... 10).raku;
say (1 ... 3.5).raku;
say (1 ... 0.5).raku;
say (1, 2 ... 4e0).raku;
say (0.1, 0.2 ... 0.3).raku;
say (0.1e0, 0.2e0 ... 0.3).raku;
```
```output
(1, 3, 5, 7, 9).Seq
(1, 2, 3).Seq
(1,).Seq
(1, 2, 3, 4).Seq
(0.1, 0.2, 0.3).Seq
(0.1e0, 0.2e0).Seq
```

`1 ... 0.5` counts down from 1, and the next value, 0, is already below the
limit. The last line is the floating-point trap: the third Num is
0.30000000000000004, just past 0.3, so it is not produced. With Rats, as on
the line before, the arithmetic is exact. A sequence with a generator
treats a numeric endpoint quite differently, as [shown
below](#ch:sequences:with-a-generator-a-numeric-endpoint-must-be-hit-exactly).

## Any other endpoint is smartmatched, and the walk goes upwards
tags: trap

An endpoint that is not a number is never converted to one. Each value is
smartmatched against it: a string matches by string equality, a regex by
matching, a junction by its eigenstates, a type object by type. An
allomorph such as `<3>` is a number, and behaves as one.

```raku
say (1 ... "3").raku;
say (1 ... /3/).raku;
say ("aa" ... /ac/).raku;
say (1 ... any(3, 5)).raku;
say (1 ... Int).raku;
say (5 ... <3>).raku;
```
```output
(1, 2, 3).Seq
(1, 2, 3).Seq
("aa", "ab", "ac").Seq
(1, 2, 3).Seq
(1,).Seq
(5, 4, 3).Seq
```

Only a numeric endpoint can make a numeric sequence count down. With any
other endpoint the values go up, one by one, whatever the endpoint seems to
say, and a string that is not the exact text of an element never matches.
`True` matches every value, and `False` none at all:

```raku
say (5 ... "3").head(4).raku;
say (1 ... "3.0").head(5).raku;
say (5 ... 3|1).head(4).raku;
say (1 ... True).raku;
say (1 ... False).head(4).raku;
```
```output
(5, 6, 7, 8).Seq
(1, 2, 3, 4, 5).Seq
(5, 6, 7, 8).Seq
(1,).Seq
(1, 2, 3, 4).Seq
```

None of these endless sequences is lazy, so without the `.head` each line
would never return.

## A `none` junction as the endpoint makes the sequence endless
tags: bug undocumented

A `none` junction ought to be smartmatched like any other endpoint:
`1 ... none(1, 2)` should stop at 3, the first value that is neither 1 nor
2. In Rakudo 2026.08 it is a lazy sequence that never stops. Before looking
at the endpoint, the operator tests whether it is infinite by comparing it
with `Inf`, and the junction answers that test too: "neither 1 nor 2 is
`Inf`" is true. The same condition in a block works.

```raku
say (1 ... none(1, 2)).is-lazy;
say (1 ... none(1, 2)).head(5).raku;
say (1 ... { $_ ~~ none(1, 2) }).raku;
say so none(1, 2) === Inf;
```
```output
True
(1, 2, 3, 4, 5).Seq
(1, 2, 3).Seq
True
```

## One or two seeds make an arithmetic sequence

A single numeric seed steps by 1, up or down towards a numeric endpoint,
and up towards `*`. The type of the seed is kept, so a Rat seed gives Rats
and a Num seed gives Nums. Two seeds step by their difference.

```raku
say (1 ... -2).raku;
say (1.5 ... 4).raku;
say (1e0 ... 3).raku;
say (10, 8 ... 1).raku;
say (1, 1/2 ... -1).raku;
say (1/3, 2/3 ... 1).raku;
```
```output
(1, 0, -1, -2).Seq
(1.5, 2.5, 3.5).Seq
(1e0, 2e0, 3e0).Seq
(10, 8, 6, 4, 2).Seq
(1, 0.5, 0.0, -0.5, -1.0).Seq
(<1/3>, <2/3>, 1.0).Seq
```

The second element of `1, 1/2 ... -1` prints as `0.5`, not `<1/2>`: it is
not the seed as written but a value computed from the first seed, a rule
[with consequences of its
own](#ch:sequences:only-the-first-seed-is-emitted-as-written).

## Three seeds make an arithmetic or a geometric sequence

With three or more numeric seeds, the operator looks for a constant
difference first, then for a constant ratio. A difference of zero is a
constant sequence. The ratio is an Int when it is a whole number and a Rat
otherwise, so a sequence that divides by three continues in Rats.

```raku
say (1, 3, 5 ... 11).raku;
say (1, 1, 1 ... *).head(4).raku;
say (1, 2, 4 ... 33).raku;
say (81, 27, 9 ... 1).raku;
say (1, 1.5, 2.25 ... 4).raku;
say (2, 6, 18 ... *).head(5).raku;
```
```output
(1, 3, 5, 7, 9, 11).Seq
(1, 1, 1, 1).Seq
(1, 2, 4, 8, 16, 32).Seq
(81, 27.0, 9.0, 3.0, 1.0).Seq
(1, 1.5, 2.25, 3.375).Seq
(2, 6, 18, 54, 162).Seq
```

A zero among the seeds rules out a ratio, so `1, 0, 0` fits neither rule,
although "multiply by zero" would describe it.

## Only the first seed is emitted as written

With a deduced step, the seeds after the first are not passed through. They
are computed again from the first seed and the step, so their type is the
type of that arithmetic, not the type they were written in. The step is
taken from the first two seeds: a Rat or a Num among them makes every later
element a Rat or a Num, while a Num written as the third seed can come out
as an Int.

```raku
say (1, 1.5 ... 3).raku;
say (1.0, 2 ... 4).raku;
say (1e0, 2 ... 3).raku;
say (1, 2e0 ... 3).raku;
say (1, 2.0, 3 ... 5).raku;
say (1, 2, 3e0 ... 5).raku;
```
```output
(1, 1.5, 2.0, 2.5, 3.0).Seq
(1.0, 2.0, 3.0, 4.0).Seq
(1e0, 2e0, 3e0).Seq
(1, 2e0, 3e0).Seq
(1, 2.0, 3.0, 4.0, 5.0).Seq
(1, 2, 3, 4, 5).Seq
```

In the last line the step is the Int 1, and the `3e0` is replaced by the
Int 3.

## Only the last three seeds decide the step

When more than three seeds are given, all but the last three are emitted
as they are, and only the last three are used to deduce the step. The
earlier ones need not follow any pattern.

```raku
say (1, 5, 2, 4, 6 ... 12).raku;
say (9, 8, 7, 1, 2, 3 ... 6).raku;
try (1, 3, 5, 7, 9, 12 ... 24).eager;
say $!.from;
```
```output
(1, 5, 2, 4, 6, 8, 10, 12).Seq
(9, 8, 7, 1, 2, 3, 4, 5, 6).Seq
7,9,12
```

The odd numbers in the third line are a perfect arithmetic sequence until
the 12, but only `7, 9, 12` counts, and it fits no rule. The exception's
`.from` names exactly those three.

## A failed deduction throws when the sequence is read, not when it is built

When the seeds fit neither a difference nor a ratio, the operator still
returns a Seq, lazy if the endpoint says so. The exception,
`X::Sequence::Deduction`, is thrown only when a value that needs the step
is asked for. Its message suggests that `..` might have been meant.

```raku
my $s = (1, 2, 4, 7 ... *);
say $s.^name;
say $s.is-lazy;
try $s.eager;
say $!.^name;
say $!.from;
say $!.message;
```
```output
Seq
True
X::Sequence::Deduction
2,4,7
Unable to deduce arithmetic or geometric sequence from: 2,4,7
Did you really mean '..'?
```

The seeds before the last three are emitted as usual, so a loop over the
sequence gets as far as them before it dies:

```raku
for (1, 2, 4, 7 ... *) { say $_ }
```
```output
1
```
```stderr
Unable to deduce arithmetic or geometric sequence from: 2,4,7
Did you really mean '..'?
  in block <unit> at example.raku line 1

```

## Seeds already beyond the endpoint produce nothing at all
tags: quirk undocumented

For a deduced step, the direction of travel is the sign of the step, not
the position of the endpoint. When the seeds already lie beyond the
endpoint in that direction, Rakudo produces nothing, not even the seeds
that were written. A step of zero counts as downwards: `1, 1 ... 2` is
empty, and `2, 2 ... 1` never ends. Seeds before the last three are still
emitted, since they take no part in the step. A single seed has no step and
simply turns towards the endpoint.

```raku
say (5, 6 ... 3).raku;
say (5, 4 ... 7).raku;
say (1, 2, 3 ... 0).raku;
say (1, 1 ... 2).raku;
say (2, 2 ... 1).head(4).raku;
say (1, 2, 4, 5, 6 ... 3).raku;
say (5 ... 3).raku;
```
```output
().Seq
().Seq
().Seq
().Seq
(2, 2, 2, 2).Seq
(1, 2).Seq
(5, 4, 3).Seq
```

A natural reading would emit the seeds, or run on for ever; the empty result
is simply what Rakudo does.

## A geometric sequence stops by size only for a negative ratio

A ratio above 1 stops before the first value above the endpoint, and a ratio
between 0 and 1 before the first value below it. A negative ratio makes the
values alternate in sign, and the sequence stops before the first value
whose absolute value passes the endpoint's, so the endpoint's own sign does
not matter. A ratio of −1 never passes anything and never ends.

```raku
say (1, 2, 4 ... 3).raku;
say (8, 4, 2 ... 3).raku;
say (1, -2, 4 ... 100).raku;
say (1, -2, 4 ... -100).raku;
say (1, -1, 1 ... 5).head(6).raku;
```
```output
(1, 2).Seq
(8, 4.0).Seq
(1, -2, 4, -8, 16, -32, 64).Seq
(1, -2, 4, -8, 16, -32, 64).Seq
(1, -1, 1, -1, 1, -1).Seq
```

## A geometric sequence of negative numbers misses its endpoint
tags: bug

The stopping rule of the previous corner looks only at the ratio. For
negative seeds and a ratio above 1, the values fall, but Rakudo 2026.08
still stops before the first value *above* the endpoint, and the first seed
already is: `-1, -2, -4 ... -16` is empty, although -16 is on its path. An
endpoint above every value is never passed, and that sequence never ends.
A ratio below 1 fails the same way. The arithmetic sequence of the first
line shows the intended behaviour: stop at the endpoint.

```raku
say (-1, -3 ... -9).raku;
say (-1, -2, -4 ... -16).raku;
say (-16, -8, -4 ... -1).raku;
say (-1, -2, -4 ... -0.5).head(6).raku;
say (-1, -2, -4 ... * <= -16).raku;
```
```output
(-1, -3, -5, -7, -9).Seq
().Seq
().Seq
(-1, -2, -4, -8, -16, -32).Seq
(-1, -2, -4, -8, -16).Seq
```

A code endpoint, as in the last line, is the way round it.

## A code object among the seeds is the generator, and ends them

The first piece of code on the left of `...` is the generator, and it closes
the list of seeds: whatever follows it is ignored, without a warning. A
generator can stand alone, with no seeds at all; if it takes no parameters,
it is simply called again for every element.

```raku
say (1, { $_ + 10 }, 99, 98 ... 31).raku;
say ({ 7 } ... *).head(3).raku;
say (-> { 42 } ... *).head(3).raku;
say (1, -> { 42 } ... *).head(4).raku;
```
```output
(1, 11, 21, 31).Seq
(7, 7, 7).Seq
(42, 42, 42).Seq
(1, 42, 42, 42).Seq
```

## A generator receives as many previous values as it has parameters

The generator is called with the last values of the sequence so far, seeds
included, as many as it has parameters. `* + *` and `-> $a, $b` take two,
`{ $_ * 2 }` one. An anonymous `$` parameter takes a value and ignores it,
and a slurpy parameter, including the implicit `@_`, receives every value
produced so far.

```raku
say (1, 1, * + * ... *).head(8).raku;
say (5, { $_ * 2 } ... 40).raku;
say (1, 1, 1, -> $a, $b, $ { $a + $b } ... *)[3..10].raku;
say (1, 2, { @_.sum } ... *).head(6).raku;
say (1, 2, 3, { $^a * $^b * $^c } ... *).head(6).raku;
```
```output
(1, 1, 2, 3, 5, 8, 13, 21).Seq
(5, 10, 20, 40).Seq
(2, 2, 3, 4, 5, 7, 9, 12)
(1, 2, 3, 6, 12, 24).Seq
(1, 2, 3, 6, 36, 648).Seq
```

## A generator dies if the seeds are fewer than its parameters
tags: unasserted

When a generator needs more values than the sequence holds, it is not given
fewer, and nothing is filled in: the call fails with the ordinary "too few
positionals" error, when the first generated element is asked for. An
optional parameter lowers the minimum, and the generator then receives what
there is.

```raku
say (1, * + * ... *).head(1).raku;
try (1, * + * ... *).head(2).eager;
say $!.message;
say (1, -> $a, $b = 10 { $a + $b } ... *).head(3).raku;
```
```output
(1,).Seq
Too few positionals passed; expected 2 arguments but got 1
(1, 11, 12).Seq
```

In the last line the first call receives only 1 and uses the default 10;
the second receives 1 and 11.

## With a generator, a numeric endpoint must be hit exactly
tags: trap

[A deduced sequence](#ch:sequences:a-numeric-endpoint-is-a-limit-not-a-target)
treats a numeric endpoint as a limit. With a generator, the endpoint is only
smartmatched against each value, and a value that jumps over it does not
stop anything: `5, { $_ * 2 } ... 41` goes on doubling for ever. A code
endpoint that compares, such as `* >= 41`, states the limit.

```raku
say (5, { $_ * 2 } ... 40).raku;
say (5, { $_ * 2 } ... 41).head(6).raku;
say (5, { $_ * 2 } ... * >= 41).raku;
say (1, * + 2 ... 10).head(6).raku;
```
```output
(5, 10, 20, 40).Seq
(5, 10, 20, 40, 80, 160).Seq
(5, 10, 20, 40, 80).Seq
(1, 3, 5, 7, 9, 11).Seq
```

Such a sequence is not lazy either, so assigning it to an array does not
return:

```raku nocheck
my @odd = 1, * + 2 ... 10;
```

## A code endpoint receives as many values as it has parameters

A piece of code as the endpoint is called with the last values, as many as
it has parameters, and the value that makes it return True ends the
sequence, included unless the operator is `...^`. It is first called as soon
as enough values exist, seeds included. A slurpy parameter receives
everything so far, and a block without a signature is called with the
current value, which it may ignore.

```raku
say (1, * * 2 ... * > 10).raku;
say (1, * * 2 ...^ * > 10).raku;
say (1 ... { $^a + $^b > 8 }).raku;
say (1 ... -> *@all { @all.sum > 10 }).raku;
say (1, 2, 3, 4, 5 ... { $^a + $^b == 3 }).raku;
say (1 ... { True }).raku;
```
```output
(1, 2, 4, 8, 16).Seq
(1, 2, 4, 8).Seq
(1, 2, 3, 4, 5).Seq
(1, 2, 3, 4, 5).Seq
(1, 2).Seq
(1,).Seq
```

`{ $^a + $^b > 8 }` first sees 1 and 2, then 2 and 3, and stops when it
sees 4 and 5. A type object as the endpoint stops at the first value of that
type, which lets a generator end the sequence by changing type:

```raku
sub countdown($n) { $n > 1 ?? $n - 1 !! "liftoff" }
say (3, &countdown ... Str).raku;
```
```output
(3, 2, 1, "liftoff").Seq
```

## `last` inside a generator or an endpoint ends the sequence
tags: undocumented

A generator can end the sequence itself with `last`: the values produced so
far are the whole sequence. `last` inside a code endpoint also ends it, but
before the value being tested, which is left out. The sequences below have
`*` as their endpoint and are lazy, so `.eager` computes them, and returns a
List.

```raku
say (1, { last if $_ > 3; $_ + 1 } ... *).eager.raku;
say (5, 4, 3, { $_ - 1 || last } ... *).eager.raku;
say (1, { last } ... *).eager.raku;
say (1 ... { last if $_ > 2; False }).raku;
```
```output
(1, 2, 3, 4)
(5, 4, 3, 2, 1)
(1,)
(1, 2).Seq
```

## A Slip from the generator adds several elements
tags: undocumented

A generator that returns a Slip adds each of its elements to the sequence,
and the next call receives them as its previous values. One generator can
thus run several sequences side by side. A List, `()` or `Nil` is a single
element: only a [Slip dissolves](#ch:lists:a-slip-dissolves-into-the-list-around-it).

```raku
say (1, { slip 2, 3 } ... *).head(5).raku;
say (1, 1, 1, { slip $^a + 1, $^b * 2, $^c - 1 } ... *).head(9).raku;
say ({ slip 'tick', 'tock' } ... *).head(5).raku;
say (1, { (2, 3) } ... *).head(3).raku;
say (1, { Nil } ... *).head(3).raku;
```
```output
(1, 2, 3, 2, 3).Seq
(1, 1, 1, 2, 2, 0, 3, 4, -1).Seq
("tick", "tock", "tick", "tock", "tick").Seq
(1, (2, 3), (2, 3)).Seq
(1, Nil, Nil).Seq
```

The second line counts up, doubles and counts down at once, three values
per call. An empty Slip adds nothing, and the generator is called again
straight away: a generator that keeps returning `Empty` makes even
`.head(2)` wait for ever.

## The endpoint is tested once per call of the generator
tags: bug undocumented

The documentation says that the endpoint is smartmatched against each
generated element. When the generator returns a Slip, Rakudo 2026.08 tests
the endpoint once for the whole call instead. A code endpoint receives the
last values after the Slip has been added, so it never sees the elements in
the middle. Any other endpoint is smartmatched against the Slip itself: as a
number a Slip is its length, and as a string its elements joined by spaces.

```raku
say (1, { slip 2, 3 } ... 3).head(6).raku;
say (1, { slip 5, 6 } ... 2).raku;
say (1, { slip 5, 6, 7 } ... "5 6 7").raku;
say (1, { slip 5, 6, 7 } ... * == 6).head(8).raku;
say (1, { slip $_ + 1, $_ + 2 } ... * > 6).raku;
```
```output
(1, 2, 3, 2, 3, 2).Seq
(1, 5, 6).Seq
(1, 5, 6, 7).Seq
(1, 5, 6, 7, 5, 6, 7, 5).Seq
(1, 2, 3, 4, 5, 6, 7).Seq
```

The 3 in the first line never ends the sequence, while the 2 in the second
ends it after a Slip that holds no 2 at all. The intended result of both is
to stop at the element equal to the endpoint.

## A sequence fails where it is read, which may be outside the `try`
tags: trap undocumented

A Seq computes its elements when something reads them, so an error in
producing them surfaces there, not where the sequence was written. A `try`
around the construction catches nothing; a `try` around the loop that reads
it catches the error, after the loop has seen the elements that came
before. (Looping over `$s` itself would give the Seq as [a single
item](#ch:lists:a-hash-spreads-into-its-pairs-a-seq-in-s-does-not); `@$s`
loops over its elements.)

```raku
my $s = try (1, 2, 4, 7 ... *);
say $s.^name;
my @got;
try { for @$s { @got.push($_) } }
say @got, " ", $!.^name;
```
```output
Seq
[1] X::Sequence::Deduction
```

A step that returns a Failure does not end the sequence or throw: the
Failure becomes an element. Walking down past `"a"` is such a step, since
[`"a".pred` fails](#ch:strings:pred-fails-where-succ-would-have-carried):

```raku
my @l = ('c', 'b', 'a' ... *).head(4);
say @l[3].^name;
say @l[3].exception.message;
```
```output
Failure
Decrement out of range
```

A fifth element would call `.pred` on that Failure, and that throws.

## Single characters walk the code points

One single-character string as the seed and another as the endpoint give
every code point between the two, upwards or downwards, punctuation
included, as a [range of single
characters](#ch:ranges:a-range-of-single-characters-walks-the-code-points)
does. Towards `*`, the walk uses `succ`, so `"z"` is followed by `"aa"`.

```raku
say ('a' ... 'e').raku;
say ('e' ... 'a').raku;
say ('A' ... 'a').elems;
say ('A' ... 'a').tail(6).raku;
say ('α' ... 'ω').join;
say ('z' ... *).head(3).raku;
```
```output
("a", "b", "c", "d", "e").Seq
("e", "d", "c", "b", "a").Seq
33
("\\", "]", "^", "_", "`", "a").Seq
αβγδεζηθικλμνξοπρςστυφχψω
("z", "aa", "ab").Seq
```

The Greek alphabet comes with the final sigma `ς`, which lies between `ρ`
and `σ` in Unicode.

## Strings of the same length vary each position separately
tags: trap

A seed and an endpoint of the same length, longer than one character, give
every combination of the characters between them position by position, as
[a range of such
strings](#ch:ranges:a-range-of-longer-strings-counts-each-position-separately)
does. Each position runs in its own direction. The result is not the walk
by `succ` that might be expected: from `"ay"` to `"bb"` the last position
runs from y down to b, twice.

```raku
say ('aa' ... 'cc').raku;
say ('ac' ... 'ca').raku;
say ('a1' ... 'c3').raku;
say ('ay' ... 'bb').elems;
say ('ay' ... 'bb').head(4).raku;
```
```output
("aa", "ab", "ac", "ba", "bb", "bc", "ca", "cb", "cc").Seq
("ac", "ab", "aa", "bc", "bb", "ba", "cc", "cb", "ca").Seq
("a1", "a2", "a3", "b1", "b2", "b3", "c1", "c2", "c3").Seq
48
("ay", "ax", "aw", "av").Seq
```

## `...^` keeps the end of a string sequence of equal lengths
tags: bug

Every operator with a final caret should leave out the element that matched
the endpoint, and for single characters `...^` does. For strings of equal
length and more than one character, Rakudo 2026.08 ignores the caret: the
endpoint is always included. The caret at the start still works.

```raku
say ('a' ...^ 'e').raku;
say ('aa' ...^ 'cc').raku;
say ('ab' ...^ 'aa').raku;
say ('aa' ^...^ 'cc').raku;
```
```output
("a", "b", "c", "d").Seq
("aa", "ab", "ac", "ba", "bb", "bc", "ca", "cb", "cc").Seq
("ab", "aa").Seq
("ab", "ac", "ba", "bb", "bc", "ca", "cb", "cc").Seq
```

## Strings of different lengths walk in string order
tags: trap undocumented

When the seed and the endpoint differ in length, the direction comes from
comparing them as strings. If the seed sorts before the endpoint, the walk
uses `succ` for as long as the value neither sorts after the endpoint nor
grows longer than it. If the seed sorts after the endpoint, the walk uses
`pred` for as long as the value does not sort before it. String order is
not length order, which is how `'z' ... 'aa'` comes to count down, and how
the digits `'9' ... '12'` stop at "2".

```raku
say ('a' ... 'zz').elems;
say ('a' ... 'bb').raku;
say ('z' ... 'aa').elems;
say ('x' ... 'ab').head(4).raku;
say ('9' ... '12').raku;
say ('bb' ... 'b').raku;
```
```output
702
("a", "b").Seq
25
("x", "w", "v", "u").Seq
("9", "8", "7", "6", "5", "4", "3", "2").Seq
("bb", "ba").Seq
```

`'a' ... 'bb'` stops after `"b"`, because `"c"` sorts after `"bb"`. A walk
downwards that has to pass below `"a"` dies, since `pred` fails there:

```raku
say 'ab' ... 'a';
```
```output
```
```stderr
Decrement out of range
  in block <unit> at example.raku line 1

```

## Two string seeds never make a step
tags: quirk undocumented

From numbers the operator deduces a step; from strings it never does. With
several string seeds, it continues from the last one with `succ` or `pred`
alone, so `'a', 'c' ... 'i'` goes on c, d, e and not c, e, g. The direction
comes from the last seed and the endpoint, compared as strings, not from
the seeds: `'x', 'y' ... 'ab'` turns round after y and walks backwards,
because "y" sorts after "ab". Towards `*`, the last two seeds decide.

```raku
say ('a', 'c' ... 'i').raku;
say ('x', 'y' ... 'ab').head(6).raku;
say ('c', 'b' ... 'e').head(4).raku;
say ('e', 'd' ... *).head(4).raku;
say (1, 'a' ... *).head(3).raku;
```
```output
("a", "c", "d", "e", "f", "g", "h", "i").Seq
("x", "y", "x", "w", "v", "u").Seq
("c", "b", "c", "d").Seq
("e", "d", "c", "b").Seq
(1, "a", "b").Seq
```

## Any type with `succ` and `pred` can be walked
tags: undocumented unasserted

The operator is not limited to numbers and strings. A seed of any type with
`succ`, `pred` and a comparison walks towards an endpoint of its type: Dates
go day by day, in either direction. Two Date seeds do not make a step; the
walk simply continues from the last one, and a generator gives any other
stride. A type without `succ`, such as Version, dies.

```raku
say Date.new('2026-01-30') ... Date.new('2026-02-02');
say Date.new('2026-01-03') ... Date.new('2026-01-01');
say Date.new('2026-01-01') ... *.day-of-week == 7;
say Date.new('2026-01-01'), Date.new('2026-01-08') ... Date.new('2026-01-11');
say (Date.new('2026-01-01'), * + 7 ... *.month == 2).map(*.day);
try (v1.0 ... v1.3).eager;
say $!.^name;
```
```output
(2026-01-30 2026-01-31 2026-02-01 2026-02-02)
(2026-01-03 2026-01-02 2026-01-01)
(2026-01-01 2026-01-02 2026-01-03 2026-01-04)
(2026-01-01 2026-01-08 2026-01-09 2026-01-10 2026-01-11)
(1 8 15 22 29 5)
X::Method::NotFound
```

## A chain of sequences starts each segment afresh
tags: undocumented

`...` is list associative, so `a ... b ... c` is one call, and it walks from
`a` to `b` and then from `b` to `c`, with `b` appearing once. Each segment
deduces its own step from its own seeds: after a middle endpoint, the
elements that follow it on its right are the next segment's seeds, together
with the endpoint itself.

```raku
say (1 ... 5 ... 1).raku;
say (1 ... 3 ... 6 ... 4).raku;
say ('a' ... 'c' ... 'a').raku;
say (1, 2 ... 4, 8 ... 32).raku;
say (0, 2 ... 8, 11 ... 17).raku;
say (1 ... 5 ... *).head(8).raku;
```
```output
(1, 2, 3, 4, 5, 4, 3, 2, 1).Seq
(1, 2, 3, 4, 5, 6, 5, 4).Seq
("a", "b", "c", "b", "a").Seq
(1, 2, 3, 4, 8, 12, 16, 20, 24, 28, 32).Seq
(0, 2, 4, 6, 8, 11, 14, 17).Seq
(1, 2, 3, 4, 5, 6, 7, 8).Seq
```

In `1, 2 ... 4, 8 ... 32` the second segment has the seeds 4 and 8, and
steps by 4. A code endpoint in the middle is used up by its segment and
does not seed the next one, which then needs seeds of its own:

```raku
say (1 ... { $_ == 3 }, 10 ... 6).raku;
try (1 ... { $_ == 3 } ... 6).eager;
say $!.message;
```
```output
(1, 2, 3, 10, 9, 8, 7, 6).Seq
Cannot get sequence start value from an empty list
```

## A chain always ends with its last endpoint
tags: bug undocumented

On its own, a numeric endpoint is a limit that the sequence may stop short
of. At the end of a chain, Rakudo 2026.08 emits the last endpoint whether it
was reached or not: `1 ... 5 ... 7.5` ends with 7 and then 7.5. It behaves
as if the last endpoint, like a middle one, started a further segment. In
the same way `^...^` in a chain drops only the first element and keeps the
last. The intended results are those of the unchained
operators: no 7.5, no 30, and no final 1.

```raku
say (1 ... 7.5).raku;
say (1 ... 5 ... 7.5).raku;
say (1, 2 ... 4, 8 ... 30).raku;
say (1 ^...^ 5 ^...^ 1).raku;
say (1 ^...^ 5 ^...^ 0.5).raku;
```
```output
(1, 2, 3, 4, 5, 6, 7).Seq
(1, 2, 3, 4, 5, 6, 7, 7.5).Seq
(1, 2, 3, 4, 8, 12, 16, 20, 24, 28, 30).Seq
(2, 3, 4, 5, 4, 3, 2, 1).Seq
(2, 3, 4, 5, 4, 3, 2, 1, 0.5).Seq
```

## `...^` cannot be chained
tags: undocumented unasserted

`...` and `^...` accept a chain, but `...^` takes exactly two operands, and
a chain of it does not compile. The message names the problem in terms of
the operator's signature:

```raku
say 1 ...^ 5 ...^ 1;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Calling infix:<...^>(Int, Int, Int) will never work with signature of the proto ($, Mu, *%)
at example.raku:1
------> say 1 ...^ 5 <HERE>...^ 1;
```

Mixing the spellings in one chain, as in `1 ... 5 ...^ 1`, is refused too,
with the message that [different operators on a list-associative level
need parentheses](#ch:precedence:different-junction-operators-do-not-mix-without-parentheses).

## The left side takes the elements of any list
tags: trap

Every element of the left operand is a seed, and a list of any kind
contributes its elements: an Array, a Range, even an endless one, whose
elements are checked against the endpoint one at a time. The result is
always a Seq; `eager` turns it into a List.

```raku
say ([1, 2, 3] ... 6).raku;
say (1..3 ... 6).raku;
say (1..* ... 5).raku;
my @seeds = 2, 4;
say (@seeds ... 10).raku;
say (eager 1 ... 3).^name;
```
```output
(1, 2, 3, 4, 5, 6).Seq
(1, 2, 3, 4, 5, 6).Seq
(1, 2, 3, 4, 5).Seq
(2, 4, 6, 8, 10).Seq
List
```

An assignment to a scalar is the usual trap. Item assignment binds tighter
than `...`, so `my $s = 1 ... 3` assigns 1 and [throws the sequence
away](#ch:whitespace:spacing-does-not-group-operands). With `*` as the
endpoint the discarded sequence is also endless, and [a sunk Seq runs to
the end](#ch:sink:a-sunk-seq-runs-to-the-end-even-a-lazy-one): this line
does not return.

```raku nocheck
my $s = 1 ... *;
```

Parentheses, `my $s = (1 ... *)`, or an array, `my @s = 1 ... *`, keep the
sequence.
