---
title: Supplies
part: Concurrency
summary: How a Supply delivers its values, its done and its quit to each tap, what supply and react blocks do with whenever, QUIT, LAST and CLOSE, and where Rakudo's Supply methods break their own rules.
---

A `Supply` is a stream of events that arrive over time. A consumer
subscribes to it with `.tap`, which returns a `Tap` object and registers
up to three handlers: one for each value (an *emit*), one for the normal
end of the stream (*done*), and one for its end by an exception (*quit*).
A stream is some number of emits followed by at most one done or quit.

Supplies come in two kinds. A *live* supply, fed by a `Supplier`, sends its
events to whoever is subscribed at the moment; a late subscriber misses what
went before. An *on-demand* supply starts from the beginning for every tap:
`Supply.from-list`, `Supply.interval` and the `supply { … }` block are
on-demand. The `react { … }` block subscribes to supplies with `whenever`
and waits until they are finished.

Most examples in this chapter need no threads. `Supply.from-list`, a
`Supplier` and a `supply` block deliver their events on the thread that
causes them, before the call that caused them returns, so the order of the
output is fixed. The examples marked as local use timers or other threads.
Promises, channels, locks and `await` as such are the subject of
[Promises, Locks and Awaiting](#ch:promises); the supplies of `Proc::Async`
are in [Processes](#ch:processes).

## A Supply comes from a factory, a Supplier or a supply block
tags: undocumented unasserted

`Supply` is not built with `.new`. Calling it without a source throws
`X::Supply::New`, whose message lists the three ways to get one:

```raku
try Supply.new;
say $!.^name;
say $!.message;
```
```output
X::Supply::New
Cannot directly create a Supply. You might want:
 - To use a Supplier in order to get a live supply
 - To use Supply.on-demand to create an on-demand supply
 - To create a Supply using a supply block
```

Besides those, most values have a `.Supply` method: a list gives one value
per element, and a single value such as a string or a number gives itself
as the only value.

```raku
say (1, 2, 3).Supply.list;
say 42.Supply.list;
say "text".Supply.list;
say (a => 1).Supply.list.raku;
```
```output
(1 2 3)
(42)
(text)
(:a(1),)
```

## `from-list` delivers every value before `.tap` returns

`Supply.from-list` is an on-demand supply that runs on the thread that taps
it. By the time `.tap` returns, every value and the done have already been
handled. The named `tap` handler receives the `Tap` object before the first
value flows.

```raku
my $s = Supply.from-list(1, 2, 3);
my $t = $s.tap(
    -> $v { say "value $v" },
    done => { say "done" },
    tap  => -> $tap { say "tapped: ", $tap.^name },
);
say "tap returned";
```
```output
tapped: Tap
value 1
value 2
value 3
done
tap returned
```

This is why most examples in this chapter can print as they go: nothing in
them happens later or elsewhere.

## `from-list` flattens a single Iterable argument only
tags: undocumented unasserted

`Supply.from-list` follows the single-argument rule of list functions. One
argument that is Iterable, an array, a list or a range, is spread into its
elements. Several arguments are each one value, even when they are lists
themselves. A string is not Iterable and stays whole.

```raku
say Supply.from-list([1, 2, 3]).list.raku;
say Supply.from-list(1..3).list.raku;
say Supply.from-list((1, 2), (3, 4)).list.raku;
say Supply.from-list("abc").list.raku;
say Supply.from-list().list.raku;
```
```output
(1, 2, 3)
(1, 2, 3)
($(1, 2), $(3, 4))
("abc",)
()
```

## A tap with no quit handler rethrows the quit at the emitter
tags: unasserted

The quit handler of `.tap` defaults to rethrowing the exception. It is
rethrown where the quit happens: for a `Supplier`, from the call to
`.quit`. A string given to `.quit` becomes an `X::AdHoc` whose payload is
that string; an exception object is passed on as it is.

```raku
my $supplier = Supplier.new;
$supplier.Supply.tap(-> $v { say "got $v" });
$supplier.emit(1);
try $supplier.quit("broken pipe");
say "caught at the quit: ", $!.message;
say $!.^name, " ", $!.payload.^name;
```
```output
got 1
caught at the quit: broken pipe
X::AdHoc Str
```

A Supplier hands the quit to its taps in the order they were made, and the
rethrow leaves that loop. A tap after the one without a handler never hears
of the quit:

```raku
my $supplier = Supplier.new;
$supplier.Supply.tap(-> $v { }, quit => { say "first tap: ", .message });
$supplier.Supply.tap(-> $v { });
$supplier.Supply.tap(-> $v { }, quit => { say "third tap: ", .message });
try $supplier.quit("stop");
say "thrown: ", $!.message;
```
```output
first tap: stop
thrown: stop
```

For a `supply` block the exception comes out of the `.tap` call itself:

```raku
my $s = supply { emit 1; die "the block failed" }
try $s.tap(-> $v { say "got $v" });
say "tap threw: ", $!.message;
```
```output
got 1
tap threw: the block failed
```

## A Supplier reaches only the taps present when it emits

A `Supplier` keeps no history. A value emitted while nobody is subscribed
is gone; a tap receives only what is emitted after it was made; and a tap
that closes itself from inside its handler receives nothing after that
value.

```raku
my $supplier = Supplier.new;
$supplier.emit(1);
my $tap;
$tap = $supplier.Supply.tap(-> $v { say "A got $v"; $tap.close if $v == 3 });
$supplier.emit(2);
$supplier.Supply.tap(-> $v { say "B got $v" });
$supplier.emit($_) for 3, 4;
```
```output
A got 2
A got 3
B got 3
B got 4
```

## After done, a tap receives nothing more
tags: undocumented unasserted

Each tap enforces the order of events: an emit, a second done or a quit
that comes after a done is dropped, and so is anything after a quit. The
rule is kept per tap, not per Supplier: a tap made after the done starts a
fresh stream and receives what is emitted into it.

```raku
my $supplier = Supplier.new;
$supplier.Supply.tap(-> $v { say "got $v" }, done => { say "done" });
$supplier.emit(1);
$supplier.done;
$supplier.emit(2);
$supplier.done;
$supplier.Supply.tap(-> $v { say "late tap got $v" });
$supplier.emit(3);
```
```output
got 1
done
late tap got 3
```

A second quit is dropped in the same way: the quit handler runs once, and
nothing is thrown.

```raku
my $supplier = Supplier.new;
$supplier.Supply.tap(-> $v { }, quit => { say "handled: ", .^name, " ", .message });
$supplier.quit(X::AdHoc.new(payload => "typed"));
$supplier.quit("second quit");
say "no exception escaped";
```
```output
handled: X::AdHoc typed
no exception escaped
```

## An emit from inside a handler waits until that handler returns
tags: undocumented unasserted

The handlers of one tap never nest. When a tap's handler emits into the
Supplier that called it, the new value goes at once to the other taps, but
reaches the emitting tap only after its current handler has returned:

```raku
my $supplier = Supplier.new;
$supplier.Supply.tap(-> $v {
    say "A starts $v";
    $supplier.emit(10) if $v == 1;
    say "A ends $v";
});
$supplier.Supply.tap(-> $v { say "B got $v" });
$supplier.emit(1);
```
```output
A starts 1
B got 10
A ends 1
A starts 10
A ends 10
B got 1
```

Tap B sees 10 before 1: the nested emit reached it while the outer emit
was still busy with tap A.

## A tap's handler never runs on two threads at once
tags: undocumented

A Supplier may be fed from several threads. Its taps still receive one value
at a time: a second emit waits until the tap's handler has finished with the
first. The program below emits forty values from four threads into a
handler that notices whenever it is entered while already running:

```raku local
my $sup = Supplier.new;
my atomicint $inside = 0;
my atomicint $overlaps = 0;
my atomicint $count = 0;
$sup.Supply.tap: -> $v {
    $overlaps⚛++ if $inside⚛++ > 0;
    $count⚛++;
    sleep 0.001;
    $inside⚛--;
}
await (^4).map: -> $t { start { $sup.emit($_) for ^10 } };
say "handled $count values, overlapped: ", $overlaps > 0;
```
```output
handled 40 values, overlapped: False
```

docs.raku.org gives this guarantee only for `.act`, described below; in
Rakudo 2026.08 a plain `.tap` of a Supplier, of an interval and of a `supply`
block behaves the same way.

## Supplier::Preserving keeps events until the first tap

A `Supplier::Preserving` stores what is emitted while nobody listens and
replays it, in order, to the first tap that arrives. From then on it is live
like a plain Supplier: a second tap starts with the next value. When the
last tap closes, it starts storing again, and a done is stored like a value.

```raku
my $supplier = Supplier::Preserving.new;
$supplier.emit(1);
$supplier.emit(2);
my $a = $supplier.Supply.tap(-> $v { say "A got $v" });
$supplier.emit(3);
my $b = $supplier.Supply.tap(-> $v { say "B got $v" });
$supplier.emit(4);
$a.close;
$b.close;
$supplier.emit(5);
$supplier.done;
$supplier.Supply.tap(-> $v { say "C got $v" }, done => { say "C done" });
```
```output
A got 1
A got 2
A got 3
A got 4
B got 4
C got 5
C done
```

## Only a Supplier's supply is live

`.live` tells whether a supply is fed by a Supplier. A supply derived from a
live one with a method such as `.map` is live too. `from-list`, `interval`
and `supply` blocks are on-demand, and `.live` is False for them. `.serial`,
the promise that values arrive one at a time, is True for all of these.

```raku
say Supplier.new.Supply.live;
say Supplier.new.Supply.map(* * 2).live;
say Supply.from-list(1).live;
say (supply { emit 1 }).live;
say Supply.from-list(1).serial, " ", Supplier.new.Supply.serial;
```
```output
True
True
False
False
True True
```

## Closing a tap twice runs an `on-close` hook twice
tags: quirk

`Tap.close` returns True, and closing a tap that is already closed does no
harm. `.on-close` adds a hook that runs when the tap is closed, but it runs
on every call of `.close`, not once:

```raku
my $supplier = Supplier.new;
my $closed = 0;
my $tap = $supplier.Supply.on-close({ $closed++ }).tap(-> $v { });
say $tap.close;
say $tap.close;
say "on-close ran $closed times";
```
```output
True
True
on-close ran 2 times
```

The `closing` hook of `Supply.on-demand`, in the next corner, runs only once
however often the tap is closed.

## `on-demand` runs its producer once per tap, on the tapping thread

`Supply.on-demand` takes a block that receives a fresh Supplier for each
tap and emits into it. The block runs when the supply is tapped, on the
thread that taps it, so its values arrive before `.tap` returns. The
`closing` hook, not described on docs.raku.org, runs when the tap ends,
whether by done or by `.close`.

```raku
my $runs = 0;
my $s = Supply.on-demand(
    -> $p { $runs++; $p.emit("run $runs"); $p.done },
    closing => { say "closing" },
);
$s.tap(-> $v { say "first tap: $v" });
$s.tap(-> $v { say "second tap: $v" });
say "producer ran $runs times";
```
```output
first tap: run 1
closing
second tap: run 2
closing
producer ran 2 times
```

A producer that does not call `done` leaves the tap open until it is
closed. An exception in the producer becomes the tap's quit:

```raku
my $s = Supply.on-demand(-> $p { $p.emit(1) }, closing => { say "closing" });
my $tap = $s.tap(-> $v { say "got $v" });
say "no done yet";
$tap.close;
$tap.close;
Supply.on-demand(-> $p { die "producer failed" })
    .tap(-> $v { }, quit => { say "quit: ", .message });
```
```output
got 1
no done yet
closing
quit: producer failed
```

## A supply block runs again for every tap

A `supply { … }` block is a recipe, not a running stream. Nothing in it runs
until it is tapped, and each tap runs the whole block afresh, with its own
variables:

```raku
my $running-total = supply {
    say "the block runs";
    my $total = 0;
    whenever Supply.from-list(1, 2, 3) { $total += $_; emit $total }
}
say "nothing ran yet";
$running-total.tap(-> $v { say "A: $v" });
$running-total.tap(-> $v { say "B: $v" });
```
```output
nothing ran yet
the block runs
A: 1
A: 3
A: 6
the block runs
B: 1
B: 3
B: 6
```

To share one run among several taps, see
[`share`](#ch:supplies:share-subscribes-once-and-at-once) below.

## The body runs to its end before any whenever event
tags: undocumented unasserted

A `whenever` subscribes to its supply as soon as it is reached, but the
events that supply delivers while the block body is still running are held
in a queue. They are handled one by one after the body has returned, in the
order they came. An `emit` in the body therefore goes out before the values
of a `whenever` written above it:

```raku
my $s = supply {
    emit "body 1";
    whenever Supply.from-list("w1", "w2") { emit $_ }
    emit "body 2";
}
$s.tap(-> $v { say $v });
```
```output
body 1
body 2
w1
w2
```

The same holds for a `whenever` inside the body of another `whenever`: its
events wait until the outer body returns, and behind any events already
queued.

```raku
my $s = supply {
    whenever Supply.from-list(1, 2) -> $outer {
        emit "outer $outer";
        whenever Supply.from-list("a", "b") -> $inner { emit "inner $outer$inner" }
    }
}
$s.tap(-> $v { say $v });
```
```output
outer 1
outer 2
inner 1a
inner 1b
inner 2a
inner 2b
```

The one queue is also what makes a supply block safe with threads: however
many threads feed its `whenever`s, only one body runs at a time.

## Closing the Tap of a whenever does not finish the supply
tags: trap

`do whenever` evaluates to the `Tap` of that subscription, and closing it
stops the events of that one `whenever`. The supply block does not count
the closed `whenever` as finished, so the supply is never done. `last`,
described below, closes the `whenever` and lets the supply finish:

```raku
my $source = Supplier.new;
my $s = supply {
    my $tap = do whenever $source.Supply -> $v {
        emit $v;
        $tap.close if $v == 2;
    }
    say "whenever gave a ", $tap.^name;
}
$s.tap(-> $v { say "got $v" }, done => { say "done" });
$source.emit($_) for 1..4;
say "---";
my $source2 = Supplier.new;
my $s2 = supply {
    whenever $source2.Supply -> $v {
        emit $v;
        last if $v == 2;
    }
}
$s2.tap(-> $v { say "got $v" }, done => { say "done" });
$source2.emit($_) for 1..4;
```
```output
whenever gave a Tap
got 1
got 2
---
got 1
got 2
done
```

## whenever accepts anything that coerces to a Supply

The argument of `whenever` is turned into a Supply with the `Supply`
coercion. A list gives one event per element, and a plain string or number
gives one event:

```raku
my @seen;
react {
    whenever (1, 2, 3) { @seen.push($_) }
    whenever "text" { @seen.push($_) }
    whenever 42 { @seen.push($_) }
    whenever [4, 5] { @seen.push($_) }
}
say @seen.raku;
```
```output
[1, 2, 3, "text", 42, 4, 5]
```

A Promise and a Channel are coerced too; the next two corners show how they
behave.

## A whenever over a Promise delivers its value later, from another thread

A Promise becomes a supply that emits the Promise's result and is then done
(its `.Supply` is in [Promises, Locks and Awaiting](#ch:promises)). The
value is handed over by the thread pool, even when the Promise is kept
already, so a `supply` block tapped with `.tap` has not seen it when `.tap`
returns. A `react` block, which waits, or an `await` on the done collects
it:

```raku local
my @got;
my $done = Promise.new;
my $s = supply { whenever Promise.kept(42) { emit $_ } }
$s.tap(-> $v { @got.push($v) }, done => { $done.keep });
say "when tap returns: ", @got.raku;
await $done;
say "after the done: ", @got.raku;
```
```output
when tap returns: []
after the done: [42]
```

`Promise.in` delivers `True` when its time is up. A broken Promise is a
quit carrying the Promise's cause, and `react` rethrows it:

```raku local
react { whenever Promise.in(0.05) { say "Promise.in gives $_" } }
try react { whenever Promise.broken("no luck") { say "never" } }
say "a broken Promise is a quit: ", $!.message;
```
```output
Promise.in gives True
a broken Promise is a quit: no luck
```

## A whenever over a Channel drains it until it closes

A Channel becomes a supply of the values received from it. Closing the
Channel is the supply's done, and failing it is the quit, which comes after
the values sent before the failure:

```raku local
my $c = Channel.new;
$c.send($_) for 1..3;
$c.close;
react {
    whenever $c { say "from the channel: $_" }
}
my $f = Channel.new;
$f.send("a");
$f.fail("channel failed");
try react {
    whenever $f { say "from the channel: $_" }
}
say "quit: ", $!.message;
```
```output
from the channel: 1
from the channel: 2
from the channel: 3
from the channel: a
quit: channel failed
```

## react waits until it is done and then returns Nil

A `react` block runs like a tapped `supply` block, then waits until every
`whenever` in it is finished or `done` is called. Its value is Nil,
whatever its last statement was. As in a `supply` block, the body runs to
its end before any `whenever` event is handled:

```raku
my $r = react {
    whenever Supply.from-list(1, 2, 3) {
        say "got $_";
        done if $_ == 2;
    }
    say "end of the react body";
}
say "react returned ", $r.raku;
say (react { whenever Supply.from-list(1) { }; 42 }).raku;
```
```output
end of the react body
got 1
got 2
react returned Any
Nil
```

Assigning the Nil to `$r` leaves the variable holding `Any`.

## A quit ends react with the exception

An exception thrown in a `react` block, or a quit from one of its
`whenever` supplies, ends the `react` and is rethrown from it:

```raku
try react {
    whenever Supply.from-list(1, 2) { die "failed on $_" if $_ == 2 }
}
say "react threw: ", $!.message;
```
```output
react threw: failed on 2
```

Uncaught, the report names the `react` first and the exception after it:

```raku
react {
    whenever Supply.from-list(1, 2) {
        die "cannot handle $_" if $_ == 2;
    }
}
```
```output
```
```stderr
A react block:
  in block <unit> at example.raku line 1

Died because of the exception:
    cannot handle 2
      in block <unit> at example.raku line 3

```

## `emit` inside react only warns

A `react` block has nobody to emit to. An `emit` there is not an error: it
warns, and the value goes nowhere.

```raku
react {
    emit 1;
    whenever Supply.from-list(1) { }
}
say "after";
```
```output
after
```
```stderr
Useless use of emit in react
  in block  at example.raku line 2
```

## `done` ends the supply at once

`done`, in the body or in a `whenever`, finishes the supply on the spot: the
rest of the block does not run, the tap's done handler is called, every
`whenever` is closed along with its subscription to its source, and later
events are ignored.

```raku
my $s = supply {
    whenever Supply.from-list(1, 2, 3) -> $v {
        emit $v;
        if $v == 2 {
            done;
            say "not reached";
        }
    }
}
$s.tap(-> $v { say "got $v" }, done => { say "done" });
```
```output
got 1
got 2
done
```

Because the events of a `whenever` wait for the body (see
[The body runs to its end before any whenever event](#ch:supplies:the-body-runs-to-its-end-before-any-whenever-event)),
a `done` at the end of the body drops them all. Code after a `done` in the
body does not run, so an `emit` there never happens:

```raku
my $s = supply {
    whenever Supply.from-list(1, 2) { emit $_ }
    emit "from the body";
    done;
}
$s.tap(-> $v { say "got $v" }, done => { say "done" });
say (supply { emit 1; done; say "not reached"; emit 3 }).list;
```
```output
got from the body
done
(1)
```

## `last` finishes one whenever, `next` skips one value

Inside a `whenever` block, `next` ends the handling of the current value
and `last` closes that `whenever` for good, running its `LAST` phaser. When
no `whenever` is left, the supply is done.

```raku
my $s = supply {
    whenever Supply.from-list(1, 2, 3, 4) -> $v {
        next if $v == 2;
        emit $v;
        last if $v == 3;
        LAST { say "LAST ran" }
    }
}
$s.tap(-> $v { say "got $v" }, done => { say "done" });
```
```output
got 1
got 3
LAST ran
done
```

Like `done`, `last` closes the subscription to the source, so a source that
is itself a `supply` block runs its `CLOSE` phaser:

```raku
my $sup = Supplier.new;
my $source = supply {
    whenever $sup.Supply { emit $_ }
    CLOSE { say "the source is closed" }
}
react {
    whenever $source {
        say "got $_";
        last if $_ == 2;
    }
    $sup.emit($_) for 1..3;
}
say "react returned";
```
```output
got 1
got 2
the source is closed
react returned
```

## A LAST run by `last` cannot emit
tags: bug

A `LAST` phaser in a `whenever` runs when its source finishes, and there
it can `emit` like the rest of the block. When `last` is what runs it, the
phaser is no longer inside the supply: `emit` dies with "emit without supply
or react", and the supply quits.

```raku
sub numbers($stop) {
    supply {
        whenever Supply.from-list(1, 2, 3) {
            emit $_;
            last if $_ == $stop;
            LAST { emit "from LAST" }
        }
    }
}
numbers(9).tap(-> $v { say "got $v" }, done => { say "done" });
numbers(2).tap(-> $v { say "got $v" }, done => { say "done" },
               quit => { say "quit: ", .message });
```
```output
got 1
got 2
got 3
got from LAST
done
got 1
got 2
quit: emit without supply or react
```

A tap without a quit handler hears nothing at all: neither the quit nor a
done arrives, and no exception is thrown. Under `react` the exception ends
the program. Rakudo 2026.08 behaves this way; a `LAST` should see the same
supply whichever way its `whenever` ended.

## A supply block is done when its body and every whenever are done

A `supply` block finishes by itself once its body has returned and every
`whenever` in it has finished. One `whenever` over a source that never ends
keeps the whole supply open:

```raku
my $never = Supplier.new;
my $s = supply {
    whenever Supply.from-list(1, 2) { emit $_ }
    whenever Supply.from-list(3) { emit $_ }
}
$s.tap(-> $v { say "got $v" }, done => { say "done after both" });
my $s2 = supply {
    whenever Supply.from-list(1) { emit $_ }
    whenever $never.Supply { emit $_ }
}
$s2.tap(-> $v { say "got $v" }, done => { say "never printed" });
say "the second supply is still open";
```
```output
got 1
got 2
got 3
done after both
got 1
the second supply is still open
```

## An exception in a supply block becomes its quit

A `die` in the body or in a `whenever` ends the supply with a quit, which
goes to the tap's quit handler. The values emitted before it have already
been delivered.

```raku
my $s = supply { emit 1; die "boom" }
$s.tap(-> $v { say "got $v" }, quit => { say "quit: ", .message, " (", .^name, ")" });
```
```output
got 1
quit: boom (X::AdHoc)
```

A `CATCH` inside a `whenever` block handles an exception of that block like
anywhere else: the value is abandoned and the supply goes on.

```raku
my $s = supply {
    whenever Supply.from-list(1, 2, 3) {
        die "no twos" if $_ == 2;
        emit $_;
        CATCH { default { say "skipped: ", .message } }
    }
}
$s.tap(-> $v { say "got $v" }, done => { say "done" });
```
```output
got 1
skipped: no twos
got 3
done
```

## One whenever's quit ends the whole supply

When the supply of one `whenever` quits and nothing handles it, the whole
`supply` block quits with that exception. The other `whenever`s are closed,
and their events still waiting in the queue are dropped:

```raku
my $s = supply {
    whenever Supply.from-list(1, 2) { emit $_ }
    whenever Supply.from-list(3, 4).map({ die "second source failed" }) { emit $_ }
    whenever Supply.from-list(5) { emit $_ }
}
$s.tap(-> $v { say "got $v" }, done => { say "done" }, quit => { say "quit: ", .message });
```
```output
got 1
got 2
quit: second source failed
```

## QUIT belongs to the whenever and handles a quit like CATCH

A `QUIT` phaser inside a `whenever` block runs when that `whenever`'s
source quits, with the exception as its topic. It chooses with `when` and
`default` as `CATCH` does. A branch that matches consumes the quit: the
`whenever` counts as finished, and the rest of the supply goes on.

```raku
my $failing = Supply.from-list(1, 2).map({ die "source failed at $_" if $_ == 2; $_ });
my $s = supply {
    whenever $failing {
        emit $_;
        QUIT { default { say "QUIT handled: ", .message } }
    }
    whenever Supply.from-list("other") { emit $_ }
}
$s.tap(-> $v { say "got $v" }, done => { say "done" }, quit => { say "quit reached the tap" });
```
```output
got 1
QUIT handled: source failed at 2
got other
done
```

## A QUIT that matches nothing lets the quit through
tags: unasserted

When no `when` of a `QUIT` matches, or the phaser has no `when` or
`default` at all, its code runs and the quit goes on to the tap as though
the phaser were not there. The value the phaser returns plays no part. A
quit cannot be resumed: `.resume` inside a `QUIT` fails, and its failure is
what reaches the tap.

```raku
sub failing { Supply.from-list(1).map({ die "source failed" }) }
my $s1 = supply {
    whenever failing() {
        QUIT { when X::NYI { say "never" } }
    }
}
$s1.tap(-> $v { }, quit => { say "no match, tap's quit: ", .message });
my $s2 = supply {
    whenever failing() {
        QUIT { say "QUIT ran without when" }
    }
}
$s2.tap(-> $v { }, quit => { say "tap's quit: ", .message });
my $s3 = supply {
    whenever failing() {
        QUIT { default { .resume } }
    }
}
$s3.tap(-> $v { }, quit => { say "tap's quit: ", .message });
```
```output
no match, tap's quit: source failed
QUIT ran without when
tap's quit: source failed
tap's quit: Too late to resume this exception
```

## QUIT sees only its own source
tags: unasserted

A `QUIT` handles the quit of the supply its `whenever` subscribed to, and
nothing else. An exception thrown by the `whenever` body is not a quit of
the source, so a `QUIT` in the same block does not see it; a `CATCH` does
(see
[An exception in a supply block becomes its quit](#ch:supplies:an-exception-in-a-supply-block-becomes-its-quit)).
A `QUIT` written in the supply body, outside every `whenever`, sees neither
kind:

```raku
my $s1 = supply {
    whenever Supply.from-list(1) {
        die "the body failed";
        QUIT { default { say "never: ", .message } }
    }
}
$s1.tap(-> $v { }, quit => { say "tap's quit: ", .message });
my $s2 = supply {
    whenever Supply.from-list(1).map({ die "source failed" }) { }
    QUIT { default { say "never: block-level QUIT" } }
}
$s2.tap(-> $v { }, quit => { say "tap's quit: ", .message });
```
```output
tap's quit: the body failed
tap's quit: source failed
```

## LAST runs when a source finishes, not on `done`

A `LAST` phaser in a `whenever` runs when that `whenever`'s source is done,
and each `whenever` runs its own in turn. An explicit `done` skips every
`LAST` still pending. A `LAST` written in the supply body, outside the
`whenever`s, never runs.

```raku
my $s = supply {
    whenever Supply.from-list(1, 2) {
        emit $_;
        LAST { say "LAST: first source finished" }
    }
    whenever Supply.from-list(3) {
        emit $_;
        done;
        LAST { say "LAST: never, done skips it" }
    }
    LAST { say "never: a block-level LAST" }
}
$s.tap(-> $v { say "got $v" }, done => { say "done" });
```
```output
got 1
got 2
LAST: first source finished
got 3
done
```

## CLOSE phasers run in reverse, before or after the done handler
tags: quirk

`CLOSE` phasers in a `supply` block run when the supply is torn down, the
last one declared first. When the supply ends by itself, they run after the
tap's done handler; when it ends by an explicit `done`, before it:

```raku
my $natural = supply {
    whenever Supply.from-list(1) { emit $_ }
    CLOSE { say "CLOSE 1" }
    CLOSE { say "CLOSE 2" }
}
$natural.tap(-> $v { say "got $v" }, done => { say "done handler" });
say "---";
my $explicit = supply {
    whenever Supply.from-list(1) { emit $_; done }
    CLOSE { say "CLOSE 1" }
    CLOSE { say "CLOSE 2" }
}
$explicit.tap(-> $v { say "got $v" }, done => { say "done handler" });
```
```output
got 1
done handler
CLOSE 2
CLOSE 1
---
got 1
CLOSE 2
CLOSE 1
done handler
```

On a quit, `CLOSE` runs before the quit handler:

```raku
my $s = supply {
    whenever Supply.from-list(1) { die "failed" }
    CLOSE { say "CLOSE ran" }
}
$s.tap(-> $v { }, quit => { say "quit handler" });
```
```output
CLOSE ran
quit handler
```

## Closing the tap of a supply block closes everything inside it

Closing the `Tap` of a `supply` block closes all its `whenever`
subscriptions and runs its `CLOSE` phasers. Later events from the sources
reach nobody:

```raku
my $source = Supplier.new;
my $s = supply {
    whenever $source.Supply { emit $_ }
    CLOSE { say "CLOSE ran" }
}
my $tap = $s.tap(-> $v { say "got $v" });
$source.emit(1);
$tap.close;
$source.emit(2);
say "after close";
```
```output
got 1
CLOSE ran
after close
```

## `whenever` outside a supply or react does not compile

`whenever` makes sense only inside a `supply` or `react` block, and the
compiler checks it:

```raku
whenever Supply.from-list(1) { say $_ }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Cannot have a 'whenever' block outside the scope of a 'supply' or 'react' block
at example.raku:1
------> whenever<HERE> Supply.from-list(1) { say $_ }
```

`done` and `emit` are only checked when they run. Called from an ordinary
tap handler, while the body of the `supply` block is emitting, `done` dies:

```raku
my $s = supply { emit 1; emit 2 }
$s.tap(-> $v { say "got $v"; done });
```
```output
got 1
```
```stderr
done without supply or react
  in block <unit> at example.raku line 2

```

## `done` in a tap handler can end a supply block without its done handler
tags: quirk undocumented

When the value comes from a `whenever` rather than from the body, a `done`
in the tap handler is taken as the supply block's own `done`. The supply
ends, but the tap's done handler is never called:

```raku
my $s = supply { whenever Supply.from-list(1, 2, 3) { emit $_ } }
$s.tap(
    -> $v { say "got $v"; done if $v == 2 },
    done => { say "done handler" },
);
say "tap returned";
```
```output
got 1
got 2
tap returned
```

## An exception in `.map` becomes a quit, and later values still arrive
tags: bug

`.map` turns an exception in its code into a quit. After a quit nothing
should follow. In Rakudo 2026.08, when the source is
synchronous, as `from-list` is, it goes on producing: the values after the
failing one are still mapped and delivered, and the done arrives after the
quit. `.grep` does the same.

```raku
Supply.from-list(1, 2, 3, 4)
    .map({ die "cannot map $_" if $_ == 2; $_ * 10 })
    .tap(-> $v { say "got $v" }, done => { say "done" }, quit => { say "quit: ", .message });
```
```output
got 10
quit: cannot map 2
got 30
got 40
done
```

A live source is closed properly, and `.do` or a `supply` block stop at the
quit as they should:

```raku
my $sup = Supplier.new;
$sup.Supply.map({ die "cannot map $_" if $_ == 2; $_ * 10 })
    .tap(-> $v { say "live got $v" }, done => { say "live done" },
         quit => { say "live quit: ", .message });
$sup.emit($_) for 1..3;
$sup.done;
Supply.from-list(1, 2, 3)
    .do({ die "cannot do $_" if $_ == 2 })
    .tap(-> $v { say "do got $v" }, quit => { say "do quit: ", .message });
```
```output
live got 10
live quit: cannot map 2
do got 1
do quit: cannot do 2
```

## After a leaking quit, `.list` and `await` lose the exception
tags: bug

The events that follow a quit from `.map` (previous corner) confuse the
consumers that turn a supply into a value. The late done completes a `.list`
normally, so the list ends before the failing value and no exception is
thrown. `await` returns the last value it saw, or `Any` when there was
none, and records no exception. `.wait` does throw, but the wrong exception:

```raku
my &risky = { die "cannot map $_" if $_ == 2; $_ * 10 };
my @all = Supply.from-list(1, 2, 3).map(&risky).list;
say @all;
my $last = try await Supply.from-list(1, 2, 3).map(&risky);
say $last, " ", $!.raku;
my $none = try await Supply.from-list(2).map(&risky);
say $none.raku, " ", $!.raku;
try Supply.from-list(1, 2, 3).map(&risky).wait;
say $!.message;
```
```output
[10]
30 Any
Any Any
Type check failed in binding; expected Exception but got Any (Any)
```

`$!` is `Any` because each `try` succeeded. A `supply` block or an
`on-demand` supply that dies is awaited correctly: `await` throws its
exception.

## `grep` smartmatches, and `first` is `grep` then `head`

`.grep` accepts anything that can be smartmatched: a type, a value, a regex
or a code block. `.first` without a test is `.head`; with a test it emits
the first value that passes and then is done; with `:end` it emits the last one, which it knows only when
the source is done. Without a match it emits nothing.

```raku
my $s = Supply.from-list(1, "a", 2.5, 3, "bc");
say $s.grep(Int).list;
say $s.grep(3).list;
say $s.grep(/<alpha>/).list;
say $s.grep(Numeric).grep(* > 2).list;
my $n = Supply.from-list(1, 2, 3, 4);
say $n.first(* > 1).list;
say $n.first(* > 1, :end).list;
say $n.first(* > 9).list;
```
```output
(1 3)
(3)
(a bc)
(2.5 3)
(2)
(4)
()
```

## `head` closes its source; `tail` waits for done

`.head(n)` passes on the first `n` values and is then done, closing its
subscription to the source. `.head(*-n)` holds back the last `n`, and
`.tail`, `.tail(n)` and `.tail(*-n)` wait for the source to be done.
`.skip(n)` drops the first `n`, and a count of zero or below drops nothing.

```raku
my $s = Supply.from-list(1, 2, 3, 4);
say $s.head(2).list;
say $s.head(0).list;
say $s.head(*-1).list;
say $s.tail.list;
say $s.tail(2).list;
say $s.tail(*-1).list;
say $s.skip.list;
say $s.skip(-1).list;
```
```output
(1 2)
()
(1 2 3)
(4)
(3 4)
(2 3 4)
(2 3 4)
(1 2 3 4)
```

On a live source, the source's subscription is closed as soon as `head` has
its values:

```raku
my $sup = Supplier.new;
my $s = supply {
    whenever $sup.Supply { emit $_ }
    CLOSE { say "source closed" }
}
$s.head(2).tap(-> $v { say "got $v" }, done => { say "done" });
$sup.emit($_) for 1..4;
say "end";
```
```output
got 1
got 2
source closed
done
end
```

## `tail` of an empty supply emits Any
tags: quirk

A List's `.tail` of nothing is Nil. A Supply's `.tail` and `.tail(1)`, when
the source ends without a value, emit one `Any`. `.tail(2)` emits nothing.

```raku
say Supply.from-list().tail.list.raku;
say Supply.from-list().tail(1).list.raku;
say Supply.from-list().tail(2).list.raku;
say ().tail.raku;
```
```output
(Any,)
(Any,)
()
Nil
```

## `unique` compares by identity; `squish`'s `:with` sees the previous value

`.unique` emits each value the first time it appears. Values are compared by
identity, so `1` and `"1"` are different; `:as` compares a key computed from
each value instead. `.squish` drops a value equal to the one just before it,
and `.repeated` emits only values seen before.

```raku
say Supply.from-list(1, 2, 1, 3, 2).unique.list;
say Supply.from-list(1, "1", 1).unique.list.raku;
say Supply.from-list(<ab cd e>).unique(:as(*.chars)).list;
say Supply.from-list(1, 1, 2, 2, 1).squish.list;
say Supply.from-list(1, 1, 2, 1, 3, 1).repeated.list;
say Supply.from-list(<a A b B>).repeated(:as(&lc)).list;
```
```output
(1 2 3)
(1, "1")
(ab e)
(1 2 1)
(1 1 1)
(A B)
```

A `:with` comparator given to `.squish` is called with the previous value
of the source and the new one, whether or not the previous one was kept, as
for [a list's `squish`](#ch:lists:unique-compares-with-what-it-kept-squish-with-the-previous-element):

```raku
my &next-number = -> $prev, $new { say "  with($prev, $new)"; $new == $prev + 1 };
say Supply.from-list(1, 2, 3, 5).squish(:with(&next-number)).list;
```
```output
  with(1, 2)
  with(2, 3)
  with(3, 5)
(1 5)
```

On a live supply, `:expires` lets a value through again once that many
seconds have passed since it was last emitted:

```raku local
my $sup = Supplier.new;
my @got;
$sup.Supply.unique(:expires(0.1)).tap(-> $v { @got.push($v) });
$sup.emit("a");
$sup.emit("a");
$sup.emit("b");
sleep 0.2;
$sup.emit("a");
$sup.emit("b");
say @got;
```
```output
[a b a b]
```

## `rotor` emits Arrays and repeats its cycle

`.rotor` cuts the stream into batches. Each count may be a pair
`count => gap`, where a positive gap skips values and a negative one makes
the batches overlap, and several counts form a cycle that repeats. A short
last batch is emitted only with `:partial`. Unlike a List's `rotor`, which
gives Lists, each batch is an Array.

```raku
my $s = Supply.from-list(1..7);
say $s.rotor(3).list.raku;
say $s.rotor(3, :partial).list.raku;
say $s.rotor(3 => -1).list.raku;
say $s.rotor(2 => 1, :partial).list.raku;
say $s.rotor(1, 2).list.raku;
say (1..7).rotor(3).raku;
```
```output
([1, 2, 3], [4, 5, 6])
([1, 2, 3], [4, 5, 6], [7])
([1, 2, 3], [3, 4, 5], [5, 6, 7])
([1, 2], [4, 5], [7])
([1], [2, 3], [4], [5, 6], [7])
((1, 2, 3), (4, 5, 6)).Seq
```

## `batch` without a size makes batches of one

`.batch` takes named arguments only: `:elems` for a size, `:seconds` for a
time. With neither, or with an `:elems` of zero or less, every value comes
in a batch of its own; docs.raku.org does not say so. A short last batch is
emitted when the source is done. The batches are Lists.

```raku
my $s = Supply.from-list(1..5);
say $s.batch.list.raku;
say $s.batch(:elems(2)).list.raku;
say $s.batch(:elems(0)).list.raku;
```
```output
((1,), (2,), (3,), (4,), (5,))
((1, 2), (3, 4), (5,))
((1,), (2,), (3,), (4,), (5,))
```

## `batch(:emit-timed)` never emits
tags: bug

With `:seconds`, a batch collects the values that fall in one slice of the
wall clock, and it is emitted when a value arrives in a later slice, or at
done. docs.raku.org adds that `:emit-timed` runs a timer that emits the
waiting batch at the end of each slice. In Rakudo 2026.08 a batch with
`:emit-timed` emits nothing at all, not even the done:

```raku local
for False, True -> $timed {
    my $sup = Supplier.new;
    my @got;
    $sup.Supply.batch(:seconds(0.1), :emit-timed($timed))
        .tap(-> $b { @got.push($b) }, done => { @got.push("done") });
    $sup.emit(1);
    $sup.emit(2);
    sleep 0.2;
    $sup.emit(3);
    $sup.done;
    sleep 0.1;
    say ":emit-timed($timed) ", @got.raku;
}
```
```output
:emit-timed(False) [(1, 2), (3,), "done"]
:emit-timed(True) []
```

Without `:emit-timed`, the batch `(1, 2)` waited until the value 3 arrived
in a new slice.

## `elems($seconds)` never reports the final count
tags: bug

`.elems` emits the running count after every value. Given a number of
seconds, it is meant to emit the count at most once in each such interval,
and the final count at done. Rakudo 2026.08 never emits the final count, so
a source that finishes within one interval reports nothing:

```raku
say Supply.from-list(<a b c>).elems.list;
say Supply.from-list(<a b c>).elems(10).list;
```
```output
(1 2 3)
()
```

An interval below one second is not usable either: the first value makes
`.elems` divide by zero.

```raku
try say Supply.from-list(1, 2).elems(0.5).list;
say $!.^name;
```
```output
X::Numeric::DivideByZero
```

## `min` and `max` emit each new record

`.min` and `.max` emit a value each time it beats every value before it,
strictly: an equal value is not a new record. Undefined values are skipped.
`.minmax` emits a Range of the smallest and largest so far each time either
changes. A one-parameter block computes a key to compare; a two-parameter
block is the comparison itself.

```raku
my $s = Supply.from-list(3, 1, 4, 1, 5, 0);
say $s.min.list;
say $s.max.list;
say $s.minmax.list.raku;
say Supply.from-list(3, Any, 1).min.list;
say Supply.from-list(<bb a ccc dd>).max(*.chars).list;
say Supply.from-list(<bb a ccc dd>).min(-> $a, $b { $a.chars <=> $b.chars }).list;
```
```output
(3 1 0)
(3 4 5)
(3..3, 1..3, 1..4, 1..5, 0..5)
(3 1)
(bb ccc)
(bb a)
```

## `reduce` of an empty supply emits Nil
tags: unasserted

`.reduce` emits one value when the source is done, the fold of all its
values; `.produce` emits every step of the fold as it goes. On an empty
source `.produce` emits nothing, and `.reduce` emits Nil. A List's
`.reduce` of nothing calls the function with no arguments instead, which
gives the operator's identity or dies:

```raku
say Supply.from-list(1, 2, 3).reduce(&[+]).list;
say Supply.from-list(1, 2, 3).produce(&[+]).list;
say Supply.from-list().reduce(&[+]).list.raku;
say Supply.from-list().produce(&[+]).list.raku;
say ().reduce(&[+]).raku;
try ().reduce(-> $a, $b { $a + $b });
say $!.^name;
```
```output
(6)
(1 3 6)
(Nil,)
()
0
X::AdHoc
```

## `sort` and `reverse` wait for done; `rotate` holds back only its count

`.sort`, `.reverse`, `.collate` and the general `.grab` collect every value
until the source is done and then emit the result, one value at a time.
`.grab` passes the whole list to its block.

```raku
my $s = Supply.from-list(3, 1, 2);
say $s.grab(*.sum).list;
say $s.sort.list;
say $s.sort(-*).list;
say $s.reverse.list;
say Supply.from-list(<b A a B>).collate.list;
```
```output
(6)
(1 2 3)
(3 2 1)
(2 1 3)
(a A b B)
```

`.rotate(n)` with a positive `n` holds back only the first `n` values, lets
the rest through as they arrive, and emits the held ones at done. When fewer
than `n` values arrive, it emits them rotated as a list would be; a
negative count collects everything first.

```raku
my $sup = Supplier.new;
$sup.Supply.rotate(2).tap(-> $v { say "got $v" }, done => { say "done" });
for 1..4 { say "emit $_"; $sup.emit($_) }
say "sending done";
$sup.done;
say Supply.from-list(1, 2, 3, 4).rotate(-1).list;
say Supply.from-list(1, 2).rotate(3).list;
```
```output
emit 1
emit 2
emit 3
got 3
emit 4
got 4
sending done
got 1
got 2
done
(4 1 2 3)
(2 1)
```

## `classify` emits a Pair per new key, with a supply that replays
tags: undocumented

`.classify` emits a Pair the first time a key appears: the key, and a
Supply of the values with that key. Keys are compared by identity, so `1`
and `"1"` are two keys. Each inner supply keeps its values for a tap that
comes late, so the groups can be read after the whole source has been
consumed:

```raku
my $groups = Supply.from-list(1, 2, 3, 4, 5).classify({ $_ %% 2 ?? "even" !! "odd" });
for $groups.list -> $pair {
    say $pair.key, " => ", $pair.value.^name, " ", $pair.value.list;
}
say Supply.from-list(1, "1", 1).classify({ $_ }).list.map(*.key.raku);
```
```output
odd => Supply (1 3 5)
even => Supply (2 4)
(1 "1")
```

`.categorize` takes a block that returns several keys, and the value goes
to each of them:

```raku
my $words = Supply.from-list(<apple avocado banana cherry>);
my $by-letter = $words.categorize({ .substr(0, 1), .chars > 6 ?? "long" !! "short" });
say $by-letter.list.map({ .key => .value.list }).raku;
```
```output
(:a(("apple", "avocado")), :short(("apple", "banana", "cherry")), :long(("avocado",)), :b(("banana",)), :c(("cherry",))).Seq
```

## `lines` and `words` join text across chunks

A supply of strings is often a stream of chunks, as read from a socket or a
process, cut at arbitrary places. `.lines` and `.words` join the chunks
before splitting, so a line or word cut in two comes out whole. A `"\r"`
at the end of a chunk waits to see whether `"\n"` follows. The last line
is emitted at done, with or without a newline.

```raku
my $chunks = Supply.from-list("first li", "ne\nsecond\nthi", "rd");
say $chunks.lines.list.raku;
say $chunks.lines(:!chomp).list.raku;
say Supply.from-list("a\r", "\nb\r\n").lines.list.raku;
say Supply.from-list("one tw", "o  three ", "four").words.list.raku;
```
```output
("first line", "second", "third")
("first line\n", "second\n", "third")
("a", "b")
("one", "two", "three", "four")
```

## `split` with a limit drops the rest
tags: trap

`.split` joins chunks like `.lines` and emits the last piece at done, even
when it is empty. Its adverbs are those of `Str.split`, but a limit means
something else: `Str.split` leaves the rest of the string in its last
piece, while a Supply emits the first pieces and throws the rest away.

```raku
say Supply.from-list("a,b", ",c,").split(",").list.raku;
say Supply.from-list("a,,b").split(",", :skip-empty).list.raku;
say Supply.from-list("a,b,c").split(",", 2).list.raku;
say "a,b,c".split(",", 2).raku;
```
```output
("a", "b", "c", "")
("a", "b")
("a", "b")
("a", "b,c").Seq
```

## `comb` with a regex never joins a match across chunks
tags: quirk undocumented

`.comb` with no argument, a count or a string joins chunks like `.lines`.
With a regex, each chunk is combed as soon as it arrives, after the text
left over from the previous chunk. Only the text after the last match is
carried over, so a match that could go on into the next chunk is emitted as
it stands:

```raku
say Supply.from-list("abc", "de").comb(2).list.raku;
say Supply.from-list("xa", "ax").comb("aa").list.raku;
say Supply.from-list("a1b", "2c").comb(/<[a..z]>\d/).list.raku;
my @chunks = "id 12", "34 and 5";
say Supply.from-list(@chunks).comb(/\d+/).list.raku;
say @chunks.join.comb(/\d+/).raku;
```
```output
("ab", "cd", "e")
("aa",)
("a1", "b2")
("12", "34", "5")
("1234", "5").Seq
```

`:match`, which makes `Str.comb` return Match objects, changes nothing
here: the values are still strings, and the chunks are still combed one by
one.

```raku
say Supply.from-list("id 12", "34 and 5").comb(/\d+/, :match).list.raku;
say "id 12".comb(/\d+/, :match).map(*.^name);
```
```output
("12", "34", "5")
(Match)
```

## `decode` holds back the last character of every chunk
tags: quirk undocumented

`.encode` turns each string into a Blob, in UTF-8 unless another encoding
is named. `.decode` turns Blobs back into strings, but keeps the last
character of each decoded chunk until the next chunk or the done, because
the next chunk may start with a combining mark that belongs to it:

```raku
my @bytes = "e".encode, "\x[301]x".encode;
say Supply.from-list(@bytes).decode.list.raku;
say @bytes.map(*.decode).raku;
say Supply.from-list("é").encode("latin-1").list.map(*.raku);
```
```output
("é", "x")
("e", "\x[301]x").Seq
(Blob[uint8].new(233))
```

On a live supply this shows as a delay of one character:

```raku
my $sup = Supplier.new;
$sup.Supply.decode.tap(-> $text { say "decoded: ", $text.raku }, done => { say "done" });
say "send ab";
$sup.emit("ab".encode);
say "send c";
$sup.emit("c".encode);
say "send done";
$sup.done;
```
```output
send ab
decoded: "a"
send c
decoded: "b"
send done
decoded: "c"
done
```

## `flat` follows every inner supply; `migrate` only the newest

A supply may emit supplies. `.flat` subscribes to each inner supply as it
arrives and emits the values of all of them. `.migrate` subscribes to the
newest one only and closes its subscription to the one before:

```raku
my $outer = Supplier.new;
my $a = Supplier.new;
my $b = Supplier.new;
$outer.Supply.migrate.tap(-> $v { say "migrate got $v" });
$outer.Supply.flat.tap(-> $v { say "flat got $v" });
$outer.emit($a.Supply);
$a.emit("a1");
$outer.emit($b.Supply);
$a.emit("a2");
$b.emit("b1");
```
```output
migrate got a1
flat got a1
flat got a2
migrate got b1
flat got b1
```

`.migrate` of a value that is not a Supply throws
`X::Supply::Migrate::Needs`. The exception comes when the list is read (see
[`.list` subscribes at once and reads lazily](#ch:supplies:list-subscribes-at-once-and-reads-lazily)),
so the `try` must include the reading:

```raku
try Supply.from-list(1, 2).migrate.list.eager;
say $!.^name;
say $!.message;
```
```output
X::Supply::Migrate::Needs
.migrate needs Supplies to be emitted
```

## `merge` interleaves, and wants defined supplies

`Supply.merge` and the method form `$a.merge($b)` emit the values of all
their supplies as they come, and are done when all of them are done.
Merging nothing gives an empty supply that is done at once. An argument
that is not a defined Supply throws `X::Supply::Combinator`, whose
`.combinator` names the method; `zip` and `zip-latest` do the same.

```raku
my $a = Supplier.new;
my $b = Supplier.new;
Supply.merge($a.Supply, $b.Supply).tap(-> $v { say "got $v" }, done => { say "done" });
$a.emit("a1");
$b.emit("b1");
$a.done;
$b.emit("b2");
$b.done;
say Supply.merge().list;
try Supply.merge(Supply.from-list(1), (2, 3));
say $!.^name, " ", $!.combinator;
try Supply.from-list(1).zip(Supply);
say $!.^name, " ", $!.combinator;
```
```output
got a1
got b1
got b2
done
()
X::Supply::Combinator merge
X::Supply::Combinator zip
```

## `zip` pairs values in step; `zip-latest` pairs the latest ones

`.zip` waits until every supply has a value it has not used, then emits
them together as an itemized List, or folds them with `:with`. It is done
when one supply is done and the others have caught up with its count.
`.zip-latest` emits whenever any supply emits, once all have emitted at
least once, and pairs the new value with the latest of the others.

```raku
my $a = Supplier.new;
my $b = Supplier.new;
Supply.zip($a.Supply, $b.Supply).tap(-> $v { say "zip: ", $v.raku });
Supply.zip-latest($a.Supply, $b.Supply).tap(-> $v { say "latest: ", $v.raku });
$a.emit("a1");
$a.emit("a2");
$b.emit("b1");
$b.emit("b2");
$a.emit("a3");
```
```output
zip: $("a1", "b1")
latest: $("a2", "b1")
zip: $("a2", "b2")
latest: $("a2", "b2")
latest: $("a3", "b2")
```

With synchronous sources the first supply has emitted everything before the
second starts, so `zip-latest` pairs the second's values with the first's
last. `:initial` gives starting values, in the order of the supplies:

```raku
say Supply.zip(Supply.from-list(<a b c>), Supply.from-list(1, 2)).list.raku;
say Supply.zip(Supply.from-list(<a b>), Supply.from-list(1, 2), :with(&[~])).list.raku;
say Supply.from-list(1, 2, 3).zip-latest(Supply.from-list(4, 5)).list.raku;
say Supply.zip-latest(Supply.from-list(1, 2), Supply.from-list(3), :initial(0, 0)).list.raku;
```
```output
($("a", 1), $("b", 2))
("a1", "b2")
($(3, 4), $(3, 5))
($(1, 0), $(2, 0), $(2, 3))
```

## `sanitize` enforces the order of events, and `act` taps through it
tags: undocumented unasserted

`.serialize` returns a supply that never delivers two events at once, and
`.sanitize` also drops everything after a done or quit. Both return the
supply itself when it already has the property, which a Supplier's supply,
`from-list`, `on-demand` and `supply` blocks all do:

```raku
my $s = Supplier.new.Supply;
say $s.serialize === $s, " ", $s.sanitize === $s;
my $blk = supply { emit 1 };
say $blk.serialize === $blk, " ", $blk.sanitize === $blk;
```
```output
True True
True True
```

They matter for a supply built directly on the `Tappable` role, which
promises nothing. `.act` is `.sanitize` followed by `.tap`:

```raku
my $wild = Supply.new(class :: does Tappable {
    method tap(&emit, &done, &quit, &tap) {
        emit(1); done(); emit(2); done();
        Tap.new
    }
    method live { False }
    method serial { False }
    method sane { False }
});
$wild.tap(-> $v { say "raw got $v" }, done => { say "raw done" });
$wild.act(-> $v { say "act got $v" }, done => { say "act done" });
```
```output
raw got 1
raw done
raw got 2
raw done
act got 1
act done
```

`.schedule-on($scheduler)` goes the other way: it hands every event to a
scheduler, which may deliver them on other threads.

## `share` subscribes once, and at once

`.share` taps the source immediately and passes its events on to every tap
of the result, so the source runs once however many taps there are. Like a
Supplier, it gives a late tap only what comes after it: on a synchronous
source, everything is over before the first tap, done included.

```raku
my $runs = 0;
my $source = Supplier.new;
my $counted = supply {
    $runs++;
    whenever $source.Supply { emit "$_ (run $runs)" }
}
my $shared = $counted.share;
$shared.tap(-> $v { say "A: $v" });
$shared.tap(-> $v { say "B: $v" });
$source.emit(1);
say "the block ran $runs time";
my @got;
Supply.from-list(1, 2, 3).share.tap(-> $v { @got.push($v) }, done => { @got.push("done") });
say @got.raku;
```
```output
A: 1 (run 1)
B: 1 (run 1)
the block ran 1 time
[]
```

`.share.list` on such a source therefore never returns.

## `.list` subscribes at once and reads lazily

`.list` taps the supply when it is called, so values emitted between the
call and the reading are kept. The List it returns fills as the values
arrive, and reading past what has arrived waits for more. It is not lazy
in the sense of `.is-lazy`. `.Seq` works the same way.

```raku
my $sup = Supplier.new;
my $list = $sup.Supply.list;
$sup.emit(1);
$sup.emit(2);
$sup.done;
say $list;
say $list.^name, " ", $list.is-lazy;
say Supply.from-list(1, 2).Seq.^name;
```
```output
(1 2)
List False
Seq
```

A quit is thrown when the List is read, not when `.list` is called, so a
`try` around the call alone does not catch it:

```raku
my $s = supply { emit 1; die "boom" }
my $list = try $s.list;
say "try returned a ", $list.^name;
try say $list.elems;
say "reading it threw: ", $!.message;
```
```output
try returned a List
reading it threw: boom
```

## A supply as a Promise holds its last value

`.Promise` gives a Promise that is kept with the last value emitted, or Nil
when there was none, and broken with the exception of a quit. `.wait` and
`await` wait for that Promise.

```raku
say Supply.from-list(1, 2, 3).wait;
say await Supply.from-list(1, 2);
say Supply.from-list().wait.raku;
my $p = (supply { emit 1; die "stopped" }).Promise;
say $p.status, " ", $p.cause.message;
```
```output
3
2
Nil
Broken stopped
```

## `.Channel` closes on done and fails on quit

`.Channel` sends each value to a new Channel, closes it when the supply is
done and fails it when the supply quits. Receiving from a failed Channel
throws the exception once the values sent before it are taken:

```raku
my $c = Supply.from-list(1, 2, 3).Channel;
say $c.list;
my $f = (supply { emit 1; die "stream failed" }).Channel;
say $f.receive;
try $f.receive;
say $!.message;
```
```output
(1 2 3)
1
stream failed
```

## `interval` ticks from 0, and its delay comes first

`Supply.interval($seconds, $delay)` emits 0, 1, 2 … every `$seconds`, the
first tick after `$delay`, which defaults to 0. It never finishes by itself:
`done`, `.head` or closing the tap stops it. It is a class method, and
calling it on a Supply instance throws.

```raku local
say Supply.interval(0.05).head(3).list;
react {
    whenever Supply.interval(0.05) -> $n {
        say "tick $n";
        done if $n == 2;
    }
}
my $t0 = now;
my $first = Supply.interval(10, 0.1).head(1).list;
say $first, " after less than a second: ", now - $t0 < 1;
try Supply.from-list(1).interval(1);
say $!.^name;
```
```output
(0 1 2)
tick 0
tick 1
tick 2
(0) after less than a second: True
X::Parameter::InvalidConcreteness
```

## `delayed` shifts every event, done included

`.delayed($seconds)` delivers each event that much later, in the same
order, the done and the quit too. A delay of zero returns the supply
itself.

```raku local
my $s = Supply.from-list(1, 2, 3);
say $s.delayed(0) === $s;
my @got;
my $done = Promise.new;
$s.delayed(0.1).tap(-> $v { @got.push($v) }, done => { $done.keep });
say "right after tap: ", @got.raku;
await $done;
say "after the done: ", @got.raku;
```
```output
True
right after tap: []
after the done: [1, 2, 3]
```

## `stable` emits a waiting value after the done
tags: bug

`.stable($seconds)` passes a value on only when no newer value follows
within `$seconds`; a newer value replaces the waiting one. The done is
passed on at once, and a value still waiting then is emitted after it,
which breaks the rule that nothing follows a done. A `react` or a `.list`
has stopped listening by then and loses the value.

```raku local
my $sup = Supplier.new;
my @got;
$sup.Supply.stable(0.1).tap(-> $v { @got.push($v) }, done => { @got.push("done") });
$sup.emit(1);
$sup.emit(2);
sleep 0.2;
$sup.emit(3);
$sup.done;
sleep 0.2;
say @got;
say Supply.from-list(1, 2, 3).stable(0.05).list;
say Supply.from-list(1, 2, 3).stable(0).list;
```
```output
[2 done 3]
()
(1 2 3)
```

A time of zero passes every value through. Even `.act`, which should drop
events after a done, delivers the late value in Rakudo 2026.08.

## `throttle` lets a number of values through per interval

`.throttle($count, $seconds)` passes at most `$count` values in each
interval of `$seconds` and keeps the rest in a buffer, to be released in
later intervals. The done waits until the buffer is empty:

```raku local
my $sup = Supplier.new;
my @got;
my $done = Promise.new;
$sup.Supply.throttle(2, 0.1).tap(-> $v { @got.push($v) }, done => { $done.keep });
$sup.emit($_) for 1..5;
say "at once: ", @got;
$sup.done;
say "done sent, still buffered: ", @got;
await $done;
say "after the done: ", @got;
```
```output
at once: [1 2]
done sent, still buffered: [1 2]
after the done: [1 2 3 4 5]
```

A `:control` supply adjusts a running throttle with strings such as
`"limit:10"`, and a `:status` Supplier receives a hash for each
`"status:id"` request and a last one, with id `done`, at the end:

```raku local
my $status = Supplier.new;
my @reports;
$status.Supply.tap(-> %report { @reports.push(%report) });
my $control = Supplier.new;
my $sup = Supplier.new;
my $done = Promise.new;
$sup.Supply.throttle(1, 0.05, :control($control.Supply), :$status)
    .tap(-> $v { }, done => { $done.keep });
$sup.emit($_) for 1..4;
$control.emit("status:first");
$control.emit("limit:10");
$sup.done;
await $done;
say @reports.map(*<id>);
say @reports[0].keys.sort;
```
```output
(first done)
(allowed bled buffered emitted id limit vent-at)
```

A `:bleed` Supplier takes the overflow once the buffer holds `:vent-at`
values. At done the buffer is emptied into it too, and the throttled supply
is done at once:

```raku local
my $bleed = Supplier.new;
my @bled;
$bleed.Supply.tap(-> $v { @bled.push($v) }, done => { @bled.push("bleed done") });
my $sup = Supplier.new;
my @got;
my $done = Promise.new;
$sup.Supply.throttle(1, 0.05, :$bleed, :vent-at(2))
    .tap(-> $v { @got.push($v) }, done => { $done.keep });
$sup.emit($_) for 1..6;
$sup.done;
await $done;
say @got;
say @bled;
```
```output
[1]
[4 5 6 2 3 bleed done]
```

Given code instead of a time, `.throttle($count, &code)` runs the code for
each value on the thread pool, at most `$count` at a time, and emits the
Promise of each run once it is kept, not its result:

```raku local
my @status;
my @results;
react {
    whenever Supply.from-list(1, 2, 3).throttle(2, -> $n { $n * 10 }) -> $p {
        @status.push: $p.^name ~ " " ~ $p.status;
        @results.push: $p.result;
    }
}
say @status.unique;
say @results.sort;
```
```output
(Promise Kept)
(10 20 30)
```

## `Supply.start` emits a supply per value

`.start(&code)` runs the code for each value on the thread pool and emits,
for each, a supply that will emit the code's result and be done. The runs
overlap. `.flat` or `.migrate` turns the supply of supplies back into
values, and an exception in the code is the quit of its inner supply:

```raku local
my $started = Supply.from-list(1, 2).start(-> $n { $n * 10 });
say $started.list.map(*.^name);
say $started.flat.list.sort;
my $failing = Supply.from-list(1).start({ die "in the thread" });
try react { whenever $failing.flat { } }
say "quit: ", $!.message;
```
```output
(Supply Supply)
(10 20)
quit: in the thread
```
