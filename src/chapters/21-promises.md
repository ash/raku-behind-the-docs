---
title: Promises, Locks and Awaiting
part: Concurrency
summary: What keeps and breaks a Promise, what `start`, `then` and `await` hand on and throw, how Channels, locks and semaphores behave between threads, and what `sleep` answers.
---

A `Promise` is a value that is not there yet. It starts out *Planned*, and
later somebody either *keeps* it with a result or *breaks* it with a cause,
once. `start` runs a block on Rakudo's thread pool and returns a Promise
for the block's value; `await` waits for a Promise and hands over its
result, or throws when it was broken. Around those two sit the tools for
code that runs on several threads at once: `then` to chain work, `Channel`
to pass values from thread to thread, `Lock`, `Lock::Async` and `Semaphore`
to take turns, and the scheduler that runs it all.

Most examples in this chapter start threads, sleep or use timers, so they
are marked to be run locally. Their output does not depend on timing: where
threads race, the example waits in a fixed order or sorts what it collects.
Everything is Raku 6.d, the default; where a `use v6.c` file behaves
differently, the corner says so. Supplies, `react` and `whenever` are in
[Supplies](#ch:supplies), `Proc::Async` in [Processes](#ch:processes), and
exceptions in general in [Exceptions and Failures](#ch:exceptions).

## A Promise is false until it is kept or broken

A new Promise has the status `Planned`. `.status` returns a value of the
enumeration `PromiseStatus`: `Planned`, `Kept` or `Broken`, numbered 0, 1
and 2. The Promise itself is false while it is Planned and true once it is
resolved, kept or broken, whatever the result. `Planned` is false as well,
because its number is 0.

```raku
my $p = Promise.new;
say $p.status, " ", $p.so;
$p.keep(0);
say $p.status, " ", $p.so;
say ?Planned, " ", ?Kept, " ", ?Broken;
say $p ~~ Kept;
say $p.status ~~ Kept;
```
```output
Planned False
Kept True
False True True
False
True
```

A smartmatch against a status must be given the status: the Promise itself
never matches `Kept`.

## `say` on a Promise shows its status, not its value
tags: trap

The gist of a Promise names its scheduler and its status. The result is not
part of it, so printing a Promise never shows what it holds; `.result` does.

```raku
my $p = Promise.kept(42);
say $p;
say $p.result;
say PromiseStatus.enums;
say PromiseStatus(2);
```
```output
Promise.new(scheduler => ThreadPoolScheduler.new(uncaught_handler => Callable), status => PromiseStatus::Kept)
42
Map.new((Broken => 2, Kept => 1, Planned => 0))
Broken
```

`PromiseStatus(2)` turns a number into a status; a name, as in
`PromiseStatus("Kept")`, is refused with `X::Enum::NoValue`.

## `keep` stores exactly its argument, and `True` when there is none

`keep` with no argument keeps the promise with `True`. With an argument it
stores that value as it is: Nil stays Nil, a type object stays a type
object, a Slip stays a Slip. `keep` itself returns Nil. `Promise.kept`
builds a promise that is kept already, with `True` or with its argument.

```raku
my $p = Promise.new;
say $p.keep.raku;
say $p.result.raku;
sub kept-with(\value) { my $q = Promise.new; $q.keep(value); $q.result }
say kept-with(Nil).raku;
say kept-with(Int).raku;
say kept-with((1, 2).Slip).raku;
say Promise.kept.result, " ", Promise.kept("value").result;
say Promise.kept(False).so;
```
```output
Nil
Bool::True
Nil
Int
slip(1, 2)
True value
True
```

The last line is the rule of the first corner again: a promise kept with
`False` is a true Promise.

## `break` without a cause breaks with "Died", not False
tags: undocumented

docs.raku.org says that a `break` without an argument leaves the cause
`False`. Rakudo, and the tests of the language, give an `X::AdHoc` whose
message is "Died". Any cause that is not an exception is wrapped in an
`X::AdHoc`, with the value as its payload, so an explicit `False` is not
stored as `False` either. An exception object is stored as it is.

```raku
my $p = Promise.new;
say $p.break.raku;
say $p.cause.^name, ": ", $p.cause.message;
sub broken-with(\cause) { my $q = Promise.new; $q.break(cause); $q.cause }
say broken-with("glass").raku;
say broken-with(False).raku;
my $e = X::NYI.new(feature => "flight");
say broken-with($e) === $e;
say Promise.broken.cause.message, " ", Promise.broken("glass").cause.message;
```
```output
Nil
X::AdHoc: Died
X::AdHoc.new(payload => "glass")
X::AdHoc.new(payload => Bool::False)
True
Died glass
```

An exception *type* is stored as it is too, which leaves a cause that is
undefined. Asking such a promise for its result then fails inside Rakudo,
with an error about `but` that has nothing to do with the promise:

```raku
my $t = Promise.broken(X::NYI);
say $t.cause.raku, " ", $t.cause.defined;
try $t.result;
say $!.^name;
```
```output
X::NYI False
X::Multi::NoMatch
```

## `.cause` refuses a promise that is not broken

Only a broken promise has a cause. Asking a Planned or a kept one throws
`X::Promise::CauseOnlyValidOnBroken`, whose `.status` says what the promise
was instead. It does not wait for the promise to be resolved.

```raku
try Promise.new.cause;
say $!.^name;
say $!.message;
try Promise.kept(1).cause;
say $!.status;
```
```output
X::Promise::CauseOnlyValidOnBroken
Can only call cause on a broken promise (status: Planned)
Kept
```

## `.result` waits, then rethrows a copy of the cause

`.result` blocks until the promise is resolved. For a kept promise it
returns the result. For a broken one it throws, but not the cause itself: it
throws a copy with the role `X::Promise::Broken` mixed in. The copy still
matches the original type, keeps the message and the type's own attributes,
and adds a `.result-backtrace`. The cause in the promise stays a plain
exception, and every `.result` makes a new copy.

```raku
my $p = Promise.broken("oh no");
try $p.result;
say $!.^name;
say $! ~~ X::AdHoc, " ", $!.message;
say $! === $p.cause, " ", $p.cause.^name;
say $!.result-backtrace.^name;
my $copy = $!;
try $p.result;
say $! === $copy;
my $q = Promise.broken(X::NYI.new(feature => "levitation"));
try $q.result;
say $!.^name, ": ", $!.feature;
```
```output
X::AdHoc+{X::Promise::Broken}
True oh no
False X::AdHoc
Backtrace
False
X::NYI+{X::Promise::Broken}: levitation
```

Uncaught, the role changes the report: it says where the result was asked
for, then gives the original exception with the backtrace of the thread
where it was thrown.

```raku local
my $p = start { die "in the thread" };
say $p.result;
```
```output
```
```stderr
Tried to get the result of a broken Promise
  in block <unit> at example.raku line 2

Original exception:
    in the thread
      in block  at example.raku line 1

```

`await` wears a different role; see
[`await` and `.result` rethrow with different roles](#ch:promises:await-and-result-rethrow-with-different-roles).

## A promise is resolved once, and the refusal names a vow

Whoever keeps or breaks a promise first takes its *vow*, the sole right to
resolve it. A second `keep` or `break` is refused with `X::Promise::Vowed`,
even when the program never asked for a vow. `.vow` takes the vow
explicitly and returns a `Promise::Vow`, an object with `.keep`, `.break`
and `.promise`; the promise's own methods are refused from then on. Keeping
through the vow a second time throws `X::Promise::Resolved`.

```raku
my $p = Promise.new;
$p.keep(1);
try $p.keep(2);
say $!.^name, ": ", $!.message;
my $q = Promise.new;
my $vow = $q.vow;
say $vow.^name, " ", $vow.promise === $q;
try $q.keep(1);
say $!.^name;
$vow.keep(42);
try $vow.keep(43);
say $!.^name, ": ", $!.message;
say $q.result;
try Promise.new.vow.keep;
say $!.message;
```
```output
X::Promise::Vowed: Access denied to keep/break this Promise; already vowed
Promise::Vow True
X::Promise::Vowed
X::Promise::Resolved: Cannot keep/break a Promise more than once (status: Kept)
42
Too few positionals passed; expected 2 arguments but got 1
```

The last line is a trap of its own: the promise's `keep` has a default
value, the vow's `keep` does not. `Promise::Vow` is a lexical class, not
reachable by that name.

Which exception a late `keep` gets shows who holds the vow. `Promise.kept`
and `Promise.broken` take none, so they answer `X::Promise::Resolved`.
Every promise that Rakudo resolves itself, from `Promise.in`, `start`,
`then`, `anyof` or `allof`, has its vow taken at birth:

```raku local
for Promise.kept, Promise.broken, Promise.in(5), (start { 1 }),
    Promise.kept.then({ 1 }), Promise.allof() -> $p {
    try $p.keep(1);
    say $!.^name;
}
```
```output
X::Promise::Resolved
X::Promise::Resolved
X::Promise::Vowed
X::Promise::Vowed
X::Promise::Vowed
X::Promise::Vowed
```

## `keep` holds on to the variable, not its value
tags: quirk unasserted

`keep`, `Promise.kept` and the value of a `start` block store the
container they are given, not the value in it. Assigning to the variable
after the promise is kept changes what `.result` returns afterwards. A
value made from the variable, such as `+$v`, is safe. The result itself is
read-only.

```raku
my $x = 5;
my $p = Promise.new;
$p.keep($x);
$x = 6;
say $p.result;
my $z = 9;
my $q = Promise.kept($z);
$z = 10;
say $q.result;
my $v = 1;
my $r = Promise.kept(+$v);
$v = 2;
say $r.result;
try { $p.result = 1 };
say $!.^name;
```
```output
6
10
1
X::Assignment::RO
```

A `start` block that ends with a variable does the same, even after it has
finished:

```raku local
my $y = 7;
my $s = start { $y };
await $s;
$y = 8;
say await $s;
```
```output
8
```

## `eqv` compares results, so it waits for them
tags: quirk undocumented

`===` on two promises asks whether they are the same object. `eqv` compares
their results instead: two different promises kept with equal values are
`eqv`. To get the results it has to wait for them, so `eqv` on a Planned
promise blocks, and a broken one makes it throw.

```raku local
say Promise.kept(1) eqv Promise.kept(1);
say Promise.kept(1) === Promise.kept(1);
say Promise.kept(1) eqv Promise.kept("1");
say (try Promise.kept(1) eqv Promise.broken("x")) // $!.^name;
my ($p, $q) = Promise.new, Promise.new;
my $compare = start { $p eqv $q };
await Promise.anyof($compare, Promise.in(0.2));
say $compare.status;
```
```output
True
False
False
X::AdHoc+{X::Promise::Broken}
Planned
```

The comparison in the `start` block never returns, because nobody keeps
`$p` or `$q`.

## A `then` block receives the promise, not its result
tags: trap

`.then` registers code to run once the promise is resolved, and returns a
new promise for that code's value. The code gets the *original promise* as
its argument, so in a bare block `$_` is a Promise and the value is
`.result`. The code runs for a broken promise too, where `.result` would
throw and `.cause` is what it can read. Code that dies breaks the new
promise, with the exception as a plain `.cause`.

```raku local
my $p = Promise.kept(42);
say await $p.then({ .^name });
say await $p.then(-> $promise { $promise.result + 1 });
say await Promise.broken("bad input").then({ .status ~ ": " ~ .cause.message });
my $d = Promise.kept(1).then({ die "the then died" });
try await $d;
say $d.status, " ", $d.cause.^name, " ", $!.message;
```
```output
Promise
43
Broken: bad input
Broken X::AdHoc the then died
```

## Each `then` makes a new promise, and one promise can have many

`.then` never returns the promise it was called on. Several `then` blocks
on one promise all run when it is resolved, and a `then` on a `then` makes
a chain. The value of the code keeps the new promise as it is, a List
included. Code that cannot take one argument breaks the new promise; a
value that is not code is refused at once.

```raku local
my $p = Promise.new;
my $t = $p.then({ .result + 1 });
my $u = $p.then({ .result * 10 });
say $t === $p, " ", $t.status;
$p.keep(5);
say await $t, $u;
say await Promise.kept(1).then({ .result + 1 }).then({ .result * 10 });
say (await Promise.kept(1).then({ (1, 2) })).raku;
try await Promise.kept(1).then(-> $a, $b { 1 });
say $!.message;
try Promise.kept(1).then(42);
say $!.^name;
```
```output
False Planned
(6 50)
20
(1, 2)
Too few positionals passed; expected 2 arguments but got 1
X::TypeCheck::Binding::Parameter
```

The `then` blocks run on the thread pool, in no promised order; `await`
collects their results in the order it is given.

## `then(:synchronous)` runs inside `keep`, and may return a plain value
tags: undocumented unasserted

With `:synchronous`, the code of a `then` does not go to the thread pool.
It runs on the thread that resolves the promise, inside the call to `keep`
or `break`, in the order the `then` blocks were added. On a promise that is
resolved already, the code runs at once, and `.then` returns the code's
value itself instead of a Promise.

```raku local
my @log;
my $p = Promise.new;
$p.then({ @log.push("first then") }, :synchronous);
$p.then({ @log.push("second then") }, :synchronous);
@log.push("before keep");
$p.keep;
@log.push("after keep");
say @log;
say Promise.kept(1).then({ .result + 1 }).^name;
say Promise.kept(1).then({ .result + 1 }, :synchronous).raku;
try Promise.kept(1).then({ die "at once" }, :synchronous);
say $!.^name, ": ", $!.message;
```
```output
[before keep first then second then after keep]
Promise
2
X::AdHoc: at once
```

On a resolved promise, code that dies throws straight to the caller of
`.then`.

## A dying synchronous `then` makes `keep` throw a wrong error
tags: bug

When the code of a synchronous `then` dies while the promise is being
kept, the new promise should be broken with that exception. In Rakudo
2026.08 the `keep` call itself throws an unrelated "Too few positionals"
error. The original promise is kept all the same, the `then` promise stays
Planned for ever, and the synchronous `then` blocks registered after the
dying one never run.

```raku local
my $p = Promise.new;
my $dies  = $p.then({ die "in a synchronous then" }, :synchronous);
my $later = $p.then({ "never runs" }, :synchronous);
try $p.keep(1);
say $!.message;
say $p.status;
await Promise.anyof($dies, $later, Promise.in(0.2));
say $dies.status, " ", $later.status;
my $q = Promise.new;
my $reader = $q.then({ .result }, :synchronous);
try $q.break("bad");
say $!.message, " / ", $q.status, " ", $reader.status;
```
```output
Too few positionals passed; expected 1 argument but got 0
Kept
Planned Planned
Too few positionals passed; expected 1 argument but got 0 / Broken Planned
```

The second case is an ordinary pattern: a `then` that reads `.result` dies
whenever the promise turns out broken.

## `andthen` and `orelse` pick the outcome they handle
tags: undocumented

A Promise has methods `andthen` and `orelse`, besides the operators of the
same names. `.andthen(&code)` runs the code only for a kept promise; for a
broken one the new promise is broken with the very same cause object.
`.orelse(&code)` runs the code only for a broken promise; a kept one passes
its result on. Chains of them work like chains of `then`.

```raku local
sub show($p) {
    try $p.result;
    say $p.status ~~ Kept ?? "kept: " ~ $p.result !! "broken: " ~ $p.cause.message;
}
show Promise.kept(2).andthen({ .result * 10 });
show Promise.broken("bad").andthen({ say "not run" });
show Promise.kept(2).orelse({ say "not run" });
show Promise.broken("bad").orelse({ "recovered from " ~ .cause.message });
my $b = Promise.broken("same");
say $b.andthen({ 1 }).cause === $b.cause;
show Promise.kept(1).andthen({ .result + 1 }).andthen({ die "stop" }).orelse({ "fallback" });
```
```output
kept: 20
broken: bad
kept: 2
kept: recovered from bad
True
kept: fallback
```

## A `start` block sees the outer `$_`, but fresh `$/` and `$!`
tags: trap

A `start` block is a closure: it sees the variables around it, `$_`
included. `$/` and `$!` are the exception: inside `start` they are fresh
and Nil. A closure captures variables, not values, so a `start` in a `for`
loop is safe, because each iteration has a `$_` of its own, while one in a
C-style `loop` shares the single counter with every other iteration.

```raku local
"abc" ~~ /b/;
try die "outer";
$_ = "outer topic";
say await start { $_.raku, $/.raku, $!.raku };
my @p;
for 1..3 { @p.push: start { $_ * 10 } }
say await @p;
my @q;
loop (my $i = 1; $i <= 3; $i++) { @q.push: start { sleep 0.1; $i * 10 } }
say await @q;
```
```output
("outer topic" Nil Nil)
(10 20 30)
(40 40 40)
```

By the time the three blocks in the `loop` read `$i`, the loop has left it
at 4.

## `start` and `then` see the dynamic variables of their creator
tags: undocumented

The code of a `start` and of a `then` runs on another thread, but it sees
the dynamic variables of the place where it was written, and can change
them there. `$*PROMISE` is the promise whose code is running: a `start`
block's own promise, or inside a `then`, the new promise, still Planned
while its code runs. Outside any promise it does not exist.

```raku local
my $*LOG = "main";
await (start { $*LOG ~= " start" }).then({ $*LOG ~= " then" });
say $*LOG;
my $p = start { $*PROMISE };
say (await $p) === $p;
say await Promise.kept.then({ $*PROMISE.status });
say (try $*PROMISE) // $!.^name;
sub helper { $*DEPTH }
my $*DEPTH = 3;
say await start { helper() };
```
```output
main start then
True
Planned
X::Dynamic::NotFound
3
```

## `start` takes an expression, and a dying block breaks its promise

`start` is a statement prefix: it takes a block or any single expression,
so `start 6 * 7` computes the product on the pool. The promise is kept with
the value as it is, a lazy Seq included. A `die` or a `fail` breaks it, and
so does `return`, which has no routine to return from. A CATCH that handles
the exception inside the block keeps the promise with Nil. `Promise.start`
does the same for a Callable and passes any further arguments to it.

```raku local
say await start 6 * 7;
say (await start (0..3).map(* + 1)).raku;
say await Promise.start(-> $a, $b { $a + $b }, 3, 4);
my $f = start { fail "failed in the thread" };
try await $f;
say $f.status, " ", $!.message;
my $c = start { die "x"; CATCH { default { say "handled in the thread" } } };
say (await $c).raku, " ", $c.status;
my $r = start { return 5 };
try await $r;
say $!.^name;
```
```output
42
(1, 2, 3, 4).Seq
7
Broken failed in the thread
handled in the thread
Nil Kept
X::ControlFlow::Return+{X::Await::Died}
```

`Promise.start` also takes `:catch`, a handler that sees the exception
before the promise is broken:

```raku local
my @seen;
my $p = Promise.start({ die "oops" }, :catch({ @seen.push: .message }));
try await $p;
say @seen, " ", $p.status;
```
```output
[oops] Broken
```

## A dying `start` whose promise is sunk ends the program
tags: trap

A `start` used as a statement on its own is in sink context: nobody holds
its promise, so nobody would ever hear that it broke. When such a block
dies, Rakudo prints "Unhandled exception in code scheduled on thread" and
the exception to standard error, and ends the whole program with exit code
1, at the moment of the death. What counts is whether the promise is sunk,
so a sub that returns a `start` arms the report when its call is sunk. A
promise kept in a variable is silent. So is a sunk `start` in a
`use v6.c` file, and so is a `Promise.start` unless it is given
`:report-broken-if-sunk`. A handler in `$*SCHEDULER.uncaught_handler`
receives the exception instead, and the program goes on.

The example runs each case as a separate program, and writes N for the
thread number:

```raku local
sub child($code) {
    my $proc = run $*EXECUTABLE, "-e", $code, :out, :err;
    my $out = $proc.out.slurp(:close).lines.join(",");
    my $err = $proc.err.slurp(:close).lines.head(2).join(" / ").subst(/\d+/, "N");
    say "exit $proc.exitcode() out [$out] err [$err]";
}
child 'start { die "boom" }; sleep 0.2; say "after"';
child 'my $p = start { die "boom" }; sleep 0.2; say "after"';
child 'sub f { start { die "boom" } }; f(); sleep 0.2; say "after"';
child 'sub f { start { die "boom" } }; my $p = f(); sleep 0.2; say "after"';
child 'use v6.c; start { die "boom" }; sleep 0.2; say "after"';
child 'Promise.start({ die "boom" }); sleep 0.2; say "after"';
child 'Promise.start({ die "boom" }, :report-broken-if-sunk); sleep 0.2; say "after"';
child '$*SCHEDULER.uncaught_handler = { say "handled: ", .message }; start { die "boom" }; sleep 0.2; say "after"';
child '$*SCHEDULER.cue({ die "cued" }); sleep 0.2; say "after"';
```
```output
exit 1 out [] err [Unhandled exception in code scheduled on thread N / boom]
exit 0 out [after] err []
exit 1 out [] err [Unhandled exception in code scheduled on thread N / boom]
exit 0 out [after] err []
exit 0 out [after] err []
exit 0 out [after] err []
exit 1 out [] err [Unhandled exception in code scheduled on thread N / boom]
exit 0 out [handled: boom,after] err []
exit 1 out [] err [Unhandled exception in code scheduled on thread N / cued]
```

The last case is code given to the scheduler directly (see
[`cue` returns Nil, and a Cancellation only with a timer](#ch:promises:cue-returns-nil-and-a-cancellation-only-with-a-timer)):
it ends the program the same way.

## `Promise.in` keeps with True after a delay; `Inf` never does

`Promise.in($seconds)` returns a promise that is kept with `True` once the
delay has passed, and `Promise.at($time)` one that is kept at an `Instant`,
a `DateTime` or a number of seconds since the epoch. A delay of zero or
less, or a time in the past, keeps it right away; `Inf` never keeps it;
`NaN` is refused at once. The delay may be any number, a `Duration` or a
numeric string. Rakudo holds the vow, so the promise cannot be kept by
hand.

```raku local
my $p = Promise.in(0.1);
say $p.status;
say $p.result;
say Promise.in(-1).result, " ", Promise.at(now - 100).result;
say Promise.in("0.1").result, " ", Promise.in(Duration.new(0.1)).result;
say Promise.at(DateTime.now.later(seconds => 0.1)).result, " ", Promise.at(now.Num + 0.1).result;
my $never = Promise.in(Inf);
await Promise.anyof($never, Promise.in(0.2));
say $never.status;
try Promise.in(NaN);
say $!.^name;
try Promise.in("soon");
say $!.^name;
try Promise.in(0.1).keep;
say $!.^name;
say Promise.in(Any).result;
```
```output
Planned
True
True True
True True
True True
Planned
X::Scheduler::CueInNaNSeconds
X::TypeCheck::Binding::Parameter
X::Promise::Vowed
True
```
```stderr
Use of uninitialized value of type Any in numeric context
  in block <unit> at example.raku line 16
```

An undefined delay counts as zero, with a warning.

## `anyof` and `allof` count a broken promise as done

`Promise.anyof` returns a promise that is kept once any of its arguments is
resolved, `Promise.allof` one that is kept once all of them are. Both are
kept with `True`, whether the arguments were kept or broken, so their
`.result` never throws: look at the arguments to learn what happened. With
no arguments the combined promise is kept already. Anything that is not a
defined Promise is refused with `X::Promise::Combinator`.

```raku local
my $ok  = Promise.new;
my $bad = Promise.new;
my $any = Promise.anyof($ok, $bad);
my $all = Promise.allof($ok, $bad);
$bad.break("failed");
say $any.result;
say $all.status;
$ok.keep(1);
say $all.result;
say Promise.allof().status;
say Promise.anyof([Promise.kept, Promise.kept]).result;
try Promise.allof(Promise.kept, 42);
say $!.^name, " ", $!.combinator;
```
```output
True
Planned
True
Kept
True
X::Promise::Combinator allof
```

The combined promise is kept by a task on the thread pool, a moment after
the argument that completes it, so read it through `.result` or `await`,
not through `.status`. `anyof` with a `Promise.in` is the usual timeout:
the work that lost the race is still running, and still Planned.

```raku local
my $work = Promise.new;
await Promise.anyof($work, Promise.in(0.1));
say $work.status;
```
```output
Planned
```

## `await` and `.result` rethrow with different roles
tags: undocumented

`await` on a broken promise throws a copy of the cause with the role
`X::Await::Died` mixed in, where `.result` mixes in `X::Promise::Broken`.
The copy matches the original type, including a class of the program's
own, and carries an `.await-backtrace`. Neither copy is the cause itself.
What an uncaught `await` prints is in
[Exceptions and Failures](#ch:exceptions:await-rethrows-a-threads-exception-with-a-role-mixed-in).

```raku
my $p = Promise.broken("oh");
try $p.result;
say $!.^name;
try await $p;
say $!.^name, " ", $!.await-backtrace.^name;
say $! ~~ X::AdHoc, " ", $! === $p.cause;
class X::Mine is Exception { method message { "mine" } }
try await Promise.broken(X::Mine.new);
say $!.^name, " ", $! ~~ X::Mine;
```
```output
X::AdHoc+{X::Promise::Broken}
X::AdHoc+{X::Await::Died} Backtrace
True False
X::Mine+{X::Await::Died} True
```

An exception that already wears `X::Await::Died` is passed on unchanged, so
an `await` of an `await` shows the role once:

```raku local
my $p = Promise.broken("inner");
try await start { await $p };
say $!.^name, ": ", $!.message;
```
```output
X::AdHoc+{X::Await::Died}: inner
```

## `await` on several promises returns their results in argument order

Given several promises, or an array of them, `await` waits for all of them
and returns a List of the results in the order of the arguments, not in the
order they finished. Nested lists are flattened, and so are Slips among the
results. A single promise gives its result alone, not a list of one. One
broken promise anywhere makes the whole `await` throw.

```raku local
my $slow = start { sleep 0.1; "slow" };
my $fast = start { "fast" };
say await $slow, $fast;
say (await ($slow, ($fast, $slow))).raku;
say (await start { (1, 2).Slip }, start { (3, 4).Slip }).raku;
say (await Promise.kept(1)).^name, " ", (await (Promise.kept(1),)).raku;
try await Promise.kept(1), Promise.broken("second");
say $!.message;
```
```output
(slow fast)
("slow", "fast", "slow")
(1, 2, 3, 4)
Int (1,)
second
```

## `await ()` is an empty list; `await()` is an error
tags: trap

An empty list is a fine argument: `await ()` returns `()` at once. A call
with no arguments at all, `await()`, is an error, and so is an undefined
value such as Nil or the `Promise` type object. A defined value that cannot
be awaited, such as a number or a string, is an error that wears the
`X::Await::Died` role.

```raku
say (await ()).raku;
for { await() }, { await Nil }, { await Promise }, { await 42 },
    { await Promise.kept, "text" } -> &code {
    code();
    CATCH { default { say .^name, ": ", .message } }
}
```
```output
()
X::AdHoc: Must specify an Awaitable to await (got an empty list)
X::AdHoc: Must specify a defined Awaitable to await (got an undefined Nil)
X::AdHoc: Must specify a defined Awaitable to await (got an undefined Promise)
X::AdHoc+{X::Await::Died}: Can only specify Awaitable objects to await (got a Int)
X::AdHoc+{X::Await::Died}: Can only specify Awaitable objects to await (got a Str)
```

In a `use v6.c` file, `await 42` is a plain `X::AdHoc`, without the role.

## `await` on the thread pool does not hold on to its thread

In Raku 6.d, code running on the thread pool that reaches `await` gives its
thread back to the pool until the promise is resolved. A tree of `start`
blocks in which every level awaits its children therefore completes even
on a pool of four threads:

```raku local
PROCESS::<$SCHEDULER> := ThreadPoolScheduler.new(max_threads => 4);
sub fib($n) {
    start { $n <= 1 ?? 1 !! await(fib($n - 2)) + await(fib($n - 1)) }
}
say await fib(10);
say $*SCHEDULER.max_threads;
```
```output
89
4
```

The `await` of 6.c blocks its thread. The same program with `use v6.c`
at the top fills the four threads with blocks that wait for children that
can never be scheduled, and it does not return:

```raku nocheck
use v6.c;
PROCESS::<$SCHEDULER> := ThreadPoolScheduler.new(max_threads => 4);
sub fib($n) {
    start { $n <= 1 ?? 1 !! await(fib($n - 2)) + await(fib($n - 1)) }
}
say await fib(10);
```

## `await` refuses a Junction, and `break` autothreads over one
tags: quirk undocumented

`await` does not autothread: a Junction of promises is refused as a value
that cannot be awaited. A method called on a Junction of promises
autothreads as usual. `keep` takes a Junction as an ordinary value. `break`
does not: it autothreads, breaks the promise with the first eigenstate, and
then throws when it tries to break it again with the second.
`Promise.broken` stumbles in the same way, with `X::Promise::Resolved`.

```raku
my ($a, $b) = Promise.kept(1), Promise.kept(2);
try await $a | $b;
say $!.message;
say ($a | $b).result;
my $k = Promise.new;
$k.keep(1 | 2);
say $k.result;
my $p = Promise.new;
try $p.break(1 | 2);
say $!.^name, " ", $p.cause.payload;
try Promise.broken(1 | 2);
say $!.^name;
```
```output
Can only specify Awaitable objects to await (got a Junction)
any(1, 2)
any(1, 2)
X::Promise::Vowed 1
X::Promise::Resolved
```

## A Channel queues values until they are received

A `Channel` is a queue that many threads may send to and receive from.
`.send` adds a value, `.receive` takes the oldest one, waiting if there is
none, and `.poll` takes one or returns Nil at once. `.close` ends the
sending; the values already sent can still be received, and after them
`.receive` throws `X::Channel::ReceiveOnClosed`. `.list` returns every
value up to the close, so on a channel that is still open it waits for the
close.

```raku
my $c = Channel.new;
$c.send($_) for 1..3;
say $c.receive;
say $c.poll;
$c.close;
say $c.list;
say $c.poll.raku;
try $c.receive;
say $!.^name;
try $c.send(4);
say $!.^name;
```
```output
1
2
(3)
Nil
X::Channel::ReceiveOnClosed
X::Channel::SendOnClosed
```

## A Channel's `closed` promise waits until the queue is empty
tags: trap

`.closed` returns a promise. docs.raku.org says it is kept once the channel
is closed; Rakudo keeps it only when the channel is closed *and* the last
value has been received. `.fail` closes the channel with an error: the
values sent before it are received as usual, then `.receive` throws the
error, and the `closed` promise is broken as soon as the last value is out.

```raku
my $c = Channel.new;
$c.send($_) for 1, 2;
$c.close;
say $c.closed.status;
say $c.receive, " ", $c.closed.status;
say $c.receive, " ", $c.closed.status;
my $d = Channel.new;
$d.send(1);
$d.fail("gone");
say $d.receive, " ", $d.closed.status;
try $d.receive;
say $!.^name, ": ", $!.message;
```
```output
Planned
1 Planned
2 Kept
1 Broken
X::AdHoc: gone
```

## A Channel passes values between threads, and `await` receives one

A channel is how one thread hands a stream of values to another. A `for`
over `.list` receives until the sender closes the channel. `await` on a
channel receives the next value, waiting for it if needed; on a channel
that is closed and empty it throws `X::Channel::ReceiveOnClosed` with the
`X::Await::Died` role.

```raku local
my $c = Channel.new;
my $producer = start {
    for 1..5 { $c.send($_ ** 2) }
    $c.close;
}
my @got;
for $c.list -> $v { @got.push($v) }
say @got;
await $producer;
my $d = Channel.new;
start { sleep 0.1; $d.send("late") };
say await $d;
$d.send(1);
$d.send(2);
say await $d, $d;
$d.close;
try await $d;
say $!.^name;
```
```output
[1 4 9 16 25]
late
(1 2)
X::Channel::ReceiveOnClosed+{X::Await::Died}
```

## `await` on a Channel takes a Nil value for no value
tags: bug

A Nil sent into a channel is a value like any other, and `.receive`
returns it. `await` should too. In Rakudo 2026.08 it consumes the Nil and
goes on waiting as though nothing had been sent: with a later value it
returns that one instead, and with none it never returns.

```raku local
my $c = Channel.new;
$c.send(Nil);
say $c.receive.raku;
my $d = Channel.new;
$d.send(Nil);
$d.send(1);
say await $d;
say $d.poll.raku;
$d.send(Nil);
my $waiter = start { await $d };
await Promise.anyof($waiter, Promise.in(0.2));
say $waiter.status;
```
```output
Nil
1
Nil
Planned
```

On the main thread nothing times it out; this program does not return:

```raku nocheck
my $c = Channel.new;
$c.send(Nil);
say await $c;
```

## `sleep` returns Nil, and some arguments mean never
tags: quirk

`sleep` waits about the given number of seconds and returns Nil. It takes
any number, a `Duration` or a numeric string. Zero, a negative number and
`NaN` return at once. `sleep` with no argument, `sleep Inf` and `sleep *`
never return. The quirk is a string that is not a number: `sleep "abc"`
returns at once, with no error and no warning. An undefined argument warns,
three times.

```raku local
say (sleep 0.1).raku;
say (sleep "0.05").raku;
say (sleep -1).raku, " ", (sleep 0).raku, " ", (sleep NaN).raku;
say (sleep "abc").raku;
my @forever = (start { sleep }), (start { sleep Inf }), (start { sleep * });
await Promise.anyof(Promise.allof(@forever), Promise.in(0.2));
say @forever».status;
say (sleep Any).raku;
```
```output
Nil
Nil
Nil Nil Nil
Nil
[Planned Planned Planned]
Nil
```
```stderr
Use of uninitialized value of type Any in numeric context
  in block <unit> at example.raku line 8
Use of uninitialized value of type Any in numeric context
  in block <unit> at example.raku line 8
Use of uninitialized value of type Any in numeric context
  in block <unit> at example.raku line 8
```

## `sleep-timer` returns what it did not sleep; `sleep-until` a Bool
tags: bug

`sleep-timer` sleeps like `sleep` and returns a `Duration`: the part of the
time it did not sleep, normally zero. `sleep-until` takes an `Instant` or a
`DateTime` and returns `True` once that time has come, or `False` at once
when it has passed already, which is the case for `now`. A plain number is
refused. `sleep NaN` returns at once, and `sleep-timer NaN` should too. In
Rakudo 2026.08 it fails its own return type check instead, because it
cannot make a Duration out of NaN.

```raku local
say (sleep-timer 0.1).raku;
say (sleep-timer -1).raku;
say (sleep-until now + 0.1).raku;
say (sleep-until now - 1).raku;
say (sleep-until now).raku;
say (sleep-until DateTime.now.later(seconds => 0.1)).raku;
try sleep-until 5;
say $!.^name;
try sleep-timer NaN;
say $!.^name;
```
```output
Duration.new(0.0)
Duration.new(0.0)
Bool::True
Bool::False
Bool::False
Bool::True
X::Cannot::New
X::TypeCheck::Return
```

## `Lock.protect` returns what its block returns, container and all

A `Lock` lets one thread at a time into a piece of code. `.protect(&code)`
takes the lock, runs the code, releases the lock and returns the code's
value. The lock is released even when the code dies, and the exception goes
on to the caller. The value is returned as it is: a variable comes back as
the variable, and can be assigned to.

```raku local
my $lock = Lock.new;
my $total = 0;
await (1..100).map: { start { $lock.protect({ $total += $_ }) } };
say $total;
say $lock.protect({ 1, 2 }).raku;
my $x = 5;
$lock.protect({ $x }) = 6;
say $x;
try $lock.protect({ die "inside" });
say $!.message;
say await start { $lock.protect({ "the lock was released" }) };
```
```output
5050
(1, 2)
6
inside
the lock was released
```

Without the lock, the hundred additions to `$total` could overlap and lose
some of the updates.

## A Lock is re-entrant, and only its holder may unlock it

The thread that holds a `Lock` can take it again: `.protect` inside
`.protect` works, and after `.lock` twice it takes two `.unlock` calls to
let another thread in. `.lock` and `.unlock` return the lock. Unlocking a
lock that the current thread does not hold, because nobody holds it or
another thread does, throws an `X::AdHoc`.

```raku local
my $lock = Lock.new;
say $lock.protect({ $lock.protect({ "re-entrant" }) });
say $lock.lock.raku;
say $lock.unlock.raku;
try Lock.new.unlock;
say $!.message;
$lock.lock;
$lock.lock;
$lock.unlock;
my $other = start { $lock.protect({ "got it" }) };
await Promise.anyof($other, Promise.in(0.2));
say $other.status;
$lock.unlock;
say await $other;
$lock.lock;
say await start { (try $lock.unlock) // $!.message };
$lock.unlock;
```
```output
re-entrant
Lock.new
Lock.new
Attempt to unlock mutex by thread not holding it
Planned
got it
Attempt to unlock mutex by thread not holding it
```

## Every call of `.condition` makes a new condition variable
tags: trap

`$lock.condition` returns a `Lock::ConditionVariable`, with which a thread
that holds the lock can `.wait`, releasing the lock until another thread
calls `.signal` or `.signal_all`. Each call of `.condition` makes a new,
separate condition variable, and a signal reaches only the threads waiting
on that same object. Keep the object in a variable and use it on both
sides. Waiting without holding the lock is an error.

```raku local
my $lock = Lock.new;
my $cond = $lock.condition;
say $cond === $lock.condition;
my $waiting = Promise.new;
my $waiter = start $lock.protect({ $waiting.keep; $cond.wait; "woken" });
await $waiting;
$lock.protect({ $lock.condition.signal_all });
await Promise.anyof($waiter, Promise.in(0.2));
say $waiter.status;
$lock.protect({ $cond.signal_all });
say await $waiter;
try $cond.wait;
say $!.message;
say $lock.protect({ $cond.wait({ True }); "no wait" });
```
```output
False
Planned
woken
Can only wait on a condition variable when holding mutex
no wait
```

The last line uses `.wait(&predicate)`, which waits until the predicate is
true, and does not wait at all when it is true already.

## `Lock::Soft` is a Lock whose misuse has typed exceptions
tags: undocumented

`Lock::Soft` has the interface of `Lock`: `lock`, `unlock`, `protect` and
`condition`, re-entrant, with the value of `protect` returned as it is. It
has no page on docs.raku.org. The differences are small: `lock` and
`unlock` return Nil, a misused `unlock` throws a typed exception, and
`.condition` returns the same condition variable every time.

```raku local
my $lock = Lock::Soft.new;
say $lock.lock.raku, " ", $lock.unlock.raku;
try $lock.unlock;
say $!.^name;
$lock.lock;
say await start { (try $lock.unlock) // $!.^name };
$lock.unlock;
say $lock.protect({ $lock.protect({ "re-entrant" }) });
say $lock.condition === $lock.condition;
try $lock.condition.wait;
say $!.^name;
```
```output
Nil Nil
X::Lock::Unlock::NoMutex
X::Lock::Unlock::WrongThread
re-entrant
True
X::Lock::ConditionVariable::NoMutex
```

## `Lock::Async.lock` returns a promise, and the lock is not re-entrant
tags: quirk

`Lock::Async` does not make its caller wait. `.lock` returns a Promise that
is kept when the lock is acquired: kept already when the lock was free,
Planned otherwise, with waiters served first come, first served. `.unlock`
hands the lock to the next waiter, and it may be called from any thread.
The quirk: every `.lock` that gets the lock at once returns the same kept
Promise, shared by all `Lock::Async` objects.

```raku local
my $lock = Lock::Async.new;
my $first = $lock.lock;
say $first.^name, " ", $first.status;
my $second = $lock.lock;
my $third = $lock.lock;
say $second.status, " ", $third.status;
$lock.unlock;
await $second;
say $second.status, " ", $third.status;
$lock.unlock;
await $third;
$lock.unlock;
try $lock.unlock;
say $!.^name, ": ", $!.message;
my $again = $lock.lock;
say $again === $first, " ", $again === Lock::Async.new.lock;
```
```output
Promise Kept
Planned Planned
Kept Planned
X::Lock::Async::NotLocked: Cannot unlock a Lock::Async that is not currently locked
True True
```

Unlike `Lock`, a `Lock::Async` cannot be taken twice by the same code: a
`protect` inside a `protect` of the same lock waits for itself and never
returns. The lock belongs to no thread, so another thread may unlock it:

```raku local
my $lock = Lock::Async.new;
say $lock.protect({ 42 });
my $nested = start { $lock.protect({ $lock.protect({ "inner" }) }) };
await Promise.anyof($nested, Promise.in(0.2));
say $nested.status;
my $other = Lock::Async.new;
await $other.lock;
say await start { $other.unlock; "unlocked by another thread" };
say $other.lock.status;
```
```output
42
Planned
unlocked by another thread
Kept
```

## `protect-or-queue-on-recursion` defers the inner call instead of waiting
tags: unasserted

For code that may call itself while holding a `Lock::Async`, the method
`protect-or-queue-on-recursion` avoids waiting for itself. With the lock
free, it runs the code now and returns Nil. Called again from inside its
own code, it does not run the code but returns a Planned promise for it;
the code runs as soon as the outer call releases the lock, and its value
keeps the promise.

```raku local
my $lock = Lock::Async.new;
my @log;
say $lock.protect-or-queue-on-recursion({ @log.push("free") }).raku;
my $queued;
$lock.protect-or-queue-on-recursion({
    $queued = $lock.protect-or-queue-on-recursion({ @log.push("inner"); "inner's value" });
    say $queued.status;
    @log.push("outer");
});
say @log;
say await $queued;
```
```output
Nil
Planned
[free outer inner]
inner's value
```

Its companion `with-lock-hidden-from-recursion-check` runs code with the
lock left out of that check. A `protect-or-queue-on-recursion` inside it
then waits for the lock that its own caller holds, and never returns:

```raku local
my $lock = Lock::Async.new;
my $w = start $lock.protect-or-queue-on-recursion({
    $lock.with-lock-hidden-from-recursion-check({
        $lock.protect-or-queue-on-recursion({ "never" })
    })
});
await Promise.anyof($w, Promise.in(0.2));
say $w.status;
```
```output
Planned
```

## A Semaphore hands out permits, and `release` has no ceiling

`Semaphore.new($n)` starts with `$n` permits. `.try_acquire` takes one and
returns `True`, or returns `False` at once when none is left; `.acquire`
waits until one is free. `.release` adds a permit, from any thread, with no
upper limit: releasing more than was acquired leaves more permits than
there were at the start. `.acquire` and `.release` return `Mu`. The count is
required, and must be a native integer that is not negative.

```raku local
my $s = Semaphore.new(2);
say $s.try_acquire, " ", $s.try_acquire, " ", $s.try_acquire;
say $s.release.raku;
$s.release for ^3;
say (^6).map({ $s.try_acquire });
my $zero = Semaphore.new(0);
my $w = start { $zero.acquire; "acquired" };
await Promise.anyof($w, Promise.in(0.2));
say $w.status;
$zero.release;
say await $w;
for { Semaphore.new }, { Semaphore.new("2") }, { Semaphore.new(-1) } -> &c {
    try c();
    say $!.message;
}
```
```output
True True False
Mu
(True True True True False False)
Planned
acquired
Too few positionals passed; expected 2 arguments but got 1
This type cannot unbox to a native integer: P6opaque, Str
Failed to initialize Semaphore: invalid argument
```

## A Semaphore's permit count wraps at 32 bits
tags: bug unasserted

The number of permits is kept in 32 bits. Counts up to `2**31 - 1` work;
from `2**31` to `2**32 - 1` they are refused. From `2**32` on, Rakudo
2026.08 accepts the count silently and keeps only its low 32 bits, so
`2**32` gives a semaphore with no permits at all and `2**32 + 1` one with a
single permit. A big count should be refused or honoured, not wrapped.

```raku
for 2**31 - 1, 2**31, 2**32, 2**32 + 1 -> $n {
    my $s = try Semaphore.new($n);
    say "$n: ", $s ?? "{$s.try_acquire} {$s.try_acquire}" !! $!.message;
}
try Semaphore.new(2**64);
say $!.message;
```
```output
2147483647: True True
2147483648: Failed to initialize Semaphore: invalid argument
4294967296: False False
4294967297: True False
Cannot unbox 65 bit wide bigint into native integer. Did you mix int and Int or literals?
```

## `cue` returns Nil, and a Cancellation only with a timer
tags: quirk

`$*SCHEDULER` is the scheduler that runs `start` blocks and timers, a
`ThreadPoolScheduler` by default. Its `cue` method runs code on the pool.
docs.raku.org says `cue` returns a `Cancellation`; Rakudo returns one only
when a timer is involved (`:in`, `:at`, `:every` or `:times`), and Nil for
plain `cue(&code)`. A Cancellation's `.cancel` stops the timer. `:catch`
receives the exception of code that dies; without it, the program ends as
shown in
[A dying `start` whose promise is sunk ends the program](#ch:promises:a-dying-start-whose-promise-is-sunk-ends-the-program).

```raku local
say $*SCHEDULER.^name;
my $done = Promise.new;
say $*SCHEDULER.cue({ $done.keep("ran") }).raku;
say await $done;
my $timer = $*SCHEDULER.cue({ say "never printed" }, :in(0.1));
say $timer.^name, " ", $timer.cancelled;
say $timer.cancel.raku, " ", $timer.cancelled;
my $caught = Promise.new;
$*SCHEDULER.cue({ die "in cued code" }, :catch({ $caught.keep(.message) }));
say await $caught;
sleep 0.2;
```
```output
ThreadPoolScheduler
Nil
ran
Cancellation False
Bool::True True
in cued code
```

The final `sleep` gives the cancelled timer the time to fire, and it does
not. `:every` repeats the code at an interval, and `:times` limits the
number of runs. `:every(Inf)` runs the code once, at once, with a warning.
`NaN` for any of the delays is refused, and so is `:in` together with
`:at`:

```raku local
my $count = 0;
my $third = Promise.new;
$*SCHEDULER.cue({ $third.keep if ++$count == 3 }, :every(0.05), :times(3));
await $third;
sleep 0.2;
say $count;
my $n = 0;
$*SCHEDULER.cue({ $n++ }, :every(Inf));
say $n;
try $*SCHEDULER.cue({ ; }, :in(NaN));
say $!.^name;
try $*SCHEDULER.cue({ ; }, :in(1), :at(now));
say $!.message;
```
```output
3
1
X::Scheduler::CueInNaNSeconds
Cannot specify :at and :in at the same time
```
```stderr
Inf was passed via :every; running the given block only once, immediately
  in block <unit> at example.raku line 8
```

## A CurrentThreadScheduler runs everything at once, in the caller

A `CurrentThreadScheduler` has no threads: code given to it runs
immediately, on the thread that asked. `Promise.start` with
`:scheduler($s)` has run its code and kept its promise by the time it
returns, a `then` on that promise is kept at once, and even `Promise.in`
sleeps in the caller. Code that dies throws to the caller of `cue`, and
`:every` is refused.

```raku local
my $here = CurrentThreadScheduler.new;
my @log;
my $p = Promise.start({ @log.push("ran"); 42 }, :scheduler($here));
@log.push("start returned");
say $p.status, " ", $p.result;
say $p.then({ .result + 1 }).status;
say Promise.in(0.1, :scheduler($here)).status;
$here.cue({ @log.push("cued") });
say @log;
try $here.cue({ die "loud" });
say $!.message;
try $here.cue({ ; }, :every(1));
say $!.^name;
```
```output
Kept 42
Kept
Kept
[ran start returned cued]
loud
X::AdHoc
```

## `hyper` keeps the order of the elements, `race` does not

`.hyper` and `.race` make a list's `map` and `grep` run in batches on the
thread pool. `hyper` returns the results in the order of the input, like an
ordinary `map`. `race` returns each batch as soon as it is done, so a slow
element can end up last. Sort what a `race` returns when the order matters.

```raku local
my @squares = (1..8).hyper(:batch(1)).map({ sleep 0.1 if $_ == 1; $_ ** 2 });
say @squares;
my @raced = (1..8).race(:batch(1)).map({ sleep 0.1 if $_ == 1; $_ ** 2 });
say @raced[*-1];
say @raced.sort;
say (1..8).hyper.^name, " ", (1..8).race.^name;
```
```output
[1 4 9 16 25 36 49 64]
1
(1 4 9 16 25 36 49 64)
HyperSeq RaceSeq
```

## An exception in a `hyper` worker surfaces where the values are read
tags: trap

When the code in a `hyper` or `race` dies, the exception arrives, with the
role `X::HyperRace::Died`, wherever the results are first read. `.List` on
a `HyperSeq` does not read them yet, so a `try` around it catches nothing,
and the exception comes out later:

```raku local
try { my @r = (1..20).hyper(:batch(2)).map({ die "bad $_" if $_ == 7; $_ }) };
say $!.^name, ": ", $!.message;
my $l = try (1..20).hyper(:batch(2)).map({ die "bad $_" if $_ == 7; $_ }).List;
say "the try is over";
say $l.elems;
```
```output
X::AdHoc+{X::HyperRace::Died}: bad 7
the try is over
```
```stderr
A worker in a parallel iteration (hyper or race) initiated here:
  in block <unit> at example.raku line 5

Died at:
    bad 7
      in block  at example.raku line 3

```

Assigning to an array, as in the first line, reads every value inside the
`try`.

## A Promise becomes a Supply of its one value

`.Supply` on a Promise gives a Supply that emits the result and is done once
the promise is kept, or quits with the cause once it is broken. Each tap
gets the value again. `await` accepts a Supply too: it returns the last
value emitted, and rethrows a quit with the `X::Await::Died` role. Both are
covered in [Supplies](#ch:supplies).

```raku local
my $s = Promise.kept(5).Supply;
say $s.list, " ", $s.list;
try await Promise.broken("no luck").Supply;
say $!.^name, ": ", $!.message;
say await Supply.from-list(1, 2, 3);
```
```output
(5) (5)
X::AdHoc+{X::Await::Died}: no luck
3
```

A tap on the Supply of a promise that is broken already gets the quit
asynchronously: sometimes before the next statement runs, sometimes after
it.
