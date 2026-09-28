---
title: Quotes and Interpolation
part: Reading the code
summary: Which backslashes, variables, brackets and braces mean something inside each of Raku's quoting forms, and what word lists, heredocs and shell quotes hand back.
---

A string literal in Raku is not one construct but a family. At the bottom is
`Q`, which takes its text exactly as written. `q`, spelled `'…'`, adds two
escapes. `qq`, spelled `"…"`, adds the rest: backslash escapes, variables,
method calls and blocks of code. Adverbs switch single features on and off,
split the result into words, run it through the shell, or take the text from
the lines that follow.

Most of the time `'…'` and `"…"` do what they look like. This chapter is about
the places where they do not: a character after a variable that changes what
the variable means, a backslash that is or is not an escape, a word list that
is not a list, and a heredoc whose indentation is counted in columns.

## `Q`, `q` and `qq` differ only in which features are on

Every quoting form is `Q` with some features switched on. `q` adds the escapes
it needs for itself, `\\` and a backslash before the delimiter; `qq` adds every
escape and every kind of interpolation. `'…'` is `q` with apostrophes as
delimiters, `"…"` is `qq` with double quotes, and `｢…｣` is `Q`.

```raku
my $x = 42;
say Q[$x a\\b {1 + 1}];
say q[$x a\\b {1 + 1}];
say qq[$x a\\b {1 + 1}];
say ｢$x a\\b {1 + 1}｣;
```
```output
$x a\\b {1 + 1}
$x a\b {1 + 1}
42 a\b 2
$x a\\b {1 + 1}
```

Each feature is an adverb, written after a colon, and each has a long name as
well as a short one:

| adverb | long name | what it does |
|---|---|---|
| `:s` | `:scalar` | interpolates `$` variables |
| `:a` | `:array` | interpolates `@` variables followed by a subscript |
| `:h` | `:hash` | interpolates `%` variables followed by a subscript |
| `:f` | `:function` | interpolates `&` calls |
| `:c` | `:closure` | interpolates `{…}` blocks |
| `:b` | `:backslash` | enables every backslash escape |
| `:q` | `:single` | the escapes of `q` |
| `:qq` | `:double` | everything `qq` has |
| `:w` | `:words` | splits the result on whitespace |
| `:ww` | `:quotewords` | splits, keeping quoted words together |
| `:v` | `:val` | turns numeric-looking results into allomorphs |
| `:x` | `:exec` | runs the result as a shell command |
| `:to` | `:heredoc` | takes the text from the following lines |

`qq` is exactly `Q:s:a:h:f:c:b`. The word forms have names of their own:
`qw` is `q:w`, `qqww` is `qq:ww`, `qx` is `q:x`, and so on.

## `Q` has no escapes at all

In `Q`, a backslash is an ordinary character. `Q[\n]` is two characters, and a
backslash cannot even protect the closing delimiter: the first `]` ends the
string.

```raku
say Q[\n].chars;
say Q[a\tb];
say Q[\];
say Q:b[a\tb].raku;
```
```output
2
a\tb
\
"a\tb"
```

`Q[\]` is a one-character string holding a backslash. `Q:b` switches on the
backslash escapes and nothing else, which gives `\t` and `\n` without any
interpolation.

## Single quotes know two escapes: the backslash and the delimiter
tags: trap

`q` and `'…'` turn `\\` into one backslash, and a backslash before the
delimiter into the delimiter. Every other backslash stays in the string,
together with the character after it. With bracket delimiters, both the
opening and the closing bracket can be escaped.

```raku
say 'it\'s';
say 'a\\b';
say 'a\nb'.chars;
say q{a\}b};
say q<a\<b\>c>;
say 'C:\temp\\';
```
```output
it's
a\b
4
a}b
a<b>c
C:\temp\
```

The last line shows the way around a trap. A single-quoted string cannot end
in one backslash, because `\'` is an escaped apostrophe: the string runs on to
the next apostrophe, here to the end of the file.

```raku
say 'C:\temp\';
say "done";
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Unable to parse expression in single quotes; couldn't find final "'" (corresponding starter was at line 1)
at example.raku:3
------> <BOL><HERE><EOL>
    expecting any of:
        argument list
        single quotes
        term
```

