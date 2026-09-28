---
title: Who Takes the Operand
part: Reading the code
summary: Precedence decides which of two neighbouring operators gets the operand between them; associativity decides what happens when they are on the same level.
---

An expression like `a ~ b * c` has an operand, `b`, sitting between two
operators. Which one takes it? Raku answers with a ladder of precedence
levels: the operator on the higher rung binds first. When both operators are
on the same rung, the level's *associativity* decides, and in Raku that
decision can also be "refuse to compile".

Most of the ladder matches intuition from other languages. This chapter is
about the rungs that do not, and about the places where a single space or a
single word moves an operand from one operator to another.

## The ladder, from tightest to loosest

Here are the levels in order, with the operators you meet most often. An
operator binds tighter than everything below it in the table.

| level | operators | associativity |
|---|---|---|
| method postfix | `.meth` `.[ ]` `.{ }` `.< >` `( )` | left |
| autoincrement | `++` `--` | non-associative |
| exponentiation | `**` | right |
| symbolic unary | `!` `+` `-` `~` `?` `|` `^` `+^` | — |
| dotty infix | `.meth` with a space before the dot | left |
| multiplicative | `*` `/` `%` `%%` `div` `mod` `gcd` `lcm` `+&` `+<` `+>` | left |
| additive | `+` `-` `+|` `+^` `~|` `~^` | left |
| replication | `x` `xx` | left |
| concatenation | `~` | left |
| junctive and | `&` | same operator only |
| junctive or | `|` `^` | same operator only |
| structural | `..` `^..^` `<=>` `leg` `cmp` `but` `does` | non-associative |
| chaining | `==` `<` `eq` `lt` `===` `eqv` `~~` `before` … | chain |
| tight and | `&&` | left |
| tight or | `||` `//` (left), `^^` `min` `max` (same operator only) | |
| conditional | `?? !!` `ff` `fff` | right |
| item assignment | `=` `=>` `+=` `x=` … | right |
| loose unary | `so` `not` | — |
| comma | `,` `:` | list |
| list infix | `Z` `X` `...` `minmax` | same operator only |
| list prefix | list assignment `=`, `[+]`, `any`, `say` without parentheses | |
| loose and | `and` (left), `andthen` `notandthen` (same operator only) | |
| loose or | `or` (left), `xor` `orelse` (same operator only) | |
| sequencer | `==>` `<==` | |

Concatenation sits *below* the arithmetic levels, and replication sits
between them, which is where the first surprises come from:

```raku
say 1 ~ 2 * 3;
say 2 x 2 + 3;
say 2 x 2 ~ 3;
say 1 + 2 ~ 3;
```
```output
16
22222
223
33
```

`2 x 2 + 3` repeats the string `"2"` five times, because `+` is tighter
than `x`; `2 x 2 ~ 3` repeats it twice and then appends `3`, because `~` is
looser.

## `**` binds tighter than unary minus, and groups from the right

The minus sign in `-2 ** 2` is a prefix operator, and prefix operators are
one level below exponentiation. The power is computed first, then negated.
Stacked powers group from the right, as in mathematics.

```raku
say -2 ** 2;
say (-2) ** 2;
say 2 ** 3 ** 2;
say 2 ** -1;
```
```output
-4
4
512
0.5
```

The last line shows the one place where a minus *after* `**` is fine: it is
the prefix of the right operand. Note also that the result is `0.5`, a
rational number, not a float.

## A method call binds tighter than everything, including prefix minus

A method postfix is the top of the ladder. In `-1.abs` the method belongs to
`1`, and the minus is applied to its result:

```raku
say -1.abs;
my $x = -5;
say -$x.abs;
say 2 ** 3.Str;
```
```output
-1
-5
8
```

`2 ** 3.Str` raises `2` to the string `"3"`, which numifies back to an
integer; the answer is an `Int` 8.

## A space before the dot turns a method call into a different operator
tags: trap

Write a space between a term and `.method` and the dot becomes the *dotty
infix*: an operator one level below exponentiation. It still calls the method,
but it now competes for operands like any other operator.

```raku
say (1..3 .elems).raku;
say (1 + 2 .Str).^name;
say "ab" .uc;
```
```output
1..1
Int
AB
```

`1..3 .elems` is `1 .. (3 .elems)`, and `3.elems` is 1, so the range is
`1..1`. In the second line `.Str` applies to `2` alone, and adding a string
`"2"` to `1` gives an `Int`. On a lone term, as in the third line, the space
changes nothing.

