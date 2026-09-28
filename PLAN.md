# Plan

The sources are the Raku++ project's findings, in the raku++ repository
(github.com/ash/rakupp). Sheet paths are relative to its
`docs/dev/findings/semantics/`; item counts are the sheet's. Every behaviour
in them was probed on Rakudo; the book rewrites them for reading and
re-verifies every example at build time. STYLE.md has the method.

| # | file | slug | chapter | part | sources |
|---|---|---|---|---|---|
| 0 | 00-how-to-read.md | how-to-read | How to Read This Book | Before you start | — |
| 1 | 01-precedence.md | precedence | Who Takes the Operand | Reading the code | Compiler-Side CP-01..13, CP-16 |
| 2 | 02-quotes.md | quotes | Quotes and Interpolation | Reading the code | Compiler-Side CP-19..26, plus quoting traps |
| 3 | 03-whitespace.md | whitespace | Whitespace, Terms and Blocks | Reading the code | CP-14, plus parsing traps |
| 4 | 04-sink.md | sink | Values Nobody Uses | Reading the code | Compiler-Side CP-27..34 |
| 5 | 05-containers.md | containers | Containers and Binding | Reading the code | CP-10, CP-15, itemization; List-Array container items |
| 6 | 06-nil-any.md | nil-any | Nil, Any and the Undefined | Nothing and numbers | Nil-Any.md (50) |
| 7 | 07-numbers.md | numbers | Numbers | Nothing and numbers | Int-Num-Rat.md (28), CP-17, CP-18 |
| 8 | 08-strings.md | strings | Strings | Nothing and numbers | Str.md (66) |
| 9 | 09-lists.md | lists | Lists, Arrays, Seqs and Slips | Collections | List-Array.md (36) |
| 10 | 10-hashes.md | hashes | Hashes, Maps and Pairs | Collections | Hash-Map-Pair.md (20) |
| 11 | 11-ranges.md | ranges | Ranges | Collections | Range.md (33) |
| 12 | 12-sequences.md | sequences | The Sequence Operator | Collections | Sequence.md (29) |
| 13 | 13-sets.md | sets | Sets, Bags and Mixes | Collections | Set-Bag-Mix.md (44) |
| 14 | 14-buffers.md | buffers | Blobs and Bufs | Collections | Blob-Buf.md (37) |
| 15 | 15-signatures.md | signatures | Signatures and Introspection | Code | Code-Introspection.md (37) |
| 16 | 16-exceptions.md | exceptions | Exceptions and Failures | Code | Exception-Backtrace.md (36) |
| 17 | 17-regexes.md | regexes | Regexes and Grammars | Code | Grammar-Match.md (41) |
| 18 | 18-dates.md | dates | Dates and Times | Time and the outside world | Date-Time.md (33) |
| 19 | 19-files.md | files | Files and Paths | Time and the outside world | IO.md (26) |
| 20 | 20-processes.md | processes | Processes | Time and the outside world | Proc-Async.md (37) |
| 21 | 21-promises.md | promises | Promises, Locks and Awaiting | Concurrency | Promise.md (36) |
| 22 | 22-supplies.md | supplies | Supplies | Concurrency | Supply.md (69) |
| A | 90-rakudo-bugs.md | rakudo-bugs | Rakudo's Own Bugs | Appendices | every V:bug item across the sheets |
| B | 91-probes.md | probes | Writing a Probe | Appendices | the probe traps recorded with the sheets |
| — | 99-colophon.md | colophon | Colophon | Back matter | — |

Roughly 700 corners when complete.
