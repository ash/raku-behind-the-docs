# Writing a chapter

This is the house style for *Raku Behind the Docs*. Chapter 1
(`src/chapters/01-precedence.md`) is the model: read it before writing.

## Method

1. Read the source material for the chapter (see PLAN.md) in full.
2. Choose the corners. A corner is one behaviour a reader could get wrong or
   could not find in the documentation. Group related behaviours into one
   corner rather than writing thirty one-line corners; split a sheet item
   that holds several unrelated rules.
3. For each corner, write the example program first and run it through
   Rakudo (`rakudo file.raku`, the binary at `/opt/homebrew/bin/rakudo`;
   `raku` on this machine is a different engine). Write the prose around the
   output Rakudo actually printed. Never write an expected output from memory
   or from a sheet: rerun it.
4. Build with `rakupp build.raku --verify --only=<slug>` until it passes. The
   build runs every example on Rakudo and fails on any difference.

## Voice

- Declarative, present tense: say what the language does. No "we", no "I",
  no "you might think", no jokes at the reader's expense.
- British spelling: behaviour, recognise, parenthesise, colour.
- Plain words. A reader who knows basic Raku must follow every paragraph.
  Name a concept before using it; link to the chapter that explains it.
- No boasting and no editorialising about implementations. Rakudo is the
  subject; the book never mentions Raku++ in its prose (the build adds a
  note under any example where Raku++ differs).
- Do not copy the sheets' wording. They are compressed notes for
  implementers; the book explains.

## A corner

```
## The heading states the behaviour as a claim
tags: trap

One to three short paragraphs: what happens, and why it happens.

```raku
say 1 ~ 2 * 3;
```
```output
16
```

A sentence or two after the example when the output needs reading.
```

- The heading is a claim, in sentence case, about ten words at most. It may
  start with code: ``## `-2**2` is negative``.
- One idea per example. Three to eight lines is typical; one `say` per line
  of output, so each output line maps to a line of code.
- Use `.raku` when the type or container matters (`(1, 2).Seq`,
  `$(1, 2)`), `.^name` for a type, plain `say` otherwise.
- Output must be deterministic: sort hash keys and set elements before
  printing, never print timings, thread ids, random values, addresses or
  `.WHICH`; avoid the current date.
- Show a compile-time error by writing the offending code and an empty
  ` ```output ` fence followed by a ` ```stderr ` fence with Rakudo's message.
  Do this only when the message teaches something; otherwise print the
  exception type with `try` and `$!.^name`.
- Rakudo prints several "Useless use" warnings of one program in a random
  order, so an example must provoke at most one of them.
- Show a warning with a ` ```stderr ` fence. The build warns about stderr
  that is not declared; declare it or remove its cause.
- ` ```raku local ` for anything that needs threads, `sleep`, files,
  processes, the network or the environment. Such examples still run at
  build time, in a scratch directory: an example that creates a file must
  delete it before it ends.

## Tags

At most two per corner, and only when they tell the reader something.

| tag | when |
|---|---|
| `trap` | by design, but regularly surprises people who write Raku |
| `quirk` | Rakudo behaviour that is surprising and probably unintended, but harmless |
| `bug` | shown as "Bug?": behaviour that looks unintended. Keep it only with evidence you can point to — the documentation's own words (check them in the doc checkout), a hang or infinite recursion, an internal object or message leaking out (NQPMu, VMNull, "cannot unbox", a raw VM error), a crash on valid input, or disagreement with a closely related form in Rakudo itself. Name the evidence in the prose and the version, "Rakudo 2026.08". Describe what happens and why it looks wrong; never assert that it is a bug, and never tag documented behaviour. Behaviour that is only surprising is a `quirk`. |
| `undocumented` | docs.raku.org does not describe it (the sheets' `D:no`) |
| `unasserted` | Roast does not assert it (the sheets' `R:no`) |

## Links

- Another chapter: `[text](#ch:slug)`; a corner in it:
  `[text](#ch:slug:corner-id)`, where the id is the heading lowercased with
  punctuation removed and spaces as hyphens. The slugs are listed in PLAN.md.
- The corners index: `[text](#index)`.

## When several chapters are written at once

Do not

- touch another chapter, `build.raku`, `src/assets/` or `src/book.raku`;
- run `git`;
- run more than one Rakudo process at a time;
- build with `--clean` or `--prune` (other chapters are being written at the
  same time).