## Junctions bind looser than arithmetic and concatenation

`&`, `|` and `^` build junctions, and they sit below `+` and `~` on the
ladder. The arithmetic around them is done first, and each finished side
becomes one eigenstate.

```raku
say (1 + 1 & 2 + 2).raku;
say ("a" ~ 1 | 2).raku;
say (1 & 2 ^ 3).raku;
```
```output
all(2, 4)
any("a1", 2)
one(all(1, 2), 3)
```

`&` is one level tighter than `|` and `^`, so in the last line the `all`
is built first and becomes one element of the `one`.

## Different junction operators do not mix without parentheses

`|` and `^` share a level, but a chain of them must use the same operator
throughout. Mixing them is a compile-time error, not a guess:

```raku
say 1 | 2 ^ 3;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Only identical operators may be list associative; since '|' and '^' differ, they are non-associative and you need to clarify with parentheses
at example.raku:1
------> say 1 | 2<HERE> ^ 3;
    expecting any of:
        infix
        infix stopper
```

The same rule governs `min` and `max`, `Z` and `X`, and `andthen` and
`notandthen`: each is *list associative* only among copies of itself.

## Comparisons chain, and the middle operand is evaluated once

`a < b < c` means `a < b && b < c`, with `b` computed a single time. Any
number of comparison operators can be chained, in any directions.

```raku
say 1 < 2 < 3;
say 1 < 3 > 2;
say 5 > 3 > 1 > 0;
my $calls = 0;
sub middle { $calls++; 2 }
say 1 < middle() < 3, " after $calls call";
```
```output
True
True
True
True after 1 call
```

A chain stops at the first link that is false, so a sub in a later position
may not be called at all.

## `== True` at the end of a chain compares the last operand, not the result
tags: trap

Because comparisons chain, appending `== True` does not test the whole
expression. It adds a link that compares the *previous operand* with `True`,
and `True` numifies to 1:

```raku
say 2 == 2 == True;
say 1 < 2 < 3 == True;
say (2 == 2) == True;
```
```output
False
False
True
```

The first line is `2 == 2 && 2 == True`, and `2 == 1` is false. Parentheses
end the chain and give the comparison you meant, though a plain `2 == 2`
already is that comparison.

## `!` negates a comparison and keeps the chain, but only a comparison

Any chaining operator can be negated by a leading `!`, and the negated
operator still chains:

```raku
say 1 !== 2;
say 1 !eqv 2;
say 1 !~~ Str;
say 1 !> 2 !< 3;
```
```output
True
True
True
False
```

The last line is `!(1 > 2) && !(2 < 3)`: the second link fails. The `!`
metaoperator is only allowed on operators that answer yes or no; on an
operator like `+` the compiler says why it refuses:

```raku
say 1 !+ 2;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Cannot negate + because additive operators are not iffy enough
at example.raku:1
------> say 1 !<HERE>+ 2;
    expecting any of:
        infix
        infix stopper
```

## Structural operators refuse to chain

`..`, `<=>`, `cmp`, `leg`, `but` and `does` share the structural level, which
is *non-associative*: two of them in a row do not parse at all.

```raku
say 1 .. 2 .. 3;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Operators '..' and '..' are non-associative and require parentheses
at example.raku:1
------> say 1 .. 2<HERE> .. 3;
    expecting any of:
        infix
        infix stopper
```

The level sits between the arithmetic and the comparisons, so arithmetic is
done before a range is built, and a comparison sees the finished `Order`:

```raku
say (1 .. 2 + 3).raku;
say 1 <=> 2 == Less;
say 1 == 3 <=> 2;
```
```output
1..5
True
True
```

The last line is `1 == (3 <=> 2)`, which is `1 == More`, and `More`
numifies to 1.

## `&&` binds tighter than `||` and `//`, and `^^` wants exactly one true operand

`&&` is on its own level above `||` and `//`, so `0 || 1 && 0` is
`0 || (1 && 0)`. The tight-or level holds `||` and `//` together, and they
mix freely from left to right.

```raku
say 0 || 1 && 0;
say 1 || 2 // 3;
say Nil // 2 || 3;
```
```output
0
1
2
```

`^^`, the exclusive or, returns the one true operand if there is exactly
one; with two or more true operands it returns `Nil`, and with none it
returns the last operand.

