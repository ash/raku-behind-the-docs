---
title: Exceptions and Failures
part: Code
summary: How Raku throws, catches, resumes and reports an exception, how a Failure holds one back until somebody looks, and what `$!`, CATCH, CONTROL and the phasers see on the way.
---

Raku has two ways of saying that something went wrong. `die` throws an
exception at once: control leaves block after block and routine after
routine until a handler takes it, and when none does, the program ends.
`fail` returns a `Failure` instead: an undefined value that carries an
exception and throws it only if the value is used without being checked.

Handlers come in two forms. `try` catches everything and leaves the
exception in the variable `$!`. The `CATCH` phaser, written inside a block,
chooses the exceptions it wants with `when`. A second family, the *control
exceptions*, is how `warn`, `next`, `last`, `return` and `take` travel; the
`CONTROL` phaser sees those.

This chapter follows an exception from `die` to the report on standard error,
and a Failure from `fail` to the moment it throws. What a Failure does when
nobody uses it is in [Values Nobody Uses](#ch:sink); a Failure as an
undefined value is in [Nil, Any and the Undefined](#ch:nil-any).

## An uncaught exception prints a backtrace and exits with status 1

When no handler takes an exception, Rakudo writes its message to standard
error, then one line for each routine or block that was active when it was
thrown, innermost first, then an empty line. The program stops.

```raku
sub check($n) {
    die "negative: $n" if $n < 0;
    $n
}
say check(3);
say check(-1);
say "not reached";
```
```output
3
```
```stderr
negative: -1
  in sub check at example.raku line 2
  in block <unit> at example.raku line 6

```

The exit status is 1. A warning also goes to standard error, but the program
goes on and the status stays 0. Running two small programs as child
processes shows both:

```raku local
my $p = run $*EXECUTABLE, "-e", 'die "oops"', :err;
say $p.err.slurp.lines[0];
say $p.exitcode;
my $q = run $*EXECUTABLE, "-e", 'warn "careful"', :err;
say $q.exitcode;
```
```output
oops
1
0
```

## `say $!` prints the backtrace along with the message
tags: trap

`say` prints an object's `.gist`, and the gist of a thrown exception is the
whole report: the message, the backtrace and an empty line. `put`, `~` and
string interpolation use `.Str`, which is the message alone, as is
`.message`.

```raku
sub load { die "config missing" }
try load();
say $!;
put $!;
say "Error: $!";
say $!.message;
```
```output
config missing
  in sub load at example.raku line 1
  in block <unit> at example.raku line 2

config missing
Error: config missing
config missing
```

## `try` gives its block's value, or Nil with the exception in `$!`

`try` takes a block or a single statement. When nothing is thrown it gives
the value of what it ran; when something is thrown it gives Nil and puts the
exception in `$!`. Inside a `try` a Failure throws as soon as a call returns
it (see [Values Nobody Uses](#ch:sink:inside-try-a-failure-throws-as-soon-as-a-call-returns-it)),
so `try` also catches the Failure of a conversion such as `+"abc"`.

```raku
say try { 42 };
say (try { die "x" }).raku;
say try 42;
say (try die "y").raku;
say $!.message;
my $n = try +"abc";
say $n.raku, " ", $!.^name;
```
```output
42
Nil
42
Nil
y
Any X::Str::Numeric
```

Assigning the Nil to `$n` leaves the variable holding `Any`.

## A successful `try` resets `$!` to `Any`
tags: trap

Before any `try` has run, `$!` is Nil. A `try` that catches sets it to the
exception, and a `try` that succeeds sets it back to `Any`, an undefined
value. `$!` therefore always describes the most recent `try`, not the most
recent failure.

```raku
say $!.raku;
try { die "first" };
say $!.raku;
try { 1 };
say $!.raku;
say $!.defined;
```
```output
Nil
X::AdHoc.new(payload => "first")
Any
False
```

The `try` that resets it may be anywhere in the same routine, even hidden in
a nested block. An exception that must be kept belongs in a variable of its
own before the next `try` runs:

```raku
try { die "saved" };
{ try { 1 } }
say $!.raku;
```
```output
Any
```

## Each routine has its own `$!`, shared by its blocks

For `$!` the mainline counts as a routine. A bare block or a `do` block has
no `$!` of its own, so a `try` inside one sets the `$!` of the routine
around it. A sub sets only its own, and a sub that reads `$!` without a
`try` sees its own, still Nil, not its caller's:

```raku
{ try { die "in a bare block" } }
say $!.message;
my $v = do { try { die "in a do block" }; 1 };
say $!.message;
sub own { try { die "in a sub" }; $!.message }
say own();
say $!.message;
sub reads { $!.raku }
say reads();
```
```output
in a bare block
in a do block
in a sub
in a do block
Nil
```

## A nested `try` hands its exception to the rest of the outer block
tags: undocumented unasserted

An inner `try` sets the `$!` that the rest of the outer `try` block reads.
A `die` with no argument there rethrows it. When the outer `try` then
succeeds, it resets `$!`, and whatever the inner one caught is gone.

```raku
try {
    try { die "inner" };
    die "outer after " ~ $!.message;
}
say $!.message;
try {
    try { die "again" };
    die;
}
say $!.message;
try { try { die "discarded" }; 1 }
say $!.raku;
```
```output
outer after inner
again
Any
```

## CATCH handles what a `when` or `default` matches, then leaves the block

A `CATCH` block handles the exceptions thrown anywhere in the block that
contains it, before or after the CATCH itself. Inside it the exception is
the topic `$_`, and `when` clauses choose by type. Once a clause has run,
the block that holds the CATCH is finished: the statements after the throw
do not run, and execution continues after that block.

```raku
sub risky($n) {
    ... if $n == 1;
    X::NYI.new(feature => "level two").throw if $n == 2;
    die "plain failure";
}
for 1..3 -> $n {
    risky($n);
    say "not reached";
    CATCH {
        when X::StubCode { say "stub: ", .message }
        when X::NYI      { say "missing: ", .feature }
        default          { say "other: ", .message }
    }
}
say "done";
```
```output
stub: Stub code executed
missing: level two
other: plain failure
done
```

Each iteration of the `for` is one run of its block, so the loop goes on
with the next element. A `when` smartmatches the exception: a type matches
by class, a regex matches against the message, and a string must equal the
message:

```raku
{
    CATCH { when /disk/ { say "regex matched: ", .message } }
    die "disk full";
}
{
    CATCH { when "exact text" { say "string matched" } }
    die "exact text";
}
```
```output
regex matched: disk full
string matched
```

## An exception that no `when` matches goes on outward

When no clause of a CATCH matches, the exception continues to the next
handler out, as though the CATCH were not there. A CATCH with no `when` and
no `default` runs its code and still matches nothing:

```raku
sub inner {
    die "unmatched";
    CATCH { when X::StubCode { say "never" } }
}
sub middle {
    inner();
    CATCH { say "middle's CATCH ran for: ", .message }
}
sub outer {
    middle();
    CATCH { default { say "outer caught: ", .message } }
}
outer();
say "after";
```
```output
middle's CATCH ran for: unmatched
outer caught: unmatched
after
```

## A `try` with its own CATCH catches nothing else
tags: trap

A `try` catches every exception, but only through a handler of its own, and
a CATCH in its block replaces that handler. Whatever the CATCH does not
match leaves the `try` as though there were no `try` at all:

```raku
try {
    die "escapes";
    CATCH { when X::StubCode { say "never" } }
}
say "not reached";
```
```output
```
```stderr
escapes
  in block <unit> at example.raku line 2

```

The same goes for an exception thrown inside the CATCH. Only a second `try`
around the first one catches it:

```raku
try {
    try {
        die "first";
        CATCH { default { die "while handling: " ~ .message } }
    }
    say "not reached";
}
say $!.message;
```
```output
while handling: first
```

## Inside CATCH the exception is `$_`, and it never becomes `$!`
tags: trap

A CATCH hands the exception over as `$_` only. Inside the CATCH, `$!` is
Nil, and `$/` is Nil too. An exception that a CATCH handles is never stored
in `$!` at all: after the block, `$!` still holds what the last `try` left
there.

```raku
try { die "earlier" };
{
    die "now";
    CATCH {
        default {
            say "topic: ", .message;
            say "inside: ", $!.raku;
        }
    }
}
say "after: ", $!.message;
```
```output
topic: now
inside: Nil
after: earlier
```

A `try` whose own CATCH handles the exception leaves `$!` untouched in the
same way.

## A CATCH in a loop body ends one iteration, and `$_` is the exception
tags: trap undocumented

A handled exception finishes the current run of the loop body, and the loop
goes on. Inside the CATCH, `$_` is the exception, not the loop's topic:

```raku
for 1..4 {
    CATCH { default { say "skipped $_" } }
    die "odd" if $_ %% 2;
    say $_;
}
```
```output
1
skipped odd
3
skipped odd
```

`next`, `last` and `redo` work from inside the CATCH and act on the loop.
Name the loop variable, as with `-> $n`, to keep it in reach:

```raku
for 1..4 -> $n {
    CATCH { default { say "stop at $n"; last } }
    die "too big" if $n == 3;
    say $n;
}
my $attempts = 0;
for <a b> -> $item {
    CATCH { default { say "retrying $item"; redo } }
    die "flaky" if $item eq "a" && $attempts++ == 0;
    say "done $item";
}
```
```output
1
2
stop at 3
retrying a
done a
done b
```

## A trailing CATCH makes the block's value Nil
tags: quirk

A block's value is the value of its last statement, and a CATCH is a
statement. Written last, it makes the block's value Nil even when nothing
was thrown. Written first, it leaves the value alone:

```raku
sub compute { 42 }
say (try { compute(); CATCH { default { say "failed" } } }).raku;
say (try { CATCH { default { say "failed" } }; compute() }).raku;
sub trailing { compute(); CATCH { default { say "failed" } } }
say trailing().raku;
sub leading { CATCH { default { say "failed" } }; compute() }
say leading().raku;
```
```output
Nil
42
Nil
42
```

When the CATCH does handle something, the block's value is Nil wherever the
CATCH stands. The value of the handler's own code is thrown away; it does
not become the value of the block:

```raku
say (do { die "x"; CATCH { default { "handler value" } } }).raku;
sub f { CATCH { default { "handler value" } }; die "x"; "unreached" }
say f().raku;
```
```output
Nil
Nil
```

## `.resume` continues after the statement that threw

Calling `.resume` on the exception inside a CATCH makes the throw return,
and execution goes on with the next statement in the frame that threw. A
routine that dies and is resumed therefore runs to its end and returns its
own value, which overwrites anything the CATCH assigned:

```raku
{
    say "one";
    die "a problem";
    say "two";
    CATCH { default { say "handled: ", .message; .resume } }
}
sub bad { die "in bad"; "bad's own value" }
my $v = "init";
{
    CATCH { default { $v = "from CATCH"; .resume } }
    $v = bad();
}
say $v;
```
```output
one
handled: a problem
two
bad's own value
```

A resumed `die` returns Nil. A resumed failed assignment leaves the variable
as it was. The block runs to its end and gives the value of its last
statement:

```raku
my $r = do {
    CATCH { default { say "caught ", .^name; .resume } }
    say (die "x").raku;
    my Int $x = "text";
    say "x is ", $x.raku;
    "the block's value"
};
say $r;
```
```output
caught X::AdHoc
Nil
caught X::TypeCheck::Assignment
x is Int
the block's value
```

## `.resume` refuses a finished `try` and a missing method

An exception can be resumed only while its handler runs. Once the `try` has
finished, `.resume` on the exception in `$!` throws "Too late". A call of a
method the object does not have, `X::Method::NotFound`, cannot be resumed at
all. Both refusals are `X::AdHoc` exceptions thrown inside the CATCH, so they
escape the `try` that holds it (see
[A `try` with its own CATCH catches nothing else](#ch:exceptions:a-try-with-its-own-catch-catches-nothing-else)):

```raku
try { die "b" };
try $!.resume;
say $!.message;
try {
    try {
        1.nosuch;
        CATCH { default { .resume } }
    }
}
say $!.message;
```
```output
Too late to resume this exception
This exception is not resumable
```

The exceptions of `die`, of a typed exception's `.throw`, of a failed type
check, and the Failures that a `try` turns into throws all resume. The
control exceptions have rules of their own, described below.

## `.rethrow` keeps the original backtrace; `.throw` starts a new one
tags: unasserted

Both methods throw the same exception object again from inside a CATCH.
`.rethrow` sends it on with the backtrace it already has. `.throw` records
a new one where it is called, and because a CATCH runs inside the `die` that
it handles, the new backtrace lists the handler's frames first and the
original frames after them:

```raku
sub inner { die "deep" }
sub keeps {
    inner();
    CATCH { default { .rethrow } }
}
sub renews {
    inner();
    CATCH { default { .throw } }
}
try keeps();
say $!.backtrace.list.map(*.subname).grep(*.chars);
try renews();
say $!.backtrace.list.map(*.subname).grep(*.chars);
```
```output
(throw die inner keeps <unit>)
(throw throw die inner renews <unit>)
```

The first names in each list are frames of Rakudo's own code. Uncaught, the
exception from `.throw` reports the CATCH twice, as a block and as a frame
named `any`:

```raku
sub inner { die "deep" }
sub renews {
    inner();
    CATCH { default { .throw } }
}
renews();
```
```output
```
```stderr
deep
  in block  at example.raku line 4
  in any  at example.raku line 4
  in sub inner at example.raku line 1
  in sub renews at example.raku line 3
  in block <unit> at example.raku line 6

```

## An exception class supplies its own `message`

A class that inherits from `Exception` becomes a throwable type. Its
attributes are the details a handler can read, and a `message` method gives
the text of the report:

```raku
class X::Empty is Exception {
    has $.what;
    method message { "$!what is empty" }
}
sub first-of(@list) {
    X::Empty.new(what => "the list").throw unless @list;
    @list[0]
}
try first-of([]);
say $!.^name;
say $!.message;
say $!.what;
first-of([]);
```
```output
X::Empty
the list is empty
the list
```
```stderr
the list is empty
  in sub first-of at example.raku line 6
  in block <unit> at example.raku line 13

```

Without a `message` method, calling `.message` dies with "Stub code
executed", and the object has fallback texts for its `.Str` and `.gist`.
Uncaught, it reports `Died with` and the class name:

```raku
class E is Exception { }
my $e = E.new;
say $e.Str;
say $e.gist;
try $e.message;
say $!.^name, ": ", $!.message;
E.new.throw;
```
```output
Something went wrong in (E)
Unthrown E with no message
X::AdHoc: Stub code executed
```
```stderr
Died with E
  in block <unit> at example.raku line 7

```

## An exception object has no backtrace until it is thrown

An exception can be built and kept like any object. Until it is thrown, its
`.backtrace` is Nil, its gist is the plain message, and `.resume` refuses it
with the message "Can only resume an exception object", although it is one.
`.throw` needs an instance, not the class. `.rethrow` on an object that was
never thrown throws it with a fresh backtrace, and the handler receives the
very same object:

```raku
my $e = X::AdHoc.new(payload => "prepared");
say $e.backtrace.raku;
say $e.gist;
try $e.resume;
say $!.message;
try X::AdHoc.throw;
say $!.^name;
try $e.rethrow;
say $! === $e, " ", $!.backtrace.^name;
```
```output
Nil
prepared
Can only resume an exception object
X::Parameter::InvalidConcreteness
True Backtrace
```

## `die` with anything but an Exception throws an X::AdHoc

`die` wraps a value that is not an exception in `X::AdHoc`. The value is kept
unchanged as the `.payload`, and the message is its string form. Several
arguments are joined with no separator, like the arguments of `print`:

```raku
try die 42;
say $!.^name, " ", $!.payload.^name, " ", $!.payload + 1;
try die [1, 2];
say $!.message, " ", $!.payload.^name;
try die "a", "b", 3;
say $!.message;
class Temperature { has $.degrees; method Str { "$!degrees degrees" } }
my $t = Temperature.new(degrees => 451);
try die $t;
say $!.message, " ", $!.payload.degrees;
```
```output
X::AdHoc Int 43
1 2 Array
ab3
451 degrees 451
```

`.message` is always a string, whatever the payload. An `X::AdHoc` built
without a payload has the message "Unexplained error".

```raku
my $e = X::AdHoc.new(payload => 42);
say $e.message.^name;
say $e.payload.^name;
say $e.raku;
say X::AdHoc.new.message;
```
```output
Str
Int
X::AdHoc.new(payload => 42)
Unexplained error
```

## `die` without an argument rethrows `$!`, or says "Died"

A bare `die` throws the exception in the current routine's `$!` if there is
one, and an `X::AdHoc` with the message "Died" if there is not. A sub has a
`$!` of its own (see
[Each routine has its own `$!`, shared by its blocks](#ch:exceptions:each-routine-has-its-own-shared-by-its-blocks)),
so a bare `die` in a sub does not see the caller's. A type object is not an
exception to throw: `die` reports it as undefined.

```raku
try die;
say $!.message;
try die "first";
try die;
say $!.message;
sub fresh { try die; $!.message }
say fresh();
try die Exception;
say $!.message;
try die X::NYI;
say $!.message;
```
```output
Died
first
Died
Died with undefined Exception
Died with undefined X::NYI
```

`die Nil` throws an `X::AdHoc` whose payload is Nil and whose message is
empty, so the report begins with an empty line:

```raku
die Nil;
```
```output
```
```stderr

  in block <unit> at example.raku line 1

```

## `die` throws an exception object as it is, and a Failure's exception

Given an exception object, `die` throws that object, attributes and all.
Given a Failure, it throws the exception inside it, and the Failure stays
unhandled. An exception among other arguments is only a piece of text: its
message joins the rest in a new `X::AdHoc`.

```raku
try die X::NYI.new(feature => "time travel");
say $!.^name, ": ", $!.feature;
sub parse { fail "cannot parse" }
my $f = parse();
try die $f;
say $!.^name, ": ", $!.message;
say $f.handled;
try die "prefix: ", X::NYI.new(feature => "teleport");
say $!.^name, ": ", $!.message;
```
```output
X::NYI: time travel
X::AdHoc: cannot parse
False
X::AdHoc: prefix: teleport not yet implemented. Sorry.
```

## A trailing newline does not hide the backtrace; `:without-backtrace` does
tags: quirk

In Perl, a message ending in a newline suppresses the location. In Raku the
newline is part of the message, and the backtrace follows it as usual:

```raku
die "oops\n";
```
```output
```
```stderr
oops

  in block <unit> at example.raku line 1

```

The named argument `:without-backtrace` makes an exception that has none.
Uncaught, it prints the message alone, without even the closing empty line:

```raku
die :without-backtrace, "short and sweet";
```
```output
```
```stderr
short and sweet
```

The quirk is its gist. The exception's `.backtrace` is Nil, and in its place
`.gist` lists the frames active where `.gist` is called, which have nothing
to do with the `die`:

```raku
sub thrower { die :without-backtrace, "wb" }
try thrower();
sub show($e) { say $e.gist }
show($!);
say $!.without-backtrace;
```
```output
wb
  in sub show at example.raku line 3
  in block <unit> at example.raku line 4

True
```

## `warn` prints to standard error, goes on, and returns 0

`warn` reports its message on standard error, followed by one line saying
where it was called, and then execution continues. It returns 0. The line
names only the innermost frame, not the chain of calls that led there.
`note` prints its arguments with no location at all and returns True.

```raku
sub check($x) {
    warn "odd value $x" if $x % 2;
    $x
}
my $r = check(3);
say "still running with $r";
say (warn "again").raku;
note "a note";
say (note "another").raku;
```
```output
still running with 3
0
Bool::True
```
```stderr
odd value 3
  in sub check at example.raku line 2
again
  in block <unit> at example.raku line 7
a note
another
```

## `warn` joins its arguments, and an empty warning gets a stock message

Like `die`, `warn` joins several arguments with no separator, and an Array
among them with spaces. With no arguments, or an empty string, the message
is "Warning: something's wrong". A trailing newline stays in the message:

```raku
warn;
warn "";
warn 42, "x", [1, 2];
warn "with newline\n";
say "end";
```
```output
end
```
```stderr
Warning: something's wrong
  in block <unit> at example.raku line 1
Warning: something's wrong
  in block <unit> at example.raku line 2
42x12
  in block <unit> at example.raku line 3
with newline

  in block <unit> at example.raku line 4
```

## CONTROL catches warnings; without `.resume` it leaves the block

A warning is a control exception of type `CX::Warn`, and a CATCH never sees
it. A `CONTROL` block does. With `.resume`, `warn` returns and the block
goes on. A CONTROL that matches the warning and does not resume ends the
block, as a CATCH does:

```raku
my @log;
{
    CONTROL { when CX::Warn { @log.push: .message; .resume } }
    warn "first";
    warn "second";
    say "the block went on";
}
say @log;
{
    CONTROL { when CX::Warn { say "caught ", .message } }
    warn "stops here";
    say "not reached";
}
say "after the block";
```
```output
the block went on
[first second]
caught stops here
after the block
```

The `CX::Warn` object has the full backtrace that the printed warning leaves
out:

```raku
sub a { warn "deep warning" }
sub b { a() }
{
    CONTROL { when CX::Warn { say .backtrace.list.map(*.subname).grep(*.chars); .resume } }
    b();
}
```
```output
(warn a b <unit>)
```

## `quietly` swallows warnings before any CONTROL sees them

`quietly` in front of a block or a statement discards the warnings raised
while it runs, `warn` and Rakudo's own warnings alike, and execution goes
on. A CONTROL outside never hears of them:

```raku
{
    CONTROL { when CX::Warn { say "outer saw it"; .resume } }
    quietly { warn "hushed" }
    quietly warn "also hushed";
    say "quiet";
}
quietly say "value: " ~ Nil;
```
```output
quiet
value: 
```

Without `quietly`, the last line would warn about Nil in string context (see
[Nil, Any and the Undefined](#ch:nil-any)).

## A `last` caught by CONTROL does not end the loop
tags: quirk

`next`, `last` and `redo` are control exceptions too, `CX::Next`, `CX::Last`
and `CX::Redo`, and a CONTROL in the loop body receives them. A handler that
matches one and does nothing more swallows it: the body is left, and the loop
goes on. `.rethrow` lets it have its effect:

```raku
for 1..4 {
    CONTROL { when CX::Last { say "last swallowed" } }
    last if $_ == 2;
    say $_;
}
for 1..4 {
    CONTROL { when CX::Last { say "last passed on"; .rethrow } }
    last if $_ == 2;
    say $_;
}
```
```output
1
last swallowed
3
4
1
last passed on
```

A CONTROL with `default` catches every control exception, and its `.message`
names it:

```raku
for 1..3 {
    CONTROL { default { say "control: ", .^name, " ", .message } }
    next if $_ == 1;
    last if $_ == 2;
}
```
```output
control: CX::Next <next control exception>
control: CX::Last <last control exception>
```

The quirk is `.resume`: warnings resume, but these three refuse, and the
refusal is an ordinary exception that leaves the loop:

```raku
try {
    for 1..3 {
        CONTROL { when CX::Next { .resume } }
        next;
    }
}
say $!.^name, ": ", $!.message;
```
```output
X::AdHoc: This exception is not resumable
```

## Rethrowing a caught `return`, `take` or `emit` loses its value
tags: bug

A CONTROL also sees `return` (`CX::Return`), `take` (`CX::Take`) and `emit`
(`CX::Emit`). The documentation describes `.rethrow` as throwing the
exception again, and a rethrown `CX::Next` does go on to the next iteration.
For these three, in Rakudo 2026.08, the construct receives the control
exception itself instead of the value: the routine returns the `CX::Return`
object, and `gather` collects `CX::Take` objects. A CONTROL that does not
catch the `return` leaves its value alone.

```raku
sub five {
    CONTROL { when CX::Return { say "seen: ", .message; .rethrow } }
    return 5;
}
say five().raku;
my @g = gather {
    CONTROL { when CX::Take { .rethrow } }
    take 1;
    take 2;
}
say @g.raku;
```
```output
seen: <return control exception>
CX::Return.new
[CX::Take.new, CX::Take.new]
```

A rethrown `emit` delivers the `CX::Emit` object, and `say` prints its gist,
message and backtrace:

```raku
my $s = supply {
    CONTROL { when CX::Emit { .rethrow } }
    emit 7;
}
react { whenever $s { say "got: ", $_ } }
```
```output
got: <emit control exception>
  in block <unit> at example.raku line 3

```

Resuming instead is no better: a resumed `take` or `emit` is skipped, so
nothing is gathered or emitted, and a resumed `return` is refused as not
resumable. A CONTROL also sees a `succeed` written outside a `when`, but
not the `succeed` or `proceed` that a `when` block performs.

## Loop control outside a loop throws X::ControlFlow

`last`, `next` and `redo` with no loop around them at run time, `take`
outside `gather`, `emit` outside a supply and `succeed` outside a `when`
throw `X::ControlFlow`. Its `.illegal` names the keyword and `.enclosing`
the construct that was missing. `return` outside a routine throws the
subclass `X::ControlFlow::Return`. These are ordinary exceptions, caught by
`try` and CATCH:

```raku
sub stop { last }
try stop();
say $!.^name, ": ", $!.illegal, " / ", $!.enclosing;
say $!.message;
try take 1;
say $!.illegal, " / ", $!.enclosing;
try emit 1;
say $!.illegal, " / ", $!.enclosing;
try succeed;
say $!.illegal, " / ", $!.enclosing;
try { return 1 };
say $!.^name, ": ", $!.illegal, " / ", $!.enclosing;
say $! ~~ X::Control;
```
```output
X::ControlFlow: last / loop construct
last without loop construct
take / gather
emit / supply or react
succeed / when clause
X::ControlFlow::Return: return / Routine
False
```

A `return` inside a `gather` has the same problem even when the `gather` is
written inside a sub. The `gather` block runs lazily, when its values are
wanted, and by then the sub it was written in has already returned:

```raku
sub evens(@n) {
    gather for @n { return "odd found" if $_ % 2; take $_ }
}
my @e = evens([2, 4]);
say @e;
try { my @f = evens([2, 3]) };
say $!.^name;
```
```output
[2 4]
X::ControlFlow::Return
```

## An uncaught stray `last` is reported like a compile-time error
tags: quirk

A `last`, `next` or `redo` that finds no loop is detected while the program
runs, as the output of the first line shows. Its report nevertheless starts
with the `===SORRY!===` header of a compile-time error, and it has no
backtrace and no closing empty line:

```raku
say "before";
last;
```
```output
before
```
```stderr
===SORRY!===
last without loop construct
```

Its gist, caught, is the message and an empty line. A `take` or a `return`
in the wrong place is reported in the usual way, with a backtrace.

## `next` and `last` in a called sub act on the caller's loop
tags: trap

Loop control is found dynamically, by walking out through the calls, not by
looking at the code around the keyword. A `last` in a sub ends whatever loop
is running when the sub is called:

```raku
sub stop { last }
for 1..5 {
    stop() if $_ == 3;
    say $_;
}
sub skip-even($n) { next if $n %% 2 }
for 1..5 {
    skip-even($_);
    say "odd $_";
}
```
```output
1
2
odd 1
odd 3
odd 5
```

## A class that does X::Control reaches CONTROL and never CATCH

A user class can be a control exception by doing the role `X::Control`.
Thrown, it passes every CATCH and goes to the nearest CONTROL, which can
resume it: a progress report, for instance, that the caller may listen to or
not.

```raku
class CX::Progress does X::Control {
    has $.done;
    method message { "$!done% done" }
}
sub work {
    for 25, 50, 100 { CX::Progress.new(done => $_).throw }
    "finished"
}
{
    CATCH   { default { say "CATCH: never" } }
    CONTROL { when CX::Progress { say .message; .resume } }
    say work();
}
```
```output
25% done
50% done
100% done
finished
```

A control exception that no CONTROL handles turns into an `X::ControlFlow`
with `.illegal` "control exception" and `.enclosing` "handler", which a
`try` does catch. Throwing a `CX::` object by hand is therefore not the same
as the keyword: `CX::Last.new.throw` in a loop does not end it but leaves it
with that error, and a hand-made `CX::Warn` is no warning without a CONTROL.

```raku
class CX::Progress does X::Control {
    method message { "progress" }
}
try CX::Progress.new.throw;
say $!.^name, ": ", $!.illegal, " / ", $!.enclosing;
try { for 1..3 { say $_; CX::Last.new.throw } }
say $!.^name, ": ", $!.illegal;
CX::Warn.new(message => "hand-made").throw;
say "not reached";
```
```output
X::ControlFlow: control exception / handler
1
X::ControlFlow: control exception
```
```stderr
control exception without handler
  in block <unit> at example.raku line 8

```

## A bare `succeed` yields an internal null that cannot be printed
tags: bug

`succeed` leaves the `when` or `given` block early, and its argument becomes
the block's value. A `do given` yields that value, a list stays a List, and
`proceed` moves on to the next `when`. What a `given` yields when nothing
matches is in
[Values Nobody Uses](#ch:sink:a-given-without-a-matching-when-gives-false-not-nil).

```raku
say (do given 5 { when Int { succeed "early"; "not reached" } }).raku;
say (do given 5 { when Int { succeed 1, 2 } }).raku;
say (do given 5 { when Int { proceed }; when 5 { "five" } }).raku;
say (do given 5 { when Int { } }).raku;
```
```output
"early"
(1, 2)
"five"
Nil
```

An empty `when` yields Nil. A bare `succeed`, in Rakudo 2026.08, yields the
virtual machine's internal null value, `VMNull`, which is not a Raku object
and has no methods at all, not even the `.gist` that `say` calls:

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

## `fail` returns a Failure from the routine; `die` throws

`fail` leaves the routine it is in, as `return` does, and returns a
`Failure` that wraps the exception. The caller gets a value it can test: a
Failure is undefined and false. Testing it marks it handled; an unhandled
Failure throws when it is used as a value or sunk (see
[Values Nobody Uses](#ch:sink:a-sunk-failure-throws-its-exception)).

```raku
sub parse-die($s)  { die  "bad input: $s" }
sub parse-fail($s) { fail "bad input: $s" }
my $a = try parse-die("x");
say "die:  ", $a.raku, ", ", $!.message;
my $b = parse-fail("y");
say "fail: ", $b.^name, ", ", $b.exception.message;
say $b.defined;
```
```output
die:  Any, bad input: x
fail: Failure, bad input: y
False
```

## `fail` accepts what `die` accepts

`fail` wraps its arguments exactly as `die` does: a plain value or several
joined into an `X::AdHoc`, an exception object kept as it is. A bare `fail`
wraps the `$!` it finds (see
[A bare `fail` and `Failure.new` look for `$!` in different places](#ch:exceptions:a-bare-fail-and-failurenew-look-for-in-different-places))
or makes the message "Failed", and a type object gives "Failed with
undefined". `Failure.new` takes the same arguments.

```raku
sub f(|c) { fail |c }
sub show($f) { $f.so; say $f.exception.^name, ": ", $f.exception.message }
show f("text");
show f(42);
show f("a", "b", 3);
show f(X::NYI.new(feature => "that"));
show f();
show f(X::NYI);
show Failure.new;
show Failure.new("given to new");
```
```output
X::AdHoc: text
X::AdHoc: 42
X::AdHoc: ab3
X::NYI: that not yet implemented. Sorry.
X::AdHoc: Failed
X::AdHoc: Failed with undefined X::NYI
X::AdHoc: Failed
X::AdHoc: given to new
```

An exception object can also fail itself, and `.Failure` wraps it without
leaving the routine. Both Failures start unhandled:

```raku
my $e = X::AdHoc.new(payload => 42);
sub f { $e.fail; "not reached" }
my $r = f();
say $r.^name, " ", $r.exception === $e, " ", $r.handled;
my $g = $e.Failure;
say $g.^name, " ", $g.handled;
$r.so; $g.so;
```
```output
Failure True False
Failure False
```

## Outside a routine, `fail` throws like `die`

A `fail` in a block inside a routine returns from the routine, not from the
block. With no routine around it, in the mainline or in a `try` or `do`
block there, `fail` has nothing to return from and throws at once:

```raku
sub first-word($s) {
    my $w = do { fail "empty" unless $s; $s.words[0] };
    "word: $w";
}
say first-word("hello world");
say first-word("").^name;
my $v = try { fail "in try" };
say $v.raku, " ", $!.message;
my $w = do { fail "in a do block" };
say "not reached";
```
```output
word: hello
Failure
Any in try
```
```stderr
in a do block
  in block <unit> at example.raku line 9

```

## A bare `fail` and `Failure.new` look for `$!` in different places
tags: quirk

Without arguments, both `fail` and `Failure.new` wrap the exception in `$!`,
so a routine can pass on what its `try` caught. They look for it in
different places. `fail` finds the routine's `$!` from any block inside the
routine. `Failure.new` finds it only when called directly in the routine
body; from a nested block it sees nothing and makes "Failed":

```raku
sub with-fail {
    try die "the cause";
    fail;
}
sub fail-in-do {
    try die "the cause";
    my $x = do { fail };
    "not reached";
}
sub with-new {
    try die "the cause";
    Failure.new;
}
sub new-in-do {
    try die "the cause";
    do { Failure.new };
}
for &with-fail, &fail-in-do, &with-new, &new-in-do -> &c {
    my $f = c();
    $f.so;
    say &c.name, ": ", $f.exception.message;
}
```
```output
with-fail: the cause
fail-in-do: the cause
with-new: the cause
new-in-do: Failed
```

## `fail` with a handled Failure re-arms it

A routine that receives a Failure, tests it, and fails with it passes on the
same Failure object, unhandled again, so that its own caller is not let off.
`.handled` can also be assigned to directly, in both directions.

```raku
sub lookup { fail "not found" }
sub wrapper {
    my $r = lookup();
    say "wrapper saw: ", $r ?? "true" !! "false";
    fail $r;
}
my $w = wrapper();
say $w.handled;
say $w.exception.message;
$w.handled = True;
```
```output
wrapper saw: false
False
not found
```

## A Failure that throws far from its `fail` reports both places

A Failure keeps the backtrace of the place it was made. When it throws
somewhere else, the report gives that backtrace first and then, under
"Actually thrown at", the place where it finally went off:

```raku
sub lookup { fail "not found" }
my $f = lookup();
say "stored";
sink $f;
```
```output
stored
```
```stderr
not found
  in sub lookup at example.raku line 1
  in block <unit> at example.raku line 2

Actually thrown at:
  in block <unit> at example.raku line 4

```

## An unhandled Failure can warn when the garbage collector frees it
tags: trap

A Failure that is never handled, never thrown and then dropped is a problem
nobody saw. When the garbage collector frees such a Failure, Rakudo prints a
warning with its message. The warning comes whenever the collector happens
to run, so a program may print it on one run and not on the next, and a
short program usually ends before it happens at all. Creating many Failures
makes it certain:

```raku nocheck
sub lookup { fail "x" }
for ^20000 { my $f = lookup(); $f.^name }
```

```
WARNING: unhandled Failure detected in DESTROY. If you meant to ignore it, you can mark it as handled by calling .Bool, .so, .not, or .defined methods. The Failure was:
x
```

The warning repeats for each Failure collected. Testing the Failure, as the
message suggests, keeps it quiet.

## An unhandled Failure passes through subscripts, lists and `for`

Most uses of an unhandled Failure throw its exception. A few pass the
Failure along untouched and do not mark it: a subscript returns the Failure
itself, assigning it to an array makes one element, and `for` runs once
with it. `.DEFINITE` is True, because a Failure is an object, not a type.

```raku
sub lookup { fail "not found" }
my $f = lookup();
say $f[0].^name;
say $f<key>.^name;
my @a = $f;
say @a.elems;
for $f { say "the loop ran once" }
say $f.DEFINITE;
say $f.handled;
say (try $f.elems) // "elems: threw";
```
```output
Failure
Failure
1
the loop ran once
True
False
elems: threw
```

`&&` marks the Failure handled and returns it; `andthen` gives `Empty`.
Once handled, a Failure is `NaN` in arithmetic and its `.Int` is the `Int`
type object (see
[Values Nobody Uses](#ch:sink:a-handled-failure-is-nan-as-a-number-and-handled-as-a-string)),
`.Set` makes a set of one element, and `.Capture` and `.elems` still throw:

```raku
sub lookup { fail "not found" }
my $f = lookup();
say ($f && "never").^name;
say $f.handled;
my $g = lookup();
say ($g andthen "never").raku;
my $h = lookup();
$h.so;
say $h.Set.elems;
say (try $h.Capture) // $!.^name;
say (try $h.elems) // "elems still throws";
```
```output
Failure
True
Empty
1
X::Cannot::Capture
elems still throws
```

## A Failure owns the backtrace of its `fail`

The backtrace of a Failure belongs to the Failure, and the exception inside
has none, because it was never thrown. `.raku` shows whether the Failure has
been handled: a handled one prints as an `orelse` expression, which EVALs
back to a handled Failure.

```raku
sub inner { fail "deep" }
sub outer { inner() }
my $f = outer();
say $f.backtrace.list.map(*.subname).grep(*.chars);
say $f.exception.backtrace.raku;
say $f.raku;
$f.so;
say $f.raku;
say $f.raku.EVAL.handled;
```
```output
(inner outer <unit>)
Nil
Failure.new(exception => X::AdHoc.new(payload => "deep"), backtrace => Backtrace.new)
&CORE::infix:<orelse>(Failure.new(exception => X::AdHoc.new(payload => "deep"), backtrace => Backtrace.new), *.self)
True
```

Calling `.new` on a Failure object, rather than on the class, throws its
exception and marks it handled.

## `use fatal` makes a returned Failure throw at once

`use fatal` in a block turns every Failure that a call returns there into a
throw, as a `try` does for its own block. A boolean test in the same
expression still gets there first, so `//` supplies its fallback. `no fatal`
switches it off again, even inside a `try`.

```raku
sub lookup { fail "not found" }
{
    my $plain = lookup();
    say "plain: ", $plain.^name;
    $plain.so;
}
{
    use fatal;
    my $x = lookup() // "fallback";
    say "fatal with //: $x";
    my $y = lookup();
    say "not reached";
    CATCH { default { say "fatal threw: ", .message } }
}
try {
    no fatal;
    my $z = lookup();
    say "no fatal: ", $z.^name;
    $z.so;
}
```
```output
plain: Failure
fatal with //: fallback
fatal threw: not found
no fatal: Failure
```

## A Failure assigned to a typed variable reports two errors
tags: trap

A variable declared `my Int` cannot hold a Failure. Assigning one throws
`X::TypeCheck::Assignment`, and its report names both problems, the
Failure's own error first:

```raku
sub lookup { fail "not found" }
my Int $n = lookup();
say "not reached";
```
```output
```
```stderr
Earlier failure:
 not found
  in sub lookup at example.raku line 1
  in block <unit> at example.raku line 2

Final error:
 Type check failed in assignment to $n; expected Int but got Failure (Failure.new(exceptio...)
  in block <unit> at example.raku line 2

```

Inside a `try` the Failure throws before the assignment is attempted, so
what is caught there is the Failure's own exception:

```raku
sub lookup { fail "not found" }
{
    my Int $n = lookup();
    CATCH { default { say .^name } }
}
try { my Int $m = lookup() }
say $!.^name;
```
```output
X::TypeCheck::Assignment
X::AdHoc
```

## A backtrace holds every frame; its string shows the interesting ones

`.backtrace` returns a `Backtrace`, a list of `Backtrace::Frame` objects,
innermost first. Each frame has a `.subname` (empty for an anonymous
block), a `.subtype`, a `.file`, a `.line`, and flags such as `.is-setting`
for frames in Rakudo's own code:

```raku
sub inner { die "bt" }
sub outer { inner() }
try { outer() }
my $bt = $!.backtrace;
say $bt.gist;
for $bt.list -> $frame {
    say $frame.subname.raku, " ", $frame.subtype, $frame.is-setting ?? " (setting)" !! "";
}
```
```output
Backtrace(6 frames)
"throw" method (setting)
"die" sub (setting)
"inner" sub
"outer" sub
"" block
"<unit>" block
```

The string views choose among the frames. `.Str`, the view an uncaught
exception prints, leaves out the setting's frames, and it folds some
anonymous blocks into the frame that follows them, as it does here with the
block of the `try`. `.concise` keeps only the routines outside the setting.
`.full` and `.summary` include the setting's frames; here both have all six
lines.

```raku
sub inner { die "bt" }
sub outer { inner() }
try { outer() }
my $bt = $!.backtrace;
print $bt.Str;
say "--";
print $bt.concise;
say "--";
say $bt.full.lines.elems;
say $bt.summary.lines.elems;
```
```output
  in sub inner at example.raku line 1
  in sub outer at example.raku line 2
  in block <unit> at example.raku line 3
--
  in sub inner at example.raku line 1
  in sub outer at example.raku line 2
--
6
6
```

## `.nice(:oneline)` shows the second frame, not the first
tags: quirk

`.Str` is `.nice`, and the documentation says `.nice(:oneline)` stops after
the first frame. Here that is `inner`, where the exception was thrown;
Rakudo 2026.08 gives the line after it:

```raku
sub inner { die "bt" }
sub outer { inner() }
try { outer() }
print $!.backtrace.nice(:oneline);
```
```output
  in sub outer at example.raku line 2
```

## `Backtrace.new` records where it is created
tags: unasserted

A backtrace can be made without an exception. `Backtrace.new` lists the
frames active where it is called, starting with its own `new` in the setting,
and `Backtrace.new(N)` skips the first N frames. Every throw records a new
backtrace, even of the same exception object, unless `.throw` is given one
to use:

```raku
sub where-am-i { Backtrace.new }
sub caller { where-am-i() }
my $bt = caller();
say $bt.list.map(*.subname);
print $bt.Str;
sub skip-one { Backtrace.new(1) }
say skip-one().list.map(*.subname);
my $e = X::AdHoc.new(payload => "again");
try $e.throw;
my $first = $e.backtrace;
try $e.throw;
say $e.backtrace === $first;
try $e.throw($first);
say $e.backtrace === $first;
```
```output
(new where-am-i caller <unit>)
  in sub where-am-i at example.raku line 1
  in sub caller at example.raku line 2
  in block <unit> at example.raku line 3
(skip-one <unit>)
False
True
```

## `is hidden-from-backtrace` leaves a routine out of the report
tags: unasserted

A helper that only checks its arguments is rarely where the mistake is. The
trait `is hidden-from-backtrace` keeps its frame out of `.Str`, `.concise`,
`.summary` and the uncaught report, so the report starts at its caller. The
frame is still in `.list`, with `.is-hidden` True.

```raku
sub validate($x) is hidden-from-backtrace {
    die "invalid: $x" unless $x > 0;
}
sub process($x) { validate($x) }
try process(-1);
say $!.backtrace.list.grep(*.is-hidden).map(*.subname);
print $!.backtrace.Str;
say &validate.is-hidden-from-backtrace;
process(-2);
```
```output
(validate)
  in sub process at example.raku line 4
  in block <unit> at example.raku line 5
True
```
```stderr
invalid: -2
  in sub process at example.raku line 4
  in block <unit> at example.raku line 9

```

## `await` rethrows a thread's exception with a role mixed in

An exception inside `start` breaks its Promise, and `await` throws it again
in the awaiting thread. The object that arrives is the original exception
with the role `X::Await::Died` mixed in, so a `when X::AdHoc` still matches
it. A `fail` in the `start` block breaks the Promise too.

```raku local
my $p = start { die "in the thread" };
try await $p;
say $!.^name;
say $! ~~ X::AdHoc;
say $!.message;
say $p.status;
say $p.cause.^name;
my $q = start { fail "failed in the thread" };
try await $q;
say $q.status, " ", $!.message;
```
```output
X::AdHoc+{X::Await::Died}
True
in the thread
Broken
X::AdHoc
Broken failed in the thread
```

Uncaught, the report gives the place of the `await` first and the thread's
exception after it:

```raku local
my $p = start { die "in the thread" };
await $p;
```
```output
```
```stderr
An operation first awaited:
  in block <unit> at example.raku line 2

Died with the exception:
    in the thread
      in block  at example.raku line 1

```

Promises are the subject of [Promises, Locks and Awaiting](#ch:promises).

## A `die` in a `map` block fires when that element is computed

`map` is lazy: building the Seq runs nothing, and the block runs for each
element when that element is asked for. The exception comes out wherever
that happens, which may be far from the `map`:

```raku
my \seq = (1, 2, 3).map({ die "bad $_" if $_ == 2; $_ * 10 });
say "the map is built";
try { for seq { say $_ } }
say "caught: ", $!.message;
```
```output
the map is built
10
caught: bad 2
```

## LEAVE runs on every exit; KEEP and UNDO split success from failure

`LEAVE` runs whenever its block is left, by an exception too. `KEEP` runs
only when the block succeeds, and `UNDO` only when it does not. The queue
runs in reverse order of declaration.

```raku
sub attempt($ok) {
    LEAVE say "  LEAVE";
    KEEP  say "  KEEP";
    UNDO  say "  UNDO";
    die "failed" unless $ok;
    "done"
}
say "success:";
attempt(True);
say "exception:";
try attempt(False);
```
```output
success:
  KEEP
  LEAVE
exception:
  UNDO
  LEAVE
```

Success means a defined value: a block that ends with 0 succeeds, and one
that ends with Nil, a type object or a Failure has failed. `let` follows the
same rule (see
[Containers and Binding](#ch:containers:let-keeps-its-change-only-if-the-block-succeeds)).

```raku
sub result($v) {
    KEEP say "KEEP";
    UNDO say "UNDO";
    $v
}
print "0: ";    result(0);
print "Nil: ";  result(Nil);
print "Int: ";  result(Int);
sub failing { UNDO say "UNDO"; fail "no" }
print "fail: "; failing().so;
```
```output
0: KEEP
Nil: UNDO
Int: UNDO
fail: UNDO
```

## A dying ENTER stops the queue; a dying LEAVE does not

An exception in an `ENTER` stops the ENTER phasers that would follow it and
the block itself, but the LEAVE phasers still run. An exception in a `LEAVE`
lets the other LEAVE phasers run and is thrown when they are done:

```raku
try {
    ENTER { say "ENTER 1"; die "in ENTER" }
    ENTER say "ENTER 2";
    LEAVE say "LEAVE still runs";
    say "body";
}
say $!.message;
try {
    LEAVE say "LEAVE a";
    LEAVE { say "LEAVE b"; die "in LEAVE b" }
    1
}
say $!.message;
```
```output
ENTER 1
LEAVE still runs
in ENTER
LEAVE b
LEAVE a
in LEAVE b
```

A LEAVE that dies while another exception is on its way replaces that
exception. Two dying LEAVEs give one `X::PhaserExceptions`, which holds both.
A CATCH in the block runs before its LEAVE phasers:

```raku
try {
    LEAVE die "from LEAVE";
    die "original";
}
say $!.message;
try {
    LEAVE die "first LEAVE";
    LEAVE die "second LEAVE";
    1
}
say $!.^name;
say $!.exceptions.map(*.message).sort;
{
    LEAVE say "LEAVE";
    CATCH { default { say "CATCH" } }
    die "x";
}
```
```output
from LEAVE
X::PhaserExceptions
(first LEAVE second LEAVE)
CATCH
LEAVE
```

## A LEAVE sees the exception in `$!` only inside the `try`
tags: trap

A LEAVE reads `$!` like any other code: the `$!` of its routine. When the
LEAVE is in the block of the `try` itself, the `try` has already stored the
exception there, and the LEAVE sees it. In a sub that dies, the LEAVE sees
the sub's own `$!`, which nothing has set; in a block whose CATCH handles
the exception, it sees whatever `$!` held before.

```raku
try {
    LEAVE say "LEAVE sees: ", $!.message;
    die "unwinding";
}
sub s {
    LEAVE say "sub LEAVE sees: ", $!.raku;
    die "in sub";
}
try s();
{
    LEAVE say "block LEAVE sees: ", $!.message;
    CATCH { default { say "handled" } }
    die "caught";
}
```
```output
LEAVE sees: unwinding
sub LEAVE sees: Nil
handled
block LEAVE sees: in sub
```

## In a loop, LEAVE runs before NEXT
tags: bug

`NEXT` runs when a loop body is about to go round again. The documentation
says it runs before the body's `LEAVE`, and Roast asserts that order
(`S04-phasers/next.t`), with a `#?rakudo todo` on the test. In Rakudo 2026.08
LEAVE comes first. `LAST` runs after the final LEAVE, as the documentation
says.

```raku
for 1..2 {
    NEXT  say "NEXT $_";
    LEAVE say "LEAVE $_";
    LAST  say "LAST $_";
    say "body $_";
}
```
```output
body 1
LEAVE 1
NEXT 1
body 2
LEAVE 2
NEXT 2
LAST 2
```

## PRE and POST throw X::Phaser::PrePost with the condition's source

A `PRE` phaser is a condition checked on entry to the block, a `POST` one
checked on the way out, with the block's value in `$_`. A false condition
throws `X::Phaser::PrePost`; its `.phaser` is `PRE` or `POST` and its
`.condition` the source text of the condition.

```raku
sub half(Int $n) {
    PRE  { $n %% 2 }
    POST { $_ < 100 }
    $n div 2
}
say half(10);
try half(7);
say $!.^name, ": ", $!.phaser, " ", $!.condition.raku;
say $!.message;
try half(300);
say $!.message;
```
```output
5
X::Phaser::PrePost: PRE "\{ \$n \%\% 2 }"
Precondition '{ $n %% 2 }' failed
Postcondition '{ $_ < 100 }' failed
```

The condition may also be written without a block:

```raku
sub root($x) {
    PRE $x >= 0;
    $x.sqrt
}
root(-4);
```
```output
```
```stderr
Precondition '$x >= 0' failed
  in sub root at example.raku line 2
  in block <unit> at example.raku line 5

```

A failing PRE runs nothing else of the block, not even ENTER or LEAVE, and
the block's own CATCH does not see its exception. POST phasers run after
LEAVE, in reverse order, and the first false one stops the rest:

```raku
sub guarded($x) {
    PRE { $x > 0 }
    CATCH { default { say "the sub's own CATCH" } }
    ENTER say "ENTER";
    LEAVE say "LEAVE";
    $x
}
try guarded(-1);
say "outside: ", $!.^name;
sub f {
    POST { say "POST 1"; True }
    POST { say "POST 2"; False }
    LEAVE say "LEAVE";
    42
}
try f();
say $!.message;
```
```output
outside: X::Phaser::PrePost
LEAVE
POST 2
Postcondition '{ say "POST 2"; False }' failed
```

## Compile-time errors are exceptions, and EVAL makes them catchable

A program that does not compile never runs, so nothing in it can catch its
own compile-time error. Code compiled at run time with `EVAL` is different:
its compile-time errors are exceptions like any other, of types under
`X::Comp`, with `.is-compile-time` true and `.line` counting from the start
of the EVAL'd string. An error raised while the EVAL'd code runs is an
ordinary run-time exception.

```raku
use MONKEY-SEE-NO-EVAL;
try EVAL 'say "fine";' ~ "\n\n" ~ '$undeclared';
say $!.^name;
say $!.is-compile-time;
say $!.line;
say $! ~~ X::Comp;
try EVAL '1 +';
say $!.^name;
try EVAL 'die "at run time"';
say $!.^name, " ", $!.is-compile-time;
```
```output
X::Undeclared
1
3
True
X::Comp::AdHoc
X::AdHoc False
```

The EVAL'd `say` never runs. `.is-compile-time` answers 1 rather than True
for some types. Each kind of compile-time error has a type of its own:

```raku
use MONKEY-SEE-NO-EVAL;
for '1 <=> 2 <=> 3', 'my $0', 'CATCH { }; CATCH { }', 'BEGIN { die "early" }' -> $code {
    try EVAL $code;
    say $!.^name;
}
```
```output
X::Syntax::NonAssociative
X::Syntax::Variable::Numeric
X::Phaser::Multiple
X::Comp::BeginTime
```

## A call that can never match its signature fails at compile time
tags: trap

When a sub is called with a literal of a type its signature cannot accept,
the compiler already knows that the call will fail, and it refuses the
program. The line before the call never runs:

```raku
sub greet(Str $name) { say "hello $name" }
say "start";
greet(42);
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Calling greet(Int) will never work with declared signature (Str $name)
at example.raku:3
------> <BOL><HERE>greet(42);
```

The same value in a variable is checked when the call is made, and fails
with a run-time `X::TypeCheck::Binding::Parameter` that `try` can catch:

```raku
sub greet(Str $name) { say "hello $name" }
say "start";
my $n = 42;
try greet($n);
say $!.^name;
```
```output
start
X::TypeCheck::Binding::Parameter
```

Under EVAL, the compile-time form is an `X::TypeCheck::Argument` with the
role `X::Comp` mixed in.

## A compile-time exception carries the details of the complaint

The compile-time exception types have attributes for what the compiler
found. `X::Undeclared` names the symbol and suggests similar names in scope.
`X::Comp::BeginTime` holds the exception that a `BEGIN` block died with. A
call that can never work lists the argument types and the signatures.
Several problems found together arrive as one `X::Comp::Group`:

```raku
use MONKEY-SEE-NO-EVAL;
try EVAL 'my $total = 1; say $totl';
say $!.what, " ", $!.symbol, " ", $!.suggestions.raku;
try EVAL 'BEGIN { die "early" }';
say $!.exception.message, " / ", $!.use-case;
try EVAL 'sub f(Str) { }; f 42';
say $!.^name, " ", $!.objname, " ", $!.arguments.raku, " ", $!.signature.raku;
try EVAL 'class Stub { ... }';
say $!.^name, " ", $!.packages.raku;
try EVAL 'for 1, 2, 3, { say 3 }';
say $!.^name, ": ", $!.sorrows.map(*.^name), ", ", $!.panic.^name;
```
```output
Variable $totl ["\$total"]
early / evaluating a BEGIN
X::TypeCheck::Argument+{X::Comp} f ["Int"] ("(Str)",)
X::Package::Stubbed ["Stub"]
X::Comp::Group: (X::Syntax::BlockGobbled), X::Syntax::Missing
```

## Dispatch and type-check errors name what they got and expected

A failed method call is an `X::Method::NotFound`, with the method name, the
type, and suggestions picked by spelling alone. A failed type check tells
what arrived, what was expected, and which operation checked: `binding` for
a parameter, `assignment` for a variable, `returning` for a return type. A
failed `where` clause sets `.constraint`:

```raku
try 42.nosuch;
say $!.^name, ": ", $!.method, " on ", $!.typename, ", suggestions ", $!.suggestions.raku;
my $s = "text";
sub f(Int $x) { }
try f($s);
say $!.^name, ": ", $!.got.raku, " ", $!.expected.^name, " ", $!.parameter.name, " ", $!.operation;
sub g($x where * > 5) { }
my $one = 1;
try g($one);
say $!.constraint;
try { my Int $x = $s };
say $!.^name, ": ", $!.symbol, " ", $!.operation;
sub h(--> Str) { 5 }
try h();
say $!.^name, ": ", $!.got, " ", $!.operation;
```
```output
X::Method::NotFound: nosuch on Int, suggestions ["cosech"]
X::TypeCheck::Binding::Parameter: "text" Int $x binding
True
X::TypeCheck::Assignment: $x assignment
X::TypeCheck::Return: 5 returning
```

A multi with no matching candidate throws `X::Multi::NoMatch` with the proto
in `.dispatcher` and the arguments in `.capture`. The wrong number of
arguments, found at run time, is only an `X::AdHoc`. A value passed to an
`is rw` parameter is an `X::Parameter::RW`:

```raku
proto area(|) {*}
multi area(Int $side) { $side ** 2 }
my $s = "big";
try area($s);
say $!.^name, ": ", $!.dispatcher.name, " ", $!.capture.raku;
sub two($a, $b) { }
my @one = 1;
try two(|@one);
say $!.^name, ": ", $!.message;
sub w($x is rw) { }
try w(5 + 0);
say $!.^name, ": ", $!.got, " ", $!.symbol;
```
```output
X::Multi::NoMatch: area \("big")
X::AdHoc: Too few positionals passed; expected 2 arguments but got 1
X::Parameter::RW: 5 $x
```

## Each misuse of a value has its own exception type

The built-in types report misuse with specific exception classes, and each
class carries attributes for the details. Inside a `try`, the operations that
return a Failure throw at once, so the exception can be read from `$!`:

```raku
try { 1.0 = 3 };
say $!.^name, ": ", $!.value, " ", $!.typename;
try { my $l := (1, 2); $l.push(3) };
say $!.^name, ": ", $!.method, " ", $!.typename;
try Date.new("2012-02-30");
say $!.^name, ": ", $!.what, " ", $!.got, " ", $!.range;
try "foo"[2].self;
say $!.^name, ": ", $!.what, " ", $!.got, " ", $!.range;
try +"5 foo";
say $!.^name, ": ", $!.source, " at ", $!.pos, ", ", $!.reason;
try (1+2i).Num;
say $!.^name, ": ", $!.reason;
try (1..*).elems.self;
say $!.^name, ": ", $!.action;
try { my @a; @a.pop.self };
say $!.^name, ": ", $!.action, " ", $!.what;
try 1 div 0;
say $!.^name, ": ", $!.using, " ", $!.numerator;
try Mu.new(1);
say $!.^name, ": ", $!.type.^name;
try { my %h = 1 };
say $!.^name, ": ", $!.found;
try !!! "unfinished";
say $!.^name, ": ", $!.message;
```
```output
X::Assignment::RO: 1 Rat
X::Immutable: push List
X::Temporal::OutOfRange: Day 30 1..29
X::OutOfRange: Index 2 0..0
X::Str::Numeric: 5 foo at 1, trailing characters after number
X::Numeric::Real: imaginary part not zero
X::Cannot::Lazy: .elems
X::Cannot::Empty: pop Array
X::Numeric::DivideByZero: div 1
X::Constructor::Positional: Mu
X::Hash::Store::OddNumber: 1
X::StubCode: unfinished
```

A method called on Nil is the exception to the rule: it answers Nil and
throws nothing (see [Nil, Any and the Undefined](#ch:nil-any)).
