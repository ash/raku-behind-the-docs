# Raku Behind the Docs

An interactive book about what Raku actually does. Every behaviour is a
*corner*: a claim, a short explanation, and the smallest program that shows
it, with the output Rakudo prints. The site is static; each example gets a
▶ Run button that turns it into a live editor (Raku++ compiled to
WebAssembly, loaded from raku.online).

## Build

```bash
rakupp build.raku --verify      # run new or changed examples on both engines, then build out/
rakupp build.raku               # rebuild out/ from the cached results only
rakupp build.raku --verify --only=precedence   # verify one chapter's examples
```

`--verify` runs every example whose result is not cached through Rakudo (the
oracle, `/opt/homebrew/bin/rakudo` by default) and through Raku++ (`rakupp`).
The build fails if Rakudo prints anything other than what the page declares.
Where Raku++ prints something else, the page says so under the example.

Results are cached in `cache/rakudo.tsv` and `cache/rakupp.tsv`, keyed by the
engine's version line, the code and its standard input. A new Rakudo or a
rebuilt rakupp re-runs everything once.

## Publishing

The book is a section of raku.online, at `raku.online/deep/`. Its pages are
built for that mount (`mount` in `src/book.raku`) and load the site's shared
bar (`/theme/shell.js`, `/theme/shell.css`) and the in-page engine
(`/raku.js`) from the raku.online origin. To publish, build and verify here,
then in a raku.online checkout run `./build.sh deep`, which copies `out/`
into `www/deep/`; raku.online is served from its committed `www/`.

To preview, build here, run `./build.sh deep` in raku.online, and serve its
`www/` with any static server.

## Layout

| path | what |
|---|---|
| `src/book.raku` | title, subtitle, byline, oracle name, part introductions |
| `src/chapters/NN-slug.md` | one chapter each, ordered by file name |
| `src/assets/` | `book.css`, `book.js`, copied to `out/assets/` |
| `cache/` | verified engine results |
| `out/` | the built site (not committed; published through raku.online) |
| `PLAN.md` | the table of contents still to write, with sources |

## Chapter format

```
---
title: Who Takes the Operand
part: Reading the code
summary: One sentence for the contents page.
kind: appendix          (optional; appendices are lettered)
---

Intro prose.

## A corner's heading states the behaviour as a claim
tags: trap quirk bug undocumented unasserted 6e     (optional)

Prose. `code`, **bold**, *italic*, [links](url), [chapter links](#ch:slug)
or (#ch:slug:corner-id), and [the index](#index).
```

Fences after prose:

- ` ```raku ` — an example, runnable in the page; ` ```raku local ` needs
  threads, files or processes and is shown static; ` ```raku nocheck ` is
  never run; ` stdin="a\nb" ` gives standard input.
- ` ```output ` — required after a checked example: Rakudo's exact stdout
  (may be empty).
- ` ```stderr ` — optional: Rakudo's exact stderr. Programs run as
  `example.raku`, so messages name that file.
- any other fence is a plain preformatted block.

Tables, bullet and numbered lists, `> ` asides and `### ` sub-headings work
as in Markdown.

Tag meanings: **trap** by design but regularly surprising; **quirk** a
harmless Rakudo oddity; **bug** Rakudo contradicts its own intent;
**undocumented** not on docs.raku.org; **unasserted** not asserted by Roast.