```raku
say 0 ^^ 42;
say (1 ^^ 42).raku;
say (0 ^^ 0).raku;
say (1 ^^ 0 ^^ 3).raku;
```
```output
42
Nil
0
Nil
```

## `min` and `max` are looser than all arithmetic, and do not mix

`min` and `max` look like functions but are infix operators on the tight-or
level, below every arithmetic and string operator:

```raku
say 3 min 2 + 5;
say 1 max 2 ** 2;
say "a" ~ 1 min 2;
```
```output
3
4
2
```

The last line compares the string `"a1"` with `2`. As with the junction
operators, a chain must use one operator throughout: `1 min 2 max 3` is a
compile-time error, *Only identical operators may be list associative*.

## The ternary nests from the right, and an assignment inside it needs parentheses

`?? !!` groups to the right, so a chain of conditions reads like an
if/elsif/else ladder without any parentheses. Each branch takes a whole
expression down to the tight-or level.

```raku
say 1 ?? 2 !! 3 ?? 4 !! 5;
say 0 ?? 2 !! 3 ?? 4 !! 5;
say 1 ?? 2 !! 3 + 10;
say 0 ?? 2 !! 3 + 10;
```
```output
2
4
2
13
```

Assignment is looser than the ternary, so a bare assignment in a branch
would swallow the rest of the expression. Raku refuses to guess:

```raku
my $a = True;
$a ?? $a = 42 !! $a = 43;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Precedence of = is too loose to use inside ?? !!; please parenthesize
at example.raku:2
------> $a ?? $a<HERE> = 42 !! $a = 43;
    expecting any of:
        infix
        infix stopper
```

## `say 0 or …` prints 0: the word operators are looser than a list call
tags: trap

`and`, `or`, `xor`, `andthen`, `orelse` and `notandthen` are the loosest
operators short of the feeds. They are looser than a sub called without
parentheses, which takes everything up to them as its argument list. So the
`say` below is complete before `or` is considered:

```raku
say 0 or say "the right side ran";
```
```output
0
```

`say 0` prints `0` and returns `True`, so the right side never runs. The
same looseness makes `or` a poor fit for assignments, which is why `||` and
`//` exist:

```raku
my $x = 0 || 7;
my $y = 0 or 7;
say "$x $y";
```
```output
7 0
```
```stderr
WARNINGS for example.raku:
Useless use of constant integer 7 in sink context (line 2)
```

The compiler notices that the `7` on line 2 can never be used and warns at
compile time, before the program runs.

## `andthen` and `orelse` test definedness and hand the value on as `$_`

`andthen` evaluates its right side only when the left side is *defined*,
not true, so `0 andthen …` goes on. The right side sees the left value as
`$_`. When the left side is undefined, the result is `Empty`, not the
undefined value itself.

```raku
say (0 andthen "0 is defined");
say (5 andthen $_ * 2 andthen $_ + 1);
say (Any andthen 2).raku;
say (Any orelse "fallback");
```
```output
0 is defined
11
Empty
fallback
```

`orelse` is the mirror image: it takes the right side when the left is
undefined. When the left side is a `Failure`, `$_` is that Failure, and
`orelse` marks it handled, so it does not throw:

```raku
sub risky { fail "no luck" }
say (risky() orelse "handled: " ~ .exception.message);
```
```output
handled: no luck
```

The parentheses matter in all of these: without them `say` would take the
left operand alone, as in the previous corner.

## The sigil of the target decides between item and list assignment
tags: trap

`=` is two operators. When the target is a `$` variable, it is *item
assignment*, which binds tighter than the comma. Any other target makes it
*list assignment*, which binds looser than the comma. The choice is made by
the target's sigil alone, even when the target is one element of an array
or a hash:

```raku
my @a;
@a[0] = 1, 2;
say @a.raku;
my %h;
%h<k> = 1, 2;
say %h.raku;
```
```output
[(1, 2),]
{:k($(1, 2))}
```

`@a[0]` is a single slot, but the `@` makes the assignment a list
assignment, and the whole list `(1, 2)` lands in that slot. With a `$`
target the comma is left outside:

```raku
my $x = 1, 2;
say $x;
```
```output
1
```
```stderr
WARNINGS for example.raku:
Useless use of constant integer 2 in sink context (lines 1, 1)
```

## List assignment is looser than `Z` and `X`; item assignment is tighter

The list infixes `Z`, `X`, `...` and `minmax` sit between the comma and list
assignment. An array assignment therefore receives the whole zip, while a
scalar assignment takes its left operand and leaves the rest behind:

```raku
my @pairs = 1, 3 Z 2, 4;
say @pairs.raku;
my $first = (1, 3) X (2, 4);
say $first.raku;
```
```output
[(1, 2), (3, 4)]
$(1, 3)
```
```stderr
WARNINGS for example.raku:
Useless use of "X" in expression "my $first = (1, 3) X (2, 4)" in sink context (line 3)
```

## The comma binds tighter than `Z`, `X` and `...`

Each side of a list infix is a whole comma list, so `1, 2 Z 3, 4` zips two
two-element lists, and a sequence can take several seeds and several
end points at once:

```raku
say (1, 2 Z 3, 4).raku;
say (1, 2 ... 5, 6).raku;
```
```output
((1, 3), (2, 4)).Seq
(1, 2, 3, 4, 5, 6).Seq
```

The second line is `(1, 2) ... (5, 6)`: the sequence deduces a step of 1
from the seeds, runs to 5, and then the remaining `6` is appended.

## `=>` sits on the assignment level and nests to the right

The pair constructor is on the item-assignment level. It groups to the right,
so `1 => 2 => 3` is a pair whose value is another pair. Being looser than
the ternary, it takes a whole conditional on either side:

```raku
say (1 => 2 => 3).raku;
say (1 => 2 => 3).value.^name;
say (1 ?? 2 !! 3 => 4).raku;
say (1 => 2 ?? 3 !! 4).raku;
say (a => 1 + 1).raku;
```
```output
1 => 2 => 3
Pair
2 => 4
1 => 3
:a(2)
```

## A reduction takes everything to its right
tags: trap

`[+]` and the other reduction operators are list prefixes: like a sub called
without parentheses, they take the whole comma list that follows. Inside a
`say` that includes every argument after them:

```raku
say "sum: ", [+] 1, 2, 3, " done";
```
```output
```
```stderr
Cannot convert string to number: base-10 number must begin with valid digits or '.' in ' <HERE>done' (indicated by <HERE>)
  in block <unit> at example.raku line 1

```

The reduction tried to add `" done"` to 6. Wrap the reduction in parentheses,
`([+] 1, 2, 3)`, to end its argument list.

## A reduction folds by the operator's associativity

`[op]` is not always a left fold. It folds the way the operator associates:
right-associative operators from the right, and chaining operators as a
chain.

```raku
say [**] 2, 3, 2;
say [-] 1, 2, 3;
say [<] 1, 2, 3;
say [<] 1, 3, 2;
say [\+] 1, 2, 3, 4;
```
```output
512
-4
True
False
(1 3 6 10)
```

`[**] 2, 3, 2` is `2 ** (3 ** 2)`, and `[<] 1, 3, 2` is
`1 < 3 < 2`. The triangle form `[\op]` returns every intermediate result.

## An empty reduction answers the operator's identity

Reducing an empty list gives the value that would leave any other list
unchanged: 0 for addition, 1 for multiplication, the empty string for
concatenation, `True` for a chain. An operator with no identity answers a
`Failure`.

```raku
say [+] ();
say [*] ();
say [~] ();
say [min] ();
say [<] ();
say ([/] ()).exception.^name;
```
```output
0
1

Inf
True
X::NoZeroArgMeaning
```

The third line is an empty string. `[min]` of nothing is `Inf`, the value
that any real number is smaller than.

## Only associative and chaining operators reduce

A non-associative operator has no meaningful fold, and the compiler rejects
the reduction before the program runs:

```raku
say [..] 1, 2, 3;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Cannot reduce with .. because structural infix operators are diffy and not chaining
at example.raku:1
------> say [<HERE>..] 1, 2, 3;
    expecting any of:
        argument list
        infix
        infix stopper
        term
```

## The pointed side of a hyper operator sets the length

A hyper operator applies its base operator element by element. The direction
of each chevron says which side may be extended: a side the chevrons *point
at* is the one whose length counts, and a blunt side is repeated to match it.

```raku
say (1, 2, 3) >>+>> (10, 20);
say (1, 2, 3) <<+>> (10, 20);
say (1, 2) >>+<< (10, 20);
say (1, 2, 3) >>*>> 2;
```
```output
(11 22 13)
(11 22 13)
(11 22)
(2 4 6)
```

When both sides are pointed at, their lengths must be equal, and a mismatch
is a run-time error:

