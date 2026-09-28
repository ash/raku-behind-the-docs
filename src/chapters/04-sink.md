---
title: Values Nobody Uses
part: Reading the code
summary: A value that nothing uses is sunk; the compiler warns about the useless ones, and at run time a sunk Failure, a failed Proc and a Seq each do something of their own.
---

A statement like `$total + 1;` computes a value and throws it away. Raku
calls this *sink context*, and the value is said to be *sunk*. Sinking is
not silent. While it compiles, the compiler looks at every sunk expression
and warns about the ones that cannot have any effect. At run time, a sunk
value has its `sink` method called. For most types that method does
nothing, but for three built-in types it matters: a `Failure` throws its
exception, a `Proc` of a failed command throws `X::Proc::Unsuccessful`, and
a `Seq` runs to the end.

This chapter is about where sink context reaches, what it does when it gets
there, and the few places it does not reach although a closely related form
does. The last
corners are about the other side of the question: the value a block, a
routine or a loop gives back when it *is* used.

## A value nobody uses has its `sink` method called

Any class can define a `sink` method, and it runs when an object of the
class ends up in sink context. A class that prints when it is sunk makes the
rule visible; the examples in this chapter use it.

```raku
class Noisy {
    has $.name;
    method sink { say "sunk $!name" }
}
Noisy.new(name => "a");
my $kept = Noisy.new(name => "b");
Noisy.new(name => "c").name;
my @list = Noisy.new(name => "d");
Noisy.new(name => "e");
```
```output
sunk a
sunk e
```

Assignment uses a value, so `b` and `d` are not sunk. In the third statement
the object is the invocant of `.name`, and the method call uses it; what is
sunk is the string the method returns. The last statement of the program is
sunk like any other.

## A block whose value is unused sinks its last statement

A block's value is the value of its last statement. When nothing uses the
block's value, as with the body of `if`, `for` or `given`, or a bare block
written as a statement, that last statement is sunk. When the value is kept,
as with `do` or `try` on the right of an assignment, it is not.

```raku
class Noisy { has $.name; method sink { say "sunk $!name" } }
if True { Noisy.new(name => "if") }
for 1 { Noisy.new(name => "for") }
{ Noisy.new(name => "bare block") }
my $v = do { Noisy.new(name => "do") };
my $t = try { Noisy.new(name => "try") };
given Noisy.new(name => "topic") { Noisy.new(name => "given") }
say $v.name, " ", $t.name;
```
```output
sunk if
sunk for
sunk bare block
sunk given
do try
```

