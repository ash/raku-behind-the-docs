---
title: How to Read This Book
part: Before you start
summary: A corner is one behaviour, stated as a claim and shown by the smallest program that proves it.
---

Raku is a large language, and most of it behaves the way its documentation
says. This book is about what lies behind the docs: the places where two rules
meet, where an empty list or an undefined value arrives, where the parser reads
a line differently from the person who wrote it, and the behaviours nobody
wrote down at all. Those places are the corners.

Every corner has the same shape. The heading states the behaviour as a claim.
A paragraph or two says what happens and why. Then comes a program, usually a
few lines long, and exactly what it prints.

## Every output is checked against the reference compiler

The outputs are not typed by hand. Each one is the reference output: what the
reference compiler of Raku, Rakudo, prints for the example. When the book is
built, every example is run again and compared, and the build stops if a
single character differs from what the page says. This edition was checked
against Rakudo v2026.08.

```raku
say 0.1 + 0.2 == 0.3;
say 0.1e0 + 0.2e0 == 0.3e0;
```
```output
True
False
```

A decimal literal is an exact rational number, so the first comparison holds.
A literal with an exponent is a floating-point `Num`, and the second one fails
for the same reason it fails in most languages.

The behaviours themselves were collected by the Raku++ project while it built
a second implementation of Raku from scratch. Building a second engine means
asking, for every construct, what exactly the first one does, including the
cases nobody wrote down. Those answers were recorded with a probe program for
each, checked against the reference compiler, and then compared with the official
documentation and with Roast, the language's test suite. This book is those
findings, rewritten to be read.

## Some output goes to standard error

Warnings and error messages are printed to standard error, and the book shows
them separately, in red, under the regular output. The program is always run
as a file called `example.raku`, which is why that name appears in messages.

```raku
my $name;
say "Hello, " ~ $name ~ "!";
```
```output
Hello, !
```
```stderr
Use of uninitialized value element of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 2
```

The program still runs to the end: the undefined `$name` becomes an empty
string, and Rakudo says so.

## The tags on a corner

Some corners carry a tag beside their heading:

- **Trap** marks a behaviour that is by design but regularly surprises people who write Raku.
- **Quirk** marks a Rakudo behaviour that is surprising and probably not intended, but harmless.
- **Bug?** marks a behaviour that looks unintended: it contradicts Rakudo's own documentation, hangs, leaks an internal error, or disagrees with a closely related form. The corner says which. Whether it is a bug is for Rakudo's developers to decide; it is described so that you recognise it, not so that you rely on it.
- **Not in the docs** marks a behaviour the official documentation does not describe.
- **Not in Roast** marks a behaviour the language's test suite does not assert, so another implementation, or a later Rakudo, may do something else.

The [index of all corners](#index) lists every corner by chapter and
filters them by tag.

## Predict before you look

Switch on **Predict mode** in the top bar and every output is hidden until
you click it. Reading a corner is more useful when you commit to an answer
first. Try it on this one:

```raku
say 7 div 2, " ", -7 div 2, " ", -7 % 2;
```
```output
3 -4 1
```

`div` rounds toward negative infinity, not toward zero, and `%` takes the
sign of the divisor, so the two always agree: `-7 == 2 * (-7 div 2) + -7 % 2`.

## The Run button

Each runnable example has a **▶ Run** button. It turns the example into an
editor where you can change the code and run it again, as many times as you
like, without leaving the page. The program runs in your browser; nothing is
sent anywhere.

The editor runs Raku++, compiled to WebAssembly. On most examples it prints
exactly the reference output. Where it does not, the page says so under the
example and shows what the editor will print, so the Run button never
contradicts the book without warning. The outputs in the book are always the
reference compiler's.

Examples that need threads, files or other processes cannot run in a browser
tab. They are marked **run it locally**: save the code as a file and run it
with the reference compiler, `rakudo`.