```raku
say (1, 2, 3) >>+<< (10, 20);
```
```output
```
```stderr
Lists on either side of non-dwimmy hyperop of infix:<+> are not of the same length while recursing
left: 3 elements, right: 2 elements
  in block <unit> at example.raku line 1

```

A hyper operator keeps the precedence of the operator it is built from, so
`>>*<<` binds tighter than `>>+<<`.

## `>>.^name` asks the list, not its elements
tags: quirk

`>>.method` calls the method on every element. A metamethod call, written
with `.^`, is not distributed the same way: the hyper prefix is ignored and
the list answers for itself.

```raku
say (1, 2)>>.^name;
say (1, 2)>>.WHAT;
say (1, 2).map(*.^name);
```
```output
List
(List)
(Int Int)
```

Use `.map` when you want the metaobject of each element.

## `R` swaps the operands and keeps the precedence

The reverse metaoperator `R` exchanges the two operands of any infix. The
new operator stays on the level of the old one, and a reduction with it
folds the other way:

```raku
say 1 R- 3;
say 2 Rx "ab";
say 1 R- 2 * 3;
say [R~] <a b c>;
```
```output
2
abab
5
cba
```

`1 R- 2 * 3` is `(2 * 3) - 1`: the multiplication is still done first.

## Autoincrement reads its operand at the moment it runs
tags: trap

The operands of an infix operator are containers, and a container is read
when the operator needs its value. A postfix `++` on the right runs before
the `+` reads its left operand:

```raku
my $i = 1;
say $i + $i++;
$i = 1;
say $i++ + $i;
$i = 1;
say ++$i + ++$i;
```
```output
3
3
5
```

In the first line the left `$i` is read after the increment, 2 + 1. Code
that depends on this order is legal but hard to read; the autoincrement
operators themselves refuse to be stacked:

```raku
my $l = 42;
say ++$l++;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Operators '++' and '++' are non-associative and require parentheses
at example.raku:2
------> say ++$l++<HERE>;
    expecting any of:
        postfix
```

## Symbolic prefixes bind tight; `so` and `not` bind loose

The one-character prefixes `! + - ~ ? ^ |` apply to the nearest term. The
word prefixes `so` and `not` are loose: below every comparison and even
below item assignment, but above the comma.

```raku
say !1 ~~ 2;
say not 1 ~~ 2;
say (not 1, 42)[1];
say (so 0, 1).raku;
```
```output
False
True
42
(Bool::False, 1)
```

`!1 ~~ 2` smartmatches `False` against 2; `not 1 ~~ 2` negates the whole
smartmatch. The comma stops `so` and `not`, so each takes only its first
operand. Because they are looser than assignment, `so $x = 42` assigns and
then tests:

```raku
my $x;
say so $x = 42;
say $x;
```
```output
True
42
```

The tight prefixes apply before any infix, which is how `^3 + 1` becomes a
range shifted by one:

```raku
say ~1 + 2;
say (~1 + 2).^name;
say (^3 + 1).raku;
say ?2 * 2;
```
```output
3
Int
1..^4
2
```

## A flip-flop counts the elements of its run

`ff` turns on when its left side matches and off after its right side
matches. While on, it returns a count, 1 for the element that switched it
on; while off it returns `Nil`. It tests the right side on the same element
that turned it on, so a condition that matches both sides makes a run of
one. `fff` waits for the next element before testing the right side.

```raku
say (1..6).map({ $_ == 2 ff $_ == 4 });
say (1..6).map({ $_ == 2 ff $_ == 2 });
say (1..6).map({ $_ == 2 fff $_ == 2 });
say (1..5).map({ $_ == 2 ^ff^ $_ == 4 });
```
```output
(Nil 1 2 3 Nil Nil)
(Nil 1 Nil Nil Nil Nil)
(Nil 1 2 3 4 5)
(Nil Nil 2 Nil Nil)
```

A `^` on either side excludes that end of the run from the results, but the
count still includes it: the excluded start is element 1, so the first
result is 2.

## Feeds are the loosest operators of all
tags: trap

`==>` and `<==` are below even `or`. That makes a feed into a `my @r = …`
assignment surprising: the assignment finishes first, and the feed then
sends its result into `sort`, where nothing collects it.

```raku
my @r = <b c a> ==> sort();
say @r;
<b c a> ==> sort() ==> my @s;
say @s;
```
```output
[b c a]
[a b c]
```

End the feed in the variable, as on the third line, and it collects the
sorted list.
