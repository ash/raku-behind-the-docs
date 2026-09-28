---
title: Strings
part: Nothing and numbers
summary: How a Str counts, cuts, searches and compares its graphemes, how text becomes a number or an allomorph that is both, and where Rakudo's string methods stop doing what their names promise.
---

A Raku string, a `Str`, is a sequence of *graphemes*: what a reader takes for
one character, even when Unicode needs several code points to write it. Every
string method counts, cuts and searches in graphemes. Behind the one-line
description of each method there are rules that decide the edges: what an
empty needle finds, which positions are out of range and which merely past the
end, what a limit counts, and what comes back when the invocant is not a plain
Str.

Strings also turn into numbers. `+"42"` reads the text with the grammar of a
number literal, and `val` goes further: it makes an *allomorph*, a value that
is a number and a string at the same time. The first part of this chapter is
about that border. Quoting, escapes and interpolation are in [Quotes and
Interpolation](#ch:quotes), numbers themselves in [Numbers](#ch:numbers), and
regexes and `.match` in [Regexes and Grammars](#ch:regexes).

## Two strings with the same text are the same value

A Str is a value: `===` and `eqv` compare the text, however the two strings
were built. The text is normalised when the string is created, to the form
Raku calls NFG, so a letter followed by a combining accent and the
precomposed letter are the same string. Both operators also require the same
type, so a Str is never identical to a number, nor to an allomorph with the
same text.

```raku
say "abc" === "ab" ~ "c";
say "e\x[301]" === "é";
say "1" eqv 1;
say "1" eqv <1>;
say Str.new(value => 1.5).raku;
```
```output
True
True
False
False
"1.5"
```

`Str.new` takes its text as the named argument `value`, and turns anything
else into its `.Str`.

## A subclass of Str keeps its type through its own methods
tags: undocumented unasserted

A class that inherits from Str gets its own type back from every method that
builds a string out of the invocant: `uc`, `substr`, `trim`, `subst`, `flip`,
and each piece returned by `words`, `lines`, `comb` and `split`. The operators
`~` and `x` return a plain Str. An object of the subclass is `eq` to a plain
string with the same text, but not `eqv`, because the types differ.

```raku
class Name is Str {}
my $n = Name.new(value => "ada lovelace");
say $n.uc.^name;
say $n.words[0].^name;
say ($n ~ "!").^name;
say ($n x 2).^name;
say $n eq "ada lovelace";
say $n eqv "ada lovelace";
```
```output
Name
Name
Str
Str
True
False
```

## `"0"` is true, but `<0>` is false
tags: trap

A string is false only when it is empty. `"0"` is true, unlike in Perl, and
so are `"0.0"` and `" "`. An allomorph takes its truth from its number, so the
word `0` in angle brackets is false. The Str type object is false, like every
type object.

```raku
say ?"0";
say ?"0.0";
say ?" ";
say ?"";
say ?<0>;
say ?<0.0>;
say ?Str;
say ?+"0";
```
```output
True
True
True
False
False
False
False
False
```

The last line numifies first, which is the way to ask whether a string holds
a zero.

## A string cannot be unpacked by a signature

A sub-signature, the parenthesised part of a parameter such as `($head, *@)`,
unpacks its argument by turning it into a Capture. A Str refuses, with a
message that guesses at the mistake:

```raku
sub first-of(($head, *@)) { $head }
say first-of(<a b c>);
say first-of("abc");
```
```output
a
```
```stderr
Cannot unpack or Capture `abc`.
To create a Capture, add parentheses: \(...)
If unpacking in a signature, perhaps you needlessly used parentheses? -> ($x) {} vs. -> $x {}
or missed `:` in signature unpacking? -> &c:(Int) {}
  in sub first-of at example.raku line 1
  in block <unit> at example.raku line 3

```

An IntStr refuses in the same way. A RatStr does not: it turns into a Capture
as a Rat does, with its numerator and denominator as named arguments, so it
unpacks into named parameters and refuses positional ones with a different
message.

```raku
my (:$numerator, :$denominator) := <4.2>;
say "$numerator/$denominator";
try { my ($x) := <42> };
say $!.^name;
try { my ($x) := <4.2> };
say $!.message;
```
```output
21/5
X::Cannot::Capture
Too few positionals passed to '<anon>'; expected 1 argument but got 0
```

## Smartmatching against a string compares the topic's text

`$x ~~ "text"` turns the topic into a string with `.Str` and compares it with
`eq`. A number matches its own spelling, which for `1.0` is `"1"`, and a list
matches its elements joined by spaces. A type object on the left never
matches, not even the empty string.

```raku
say 1.0 ~~ "1";
say 1/2 ~~ "0.5";
say (1, 2) ~~ "1 2";
say "abc" ~~ "ABC";
say Nil ~~ "";
given 1.0 {
    when "1" { say "matched the text" }
}
```
```output
True
True
True
False
False
matched the text
```

The `given` shows where this matters: `when` with a string compares the text
of whatever the topic is.

## `+"…"` skips surrounding whitespace, and an empty string is 0
tags: trap

Numification, whether by prefix `+`, by `.Numeric` or by an arithmetic
operator, reads the string with the grammar of a number literal. Whitespace at
either end is ignored, and a string with nothing else in it, the empty string
included, is 0, without a warning. Underscores between digits, the Unicode
minus sign U+2212 and the decimal digits of any script are accepted. As in
code, a radix point makes a Rat, even in `3.0`, and an exponent makes a Num.

```raku
say +" 42\n";
say +"";
say +"1_000";
say +"\x[2212]42";
say +"١٢";
say (+"3.0").raku;
say (+"1e3").raku;
say (+".5").raku;
say +"1e400";
```
```output
42
0
1000
-42
12
3.0
1000e0
0.5
Inf
```

The fifth line is 12 written in Arabic-Indic digits. An exponent too large
for a Num gives Inf, not an error.

## A string can hold any number literal, even a fraction

The grammar is the language's whole number syntax: radix prefixes, the
`:16<FF>` form, a fraction written as two integers, `Inf` and `NaN`, complex
numbers, and the `2*10**3` form that radix notation uses for an exponent. A
fraction with a zero denominator is kept as it is, not refused.

```raku
for "0x1F", "0b101", "0x1.8", ":16<FF>", "1/3", "1/0", "-Inf", "NaN",
    "1+2i", "3-4\\i", "2*10**3", "½" {
    say "$_ → ", (+$_).raku;
}
```
```output
0x1F → 31
0b101 → 5
0x1.8 → 1.5
:16<FF> → 255
1/3 → <1/3>
1/0 → <1/0>
-Inf → -Inf
NaN → NaN
1+2i → <1+2i>
3-4\i → <3-4i>
2*10**3 → 2000
½ → RatStr.new(0.5, "½")
```

The last line is the odd one: a lone vulgar-fraction character numifies to a
RatStr, an allomorph, where every other form gives a plain number.

## A string that is not a number gives a Failure

When the text does not parse, numification does not throw at once. It
returns a Failure, which throws only when something uses the value, so the
report names two lines: where the string was converted, and where the result
was used.

```raku
my $n = +"12abc";
say "still running";
say $n + 1;
```
```output
still running
```
```stderr
Cannot convert string to number: trailing characters after number in '12<HERE>abc' (indicated by <HERE>)
  in block <unit> at example.raku line 1

Actually thrown at:
  in block <unit> at example.raku line 3

```

A Failure is undefined, so `with` or `.defined` tests the result without
throwing, and its exception holds the position where parsing stopped. The
named argument `:fail-or-nil` makes `.Numeric` return Nil instead. All of
these are refused, except the last:

```raku
sub parse($s) {
    my $n = $s.Numeric;
    $n.defined ?? $n.raku !! "refused at {$n.exception.pos}";
}
say parse($_) for "5.", "1,000", "1__0", "inf", "Ⅻ", "0b2", "- 5", "1/-2";
say "12abc".Numeric(:fail-or-nil).raku;
```
```output
refused at 2
refused at 1
refused at 1
refused at 0
refused at 0
refused at 2
refused at 1
-0.5
Nil
```

A radix point must be followed by a digit, a comma is not a digit separator,
underscores come one at a time, `Inf` is spelt with a capital, Roman numerals
are letters, a binary number has no digit 2, and a sign must touch its
number. A sign on the denominator of a fraction is accepted.

## `.Int` truncates, and `.Num` keeps a negative zero

The coercion methods of Str parse the text and then convert the number.
`.Int` truncates toward zero whatever the string held, `.Rat` makes an integer
into a Rat, and `.UInt` truncates before it checks the sign, so `"-0.5"`
passes. Int and Rat have no negative zero; Num has one, and `.Num` keeps the
sign of every spelling of zero.

```raku
say "-42.7".Int;
say "1e3".Int;
say "42".Rat.raku;
say "-0.5".UInt;
say (+"-0.0").raku;
say (+"-0e0").raku;
say "-0".Num.raku;
```
```output
-42
1000
42.0
0
0.0
-0e0
-0e0
```

A value with no integer form is refused, each kind with its own exception,
while a zero denominator is fine as a Rat or a Num:

```raku
for "Inf", "1/0", "1+2i", "abc" -> $s {
    try $s.Int;
    say "$s: ", $!.^name;
}
say (try "-1".UInt) // $!.^name;
say "1/0".Rat.raku;
say "1/0".Num;
```
```output
Inf: X::Numeric::CannotConvert
1/0: X::Numeric::DivideByZero
1+2i: X::Numeric::Real
abc: X::Str::Numeric
X::OutOfRange
<1/0>
Inf
```

## `val` makes an allomorph and keeps the exact text

`val` parses a string as numification does and, when it holds a number,
returns an allomorph: an IntStr, RatStr, NumStr or ComplexStr holding both the
number and the original text, surrounding whitespace included. A string that
is not a number comes back unchanged. A `< >` word list passes each of its
words through `val` ([Quotes and
Interpolation](#ch:quotes:numbers-in-a-word-list-become-allomorphs)).

```raku
say val("42").raku;
say val(" 42 ").raku;
say val("0x1F").raku;
say val("1e3").raku;
say val("12abc").raku;
say val("").raku;
say val(" ").raku;
```
```output
IntStr.new(42, "42")
IntStr.new(42, " 42 ")
IntStr.new(31, "0x1F")
NumStr.new(1000e0, "1e3")
"12abc"
IntStr.new(0, "")
" "
```

The empty string becomes an allomorph of 0, but a string of spaces stays a
Str, although both numify to 0. Given a list, `val` works on each element; a
value that is not a string comes back as it is, with a warning.

```raku
say val(("1", "x")).raku;
say val(42).raku;
```
```output
(IntStr.new(1, "1"), "x")
42
```
```stderr
Value of type Int uselessly passed to val()
  in block <unit> at example.raku line 2
```

## An allomorph compares by both halves

`==` compares the numbers and `eq` the strings, so `<00>` and `<0>` are equal
as numbers and different as text. `===` wants both halves the same, and `eqv`
also the same allomorph type:

```raku
say <00> == <0>;
say <00> eq <0>;
say <00> === <0>;
say <42> === 42;
say <42> eqv <42>;
say <1> eqv <1.0>;
```
```output
True
False
False
False
True
False
```

`cmp`, and with it `sort`, compares the numbers first and looks at the
strings only when the numbers are equal. `leg` compares only the strings,
and `<=>` only the numbers:

```raku
say <2> cmp <10>;
say "2" cmp "10";
say <1> cmp <01>;
say <1> leg <1.0>;
say <1> <=> <1.0>;
say <10 9 2 01 1>.sort;
```
```output
Less
More
More
Less
Same
(01 1 2 9 10)
```

Numbers in a word list therefore sort as numbers, and `01` and `1`, equal as
numbers, sort by their text.

## Smartmatch reads one half of an allomorph; sets want both

When an allomorph is the pattern of a smartmatch, the type of the topic
decides which half is compared: a number is compared with the number, a
string with the string. So `5.0` matches `<5>`, and `"5.0"` does not.

```raku
say 5.0 ~~ <5>;
say "5" ~~ <5>;
say "5.0" ~~ <5>;
say <5> ~~ 5;
```
```output
True
True
False
True
```

Sets, bags and `.unique` compare by identity, and an allomorph is identical
only to an allomorph of the same type and text ([the previous
corner](#ch:strings:an-allomorph-compares-by-both-halves)). Neither the number
nor the string is. Numify the words when the set is meant to hold numbers:

```raku
say <42> ∈ (42, 43);
say "42" ∈ <42 43>;
say 42 ∈ <42 43>».Numeric;
say <1 1.0>.unique.elems;
say (<1>, 1).unique.elems;
```
```output
False
False
True
2
2
```

## An allomorph is Int and Str, so a multi cannot choose
tags: trap

An IntStr is an Int and a Str at once, and it passes a parameter typed with
either. When a multi has one candidate for each, both match equally well and
the call fails:

```raku
sub twice(Int $n) { $n * 2 }
say twice(<21>);
multi kind(Int $) { "Int" }
multi kind(Str $) { "Str" }
say kind(<21>);
```
```output
42
```
```stderr
Ambiguous call to 'kind(IntStr)'; these signatures all match:
  (Int $) from example.raku line 3
  (Str $) from example.raku line 4
  in block <unit> at example.raku line 5

```

A candidate for the allomorph type itself is narrower than both, and wins.
Each allomorph type inherits from Allomorph, which is a Str, and from its
number type:

```raku
multi kind(Int $) { "Int" }
multi kind(Str $) { "Str" }
multi kind(IntStr $) { "both" }
say kind(<21>);
say kind(21);
say <21>.^mro.map(*.^name);
```
```output
both
Int
(IntStr Allomorph Str Int Cool Any Mu)
```

## String methods on an allomorph return a plain Str

An allomorph's string methods work on its text and return plain strings, and
its arithmetic works on its number. An operation that changes an allomorph
variable in place stores whatever the operation produced, so the variable
holds a plain value afterwards:

```raku
my $n = <42>;
say $n.flip.raku;
say ($n ~ "").raku;
say ($n + 1).raku;
my $x = <42>;
$x .= subst("4", "x");
say $x.raku;
my $y = <42>;
$y++;
say $y.raku;
```
```output
"24"
"42"
43
"x2"
43
```

## `<42>.lines` returns an allomorph whose number is 0
tags: bug

`lines` is the exception to the previous corner. On an allomorph it returns
an allomorph of the same type, with the right text and the number 0, so the
line is `eq "42"` and `== 0` at once. Every other string method returns a plain
Str, and so should this one (Rakudo 2026.08).

```raku
say <42>.lines.raku;
say <42>.lines[0] == 0;
say "42".lines.raku;
```
```output
(IntStr.new(0, "42"),).Seq
True
("42",).Seq
```

## `~` calls `.Str`, which shortens a Rat and tab-joins a Hash
tags: trap

Concatenation turns each operand into a string with `.Str`. A Rat whose
decimal expansion does not end is shortened (the rule is in
[Numbers](#ch:numbers)), a large Num gets an explicit exponent sign, a list
is joined with spaces, and a Hash or a Pair with a tab between key and value.
The result is always a plain Str.

```raku
my $third = 1/3;
say "a" ~ $third;
say "a" ~ 1e100;
say "a" ~ (1, 2);
say ("a" ~ { x => 1 }).raku;
say ("a" ~ (1 => 2)).raku;
```
```output
a0.333333
a1e+100
a1 2
"ax\t1"
"a1\t2"
```

The Rat keeps its whole value; only its text is short. An undefined value
concatenates as the empty string, and each one warns when it happens:

```raku
my $s;
say "[" ~ $s ~ "]";
say "[" ~ Int ~ "]";
```
```output
[]
[]
```
```stderr
Use of uninitialized value element of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 2
Use of uninitialized value of type Int in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 3
```

## The count of `x` goes through `.Int`, and Inf is refused

`x` repeats a string. Its right side is converted to an integer: a fraction
is truncated, zero or a negative count gives the empty string, `True` counts
1, a numeric string is parsed, and a list counts its elements.

```raku
say "ab" x 2.9;
say ("ab" x -1).raku;
say "ab" x True;
say "ab" x "2";
say "ab" x (7, 8);
```
```output
abab
""
ab
abab
abab
```

An infinite count is refused as not implemented, NaN has no integer form,
and a count that would make the string longer than 2³²−1 graphemes dies
before any memory is spent:

```raku
for Inf, NaN, 2**31 -> $n {
    try { my $s = "ab" x $n };
    say $!.message;
}
```
```output
Cat object not yet implemented. Sorry.
Cannot convert NaN to Int
Can't repeat string, required number of graphemes (2 * 2147483648) greater than max allowed of 4294967295
```

## `lt` and `cmp` compare code points, so capitals sort first
tags: trap

String comparison goes code point by code point, with no notion of an
alphabet or a locale. Every capital Latin letter comes before every lower-case
one, and an accented letter comes after `z`. A string that is a prefix of
another sorts first. A number compared by a string operator is compared as its
text.

```raku
say <b A a B>.sort;
say <é z e>.sort;
say "a" cmp "ab";
say "10" cmp 9;
say 10 lt 9;
say <b A a B>.sort(*.fc);
```
```output
(A B a b)
(e z é)
Less
Less
True
(A a b B)
```

Sorting by `.fc`, the case-folded form, gives an order that ignores case.
`sort` is stable, so of two strings that fold alike, the one that came first
stays first.

## `~|`, `~&` and `~^` combine strings code point by code point
tags: undocumented

The string bitwise operators apply `+|`, `+&` and `+^` to each pair of code
points. Or and xor keep the tail of the longer operand; and stops at the end
of the shorter one. The result is always a Str, even for numbers.

```raku
say ("ab" ~| "  ").raku;
say ("AB" ~^ "  ").raku;
say ("abc" ~^ "ab").raku;
say ("abc" ~& "A").raku;
say (3 ~| 4).raku;
```
```output
"ab"
"ab"
"\0\0c"
"A"
"7"
```

The prefix form `~^` and the shifts `~<` and `~>` parse, but die as not yet
implemented:

```raku
try { say ~^"a" };
say $!.message;
try { say "a" ~< 1 };
say $!.message;
```
```output
prefix:<~^> not yet implemented. Sorry.
infix:«~<» not yet implemented. Sorry.
```

## `succ` increments the last run of letters or digits
tags: quirk

`++` on a string calls `succ`, which counts like an odometer on the last run
of letters or digits. Each character carries into the one before it within
its own range, `a` to `z`, `A` to `Z` or `0` to `9`, and a carry out of the
first character adds a new one. A run that follows a dot is taken for a file
extension and skipped. A string that ends in anything else, or in a letter
outside the known ranges such as `é`, is left alone.

```raku
say .succ for "Az", "zz", "a9", "Zz9", "img001.png", "12.34", "a.9", "a-", "é";
```
```output
Ba
aaa
b0
AAa0
img002.png
13.34
b.9
a-
é
```

`"12.34".succ` is `"13.34"`, not `"12.35"`: the `34` counts as an
extension. Other scripts have ranges of their own, and so do the Roman
numerals from `Ⅰ` to `Ⅻ`, which makes `Ⅻ` carry like a `9`:

```raku
say "α".succ, " ", "ω".succ;
say "٩".succ;
say "⑨".succ;
say "Ⅴ".succ;
say "Ⅻ".succ;
```
```output
β αα
١٠
⑩
Ⅵ
ⅠⅠ
```

## `pred` fails where `succ` would have carried

`--` calls `pred`, which counts down to the start of each range. A run that
cannot go lower does not wrap or shrink: `pred` returns a Failure, and `--`
stores that Failure in the variable.

```raku
say "b".pred;
say "ba".pred;
say "10".pred;
say "a".pred.exception.message;
my $v = "a0";
$v--;
say $v.^name;
```
```output
a
az
09
Decrement out of range
Failure
```

`"10".pred` keeps the width, `"09"`. `"a0"` fails because the `0` would have
to borrow from the `a`, which is already at the start of its range.

## Case mapping follows Unicode, and can change the length

`uc`, `lc`, `tc` and `fc` use the full Unicode case mappings. `ß` has no
single capital, so `uc` makes it `SS` and `tc` makes it `Ss`; a ligature
expands; a digraph such as `ǆ` has a title-case form of its own; a final
sigma gets the final lower-case form. `fc`, *case folding*, is the form to
compare when case should not matter.

```raku
say "straße".uc;
say "ß".tc;
say "ﬁne".uc;
say "ǆemal".tc;
say "ΣΑΣ".lc;
say "Straße".fc eq "STRASSE".fc;
```
```output
STRASSE
Ss
FINE
ǅemal
σας
True
```

`flip` reverses graphemes, not code points, so an accent stays on its letter
and `\r\n` stays in order:

```raku
say "noe\x[308]l".flip;
say "a\r\nb".flip.raku;
```
```output
lëon
"b\r\na"
```

## `wordcase` capitalises a letter after a digit or a dot
tags: quirk

`wordcase` title-cases the first letter of each word and lower-cases the
rest. A word starts at a letter and runs on through letters, digits and
underscores, with `'` and `-` allowed inside, so `don't` and `stop-me` are one
word each. A digit cannot start a word, so letters after a leading digit start
one, and a dot ends a word.

```raku
say "don't stop-me now".wordcase;
say "3rd place".wordcase;
say "file.txt is_here".wordcase;
say "HELLO world".wordcase;
say "ab cd".wordcase(:filter(&uc));
say "have fun working on raku".wordcase(:where({ .chars > 3 }));
```
```output
Don't Stop-me Now
3Rd Place
File.Txt Is_here
Hello World
AB CD
Have fun Working on Raku
```

`:filter` replaces the title-casing, and `:where` chooses the words that are
changed.

## `samecase` and `samemark` copy a pattern position by position
tags: quirk

`samecase` gives each character the case of the pattern character at the same
position. A pattern character without case, such as a digit, `_`, a space or
a title-case letter, leaves its character alone, and when the pattern runs out
its last case carries on. `samemark` does the same with combining marks.

```raku
say "raku".samecase("A_a_");
say "abcdef".samecase("Ab");
say "bye bye".samecase("Hello World");
say "abc".samemark("ä");
say "åäö".samemark("aäo");
```
```output
Raku
Abcdef
Bye byE
äb̈c̈
aäo
```

The third line applies the rule by position, not by word: the letters of the
second `bye` stand under `o`, a space and `W`, which makes them lower,
unchanged and upper. `samemark` treats the grapheme `\r\n` as a `\r`
carrying the `\n` as its mark, so the `\n` is replaced:

```raku
say "\r\n".samemark("ä").ords;
```
```output
(13 776)
```

## `samespace` copies the whitespace between words
tags: undocumented

`samespace` replaces each run of whitespace in the string with the run at the
same position in the pattern. Whitespace at the start counts as the first run.
Where the pattern has no more runs, the string's own stay.

```raku
say "a b c".samespace("x\ty\nz").raku;
say "a b c d".samespace("x\ty").raku;
say " a b".samespace("\tx\ty").raku;
say "a b ".samespace("x y").raku;
```
```output
"a\tb\nc"
"a\tb c d"
"\ta\tb"
"a b "
```

## `chomp` removes one line ending of any kind; `chop` one grapheme

`chomp` removes a single line ending: `\n`, `\r`, the pair `\r\n`, or one of
the Unicode line separators. Only one, so a string that ends in two newlines
keeps one, and `\n\r` is two line endings, of which the `\r` goes. Given an
argument, `chomp` removes that exact suffix once; `\r\n` is one grapheme, so
`"\n"` does not match its end.

```raku
say "abc\r\n".chomp.raku;
say "abc\n\n".chomp.raku;
say "abc\n\r".chomp.raku;
say "abc\x[2028]".chomp.raku;
say "abcdef".chomp("def").raku;
say "abc\r\n".chomp("\n").raku;
```
```output
"abc"
"abc\n"
"abc\n"
"abc"
"abc"
"abc\r\n"
```

`chop` removes the last grapheme, or the last *n*. A count larger than the
string empties it, and a negative count changes nothing.

```raku
say "ab\r\n".chop;
say "ae\x[301]".chop;
say "abc".chop(2);
say "abc".chop(5).raku;
say "abc".chop(-1);
```
```output
ab
a
a
""
abc
```

## `trim` removes Unicode whitespace, but not zero-width characters

`trim`, `trim-leading` and `trim-trailing` remove characters that Unicode
classes as White_Space: the ASCII ones, the no-break space, the ideographic
space and the other typographic spaces. The zero-width space U+200B and the
byte-order mark U+FEFF are not whitespace, and stay.

```raku
say "\x[A0]a\x[3000]".trim.raku;
say "\x[200B]a".trim.chars;
say "\x[FEFF]a".trim.chars;
say " \x[301]a".trim.raku;
```
```output
"a"
2
2
"a"
```

A combining mark after a space forms one grapheme with it, and goes with the
space.

## `index` returns Nil, not -1, and 0 is a find
tags: trap

`index` gives the position of the first occurrence, or Nil when there is
none. A match at the start is at position 0, which is false, so `if` is the
wrong test; `with` tests for a defined result.

```raku
say "abcabc".index("b");
say "abcabc".index("b", 2);
say "abcabc".index("x").raku;
say "at 0" if "abc".index("a");
say "found" with "abc".index("a");
```
```output
1
4
Nil
found
```

The empty needle is found wherever the search starts, up to and including
the end of the string. A list of needles finds the earliest of them:

```raku
say "abc".index("", 3);
say "abc".index("", 4).raku;
say "abc".index(<c b>);
```
```output
3
Nil
1
```

## A negative position fails; one past the end finds nothing

For `index`, `rindex`, `indices`, `contains` and `substr-eq`, a negative
starting position is an error, returned as a Failure. A position after the
end is not an error: there is simply nothing to find there.

```raku
my $s = "abc";
say $s.index("b", -1).exception.message;
say $s.index("b", 3).raku;
say $s.contains("b", 4);
say $s.indices("b", 4).raku;
```
```output
Position in calling 'index' out of range. Is: -1, should be in 0..3
Nil
False
()
```

## `rindex` dies on a position at the end
tags: bug

`rindex` searches backwards from its position. Given a position at the end of
the string or beyond, it should search from the end and find the last
occurrence; for the other search methods a position past the end is no error.
Instead it throws an untyped exception whose message contradicts itself
(Rakudo 2026.08). An empty needle is spared:

```raku
my $s = "abc";
say $s.rindex("c");
say $s.rindex("c", 2);
say $s.rindex("", 4).raku;
say $s.rindex("c", 3);
```
```output
2
2
Nil
```
```stderr
index start offset (3) out of range (0..3)
  in block <unit> at example.raku line 5

```

## A needle list with a position is searched as one string
tags: bug

`index` and `rindex` accept a list of needles and search for all of them.
Adding a starting position breaks that (Rakudo 2026.08). `index` then joins
the list into one string, with spaces, and searches for that:

```raku
my $s = "abc";
say $s.index(<c b>);
say $s.index(<c b>, 0).raku;
say "a b".index(<a b>, 0);
```
```output
1
Nil
0
```

The third line finds the text `a b`, the two needles joined. The same call on
`rindex` does not return at all; it runs until it is killed:

```raku nocheck
say "abc".rindex(<a b>, 1);
```

## `rindex` searches backwards and ignores `:i`
tags: quirk

`rindex` returns the last position, at or before its second argument, where
the needle starts; a list of needles gives the latest position of any of
them. `index`, `indices`, `contains`, `starts-with` and `ends-with` take `:i`
to ignore case and `:m` to ignore marks. `rindex` accepts both adverbs and
does nothing with them.

```raku
say "abcabc".rindex("b", 3);
say "abc".rindex("bc", 1);
say "aardvark".rindex(<d v k>);
say "aBc".index("b", :i);
say "aBc".rindex("b", :i).raku;
```
```output
1
1
7
1
Nil
```

## `indices` does not overlap unless asked

`indices` lists every position where the needle starts. After a match it goes
on past the matched text; `:overlap` makes it go on one character later. The
empty needle is found at every position, the end included.

```raku
say "banana".indices("ana");
say "banana".indices("ana", :overlap);
say "abc".indices("");
say "abc".indices("x").raku;
say "banAna".indices("a", :i);
```
```output
(1)
(1 3)
(0 1 2 3)
()
(1 3 5)
```

## `contains(/…/, $pos)` cannot match at the end
tags: quirk

`contains` takes a string, a regex, or a Junction of needles. The empty string
is found at any position up to the end, as with the other search methods. With
a regex and a starting position, though, the regex is tried only at positions
before the end, so a pattern that can only match at the end is missed:

```raku
say "abc".contains("", 3);
say "abc".contains(any <x b>);
say "abc".contains(/$/);
say "abc".contains(/$/, 3);
say "".contains(/^$/);
say "".contains(/^$/, 0);
```
```output
True
any(False, True)
True
False
True
False
```

In the empty string, position 0 is already the end.

## `:i` folds case fully, except in `ends-with`
tags: quirk

`:i` compares case-folded text, so `ß` matches `SS` and a ligature matches
its letters. Folding can change the length, and `ends-with` measures the
needle before folding it, so a fold that changes the length never matches at
the end. `:m` compares the base characters without their marks.

```raku
say "Straße".starts-with("STRASSE", :i);
say "ﬁx".starts-with("fi", :i);
say "straße".ends-with("SSE", :i);
say "STRASSE".ends-with("ße", :i);
say "résumé".index("e", :m);
say "a".contains("a\x[301]", :m);
```
```output
True
True
False
False
1
True
```

## `starts-with`, `ends-with` and `substr-eq` compare at one place

`substr-eq` tests whether the needle occurs exactly at a position, which may
be code that receives the length; without a position it is `starts-with`.
The empty needle matches at every position up to the end. A needle that is
not a string is stringified, so a list is its elements joined by spaces, and
a regex is refused.

```raku
say "foobar".substr-eq("bar", 3);
say "foobar".substr-eq("bar", *-3);
say "foobar".substr-eq("", 6);
say "foobar".substr-eq("", 7);
say "a b".starts-with(<a b>);
say (try "abc".starts-with(/a/)) // $!.^name;
```
```output
True
True
True
False
True
X::Multi::NoMatch
```

## `substr` takes a range or code, but not `*-3..*`
tags: trap

`substr($from, $chars)` returns up to `$chars` characters, so a length past
the end is cut short. The start may be code that receives the length of the
string, `*-2` for the last two characters, and the length may be code that
receives the number of characters left. A Range gives the positions
directly.

```raku
my $s = "abcdef";
say $s.substr(2, 100);
say $s.substr(*-2);
say $s.substr(1, *-1);
say $s.substr(1..3);
say $s.substr(2..*);
say $s.substr(3..2).raku;
```
```output
cdef
ef
bcde
bcd
cdef
""
```

An array takes the slice `[*-3..*]`, but `substr(*-3..*)` fails: code that
returns a Range is not one of its forms. With `*` on both ends the code
wants two arguments and gets one.

```raku
my $s = "abcdef";
try $s.substr(*-3..*);
say $!.message;
try $s.substr(*-3..*-1);
say $!.message;
say $s.substr(*-3);
```
```output
Cannot convert Inf to Int
Too few positionals passed; expected 2 arguments but got 1
def
```

## `substr` out of range returns a Failure with advice

A start below 0 or past the end, or a negative length, is an `X::OutOfRange`
Failure. Its message suggests the `*-N` form, even for a start past the end,
where `*-N` is out of range too. A start of exactly the length is fine and
gives the empty string.

```raku
my $s = "abc";
say $s.substr(3).raku;
say $s.substr(-1).exception.message;
say $s.substr(4).exception.message;
say $s.substr(1, -1).exception.message;
```
```output
""
Start argument to substr out of range. Is: -1, should be in 0..3; use *-1 if you want to index relative to the end
Start argument to substr out of range. Is: 4, should be in 0..3; use *-4 if you want to index relative to the end
Number of characters argument to substr out of range. Is: -1, should be in 0..^Inf; use *-1 if you want to index relative to the end
```

## `substr-rw` splices into the variable

`substr-rw` returns a container for part of a variable's text: assigning to it
replaces that part, whatever the length of the replacement. The variable ends
up holding a new Str, even if it held a number. A literal is not a variable,
and cannot be changed.

```raku
my $s = "abcd";
$s.substr-rw(1, 2) = "XYZ";
say $s;
$s.substr-rw(2, 0) = "-";
say $s;
my $n = 1234;
$n.substr-rw(1, 1) = "z";
say $n.raku;
try { "abcd".substr-rw(1) = "x" };
say $!.message;
```
```output
aXYZd
aX-YZd
"1z34"
'substr-rw' requires a writeable container
```

## A bound `substr-rw` writes into the text it first saw
tags: quirk

Binding the result of `substr-rw` keeps the container for later. Reading it
reads the variable's current text, but every assignment to it splices into
the text as it was when the container was made, so a change made to the
variable in between is lost:

```raku
my $s = "abcd";
my $part := $s.substr-rw(1, 2);
$s = "wxyz";
say $part;
$part = "Q";
say $s;
```
```output
xy
aQd
```

## `chars` counts graphemes, `codes` code points after composition

A Str is stored as graphemes, and `chars` counts them. `codes` counts code
points in NFC, the composed form: a letter and an accent that have a
precomposed code point count one, and those that do not count two. The number
of bytes depends on the encoding, UTF-8 by default.

```raku
for "e\x[301]", "x\x[301]", "\r\n",
    "\x[1F468]\x[200D]\x[1F469]\x[200D]\x[1F467]", "\x[1F1FA]\x[1F1F8]" -> $s {
    say "{$s.chars} {$s.codes} {$s.encode.bytes}";
}
say "é".NFD.list;
```
```output
1 1 2
1 2 3
1 2 2
1 5 18
1 2 8
(101 769)
```

The fourth string is a family emoji, three people joined by zero-width
joiners; the fifth is a flag, two regional indicators. `.NFD` gives the
decomposed code points.

## `comb` with a number cuts chunks; with a fraction it searches
tags: trap

`comb(n)` cuts the string into chunks of *n* characters, the last one
shorter; a size of 1 or less means single characters, and a second argument
limits the number of chunks. A size that is not an integer is not truncated:
a Rat is taken as a string to search for.

```raku
say "abcdefg".comb(3);
say "abcdefg".comb(3, 2);
say "abc".comb(0);
say "a\r\nb".comb.raku;
say "1.2.5 x 2.5".comb(2.5);
```
```output
(abc def g)
(abc def)
(a b c)
("a", "\r\n", "b").Seq
(2.5 2.5)
```

## `comb` with a string and a limit finds overlapping matches
tags: bug

`comb("aa")` returns each occurrence of the needle, without overlaps. Given a
limit, the search moves on by one character after each find instead of by the
length of the needle, so the matches overlap; a negative limit, which means
none in the other forms of `comb`, gives all the overlapping ones. `*` keeps
the normal rule (Rakudo 2026.08).

```raku
say "aaaa".comb("aa");
say "aaaa".comb("aa", 3);
say "aaaa".comb("aa", *);
say "aaaa".comb("aa", -1);
```
```output
(aa aa)
(aa aa aa)
(aa aa)
(aa aa aa)
```

## `comb` with a regex returns every match, empty ones included

A regex needle returns the matched strings, or Match objects with `:match`.
A pattern that can match the empty string does so wherever nothing longer
matches, the end of the string included.

```raku
say "a1b22c333".comb(/\d+/);
say "a1b22c333".comb(/\d+/, 2);
say "aaa".comb(/a*/).raku;
say "abc".comb(/<?>/).raku;
say "aXbXc".comb(/X <( \w /);
say "a1b22".comb(/\d+/, :match)[1].from;
```
```output
(1 22 333)
(1 22)
("aaa", "").Seq
("", "", "", "").Seq
(b c)
3
```

`<(` marks where the returned part of the match begins. Regexes themselves
are the subject of [Regexes and Grammars](#ch:regexes).

## `lines` splits at any line ending; a final one adds nothing

`lines` breaks the string at `\n`, `\r`, `\r\n` and the Unicode line and
paragraph separators. A line ending at the very end does not start another
line, so `"\n"` is one empty line and `""` is none at all. `:!chomp` keeps the
endings, and a number limits the count.

```raku
say "a\nb\n".lines.raku;
say "a\r\nb\rc\x[2028]d".lines.raku;
say "\n".lines.raku;
say "".lines.raku;
say "a\r\nb\n".lines(:!chomp).raku;
say "a\nb\nc".lines(2).raku;
```
```output
("a", "b").Seq
("a", "b", "c", "d").Seq
("",).Seq
().Seq
("a\r\n", "b\n").Seq
("a", "b").Seq
```

## `lines(:!count)` dies
tags: bug

`lines(:count)` returns the number of lines instead of the lines; the
documentation calls it deprecated. `:!count` should mean an ordinary call.
Instead it dies with a type error, as though the call had promised an integer
(Rakudo 2026.08):

```raku
say "a\nb\nc".lines(:count);
say "a\nb\nc".lines(:!count);
```
```output
3
```
```stderr
Type check failed for return value; expected Int:D but got Seq (("a", "b", "c").Seq)
  in block <unit> at example.raku line 2

```

## `words` splits at a no-break space; a word list does not

`words` splits at any Unicode whitespace, the no-break space U+A0 included,
and drops whitespace at the ends. The word-quoting constructs `< >`, `qw` and
`<< >>` treat a no-break space as part of a word, which is what the character
is for. The ideographic space U+3000 separates in both, and the zero-width
space in neither.

```raku
use MONKEY-SEE-NO-EVAL;
my $text = "a\x[A0]b c";
say $text.words.elems;
say EVAL("<$text>").elems;
say EVAL("<$text>")[0].ords;
say EVAL("<a\x[3000]b>").elems;
say "a\x[200B]b".words.elems;
```
```output
3
2
(97 160 98)
2
1
```

A no-break space cannot be seen in source code, which is why this example
builds its word lists with `EVAL`.

## `split("")` adds an empty string at each end

`split("")` splits between every two characters, and also before the first
and after the last, so the result starts and ends with an empty string. A
separator at either end does the same. `:skip-empty` removes the empty
strings, and nothing else.

```raku
say "abc".split("").raku;
say "abc".split("", :skip-empty).raku;
say ";a;;b;".split(";").raku;
say ";a;;b;".split(";", :skip-empty).raku;
say "".split(";").raku;
```
```output
("", "a", "b", "c", "").Seq
("a", "b", "c").Seq
("", "a", "", "b", "").Seq
("a", "b").Seq
("",).Seq
```

Splitting the empty string gives one empty piece, not none.

## `split` can return the separators, but in one form only

`:v` puts each separator between the pieces, `:k` its index in the list of
needles (always 0 for a single needle), `:kv` both, and `:p` a Pair of the
two. They exclude each other, and a second one is refused as soon as `split`
is called:

```raku
say "a;b,c".split(";", :v).raku;
say "a;b;c".split(";", :k).raku;
say "a;b;c".split(";", :p).raku;
try "a;b".split(";", :v, :k);
say $!.message;
```
```output
("a", ";", "b,c").Seq
("a", 0, "b", 0, "c").Seq
("a", 0 => ";", "b", 0 => ";", "c").Seq
Unsupported combination of adverbs ('k', 'v') passed to split on 'Str'.
```

## The limit of `split` counts pieces; `:end` counts from the right
tags: quirk

A second argument limits the number of pieces, so 2 splits once, 1 returns
the whole string (as a List, not a Seq) and 0 returns nothing. `:end` keeps
the last pieces instead of the first. Three combinations misbehave: `:end`
with 0 returns every piece, `:!end` drops the limit instead of ignoring the
adverb, and with a list of needles `:end` is ignored.

```raku
say "a;b;c;d".split(";", 2).raku;
say "a;b;c;d".split(";", 1).raku;
say "a;b;c;d".split(";", 0).raku;
say "a;b;c;d".split(";", 2, :end).raku;
say "a;b;c".split(";", 0, :end).raku;
say "a;b;c".split(";", 2, :!end).raku;
say "abcabc".split(<b c>, 2, :end).raku;
```
```output
("a", "b;c;d").Seq
("a;b;c;d",)
().Seq
("a;b;c", "d").Seq
("a", "b", "c").Seq
("a", "b", "c").Seq
("a", "cabc").Seq
```

## A fractional limit kills `split` with a string needle
tags: bug

Other methods convert a limit to an integer, and so does `split` with a
regex. With a string needle, a limit that is not an Int, even `2.0`, dies
with a low-level message (Rakudo 2026.08):

```raku
my $limit = 2.0;
say "a1b2c3d".split(/\d/, $limit).raku;
say "a;b;c;d".split(";", $limit).raku;
```
```output
("a", "b2c3d").Seq
```
```stderr
This type cannot unbox to a native integer: P6opaque, Rat
  in block <unit> at example.raku line 3

```

## `split` with a regex splits at empty matches too

With a regex needle, `:v` interleaves Match objects. A regex that can match
the empty string splits wherever it does, the start and the end included.

```raku
say "a1b22c".split(/\d+/).raku;
say "a1b22c".split(/\d+/, :v).map(*.^name);
say "abc".split(/<?>/).raku;
say "abc".split(/^/).raku;
say "abc".split(/b*/).raku;
```
```output
("a", "b", "c").Seq
(Str Match Str Match Str)
("", "a", "b", "c", "").Seq
("", "abc").Seq
("", "a", "", "c", "").Seq
```

## A list of needles splits at the longest, and returns strings
tags: bug

`split` takes a list of needles, strings or regexes. At each position the
earliest match wins, and of matches at the same position the longest; `:k`
gives the index of the needle in the list. An empty list splits nothing and
returns nothing. The documentation says that `:v` gives Match objects unless
every needle is a string, but it gives strings in every case (Rakudo
2026.08).

```raku
say "a;b,c".split(<; ,>, :k).raku;
say "aaa".split(("a", "aa"), :v).raku;
say "1a2bb3".split(['a', /b+/], :v).raku;
say "1a2bb3".split(['a', /b+/], :v).map(*.^name);
say "abc".split(()).raku;
```
```output
("a", 0, "b", 1, "c").Seq
("", "aa", "", "a", "").Seq
("1", "a", "2", "bb", "3").Seq
(Str Str Str Str Str)
().Seq
```

## A zero-width regex in a list of needles never returns
tags: bug

A single regex that matches the empty string splits between characters, [as
shown above](#ch:strings:split-with-a-regex-splits-at-empty-matches-too). Put
the same regex in a list of needles and it matches at the same place again
and again, without moving on: the call runs until it is killed (Rakudo
2026.08). It was meant to split as the single regex does.

```raku nocheck
say "abc".split([/<?>/]);
```

## `subst` with a string needle replaces it literally, once

A string needle is not a pattern: `"."` is a dot. Only the first occurrence
is replaced unless `:g` is given. The replacement defaults to the empty
string, and a replacement that is not a string is stringified.

```raku
say "a.b.c".subst(".", "-");
say "a.b.c".subst(".", "-", :g);
say "a.b.c".subst(/./, "-");
say "abc".subst("b");
say "abc".subst("b", 42);
```
```output
a-b.c
a-b-c
-.b.c
ac
a42c
```

When nothing matches, `subst` returns a Str with the original text.

## An empty needle with `:g` misses both ends
tags: bug

An empty string needle matches at position 0, so `subst` puts the
replacement at the start. With `:g` it matches only between characters,
never at the start or the end, and an empty string gets no replacement at
all. The regex `/<?>/`, which also matches the empty string, finds the ends
too. `:g` was meant to find every place that the single match can (Rakudo
2026.08).

```raku
say "abc".subst("", "-");
say "abc".subst("", "-", :g);
say "abc".subst(/<?>/, "-", :g);
say "".subst("", "x").raku;
say "".subst("", "x", :g).raku;
```
```output
-abc
a-b-c
-a-b-c-
"x"
""
```

## `subst` passes `:nth` and `:x` on, and refuses `:ov` and `:ex`

The matching adverbs of `.match` work in `subst` too, with a string needle as
well as a regex. `:nth` picks the occurrences to replace, `:x` wants an exact
count and replaces nothing when there are fewer, and `:c` starts the search at
a position. `:ov` and `:ex` would give overlapping matches, which cannot all be
replaced, and are refused.

```raku
say "abcbcb".subst("b", "x", :nth(2));
say "abcbcb".subst("b", "x", :nth(*));
say "abcbcb".subst("b", "x", :x(2));
say "abcbcb".subst("b", "x", :x(4));
say "abcbcb".subst("b", "x", :c(2), :g);
try "abc".subst("b", "x", :ov);
say $!.message;
```
```output
abcxcb
abcbcx
axcxcb
abcbcb
abcxcx
Cannot use :ov adverb in Str.subst, got True
```

The adverbs are described with `.match` in [Regexes and
Grammars](#ch:regexes).

## `:as(Str)` breaks `subst` with `:g`, `:nth` or `:x`
tags: bug

`:as(Str)` asks a match for strings instead of Match objects. `subst` accepts
it and, for a single replacement, ignores it. With any adverb that makes
several matches, `subst` looks for the positions of the matches, the strings
have none, and it dies, whether the needle is a string or a regex (Rakudo
2026.08). An adverb that changes nothing in the result was not meant to break
the call.

```raku
say "abc".subst(/b/, "x", :as(Str));
say "abcb".subst("b", "x", :as(Str), :g);
```
```output
axc
```
```stderr
No such method 'from' for string 'b'. Did you mean 'trim'?
  in block <unit> at example.raku line 2

```

## A replacement block receives the Match

A block given as the replacement is called for each match. A block without
parameters sees the Match as `$_`, and for a regex also as `$/`, so `$0`
works; a block with one parameter gets the Match as its argument. The result
is stringified. A block that wants two arguments dies.

```raku
say "a1b22".subst(/(\d+)/, { "<$0>" }, :g);
say "abc".subst(/b/, *.uc);
say "abc".subst(/b/, -> $m { $m.from });
say "abcb".subst(/b/, { $++ }, :g);
try "abc".subst(/b/, -> $m, $n { "" });
say $!.message;
```
```output
a<1>b<22>
aBc
a1c
a0c1
Too few positionals passed; expected 2 arguments but got 1
```

## With a string needle, `subst` leaves `$/` alone
tags: quirk

After `subst` with a regex, the caller's `$/` holds the Match, Nil when
nothing matched, or the list of matches for `:g`. With a string needle `$/`
is not touched, and inside a replacement block it is whatever it was before,
although `$_` still holds the Match. The documentation says that `$/` is set
in both cases.

```raku
"prior" ~~ /o/;
say "abc".subst("b", { $/.Str });
say "abc".subst("b", { .Str.uc });
say "abc".subst(/b/, { $/.Str.uc });
say $/.raku;
my $r = "xyz".subst("y", "_");
say $/.raku;
```
```output
aoc
aBc
aBc
Match.new(:orig("abc"), :from(1), :pos(2))
Match.new(:orig("abc"), :from(1), :pos(2))
```

The first block sees the `o` of `prior`. The last line shows that the string
needle left the previous `$/` in place.

## `:ii`, `:ss` and `:mm` shape the replacement, not the match

`:ii` (`:samecase`) applies
[`samecase`](#ch:strings:samecase-and-samemark-copy-a-pattern-position-by-position)
to the replacement, with the matched text as the pattern; `:ss`
(`:samespace`) does it word by word and also copies the whitespace; `:mm`
(`:samemark`) copies the marks. On the method they do not change how the regex
matches, so `:ii` with a regex that respects case finds nothing more. In the
`s///` form, `:ii` does imply `:i`.

```raku
say "Hello World".subst(/hello \s world/, "bye bye", :ii);
say "Hello World".subst(/:i hello \s world/, "bye bye", :ii);
say "Hello World".subst(/:i hello \s world/, "bye bye", :ii, :ss);
say "Hello  World".subst(/:i:s hello world/, "bye bye", :ss);
say "über".subst(/:m uber/, "ober", :mm);
my $s = "Hello World";
$s ~~ s:ii/hello \s world/bye bye/;
say $s;
```
```output
Hello World
Bye byE
Bye Bye
bye  bye
öber
Bye byE
```

## `subst-mutate` returns the Match, not the new string
tags: unasserted

`subst-mutate` changes the variable in place and returns what the match
returned: a Match, Nil when there was none, or a list for `:g`. A variable
that held a number becomes a Str, but only when something was replaced.

```raku
my $s = "Some foo";
my $m = $s.subst-mutate(/foo/, "string");
say $s;
say $m.raku;
my $t = "abc";
say $t.subst-mutate("x", "y").raku;
my $n = 123;
$n.subst-mutate(9, "x");
say $n.^name;
$n.subst-mutate(2, "x");
say $n.raku;
```
```output
Some string
Match.new(:orig("Some foo"), :from(5), :pos(8))
Nil
Int
"1x3"
```

## `subst-mutate` accepts `:ov` and `:ex`, and they garble the text
tags: bug unasserted

`subst` refuses `:ov` and `:ex`
([above](#ch:strings:subst-passes-nth-and-x-on-and-refuses-ov-and-ex));
`subst-mutate` lets them through. `:ov` then replaces overlapping matches one
after another in the same text, and `:ex` dies with a message about a
negative length (Rakudo 2026.08). Both were meant to be refused, as in
`subst`.

```raku
my $s = "aaa";
$s.subst-mutate(/aa/, "x", :ov);
say $s;
my $t = "aaa";
try $t.subst-mutate(/a+/, "x", :ex);
say $!.message;
```
```output
xax
Substring length (-3) cannot be negative
```

## `.match` with a negative `:c` matches before the start
tags: bug

`:c` (`:continue`) starts the search at a position and `:p` (`:pos`) anchors
it there. A negative position should be refused or find nothing; instead the
match starts at -1, and its text comes from the other end of the string. A
bare `:c` is documented to continue from where the last match ended, `$/.to`,
but it always starts at 1 (Rakudo 2026.08).

```raku
say "abc".match(/./, :c(-1)).raku;
say "abc".match(/./, :c(-1)).Str;
"abcabc".match(/c/);
say $/.to;
say "abcabc".match(/./, :c).from;
```
```output
Match.new(:orig("abc"), :from(-1), :pos(0))
c
3
1
```

The rest of the matching adverbs are in [Regexes and Grammars](#ch:regexes).

## `trans` maps characters, and a short target string starts over
tags: quirk

`trans` takes Pairs of what to replace and what to put in its place. Two
strings map character to character, and `a..c` inside either is a range. When
the target runs out, a target string starts again from its first character,
while a target list repeats its last element. `:d` deletes the characters that
have no target, and an empty target deletes them all.

```raku
say "abc".trans("ab" => "xyz");
say "abcd".trans("a..c" => "x..z");
say "abcd".trans("a..c" => "xy");
say "abcd".trans(<a b c> => <x y>);
say "abcd".trans("a..c" => "xy", :d);
say "abc".trans("abc" => "").raku;
say "a123b123c".trans('123' => 'þð');
```
```output
xyc
xyzd
xyxd
xyyd
xyd
""
aþðþbþðþc
```

The `..` makes a range only with a character on each side; anywhere else the
dots are dots. A list key is a whole substring, and at each position the
longest key wins. A number is stringified.

```raku
say "a.b".trans("." => "x");
say "a..b".trans("..." => "x");
say "abcd".trans(["ab", "a"] => ["1", "2"]);
say 4200.trans(42 => 14);
```
```output
axb
axxb
1cd
1400
```

## When `trans` keys repeat, the last wins, or the first
tags: quirk

Of two Pairs with the same single-character key, the later one wins. Of two
with the same substring key, the earlier one wins. With any of the adverbs
`:s`, `:c` or `:d`, the earlier one wins for single characters too.

```raku
say "abc".trans("a" => "x", "a" => "y");
say "abcd".trans(["ab"] => ["1"], ["ab"] => ["2"]);
say "abc".trans("a" => "x", "a" => "y", :s);
```
```output
ybc
1cd
xbc
```

## `trans` replaces a regex key's whole match, or calls code

A regex key matches a substring, and its target string replaces the whole
match rather than character by character. A target may be code, called for
each match with the Match in `$/`. `:c` (complement) replaces what the keys do
*not* match, and `:s` (squash) turns a run of identical replacements into one.

```raku
say "a1b2".trans(/\d/ => { $/ * 2 });
say "aXbXc".trans(/X/ => "12");
say "abc".trans("a" => &uc);
say "a11b22".trans(/\d/ => "#", :s);
say "a11b22".trans(/\d/ => "#", :c);
say "aabbcc".trans("ab" => "xx", :s);
```
```output
a2b4
a12b12c
Abc
a#b#
#11#22
xcc
```

The last line squashes across keys: `a` and `b` both become `x`, and the run
of four becomes one.

## `trans` wants Pairs, and `Str => "x"` is not one
tags: undocumented unasserted

Every positional argument of `trans` must be a Pair: a lone string dies with
`X::Str::Trans::InvalidArg`, and a type object inside a list key with
`X::Str::Trans::IllegalKey`. A type object as a target changes nothing, and a
number target is stringified and mapped character by character. A bare word
before `=>` makes a named argument, not a Pair, so `Str => "x"` gives `trans`
nothing to map, and it warns:

```raku
say (try "abc".trans("a")) // $!.^name;
say (try "abc".trans(["a", Any] => "x")) // $!.^name;
say "abc".trans("a" => Any);
say "abc".trans("a" => 1.5);
say "abc".trans(Str => "x");
```
```output
X::Str::Trans::InvalidArg
X::Str::Trans::IllegalKey
abc
1bc
abc
```
```stderr
Unexpected named variable(s) ':Str("x"),' specified with .trans, did
you mean to specify Pair(s)?
  in block <unit> at example.raku line 5
```

## `indent` adds to every line that has a character

`indent(n)` puts *n* spaces before each line, whitespace-only lines included;
only lines that are completely empty are left alone. A line indented with tabs
only gets tabs as far as they go, a tab counting eight columns; a line
indented with one kind of space gets more of it; a mixed indentation gets
spaces after it. The count is converted to an integer.

```raku
say "a\n\nb".indent(2).raku;
say "a\n  \nb".indent(2).raku;
say "\ta".indent(10).raku;
say " \ta".indent(1).raku;
say "a".indent(2.9).raku;
```
```output
"  a\n\n  b"
"  a\n    \n  b"
"\t\t  a"
" \t a"
"  a"
```

## `indent(*)` removes the common indentation, counting tabs as columns

A negative count removes that many columns from each line, and `*` removes as
many as the non-empty lines have in common. A line of nothing but spaces
counts, limits what can be removed from the others, and ends up empty. Tabs
count to the next multiple of eight, and a tab that is partly removed becomes
spaces. Removing more than a line has warns, and removes what there is.

```raku
say "  a\n    b".indent(*).raku;
say "  a\n \n    b".indent(*).raku;
say "\ta".indent(-2).raku;
say "\t\ta".indent(-4).raku;
say "  a\n b".indent(-2).raku;
```
```output
"a\n  b"
" a\n\n   b"
"      a"
"\t    a"
"a\nb"
```
```stderr
Asked to remove 2 spaces, but the shortest indent is 1 spaces
  in block <unit> at example.raku line 5
```

A heredoc line indented less than its terminator gets the same warning
([Quotes and
Interpolation](#ch:quotes:a-heredoc-removes-the-terminators-indentation-from-every-line)).

## `parse-base` reads a string in any base from 2 to 36
tags: quirk

`parse-base` reads digits in either case, a sign (the Unicode minus too) and a
radix point; it accepts no prefix, underscore or whitespace, and `e` is a
digit, not an exponent. A bad base is an `X::Syntax::Number::RadixOutOfRange`
Failure and bad text an `X::Str::Numeric` one. A fraction too fine for a
64-bit denominator comes back as a Num, where numification keeps a Rat.

```raku
say "ff".parse-base(16);
say "-Raku".parse-base(36);
say "1.1".parse-base(2);
say "1e3".parse-base(16);
say "0x10".parse-base(16).exception.message;
say "1".parse-base(37).exception.^name;
my $s = "1.00000000000000000001";
say $s.parse-base(10).raku;
say (+$s).raku;
```
```output
255
-1273422
1.5
483
Cannot convert string to number: malformed base-16 number in '0<HERE>x10' (indicated by <HERE>)
X::Syntax::Number::RadixOutOfRange
1e0
<100000000000000000001/100000000000000000000>
```

Two strings are accepted in place of a base: `"camel"` reads 🐪 and 🐫 as
binary digits, and `"beer"` does the same with 🍺 and 🍻.

```raku
say "🐪🐫🐪".parse-base("camel");
```
```output
2
```

## `:16("…")` understands prefixes, unless the letter is a digit
tags: quirk

The radix call `:16("FF")` reads a string in base 16. It accepts underscores
and a radix point, but no sign. A `0x`, `0o`, `0b` or `0d` prefix switches to
that base, but only when the prefix letter is not a digit of the base: in base
16, `0b1` is the number 0B1. A `:R<…>` inside the string switches too. A
number in place of the string is refused with advice.

```raku
say :16("FF.8");
say :16("0xFF");
say :16("0b1");
say :2("0b101");
say :16(":10<12>");
say (try :16("-FF")) // $!.^name;
try :16(255);
say $!.message;
```
```output
255.5
255
177
5
12
X::Str::Numeric
This call only converts base-16 strings to numbers; value 255 is of type Int, so cannot be converted!
(If you really wanted to convert 255 to a base-16 string, use 255.base(16) instead.)
```

In square brackets the digits are given as numbers, and a digit above the base
is accepted:

```raku
say :16[1, 2, 3];
say :2[1, 2];
say :16[1, ".", 8];
```
```output
291
4
1.5
```

## `.raku` escapes sigils and control characters, but not invisible ones
tags: undocumented unasserted

`.raku` writes a double-quoted literal that evaluates to the same string. It
escapes the characters that would interpolate, `$ @ % & {`, the backslash,
the double quote and every control character; `\e` comes out as `\x[1B]`. A
grapheme that starts with a combining mark is written as code points.
Everything else is printed as it is, including characters that cannot be
seen, such as the no-break space and the zero-width space:

```raku
say "a\0b".raku;
say "\$\@\%\&\{}'".raku;
say "\e\x[85]".raku;
say "\x[301]a".raku;
say "a\x[A0]b".raku.ords;
say "a\x[200B]b".raku.chars;
```
```output
"a\0b"
"\$\@\%\&\{}'"
"\x[1B]\x[85]"
"\x[301]a"
(34 97 160 98 34)
5
```

The last two lines show the no-break space and the zero-width space coming
out as themselves, so that the result reads as `"a b"` and `"ab"`.

## `encode` composes first, and refuses what it cannot encode

`encode` turns the string into bytes, UTF-8 unless an encoding is named. The
text is composed first, so an `e` with a combining accent is the two bytes of
`é`. A character that the encoding lacks is an error, unless `:replacement`
gives something to put in its place, `?` for `True`. The buffers themselves
are in [Blobs and Bufs](#ch:buffers).

```raku
say "e\x[301]".encode.bytes;
say "é".encode("latin-1");
say (try "€".encode("latin-1")) // $!.message;
say "€".encode("latin-1", :replacement);
say "€".encode("ascii", :replacement("EUR"));
say (try "a".encode("utf-32")) // $!.^name;
```
```output
2
Blob[uint8]:0x<E9>
Error encoding Latin-1 string: could not encode codepoint 8364
Blob[uint8]:0x<3F>
Blob[uint8]:0x<45 55 52>
X::Encoding::Unknown
```

## `encode` with an undefined encoding never returns
tags: bug

An undefined encoding name, whether the Str type object or a variable that
was never set, should be refused like an unknown name. Instead `encode` runs
until it is killed (Rakudo 2026.08):

```raku nocheck
my $encoding;
say "abc".encode($encoding);
```

## `fmt` counts graphemes, and its errors have no type
tags: quirk

`fmt` formats the string with a `sprintf` format, `%s` by default. Widths and
precisions count graphemes, and a numeric string satisfies `%d`. Every error
from `fmt` is an `X::AdHoc`, while `sprintf` raises a specific exception for
the same mistake.

```raku
say "é".fmt("[%3s]");
say "abc".fmt("%.1s");
say "42".fmt("%03d");
try "abc".fmt("%d");
say $!.^name, ": ", $!.message;
try sprintf("%d", "abc");
say $!.^name;
```
```output
[  é]
a
042
X::AdHoc: Directive d not applicable for value of type Str
X::Str::Sprintf::Directives::BadType
```

## `.Version`, `.Date` and `.IO` parse strings; one string has a `WHY`
tags: quirk

`.Version` accepts any text, and keeps a leading `v` as a part of its own.
`.Date` and `.DateTime` want the ISO 8601 form, with two-digit months and
days. `.IO` makes a path of anything but the empty string. `.WHY`, which
returns the documentation attached to an object, is Nil for a string, with
one exception.

```raku
say "1.2.3".Version;
say "v1.2".Version.raku;
say "2015-11-24".Date.year;
say (try "2015-1-1".Date) // $!.^name;
say (try "".IO) // $!.message;
say 'Life, the Universe and Everything'.WHY;
say "abc".WHY.raku;
```
```output
v1.2.3
Version.new('v.1.2')
2015
X::Temporal::InvalidFormat
Must specify a non-empty string as a path
42
Nil
```

Dates are the subject of [Dates and Times](#ch:dates), paths of [Files and
Paths](#ch:files).

## `contains` on a list searches the list's text
tags: trap unasserted

`contains`, `index`, `rindex` and `indices` are string methods, and a List or
an Array is turned into a string, its elements joined by spaces, before the
search. `(1, 12).contains(2)` is therefore True. Rakudo warns, and suggests
the list operation that was probably meant:

```raku
say (1, 12).contains(2);
say <a b>.index("b");
```
```output
True
2
```
```stderr
Calling '.contains' on a List, did you mean '$item (elem) @list'?
  in block <unit> at example.raku line 1
Calling '.index' on a List, did you mean '.first( ..., :k)'?
  in block <unit> at example.raku line 2
```

## The Str type object warns, answers empty, or refuses
tags: undocumented quirk

Used as a string or a number, the Str type object is the empty string or 0,
with a warning. The methods that can answer for it do, `chars` with 0 and `uc`
with the empty string; most others have no candidate for a type object and
die. `.Rat` answers 0.0, but `.Int` and `.Num` refuse the type object outright.

```raku
my Str $s;
say $s.chars;
say (try $s.substr(0)) // $!.^name;
say $s.Rat.raku;
say $s.Int;
```
```output
0
X::Multi::NoMatch
0.0
```
```stderr
Use of uninitialized value of type Str in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 2
Use of uninitialized value of type Str in numeric context
  in block <unit> at example.raku line 4
Invocant of method 'Int' must be an object instance of type 'Str', not
a type object of type 'Str'. Did you forget a '.new'?
  in block <unit> at example.raku line 5

```
