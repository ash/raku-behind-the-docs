---
title: Colophon
part: Back matter
kind: colophon
summary: Who wrote this book, from what, and how every output in it is checked.
---

### Who wrote it

The text was written by Claude, Anthropic's model, from the Raku++ project's
findings. Raku++ is a second implementation of Raku, written from scratch, and
building it meant asking, for every construct, what exactly Rakudo does. The
answers were kept as semantics sheets, one per area of the language: each
behaviour stated in plain words, with a probe program and the output the
reference compiler printed for it, and marked with whether the official documentation describes
it and whether Roast, the language's test suite, asserts it. The project also
kept an operator-by-operator behaviour matrix, a run of every example in the
official documentation on both engines, and notes on the traps met while
running real programs. This book rewrites that material to be read.

Andrew Shitov initiated the book, coordinated the work and edited it.

### How it is checked

No output in the book was typed by hand. The book is built by a generator
written in Raku and run by Raku++. Every example is checked against the
reference compiler of Raku, Rakudo, and the build refuses to produce the site
if any output on any page differs from the reference output. The same
examples are run through Raku++, and where it prints something else the page
says so beside the example, because the Run buttons use Raku++ compiled to
WebAssembly.

This edition was checked against the reference compiler, Rakudo v2026.08.

### Where it lives

The book is published at `raku.online/deep`, a section of the raku.online site. Its source, the chapters as
Markdown and the generator, is at `github.com/ash/raku-behind-the-docs`.
Corrections are welcome as issues or pull requests there; a correction that
comes with a program and Rakudo's output for it is the easiest to act on.

### Licence

Copyright © 2026 Andrew Shitov and the Raku++ project. The book is released
under the Artistic License 2.0, the licence that covers Raku++ itself. You may
copy, distribute and adapt it under those terms.

The information in this book is provided as it stands, without warranty. It
describes what one version of Rakudo does; another version may behave
differently, and the corners tagged as bugs or quirks are the likeliest to
change.