The topic of `given` is not sunk: `given` uses it to set `$_`. The bodies of
`while` and `loop` are sunk in the same way. The body of `for` has
exceptions, described in
[The last value of a `for` body is not always sunk](#ch:sink:the-last-value-of-a-for-body-is-not-always-sunk).

## A call that stands alone sinks the value it returns

A routine hands its value back to the caller, and the caller decides whether
to use it. A call written as a statement sinks it, whether the routine
returned it as its last statement or with `return`. Inside the routine,
every statement but the last is sunk as usual.

```raku
class Noisy { has $.name; method sink { say "sunk $!name" } }
sub make($n)  { Noisy.new(name => $n) }
sub early($n) { return Noisy.new(name => $n) }
sub two       { Noisy.new(name => "not last"); make("kept") }
make("implicit");
early("explicit");
my $kept = two();
```
```output
sunk implicit
sunk explicit
sunk not last
```

## A sunk operator sinks its result, not its condition

`?? !!`, `||`, `&&` and `andthen` each return one of their operands. When the
whole expression is sunk, the operand that becomes its result is sunk with
it. An operand that was only tested is not: the condition of `?? !!`, the
left side of `&&` when it is true, the left side of `andthen`.

```raku
class Noisy { has $.name; method sink { say "sunk $!name" } }
sub one { 1 }
Noisy.new(name => "condition") ?? one() !! one();
one() ?? Noisy.new(name => "branch") !! one();
Noisy.new(name => "left of ||") || one();
Noisy.new(name => "left of &&") && one();
one() andthen Noisy.new(name => "right of andthen");
```
```output
sunk branch
sunk left of ||
sunk right of andthen
```

A new object is true, so `||` returns it and it is sunk, while `&&` goes on
to its right side and returns that instead.

## `//` never sinks its left side
tags: quirk

`//` returns its left side when that side is defined, just as `||` returns a
true one. Rakudo nevertheless leaves the left side of `//` unsunk, although
`or` and `orelse`, the loose forms of `||` and `//`, both sink theirs:

```raku
class Noisy { has $.name; method sink { say "sunk $!name" } }
sub one { 1 }
Noisy.new(name => "left of ||") || one();
Noisy.new(name => "left of or") or one();
Noisy.new(name => "left of //") // one();
Noisy.new(name => "left of orelse") orelse one();
```
```output
sunk left of ||
sunk left of or
sunk left of orelse
```

The consequence that matters is for processes: the `Proc` of a failed
command on the left of `//` goes unchecked (see
[A failed process throws when its `Proc` is sunk](#ch:sink:a-failed-process-throws-when-its-proc-is-sunk)).

## A sunk list sinks every element; a sunk `xx` sinks none

A parenthesised list written as a statement sinks each of its elements, and
a statement-modifier `for` sinks its expression once per iteration. `xx`
evaluates its left side once per repetition, but a sunk `xx` sinks none of
the results.

```raku
class Noisy { has $.name; method sink { say "sunk $!name" } }
(Noisy.new(name => "first"), Noisy.new(name => "second"));
Noisy.new(name => "repeated") xx 2;
Noisy.new(name => "modifier") for 1, 2;
```
```output
sunk first
sunk second
sunk modifier
sunk modifier
```

## The compiler reports sunk values that cannot matter

Before the program runs, the compiler examines each sunk expression. A
literal, a variable or an operator without side effects can do nothing in
sink context, so the compiler reports it as *useless*. The report is a
warning, not an error, and the program runs. The typical case is a value
that was meant to be returned or assigned:

```raku
sub double($x) {
    $x * 2;
    say "doubled";
}
double(21);
```
```output
doubled
```
```stderr
WARNINGS for example.raku:
Useless use of "*" in expression "$x * 2" in sink context (line 2)
```

The reports are collected in one block, headed `WARNINGS for` and the file
name, and each ends with the lines where the expression occurs. When a
program earns several different reports, their order changes from one run
to the next. The wording names the kind of value that was wasted:

| sunk statement | reported as "Useless use of … in sink context" |
|---|---|
| `42;` | `constant integer 42` |
| `1.5;` | `constant rational 1.5` |
| `1e0;` | `constant floating-point number 1e0` |
| `"a";` | `constant string "a"` |
| `<a b>;` | `constant value a b` |
| `Empty;` | `constant value Empty` |
| `True;` | `constant integer True` |
| `Int;` | `constant integer Int` |
| `$x;` (also `@a;`, `%h;`, `&f;`, `$_;`) | `$x` |
| `$x + 1;` | `"+" in expression "$x + 1"` |
| `so 1;` | `"so " in expression "so 1"` |
| `1 ... 3;` | `...` |
| `();` | `()` |
| `now;` | `'now'` |
| `[+] 1, 2;` | `[+]` |

`True` and the type object `Int` are both called a "constant integer".

## Calls, method calls and assignments are never reported

The compiler cannot know what a call does, so it never reports one, even
when its value is certainly thrown away. Method calls, subscripts,
smartmatches, `//`, `Nil` and anything that changes a variable are silent
too:

```raku
my $x = 5;
my @a = 1, 2;
$x.abs;
@a[0];
$x ~~ Int;
$x // 0;
Int.new;
Nil;
$x++;
say "no warnings";
```
```output
no warnings
```

A statement modifier behaves unevenly. The expression before a `for`
modifier is never reported, but the expression before an `if` modifier is:

```raku
my $x = 5;
$x + 1 for 1;
$x + 1 if $x;
say $x;
```
```output
5
```
```stderr
WARNINGS for example.raku:
Useless use of "+" in expression "$x + 1" in sink context (line 3)
```

## Each unused branch is reported, except the right side of `//`

A sunk `?? !!`, `||`, `&&`, `and` or `andthen` sinks whichever operand it
returns, so the compiler checks every operand that could be returned. A
literal fallback after `||` is reported; the same fallback after `//` is
not:

```raku
my $x = 0;
$x || "default";
$x // "default";
say $x;
```
```output
0
```
```stderr
WARNINGS for example.raku:
Useless use of constant string "default" in sink context (line 2)
```

A ternary with two literal branches gets one report for each branch.

## `no worries` does not silence a "Useless use"
tags: quirk

Rakudo has two kinds of compile-time complaints. *Potential difficulties*,
such as declaring the same variable twice, are worries, and the
`no worries` pragma turns them off. The "Useless use" reports are printed in
their own `WARNINGS` block, and `no worries` does not reach them:

```raku
no worries;
my $a = 1;
my $a = 2;
42;
say $a;
```
```output
2
```
```stderr
WARNINGS for example.raku:
Useless use of constant integer 42 in sink context (line 4)
```

The redeclaration on line 3 passes without a word. `quietly`, which
silences warnings issued at run time, does not help either: `quietly 42;` is
still reported. A bare block written as a statement runs at once and its
value is unused, so a literal at its end is reported too: `{ 42 };`.

## Only a bare block runs where it stands
tags: trap

A bare block written as a statement is executed where it stands. A pointy
block and an anonymous sub are values, a `Block` and a `Sub`, and a value in
sink context is thrown away without being called:

```raku
sub { say "anonymous" };
-> { say "pointy" };
{ say "bare" };
```
```output
bare
```
```stderr
WARNINGS for example.raku:
Useless use of anonymous sub, did you forget to provide a name? (line 1)
```

The compiler asks about the anonymous sub, but says nothing about the pointy
block that never ran.

## Everything after an item assignment's comma is sunk
tags: trap

Item assignment, `=` with a `$` target, binds tighter than the comma, so the
comma list around it is built after the assignment and then sunk (see
[Who Takes the Operand](#ch:precedence)). The whole right-hand side of an
item assignment is parsed at that tight level. An array assignment nested
inside it is therefore not a list assignment, and it does not collect the
list either:

```raku
my @a;
my $y = @a = 2, 3;
say @a.raku;
say $y.raku;
```
```output
[2]
$[2]
```
```stderr
WARNINGS for example.raku:
Useless use of constant integer 3 in sink context (lines 2, 2)
```

The one `3` is reported twice. Binding with `:=` is not assignment, and it
takes the whole list. A call without parentheses takes the whole comma list
as its arguments, so nothing is left over to sink:

```raku
my $x := 1, 2;
say $x.raku;
my $y;
say $y = 3, 4;
say $y;
```
```output
(1, 2)
34
3
```

When the leftover list feeds a list operator such as `Z`, the operator is
reported, and the expression the report quotes is a fragment of the line
rather than the code that was sunk:

```raku
my $x;
$x = 10, 20 Z 30, 40;
say $x;
```
```output
10
```
```stderr
WARNINGS for example.raku:
Useless use of "Z" in expression ", 20 Z 30," in sink context (line 2)
```

What was sunk is `(($x = 10), 20) Z (30, 40)`.

## A sunk Failure throws its exception

`fail` returns a `Failure`: an undefined value that carries an exception.
Kept in a variable, it waits. Sunk, it throws, and an uncaught throw ends
the program with the message and a backtrace from where `fail` was called:

```raku
sub parse($s) { fail "cannot parse '$s'" }
my $r = parse("abc");
say $r.^name;
parse("xyz");
say "not reached";
```
```output
Failure
```
```stderr
cannot parse 'xyz'
  in sub parse at example.raku line 1
  in block <unit> at example.raku line 4

```

This is what makes `fail` safe: a caller that ignores the result by calling
the routine as a statement gets the exception, as if the routine had used
`die`. The stored Failure in `$r` never throws, because it is never sunk.

## Testing a Failure marks it handled, and then it sinks quietly

Asking a Failure whether it is true or defined counts as dealing with it.
The Failure becomes *handled*, and sinking it no longer throws. The
`.handled` method reports the state; it can also be assigned to.

```raku
sub parse($s) { fail "cannot parse '$s'" }
my $r = parse("abc");
say $r.handled;
say $r.defined;
say $r.handled;
sink $r;
say "sinking a handled Failure is silent";
```
```output
False
False
True
sinking a handled Failure is silent
```

The mark belongs to the Failure object, so a test through another variable
that holds the same Failure counts. Looking at a Failure without testing it
does not:

```raku
sub parse($s) { fail "cannot parse '$s'" }
my $r = parse("abc");
my $alias = $r;
say $alias ?? "true" !! "false";
say $r.handled;
my $s = parse("def");
say $s ~~ Failure;
say $s.exception.message;
say $s.handled;
```
```output
false
True
True
cannot parse 'def'
False
```

`.so`, `.Bool`, `.defined`, `!`, `if`, `with`, `?? !!`, `||`, `//`,
`andthen` and `orelse` all mark a Failure handled. A smartmatch, including a
`when`, and `.exception`, `.^name`, `.raku` and `.WHAT` do not. A Failure
that has thrown once is handled from then on.

## A handled Failure is `NaN` as a number and "(HANDLED)" as a string
tags: trap

Handling disarms the sink, not the value. An unhandled Failure used as a
number or a string throws. A handled one used the same way does not throw:
it answers `NaN` as a number, and as a string its message after
`(HANDLED)`, followed by the backtrace. `.Int` gives the `Int` type object.
Other uses, such as `.chars` or `.elems`, still throw.

```raku
sub parse($s) { fail "cannot parse '$s'" }
my $u = parse("xyz");
say (try { $u + 1 }) // "unhandled: threw";
my $r = parse("abc");
say $r // "fallback";
say $r + 1;
say $r.Str.lines[0];
say $r.Int.raku;
say (try $r.chars) // "chars: threw";
```
```output
unhandled: threw
fallback
NaN
(HANDLED) cannot parse 'abc'
Int
chars: threw
```

`.lines[0]` keeps the first line of the string; the rest is the backtrace.
A test that handles the Failure should therefore also supply the value to
use instead, as `$r // "fallback"` does, rather than leave the Failure in
place to be computed with.

## Inside `try`, a Failure throws as soon as a call returns it
tags: trap

A `try` block turns on the `fatal` pragma for its body. Under `use fatal`, a
Failure returned by a call throws at once, before it can be stored. Only a
boolean test in the same expression gets to it first: `//`, `||`, `?? !!`,
`if` or `so`. A `.defined`, a `with` or an `orelse` comes too late:

```raku
sub parse($s) { fail "cannot parse '$s'" }
my $outside = parse("a");
say "outside: ", $outside.defined;
try {
    my $inside = parse("b");
    say "not reached";
}
say "caught: ", $!.message;
say try { parse("c") // "fallback" };
try { with parse("d") { say "defined" } else { say "undefined" } }
say "with: ", $!.message;
```
```output
outside: False
caught: cannot parse 'b'
fallback
with: cannot parse 'd'
```

The same `with` outside the `try` would print `undefined`.

## A failed process throws when its `Proc` is sunk

`run` and `shell` return a `Proc`. When the command fails, with a non-zero
exit code or killed by a signal, sinking its Proc throws
`X::Proc::Unsuccessful`. A Proc kept in a variable can be examined without
throwing: `.exitcode`, `.signal`, and `.so`, which is `False` for a failed
command.

```raku local
my $p = run "false";
say $p.exitcode;
say $p.so;
run "false";
say "not reached";
```
```output
1
False
```
```stderr
The spawned command 'false' exited unsuccessfully (exit code: 1, signal: 0)
  in block <unit> at example.raku line 4

```

A command that cannot be started at all counts as failed, with exit code
-1. A command killed by a signal has exit code 0 and the signal number in
`.signal`. The exception's `.proc` is the failed Proc:

```raku local
my $missing = run "no-such-command-here";
say $missing.exitcode;
my $killed = run "sh", "-c", 'kill -9 $$';
say $killed.exitcode, " ", $killed.signal;
try sink $killed;
say $!.^name, ": ", $!.proc.signal;
```
```output
-1
0 9
X::Proc::Unsuccessful: 9
```

A command that exits with 0 is never a problem: its Proc sinks quietly.

## `.out.close` sinks the `Proc`; `.slurp(:close)` does not
tags: trap

With `:out`, a command's exit code is known only once its output has been
read and the handle closed. `.close` on that handle returns the Proc, so
`$p.out.close` as a statement sinks it, and a failure throws there.
`.slurp(:close)` closes the handle as well, but it returns the text, and the
Proc behind it is never sunk:

```raku local
my $text = run("sh", "-c", "echo partial; exit 3", :out).out.slurp(:close);
say $text.trim;
my $p = run "sh", "-c", "echo partial; exit 3", :out;
say $p.out.slurp.trim;
$p.out.close;
say "not reached";
```
```output
partial
partial
```
```stderr
The spawned command 'sh' exited unsuccessfully (exit code: 3, signal: 0)
  in block <unit> at example.raku line 5

```

The first command failed as well, and nothing said so.

## A `Proc` stays armed however often it is tested

A Proc has no handled state. Reading `.exitcode` or `.so` does not disarm
it, a first throw does not either, and every later sink throws again. Only
an operator that returns something else keeps it out of sink context: `||`
goes on to its right side when the Proc is false, while `&&` returns the
false Proc, which is then sunk.

```raku local
my $p = run "false";
say $p.so;
say (try { sink $p; "silent" }) // "threw";
say (try { sink $p; "silent" }) // "threw";
run("false") || say "|| moved on";
say (try { run("false") && say "never"; "silent" }) // "&& threw";
```
```output
False
threw
threw
|| moved on
&& threw
```

## `try { run … }` does not catch a failed process
tags: trap

The last statement of a `try` block is the block's value, and when the
`try` is a statement, that value is sunk after the `try` has finished,
outside its protection. A failed Proc at the end of a `try` block escapes:

```raku local
my $p = try { run "false" };
say $p.exitcode;
try { run "false" }
say "not reached";
```
```output
1
```
```stderr
The spawned command 'false' exited unsuccessfully (exit code: 1, signal: 0)
  in block <unit> at example.raku line 3

```

Assigning the result, as on the first line, avoids the sink. To catch the
failure instead, sink the Proc inside the `try`:

```raku local
try sink run "false";
say "caught: ", $!.^name;
try { run "false"; Nil }
say "caught: ", $!.^name;
```
```output
caught: X::Proc::Unsuccessful
caught: X::Proc::Unsuccessful
```

A Failure at the end of a `try` block has no such problem, because
`use fatal` throws it inside the block.

## The last value of a `for` body is not always sunk
tags: quirk

The last statement of a `for` loop's block is sunk when the block is a plain
one. When the block has a signature, `-> $x { … }`, a method call at its end
is sunk but a sub call is not. Inside a `try` block, or anywhere under
`use fatal`, the plain block's last statement is not sunk either.

```raku
class Noisy { has $.name; method sink { say "sunk $!name" } }
sub make($name) { Noisy.new(:$name) }
for 1 { make("block, sub call") }
for 1 -> $x { make("pointy block, sub call") }
for 1 -> $x { Noisy.new(name => "pointy block, method call") }
try { for 1 { make("block inside try") }; Nil }
```
```output
sunk block, sub call
sunk pointy block, method call
```

`run` is a sub, so the usual way of running a list of commands ignores their
failures, and so does any sub that returns a Failure. A `sink` prefix on the
call restores the check:

```raku local
for <true false> -> $cmd { run $cmd }
say "the failure went unnoticed";
for <true false> -> $cmd { sink run $cmd }
say "not reached";
```
```output
the failure went unnoticed
```
```stderr
The spawned command 'false' exited unsuccessfully (exit code: 1, signal: 0)
  in block <unit> at example.raku line 3

```

## A sunk `Seq` runs to the end, even a lazy one

A `Seq` computes its values only when they are asked for. Sinking one asks
for all of them, so a sunk `map` or `gather` runs its block for every
element, even when the Seq is marked lazy. A stored Seq has not run yet, and
sinking it later runs it.

```raku
my $n = 0;
(1..3).map({ $n++ });
say $n;
$n = 0;
my $s = (1..3).map({ $n++ });
say $n;
sink $s;
say $n;
$n = 0;
lazy (1..3).map({ $n++ });
say $n;
```
```output
3
0
3
3
```

Turning a Seq into a list with `.list` or `.cache` does not run it, and a
truth test runs it for one element only:

```raku
my $n = 0;
(1..3).map({ $n++ }).list;
say $n;
say so (1..3).map({ $n++ });
say $n;
```
```output
0
True
1
```

A Seq returned by a sub, with or without `return`, runs when the call is
sunk. A sunk infinite Seq, such as `(1..*).map({ … })`, never returns. The
values the Seq produces are discarded without being sunk themselves, so a
`map` that runs commands ignores their failures, as a `for` loop with a
pointy block does:

```raku
class Noisy { has $.name; method sink { say "sunk $!name" } }
my $n = 0;
(1, 2).map({ $n++; Noisy.new(name => "element $_") });
say $n;
```
```output
2
```

## A routine's value is its last statement's, and a loop's is `Nil`

A routine without `return` gives back the value of its last statement. A
loop there gives `Nil`: its body's values are sunk, not collected. `do for`
collects them into a list instead. An `if` or `unless` whose block did not
run gives `Empty`, a Slip that vanishes from any list it lands in, while the
`Nil` of a loop stays:

```raku
sub doubled { for 1..3 { $_ * 2 } }
sub collect { do for 1..3 { $_ * 2 } }
sub skipped { if False { 1 } }
sub chosen  { if True { 1, 2 } }
say doubled().raku;
say collect().raku;
say skipped().raku;
say chosen().raku;
say (0, doubled(), 9).raku;
say (0, skipped(), 9).raku;
```
```output
Nil
(2, 4, 6)
Empty
(1, 2)
(0, Nil, 9)
(0, 9)
```

An empty routine gives `Nil`, a final assignment gives what was assigned,
and `do while` collects into a Seq rather than a list:

```raku
sub nothing  { }
sub assigned { my @a = 1, 2 }
sub counted  { my $i = 0; do while $i < 3 { $i++ } }
say nothing().raku;
say assigned().raku;
say counted().raku;
```
```output
Nil
[1, 2]
(0, 1, 2).Seq
```

## A `given` without a matching `when` gives `False`, not `Nil`
tags: trap

A `given` block as the last statement of a routine is a common way to pick a
result. When no `when` matches and there is no `default`, the block's value
is that of its last statement, the last `when`, and a `when` that did not
match gives the result of its smartmatch, `False`. With an undefined topic
it gives `0` instead.

```raku
sub name-of($n) {
    given $n {
        when 1 { "one" }
        when 2 { "two" }
    }
}
say name-of(1).raku;
say name-of(3).raku;
say name-of(Any).raku;
say (1, 5, 2).map(&name-of).raku;
```
```output
"one"
Bool::False
0
("one", Bool::False, "two").Seq
```

A `default { Nil }` at the end makes the no-match case give `Nil`.

## `return $x` keeps the container that a last statement drops
tags: quirk

A value that comes from a routine's last statement is decontainerised:
`.VAR` on the result shows the value itself. With `return $x`, `.VAR` shows
a `Scalar`. It is a read-only copy, not the variable, so the difference
shows only in introspection and in the message when the result is assigned
to:

```raku
sub implicit { my $x = 5; $x }
sub explicit { my $x = 5; return $x }
say implicit().VAR.^name;
say explicit().VAR.^name;
try { implicit() = 6 }; say $!.message;
try { explicit() = 6 }; say $!.message;
```
```output
Int
Scalar
Cannot modify an immutable Int (5)
Cannot assign to a readonly variable or a value
```

## The `sink` prefix runs a statement and gives `Nil`

`sink` in front of a statement evaluates all of it, sinks the result and
returns `Nil`. It runs a Seq to the end, calls a bare block, and makes a
Failure or a failed Proc throw. On an ordinary value the `.sink` method
does nothing and also returns `Nil`.

```raku
my $n = 0;
my $r = sink (1..3).map({ $n++ });
say $r.raku;
say $n;
my $calls = 0;
sink { $calls++ };
say $calls;
say (sink 2 + 3).raku;
say 42.sink.raku;
say [1, 2].sink.raku;
```
```output
Any
3
1
Nil
Nil
Nil
```

`my $r = sink …` assigns `Nil`, which leaves `$r` holding `Any`. A routine
whose last statement starts with `sink` returns `Nil`, whatever the
statement computes. The compiler still reports a literal after `sink`,
though not a variable or an operator:

```raku
my $x = 5;
sink $x;
sink $x + 1;
sink 42;
say "end";
```
```output
end
```
```stderr
WARNINGS for example.raku:
Useless use of constant integer 42 in sink context (line 4)
```
