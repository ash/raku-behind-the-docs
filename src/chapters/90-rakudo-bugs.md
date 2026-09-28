---
title: Possible Bugs
part: Appendices
kind: appendix
summary: Every behaviour the chapters mark as a possible bug, with the evidence that makes it look unintended and the smallest program that shows it.
---

Some corners in this book carry the tag **Bug?**. It marks a behaviour
of Rakudo that looks unintended: something a program can run into, and could
come to depend on, although there is a reason to think it is not meant to
work that way. This appendix collects all of them in chapter order, so that
they can be scanned in one place, kept out of programs that are meant to
last, and reported to Rakudo's developers or examined further.

The tag asks a question; it does not answer it. Whether a behaviour is a bug
is for Rakudo's developers to decide, and some of these may prove to be
intended, or be documented another way later. What the book records is what
happens and what makes it look unintended. A corner keeps the tag only with
evidence of one of these kinds:

- **the documentation**: docs.raku.org says something else. The entry names
  the page by its file in the documentation's repository, Raku/doc, such as
  `doc/Type/Str.rakudoc`, and says what the page states;
- **Roast**: a test in the language's test suite asserts something else. The
  entry names the test file in the Raku/roast repository;
- **a hang**: a call does not return, on input it accepts;
- **an internal leak**: an object or a message from inside the compiler or
  the virtual machine reaches the program, such as `NQPMu`, `VMNull`, "cannot
  unbox", or an error about a call the program never made;
- **a crash on valid input**: a call dies on arguments it accepts, for
  example because its result fails the method's own declared return type;
- **a related form**: Rakudo itself does something else for a closely related
  call, such as the same method on another type, the same operator with a
  slightly different operand, or the one-argument form of a call.

Every behaviour below was reproduced on Rakudo v2026.08 when this book was
built: the examples are run like all the others, and the outputs are the ones
it printed. A later Rakudo may behave differently, and the build that
checks the book against it will show which entries have changed.