## `\qq[…]` interpolates inside single quotes

A single-quoted string can switch to double-quote rules for a stretch:
`\qq[…]` interpolates what is inside it, with any bracket pair as delimiters,
and the rest of the string stays single-quoted. `\q[…]` does the reverse inside
double quotes.

```raku
my $n = 3;
say 'Total: \qq[$n] items at $n each';
say 'Sum: \qq[{1 + 2}]';
say 'Sum: \qq{{1 + 2}}';
say "a \q[$n] b";
say Q[\qq[$n]];
```
```output
Total: 3 items at $n each
Sum: 3
Sum: 1 + 2
a $n b
\qq[$n]
```

With braces as the delimiters of `\qq`, the inner braces are text rather than
a block, as they are in [any brace-delimited
quote](#ch:quotes:inside-brace-delimiters-a-is-not-a-block). `Q` knows no
escapes, so `\qq` means nothing there. The same `\qq[…]` works in the body of a
`q:to` heredoc.

## Double quotes know the C escapes, and three ways to write a code point

Inside `"…"` and `qq`, these backslash sequences are recognised:

| escape | gives |
|---|---|
| `\n` `\t` `\r` `\f` `\b` `\a` `\e` `\0` | newline, tab, carriage return, form feed, backspace, bell, escape, NUL |
| `\x41` `\x[41]` `\x[41,42]` | characters by hexadecimal code point |
| `\o101` `\o[101]` | by octal code point |
| `\c65` `\c[65, 66]` | by decimal code point |
| `\c[LATIN CAPITAL LETTER A]` | by Unicode name |
| `\c@` `\cI` `\c?` | NUL, tab and DEL, in the old control-key notation |

```raku
say "\n\t\e\0\a\b\f\r".ords;
say "\x41\x[42]\x[43,44]";
say "\o105\o[106]";
say "\c71\c[72, 73]";
say "\c[LATIN CAPITAL LETTER J]";
say "\c@\cI\c?".ords;
```
```output
(10 9 27 0 7 8 12 13)
ABCD
EF
GHI
J
(0 9 127)
```

`\c` followed by digits is a *decimal* code point; followed by `@`, a letter
or `?`, it is a control character.

## `\x`, `\o` and `\c` take every digit that follows
tags: trap

A code point escape without brackets does not stop after two digits. It takes
every digit of its base that follows, so a letter from `a` to `f` right after a
hexadecimal escape becomes part of the number:

```raku
say "\x22d";
say "\x[22]d";
say "\x41BC";
say "\x[41]BC";
say "\c651";
say "\c[65]1";
```
```output
ȭ
"d
䆼
ABC
ʋ
A1
```

`"\x22d"` is U+022D, not a double quote followed by `d`. Brackets end the
number; they are the safe spelling whenever a letter or a digit follows.

## `\c[…]` takes names, aliases and sequences

Names are matched without regard to case, and the Unicode aliases work as
well (`LF`, `NBSP`, `ESC`). Several names separated by commas give several
code points; a letter followed by a combining mark becomes one character, as it
does everywhere in a Raku string.

```raku
say "\c[latin small letter a]";
say "\c[LF]".ord;
say "\c[NBSP]".ord;
say "\c[LATIN SMALL LETTER E, COMBINING ACUTE ACCENT]".chars;
say "\c[BEL]".ord;
say "\c[BELL]".ord;
```
```output
a
10
160
1
7
128276
```

The last two lines follow Unicode: control character 7 is named `ALERT` or
`BEL`, while the name `BELL` belongs to U+1F514, the bell emoji. An unknown name
is a compile-time error, *Unrecognized character name*, and so is a code point
beyond U+10FFFF such as `\x[110000]`.

## A backslash before a letter is an error; before anything else it is that character

In double quotes, a backslash before a character that is not a letter, a digit
or an underscore gives that character, whether or not it would have meant
anything: `\"`, `\$`, `\@`, `\{`, `\%`, even `\ ` for a space.

```raku
say "\"\$x\" \@a \{1\} 100\%";
```
```output
"$x" @a {1} 100%
```

Before a letter, a digit or an underscore that does not start a known escape,
the backslash is a compile-time error rather than a silent literal. Regex
habits such as `"\d+"` fail this way, and a Perl back-reference gets a hint:

```raku
say "a\1b";
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Unrecognized backslash sequence: '\1'. Did you mean $0?
at example.raku:1
------> say "a\<HERE>1b";
    expecting any of:
        argument list
        double quotes
        term
```

## Perl's spellings are refused, with the Raku one in the message

Several Perl forms are compile-time errors whose message names the Raku
replacement. `"${x}"` becomes a block:

```raku
my $x = 42;
say "${x}";
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Unsupported use of ${x}. In Raku please use: {$x}.
at example.raku:2
------> say "${x}<HERE>";
```

The same happens to `"\x{41}"` and `"\o{101}"`, which want square brackets
instead of braces, and to `"\N{LATIN SMALL LETTER A}"`, which becomes
`"\c[LATIN SMALL LETTER A]"`. `"@{[ … ]}"` is refused as well, and so is the
empty `<>`, Perl's input operator, for which the message suggests `lines()`.

## A variable interpolates; a method call on it needs parentheses
tags: trap

`$x` alone always interpolates. A method call after it interpolates only when
it ends in parentheses; without them the dot and the name are plain text. In a
chain, everything up to the last parenthesised call interpolates, and what
follows it is text.

```raku
my $s = "ab";
say "$s.uc";
say "$s.uc()";
say "$s.uc.lc()";
say "$s.uc().lc";
say "$s.^name";
say "$s.^name()";
say "$s.substr: 1";
```
```output
ab.uc
AB
ab
AB.lc
ab.^name
Str
ab.substr: 1
```

The rule is what keeps ordinary prose safe: a full stop at the end of a
sentence and a file extension after a name stay text.

```raku
my $name = "report";
say "Saved $name.txt as $name.";
```
```output
Saved report.txt as report.
```

## Arrays, hashes and subs interpolate only with a subscript or a call
tags: trap

`@a`, `%h` and `&f` stay literal on their own. They interpolate when followed
by a subscript, or by parentheses for a sub. An empty subscript takes the
whole variable: `"@a[]"` joins the elements with spaces, and `"%h{}"` gives
each pair as a key, a tab and a value.

```raku
my @a = 1, 2, 3;
my %h = a => 9;
sub f { "F" }
say "@a | @a[] | @a[0] | @a[1..2] | @a[*-1]";
say "@a.elems | @a.elems() | @a.join(',')";
say "%h | %h<a> | %h{'a'} | %h{}";
say "&f | &f() | &f.name()";
```
```output
@a | 1 2 3 | 1 | 2 3 | 3
@a.elems | 3 | 1,2,3
%h | 9 | 9 | a	9
&f | F | f
```

This is why an e-mail address is safe in double quotes: `@example` in
`"me@example.com"` has no subscript, so it is text, whether or not an array of
that name exists. A bracket after it changes that, and an undeclared variable
in a string is a compile-time error like any other:

```raku
say "me@example.com";
say "user@example[1].com";
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Variable '@example' is not declared. Perhaps you forgot a 'sub' if this
was intended to be part of a signature?
at example.raku:2
------> say "user<HERE>@example[1].com";
```

## A bracket right after a variable belongs to the variable
tags: trap

Inside double quotes, a `[`, `{`, `<` or `(` directly after a variable, or
after a method call's parentheses, is a subscript or a call, as it would be in
code. Markup runs into this: in `"$label</a>"`, the `</a>` is read as a hash
subscript with the key `/a`.

```raku
my $label = "Home";
say "<a>$label</a>";
```
```output
```
```stderr
Type Str does not support associative indexing.
  in block <unit> at example.raku line 2

```

A backslash before the bracket, or braces around the variable, end the
variable before the bracket:

```raku
my $label = "Home";
my $n = 3;
say "<a>$label\</a>";
say "<a>{$label}</a>";
say "$n\{1} {$n}[0] $n\[0]";
```
```output
<a>Home</a>
<a>Home</a>
3{1} 3[0] 3[0]
```

The other brackets fail in the same way at run time: `"$n{1}"` asks an `Int`
for a hash key, `"$name()"` tries to call a string, and `"$n[1]"` asks a single
value for its second element. `"$n[0]"` happens to work, because a single value
answers index 0 with itself.

## A `{` in double quotes opens a block of code
tags: trap

`{…}` inside double quotes is a block: it runs, and its value is interpolated.
It is the way to interpolate an expression, or to separate a variable from the
letters that follow it. A lone `}` is plain text; only `{` needs a backslash.

```raku
my $x = 5;
say "{ 1 + 1 }";
say "{$x}th";
say "if (x) \{ y }";
```
```output
2
5th
if (x) { y }
```

Without the backslash, text meant as a brace is compiled as code, and the error
names whatever the code turned out to call. In this CSS rule, `color` and `red`
are read as sub calls, and so is the `n` of `\n`: inside a block a backslash is
an operator, not an escape.

```raku
say "body {\n  color: red;\n}";
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Undeclared routines:
    color used at line 1. Did you mean 'floor'?
    n used at line 1
    red used at line 1. Did you mean 'redo'?

```

## An apostrophe or a hyphen followed by a letter continues the name
tags: trap

Raku identifiers may contain `'` and `-` between letters, as in `$don't` or
`$first-name`. Interpolation reads the longest name it can, so `"$name's"`
looks for a variable called `$name's`:

```raku
my $name = "Ada";
say "$name's book";
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Variable '$name's' is not declared. Did you mean '$name'?
at example.raku:2
------> say "<HERE>$name's book";
```

Followed by anything other than a letter, the `'` or `-` is text, so `"$x-1"`,
`"$x'"` and `"$x!"` interpolate `$x`. Braces or a backslash end the name before
a letter:

```raku
my $name = "Ada";
my $x = 42;
say "{$name}'s book";
say "$name\'s book";
say "$x-1 $x' $x!";
```
```output
Ada's book
Ada's book
42-1 42' 42!
```

## Every kind of scalar interpolates, including match variables

Match variables, compile-time variables and dynamic variables are scalars too.
A `$` variable that holds an array or a hash interpolates whole, without a
subscript:

```raku
"2026-09" ~~ /(\d+) '-' $<month>=(\d+)/;
say "year $0, month $<month>, all $/";
say "line $?LINE";
say "$*RAKU";
my $h = { a => 1 };
my $l = [1, 2];
say "$h | $l";
```
```output
year 2026, month 09, all 2026-09
line 3
Raku
a	1 | 1 2
```

## An undefined value interpolates as an empty string, with a warning

An undefined scalar becomes the empty string, and Rakudo warns at run time. An
empty block returns `Nil`, which warns in the same way.

```raku
my $name;
say "Hello, $name!";
say "[{}]";
```
```output
Hello, !
[]
```
```stderr
Use of uninitialized value element of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 2
Use of Nil in string context
  in block <unit> at example.raku line 3
```

The warning does not name the variable; the line number is the clue.

## `< >` splits on whitespace and on nothing else

`<…>` and `qw<…>` cut their text at whitespace. Quotes inside are ordinary
characters, and so is a backslash before a space:

```raku
say <a b c>.raku;
say <a "b c" d>.raku;
say <a\ b>.raku;
say qw<a 'b c'>.raku;
```
```output
("a", "b", "c")
("a", "\"b", "c\"", "d")
("a\\", "b")
("a", "'b", "c'")
```

The forms that keep quoted words together are `qww` and `<< >>`, below.

## A single word in angle brackets is a Str, not a list
tags: trap

`<a b>` is a `List`, but `<a>` is the string `"a"`. Code that expects a list
from a word quote breaks as soon as the quote holds one word:

```raku
sub count(@items) { @items.elems }
say <a b>.^name;
say <a>.^name;
say count(<a b>);
say count(<a>);
```
```output
List
Str
2
```
```stderr
Type check failed in binding to parameter '@items'; expected Positional but got Str ("a")
  in sub count at example.raku line 1
  in block <unit> at example.raku line 5

```

`< >` with only whitespace inside is the empty list. A word list is
immutable: assign it to an array to change it.

```raku
say < >.raku;
say (try <a b>.push("c")) // $!.^name;
my @words = <a b>;
@words.push: "c";
say @words;
```
```output
()
X::Immutable
[a b c]
```

## Numbers in a word list become allomorphs
tags: trap

`<…>` passes every word through `val`: a word that reads as a number becomes an
*allomorph*, a value that is a number and a string at once (`IntStr`,
`RatStr`, `NumStr` or `ComplexStr`). Everything else stays a `Str`. `qw` does
not do this.

```raku
say <42 4.5 1e3 1/2 0x10 1_000 -1 Inf .5>.map(*.^name);
say <1a 1. 1_ 1e 12:30>.map(*.^name);
say qw<42 4.5>.map(*.^name);
```
```output
(IntStr RatStr NumStr RatStr IntStr IntStr IntStr NumStr RatStr)
(Str Str Str Str Str)
(Str Str)
```

An allomorph is equal to its number under `==` and to its string under `eq`,
it sorts as a number, and it type-checks as both an `Int` and a `Str`. It is
not the same value as either, though, so anything that compares by identity
tells them apart. Set membership does not find the number 1 among the words
`<1 2 3>`:

```raku
say <10 9 100>.sort;
say qw<10 9 100>.sort;
say <42> == 42 && <42> eq "42";
say <42> ~~ Int && <42> ~~ Str;
say <42> === 42;
say 1 ∈ <1 2 3>;
say <1> ∈ <1 2 3>;
```
```output
(9 10 100)
(10 100 9)
True
True
False
False
True
```

## A lone fraction in angle brackets is a number literal

With a single word and no whitespace inside the brackets, `<1/2>` is not a
word list at all: it is how Raku writes a `Rat` literal, and `<1+2i>` a
`Complex`. Add spaces and the same text is a word, and becomes an allomorph.

```raku
say <1/2>.^name;
say < 1/2 >.^name;
say <1+2i>.^name;
say < 1+2i >.^name;
say <42>.^name;
say <1/0>.raku;
```
```output
Rat
RatStr
Complex
ComplexStr
IntStr
<1/0>
```

Only fractions and complex numbers get this treatment; `<42>` is an `IntStr`
with or without the spaces. `<1/0>` is a `Rat` with a zero denominator, and
prints itself in the same form.

## `<< >>` interpolates and keeps quoted words together

There are four word-quoting forms, one for each combination of interpolation
and *quote protection*, which keeps a quoted part together as one word:

| form | interpolates | protects quotes |
|---|---|---|
| `qw` | no | no |
| `qww` | no | yes |
| `qqw` | yes | no |
| `qqww`, `<< >>`, `« »` | yes | yes |

A protected word follows the rules of its own quotes, so `"…"` interpolates
even in `qww` and `'…'` does not interpolate even in `qqww`. An interpolated
value is split into words, unless it sits inside quotes.

```raku
my $x = "p q";
say qw{$x "$x" '$x'}.raku;
say qww{$x "$x" '$x'}.raku;
say qqw{$x "$x" '$x'}.raku;
say << $x "$x" '$x' >>.raku;
```
```output
("\$x", "\"\$x\"", "'\$x'")
("\$x", "p q", "\$x")
("p", "q", "\"p", "q\"", "'p", "q'")
("p", "q", "p q", "\$x")
```

`<< >>` differs from `qqww` only in passing its words through `val`, as `< >`
does: `<< 1 "2" >>` holds two `IntStr` values.

## In `<< >>`, every interpolation starts a new word
tags: trap

In `<< >>` and `qqww`, text written directly next to a variable is not joined
to it: the variable's value becomes words of its own, and so does the text.
A quoted part next to plain text is likewise a separate word. `qqw`
interpolates first and splits afterwards, so it joins them.

```raku
my $b = "b";
say << a$b >>.raku;
say qqw{a$b}.raku;
say << 'a b'c >>.raku;
say << "a$b" >>.raku;
```
```output
("a", "b")
("ab",)
("a b", "c")
"ab"
```

To glue the parts together, put the whole word in double quotes, as on the
last line, where the result is a single word and therefore a `Str`.

## Adverbs switch features one at a time, and the last one wins

Any of the adverbs in the table at the start of the chapter can be added to
`Q`, `q` or `qq`, and negated with `!`. When two of them disagree, the later
one wins:

```raku
my $x = 1;
my @a = 2, 3;
sub f { "F" }
say q:s[$x @a[] &f() {1 + 1}];
say q:a:f[$x @a[] &f() {1 + 1}];
say qq:!s[$x @a[] &f() {1 + 1}];
say qq:!b[$x\n];
say qq:c:!c[{1}];
say qq:!c:c[{1}];
say Q:scalar:closure[$x {$x + 1} @a[]];
```
```output
1 @a[] &f() {1 + 1}
$x 2 3 F {1 + 1}
$x 2 3 F 2
1\n
{1}
1
1 2 @a[]
```

`:q` and `:qq` choose the whole set of escapes, and can only be added to a bare
`Q`. On a form that already has them, the compiler says it is too late:

```raku
say qq:q{a};
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Too late for :q
at example.raku:1
------> say qq:q<HERE>{a};
```

An adverb the compiler does not know, such as `q:zz`, is a compile-time error
too, *Unrecognized adverb*.

## `:w`, `:v` and `:x` work on the result, in the order written

`:w`, `:ww`, `:v` and `:x` do not change how the text is read; they transform
the finished string, one after another, in the order they appear. A later
`:!w` cannot undo a split that has already been done, while `:w(0)` is the
adverb switched off from the start.

```raku
say q:w:!w{a b}.raku;
say q:w(0){a b}.raku;
say q:w:v{1 b 2.5}.map(*.^name);
say q:v:w{1 b 2.5}.map(*.^name);
say Q:v{42}.^name;
say Q:v{1 2}.^name;
```
```output
("a", "b")
"a b"
(IntStr Str RatStr)
(Str Str Str)
IntStr
Str
```

In `q:v:w`, `val` sees the whole string `"1 b 2.5"`, which is not a number,
and the split that follows produces plain strings.

## Inside brace delimiters, a `{` is not a block
tags: trap

When a quote is delimited by braces, inner braces only nest: they are never a
block, even with `:c` switched on explicitly. The other interpolations still
work, including a hash subscript written with braces.

```raku
my %h = k => 5;
say qq{one and one is {1 + 1}};
say qq[one and one is {1 + 1}];
say qq:c{one and one is {1 + 1}};
say qq{%h{'k'} %h<k>};
say qq{a\{1 + 1\}b};
```
```output
one and one is {1 + 1}
one and one is 2
one and one is {1 + 1}
5 5
a{1 + 1}b
```

Choose another delimiter when the string needs a block.

## Brackets nest, and a doubled bracket is one delimiter

Any bracketing pair, ASCII or Unicode, can delimit a quote, and the same pair
inside nests to its own depth. A different pair inside is just text. Doubling
the opening bracket makes the doubled closer the delimiter, so that a single
closer can appear inside:

```raku
say q{a{b}c};
say q<a<b>c>;
say q«a«b»c»;
say q{a⟨b⟩c};
say q{a[b};
say Q{{a}b}};
say Q[[a] [b]];
say q<<a b>>.raku;
```
```output
a{b}c
a<b>c
a«b»c
a⟨b⟩c
a[b
a}b
a] [b
"a b"
```

The last line is the trap in the rule: `q<<a b>>` is `q` with a doubled
delimiter, one string, while `<<a b>>` on its own is a word list. An
unbalanced inner bracket leaves the quote open: `q{a{b}` looks for one more
`}` to the end of the file. `q<>` is the empty string.

## Any other character closes itself, but not every character can open
tags: trap

A delimiter that is not a bracket is its own closer: `q/a/`, `q!a!`, `q|a|`,
even `q😀a😀`. A backslash escapes it in `q` but not in `Q`. A space between
`q` and the delimiter is allowed, and sometimes needed:

```raku
say q/a\/b/;
say q!a!;
say q😀a😀;
say q (a);
say q 'x';
say Q :w [a b];
```
```output
a/b
a
a
a
x
(a b)
```

What cannot follow `q` directly is anything that would continue a name or
start something else. Letters, digits, `_` and `'` join the name, so `q1a1` is
a call to a sub called `q1a1`, and `q'a'` is the identifier `q'a` followed by a
stray apostrophe. `#` is refused as a delimiter, `:` starts an adverb, and a
letter after a space is refused too. A parenthesis makes a sub call:

```raku
say q(a);
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Undeclared routines:
    a used at line 1
    q used at line 1

```

## Curly quotes are quotes too

`‘…’` quotes like `'…'`, `“…”` like `"…"`, and `｢…｣` is `Q`. The low and the
reversed openers used in some languages work as well. Any of `‘`, `’` and `‚`
opens a single-quoted string; `’` closes it, and so does `‘`, unless `‘` was
also the opener. The double quotes `“`, `”` and `„` follow the same pattern
with `”` and `“`. So `„…“` and `‚…’` work, while `‘…‘` and `„…„` never find
their end.

```raku
my $x = 42;
say ‘single $x’;
say “double $x”;
say ｢corner $x \n｣;
say „low $x“;
say “it’s”;
say q“a”;
```
```output
single $x
double 42
corner $x \n
low 42
it’s
a
```

A `’` inside `“…”` is an ordinary character, which is what makes “it’s”
work.

## A heredoc removes the terminator's indentation from every line

`q:to/END/` starts a string on the next line and ends it at a line holding only
`END`. The terminator may be indented; that much indentation is removed from
every line of the body, and whatever is beyond it stays. The newline before
the terminator belongs to the string.

```raku
my $text = q:to/END/;
    first
      indented
    last
    END
print $text;
say $text.raku;
```
```output
first
  indented
last
"first\n  indented\nlast\n"
```

A blank line stays blank. A line indented less than the terminator loses all
of its leading whitespace, and the compiler warns:

```raku
my $odd = q:to/END/;
      six
  two

    four
    END
say $odd.raku;
```
```output
"  six\ntwo\n\nfour\n"
```
```stderr
Potential difficulties:
    Asked to remove 4 spaces, but the shortest indent is 2 spaces
    at example.raku:6
    ------>     END<HERE><EOL>
```

## A tab in a heredoc's indentation reaches the next multiple of eight

Indentation is measured in columns, and a tab advances to the next multiple of
`$?TABSTOP`, which is 8. A terminator indented by one tab therefore removes a
tab or eight spaces, and a tab that is only partly inside the indentation is
turned into the spaces that remain. These examples build each heredoc as a
string, so that the tabs are visible as `\t`:

```raku
say $?TABSTOP;
say EVAL("q:to/END/;\n\ta\n\t\tb\n\tEND\n").raku;
say EVAL("q:to/END/;\n        a\n\tb\n        END\n").raku;
say EVAL("q:to/END/;\n  \ta\n  END\n").raku;
```
```output
8
"a\n\tb\n"
"a\nb\n"
"      a\n"
```

In the last one the terminator is indented by two spaces. The tab after them
reaches column 8; removing two columns leaves six spaces.

## Interpolated text keeps its own indentation

In `qq:to`, the indentation is removed from the template before anything is
interpolated. A value with leading spaces or several lines goes in exactly as
it is:

```raku
my $lines = "one\n  two";
my $s = qq:to/END/;
    [$lines]
      {"  x"}
    END
say $s.raku;
```
```output
"[one\n  two]\n    x\n"
```

The second line of the template kept the two spaces beyond the indentation,
and the block added two more.

## The rest of a heredoc's line is ordinary code

The body starts on the line after the quote, so the statement around the quote
carries on normally to the end of its own line: a method call, an operator, a
second heredoc. Several heredocs on one line take their bodies one after
another.

```raku
my @lines = q:to/END/.lines;
    alpha
    beta
    END
say @lines.raku;
say q:to/END/.uc ~ "!";
    shout
    END
my ($a, $b) = q:to/A/, q:to/B/;
    first
    A
    second
    B
say $a.raku, " ", $b.raku;
```
```output
["alpha", "beta"]
SHOUT
!
"first\n" "second\n"
```

The statement still needs its `;` on that line. Without it, the body is read as
code that continues the statement, and the compiler reports two terms in a row
with a hint about a runaway multi-line quote.

## The terminator must match exactly and stand alone

The terminator is compared exactly and case-sensitively, and it may contain
spaces. Lines that only start with it, or differ from it in case, are body
text:

```raku
my $s = q:to/END/;
    ENDING
    end
    END:
    END
say $s.raku;
say q:to/THE END/.raku;
    body
    THE END
say q:to{END}.raku;
    END
```
```output
"ENDING\nend\nEND:\n"
"body\n"
""
```

Any delimiter works around the terminator's name, braces included, and a
heredoc with nothing before its terminator is the empty string.

Anything after the terminator on its line, even a comment, turns it into body
text, and the heredoc then has no end:

```raku
my $s = q:to/END/;
    a
    END # done
say $s;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Ending delimiter END not found
at example.raku:5
------> <BOL><HERE><EOL>
    expecting any of:
        whitespace
```

## Adverbs apply to a heredoc as to any quote

`:to` combines with the other adverbs: `q:to:w` splits the body into words,
`qq:to:!s` leaves scalars alone, and `\qq[…]` works in a `q:to` body. `Q:to`
keeps every backslash. `:v` is the exception: the body stays a `Str`.

```raku
my $x = 42;
say q:to:w/END/.raku;
    a b
    c
    END
say qq:to:!s/END/.raku;
    $x {$x}
    END
say q:to/END/.raku;
    $x \qq[$x]
    END
say q:to:v/END/.^name;
    42
    END
```
```output
("a", "b", "c")
"\$x 42\n"
"\$x 42\n"
Str
```

## `qx` returns what the command printed, and never fails

`qx{…}`, like `q:x` and `Q:x`, passes its text to the shell and returns the
command's standard output as a `Str`, newline included. The exit status is not
reported: a failing command returns whatever it printed before failing, often
the empty string, and nothing is thrown.

```raku local
say qx{echo hi}.raku;
say qx{exit 3}.raku;
say qx{echo partial; exit 2}.raku;
say qx{no-such-command-42 2>/dev/null}.raku;
say qx{printf 'a\nb'}.lines.raku;
```
```output
"hi\n"
""
"partial\n"
""
("a", "b").Seq
```

Use `run` or `shell` when the exit status matters.

## Only `qqx` interpolates; `qx` hands `$who` to the shell

`qx` has the rules of `q`, so a `$who` in it reaches the shell untouched, and
the shell expands its own variable of that name, usually empty. `qqx`
interpolates Raku's `$who` first. The result adverbs apply in order:
`q:x:w` splits the output, `q:w:x` splits the command and runs its words
joined by single spaces, which reaches even into the shell's own quotes, and
`:v` makes a numeric output an allomorph.

```raku local
my $who = "there";
say qqx{echo hi $who}.raku;
say qx{echo hi $who}.raku;
say q:x:w{echo a b}.raku;
say qx{echo "a   b"}.raku;
say q:w:x{echo "a   b"}.raku;
say q:x:v{echo 42}.raku;
```
```output
"hi there\n"
"hi\n"
("a", "b")
"a   b\n"
"a b\n"
IntStr.new(42, "42\n")
```

## Braces inside `qx{…}` run a command of their own
tags: bug

With brace delimiters, the inner braces of a `qx` should be text, as nested
delimiters are in every other quoting form, `qq{…}` included. Rakudo 2026.08
instead runs the
text between the inner braces as a separate shell command first, and puts its
output, trailing newline and all, in their place. With other delimiters the
braces are left alone:

```raku local
say qx[echo '{echo inner}'].raku;
say qx{echo '{echo inner}'}.raku;
```
```output
"\{echo inner}\n"
"\{inner\n}\n"
```

The single quotes keep the shell from reading the braces; even so, `echo inner`
ran on its own and its output landed between them. (`.raku` writes a brace as
`\{` so that its result can be pasted back into double quotes.) A brace group
that is not a command, as in `qx{echo {1+1}}`, puts a "command not found" from
the shell on standard error and is replaced by nothing. Use square brackets for
a command that contains braces.
