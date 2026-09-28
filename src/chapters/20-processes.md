---
title: Processes
part: Time and the outside world
summary: run and shell wait for a program and return a Proc that holds its status and pipes; Proc::Async reports through supplies and promises, whose rules decide when output arrives and whether the program is ever seen to end.
---

Raku starts other programs in two ways. `run` and `shell` start a program,
wait for it, and return a `Proc`: an object that holds the exit status and,
when asked for, pipes to the program's standard input, output and error.
`Proc::Async` starts a program and returns at once. The program's output
arrives through supplies, and a promise is kept when the program ends.

This chapter goes through both. It shows what a `Proc` reports for each kind
of outcome, how the three streams are captured, fed, bound, decoded and split
into lines, and where the parent waits. The second half is about the rules of
`Proc::Async`, including the ones that leave a program's promise unsettled
for ever. What happens when a failed `Proc` is sunk is in
[Values Nobody Uses](#ch:sink:a-failed-process-throws-when-its-proc-is-sunk),
and `qx` and `qqx` are in
[Quotes and Interpolation](#ch:quotes:qx-returns-what-the-command-printed-and-never-fails).
Promises, supplies and `react` blocks in general are explained in
[Promises, Locks and Awaiting](#ch:promises) and [Supplies](#ch:supplies),
and file handles in [Files and Paths](#ch:files). Every example here
starts another program, so none of them can run in the browser.

## `run` passes arguments as they are; `shell` hands one string to `/bin/sh`

`run` takes the program and its arguments as separate strings and starts the
program directly, with no shell in between. Nothing in an argument is
expanded: a `$HOME`, a `*` or a space reaches the program exactly as written.
`shell` takes a single string and runs it with `/bin/sh -c` (on Windows, with
the program in `%*ENV<ComSpec>` and `/c`), so the shell splits the string into
words and expands what it finds first. `.command` gives back what was asked
for:

```raku local
my $p = run "printf", "<%s>", '$HOME', '*', 'a b', :out;
say $p.out.slurp(:close);
my $s = shell 'printf "<%s>" $0 "a  b" *.none', :out;
say $s.out.slurp(:close);
say run("true").command.raku;
say shell("true; true").command.raku;
```
```output
<$HOME><*><a b>
</bin/sh><a  b><*.none>
("true",)
("true; true",)
```

`printf` applies its format to each argument in turn, so every argument
appears in its own brackets. Under `shell`, `$0` is `/bin/sh`, and `*.none`
stays as written only because no file matches it. `.command` of a `shell`
Proc is a list of one element, the whole string.

## Arguments are turned into strings, and lists are flattened

Each positional argument of `run` is made a string: a number becomes its
digits and an `IO::Path` its path. A list or an array among the arguments is
flattened into separate arguments, so the program and its first arguments can
come as one list, and a named argument such as `:out` may stand anywhere:

```raku local
my @words = <b c>;
say run("printf", "<%s>", 42, 1.5, "x".IO, @words, (1, 2), :out).out.slurp(:close);
say run(<printf [%s] one>, :out).out.slurp(:close);
say run("printf", :out, "<%s>", "named anywhere").out.slurp(:close);
say (try run()) // $!.^name;
say run("").exitcode;
say shell("").exitcode;
```
```output
<42><1.5><x><b><c><1><2>
[one]
<named anywhere>
X::Multi::NoMatch
-1
0
```

`run()` with no program at all dies. `run("")` starts nothing and returns a
failed Proc (see
[A program that cannot start](#ch:processes:a-program-that-cannot-start-gives-exit-code-1-signal-254-and-no-pid)),
while `shell("")` runs an empty script, which succeeds. An undefined argument
becomes an empty string, with the usual "Use of uninitialized value" warning.
`shell` takes exactly one string: `shell "exit 1", "extra"` is rejected at
compile time, with *Calling shell(Str, Str) will never work*.

## A `Proc` is true only when the exit code and the signal are both 0

Without pipes, `run` and `shell` return after the program has ended.
`.exitcode` is its exit status and `.signal` the number of the signal that
killed it, 0 for a normal exit. A Proc is true only when both are 0, and as a
number it is its exit code. A program killed by a signal has exit code 0, so
the number alone cannot tell it from success:

```raku local
my $p = run "sh", "-c", "exit 3";
say $p.exitcode, " ", $p.signal, " ", ?$p, " ", +$p;
say ?run("true"), " ", +run("true");
my $k = run "sh", "-c", 'kill -9 $$';
say $k.exitcode, " ", $k.signal, " ", ?$k, " ", +$k;
say run("sh", "-c", "exit 256").exitcode;
say $p.pid ~~ Int && $p.pid > 0;
say $p.out.raku, " ", $p.os-error.raku;
```
```output
3 0 False 3
True 0
0 9 False 0
0
True
IO::Pipe Str
```

The status a program passes to its parent has eight bits, so `exit 256`
arrives as 0 before Raku sees it. `.pid` is the program's process id. A pipe
that was not asked for, like `.out` here, is the `IO::Pipe` type object, and
`.os-error` is the `Str` type object unless the program could not be started.

A Proc is otherwise a plain object: `say $p` prints a `Proc.new(…)` dump of
every attribute, the process id included, two Procs are never `eqv`, and
`Proc` and `Proc::Async` are unrelated classes, neither a subtype of the
other.

## A program that cannot start gives exit code -1, signal 254 and no pid
tags: quirk

When the program cannot be started, because it does not exist, its name is
empty or the `:cwd` directory is missing, `run` does not throw. It returns a
failed Proc with exit code -1, signal 254 and no process id, and `.os-error`
holds the system's explanation. Pipes that were asked for exist and read as
empty.

```raku local
my $p = run "no-such-command-here", "arg", :out;
say $p.exitcode, " ", $p.signal, " ", $p.pid.raku, " ", $p.so;
say $p.os-error;
say $p.out.slurp(:close).raku;
say run("sh", "-c", "true", :cwd<no-such-dir>).os-error;
my $s = shell "no-such-command-here 2>/dev/null";
say $s.exitcode, " ", $s.signal, " ", $s.pid.^name;
```
```output
-1 254 Nil False
Failed to spawn process no-such-command-here: no such file or directory (error code -2)
""
Failed to spawn process sh: no such file or directory (error code -2)
127 0 Int
```

The 254 carries no meaning; the documentation promises only the -1. A missing
directory is reported as a missing program, `sh`, which exists. With `shell`
the shell itself starts, and it is the shell that fails to find the command,
so the result is an ordinary exit code 127 with a process id. Sunk, a Proc
that never started throws like any other failure, and the message gains a
second line with the system's explanation:

```raku local
run "no-such-command-here";
```
```output
```
```stderr
The spawned command 'no-such-command-here' exited unsuccessfully (exit code: -1, signal: 254)
(OS error = Failed to spawn process no-such-command-here: no such file or directory (error code -2))
  in block <unit> at example.raku line 1

```

## `:out` gives a read-only `IO::Pipe`, and closing it returns the `Proc`

With `:out`, `run` returns as soon as the program has started, and `.out` is
an `IO::Pipe`: an `IO::Handle` opened for reading what the program writes. It
reads like a file handle, with `.get`, `.lines`, `.slurp` and `.eof`. Its line
separator, `nl-in`, is only `"\n"` (a file's default also has `"\r\n"`).
`.close` returns the Proc, which is why `$p.out.close` as a statement throws
for a failed program (see
[`.out.close` sinks the `Proc`](#ch:sink:outclose-sinks-the-proc-slurpclose-does-not)),
and `.proc` gives the same Proc.

```raku local
my $p = run "printf", 'a\nb\nc\n', :out;
say $p.out.^name, " ", $p.out ~~ IO::Handle;
say $p.out.nl-in.raku;
say $p.out.get.raku, " ", $p.out.eof;
say $p.out.lines.raku;
say $p.out.get.raku, " ", $p.out.eof;
say (try $p.out.print("x")) // $!.message;
say $p.out.close === $p, " ", $p.out.opened;
```
```output
IO::Pipe True
"\n"
"a" False
("b", "c").Seq
Nil True
This pipe was opened for reading, not writing
True False
```

## `.exitcode` waits for the program, and so does reading to the end
tags: unasserted

With a pipe, `run` returns before the program has ended. `.exitcode`,
`.signal`, a truth test and a sink wait for it to end, and `.out.slurp` waits
for it to close its output. A program that reads its input to the end, such
as `cat` or `sort`, cannot end while `.in` is open, so the wait lasts until
the parent closes `.in`. Here the wait runs in a `start` block, so that the
parent can go on:

```raku local
my $p = run "cat", :in, :out;
my $status = start { $p.exitcode };
sleep 1;
say $status.status;
$p.in.print("late");
$p.in.close;
say await $status;
say $p.out.slurp(:close);
```
```output
Planned
0
late
```

Without the `start`, the wait has no end. The next program never returns,
because `cat` waits for its input and the parent waits for `cat`:

```raku nocheck
my $p = run "cat", :in;
say $p.exitcode;
```

A program that ends on its own, like `true`, ends whether `.in` is open or
not. While `.exitcode` waits, it collects the program's output, so the
status can be asked for before the output is read, whatever its size, and the
output is still there afterwards:

```raku local
my $p = run "sh", "-c", "yes | head -c 200000; exit 6", :out;
say $p.exitcode;
say $p.out.slurp(:close).chars;
```
```output
6
200000
```

## Reading `.out` first can deadlock when `.err` is captured too
tags: quirk unasserted

A pipe holds a limited amount of data, 64 KiB on common systems. A captured
stream is only collected once the parent starts reading it or closes it;
until then, a program that writes more than a pipe's worth to it stops and
waits. With both `:out` and `:err`, a program that fills its standard error
while the parent reads `.out` to the end waits for the parent, and the parent
waits for the program. This never returns:

```raku nocheck
my $p = run "sh", "-c", "yes | head -c 200000 >&2; echo done", :out, :err;
say $p.out.slurp(:close);
```

Reading `.err` first works when the other stream is small. Closing `.err`
before reading `.out` collects its data and throws it away. Asking for
`.exitcode` first collects both streams while it waits, and `:merge` has only
one stream to read:

```raku local
my $cmd = "yes | head -c 200000 >&2; echo done";
my $p = run "sh", "-c", $cmd, :out, :err;
say $p.err.slurp(:close).chars;
say $p.out.slurp(:close).raku;
my $q = run "sh", "-c", $cmd, :out, :err;
$q.err.close;
say $q.out.slurp(:close).raku;
my $r = run "sh", "-c", $cmd, :out, :err;
say $r.exitcode;
say $r.out.slurp(:close).raku;
say run("sh", "-c", $cmd, :merge).out.slurp(:close).chars;
```
```output
200000
"done\n"
"done\n"
0
"done\n"
200005
```

Reading `.err` first only moves the problem: a program that fills its
standard output deadlocks with it in the same way.

## `:merge` puts both streams in `.out`, but not in the order they were written

`:err` captures standard error in `.err`, a pipe like `.out`. `:merge` sends
both streams into `.out` and leaves `.err` the type object, whatever `:out`
and `:err` say beside it. A stream that is neither captured nor merged is
inherited: the program writes straight to the parent's own stream, which is
where the `err` on standard error below comes from. `:!err`, or
`:err(False)`, discards the stream instead.

```raku local
my $cmd = "echo out; echo err >&2";
my $p = run "sh", "-c", $cmd, :out, :err;
say $p.out.slurp(:close).raku, " ", $p.err.slurp(:close).raku;
my $m = run "sh", "-c", $cmd, :merge, :!out, :err;
say $m.out.slurp(:close).lines.sort;
say $m.err.raku;
my $o = run "sh", "-c", $cmd, :out;
say $o.out.slurp(:close).raku;
my $d = run "sh", "-c", $cmd, :out, :!err;
say $d.out.slurp(:close).raku;
```
```output
"out\n" "err\n"
(err out)
IO::Pipe
"out\n"
"out\n"
```
```stderr
err
```

The example sorts the merged lines because their order varies. The program's
two streams reach the parent through two pipes, and the parent joins them as
the data arrives: a program that writes `out`, then `err`, then `out2`
usually shows up as `out`, `out2`, `err`, and now and then in its own order.

## `:in` gives a write-only pipe; without it, the program reads the parent's input

With `:in`, `.in` is an `IO::Pipe` opened for writing to the program's
standard input. `print`, `say`, `put` and `write` (which takes a Blob) return
`True`, `spurt` with `:close` writes and closes, and `.close` returns the Proc.
The program sees the end of its input only when `.in` is closed.

```raku local
my $p = run "cat", :in, :out;
say $p.in.print("a"), " ", $p.in.say("b"), " ", $p.in.write("c".encode);
say (try $p.in.get) // $!.message;
say $p.in.close.^name;
say $p.out.slurp(:close).raku;
my $q = run "cat", :in, :out;
$q.in.spurt("spurted", :close);
say $q.out.slurp(:close).raku;
```
```output
True True True
This pipe was opened for writing, not reading
Proc
"ab\nc"
"spurted"
```

Without `:in`, the program inherits the parent's standard input and can read
all of it. `:!in` closes the program's input at once, so it reads nothing.
This example is given two lines on its standard input:

```raku local stdin="line one\nline two\n"
say run("cat", :!in, :out).out.slurp(:close).raku;
say run("cat", :out).out.slurp(:close).raku;
say $*IN.get.raku;
```
```output
""
"line one\nline two\n"
Nil
```

The second `cat` read both lines, and nothing was left for the parent.

## An open handle or another program's pipe can stand in for a stream

`:in`, `:out` and `:err` also take an opened handle. `:in` takes another
Proc's `.out` or `.err`, which chains the two programs; the pipe is closed
when the consuming program ends. `:out` and `:err` take a handle opened for
writing, and the same handle can take both. A stream sent to a handle is not
captured, so `.out` is then the type object. A handle that is not open is
refused when the program is started:

```raku local
my $a = run "printf", 'b\na\n', :out;
my $b = run "sort", :in($a.out), :out;
say $b.out.slurp(:close).raku;
say $a.out.opened;
my $log = open "log.txt", :w;
my $c = run "sh", "-c", "echo to-out; echo to-err >&2", :out($log), :err($log);
$log.close;
say $c.out.raku;
say "log.txt".IO.lines.sort;
unlink "log.txt";
say (try run("true", :out(IO::Handle.new))) // $!.message;
```
```output
"a\nb\n"
False
IO::Pipe
(to-err to-out)
File handle not open, so cannot get native descriptor
```

A file handle given as `:in` is left open after the program has read it. With
`:merge`, `:out($handle)` receives both streams.

## A binary pipe refuses text with `X::IO::Closed`
tags: quirk

`:bin` makes every pipe of the Proc binary: `.slurp` gives a `Buf[uint8]`,
`.encoding` is `Nil`, and `.in.write` sends bytes. The text methods, `get`,
`lines` and `.in.print`, throw `X::IO::Closed` and say the handle is closed,
although it is open: a binary pipe has nothing to turn bytes into text, and
`X::IO::BinaryMode` would have been the fitting exception. `:enc` sets the
encoding of every pipe, in both directions, and `.encoding` reports the
canonical name. A text pipe can still give bytes with `.slurp(:bin)`.

```raku local
my $b = run "printf", 'caf\303\251', :out, :bin;
say $b.out.encoding.raku;
say (try $b.out.get) // "{$!.^name}: {$!.message}";
say $b.out.slurp(:close).raku;
say run("printf", 'caf\351', :out, :enc<latin1>).out.slurp(:close);
say run("printf", 'x', :out, :enc<Latin1>).out.encoding;
say run("printf", "ab", :out).out.slurp(:close, :bin).raku;
say (try run("printf", "x", :out, :bin, :enc<utf8>)) // $!.^name;
say (try run("printf", 'caf\377', :out).out.slurp(:close)) // $!.message;
```
```output
Nil
X::IO::Closed: Cannot do 'get' on a closed handle
Buf[uint8].new(99,97,102,195,169)
café
iso-8859-1
Buf[uint8].new(97,98)
X::IO::BinaryAndEncoding
Malformed UTF-8 near bytes 61 66 ff
```

`:bin` together with `:enc` is refused, an unknown encoding name throws
`X::Encoding::Unknown` when the program is started, and bytes that are not
valid UTF-8 make `slurp` and `get` die (see also
[Malformed bytes die](#ch:buffers:malformed-bytes-die-and-replacement-does-not-rescue-utf-8)).

## `read($n)` on a binary pipe returns a whole chunk, whatever `$n` is
tags: bug unasserted

The documentation says that `read($n)` returns at most `$n` bytes. On a pipe
opened with `:bin`, Rakudo 2026.08 ignores the count and returns everything
that has arrived in one piece, which is whatever the program wrote in one go.
The next `read` has nothing left. On a text pipe the count is kept, as it is
by `readchars` and `getc`, and a `read` goes on from where they stopped:

```raku local
my $b = run "printf", "abcdef", :out, :bin;
say $b.out.read(2).raku;
say $b.out.read(2).raku;
say $b.out.eof;
my $t = run "printf", "abcdef", :out;
say $t.out.readchars(2).raku;
say $t.out.getc.raku;
say $t.out.read(2).raku;
say $t.out.slurp(:close).raku;
```
```output
Buf[uint8].new(97,98,99,100,101,102)
Buf[uint8].new()
True
"ab"
"c"
Buf[uint8].new(100,101)
"f"
```

A program that writes `abc`, pauses, and writes `def` gives two `read`s of
three bytes each on a binary pipe, however small the count.

## `:nl` sets the line separator both ways, and `:!chomp` keeps it

`:nl` sets the line separator of the pipes. `.lines` and `.get` split on it,
and on it alone, so `"\n"` stops being a separator; `.in.say` ends each line
with it. `:!chomp` leaves the separator on each line. Neither affects
`.slurp`.

```raku local
say run("printf", 'a!b\nc!', :out, :nl<!>).out.lines.raku;
say run("printf", 'a\nb\n', :out, :!chomp).out.lines.raku;
my $p = run "cat", :in, :out, :nl<!>;
$p.in.say("x");
$p.in.close;
say $p.out.slurp(:close).raku;
```
```output
("a", "b\nc").Seq
("a\n", "b\n").Seq
"x!"
```

## A text pipe turns `\r\n` into `\n` before `:nl` sees it
tags: quirk unasserted

Whatever the separator, a `\r\n` that arrives on a text pipe is turned into
`\n` as it is decoded. That is why `.lines` splits Windows-style lines,
although `nl-in` holds only `"\n"`, and why `:nl("\r\n")` never finds its
separator: by the time lines are split, it is gone. A lone `\r` is kept, and
`:nl("\r")` splits on it. A binary pipe and `.slurp(:bin)` see the bytes as
they came.

```raku local
say run("printf", 'a\r\nb\r\n', :out).out.lines.raku;
say run("printf", 'a\r\nb\r\n', :out, :nl("\r\n")).out.lines.raku;
say run("printf", 'a\rb\rc', :out).out.slurp(:close).ords;
say run("printf", 'a\rb\rc', :out, :nl("\r")).out.lines.raku;
say run("printf", 'a\r\nb', :out).out.slurp(:close, :bin).raku;
```
```output
("a", "b").Seq
("a\nb\n",).Seq
(97 13 98 13 99)
("a", "b", "c").Seq
Buf[uint8].new(97,13,10,98)
```

Under `:nl("\r\n")` the whole output comes back as a single line, with its
`\n`s in it and nothing chomped.

## `:env` replaces the whole environment, but the program is found through the parent's `PATH`
tags: quirk

`:cwd`, a string or an `IO::Path`, is the directory the program starts in;
a relative one is taken from `$*CWD`. `:env` takes a hash that becomes the
program's entire environment: `HOME`, `PATH` and every other variable are
gone unless the hash has them. Without `:env`, the program gets `%*ENV`,
including a change made with `temp`. `shell` takes both options too.

```raku local
mkdir "sub";
print run("sh", "-c", 'basename "$PWD"', :cwd<sub>, :out).out.slurp(:close);
print run("sh", "-c", 'echo "[$GREETING] [$HOME]"', :env{ GREETING => "hi" }, :out).out.slurp(:close);
{
    temp %*ENV<GREETING> = "from temp";
    print run("sh", "-c", 'echo "[$GREETING]"', :out).out.slurp(:close);
}
rmdir "sub";
```
```output
sub
[hi] []
[from temp]
```

The second command ran with no `PATH` in its environment, and `sh` was found
all the same: the program is looked up through the parent's `PATH`, not
through the environment it is given.

## `Proc.new` builds a finished `Proc`, or one that spawns later

`Proc.new` takes the pipe options that `run` takes, and makes a Proc that has
not run anything: its `.pid` is `Nil` and its `.command` empty. `.spawn`
then starts a program from a list of arguments, and `.shell` from a string;
both take `:cwd` and `:env`. They return `True` when the program could be
started, whatever its exit code, and `False` when it could not. With
`:exitcode`, `:signal` and `:command`, `Proc.new` makes a Proc for a program
that has already ended, and such a Proc throws when sunk like any failed one:

```raku local
my $p = Proc.new(:out);
say $p.pid.raku, " ", $p.command.raku;
say $p.spawn("printf", "spawned");
say $p.out.slurp(:close), " ", $p.exitcode, " ", $p.command.raku;
say Proc.new.shell("exit 5");
say Proc.new.spawn("no-such-command-here");
my $done = Proc.new(:exitcode(3), :signal(0), :command<make all>);
say $done.so, " ", $done.command.raku;
sink $done;
```
```output
Nil []
True
spawned 0 ("printf", "spawned")
True
False
False ("make", "all")
```
```stderr
The spawned command 'make' exited unsuccessfully (exit code: 3, signal: 0)
  in block <unit> at example.raku line 9

```

A signal left out of `Proc.new` is `Any`, and a truth test then warns:

```raku local
my $p = Proc.new(:exitcode(0));
say $p.signal.raku;
say $p.so;
```
```output
Any
True
```
```stderr
Use of uninitialized value $!signal of type Any in numeric context
  in block <unit> at example.raku line 3
```

`spawn` and `exitcode` called on the `Proc` type object die with *Did you
forget a '.new'?*

## Asking a new `Proc` for its status fixes the status at 1
tags: bug unasserted

The documentation says that `.exitcode` is -1 for a program that has not
exited yet. On a `Proc.new` that has not spawned anything, Rakudo 2026.08
answers 1, with signal 0, and the answer sticks: a spawn afterwards runs the
program, but the Proc keeps reporting 1. A Proc that spawns a second time
keeps the status of its first program, although `.command` changes:

```raku local
my $p = Proc.new;
say $p.exitcode, " ", $p.signal;
$p.spawn("true");
say $p.exitcode, " ", $p.so;
my $q = Proc.new;
$q.spawn("sh", "-c", "exit 7");
$q.spawn("sh", "-c", "exit 8");
say $q.exitcode, " ", $q.command.raku;
my $r = run "true";
$r.shell("exit 9");
say $r.exitcode, " ", $r.command.raku;
```
```output
1 0
1 False
7 ("sh", "-c", "exit 8")
0 ("exit 9",)
```

The intended behaviour is -1 before any spawn, and each spawn's own status
after it. Use a new Proc for each program.

## `Proc::Async.new` ignores the named arguments it does not know
tags: quirk

`Proc::Async.new` takes the program and its arguments as positionals; a list
among them is flattened, and other values are kept as given in `.command` and
made strings when the program starts. Its options are `:w` (to write to the
program), `:enc` and `:translate-nl`, which the next sections use, and
`:arg0`, the name the program is told it was called by. Any other named
argument is silently ignored, so an `:out` copied from a `run` call does
nothing. The form with `:path` and `:args`, which the documentation lists,
does not exist:

```raku local
my $p = Proc::Async.new(<echo a>, "b", 42, :out);
say $p.command.raku;
say $p.enc, " ", $p.translate-nl, " ", $p.w.raku, " ", $p.started;
say (try Proc::Async.new(:path<echo>, :args<hi>)) // $!.^name;
say (try Proc::Async.new("cat", :enc<nope>)) // $!.^name;
say (try run("true", :bogus)) // $!.^name;
```
```output
("echo", "a", "b", 42)
utf8 True Any False
X::Multi::NoMatch
X::Encoding::Unknown
X::Multi::NoMatch
```

`run` refuses a named argument it does not know, as the last line shows. It
takes `:arg0` too: `run("sh", "-c", 'echo "$0"', :arg0<kitty>)` prints
`kitty`, the name a shell script sees as its own.

`:started` is a public attribute and not an option, and
`Proc::Async.new("cat", :started)` makes an object that reports itself
started and can never start: its `.start` throws
`X::Proc::Async::AlreadyStarted`. `:pty`, which runs the program in a
pseudo-terminal, must say its size, as in `:pty(:cols(80), :rows(24))`;
without one, `.new` throws `X::Proc::Async::MissingColsRows`.

## `.start` returns a promise of a bare `Proc`, and `await` as a statement checks it
tags: trap

`.start` starts the program and returns a Promise; a second `.start` throws
`X::Proc::Async::AlreadyStarted`. When the program ends, the promise is kept
with a Proc that has `.exitcode`, `.signal` and `.command` and nothing else:
no pid and no pipes. That Proc throws when sunk if the program failed, so
`await $promise;` written as a statement throws for a non-zero exit, while
`my $result = await $promise` does not:

```raku local
my $proc = Proc::Async.new("sh", "-c", "exit 6");
my $promise = $proc.start;
say $promise.^name;
say (try $proc.start) // $!.^name;
my $result = await $promise;
say $result.^name, " ", $result.exitcode, " ", $result.so;
say $result.pid.raku, " ", $result.out.raku;
say $proc.pid === $proc.ready;
say (await $proc.ready) > 0;
await $promise;
say "not reached";
```
```output
Promise
X::Proc::Async::AlreadyStarted
Proc 6 False
Nil IO::Pipe
True
True
```
```stderr
The spawned command 'sh' exited unsuccessfully (exit code: 6, signal: 0)
  in block <unit> at example.raku line 10

```

`.ready` and `.pid` return one and the same Promise, kept with the program's
process id once it is running, and kept before the start promise is.

## A program that cannot start breaks the promise with `X::OS`

When the program is missing, or the `:cwd` given to `.start` is unusable, the
start promise is broken with an `X::OS`. Its `.error-code` is the system's
error number, negated. `.ready` is broken with the same exception, and
`.started` is `True` all the same:

```raku local
my $proc = Proc::Async.new("no-such-command-here");
my $promise = $proc.start;
try await $promise;
say $promise.status, " ", $!.^name;
say $promise.cause.^name, " ", $promise.cause.error-code;
say $promise.cause.message;
say $proc.ready.status, " ", $proc.ready.cause === $promise.cause;
say $proc.started;
spurt "a-file", "";
my $f = Proc::Async.new("true").start(:cwd<a-file>);
try await $f;
say $f.cause.error-code, " ", $f.cause.message;
unlink "a-file";
```
```output
Broken X::OS+{X::Await::Died}
X::OS -2
Failed to spawn process no-such-command-here: no such file or directory (error code -2)
Broken True
True
-20 Failed to spawn process true: not a directory (error code -20)
```

`await` rethrows the cause with the role `X::Await::Died` mixed in, which is
why `$!` has a longer name than `.cause`. The supplies and the writing
methods fail too: every output supply quits, and a write gives a broken
promise. `.close-stdin` and `.kill` do nothing harmful:

```raku local
my $proc = Proc::Async.new("no-such-command-here", :w);
my $quit = Promise.new;
$proc.stdout.tap(-> $chunk { }, quit => -> $e { $quit.keep($e) });
my $promise = $proc.start;
my $e = await $quit;
say $e.^name, ": ", $e.message;
my $w = $proc.print("x");
try await $w;
say $w.status, " ", $w.cause.message;
say $proc.close-stdin, " ", $proc.kill;
```
```output
X::AdHoc: Failed to spawn process no-such-command-here: no such file or directory (error code -2)
Broken broken pipe
True 1
```

## `.start` takes `:ENV`, not `:env`, and ignores the wrong one
tags: trap

`.start` takes the program's directory as `:cwd` and its environment as
`:ENV`, in capitals, where `run` takes `:env`. Like `Proc::Async.new`, it
ignores named arguments it does not know, so an `:env` passed to `.start` is
dropped without a word and the program gets the parent's environment:

```raku local
mkdir "sub";
my $proc = Proc::Async.new("sh", "-c", 'echo "$(basename "$PWD") [$GREETING]"');
my $out = "";
$proc.stdout.tap(-> $chunk { $out ~= $chunk });
await $proc.start(:cwd<sub>, :ENV{ GREETING => "hi" });
print $out;
my $wrong = Proc::Async.new("sh", "-c", 'echo "[$GREETING]"');
my $out2 = "";
$wrong.stdout.tap(-> $chunk { $out2 ~= $chunk });
await $wrong.start(:env{ GREETING => "hi" });
print $out2;
rmdir "sub";
```
```output
sub [hi]
[]
```

As with `run`, `:ENV` is the whole environment, it defaults to `%*ENV` with
any `temp` changes, and the program is found through the parent's `PATH`.

## An untapped `.stdout` holds back the start promise
tags: quirk undocumented

Calling `.stdout` or `.stderr` tells the `Proc::Async` to capture that
stream, but the stream is read only once its Supply has a tap. Until then the
start promise is not kept, even after the program has ended, and a program
that writes more than a pipe holds stops and waits. A tap added later, at any
time, releases it, and receives everything the program wrote:

```raku local
my $proc = Proc::Async.new("echo", "hello");
my $stdout = $proc.stdout;
my $promise = $proc.start;
await Promise.anyof($promise, Promise.in(1));
say $promise.status, " ", $proc.ready.status;
my $out = "";
$stdout.tap(-> $chunk { $out ~= $chunk });
await $promise;
say $promise.status, " ", $out.raku;
```
```output
Planned Kept
Kept "hello\n"
```

A Supply made from the stream, such as `.stdout.lines`, is not a tap either.
The next program never ends, because its line Supply is never tapped:

```raku nocheck
my $proc = Proc::Async.new("echo", "hello");
my $lines = $proc.stdout.lines;
await $proc.start;
say "done";
```

Asking the Supply for `.native-descriptor`, a promise of the pipe's file
descriptor, counts as taking the stream over, and the start promise is then
kept without a tap. The merged `.Supply` is read from the start, tapped or
not (see
[The merged Supply](#ch:processes:the-merged-supply-is-read-from-the-start-and-whenever-proc-taps-it)).

## Output nobody captures can overtake the parent's buffered output
tags: trap

A stream of the program for which no Supply was asked and no handle bound is
inherited: the program writes to the parent's own standard output or error.
When the parent's standard output is a file or a pipe, as it is for these
examples, all but the first write of the parent's own output is buffered. The
program's output then overtakes whatever the parent has printed and not yet
flushed. `$*OUT.flush` before starting the program restores the order:

```raku local
say "parent 1";
say "parent 2";
run "echo", "child of run";
$*OUT.flush;
await Proc::Async.new("echo", "child after a flush").start;
say "parent 3";
```
```output
parent 1
child of run
parent 2
child after a flush
parent 3
```

It makes no difference whether `run`, `shell` or `Proc::Async` started the
program. At a terminal the parent's output is not buffered, and the lines come
in the order they were written. A program started without `:w` and with no
handle bound to its standard input reads the parent's input.

## A Supply must be chosen before `.start`, and some choices exclude others

`.stdout`, `.stderr` and the merged `.Supply` must be called before `.start`;
afterwards they throw `X::Proc::Async::TapBeforeSpawn`, even for a stream
that already has a Supply. Each call returns a new `Proc::Async::Pipe`, a
kind of Supply, over the same stream. A stream is read as text or as bytes,
not both, and the merged Supply excludes the separate ones:

```raku local
my $proc = Proc::Async.new("echo", "hi");
my $a = $proc.stdout;
say $a.^name, " ", $a ~~ Supply, " ", $a === $proc.stdout;
say (try $proc.stdout(:bin)) // $!.message;
say (try $proc.Supply) // $!.message;
my $out = "";
$a.tap(-> $chunk { $out ~= $chunk });
my $promise = $proc.start;
say (try $proc.stderr) // $!.message;
await $promise;
print $out;
```
```output
Proc::Async::Pipe True False
Can only tap one of chars or bytes supply for stdout
Using .Supply on a Proc::Async implies merging stdout and stderr; .stdout and .stderr cannot therefore be used in combination with it
To avoid data races, you must tap stderr before running the process
hi
```

The exceptions are `X::Proc::Async::CharsOrBytes`, `SupplyOrStd` and
`TapBeforeSpawn`. They and the other exceptions for misusing a `Proc::Async`
(`AlreadyStarted`, `MustBeStarted`, `OpenForWriting`, `BindOrUse`) all do the
role `X::Proc::Async`, and their `.proc` is the object. `X::Proc::Unsuccessful`
and `X::OS` do not do it:

```raku local
for X::Proc::Async::AlreadyStarted, X::Proc::Async::TapBeforeSpawn, X::Proc::Unsuccessful, X::OS -> $type {
    say $type.^name, " ", $type ~~ X::Proc::Async;
}
```
```output
X::Proc::Async::AlreadyStarted True
X::Proc::Async::TapBeforeSpawn True
X::Proc::Unsuccessful False
X::OS False
```

## A tap added after the output has ended receives nothing, not even `done`
tags: quirk undocumented

The first tap on a stream receives everything from the start, whenever it
comes, as the previous corners showed. Taps added while the program runs
receive what arrives after them. A tap added once the stream has ended
receives nothing at all, not even the `done` that would tell it so:

```raku local
my $proc = Proc::Async.new("echo", "once");
my $stdout = $proc.stdout;
my ($first, $late) = "", "";
my $late-done = False;
$stdout.tap(-> $chunk { $first ~= $chunk });
await $proc.start;
$stdout.tap(-> $chunk { $late ~= $chunk }, done => { $late-done = True });
sleep 0.5;
say $first.raku;
say $late.raku, " ", $late-done;
```
```output
"once\n"
"" False
```

Anything that waits for such a Supply to finish, such as `.list` on it or a
`react` block with a `whenever` on it, waits for ever.

## Every chunk and every `done` come before the start promise is kept
tags: undocumented

For a tapped `.stdout` or `.stderr`, each chunk arrives before that
stream's `done`, and both `done`s arrive before the start promise is kept.
Code that runs when the promise is kept, after an `await` or in a `.then`,
therefore sees all the output already delivered. The two streams keep no
order between them, so the example shows each stream's events apart:

```raku local
my $proc = Proc::Async.new("sh", "-c", "echo out; echo err >&2");
my @events;
my $lock = Lock.new;
sub log($e) { $lock.protect: { @events.push($e) } }
$proc.stdout.tap(-> $chunk { log "stdout chunk" }, done => { log "stdout done" });
$proc.stderr.tap(-> $chunk { log "stderr chunk" }, done => { log "stderr done" });
await $proc.start.then({ log "start kept" });
say @events.tail;
say @events.grep(/stdout/).join(", ");
say @events.grep(/stderr/).join(", ");
```
```output
start kept
stdout chunk, stdout done
stderr chunk, stderr done
```

A program that writes nothing emits no chunk, not even an empty one; its
Supply is simply done.

## A chunk is not a line, and its last character waits for the next

A text Supply emits strings as they arrive, in pieces of any size, never
split into lines; `.lines` on the Supply gives lines. Each piece holds back
its last character until more text or the end arrives, because the next
bytes could be a combining mark that belongs to it (see
[incremental decoders](#ch:buffers:an-encoding-object-makes-encoders-and-incremental-decoders)).
So the chunks differ from the program's writes even when the writes are far
apart in time:

```raku local
my $proc = Proc::Async.new("sh", "-c", 'printf "one\ntw"; sleep 0.5; printf "o\nthree\n"');
my (@chunks, @lines);
$proc.stdout.tap(-> $chunk { @chunks.push($chunk) });
$proc.stdout.lines.tap(-> $line { @lines.push($line) });
await $proc.start;
say @chunks.raku;
say @lines.raku;
```
```output
["one\nt", "wo\nthree\n"]
["one", "two", "three"]
```

The program wrote `one\ntw` and later `o\nthree\n`; the `w` was held back and
arrived with the second write. When the second write starts with a combining
mark, the held character takes it. A binary Supply, `.stdout(:bin)`, emits
the bytes of each write untouched:

```raku local
my $proc = Proc::Async.new("sh", "-c", 'printf "ab"; sleep 0.5; printf "\314\201c"');
my @chunks;
$proc.stdout.tap(-> $chunk { @chunks.push($chunk) });
await $proc.start;
say @chunks.raku;
my $b = Proc::Async.new("sh", "-c", 'printf "ab"; sleep 0.5; printf "cd"');
my @bytes;
$b.stdout(:bin).tap(-> $chunk { @bytes.push($chunk) });
await $b.start;
say @bytes.raku;
```
```output
["a", "b́", "c"]
[Buf[uint8].new(97,98), Buf[uint8].new(99,100)]
```

## `\r\n` becomes `\n`, and `:enc` can be set for each stream

A text Supply turns `\r\n` into `\n` and keeps a lone `\r`, unless
`:translate-nl` is false, either on `Proc::Async.new` or on the call to
`.stdout`, `.stderr` or `.Supply`. It decodes with the `:enc` given to `.new`,
UTF-8 by default, and each of those calls can name its own:

```raku local
sub capture(Proc::Async $proc, *%opts) {
    my $out = "";
    $proc.stdout(|%opts).tap(-> $chunk { $out ~= $chunk });
    await $proc.start;
    $out
}
say capture(Proc::Async.new("printf", 'a\r\nb\rc')).ords;
say capture(Proc::Async.new("printf", 'a\r\nb'), :!translate-nl).ords;
say capture(Proc::Async.new("printf", 'a\r\nb', :!translate-nl)).ords;
say capture(Proc::Async.new("printf", 'caf\351', :enc<latin1>));
say capture(Proc::Async.new("printf", 'caf\351'), :enc<latin1>);
```
```output
(97 10 98 13 99)
(97 13 10 98)
(97 13 10 98)
café
café
```

## Malformed input quits the Supply, and the text before it is lost
tags: undocumented

Bytes that are not valid in the stream's encoding make the text Supply quit
with an `X::AdHoc`. The valid text before them is not emitted. The program
itself is unaffected, and so are the other stream and the start promise. A
binary Supply delivers the same bytes whole:

```raku local
my $proc = Proc::Async.new("printf", 'good \377 bad');
my $out = "";
my $quit = "";
$proc.stdout.tap(-> $chunk { $out ~= $chunk }, quit => -> $e { $quit = "{$e.^name}: {$e.message}" });
my $result = await $proc.start;
say $out.raku;
say $quit;
say $result.exitcode;
my $b = Proc::Async.new("printf", 'good \377 bad');
my $buf = Buf.new;
$b.stdout(:bin).tap(-> $chunk { $buf.append($chunk) });
await $b.start;
say $buf.elems;
```
```output
""
X::AdHoc: Malformed UTF-8 near bytes 64 20 ff
0
10
```

An unknown encoding name given to `.stdout`, `.stderr` or `.Supply` is
accepted, and the Supply quits with `X::Encoding::Unknown` once the program
starts; given to `Proc::Async.new`, it throws at once. A quit that nobody
handles inside a `react` block ends the block, and the program, with the
exception:

```raku local
react {
    my $proc = Proc::Async.new("printf", '\377');
    whenever $proc.stdout { }
    whenever $proc.start { }
}
```
```output
```
```stderr
A react block:
  in block <unit> at example.raku line 1

Died because of the exception:
    Malformed UTF-8

```

## The merged Supply is read from the start, and `whenever $proc` taps it

`.Supply` carries standard output and standard error together, as text or,
with `:bin`, as bytes, in the order the parent receives them. A `whenever`
given the `Proc::Async` object itself taps its merged Supply. Unlike
`.stdout` and `.stderr`, the merged Supply is read from the start, tapped or
not: the start promise is kept without a tap, and a first tap after the end
receives everything at once.

```raku local
my $proc = Proc::Async.new("sh", "-c", "echo out; echo err >&2");
my $all = "";
react {
    whenever $proc { $all ~= $_ }
    whenever $proc.start { say "exit code ", .exitcode }
}
say $all.lines.sort;
my $late = Proc::Async.new("echo", "merged");
my $supply = $late.Supply;
await $late.start;
my $out = "";
$supply.tap(-> $chunk { $out ~= $chunk });
say $out.raku;
```
```output
exit code 0
(err out)
"merged\n"
```

As with `:merge`, the lines of the two streams do not keep the program's
order, so the example sorts them.

## `bind-stdout` and `bind-stderr` send a stream into an open handle

Instead of a Supply, a stream can be bound to an opened `IO::Handle`, and
the program's output goes straight into it. `.bind-stdout` and
`.bind-stderr` return `Nil`, the same handle may take both streams, binding
again replaces the handle, and the handle is left open when the program ends.
A bound stream has no Supply, and the merged `.Supply` cannot be used while
either stream is bound; both mistakes throw `X::Proc::Async::BindOrUse`.

```raku local
my $log = open "log.txt", :w;
my $proc = Proc::Async.new("sh", "-c", "echo out; echo err >&2");
say $proc.bind-stdout($log).raku;
$proc.bind-stderr($log);
say (try $proc.stdout) // $!.message;
await $proc.start;
say $log.opened;
$log.close;
say "log.txt".IO.lines.sort;
unlink "log.txt";
say (try Proc::Async.new("true").bind-stdout("log.txt")) // $!.^name;
```
```output
Nil
Cannot both bind stdout to a handle and also get the stdout Supply
True
(err out)
X::TypeCheck::Binding::Parameter
```

## `bind-stdin` feeds a program from a file or another program

`.bind-stdin` takes an opened handle to read from, the `.stdout` or `.stderr`
Supply of another `Proc::Async`, which chains the two programs, or the `.out`
pipe of a `run`. Both programs of a chain must be started, in either order.
A pipe from `run` is closed when the program has read it; a file handle is
left open. A `:w` object writes its own input and refuses the binding:

```raku local
my $producer = Proc::Async.new("printf", 'b\na\nc\n');
my $consumer = Proc::Async.new("sort");
$consumer.bind-stdin($producer.stdout);
my $sorted = "";
$consumer.stdout.tap(-> $chunk { $sorted ~= $chunk });
await $producer.start, $consumer.start;
say $sorted.lines;
my $pipe = run "printf", "via run", :out;
my $cat = Proc::Async.new("cat");
$cat.bind-stdin($pipe.out);
my $got = "";
$cat.stdout.tap(-> $chunk { $got ~= $chunk });
await $cat.start;
say $got, " ", $pipe.out.opened;
say (try Proc::Async.new("cat", :w).bind-stdin($*IN)) // $!.^name;
```
```output
(a b c)
via run False
X::Proc::Async::BindOrUse
```

## Writing needs `:w`, and the program sees the end only after `close-stdin`
tags: quirk

A `Proc::Async` made with `:w` can write to the program once it is started.
`.write` sends a Blob, `.print` a string in the object's encoding, `.say` the
`.gist` of its argument and a newline, and `.put` the argument joined without
separators and a newline. Each returns a Promise kept with the number of
bytes sent. The program sees the end of its input only after `.close-stdin`,
and a program that reads to the end, like `cat`, cannot end before it:

```raku local
my $proc = Proc::Async.new("cat", :w);
my $out = "";
$proc.stdout.tap(-> $chunk { $out ~= $chunk });
my $done = $proc.start;
say await $proc.write("ab".encode);
say await $proc.print("cd");
say await $proc.say(<e f>);
say await $proc.put(<g h>);
await Promise.anyof($done, Promise.in(1));
say $done.status;
say $proc.close-stdin;
await $done;
say $out.raku;
```
```output
2
2
6
3
Planned
True
"abcd(e f)\ngh\n"
```

Before `.start`, these four methods and `.close-stdin` throw
`X::Proc::Async::MustBeStarted`, and without `:w`,
`X::Proc::Async::OpenForWriting`. Each exception names the
method in `.method`, except that `put` reports itself as `say`:

```raku local
my $unstarted = Proc::Async.new("cat", :w);
say (try $unstarted.print("x")) // "{$!.^name} {$!.method}";
say (try $unstarted.put("x")) // $!.message;
my $readonly = Proc::Async.new("true");
my $r = $readonly.start;
say (try $readonly.put("x")) // $!.message;
await $r;
my $w = Proc::Async.new("cat", :w);
my $wp = $w.start;
say (try $w.write("text")) // $!.^name;
$w.close-stdin;
await $wp;
my $late = $w.write("z".encode);
try await $late;
say $late.status, " ", $late.cause.message;
say $w.close-stdin;
```
```output
X::Proc::Async::MustBeStarted print
Process must be started first before calling 'say'
Process must be opened for writing with :w to call 'say'
X::TypeCheck::Binding::Parameter
Broken Cannot write to process that has already terminated
True
```

`.write` takes only a Blob. A write after the program has ended gives a
broken promise, while `.close-stdin` can be called again at any time.

## `.kill` sends SIGHUP unless told otherwise, and returns the number it sent
tags: quirk

`.kill` sends a signal to a started program: SIGHUP by default, or the one
given as a `Signal` value, a number, or a name with or without its `SIG`
prefix. It returns the number it sent. The program ends with exit code 0 and
the signal in `.signal`, and the Proc it delivers is false:

```raku local
sub killed-by($signal?) {
    my $proc = Proc::Async.new("sleep", "5");
    my $promise = $proc.start;
    await $proc.ready;
    my $sent = $signal.defined ?? $proc.kill($signal) !! $proc.kill;
    my $result = await $promise;
    "sent $sent, exit code {$result.exitcode}, signal {$result.signal}, {$result.so}"
}
say killed-by();
say killed-by(SIGTERM);
say killed-by("INT");
say killed-by("SIGKILL");
say killed-by(9);
```
```output
sent 1, exit code 0, signal 1, False
sent 15, exit code 0, signal 15, False
sent 2, exit code 0, signal 2, False
sent 9, exit code 0, signal 9, False
sent 9, exit code 0, signal 9, False
```

`.kill` before `.start` throws `X::Proc::Async::MustBeStarted`; after the
program has ended it does nothing. A name that is not a signal's throws
`X::TypeCheck::Return`, a complaint about a return value, because the
lookup through `$*KERNEL.signal` finds no number for it:

```raku local
my $proc = Proc::Async.new("sleep", "5");
say (try $proc.kill) // $!.^name;
my $promise = $proc.start;
await $proc.ready;
say (try $proc.kill("NOPE")) // $!.message;
say $proc.kill("TERM");
my $result = await $promise;
say $proc.kill;
say $*KERNEL.signal("TERM"), " ", $*KERNEL.signal(SIGINT);
```
```output
X::Proc::Async::MustBeStarted
Type check failed for return value; expected Int:D but got Int (Int)
15
1
15 2
```