Each entry's heading says what happens. The entry opens with the chapter it
comes from, then says in a sentence or two what Rakudo does, and a line
beginning **Evidence:** names the kind of evidence and, for the documentation
or Roast, the file and what it says. The example is the smallest program that
shows the behaviour, often shorter than the chapter's. A program that never
returns is shown without output and marked *not run*; one that needs threads,
timers or processes is marked *run it locally*. The link at the end leads to
the full corner, which explains the behaviour in its context and shows more
of it. Where two corners describe one behaviour, the entry links both, so the
72 tagged corners make 69 entries. The [index of all corners](#index) can
also filter the book by this tag.

## Braces inside `qx{…}` run a command of their own
tags: bug

From [Quotes and Interpolation](#ch:quotes). With brace delimiters, Rakudo
2026.08 runs the text between a pair of inner braces in a `qx` as a shell
command of its own, before the outer command, and puts that command's
output, trailing newline included, in place of the braces. With any other
delimiters the braces stay as text.

**Evidence:** the documentation and a related form.
`doc/Language/quoting.rakudoc` says that delimiters can be nested and that
`qx` does not interpolate; in the other quoting forms, `qq{…}` included,
nested braces are text.

```raku local
say qx[echo '{echo inner}'].raku;
say qx{echo '{echo inner}'}.raku;
```
```output
"\{echo inner}\n"
"\{inner\n}\n"
```

[The full corner](#ch:quotes:braces-inside-qx-run-a-command-of-their-own).

## `7 mod 2.5` is -0.5, and an Int's `polymod` follows it
tags: bug

From [Numbers](#ch:numbers). Rakudo 2026.08 accepts a Rat divisor for `mod`
and `div`. It truncates the divisor to an Int for the quotient and uses the
full value for the remainder, so `7 mod 2.5` is `7 - 3 * 2.5`: -0.5, a Rat
with the opposite sign to the divisor. An Int's `polymod` uses `mod` and
`div` and gives negative remainders as well, while the same number written as
a Rat, `10.0`, uses `%`.

**Evidence:** the documentation and a related form.
`doc/Language/operators.rakudoc` declares
`infix:<mod>(Int:D $a, Int:D $b --> Int:D)`, with an Int result; `%` gives
2 for the same operands, and `polymod` answers differently for `10` and
`10.0`.

```raku
say 7 mod 2.5;
say 7 % 2.5;
say 10.polymod(2.5);
say 10.0.polymod(2.5);
```
```output
-0.5
2
(-2.5 5)
(0 4)
```

The full corners: [`mod`](#ch:numbers:7-mod-25-is-05) and
[`polymod`](#ch:numbers:an-ints-polymod-by-a-fraction-gives-negative-remainders).

## `Inf ** -1` is an underflow, not zero
tags: bug

From [Numbers](#ch:numbers). Rakudo 2026.08 returns a Failure of
`X::Numeric::Underflow` for any negative power of Inf: the power operator
counts the zero result as an underflow from a non-zero base.

**Evidence:** a related form. IEEE 754 makes infinity to a negative power
zero, and Rakudo agrees that `1 / Inf` is `0e0`; the same power operator
gives a plain 0 for the mirror case, a fraction raised to Inf.

```raku
say (1 / Inf).raku;
say (Inf ** -1).exception.^name;
say 0.9 ** Inf;
```
```output
0e0
X::Numeric::Underflow
0
```

[The full corner](#ch:numbers:inf-1-is-an-underflow-not-zero).

## A negative base to a negative power puts the sign on the denominator
tags: bug

From [Numbers](#ch:numbers). `(-2) ** -3` in Rakudo 2026.08 is a Rat whose
denominator carries the sign, `<1/-8>`. It is not equal to -0.125, it prints
as -1.875, and any arithmetic on it normalises it to `<-1/8>`.

**Evidence:** the documentation. `doc/Type/Rational.rakudoc` (method `norm`)
says that since 6.d a Rational is normalised when it is created, with a
positive denominator.

```raku
my $x = (-2) ** -3;
say $x.raku;
say $x == -0.125;
say $x;
```
```output
<1/-8>
False
-1.875
```

[The full corner](#ch:numbers:a-negative-base-to-a-negative-power-puts-the-sign-on-the-denominator).

## `[lcm] ()` dies of an ambiguous call
tags: bug

From [Numbers](#ch:numbers). `lcm` has two candidates that accept no
arguments, and Rakudo 2026.08 cannot choose between them, so reducing an
empty list with `lcm` dies. `[gcd] ()` returns a Failure of
`X::NoZeroArgMeaning`, like the other numeric operators without an identity.

**Evidence:** the documentation and an internal leak.
`doc/Language/operators.rakudoc` (section Identity) says that infix operators
can in general be applied to no element without an error; the message points
into two files of Rakudo's own setting.

```raku
say ([gcd] ()).exception.^name;
say [lcm] ();
```
```output
X::NoZeroArgMeaning
```
```stderr
Ambiguous call to 'infix:<lcm>(...)'; these signatures all match:
  () from SETTING::src/core.c/Numeric.rakumod line 265
  () from SETTING::src/core.c/Int.rakumod line 421
  in block <unit> at example.raku line 2

```

[The full corner](#ch:numbers:lcm-dies-of-an-ambiguous-call).

## A left shift by a negative count past -63 wraps around
tags: bug

From [Numbers](#ch:numbers). A negative count reverses the direction of a
shift. For an Int that fits in 64 bits, Rakudo 2026.08 takes a negative count
for `+<` modulo 64: `+< -64` shifts nothing and `+< -65` shifts right by one
place, where a right shift by 64 or 65 places gives 0.

**Evidence:** Roast. `S03-operators/numeric-shift.t` asserts that
`$a +< -$b` equals `$a +> $b`.

```raku
say 1024 +< -64;
say 1024 +> 64;
say 1024 +< -65;
say 1024 +> 65;
```
```output
1024
0
512
0
```

[The full corner](#ch:numbers:a-left-shift-by-a-negative-count-past-63-wraps-around).

## `1e-300.narrow` is 0
tags: bug

From [Numbers](#ch:numbers). For a Num, Rakudo 2026.08 decides whether it is
whole with the approximate comparison `=~=`, which compares absolutely when
one side is zero. Every Num below 1e-15 is then taken for 0, and a Num close
to a large integer for that integer.

**Evidence:** the documentation. `doc/Type/Numeric.rakudoc` says that
`narrow` converts a number to the narrowest type that can hold it "without
loss of precision"; 0 keeps nothing of 1e-300.

```raku
say 4.5e0.narrow.raku;
say 1e-14.narrow.raku;
say 1e-300.narrow.raku;
```
```output
4.5e0
1e-14
0
```

[The full corner](#ch:numbers:narrow-makes-an-int-of-any-num-close-to-one-however-small).

## `<42>.lines` returns an allomorph whose number is 0
tags: bug

From [Strings](#ch:strings). On an allomorph, `lines` in Rakudo 2026.08
returns allomorphs of the same type, holding the text of each line and the
number 0, so the line is `eq "42"` and `== 0` at once. The same text as a
Str gives Strs.

**Evidence:** related forms. `doc/Type/Allomorph.rakudoc` describes `chomp`,
`comb`, `lc` and the allomorph's other string methods as calling the Str
method on its Str value, and they return plain Strs; the number that `lines`
gives disagrees with its text.

```raku
say <42>.lines.raku;
say <42>.lines[0] == 0;
say <42>.lc.raku;
```
```output
(IntStr.new(0, "42"),).Seq
True
"42"
```

[The full corner](#ch:strings:lines-returns-an-allomorph-whose-number-is-0).

## `rindex` dies on a position at the end
tags: bug

From [Strings](#ch:strings). Given the position at the end of the string,
`rindex` in Rakudo 2026.08 throws an untyped exception whose message calls
the offset out of a range that contains it. An empty needle is spared, and
for the other search methods a position past the end is no error.

**Evidence:** the documentation. `doc/Type/Str.rakudoc` says that `rindex`
returns the last position of the needle "not after `$pos`", which here is
the last occurrence.

```raku
say "abc".rindex("c", 2);
say "abc".rindex("c", 3);
```
```output
2
```
```stderr
index start offset (3) out of range (0..3)
  in block <unit> at example.raku line 2

```

[The full corner](#ch:strings:rindex-dies-on-a-position-at-the-end).

## `rindex` with a needle list and a position never returns
tags: bug

From [Strings](#ch:strings). `rindex` searches a list of needles when it is
given no position. Given a position as well, the call in Rakudo 2026.08 does
not return, and runs until it is killed.

**Evidence:** a hang.

```raku nocheck
say "abc".rindex(<a b>, 1);
```

[The full corner](#ch:strings:rindex-with-a-needle-list-and-a-position-never-returns).

## `comb` with a string and a limit finds overlapping matches
tags: bug

From [Strings](#ch:strings). Given a limit, `comb` with a string needle in
Rakudo 2026.08 moves on by one character after each match instead of by the
length of the needle, so the matches overlap; a negative limit gives all the
overlapping ones. Without a limit, or with `*`, the matches stay apart.

**Evidence:** the documentation. `doc/Type/Str.rakudoc` says that `comb`
returns "non-overlapping matches limited to at most `$limit` matches".

```raku
say "aaaa".comb("aa");
say "aaaa".comb("aa", 3);
```
```output
(aa aa)
(aa aa aa)
```

[The full corner](#ch:strings:comb-with-a-string-and-a-limit-finds-overlapping-matches).

## `lines(:!count)` dies
tags: bug

From [Strings](#ch:strings). `:count`, which the documentation calls
deprecated, makes `lines` return the number of lines. `:!count` asks for the
ordinary call, and Rakudo 2026.08 computes the lines, then dies: the method's
declared return type is an integer, and the Seq of lines fails that check.

**Evidence:** a crash on valid input: the method fails its own declared
return type.

```raku
say "a\nb".lines(:!count);
```
```output
```
```stderr
Type check failed for return value; expected Int:D but got Seq (("a", "b").Seq)
  in block <unit> at example.raku line 1

```

[The full corner](#ch:strings:linescount-dies).

## `split` with a string needle dies on a fractional limit
tags: bug

From [Strings](#ch:strings). With a string needle, a limit that is not an
Int, even `2.0`, makes `split` die in Rakudo 2026.08. With a regex needle
the same limit is taken as an integer.

**Evidence:** an internal leak. The message comes from the virtual machine,
which cannot unbox the limit to a native integer, and names the internal
representation `P6opaque`.

```raku
say "a1b2c".split(/\d/, 2.0).raku;
say "a;b;c".split(";", 2.0).raku;
```
```output
("a", "b2c").Seq
```
```stderr
This type cannot unbox to a native integer: P6opaque, Rat
  in block <unit> at example.raku line 2

```

[The full corner](#ch:strings:split-with-a-string-needle-dies-on-a-fractional-limit).

## `split(:v)` gives a string for a regex in a list of needles
tags: bug

From [Strings](#ch:strings). A regex needle on its own makes `split(:v)`
return each delimiter as a Match object. In a list of needles, Rakudo 2026.08
returns a Str for every delimiter, regex or not.

**Evidence:** the documentation. `doc/Type/Str.rakudoc` (routine `split`)
says that with `:v` a regex delimiter comes back as its Match object, and
that each element of a list is a delimiter according to its type.

```raku
say "1bb2".split(/b+/, :v).map(*.^name);
say "1bb2".split([/b+/], :v).map(*.^name);
```
```output
(Str Match Str)
(Str Str Str)
```

[The full corner](#ch:strings:v-gives-a-string-for-a-regex-in-a-list-of-needles).

## A zero-width regex in a list of needles never returns
tags: bug

From [Strings](#ch:strings). A single regex that matches the empty string
makes `split` cut between the characters. Alone in a list of needles, the
same regex in Rakudo 2026.08 matches at one place again and again, and the
call does not return.

**Evidence:** a hang.

```raku nocheck
say "abc".split([/<?>/]);
```

[The full corner](#ch:strings:a-zero-width-regex-in-a-list-of-needles-never-returns).

## An empty needle with `:g` misses both ends
tags: bug

From [Strings](#ch:strings). An empty string needle matches at position 0,
so `subst` without `:g` puts the replacement at the start. With `:g`, Rakudo
2026.08 matches an empty needle only between characters, never at the start
or the end; the regex `/<?>/`, which also matches the empty string, finds
the ends too.

**Evidence:** the documentation and a related form. `doc/Type/Str.rakudoc`
(method `subst`) says that `:g` "tries to match as often as possible", and
the same needle without `:g` matches at the start.

```raku
say "abc".subst("", "-");
say "abc".subst("", "-", :g);
say "abc".subst(/<?>/, "-", :g);
```
```output
-abc
a-b-c
-a-b-c-
```

[The full corner](#ch:strings:an-empty-needle-with-g-misses-both-ends).

## `subst` with `:as(Str)` dies under `:g`, `:nth` or `:x`
tags: bug

From [Strings](#ch:strings). `subst` accepts `:as(Str)` and ignores it for a
single replacement. With any adverb that makes several matches, Rakudo
2026.08 dies, with a message about a method `from` that the program never
calls: `subst` asks each match for its position, and a string has none.

**Evidence:** a crash on valid input, and a related form: the single
replacement accepts the same adverb.

```raku
say "abcb".subst("b", "x", :as(Str));
say "abcb".subst("b", "x", :as(Str), :g);
```
```output
axcb
```
```stderr
No such method 'from' for string 'b'. Did you mean 'trim'?
  in block <unit> at example.raku line 2

```

[The full corner](#ch:strings:subst-with-asstr-dies-under-g-nth-or-x).

## `subst-mutate` accepts `:ov` and `:ex`, which `subst` refuses
tags: bug

From [Strings](#ch:strings). `subst` refuses `:ov` and `:ex` with
`X::Str::Subst::Adverb`. Its in-place form, `subst-mutate`, lets them
through in Rakudo 2026.08: `:ov` replaces overlapping matches one after
another in the same text, and `:ex` dies with a message about a substring
length of -3, which the program never gave.

**Evidence:** a related form: `subst` refuses the same adverbs.

```raku
my $s = "aaa";
$s.subst-mutate(/aa/, "x", :ov);
say $s;
try "aaa".subst(/aa/, "x", :ov);
say $!.^name;
```
```output
xax
X::Str::Subst::Adverb
```

[The full corner](#ch:strings:subst-mutate-accepts-ov-and-ex-which-subst-refuses).

## `.match` with a negative `:c` matches before the start
tags: bug

From [Strings](#ch:strings). Given `:c(-1)`, Rakudo 2026.08 starts the match
at -1, outside the string, and takes its text from the other end. A bare
`:c`, with no position, always starts at 1.

**Evidence:** the documentation and related forms. `doc/Type/Str.rakudoc`
(method `match`) says that a bare `:c` starts at `$/.to` when `$/` is set,
and at 0 otherwise; `index` and `substr` refuse a negative position as out
of range.

```raku
say "abc".match(/./, :c(-1)).raku;
"abcabc".match(/c/);
say "abcabc".match(/./, :c).from;
```
```output
Match.new(:orig("abc"), :from(-1), :pos(0))
1
```

The first match ends at 3, where the documentation starts a bare `:c`.

[The full corner](#ch:strings:match-with-a-negative-c-matches-before-the-start).

## `encode` with an undefined or numeric encoding never returns
tags: bug

From [Strings](#ch:strings) and [Blobs and Bufs](#ch:buffers). An unknown
encoding name is refused with `X::Encoding::Unknown`. An undefined encoding,
the Str type object or a variable that was never set, is not refused, nor is
a number: in Rakudo 2026.08 `encode` does not return. Each of these calls
runs until it is killed.

**Evidence:** a hang.

```raku nocheck
my $encoding;
say "abc".encode($encoding);
say "a".encode(42).raku;
```

The full corners: [an undefined
encoding](#ch:strings:encode-with-an-undefined-encoding-never-returns) and
[a number](#ch:buffers:encode-with-a-number-as-the-encoding-never-returns).

## `splice` without a size removes only what a lazy array has computed
tags: bug

From [Lists, Arrays, Seqs and Slips](#ch:lists). On a lazy array, `splice`
without a size in Rakudo 2026.08 removes only the elements computed so far,
leaves the lazy rest in place, and reports no error. `push` and `pop`, which
also need the end of the array, refuse a lazy array with `X::Cannot::Lazy`.

**Evidence:** the documentation. `doc/Type/Array.rakudoc` (routine `splice`)
says that when the number of elements is omitted, all the elements from the
start index on are deleted.

```raku
my @a = 1..*;
say @a.splice(1).raku;
say @a.head(3).raku;
```
```output
[]
(1, 2, 3).Seq
```

[The full corner](#ch:lists:splice-without-a-size-removes-only-what-a-lazy-array-has-computed).

## `reverse` of a fractional range counts down from its end
tags: bug

From [Ranges](#ch:ranges). For a range that is not of Ints or of single
characters, `reverse` in Rakudo 2026.08 starts at the end point, or one below
it when the end is excluded, and counts down by one while it stays at or
above the start. The result is not the elements reversed, and can hold
values the range never yields.

**Evidence:** the documentation. `doc/Type/Range.rakudoc` (method `reverse`)
describes the result as all the elements that the Range represents,
reversed.

```raku
say (1.1..4).list.raku;
say (1.1..4).reverse.raku;
```
```output
(1.1, 2.1, 3.1)
(4, 3, 2).Seq
```

[The full corner](#ch:ranges:reverse-of-a-fractional-range-counts-down-from-its-end).

## `first(:end, :kv)` on a Range counts its index from the end
tags: bug

From [Ranges](#ch:ranges). With `:end`, a Range answers `:k` with the
position counted from the front, but with `:kv` Rakudo 2026.08 pairs the
value with the position counted from the end. The same call on an Array
counts from the front.

**Evidence:** the documentation and Roast. `doc/Type/List.rakudoc` (routine
`first`) says that the index is always counted from the beginning of the
list, whether or not `:end` is given, and `S32-list/first-end-kv.t` asserts
that for lists and arrays.

```raku
say (1..10).first(* %% 3, :end, :k);
say (1..10).first(* %% 3, :end, :kv).raku;
say [1..10].first(* %% 3, :end, :kv).raku;
```
```output
8
(1, 9)
(8, 9)
```

[The full corner](#ch:ranges:firstend-kv-counts-its-index-from-the-end).

## A `none` junction as the endpoint makes the sequence endless
tags: bug

From [The Sequence Operator](#ch:sequences). `1 ... none(1, 2)` is a lazy
sequence that never stops in Rakudo 2026.08. Before it looks at the
endpoint, the operator tests whether the endpoint is infinite by comparing it
with `Inf`, and the junction answers that test too: neither 1 nor 2 is
`Inf`. The same condition in a block stops at 3.

**Evidence:** the documentation and a related form.
`doc/Language/operators.rakudoc` (infix `...`) says that an endpoint other
than `*` is smartmatched against each generated element, and names junctions
among the possible endpoints.

```raku
say (1 ... none(1, 2)).head(5).raku;
say (1 ... { $_ ~~ none(1, 2) }).raku;
```
```output
(1, 2, 3, 4, 5).Seq
(1, 2, 3).Seq
```

[The full corner](#ch:sequences:a-none-junction-as-the-endpoint-makes-the-sequence-endless).

## A geometric sequence of negative numbers misses its endpoint
tags: bug

From [The Sequence Operator](#ch:sequences). With negative seeds and a ratio
above 1 the values fall, but Rakudo 2026.08 stops before the first value
*above* the endpoint, and the first seed already is: `-1, -2, -4 ... -16` is
empty, although -16 is on its path. An endpoint above every value is never
passed, and that sequence never ends.

**Evidence:** related forms. The arithmetic sequence `-1, -3 ... -9` stops
at its endpoint, and so does the geometric sequence with the signs flipped,
like the documentation's own example `1, 2, 4 ... 32`.

```raku
say (1, 2, 4 ... 16).raku;
say (-1, -2, -4 ... -16).raku;
say (-1, -3 ... -9).raku;
```
```output
(1, 2, 4, 8, 16).Seq
().Seq
(-1, -3, -5, -7, -9).Seq
```

[The full corner](#ch:sequences:a-geometric-sequence-of-negative-numbers-misses-its-endpoint).

## The endpoint is tested once per call of the generator
tags: bug

From [The Sequence Operator](#ch:sequences). When the generator returns a
Slip, Rakudo 2026.08 tests the endpoint once for the whole call rather than
once for each element. A code endpoint sees only the last values, and any
other endpoint is smartmatched against the Slip itself, which as a number is
its length.

**Evidence:** the documentation. `doc/Language/operators.rakudoc` (infix
`...`) says that the endpoint is smartmatched against each generated
element.

```raku
say (1, { slip 2, 3 } ... 3).head(6).raku;
say (1, { slip 5, 6 } ... 2).raku;
```
```output
(1, 2, 3, 2, 3, 2).Seq
(1, 5, 6).Seq
```

The 3 never ends the first sequence, although every Slip holds a 3; the 2
ends the second after a Slip of two elements that holds no 2.

[The full corner](#ch:sequences:the-endpoint-is-tested-once-per-call-of-the-generator).

## `...^` keeps the end of a string sequence of equal lengths
tags: bug

From [The Sequence Operator](#ch:sequences). For strings of the same length
and more than one character, Rakudo 2026.08 ignores the final caret of
`...^` and includes the endpoint. For single characters it is left out.

**Evidence:** the documentation. `doc/Language/operators.rakudoc` says that
the variants with a final caret produce sequences that do not contain the
final element.

```raku
say ('a' ...^ 'c').raku;
say ('aa' ...^ 'ab').raku;
```
```output
("a", "b").Seq
("aa", "ab").Seq
```

[The full corner](#ch:sequences:keeps-the-end-of-a-string-sequence-of-equal-lengths).

## A chain always ends with its last endpoint
tags: bug

From [The Sequence Operator](#ch:sequences). At the end of a chain of
sequence operators, Rakudo 2026.08 emits the last endpoint whether the
sequence reached it or not, as if it started a further segment:
`1 ... 5 ... 7.5` ends with 7 and then 7.5. In a chain, `^...^` keeps the
last element.

**Evidence:** the documentation and a related form.
`doc/Language/operators.rakudoc` says that a final caret leaves out the
final element, and the unchained `1 ... 7.5` stops at 7.

```raku
say (1 ... 7.5).raku;
say (1 ... 5 ... 7.5).raku;
say (1 ^...^ 5 ^...^ 1).raku;
```
```output
(1, 2, 3, 4, 5, 6, 7).Seq
(1, 2, 3, 4, 5, 6, 7, 7.5).Seq
(2, 3, 4, 5, 4, 3, 2, 1).Seq
```

[The full corner](#ch:sequences:a-chain-always-ends-with-its-last-endpoint).

## `.Bag` of a Mix truncates the Mix itself
tags: bug

From [Sets, Bags and Mixes](#ch:sets). In Rakudo 2026.08, `.Bag` and
`.BagHash` of a Mix or a MixHash also rewrite the source: every weight of 1
or more becomes its `.Int`. A total computed before is remembered, so
afterwards the Mix no longer adds up.

**Evidence:** the documentation. `doc/Type/Mix.rakudoc` calls a Mix an
immutable collection and describes `.Bag` as a coercion to a Bag.

```raku
my $m = ("a" => 2.7, "b" => 0.5).Mix;
say $m.Bag;
say $m;
```
```output
Bag(a(2))
Mix(a(2) b(0.5))
```

[The full corner](#ch:sets:bag-of-a-mix-truncates-the-mix-itself).

## `my %h is Set;` without a value is unusable
tags: bug

From [Sets, Bags and Mixes](#ch:sets). Declared without an initializer, the
variable in Rakudo 2026.08 holds an object that claims to be a Set but
throws from `.elems`, `.gist` and `.raku`; being immutable, it cannot be
assigned afterwards either. `is Bag` behaves the same. An initializer, even
an empty list, gives a working Set.

**Evidence:** the documentation and an internal leak.
`doc/Language/syntax.rakudoc` lists `my %set is Set;`, with no value, as the
declaration of a Set variable; the error is about a Scalar, the container
underneath.

```raku
my %h is Set;
try { %h.elems };
say $!.message;
my %e is Set = ();
say %e.elems;
```
```output
This type (Scalar) does not support elems
0
```

[The full corner](#ch:sets:my-h-is-set-without-a-value-is-unusable).

## `∩` of two Hashes ignores false values
tags: bug

From [Sets, Bags and Mixes](#ch:sets). When both operands of `∩` are plain
Hashes, Rakudo 2026.08 compares only their keys, so a key whose value is
false is an element of the result. Every other set operator, and `∩` with any
other operand, leaves such a key out.

**Evidence:** the documentation. `doc/Type/Set.rakudoc` says that set
operators act as if they called `.Set` on their operands, and that `.Set` of
a Hash skips the keys whose values are false.

```raku
say { a => 1, b => 0 } ∩ { a => 1, b => 1 };
say { a => 1, b => 0 }.Set ∩ { a => 1, b => 1 };
```
```output
Set(a b)
Set(a)
```

[The full corner](#ch:sets:of-two-hashes-ignores-false-values).

## A Junction operand makes four set operators hang
tags: bug

From [Sets, Bags and Mixes](#ch:sets). The set operators that build a
collection do not autothread over a Junction. In Rakudo 2026.08 `∪`, `∩`,
`⊎` and `⊍` with a Junction on either side never return, and `∖` and `⊖`
die with a message that names the virtual machine's representation of the
object.

**Evidence:** a hang, and an internal leak in the message of the other two
operators.

```raku
try { set(1) (-) any(2, 3) };
say $!.message;
```
```output
Cannot iterate object with P6opaque representation (Junction)
```

Each of these lines runs until it is killed:

```raku nocheck
say set(1) (|) any(2, 3);
say any(2, 3) (&) set(1);
say set(1) (+) any(2, 3);
say set(1) (.) any(2, 3);
```

[The full corner](#ch:sets:a-junction-operand-makes-four-operators-hang).

## `.bytes` of a `Blob[int]` counts one byte per element
tags: bug

From [Blobs and Bufs](#ch:buffers). `Blob[int]` and `Blob[uint]` store 64
bits per element, as the hex dump shows, but Rakudo 2026.08 counts one byte
for each; a `buf64` of the same two values counts 16.

**Evidence:** the documentation. `doc/Type/Blob.rakudoc` says that `.bytes`
returns the number of bytes used by the elements, and shows 24 for three
elements of a `blob64`.

```raku
say buf64.new(1, 2).bytes;
say Blob[int].new(1, 2).bytes;
say Blob[int].new(1, 2);
```
```output
16
2
Blob[int]:0x<0000000000000001 0000000000000002>
```

[The full corner](#ch:buffers:bytes-of-a-blobint-counts-one-byte-per-element).

## `allocate` with an empty pattern never returns
tags: bug

From [Blobs and Bufs](#ch:buffers). The pattern given to `allocate` is
repeated until the buffer is full. Given an empty list, Rakudo 2026.08 never
returns, and runs until it is killed.

**Evidence:** a hang.

```raku nocheck
say Blob.allocate(3, ()).raku;
```

[The full corner](#ch:buffers:allocate-with-an-empty-pattern-never-returns).

## A bad value among several grows the Buf, then throws
tags: bug

From [Blobs and Bufs](#ch:buffers). Given several values, `push` and
`append` in Rakudo 2026.08 throw at a bad one only after the buffer has
grown by one slot for each value before it and one for the bad value itself,
which holds 0. A single bad value returns a Failure and leaves the buffer as
it was.

**Evidence:** related forms: the one-argument call, and `splice` with a bad
element in its list, leave the buffer unchanged.

```raku
my $b = Buf.new(7, 7);
try { $b.push(1, "x") };
say $b.raku;
my $f = $b.push("x");
say $f.^name;
say $b.raku;
```
```output
Buf.new(7,7,1,0)
Failure
Buf.new(7,7,1,0)
```

[The full corner](#ch:buffers:a-bad-value-among-several-grows-the-buf-then-throws).

## A failed `splice` still changes the Buf
tags: bug

From [Blobs and Bufs](#ch:buffers). An offset past the end with a nonzero
size, a negative offset and a negative size make `splice` return a Failure
of `X::OutOfRange`, and in Rakudo 2026.08 they change the buffer as well. An
infinite list as the replacement is not refused as lazy, and the call never
returns.

**Evidence:** a related form and a hang. A bad replacement value makes
`splice` return a Failure and leaves the buffer alone.

```raku
my $b = Buf.new(1, 2, 3);
my $f = $b.splice(5, 1);
say $f.exception.^name;
say $b.raku;
```
```output
X::OutOfRange
Buf.new(1,2,3,0,0)
```

The call with the infinite list runs until it is killed:

```raku nocheck
my $b = Buf.new(1, 2, 3);
say $b.splice(0, 2, 1..*).raku;
```

[The full corner](#ch:buffers:a-failed-splice-still-changes-the-buf).

## `subbuf` with a string start and a length never returns
tags: bug

From [Blobs and Bufs](#ch:buffers). A string start alone, a string length and
a fractional start have no candidate and throw `X::Multi::NoMatch` at once.
A string start followed by an integer length is not refused, and in Rakudo
2026.08 the call never returns.

**Evidence:** a hang.

```raku nocheck
say Blob.new(1, 2).subbuf("1", 1).raku;
```

[The full corner](#ch:buffers:subbuf-with-a-string-start-and-a-length-never-returns).

## `~&` and `~|` die on signed buffers of unequal length
tags: bug

From [Blobs and Bufs](#ch:buffers). Between two signed buffers of different
lengths, and for `~&` with a signed left operand and an unsigned right one
of another length, Rakudo 2026.08 dies. Unsigned buffers of unequal length
are padded, and `~^` works with any.

**Evidence:** an internal leak. The message comes from the virtual machine
and names its array type, `MVMArray`.

```raku
try { Blob[int8].new(-1, -1) ~& Blob[int8].new(1) };
say $!.message;
say (blob8.new(1, 1) ~& blob8.new(1)).raku;
```
```output
MVMArray: bindpos I8 expected int register
Blob[uint8].new(1,0)
```

[The full corner](#ch:buffers:and-die-on-signed-buffers-of-unequal-length).

## `write-ubits` clears the bits after the run in its last byte
tags: bug

From [Blobs and Bufs](#ch:buffers). When the run ends inside a byte, Rakudo
2026.08 also changes the bits of that byte to the right of the run: only the
first of them survives, and the rest become zeros. A run that ends on a byte
boundary leaves every other bit alone.

**Evidence:** the documentation. `doc/Type/Buf.rakudoc` describes
`write-ubits` as writing a value to the given number of bits from the given
bit offset.

```raku
say buf8.new(0xFF).write-ubits(0, 4, 0).raku;
say buf8.new(0xFF).write-ubits(4, 4, 0).raku;
```
```output
Buf[uint8].new(8)
Buf[uint8].new(240)
```

With the four low bits kept, the first result would be 15.

[The full corner](#ch:buffers:write-ubits-clears-the-bits-after-the-run-in-its-last-byte).

## `.multi` is 0 on a proto, and a plain sub's `.dispatcher` is an `NQPMu`
tags: bug

From [Signatures and Introspection](#ch:signatures). A candidate answers
`.multi` with `True`, but in Rakudo 2026.08 a proto and a plain sub answer
the number 0. `.dispatcher` of a plain sub is the compiler's internal
`NQPMu`, which is not a Raku object and has no `.raku`.

**Evidence:** the documentation and an internal leak.
`doc/Type/Routine.rakudoc` declares `.multi` to return a `Bool:D` and shows
a proto answering `False`.

```raku
multi f(Int $x) { }
sub g($x) { }
say &f.multi.raku;
say &g.dispatcher.^name;
```
```output
0
NQPMu
```

[The full corner](#ch:signatures:multi-is-0-on-a-proto-and-a-plain-subs-dispatcher-is-an-nqpmu).

## `.prec("prec")` fails its own return type
tags: bug

From [Signatures and Introspection](#ch:signatures). Given a key, an
operator's `.prec` computes that one property, a string, and in Rakudo
2026.08 dies with `X::TypeCheck::Return`, because the method is declared to
return `Hash:D`. Subscripting the Hash that `.prec` returns without a key
works.

**Evidence:** a crash on valid input: the method fails its own declared
return type.

```raku
say &infix:<+>.prec<prec>;
try &infix:<+>.prec("prec");
say $!.message;
```
```output
t=
Type check failed for return value; expected Hash:D but got Str
```

[The full corner](#ch:signatures:an-operator-reports-its-precedence-and-precprec-dies).

## A method's signature prints `$::`, which does not parse back
tags: bug

From [Signatures and Introspection](#ch:signatures). The invocant marker is
one colon, as in `method m($self: $x)`. In Rakudo 2026.08 a method's
signature prints it as two, `$::`, and the printed signature does not
compile.

**Evidence:** the documentation. The printed signatures in
`doc/Type/Routine.rakudoc` have one colon, as in
`(Cool $: Str $matcher, $limit = Inf, *%_)`; `EVAL` of the printed text
throws.

```raku
use MONKEY-SEE-NO-EVAL;
class C { method m($x) { } }
my $printed = C.^lookup('m').signature.raku;
say $printed;
try EVAL $printed;
say $!.^name;
```
```output
:(C $:: $x, *%_)
X::Syntax::Signature::InvocantMarker
```

[The full corner](#ch:signatures:a-methods-signature-prints-which-does-not-parse-back).

## `Int:D()` prints as `Int:D(Any):D`, which does not compile
tags: bug

From [Signatures and Introspection](#ch:signatures). A definite coercion type
in a signature prints, in Rakudo 2026.08, with a second `:D` after the
coercion, and the printed text does not compile.

**Evidence:** the documentation. `doc/Type/Mu.rakudoc` says that `.raku`
conventionally returns a representation of the object that `EVAL` can use to
reconstruct it.

```raku
use MONKEY-SEE-NO-EVAL;
my $printed = :(Int:D() $x).raku;
say $printed;
try EVAL $printed;
say $!.^name;
```
```output
:(Int:D(Any):D $x)
X::MultipleTypeSmiley
```

[The full corner](#ch:signatures:intd-prints-as-intdanyd-which-does-not-compile).

## A signature built with `Signature.new` cannot bind anything
tags: bug

From [Signatures and Introspection](#ch:signatures). Smartmatching a Capture
against a signature built at run time with `Signature.new` throws in Rakudo
2026.08, even for an empty signature and an empty Capture.

**Evidence:** the documentation and an internal leak.
`doc/Type/Signature.rakudoc` (method `ACCEPTS`) says that smartmatching a
Capture against a signature answers whether the Capture can be bound to it;
the message comes from the virtual machine and names `p6invokeunder` and an
`MVMCode`.

```raku
try { \() ~~ Signature.new };
say $!.message;
```
```output
p6invokeunder first argument has to be a concrete MVMCode, got a concrete P6opaque (type ContainerDescriptor)
```

[The full corner](#ch:signatures:a-signature-built-with-signaturenew-cannot-bind-anything).

## `Parameter.new` dies on `+@a` and doubles a bare name
tags: bug

From [Signatures and Introspection](#ch:signatures). In Rakudo 2026.08
`Parameter.new` accepts a name without a sigil and prints it twice, and dies
on the single-argument slurpy `+@a` with an out-of-range `substr` from
inside the constructor.

**Evidence:** the documentation and an internal leak.
`doc/Type/Parameter.rakudoc` says that the name is written as in a
Signature, and lists the `+`, `*` and `**` prefixes among the marks it may
carry.

```raku
say Parameter.new(name => 'x').raku;
try Parameter.new(name => '+@a');
say $!.message;
```
```output
xx
Start argument to substr out of range. Is: -1, should be in 0..2; use *-1 if you want to index relative to the end
```

[The full corner](#ch:signatures:parameternew-dies-on-a-and-doubles-a-bare-name).

## A WhateverCode's `.file` is a null string
tags: bug

From [Signatures and Introspection](#ch:signatures). A sub answers `.file`
with the name of its source file. A WhateverCode in Rakudo 2026.08 answers
with a Str object that holds no string at all: it is defined, but using it as
a string dies.

**Evidence:** an internal leak: an error from the virtual machine about a
null string.

```raku
my $w = * + 1;
my $f = $w.file;
say $f.defined;
try say ~$f;
say $!.message;
```
```output
True
concatenate requires a concrete string, but got null
```

[The full corner](#ch:signatures:a-whatevercodes-file-is-a-null-string).

## A ForeignCode's gist is not its name
tags: bug

From [Signatures and Introspection](#ch:signatures). `ForeignCode` is code
that belongs to the virtual machine rather than to Raku, such as some of the
methods every routine has. In Rakudo 2026.08 its `.gist` is
`ForeignCode.new`, and its `.Str` the default form with an address.

**Evidence:** the documentation. `doc/Type/ForeignCode.rakudoc` says that
`.gist` and `.Str` return the name of the code, by calling `.name`.

```raku
sub f() { }
my $fc = &f.^methods.first(* ~~ ForeignCode);
say $fc.name;
say $fc.gist;
```
```output
<anon>
ForeignCode.new
```

[The full corner](#ch:signatures:a-foreigncodes-gist-is-not-its-name).

## Rethrowing a caught `return`, `take` or `emit` loses its value
tags: bug

From [Exceptions and Failures](#ch:exceptions). When a CONTROL block
rethrows a `CX::Return`, `CX::Take` or `CX::Emit`, the construct in Rakudo
2026.08 receives the control exception itself instead of the value: the
routine returns the `CX::Return` object, `gather` collects `CX::Take`
objects, and a supply emits the `CX::Emit`.

**Evidence:** the documentation and a related form.
`doc/Type/Exception.rakudoc` describes `.rethrow` as throwing the exception
again, and a rethrown `CX::Next` does go on to the next iteration.

```raku
sub five {
    CONTROL { when CX::Return { .rethrow } }
    return 5;
}
say five().raku;
```
```output
CX::Return.new
```

[The full corner](#ch:exceptions:rethrowing-a-caught-return-take-or-emit-loses-its-value).

## A bare `succeed` yields an internal null that cannot be printed
tags: bug

From [Exceptions and Failures](#ch:exceptions). With an argument, `succeed`
makes it the value of the `when` or `given` block, and an empty `when`
yields Nil. A bare `succeed` in Rakudo 2026.08 yields `VMNull`, the virtual
machine's internal null, which is not a Raku object and has no methods, not
even the `.gist` that `say` calls.

**Evidence:** an internal leak.

```raku
my $v = do given 5 { when Int { succeed } };
say $v;
```
```output
```
```stderr
No such method 'gist' for invocant of type 'VMNull'. Found 'gist' on
type 'Mu'
  in block <unit> at example.raku line 2

```

[The full corner](#ch:exceptions:a-bare-succeed-yields-an-internal-null-that-cannot-be-printed).

## In a loop, LEAVE runs before NEXT
tags: bug

From [Exceptions and Failures](#ch:exceptions). When a loop body is about to
go round again, Rakudo 2026.08 runs its `LEAVE` phaser first and `NEXT`
after it.

**Evidence:** the documentation and Roast. `doc/Language/phasers.rakudoc`
says that `NEXT` runs before `LEAVE`, and `S04-phasers/next.t` asserts that
order, with a `#?rakudo todo` on the test.

```raku
for 1..2 {
    NEXT  say "NEXT $_";
    LEAVE say "LEAVE $_";
}
```
```output
LEAVE 1
NEXT 1
LEAVE 2
NEXT 2
```

[The full corner](#ch:exceptions:in-a-loop-leave-runs-before-next).

## `.match` with `:x(Nil)` dies of an arity error
tags: bug

From [Regexes and Grammars](#ch:regexes). A count that is neither a number
nor a Range, a numeric string included, makes `.match` return a Failure of
`X::Str::Match::x`. Nil is neither, but in Rakudo 2026.08 `:x(Nil)` dies,
with an arity error about a call made inside `.match`.

**Evidence:** the documentation and an internal leak.
`doc/Type/Str.rakudoc` (method `match`) says that a value of `:x` other than
a Numeric or a Range makes `.match` return a Failure containing
`X::Str::Match::x`.

```raku
say "aaaa".match(/a/, :x("2")).exception.^name;
try "aaaa".match(/a/, :x(Nil));
say $!.message;
```
```output
X::Str::Match::x
Too many positionals passed; expected 3 arguments but got 4
```

[The full corner](#ch:regexes:an-invalid-x-is-a-failure-and-xnil-dies).

## `:nth(2), :x(1)` answers an empty list
tags: bug

From [Regexes and Grammars](#ch:regexes). With a single `:nth` number and
`:x(1)`, `.match` in Rakudo 2026.08 returns an empty List, although the
match exists. A list of one number, `:nth((2,))`, returns that match.

**Evidence:** the documentation and a related form. `doc/Type/Str.rakudoc`
(method `match`) describes `:x` as the number of matches to return.

```raku
say "abcd".match(/./, :nth((2,)), :x(1))».Str;
say "abcd".match(/./, :nth(2), :x(1)).raku;
```
```output
(b)
()
```

[The full corner](#ch:regexes:nth2-x1-answers-an-empty-list).

## `.actions` of a parse without actions is not a Raku object
tags: bug

From [Regexes and Grammars](#ch:regexes). Without an actions object,
`.actions` of a parse result in Rakudo 2026.08 is an object of the
compiler's own `NQPMu` type, which has no `.gist`, so printing it dies.

**Evidence:** the documentation and an internal leak.
`doc/Type/Match.rakudoc` says that `.actions` returns `Mu` when no actions
object was set.

```raku
grammar G { token TOP { a } }
say G.parse("a").actions.^name;
say G.parse("a").actions;
```
```output
NQPMu
```
```stderr
Method NQPMu.gist not found
  in block <unit> at example.raku line 3

```

[The full corner](#ch:regexes:actions-of-a-parse-without-actions-is-not-a-raku-object).

## A Date range compares by text, so a formatter cuts it short
tags: bug

From [Dates and Times](#ch:dates). A range decides where its iteration stops
with `cmp`, and `cmp` compares Dates as text. With a formatter on the start,
Rakudo 2026.08 stops as soon as the formatted text sorts after the end:
below, the days print as their numbers, `"3"` sorts after `"2019-05-09"`,
and a range of nine days has two elements.

**Evidence:** the documentation. `doc/Type/Date.rakudoc` offers
`$date .. $date.last-date-in-month` as the remaining dates of a month; a
formatter changes where such a range stops.

```raku
my $start = Date.new("2019-05-01", :formatter({ ~.day }));
say ($start .. Date.new("2019-05-09")).list;
```
```output
(1 2)
```

[The full corner](#ch:dates:a-date-range-compares-by-text-so-a-formatter-cuts-it-short).

## A date-only string with a bad month dies with an internal error
tags: bug

From [Dates and Times](#ch:dates). `DateTime.new` given a full timestamp
with month 13, or a date-only string with day 32, throws
`X::Temporal::OutOfRange`. Given a date-only string with month 13, Rakudo
2026.08 dies with an `X::AdHoc` about unboxing a type object.

**Evidence:** an internal leak, and related forms: the two neighbouring
forms name the field that is out of range.

```raku
try DateTime.new("2012-13-22T07:02:00Z");
say $!.^name;
try DateTime.new("2012-13-22");
say $!.message;
```
```output
X::Temporal::OutOfRange
Cannot unbox a type object (Nil) to int.
```

[The full corner](#ch:dates:a-date-only-string-with-a-bad-month-dies-with-an-internal-error).

## Rounding the second can print one that does not exist, or die
tags: bug

From [Dates and Times](#ch:dates). A DateTime prints its second with six
decimals, rounded half up. In Rakudo 2026.08 a second just below 60 prints
as `60.000000`, a leap second that `DateTime.new` refuses at that time, and a
second from 0.9999995 up to 1 makes `.Str` die on a value the constructor
accepted.

**Evidence:** related forms and an internal leak. The constructor refuses
the second of 60 that `.Str` prints, while `10.9999996` is carried to
`11.000000`; the message of the other case is about a negative repeat count.

```raku
say DateTime.new(:2000year, :second(59.9999999));
try say DateTime.new(:2000year, :second(0.9999999));
say $!.message;
```
```output
2000-01-01T00:00:60.000000Z
Repeat count (-1) cannot be negative
```

[The full corner](#ch:dates:rounding-the-second-can-print-one-that-does-not-exist-or-die).

## A DateTime's identity is its printed text
tags: bug

From [Dates and Times](#ch:dates). The identity of a DateTime, which `===`,
`unique` and sets use, is made from its `.Str` in Rakudo 2026.08. Two
DateTimes for the same moment in different zones are `==` and `eqv` but not
`===`, and two whose formatter prints the same text are `===` whatever
moments they hold.

**Evidence:** the documentation. `doc/Language/operators.rakudoc` says that
for value types `===` behaves like `eqv`.

```raku
my $utc  = DateTime.new("1971-10-28T10:45:00Z");
my $cest = DateTime.new("1971-10-28T12:45:00+02:00");
say $utc eqv $cest, " ", $utc === $cest;
```
```output
True False
```

[The full corner](#ch:dates:a-datetimes-identity-is-its-printed-text).

## DateTimes compare by moment, except with `cmp`, `leg` and `sort`
tags: bug

From [Dates and Times](#ch:dates). `==`, `<` and `<=>` compare the moments
of two DateTimes. In Rakudo 2026.08 `cmp` and `leg` compare their texts, and
so do `sort`, `min` and `max`, which use `cmp`: moments in different zones
can sort in the reverse of their order in time.

**Evidence:** the documentation. `doc/Type/DateTime.rakudoc` says that `cmp`
on two DateTimes compares the equivalent instants.

```raku
my $early = DateTime.new("2020-01-01T08:00:00+05:00");
my $late  = DateTime.new("2020-01-01T05:00:00-02:00");
say $early < $late;
say $early cmp $late;
```
```output
True
More
```

`$early` is 03:00 UTC and `$late` 07:00 UTC.

[The full corner](#ch:dates:datetimes-compare-by-moment-except-with-cmp-leg-and-sort).

## `read($n)` on a binary pipe returns a whole chunk, whatever `$n` is
tags: bug

From [Processes](#ch:processes). On a pipe opened with `:bin`, `read` in
Rakudo 2026.08 returns everything that has arrived in one piece, whatever
the count; the next `read` finds nothing left. On a text pipe the count is
kept.

**Evidence:** the documentation. `doc/Type/IO/Handle.rakudoc` says that
`read` returns up to the given number of bytes.

```raku local
my $p = run "printf", "abcdef", :out, :bin;
say $p.out.read(2).raku;
```
```output
Buf[uint8].new(97,98,99,100,101,102)
```

[The full corner](#ch:processes:readn-on-a-binary-pipe-returns-a-whole-chunk-whatever-n-is).

## Asking a new `Proc` for its status fixes the status at 1
tags: bug

From [Processes](#ch:processes). On a `Proc.new` that has not spawned
anything, Rakudo 2026.08 answers `.exitcode` with 1, and the answer sticks:
a spawn afterwards runs the program, but the Proc keeps reporting 1. A Proc
that spawns a second time keeps the status of its first program.

**Evidence:** the documentation. `doc/Type/Proc.rakudoc` says that
`.exitcode` is -1 for a process that has not exited yet.

```raku local
my $p = Proc.new;
say $p.exitcode;
$p.spawn("true");
say $p.exitcode;
```
```output
1
1
```

[The full corner](#ch:processes:asking-a-new-proc-for-its-status-fixes-the-status-at-1).

## A dying synchronous `then` makes `keep` throw an unrelated error
tags: bug

From [Promises, Locks and Awaiting](#ch:promises). When the code of a
synchronous `then` dies while its promise is being kept, the `keep` call in
Rakudo 2026.08 throws "Too few positionals". The promise is kept all the
same, but the `then` promise stays Planned, so an `await` on it never
returns, and the synchronous `then` blocks registered after the dying one
never run.

**Evidence:** an internal leak and a hang. The message is an arity error
from a call inside Rakudo, since `keep(1)` passes one argument, and the
`then` promise is never resolved.

```raku local
my $p = Promise.new;
my $dies = $p.then({ die "in a synchronous then" }, :synchronous);
try $p.keep(1);
say $!.message;
say $p.status, " ", $dies.status;
```
```output
Too few positionals passed; expected 1 argument but got 0
Kept Planned
```

[The full corner](#ch:promises:a-dying-synchronous-then-makes-keep-throw-an-unrelated-error).

## `await` on a Channel takes a Nil value for no value
tags: bug

From [Promises, Locks and Awaiting](#ch:promises). A Nil sent into a channel
is a value like any other, and `.receive` returns it. `await` in Rakudo
2026.08 consumes the Nil and goes on waiting: with a later value it returns
that one, and with none it never returns.

**Evidence:** the documentation and a hang. `doc/Type/Channel.rakudoc` says
that `await` calls `.receive` on the Channel.

```raku local
my $c = Channel.new;
$c.send(Nil);
say $c.receive.raku;
$c.send(Nil);
$c.send(1);
say await $c;
```
```output
Nil
1
```

[The full corner](#ch:promises:await-on-a-channel-takes-a-nil-value-for-no-value).

## `sleep-timer NaN` fails its own return type check
tags: bug

From [Promises, Locks and Awaiting](#ch:promises). `sleep NaN` returns at
once. `sleep-timer NaN` in Rakudo 2026.08 throws `X::TypeCheck::Return`:
the value it returns is not a Duration but a Rat of 0/0 with an internal
role mixed in.

**Evidence:** the documentation and a crash on valid input.
`doc/Type/independent-routines.rakudoc` gives `sleep-timer` the signature
`(Real() $seconds = Inf --> Duration:D)` and says it is implemented like
`sleep`; NaN is a Real.

```raku local
try sleep-timer NaN;
say $!.message;
```
```output
Type check failed for return value; expected Duration:D but got Rat+{Duration::add-tai} (<0/0>)
```

[The full corner](#ch:promises:sleep-timer-nan-fails-its-own-return-type-check).

## A Semaphore's permit count wraps at 32 bits
tags: bug

From [Promises, Locks and Awaiting](#ch:promises). Rakudo 2026.08 keeps the
number of permits of a Semaphore in 32 bits. Counts from `2**31` to
`2**32 - 1` are refused; from `2**32` on, the count is accepted silently and
only its low 32 bits are kept, so `2**32 + 1` gives one permit.

**Evidence:** a related form and the documentation. The smaller count
`2**31` is refused outright, and `doc/Type/Semaphore.rakudoc` describes the
count as the number of acquires that pass before one blocks.

```raku
my $s = Semaphore.new(2**32 + 1);
say $s.try_acquire, " ", $s.try_acquire;
try Semaphore.new(2**31);
say $!.message;
```
```output
True False
Failed to initialize Semaphore: invalid argument
```

[The full corner](#ch:promises:a-semaphores-permit-count-wraps-at-32-bits).

## A LAST run by `last` cannot emit
tags: bug

From [Supplies](#ch:supplies). A `LAST` phaser in a `whenever` can `emit`
when its source finishes. When `last` is what runs it, in Rakudo 2026.08 the
phaser no longer runs inside the supply: `emit` dies with "emit without
supply or react", although the code sits in a `supply` block, and the supply
quits. A tap without a quit handler hears nothing at all.

**Evidence:** Roast and a related form. `S17-supply/syntax.t` asserts that a
`LAST` in a `whenever` can emit, and that `last` runs the `LAST` block; the
same phaser emits when the source finishes by itself.

```raku
my $s = supply {
    whenever Supply.from-list(1, 2, 3) {
        emit $_;
        last if $_ == 2;
        LAST { emit "from LAST" }
    }
}
$s.tap(-> $v { say "got $v" }, quit => { say "quit: ", .message });
```
```output
got 1
got 2
quit: emit without supply or react
```

[The full corner](#ch:supplies:a-last-run-by-last-cannot-emit).

## After a quit from `.map`, later values and a done still arrive
tags: bug

From [Supplies](#ch:supplies). `.map` turns an exception in its code into a
quit. When the source is synchronous, as `from-list` is, Rakudo 2026.08 goes
on mapping and delivering the later values, and the done arrives after the
quit; `.grep` does the same. The consumers that turn a supply into a value
then lose the exception: the late done ends `.list` normally, before the
failing value, `await` returns the last value it saw, and `.wait` throws a
type check failure instead of the exception of the quit.

**Evidence:** related forms and the documentation. Over a live source
nothing follows the quit, and `.do` over the same synchronous source stops
at its quit. `doc/Type/Supply.rakudoc` says that `.list` throws once the
list reaches the quit, and that `.wait` throws the exception passed to
`quit`.

```raku
my &risky = { die "cannot map $_" if $_ == 2; $_ * 10 };
Supply.from-list(1, 2, 3).map(&risky)
    .tap(-> $v { say "got $v" }, done => { say "done" }, quit => { say "quit: ", .message });
say Supply.from-list(1, 2, 3).map(&risky).list;
try Supply.from-list(1, 2, 3).map(&risky).wait;
say $!.message;
```
```output
got 10
quit: cannot map 2
got 30
done
(10)
Type check failed in binding; expected Exception but got Any (Any)
```

The full corners: [the late
values](#ch:supplies:an-exception-in-map-becomes-a-quit-and-later-values-still-arrive)
and [`.list` and
`await`](#ch:supplies:after-a-leaking-quit-list-and-await-lose-the-exception).

## `batch(:emit-timed)` never emits
tags: bug

From [Supplies](#ch:supplies). Without `:emit-timed`, a batch with
`:seconds` is emitted when a value arrives in a later slice of time, or at
the done. With `:emit-timed`, Rakudo 2026.08 emits nothing at all, not even
the done.

**Evidence:** the documentation. `doc/Type/Supply.rakudoc` (method `batch`)
says that with `:emit-timed` a timer emits whatever is in the batch every
given number of seconds, and that the remaining values come in a final batch
when the supply is done.

```raku local
my $sup = Supplier.new;
my @got;
$sup.Supply.batch(:seconds(0.1), :emit-timed)
    .tap(-> $b { @got.push($b) }, done => { @got.push("done") });
$sup.emit(1);
sleep 0.2;
$sup.done;
say @got.raku;
```
```output
[]
```

[The full corner](#ch:supplies:batchemit-timed-never-emits).

## `elems` with an interval below one second divides by zero
tags: bug

From [Supplies](#ch:supplies). Given an interval below one second, the
Supply method `.elems` in Rakudo 2026.08 makes the first value die with
`X::Numeric::DivideByZero`, a division the caller never wrote.

**Evidence:** the documentation and a crash on valid input.
`doc/Type/Supply.rakudoc` describes the argument of `.elems` as an interval
in seconds, and `batch` takes its `:seconds` to the millisecond.

```raku
try say Supply.from-list(1, 2).elems(0.5).list;
say $!.^name;
```
```output
X::Numeric::DivideByZero
```

[The full corner](#ch:supplies:elems-with-an-interval-below-one-second-divides-by-zero).

## `stable` emits a waiting value after the done
tags: bug

From [Supplies](#ch:supplies). `.stable($seconds)` passes a value on only
when no newer value follows within the time. In Rakudo 2026.08 the done is
passed on at once, and a value still waiting is emitted after it, when a
`react` or a `.list` has stopped listening.

**Evidence:** related forms: `delayed` and `throttle`, which also hold values
back for a time, deliver what they hold before the done.

```raku local
my $sup = Supplier.new;
my @got;
$sup.Supply.stable(0.1).tap(-> $v { @got.push($v) }, done => { @got.push("done") });
$sup.emit(1);
$sup.done;
sleep 0.2;
say @got;
```
```output
[done 1]
```

[The full corner](#ch:supplies:stable-emits-a-waiting-value-after-the-done).
