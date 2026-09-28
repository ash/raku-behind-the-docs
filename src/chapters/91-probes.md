---
title: Writing a Probe
part: Appendices
kind: appendix
summary: The ways a small test program measures something other than what its author meant, and how to write one whose output can be trusted.
---

Every corner in this book began as a *probe*: a small program written to
find out what Rakudo does. Probes are also how bugs are reported, how
questions are asked on a forum, and how a test starts its life. A probe is
only as good as its question, and Raku offers many ways for a probe to
answer a different question from the one its author asked: an error that
happens outside the `try` meant to catch it, a line the compiler computed
before the program ran, an argument that changed its meaning, an output that
changes from one run to the next.

Each corner below states one such trap, shows a probe that falls into it with
the output that misleads, and then the corrected probe with the output that
can be trusted. The rules behind most of the traps have corners of their own
in the chapters, and the links lead there.

## A `try` around a lazy Seq catches nothing
tags: trap

A probe that asks whether some code throws usually wraps it in `try` and
looks at `$!` afterwards. When the code returns a lazy Seq, as `map` does,
none of it has run when the `try` ends. The elements are computed when
something reads them, which is outside the `try` ([The Sequence
Operator](#ch:sequences:a-sequence-fails-where-it-is-read-which-may-be-outside-the-try)).
If nothing reads them, the error never shows at all:

```raku
my $r = try (1..3).map({ die "bad $_" if $_ == 2; $_ });
say $! ?? "threw: $!.message()" !! "did not throw";
```
```output
did not throw
```

`.eager` computes every element on the spot, inside the `try`. So do
`.Array` and assignment to an array. `.List` does not: it wraps the Seq in
a list that is still computed as it is read, so it escapes in the same way.

```raku
my $r = try (1..3).map({ die "bad $_" if $_ == 2; $_ }).eager;
say $! ?? "threw: $!.message()" !! "did not throw";
my $l = try (1..3).map({ die "bad $_" if $_ == 2; $_ }).List;
say $! ?? "threw: $!.message()" !! "did not throw";
```
```output
threw: bad 2
did not throw
```

## Through `try`, a Failure looks like a `die`, or like success
tags: trap

`try` turns on `use fatal` for its body, and under it a Failure returned by
a call throws at once ([Exceptions and
Failures](#ch:exceptions:use-fatal-makes-a-returned-failure-throw-at-once)).
A probe that uses `try` to learn how a routine reports an error therefore
gets the same answer from a routine that dies and from one that fails:

```raku
sub thrower { die "no" }
sub failer  { fail "no" }
my $a = try thrower();
say "thrower: ", $!.^name;
my $b = try failer();
say "failer: ", $!.^name;
```
```output
thrower: X::AdHoc
failer: X::AdHoc
```

Without `try` the two are told apart: a CATCH sees what was thrown, and the
result of the call shows what was returned. Asking the result `.defined`
also marks the Failure handled, so it does not throw later.

```raku
sub thrower { die "no" }
sub failer  { fail "no" }
for &thrower, &failer -> &f {
    my $r = f();
    say &f.name, ": returned a ", $r.^name, ", defined: ", $r.defined;
    CATCH { default { say &f.name, ": threw ", .^name } }
}
```
```output
thrower: threw X::AdHoc
failer: returned a Failure, defined: False
```

The opposite happens with a comparison. `==` and `<` on a string that is not
a number return a Failure that passes through the `try` without throwing
([Numbers](#ch:numbers:try-catches-the-failure-from-but-not-the-one-from)).
The `try` counts as a success and resets `$!`, and only the value says what
happened:

```raku
my $s = "abc";
my $r = try $s < 1;
say $! ?? "threw" !! "did not throw";
say $r.defined ?? "result: $r" !! "failed: " ~ $r.exception.^name;
```
```output
did not throw
failed: X::Str::Numeric
```

Test the result of the code under study, not `$!`.

## `$!` belongs to the latest `try` in the routine
tags: trap

A `try` that succeeds sets `$!` back to `Any` ([Exceptions and
Failures](#ch:exceptions:a-successful-try-resets-to-any)), and every `try`
in a routine shares the routine's `$!`, even one in a nested block. A probe
that catches the exception it studies, does a little more work and then
prints `$!` prints the outcome of the work if the work contains a `try`:

```raku
try { die "the error under study" };
my $n = try { +"42" };
say $! ?? $!.message !! "no exception";
```
```output
no exception
```

Copy `$!` into a variable of its own straight after the `try` it belongs
to:

```raku
try { die "the error under study" };
my $error = $!;
my $n = try { +"42" };
say $error ?? $error.message !! "no exception";
```
```output
the error under study
```

## A `try` with a CATCH of its own lets the rest escape
tags: trap

A CATCH block inside a `try` replaces the handler that `try` would supply.
Whatever no `when` or `default` in it matches leaves the `try` as if there
were no `try` ([Exceptions and
Failures](#ch:exceptions:a-try-with-its-own-catch-catches-nothing-else)).
A probe that runs several pieces of code and reports the exceptions its
author expects ends at the first exception nobody expected, and the pieces
after it never run:

```raku
my @probes = { die "plain" }, { +"abc" }, { 42 };
for @probes -> &code {
    try {
        code();
        CATCH { when X::AdHoc { say "caught: ", .^name } }
    }
}
say "all probes ran";
```
```output
caught: X::AdHoc
```
```stderr
Cannot convert string to number: base-10 number must begin with valid digits or '.' in '<HERE>abc' (indicated by <HERE>)
  in block <unit> at example.raku line 1

Actually thrown at:
  in block  at example.raku line 4
  in block <unit> at example.raku line 2

```

Without the CATCH, `try` catches everything, and `$!` names what it caught:

```raku
my @probes = { die "plain" }, { +"abc" }, { 42 };
for @probes -> &code {
    try code();
    say $! ?? "caught: " ~ $!.^name !! "no exception";
}
say "all probes ran";
```
```output
caught: X::AdHoc
caught: X::Str::Numeric
no exception
all probes ran
```

## Rakudo computes an operation on literals while it compiles
tags: trap

When every operand of an operator is a literal, Rakudo may compute the
result while it compiles the program and put the value in the operation's
place. This is *constant folding*. When the program runs, there is no
operation left, and nothing that should influence the operation reaches it.
A probe that wraps the `+` operator to count its calls sees no call for
`1 + 2`:

```raku
my $calls = 0;
&infix:<+>.wrap(-> |c { $calls++; callsame });
my $sum = 1 + 2;
say "calls: $calls";
my $one = 1;
$sum = $one + 2;
say "calls: $calls";
```
```output
calls: 0
calls: 1
```

A dynamic variable cannot reach a folded operation either: `1 / 2**64`
becomes a Num however `$*RAT-OVERFLOW` is set when the line runs
([Numbers](#ch:numbers:rat-overflow-does-not-reach-a-division-of-literals)).
For the same reason, a benchmark of an expression made only of literals
times nothing but a constant. An operation that throws or warns is not
folded: `Int + 1` still throws, and `Nil == 0` still warns, when its line
runs. A probe that takes its operands from variables sees the operation
happen where it expects.

## A literal mistake keeps the whole probe from compiling
tags: trap

Some mistakes are visible in the source text: a literal of the wrong type
for a typed variable, a literal negative index, a type parameterized with a
value, a call whose literal argument can never match the signature. Rakudo
refuses such a program before running any of it. A probe that asks several
questions in one file then answers none of them, not even those on the
lines before the mistake:

```raku
say "7 div 2 is ", 7 div 2;
sub greet(Str $name) { "hello $name" }
say greet(42);
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Calling greet(Int) will never work with declared signature (Str $name)
at example.raku:3
------> say <HERE>greet(42);
```

With the value in a variable, each mistake becomes an ordinary exception, or
a Failure, when its line runs ([Exceptions and
Failures](#ch:exceptions:a-call-that-can-never-match-its-signature-fails-at-compile-time)):

```raku
my $v = 1.5;
try { my int $x = $v };
say $!.^name;
my @a = 1, 2;
my $i = -1;
my $r = @a[$i];
say $r.defined ?? $r !! $r.exception.^name;
my $n = 42;
try { Array[$n] };
say $!.^name;
```
```output
X::AdHoc
X::OutOfRange
X::AdHoc
```

To study the compile-time error itself, compile the code with `EVAL`, which
turns the refusal into an exception that `try` can catch ([Exceptions and
Failures](#ch:exceptions:compile-time-errors-are-exceptions-and-eval-makes-them-catchable)).
One EVAL per question keeps each refusal from hiding the others:

```raku
use MONKEY-SEE-NO-EVAL;
for 'my int $x = 1.5', 'my @a = 1, 2; @a[-1]', 'Array[42]',
    'sub greet(Str $n) { }; greet(42)' -> $code {
    try EVAL $code;
    say $!.^name;
}
```
```output
X::Syntax::Number::LiteralType
X::Obsolete
X::AdHoc
X::TypeCheck::Argument+{X::Comp}
```

## Braces in a double-quoted EVAL string run before the EVAL
tags: trap

A probe often builds code in a string and hands it to `EVAL`. In a
double-quoted string, `{ … }` is a block that runs while the string is being
built, and its value is interpolated ([Quotes and
Interpolation](#ch:quotes:a-in-double-quotes-opens-a-block-of-code)). EVAL
then compiles something other than what was written:

```raku
use MONKEY-SEE-NO-EVAL;
say "say { 1 + 1 }.WHAT";
EVAL "say { 1 + 1 }.WHAT";
```
```output
say 2.WHAT
(Int)
```

Single quotes leave the braces alone, and EVAL compiles the code as written:

```raku
use MONKEY-SEE-NO-EVAL;
EVAL 'say { 1 + 1 }.WHAT';
```
```output
(Block)
```

A backslash inside the braces does not help, because the braces hold code,
where a backslash is an operator and not an escape. A value that must go
into the code is joined on with `~`.

## A list operator inside `say` takes every argument after it
tags: trap

A sub called without parentheses, and a reduction such as `[+]`, take the
whole comma list that follows them
([Whitespace](#ch:whitespace:a-sub-called-without-parentheses-takes-the-whole-comma-list),
[Precedence](#ch:precedence:a-reduction-takes-everything-to-its-right)).
Inside a `say`, that is every remaining argument, labels included. The
result may be an error, or a plausible answer to the wrong question:

```raku
say "joined: ", join "-", 1, 2, 3, "!";
say "smallest: ", [min] 3, 1, 2, " (expected 1)";
```
```output
joined: 1-2-3-!
smallest:  (expected 1)
```

The label became one of the values compared. Compared with a number, a
string is compared as a string, and one that starts with a space comes
before every digit, so it is the smallest. Parentheses end the argument
list where it was meant to end:

```raku
say "joined: ", join("-", 1, 2, 3), "!";
say "smallest: ", ([min] 3, 1, 2), " (expected 1)";
```
```output
joined: 1-2-3!
smallest: 1 (expected 1)
```

## Precedence can build a different expression from the one intended
tags: trap

The parser reads a probe by the precedence table, not by its layout. When a
probe dies of an error about something it did not ask, or earns a warning,
it may be testing another expression. `xx` binds tighter than `..`, so this
probe repeats the endpoint 3 rather than the range, and fails for a reason
that has nothing to do with `xx`
([Ranges](#ch:ranges:xx-and-bind-tighter-than-and-a-prefix-warns)):

```raku
my @r = 1..3 xx 2;
say @r;
```
```output
```
```stderr
Seq objects are not valid endpoints for Ranges
  in block <unit> at example.raku line 1

```

Parentheses make the probe say what it means, and `.raku` shows what was
built:

```raku
say ((1..3) xx 2).raku;
my $s = (1 ... 3);
say $s;
say (1..2) cmp (1..2);
```
```output
(1..3, 1..3).Seq
(1 2 3)
Same
```

Without its parentheses, `my $s = 1 ... 3` is `(my $s = 1) ... 3`, which
leaves 1 in `$s` and earns a warning
([Whitespace](#ch:whitespace:spacing-does-not-group-operands)).
`(1..2) cmp 1..2` does not compile at all, because `cmp` and `..` share a
non-associative level
([Precedence](#ch:precedence:structural-operators-refuse-to-chain)).

## A sub's `$_`, `(* + 1).arity` and `try { $^a }` mislead
tags: trap

Three short spellings do not mean what a probe's author may take them for.
A sub has a `$_` of its own, which is neither its argument nor the caller's
topic, and it starts out undefined. A method called on a `*` expression is
added to the WhateverCode instead of asking it anything
([Signatures](#ch:signatures:a-method-call-on-a-expression-becomes-part-of-it)):

```raku
sub double($n) { $_ * 2 }
say double(21);
say (* + 1).arity;
```
```output
0
WhateverCode.new
```
```stderr
Use of uninitialized value $_ of type Any in numeric context
  in sub double at example.raku line 1
```

The third spelling does not compile. `try` followed by a block takes the
block as its own body, and a `try` body cannot have placeholder parameters:

```raku
my $f = try { $^a * 2 };
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Placeholder variable '$^a' may not be used here because the surrounding
block does not take a signature.
at example.raku:1
------> my $f = try { $^a * 2 }<HERE>;
    expecting any of:
        horizontal whitespace
        statement end
        statement modifier
        statement modifier loop
```

A parameter named `$_` is the topic; a WhateverCode kept in a variable
answers questions about itself; and parentheses make a block a value that
`try` returns:

```raku
sub double($_) { $_ * 2 }
say double(21);
my $inc = * + 1;
say $inc.arity;
my $f = try ({ $^a * 2 });
say $f(21);
```
```output
42
1
42
```

## A Pair in a call is a named argument, not data
tags: trap

`a => 1` or `:a` written directly in a call is a named argument
([Signatures](#ch:signatures:a-pair-written-in-a-call-is-a-named-argument)).
A routine with no parameter of that name ignores it or refuses the call, so
a probe that feeds Pairs to a routine may be feeding it nothing. And the left
side of `=>` is quoted when it is a bare word, so `Int => 1` has the string
`"Int"` as its key
([Hashes](#ch:hashes:a-bareword-before-is-a-string-even-a-type-name)):

```raku
my %h = a => 1;
%h.push(a => 2);
say %h;
say Bag.new(a => 3).elems;
my %o{Any} = Int => "type";
say %o.keys.map(*.^name);
```
```output
{a => 1}
0
(Str)
```

This probe concludes that `push` does not add to an existing key, that
`Bag.new` drops a Pair, and that an object hash turns a type into a string.
Parentheses make each Pair a value, and the answers change:

```raku
my %h = a => 1;
%h.push((a => 2));
say %h;
say Bag.new((a => 3)).elems;
my %o{Any} = (Int) => "type";
say %o.keys.map(*.^name);
```
```output
{a => [1 2]}
1
(Int)
```

`push` stacks the new value on the old one ([Hashes](#ch:hashes:hpusha-1-pushes-nothing)),
and `Bag.new` makes the Pair an element ([Sets, Bags and
Mixes](#ch:sets:a-pair-given-to-set-is-an-element-not-a-weight)). The subs
`set` and `bag` refuse a named argument outright: `set(:a)` dies with
`X::Multi::NoMatch`.

## `say` prints nothing if one argument cannot be printed
tags: trap

`say` turns all its arguments into text before it prints any of them. When
one cannot be turned into text, `say` dies, and the values before it are lost
with it. A probe that prints several results on one line reports only the
error, which then seems to be about the whole line:

```raku
my ($a, $b) = 1, 0;
say "sum: ", $a + $b, ", ratio: ", $a / $b;
```
```output
```
```stderr
Attempt to divide 1 by zero when coercing Rational to Str
  in block <unit> at example.raku line 2

```

The division succeeded. `1 / 0` is a Rat, and only its conversion to text
fails ([Numbers](#ch:numbers:10-is-a-rat-and-it-fails-only-when-printed)).
An unhandled Failure among the arguments, such as `+"x"`, takes the line
down in the same way. One result per `say` keeps the good ones, and `.raku`
shows a value that has no text form:

```raku
my ($a, $b) = 1, 0;
say "sum: ", $a + $b;
say "ratio: ", ($a / $b).raku;
```
```output
sum: 1
ratio: <1/0>
```

## Plain printing hides what a value is
tags: trap

`put` and `print` show a value's `.Str`, and `say` its `.gist`. Both forms
are made for people, and both drop what a probe often needs to know. Under
`put`, the empty string, Nil and an undefined Any all print as an empty
line, two of them with a warning ([Nil, Any and the
Undefined](#ch:nil-any:nil-is-0-in-arithmetic-and-empty-in-a-string-with-a-warning)).
Under `say`, a number and a string of the same digits look alike:

```raku
put "";
put Nil;
put Any;
say 1, " ", "1";
```
```output



1 1
```
```stderr
Use of Nil in string context
  in block <unit> at example.raku line 2
Use of uninitialized value of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 3
```

`.raku` tells each of them apart, silently:

```raku
say "".raku;
say Nil.raku;
say Any.raku;
say 1.raku, " ", "1".raku;
```
```output
""
Nil
Any
1 "1"
```

## Hash and set order changes with every run
tags: trap

Rakudo walks the pairs of a hash in an order that differs from one process to
the next ([Hashes, Maps and
Pairs](#ch:hashes:iteration-order-is-random-but-printing-sorts)). A probe
that prints `.keys`, `.values`, `.pairs` or `.kv`, or the result of `.fmt`
or `.map` on a hash, shows one order on one run and another on the next, and
the order it happened to see proves nothing. The same holds for the elements
of a Set or a Bag listed by `.keys` or `.Str`, and for the named captures of
a match listed by `.keys`
([Regexes](#ch:regexes:caps-and-chunks-keep-the-order-of-the-text-keys-does-not)):

```raku nocheck
my %h = a => 1, b => 2, c => 3, d => 4;
say %h.keys;
say %h.fmt("%s=%s", ",");
say set(<a b c d>).keys;
```

Three runs of this program began with `(c a b d)`, `(b d c a)` and
`(a b c d)`; the third order happened to be sorted, which proves nothing
either. Sort before printing. The gist, `.Str` and `.raku` of a whole
Hash are sorted already, and so is the gist of a Set or a Bag ([Sets, Bags
and Mixes](#ch:sets:say-sorts-the-elements-str-and-raku-do-not)):

```raku
my %h = a => 1, b => 2, c => 3, d => 4;
say %h.keys.sort;
say %h.sort.map(*.fmt("%s=%s")).join(",");
say set(<a b c d>).keys.sort;
say %h;
"x1" ~~ / $<letter>=(\w) $<digit>=(\d) /;
say $/.keys.sort;
```
```output
(a b c d)
a=1,b=2,c=3,d=4
(a b c d)
{a => 1, b => 2, c => 3, d => 4}
(digit letter)
```

## Several "Useless use" warnings come out in a random order
tags: quirk

The compiler collects its reports of useless values ([Values Nobody
Uses](#ch:sink:the-compiler-reports-sunk-values-that-cannot-matter)) and
prints them in one block after compiling. When there are several, their
order changes from one run to the next:

```raku nocheck
my $x = 1;
$x + 1;
$x * 2;
42;
say $x;
```

The three reports of this probe came out in a different order on almost
every run: line 2 first on one run, line 4 or line 3 first on others. A
probe that studies these warnings provokes one per program:

```raku
my $x = 1;
$x * 2;
say $x;
```
```output
1
```
```stderr
WARNINGS for example.raku:
Useless use of "*" in expression "$x * 2" in sink context (line 2)
```

## After `srand`, a first pass draws other numbers
tags: quirk

`srand` seeds the generator behind `rand`, `pick` and `roll`, so that the
same seed should give the same numbers. In Rakudo 2026.08 the same seed gives
the same numbers only when the code that draws them has already run once
after a seed ([Numbers](#ch:numbers:srand-repeats-a-sequence-only-from-its-second-run)).
A probe that seeds twice and compares the draws concludes that `srand`
repeats nothing:

```raku
srand(42); my @first = (^100).roll(5);
srand(42); my @second = (^100).roll(5);
say @first eqv @second;
```
```output
False
```

Run the same comparison twice, and the second pass gives the answer that
holds from then on:

```raku
for 1, 2 -> $pass {
    srand(42); my @first = (^100).roll(5);
    srand(42); my @second = (^100).roll(5);
    say "pass $pass: ", @first eqv @second;
}
```
```output
pass 1: False
pass 2: True
```

The code that counts includes Rakudo's own. Two ways of reading the same
`roll` draw different numbers after the same seed, on every pass: the gist
of the Seq and an array assigned from it do not agree.

```raku
for 1, 2 {
    srand(42); my $shown = (^100).roll(5).gist;
    srand(42); my @kept = (^100).roll(5);
    say $shown eq @kept.List.gist;
}
```
```output
False
False
```

The numbers are the same from one run of the program to the next, so a
probe that prints them is repeatable. It is not evidence of what another
version of Rakudo, or the same code reached another way, will draw.

## A dropped Failure warns at an unpredictable moment
tags: trap

A Failure that is never tested is reported when the garbage collector frees
it ([Exceptions and
Failures](#ch:exceptions:an-unhandled-failure-can-warn-when-the-garbage-collector-frees-it)).
Looking at its type with `.^name`, or at its message, does not count as a
test ([Values Nobody
Uses](#ch:sink:testing-a-failure-marks-it-handled-and-then-it-sinks-quietly)).
A probe that makes Failures in a loop and examines each one prints warnings
whose number depends on when the collector happens to run:

```raku nocheck
sub lookup($k) { fail "no key $k" }
for ^5000 { my $f = lookup($_); $f.^name }
say "done";
```

Four runs of this probe printed 4,852, 2,265, 2,267 and 4,450 warnings on
standard error, each beginning `WARNING: unhandled Failure detected in
DESTROY`. A probe with a single Failure usually prints none, which is no
better: the same probe, grown a little, may start to warn. A probe tests
every Failure it creates, with `.so`, `.defined` or a Boolean context, and
the collector has nothing to report:

```raku
sub lookup($k) { fail "no key $k" }
my $missing = 0;
for ^5000 { my $f = lookup($_); $missing++ unless $f }
say $missing;
```
```output
5000
```

## A probe that prints a path prints where it ran
tags: trap

`$*CWD`, the result of `.absolute` and `$*EXECUTABLE` name places on the
machine that runs the probe. Printed, they make the output differ from one
directory or one machine to the next, and they say nothing about the
behaviour under study. `$*EXECUTABLE` is the binary's path with symbolic
links followed, which need not be the path that was typed to run it:

```raku nocheck
say $*CWD;
say "a.txt".IO.absolute;
say $*EXECUTABLE;
```

Print a test of the property the probe is about instead:

```raku local
say "a.txt".IO.absolute eq $*CWD.add("a.txt").Str;
say "a.txt".IO.absolute.IO.is-absolute;
say $*EXECUTABLE.is-absolute;
say $*EXECUTABLE.e;
```
```output
True
True
True
True
```

## An endless list hangs a probe that has no timer
tags: trap

`.eager` computes every element of a list, and on an endless list it never
finishes. `.elems` of a lazy Range or Array returns a Failure ([Lists,
Arrays, Seqs and Slips](#ch:lists:a-lazy-list-can-be-indexed-but-not-counted)),
but a `gather` does not count as lazy
([Lists](#ch:lists:is-lazy-is-false-for-a-gather-even-an-endless-one)), and
`.elems` of an endless one runs for ever too. Each of these lines hangs on
its own:

```raku nocheck
say (1..*).eager.elems;
say (1, 2 ... *).eager.elems;
say (gather { my $i = 0; loop { take $i++ } }).elems;
```

A hanging probe blocks whatever runs it, a terminal or a test suite. Run
every probe under a timer. With Perl, which is present on almost every Unix
system, that takes one line:

```text
perl -e 'alarm 10; exec @ARGV' rakudo probe.raku
```

After ten seconds the alarm signal ends the process. What the probe printed
before the hang stays; the line that hangs prints nothing, and the exit
status is 142, which is 128 plus the signal number 14. A probe that shows no
output at all may have hung on its first line, rather than printed an empty
result.

## An output that changes between runs cannot be verified

This book runs every example twice. The build keeps the reference
output of each example; with `--fresh` it runs every example again and
fails if any prints something different. An example whose output changes
from run to run cannot be checked, because no single text is right, and the
traps above are where such outputs come from. A probe can check itself the
same way, by running its code in two separate processes and comparing:

```raku local
my $probe = 'my %h = <a b c d e f> Z=> 1..6; print %h.keys.sort';
my @out = (1, 2).map: { run($*EXECUTABLE, "-e", $probe, :out).out.slurp(:close) };
say @out[0] eq @out[1];
say @out[0];
```
```output
True
a b c d e f
```

Without `.sort`, five runs of the same code printed five different orders.
Before trusting what a probe prints:

- reify a lazy result inside the `try` that guards it;
- test the value the code returns, not `$!`, and copy `$!` at once;
- take operands from variables, and put code for `EVAL` in single quotes;
- parenthesise a list operator or a reduction inside `say`;
- print one result per `say`, with `.raku` when the type matters;
- sort hash keys, set elements and capture names;
- provoke one "Useless use" warning per program, and test every Failure;
- compare seeded random draws only after a first pass;
- print a test instead of a path;
- run the probe under a timer, and run it twice.
