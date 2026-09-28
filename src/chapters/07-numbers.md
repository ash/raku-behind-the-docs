---
title: Numbers
part: Nothing and numbers
summary: Four kinds of real number, Int, Rat, FatRat and Num, each with its own rules for combining, printing, comparing, rounding and failing, and a handful of results that look unintended.
---

Raku has four types of real number, and which one a computation produces is
part of its answer. An `Int` is an integer of any size. A `Rat` is an exact
fraction, a numerator over a denominator that fits in 64 bits. A `FatRat` is
the same without the limit. A `Num` is an IEEE 754 double, the floating-point
number of most other languages. Above them all sits `Complex`, which this
chapter touches only where the others turn into it.

A literal with a decimal point, such as `0.1`, is a Rat, and a literal with
an exponent, such as `1e3`, is a Num; the literal syntax is covered in
[Whitespace, Terms and
Blocks](#ch:whitespace:numeric-literals-allow-between-digits-and-e-makes-a-num).
The precedence of the arithmetic operators is in [Who Takes the
Operand](#ch:precedence), and how a string becomes a number, allomorphs such
as `IntStr` included, is in [Strings](#ch:strings). This chapter is about the
numbers themselves: how they combine, print, compare, round and fail.

## The wider type wins: Int, Rat, FatRat, Num, Complex

The numeric types form a ladder. When the two operands of `+`, `-`, `*`, `%`
or `**` have different types, the result takes the type that is higher up.
Two exceptions stand out: `/` between two integers makes a Rat even when the
division is exact, and `div` always makes an Int. A Bool counts as an Int.

```raku
say (1 + 1.0).^name;
say (1.0 + FatRat.new(1, 3)).^name;
say (FatRat.new(1, 3) + 1e0).^name;
say (1e0 + 1i).^name;
say (6 / 3).raku;
say (7.5 div 2).^name;
say (True + True).^name;
```
```output
Rat
FatRat
Num
Complex
2.0
Int
Int
```

`6 / 3` is the Rat `2.0`, not the Int 2; `.narrow`, described
[below](#ch:numbers:narrow-makes-an-int-of-any-num-close-to-one-however-small),
turns such a value back into an Int.

## `1`, `1.0` and `1e0` are equal but not the same value

`==` compares numbers after bringing them to a common type, so an Int, a Rat
and a Num of the same value are equal. `===` and `eqv` also compare the type,
and they tell the three apart. A Rat is always kept in lowest terms, so `1/2`
and `2/4` are one value. A Bool is equal to 0 or 1, but it is its own type.

```raku
say 1 == 1.0 == 1e0;
say 1 === 1.0;
say 1 eqv 1.0;
say 1/2 === 2/4;
say True == 1;
say True === 1;
say (1, 1.0, 1e0).unique.elems;
```
```output
True
False
False
True
True
False
3
```

`unique` compares with `===`, so a list holding 1, 1.0 and 1e0 has three
distinct elements. The same goes for a FatRat and a Rat of equal value: `==`
but never `eqv`.

## `NaN` is identical to itself, and `-0e0` is not identical to `0e0`

The IEEE rules say that NaN is not equal to anything, itself included, and
that the two zeros are equal. `==` follows them. `===` and `eqv` compare
values as objects, and turn both rules round: a NaN is the same value as
another NaN, and the negative zero is a different value from the positive
one.

```raku
say NaN == NaN;
say NaN === NaN;
say NaN eqv NaN;
say 0e0 == -0e0;
say 0e0 === -0e0;
say (0e0, -0e0).unique.elems;
```
```output
False
True
True
True
False
2
```

A Rat with a zero denominator behaves like NaN when it is `<0/0>`: never
`==` to itself, but `===` to itself. A non-zero numerator over zero is
stored as 1 or -1, so `<2/0>` and `<1/0>` are the same value.

```raku
say <0/0> == <0/0>;
say <0/0> === <0/0>;
say <2/0>.raku;
say <2/0> === <1/0>;
```
```output
False
True
<1/0>
True
```

## Smartmatching against a number compares numerically

When the right side of `~~` is a number, the topic is converted with
`.Numeric` and compared with `==`, except that two NaNs match. A string
that does not read as a number simply does not match; there is no error.
When the right side is a string, the comparison is between strings instead,
and a type object on the left never matches a number.

```raku
say "1" ~~ 1;
say " 1.0 " ~~ 1;
say "abc" ~~ 1;
say NaN ~~ NaN;
say 1 ~~ "1.0";
say Int ~~ 1;
```
```output
True
True
False
True
False
False
```

## Zero is false in every numeric type, and NaN is true

A number is false when it is zero, whatever its type, the negative zero
included. NaN is not zero, so it is true. A Rat is judged by its numerator
alone, which makes `<0/0>` false even though the same value converted to a
Num, NaN, is true.

```raku
say so 0.0;
say so -0e0;
say so NaN;
say so <0/0>;
say so <0/0>.Num;
say so <1/0>;
say so 1e-320;
```
```output
False
False
True
False
True
True
True
```

The string `"0"` is true, because only the empty string is false; how
strings and allomorphs such as `<0>` decide their truth is covered in
[Strings](#ch:strings).

## A whole Num prints like an Int
tags: trap

`say` prints a Num as the shortest decimal that reads back as the same
double. A whole value prints without a decimal point, so `1e0` looks exactly
like the Int 1. Plain digits are used from 0.0001 up to just below 1e16;
outside that range the number gets an exponent with at least two digits.

```raku
say 1e0;
say 100e0;
say 1e15;
say 1e16;
say 0.0001e0;
say 0.00001e0;
say 0.1e0 + 0.2e0;
```
```output
1
100
1000000000000000
1e+16
0.0001
1e-05
0.30000000000000004
```

`.raku` always shows that the value is a Num: it appends `e0` unless an
exponent is already there. The negative zero prints as `-0`.

```raku
say 1e0.raku;
say 1e20.raku;
say 2.5e-3.raku;
say (-0e0).raku, " ", -0e0;
```
```output
1e0
1e+20
0.0025e0
-0e0 -0
```

## A Rat prints at most six decimals, but `.raku` is exact
tags: trap

The printed form of a Rat is rounded. A denominator below 100,000 gets six
digits after the point; a larger one gets one digit more than it has itself.
Trailing zeros are dropped, and the rounding applies even when the decimal
would end a little later, as for 1/1024. A value that rounds to a whole
number prints as that number.

```raku
say 1/3;
say 2/3;
say 1/1024;
say 1/3000000;
say 0.9999999999999999999999;
```
```output
0.333333
0.666667
0.000977
0.00000033
1
```

`.raku` never rounds. It writes the decimal when the denominator has no
prime factors but 2 and 5, and the fraction in angle brackets otherwise; a
whole Rat keeps its `.0`, and a FatRat names its type.

```raku
say (1/3).raku;
say (1/1024).raku;
say (3/1).raku;
say 0.9999999999999999999999.raku;
say FatRat.new(1, 3).raku;
```
```output
<1/3>
0.0009765625
3.0
<9999999999999999999999/10000000000000000000000>
FatRat.new(1, 3)
```

## `1/0` is a Rat, and it fails only when printed
tags: trap

Dividing an Int by zero does not fail: it makes a Rat with a zero
denominator, and that value takes part in arithmetic like any other. Only
turning it into a string, which is what `say` does, throws
`X::Numeric::DivideByZero`. `.raku` shows it safely.

```raku
my $r = 1 / 0;
say $r.^name;
say $r.raku;
say ($r + 1).raku;
say ($r * 0).raku;
say $r;
```
```output
Rat
<1/0>
<1/0>
<0/0>
```
```stderr
Attempt to divide 1 by zero when coercing Rational to Str
  in block <unit> at example.raku line 6

```

Rounding it fails too: `.floor`, `.ceiling`, `.round`, `.truncate` and
`.Int` on a zero-denominator Rat return a Failure.

## Rat arithmetic is exact until the denominator needs 64 bits
tags: trap

`0.1 + 0.2 == 0.3` holds in Raku, because both sides are exact fractions.
The exactness has a limit: a Rat's denominator must fit in 64 bits, and an
operation whose reduced result needs more gives a Num instead. A sum of many
fractions reaches the limit sooner than it seems.

```raku
say 0.1 + 0.2 == 0.3;
say (1/3 + 1/3 + 1/3).raku;
say (1 / 2**63).^name;
say (1 / 2**64).^name;
my $sum = 0;
$sum += 1 / $_ ** 2 for 1..100;
say $sum.^name;
```
```output
True
1.0
Rat
Num
Num
```

Nothing warns when this happens. A program that must stay exact uses FatRat,
or sets `$*RAT-OVERFLOW`, the subject of the next corner.

## `$*RAT-OVERFLOW` decides what an overflowing Rat becomes

The dynamic variable `$*RAT-OVERFLOW` holds what to do with a result whose
denominator does not fit. Its default is `Num`. `FatRat` keeps the value
exact, `Failure` returns a Failure, `Exception` throws, and `CX::Warn` warns
and then gives a Num.

```raku
my $d = 2 ** 64;
{
    my $*RAT-OVERFLOW = FatRat;
    say (1 / $d).^name;
}
{
    my $*RAT-OVERFLOW = Exception;
    try 1 / $d;
    say $!.message;
}
{
    my $*RAT-OVERFLOW = CX::Warn;
    say (1 / $d).^name;
}
```
```output
FatRat
Upgrading of Rat 1 / 18446744073709551616 not allowed
Num
```
```stderr
Downgrading Rat 1 / 18446744073709551616 to Num
  in block  at example.raku line 13
```

## `$*RAT-OVERFLOW` does not reach a division of literals
tags: trap

Rakudo computes an operation on literals while it compiles the program, and
the dynamic variable has no value yet at that point. `1 / 2**64` is
therefore turned into a Num with the default rule, however `$*RAT-OVERFLOW`
is set when the line runs. The same division with a variable happens at run
time and obeys it. So, as it happens, does a division of literals that is
the operand of `try`, which makes a variable the only dependable way.

```raku
my $*RAT-OVERFLOW = FatRat;
say (1 / 2**64).^name;
my $d = 2**64;
say (1 / $d).^name;
```
```output
Num
FatRat
```

## A FatRat never degrades, and beats a Rat

A FatRat has no limit on its denominator, and it is higher on the ladder than
a Rat: combining the two gives a FatRat, and every result stays a FatRat,
however large its denominator grows. Only a Num or a Complex operand turns it
into something else. Converting back with `.Rat` fails when the denominator
does not fit.

```raku
my $third = FatRat.new(1, 3);
say ($third + 1/3).^name;
say ($third * 3).raku;
say ($third ** 100).^name;
say ($third + 0.5e0).^name;
say FatRat.new(1, 5).Rat.^name;
say FatRat.new(1, 2**100).Rat.^name;
```
```output
FatRat
FatRat.new(1, 1)
FatRat
Num
Rat
Failure
```

## `Rat.new` reduces, moves the sign up and takes only Ints

`Rat.new(n, d)` stores the fraction in lowest terms, with the sign on the
numerator and a zero denominator normalised as described
[above](#ch:numbers:nan-is-identical-to-itself-and-0e0-is-not-identical-to-0e0).
Without arguments it is 0. Both parts must be Ints; a Rat or a Num as a part
is a type error, not a conversion.

```raku
say Rat.new(2, 4).nude;
say Rat.new(1, -2).nude;
say Rat.new(-6, 0).nude;
say Rat.new.raku;
try Rat.new(1.5, 2);
say $!.^name;
```
```output
(1 2)
(-1 2)
(-1 0)
0.0
X::TypeCheck::Binding::Parameter
```

`Rat.new` accepts a denominator of more than 64 bits, which no arithmetic
would produce. The result is a Rat and prints its full value, but the first
operation on it makes a Num:

```raku
my $tiny = Rat.new(1, 2**65);
say $tiny.^name;
say $tiny;
say ($tiny + 0).^name;
```
```output
Rat
0.000000000000000000027
Num
```

## `.Int` truncates a Num exactly; `.Rat` only approximates it
tags: trap

`.Int`, and `Int.new` with an argument, drop the fraction towards zero, and
for a Num the result is exact at any size: `1e300.Int` has all 301 digits of
the double's value. Inf and NaN cannot be integers, and give a Failure.

```raku
say 1e20.Int;
say (-1.5e0).Int;
say 1e300.Int.chars;
say Int.new(4.7);
my $inf = Inf;
say $inf.Int.^name;
```
```output
100000000000000000000
-1
301
4
Failure
```

`.Rat` on a Num does not give the double's exact value. It looks for a
simple fraction within a tolerance, one millionth by default, so `pi.Rat`
is 355/113 and a number smaller than the tolerance becomes zero. An explicit
argument sets the tolerance, and 0 asks for the exact value.

```raku
say pi.Rat.raku;
say 0.1e0.Rat.raku;
say 1e-7.Rat.raku;
say 1e-7.Rat(1e-9).raku;
say pi.Rat(0).raku;
```
```output
<355/113>
0.1
0.0
0.0000001
<245850922/78256779>
```

## An undefined number dies in arithmetic, but only warns under `+`
tags: trap

A numeric type object, or a variable such as `my Int $n` that has not been
assigned, is not treated as zero by the arithmetic operators. Every
arithmetic operator and every numeric comparison throws
`X::Numeric::Uninitialized`, whichever side the undefined value is on. The
prefix operators `+` and `-`, and `.Numeric`, are gentler: they warn and give
0. Because the exception's message is the same sentence as the warning, the
difference is easy to miss: only the first message below is a warning, and
the second one ends the program.

```raku
my Int $n;
say +$n;
say $n.Bool;
say $n + 1;
```
```output
0
False
```
```stderr
Use of uninitialized value of type Int in numeric context
  in block <unit> at example.raku line 2
Use of uninitialized value of type Int in numeric context
  in block <unit> at example.raku line 4

```

Methods declared only for defined numbers, such as `.abs`, `.floor` and
`.Rat`, refuse the type object with `X::Parameter::InvalidConcreteness`.
`cmp` does not throw: it compares the type object as an empty string, with a
string-context warning. And the assignment forms start an undefined variable
from the operator's identity, so `+=` counts from 0 and `*=` from 1.

```raku
my Int $n;
try $n * 2;
say $!.^name;
try $n.abs;
say $!.^name;
say $n cmp -1;
my Int $sum;
$sum += 5;
my Int $product;
$product *= 5;
say "$sum $product";
```
```output
X::Numeric::Uninitialized
X::Parameter::InvalidConcreteness
Less
5 5
```
```stderr
Use of uninitialized value $n of type Int in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 6
```

Numerically, 0 would be `More` than -1; the `Less` comes from comparing `""`
with `"-1"`. `Nil` and `Any` are different again: [in arithmetic they count
as 0 with a
warning](#ch:nil-any:nil-is-0-in-arithmetic-and-empty-in-a-string-with-a-warning).
And `max` and `min` [skip an undefined operand
altogether](#ch:nil-any:min-and-max-let-an-undefined-operand-lose), the type
object of a number included.

## A string that is not a number makes arithmetic return a Failure

Arithmetic on a string first converts it to a number, by the rules in
[Strings](#ch:strings). When the conversion fails, the operator does not
throw: it returns a Failure, a value that carries the exception and throws it
when it is used. The error then surfaces far from its cause, and the message
says where each happened.

```raku
my $s = "abc";
my $x = $s + 3;
say "still running";
say $x * 2;
```
```output
still running
```
```stderr
Cannot convert string to number: base-10 number must begin with valid digits or '.' in '<HERE>abc' (indicated by <HERE>)
  in block <unit> at example.raku line 2

Actually thrown at:
  in block <unit> at example.raku line 4

```

The comparison operators return a Failure too, and a Failure is false when
tested, which handles it. So `"abc" == 3` is false, and `"abc" != 3`, which
negates it, is true. `div` is the exception: it throws at once.

```raku
my $s = "abc";
say ($s == 3).^name;
say so $s == 3;
say $s != 3;
try $s div 3;
say $!.^name;
```
```output
Failure
False
True
X::AdHoc
```

## `try` catches the Failure from `+`, but not the one from `==`
tags: trap

`try` turns on the `use fatal` pragma, which makes a Failure returned by a
call throw at once, so the `try` catches it and sets `$!`. A comparison
operator slips through: its Failure becomes the value of the `try`, and `$!`
stays empty. The same comparison inside a sub is caught.

```raku
my $s = "abc";
my $sum = try $s + 1;
say $!.^name;
my $same = try $s == 1;
say $!.defined;
say $same.^name;
sub same { $s == 1 }
my $wrapped = try same;
say $!.^name;
```
```output
X::Str::Numeric
False
Failure
X::Str::Numeric
```

## `div` rounds down and `%` takes the sign of the divisor

`div` is integer division that rounds towards negative infinity, not towards
zero. `%` and `mod` give the matching remainder, which has the sign of the
divisor, so that for integers `x == y * (x div y) + x % y` always holds. `%`
works on any real numbers and keeps their type; `%%` asks whether the
remainder is zero.

```raku
say 7 div 2, " ", -7 div 2, " ", 7 div -2;
say 7 % 2, " ", -7 % 2, " ", 7 % -2;
say -7 mod 2, " ", 7 mod -2;
say 5.5 % 2, " ", -5.5 % 2;
say (5.5 % 2).^name, " ", (5.5e0 % 2).^name;
say 7 %% 2, " ", 8 %% 2;
```
```output
3 -4 -4
1 1 -1
1 -1
1.5 0.5
Rat Num
False True
```

## Dividing by zero gives a Rat, a Failure or an exception

What a division by zero does depends on the operator. `/` on Ints or Rats
makes a zero-denominator Rat, as shown
[above](#ch:numbers:10-is-a-rat-and-it-fails-only-when-printed). `div`, `%`,
`%%` and `/` with a Num return a Failure. `mod` throws at once, and its
message names `div`.

```raku
my $zero = 0;
say (7 / $zero).raku;
say (7 div $zero).exception.message;
say (7 % $zero).exception.message;
say (7 %% $zero).exception.message;
say (7e0 / $zero).exception.message;
try 7 mod $zero;
say $!.message;
```
```output
<1/0>
Attempt to divide 7 by zero using div
Attempt to divide 7 by zero using %
Attempt to divide 7 by zero using infix:<%%>
Attempt to divide 7 by zero using /
Attempt to divide 7 by zero using div
```

A Num divided by zero is a Failure, not the infinity that IEEE 754 would
give. Native integers, [further down](#ch:numbers:native-integers-wrap-around-and-a-64-bit-one-refuses-a-big-int),
have their own behaviour.

## `7 mod 2.5` is -0.5
tags: bug

The documentation declares `mod` and `div` for Ints only, and gives `mod` the
signature `(Int:D $a, Int:D $b --> Int:D)`. Rakudo 2026.08 accepts a Rat
divisor all the same, truncates it to an Int for the quotient, and uses the
full value to compute the remainder. `7 mod 2.5` is then
`7 - (7 div 2) * 2.5`, which is -0.5: a Rat, where the signature promises an
Int, with the opposite sign to the divisor, and not what `%` gives. A divisor
below 1 truncates to zero.

```raku
say 7 div 2.5;
say 7 mod 2.5;
say 7 % 2.5;
try 7 div 0.5;
say $!.message;
```
```output
3
-0.5
2
Attempt to divide 7 by zero using div
```

`%` is the operator for fractional divisors.

## `gcd` and `lcm` truncate to Int, and zero is special

`gcd` and `lcm` convert their operands to Int first, dropping any fraction,
and always return a non-negative Int. The greatest common divisor of 0 and 0
is 0, and the least common multiple of anything and 0 is 0.

```raku
say 3.5 gcd 2;
say -4 gcd 6;
say 0 gcd 0;
say 4 lcm 6, " ", -4 lcm 6;
say 4 lcm 0;
```
```output
1
2
0
12 12
0
```

## `**` stays exact with an Int exponent

An Int raised to an Int is an exact Int, of any size. A negative exponent
gives an exact Rat, so `0 ** -1` is the zero-denominator Rat rather than an
error. A Rat base with an Int exponent stays a Rat. Any other exponent makes
the result a Num, which is why `(-8) ** (1/3)` is NaN and not -2.

```raku
say (2 ** 10).^name;
say (2 ** -2).raku;
say ((2/3) ** -3).raku;
say (0 ** -1).raku;
say 0 ** 0;
say (4 ** 0.5).raku;
say (-8) ** (1/3);
```
```output
Int
0.25
3.375
<1/0>
1
2e0
NaN
```

Powers of the special values follow IEEE 754, where 1 raised to anything,
and anything raised to 0, is 1, even when NaN is involved:

```raku
say 1 ** NaN;
say NaN ** 0;
say 1 ** Inf;
say (-1) ** Inf;
say 0.9 ** Inf;
```
```output
1
1
1
1
0
```

## A power too large or too small is a Failure, except `** 2`
tags: quirk

An exact power that would need an enormous number of digits is not
computed: it returns a Failure of `X::Numeric::Overflow`, or of
`X::Numeric::Underflow` for a Rat whose denominator cannot be formed. A Num
power that comes out as zero from a non-zero base is also an Underflow
Failure. The exception is a literal exponent of 2: `$x ** 2` gives what
`$x * $x` gives, a plain `0e0`, while the same power with the 2 in a
variable fails.

```raku
my $big = 2 ** 2 ** 40;
say $big.exception.^name;
my $small = 2 ** -(10 ** 10);
say $small.exception.^name;
my $x = 1e-300;
my $two = 2;
say ($x ** $two).exception.^name;
say ($x ** 2).raku;
```
```output
X::Numeric::Overflow
X::Numeric::Underflow
X::Numeric::Underflow
0e0
```

## `Inf ** -1` is an underflow, not zero
tags: bug

IEEE 754 says that infinity to a negative power is zero, and Rakudo agrees
that `1 / Inf` is `0e0`. The power operator counts the zero as an underflow
from a non-zero base, though, and Rakudo 2026.08 returns a Failure for any
negative power of Inf. The same operator gives a plain zero for the mirror
case, a fraction raised to Inf: `0.9 ** Inf` is 0, as shown
[above](#ch:numbers:stays-exact-with-an-int-exponent).

```raku
say (1 / Inf).raku;
say (Inf ** -1).^name;
say (Inf ** -1).exception.^name;
say (Inf ** -2e0).exception.^name;
```
```output
0e0
Failure
X::Numeric::Underflow
X::Numeric::Underflow
```

## A negative base to a negative power puts the sign on the denominator
tags: bug

The documentation of `Rational` says that since 6.d a Rat is normalised when
it is created, and that a normalised Rat has a positive denominator; the sign
lives on the numerator, and comparisons rely on that. `(-2) ** -3` in Rakudo
2026.08 produces a Rat whose sign is on the denominator instead. It is not
equal to -0.125, it is not below zero, and it prints as -1.875. Any
arithmetic on it normalises it again, to `<-1/8>`.

```raku
my $x = (-2) ** -3;
say $x.raku;
say $x.nude;
say $x == -0.125;
say $x < 0;
say $x;
say $x + 0;
```
```output
<1/-8>
(1 -8)
False
False
-1.875
-0.125
```

## Superscript digits are the `**` operator

A number written with superscript digits after a term is a power, with the
same precedence as `**`, so it binds tighter than a prefix minus. A
superscript minus makes the exponent negative. The other direction exists as
well: `.Str` with `:superscript` or `:subscript` writes an Int's digits that
way.

```raku
say 3⁴;
say -2²;
say 2⁻¹;
say (-1)¹²³;
say 10¹⁰⁰.chars;
say 42.Str(:superscript);
say (-42).Str(:subscript);
```
```output
81
-4
0.5
-1
101
⁴²
₋₄₂
```

## `round` sends halves towards positive infinity
tags: quirk

`round` adds one half and takes the floor. Halves therefore go up, towards
positive infinity, for every type: 2.5 becomes 3, but -2.5 becomes -2. That
is neither rounding away from zero, as C's `round` does, nor rounding to
even, the IEEE 754 default. The largest double below one half rounds to 1,
because adding 0.5 to it already gives 1.0 in binary.

```raku
say 2.5.round, " ", 3.5.round;
say (-2.5).round, " ", (-3.5).round;
say (-0.5e0).round;
say 0.49999999999999994e0.round;
```
```output
3 4
-2 -3
0
1
```

## `floor` and friends return an Int; `round` with a scale may not

`floor`, `ceiling`, `round` and `truncate` return an Int for a Rat or a Num,
exact at any size. Inf and NaN have no integer, and they pass through as
Nums; a zero-denominator Rat gives a Failure.

```raku
say 1.5e0.floor.^name;
say 1.5e300.floor.chars;
say (-1.5).floor, " ", (-1.5).ceiling, " ", (-1.5).truncate;
say Inf.round.raku, " ", NaN.floor.raku;
say <1/0>.floor.^name;
```
```output
Int
301
-2 -1 -1
Inf NaN
Failure
```

`round($scale)` rounds to a multiple of the scale by ordinary arithmetic, so
the type of the result is whatever that arithmetic produces: an Int for an
Int scale, a Rat for a Rat scale, a Num for a Num. A scale of zero is a
division by zero, and a string is converted first.

```raku
say 1234.round(100), " ", 1234.round(100).^name;
say pi.round(0.001), " ", pi.round(0.001).^name;
say 42.round(10e0).^name;
say "17.25".round("0.1");
try 5.round(0);
say $!.^name;
```
```output
1200 Int
3.142 Rat
Num
17.3
X::Numeric::DivideByZero
```

## `sign` is an Int, and `succ` adds one in the value's own type

`sign` returns the Int -1, 0 or 1 for any real number, Inf and the negative
zero included; only NaN gives NaN. `abs` keeps the type. `succ` and `pred`
add or subtract one without changing the type, so a Rat keeps its
denominator. A Num of 2**53 or more cannot move by one, and `True.succ`
stays `True`.

```raku
say (-2.5).sign.^name, " ", Inf.sign, " ", (-0e0).sign;
say NaN.sign;
say (-1.5e0).abs.raku;
say (1/3).succ.raku;
say 1e0.succ.raku;
say (2**53).Num.succ == 2**53;
say True.succ;
```
```output
Int 1 0
NaN
1.5e0
<4/3>
2e0
True
True
```

## An Int compared with a Num is compared as a Num
tags: trap

Comparisons between Ints, Rats and FatRats are exact. As soon as one side is
a Num, both are compared as doubles, and a double cannot tell apart integers
beyond 2**53 or represent most fractions. Two different numbers can then be
equal, and an exact Rat stops being exact when a Num joins the sum.

```raku
say 2**70 + 1 == 2e0 ** 70;
say 2**70 + 1 == 2**70;
say 9007199254740993 == 9007199254740992e0;
say 1/3 == (1/3).Num;
say 0.1 + 0.2e0 == 0.3;
say 1/3 < 1/3 + FatRat.new(1, 10**30);
```
```output
True
False
True
True
False
True
```

## NaN is unequal to everything, and `<=>` with it is Nil

Every numeric comparison with NaN is false, except `!=`. `<=>` cannot say
which side is larger and returns `Nil`. `cmp` must put everything in some
order, so it treats NaN as larger than every number, Inf included, and a sort
puts it last.

```raku
say NaN == NaN, " ", NaN != NaN;
say NaN < 1, " ", NaN > 1;
say (NaN <=> 1).raku;
say NaN cmp 1;
say (1, NaN, 0, Inf, -Inf).sort;
```
```output
False True
False False
Nil
More
(-Inf 0 1 Inf NaN)
```

## `cmp` compares a number with a string as two strings
tags: trap

`cmp` compares numerically only when both sides are numbers; an allomorph
such as `<10>` counts as one. With a string on either side it compares
strings, so 10 comes before "9". `<=>` always converts both sides to numbers.
A sort of mixed numbers and strings uses `cmp`, and orders them as text.

```raku
say 10 cmp "9";
say 10 <=> "9";
say <10> cmp 9;
say (3, "10", 2).sort;
say 1.0 cmp 1;
say Inf cmp "abc", " ", -Inf cmp "abc";
```
```output
Less
More
More
(10 2 3)
Same
More Less
```

Infinity is the one exception: it is larger than any string, and minus
infinity smaller. `leg` always compares strings; string comparison itself is
in [Strings](#ch:strings).

## `=~=` is relative to the larger operand, and absolute at zero

`=~=`, also written `≅`, is true when two numbers differ by less than
`$*TOLERANCE`, 1e-15 by default, times the larger of their magnitudes. When
one side is zero there is nothing to scale by, and the difference itself is
compared with the tolerance. Two infinities are approximately equal; NaN is
not approximately anything.

```raku
say 1 =~= 1 + 1e-16;
say 1e10 =~= 1e10 + 1;
say 1e10 =~= 1e10 + 1e-6;
say 0 =~= 1e-16;
say 1e-20 =~= 2e-20;
say Inf =~= Inf, " ", NaN =~= NaN;
say $*TOLERANCE;
```
```output
True
False
True
True
False
True False
1e-15
```

Being dynamic, the tolerance can be changed for a block and everything it
calls:

```raku
{
    my $*TOLERANCE = 0.1;
    say 100 =~= 109;
}
say 100 =~= 109;
```
```output
True
False
```

## An Order is a number, and `.Order` looks only at the integer part

`<=>` and `cmp` return an `Order`: `Less`, `Same` or `More`. The three are
the numbers -1, 0 and 1 in disguise, and arithmetic on them works. Lists
compare element by element. `.Order` on a number converts it to an Int
first, so any value strictly between -1 and 1 is `Same`.

```raku
say Less == -1, " ", Same == 0, " ", More == 1;
say (1 <=> 2) + 1;
say (1 <=> 2).^name;
say (1, 10) cmp (1, 9);
say 2.5.Order, " ", (-0.5).Order, " ", (-1.5).Order;
```
```output
True True True
0
Order
More
More Same Less
```

`Inf.Order` and `NaN.Order` return a Failure, since neither has an integer
part, and an Int beyond 63 bits makes `.Order` die with `X::AdHoc`.

## A reduction over one operand returns it unchanged
tags: undocumented

[An empty reduction](#ch:precedence:an-empty-reduction-answers-the-operators-identity)
answers the operator's identity: that includes -1 for `+&` and minus infinity
for `max`. With a single operand, a reduction does not apply the operator at
all. `[-] 5` is 5, not -5, and `[/] 5` is 5; the operand only goes through
`.Numeric`. A chain such as `[%%]` is true. `div` and `mod` have no
one-operand form and die.

```raku
say [-] 5;
say [/] 5;
say ([+] "5").^name;
say [%%] 5;
say [+&] ();
say [max] ();
try [div] 5;
say $!.message;
```
```output
5
5
Int
True
-1
-Inf
Too few positionals passed; expected 2 arguments but got 1
```

A Range among several operands is one operand, not a list of them: in
`[+] 1..3, 4`, the Range plus 4 is a shifted Range, as
[Ranges](#ch:ranges) explains.

```raku
say [+] 1..3;
say ([+] 1..3, 4).raku;
```
```output
6
5..7
```

## `[lcm] ()` dies of an ambiguous call
tags: bug undocumented

The documentation says that, in general, an infix operator can be reduced
over no elements without an error. Every other numeric reduction over nothing
either answers an identity or returns a Failure of `X::NoZeroArgMeaning`, as
`[gcd] ()` does. `lcm` has two candidates that accept no arguments, and
Rakudo 2026.08 cannot choose between them: the call dies, with a message that
points into Rakudo's own setting.

```raku
say [gcd] 12, 18;
say [lcm] 4, 6, 10;
say [lcm] ();
```
```output
6
60
```
```stderr
Ambiguous call to 'infix:<lcm>(...)'; these signatures all match:
  () from SETTING::src/core.c/Numeric.rakumod line 265
  () from SETTING::src/core.c/Int.rakumod line 421
  in block <unit> at example.raku line 3

```

## Of two equal values, `max` keeps the second; of more, the first
tags: undocumented

`max` and `min` return one of their operands unchanged, so the type of the
result shows which one was chosen. When exactly two operands are equal, the
infix returns the right one, and so does a reduction over two values. With
three or more operands, and in the sub and the method forms, the first of
the equal values wins.

```raku
say (1 max 1.0).raku;
say ([max] 1, 1.0).raku;
say (1 max 1.0 max 1e0).raku;
say ([max] 1, 1.0, 1e0).raku;
say max(1, 1.0).raku;
say (1, 1.0).max.raku;
```
```output
1.0
1.0
1
1
1
1
```

## Bitwise operators see an Int as endless two's complement

`+&`, `+|`, `+^` and the shifts `+<` and `+>` treat an Int of any size as if
it were written in two's complement with infinitely many sign bits. A
negative number therefore has ones all the way up, and a right shift of a
negative number never gets past -1. Operands that are not Ints are truncated
first, and strings are converted.

```raku
say -1 +& 0xFF;
say +^0, " ", +^5;
say -7 +> 1;
say -123 +> 1000;
say +^(2**70);
say 3.7 +& 1, " ", "6" +| "9";
```
```output
255
-1 -6
-4
-1
-1180591620717411303425
1 15
```

`lsb` and `msb` give the position of the lowest and highest set bit, and
`Nil` for 0. For a negative number they read the same two's complement form,
and `msb` is the position where the endless run of ones begins.

```raku
say 12.lsb, " ", 12.msb;
say 0.msb.raku;
say (-1).msb, " ", (-2).msb, " ", (-256).msb;
say (-8).lsb;
```
```output
2 3
Nil
0 1 8
3
```

An Inf or NaN operand is `X::Numeric::CannotConvert`, and a shift count too
large for a native integer dies with `X::AdHoc`.

## A left shift by a negative count past -63 wraps around
tags: bug

`5 +< -1` shifts right, and `5 +> -1` shifts left: a negative count reverses
the direction, and Roast (`S03-operators/numeric-shift.t`) asserts that
`$a +< -$b` equals `$a +> $b`. For an Int that fits in 64 bits, Rakudo
2026.08 takes a negative count for `+<` modulo 64, so `+< -64` shifts nothing
and `+< -65` shifts right by one place. A right shift by the same positive
amount gives 0, and a larger Int shifts as far as the count says.

```raku
say 5 +< -1;
say 5 +> -1;
say 1024 +< -63;
say 1024 +< -64;
say 1024 +< -65;
say 1024 +> 65;
say (2**100) +< -65;
```
```output
2
10
0
1024
512
0
34359738368
```

## `Inf - Inf` is NaN, and the negative zero keeps its sign
tags: quirk

Arithmetic on Inf and NaN follows IEEE 754: `Inf - Inf` and `Inf * 0` are
NaN, and dividing a negative number by Inf gives the negative zero. That
value prints as `-0`, is `==` to 0 and has sign 0, but it keeps its sign
through multiplication. `**` does not keep it: Rakudo turns a zero result of
a power into the positive zero, where IEEE 754 says `(-0e0) ** 3` is `-0e0`.

```raku
say Inf - Inf, " ", Inf * 0;
say (-1 / Inf).raku;
my $nz = -0e0;
say $nz, " ", $nz == 0, " ", $nz.sign;
say ($nz * $nz * $nz).raku;
say ($nz ** 3).raku;
say (1e0 / $nz).exception.message;
```
```output
NaN NaN
-0e0
-0 True 0
-0e0
0e0
Attempt to divide 1 by zero using /
```

The last line shows that dividing by the negative zero is a Failure, like
[any Num division by zero](#ch:numbers:dividing-by-zero-gives-a-rat-a-failure-or-an-exception),
rather than minus infinity. NaN and Inf convert to the zero-denominator
Rats: `NaN.Rat` is `<0/0>` and `Inf.Rat` is `<1/0>`.

## `narrow` makes an Int of any Num close to one, however small
tags: bug

The documentation says that `narrow` converts a number to the narrowest type
that can hold it "without loss of precision": an Int for a whole Rat or Num,
the value unchanged otherwise. For a Num, Rakudo 2026.08 decides "whole" with
the approximate comparison `=~=`, which keeps
`((0.1e0 + 0.2e0) * 10).narrow` from being a Num. But `=~=` compares
absolutely when one side is zero, so every Num below 1e-15 is taken for 0,
and a value near a large integer is taken for that integer. `1e-300.narrow`
is then 0, which keeps nothing of the value.

```raku
say (4/2).narrow.raku;
say 4.5e0.narrow.raku;
say ((0.1e0 + 0.2e0) * 10).narrow.raku;
say 4.000000000000001e0.narrow.raku;
say 1e-14.narrow.raku;
say 1e-300.narrow.raku;
say (1 / 2**64).narrow.raku;
```
```output
2
4.5e0
3
4
1e-14
0
0
```

## `base` rounds its last digit, and `*` asks for every digit

`.base($radix)` writes a number in any radix from 2 to 36, with capital
letters for digits above 9. An Int gets no fraction unless a digit count is
given. A Rat gets six fraction digits by default, more for a large
denominator; an explicit count pads with zeros unless `:no-trailing-zeroes`
is given, and the last digit is always rounded. A radix outside 2..36 is a
Failure.

```raku
say 255.base(16), " ", (-255).base(16);
say 255.base(16, 2);
say (1/3).base(10);
say (2/3).base(10, 2);
say (1/128).base(10, *);
say (1/2).base(10, 3, :no-trailing-zeroes);
say 255.base(37).exception.message;
```
```output
FF -FF
FF.00
0.333333
0.67
0.0078125
0.5
base argument to base out of range. Is: 37, should be in 2..36
```

`*` as the digit count means all the digits, and for a fraction that never
ends, such as 1/3 in base 10 or 1/10 in base 2, the call does not return:

```raku nocheck
say (1/3).base(10, *);
```

`.base-repeating` is the safe alternative for a Rat. It returns two strings:
the digits before the repetition starts, and the repeating cycle, which is
empty for a fraction that ends.

```raku
say (19/3).base-repeating.raku;
say (1/7).base-repeating.raku;
say (5/2).base-repeating.raku;
say (1/3).base-repeating(2).raku;
```
```output
("6.", "3")
("0.", "142857")
("2.5", "")
("0.", "01")
```

## `base` also counts in camels
tags: undocumented

Besides a number, `.base` accepts two words. `"camel"` writes the number in
binary with a two-humped camel for 1 and a one-humped camel for 0; `"beer"`
uses a pair of mugs for 1 and a single mug for 0. Any other string is
converted to a number, so `255.base("16")` is `FF` and `255.base("foo")`
fails with `X::Str::Numeric`.

```raku
say 5.base(2);
say 5.base("camel");
say 5.base("beer");
```
```output
101
🐫🐪🐫
🍻🍺🍻
```

## `is-prime` and `expmod` accept whole numbers of any type

`is-prime` asks whether the value is a whole prime, so a Num or Rat that is
a whole number works, a fraction is simply not prime, and a string is
converted. Negative numbers, 0 and 1 are not prime. `expmod` computes a
power modulo a number, and accepts a negative exponent when the modular
inverse exists; when it does not, the error comes straight from the
big-integer library.

```raku
say 2e0.is-prime, " ", 2.0.is-prime, " ", 2.5.is-prime;
say "7".is-prime, " ", (-7).is-prime;
say (2**61 - 1).is-prime;
say 7.expmod(-2, 5);
try 42.expmod(-1, 7);
say $!.message;
```
```output
True True False
True False
True
4
Error in mp_exptmod: Value out of range
```

## `polymod` stops at a divisor of 1 or less

`polymod` divides by each divisor in turn and returns the remainders, and
finally what is left: `3661.polymod(60, 60)` splits seconds into seconds,
minutes and hours. Two rules are easy to miss. A divisor of 1 or less ends
the list there, with what is left as its last element. And with a lazy list
of divisors, the list ends as soon as nothing is left, so 0 gives no
elements at all. A negative number is a Failure.

```raku
say 3661.polymod(60, 60);
say 120.polymod(1, 10, 100);
say 100.polymod(10, 1, 10);
say 1234567.polymod(256 xx *);
say 0.polymod(10 xx *).raku;
say (-1).polymod(10).exception.message;
```
```output
(1 1 1)
(120)
(0 10)
(135 214 18)
().Seq
invocant to polymod out of range. Is: -1, should be in 0..^Inf
```

## An Int's `polymod` by a fraction gives negative remainders
tags: bug

For an Int, `polymod` uses `mod` and `div`, and so shares their
[handling of a fractional divisor](#ch:numbers:7-mod-25-is-05): the remainders
come out negative. A Rat or Num with the same value uses `%`, and in Rakudo
2026.08 the same division gives a different answer depending on whether the
invocant is written `10` or `10.0`.

```raku
say 10.polymod(2.5);
say 10.0.polymod(2.5);
say 10.polymod(1.5);
say 10e0.polymod(1.5);
```
```output
(-2.5 5)
(0 4)
(-5 10)
(1 6)
```

## A Rat unpacks into numerator and denominator
tags: quirk

A parameter can unpack an argument through a sub-signature, which matches
against the argument's `.Capture`. A Rat's capture holds its two attributes
as named arguments, so a sub-signature can take it apart. An Int or a Num
refuses to be captured at all.

```raku
sub parts(Rat $ (:$numerator, :$denominator)) {
    say "$numerator over $denominator";
}
parts(0.75);
say (1/2).Capture.raku;
try 42.Capture;
say $!.^name;
```
```output
3 over 4
\(:denominator(2), :numerator(1))
X::Cannot::Capture
```

## `.fmt` rounds halves up, and `%f` goes through a double

`.fmt` formats a number like `sprintf`. `%d` truncates a Rat or a Num
towards zero, and `%x`, `%o` and `%b` work on Ints of any size. `%.Nf`
rounds halves up, so 2.5 becomes 3 and 0.125 becomes 0.13, where C rounds
both to even. It also converts the number to a double first: only about 17
significant digits survive, and the rest are printed as zeros, even for a
value a double holds exactly.

```raku
say 2.5.fmt("%.0f"), " ", 3.5.fmt("%.0f");
say 0.125.fmt("%.2f");
say 3.7.fmt("%d"), " ", (-3.7).fmt("%d");
say (2**64).fmt("%x");
say (2**70).fmt("%.2f");
say (1/3).fmt("%.20f");
```
```output
3 4
0.13
3 -3
10000000000000000
1180591620717411300000.00
0.33333333333333330000
```

Some formats are refused: `%d` of Inf, `%u` of a negative number, and a
format with more directives than the one number supplied all die with
`X::AdHoc`.

## `log10`, `log2` and a logarithm with a base divide two logarithms
tags: trap

Every logarithm goes through a Num. `log10`, `log2` and `log($x, $base)` are
computed as one natural logarithm divided by another, and the division is
not exact: `1000.log10` is just below 3, so its floor is 2. An Int too large
for a double becomes Inf before the logarithm is taken.

```raku
say 100.log10;
say 1000.log10;
say log(1000, 10);
say (10**15).log10;
say 8.log2, " ", 8.log(2);
say (2**1000).log2;
say (10**400).log10;
```
```output
2
2.9999999999999996
2.9999999999999996
14.999999999999998
3 3
1000.0000000000001
Inf
```

## `$x.exp($base)` raises the base to `$x`
tags: trap

`exp` with a second argument is a power with that base, and the invocant, or
the first argument of the sub, is the exponent. `2.exp(10)` is 10 squared,
not 2 to the tenth. With an Int base and exponent the result is an exact
Int.

```raku
say 2.exp(10);
say 10.exp(2);
say exp(2, 10), " ", exp(2, 10).^name;
say 2.exp(-1);
say exp(1);
```
```output
100
1024
100 Int
1
2.718281828459045
```

## `sqrt` of a negative Real is NaN, not a Complex

The square root and the logarithm of a negative real number are NaN. Only a
Complex argument gives a Complex result. The logarithm of 0 is minus
infinity, and a base-1 logarithm divides by `log(1)`, which is zero, so it
is a Failure. The constants `pi`, `e` and `tau` are Nums, and the
trigonometric functions carry a Num's error.

```raku
say sqrt(-1);
say sqrt(-1+0i);
say 4.sqrt.raku;
say log(0), " ", log(-1);
say log(1, 1).exception.^name;
say sin(pi);
```
```output
NaN
0+1i
2e0
-Inf NaN
X::Numeric::DivideByZero
1.2246467991473532e-16
```

## `rand` takes no argument

`rand` is a term, a random Num from 0 up to but not including 1. Perl's
`rand(10)` does not compile; `10.rand` scales the range, and `(^10).pick` or
`(^10).roll` gives an integer.

```raku
say rand(10);
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Unsupported use of rand(N). In Raku please use: N.rand for Num or
(^N).pick for Int result.
at example.raku:1
------> say rand<HERE>(10);
```

## `srand` repeats a sequence only from its second run
tags: quirk

`srand($seed)` seeds the generator behind `rand`, `pick` and `roll`, and
returns the seed. In Rakudo 2026.08, seeding again with the same value
replays the same numbers only once the code in between has run before: the
first pass through a stretch of code after `srand` draws other
numbers than every later pass after the same `srand`. The numbers are still
the same from one run of the program to the next.

```raku
my @runs;
for ^3 {
    srand(7);
    @runs.push: [5.rand, 5.rand, |(1..6).roll(3)];
}
say @runs[0] eqv @runs[1];
say @runs[1] eqv @runs[2];
say srand(42);
```
```output
False
True
42
```

## A literal of the wrong numeric type is a compile-time error

A typed variable accepts only its own type: an Int variable does not take a
Rat, and a Num variable does not take an Int, even a whole one. When the
value is a literal, the compiler knows already, and refuses the program with
a message that suggests the fixes:

```raku
my Int $x = 1.5;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Cannot assign a literal of type Rat (1.5) to a variable ($x) of type
Int. You can declare the variable to be of type Real, or try to coerce
the value with 1.5.Int or Int(1.5), or just write the value as 1.
at example.raku:1
------> my Int <HERE>$x = 1.5;
```

The same value in a variable fails only when the assignment runs, with an
ordinary type-check error. That check also catches `++` on an undefined Rat
variable: [an undefined variable counts from
0](#ch:nil-any:on-an-undefined-variable-counts-from-0), and the result is the
Int 1, not a Rat. `+=` starts from 0 as well, and with a Rat on the right the
sum is a Rat, which passes.

```raku
my $v = 1.5;
try { my Int $x = $v };
say $!.^name;
my Rat $r;
try $r++;
say $!.message;
$r += 0.5;
say $r;
```
```output
X::TypeCheck::Assignment
Type check failed in assignment to $r; expected Rat but got Int (1)
0.5
```

## Native integers wrap around, and a 64-bit one refuses a big Int

A native integer variable, such as `int` or `uint8`, holds a machine
integer. Storing a value that does not fit in an 8-, 16- or 32-bit one
silently keeps the low bits, and arithmetic on any native integer wraps
around at its size. Only `int` and `uint`, 64 bits wide, refuse a larger Int
outright.

```raku
my int8 $b = 300;
say $b;
my uint8 $u = -1;
say $u;
my int $i = 2**63 - 1;
$i++;
say $i;
my int $big = 2**64;
```
```output
44
255
-9223372036854775808
```
```stderr
Cannot unbox 65 bit wide bigint into native integer. Did you mix int and Int or literals?
  in block <unit> at example.raku line 8

```

Native integers have their own division by zero, a plain `X::AdHoc`, and a
negative power of a native integer is 0 rather than a Rat. `.bits` gives a
type's width; it is asked of the type, and `Int` answers `Inf`.

```raku
my int $a = 7;
my int $zero = 0;
try $a div $zero;
say $!.message;
my int $m = -1;
say $a ** $m;
say int8.bits, " ", uint16.bits, " ", Int.bits;
```
```output
Division by zero
0
8 16 Inf
```
