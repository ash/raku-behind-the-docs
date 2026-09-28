---
title: Regexes and Grammars
part: Code
summary: Which alternative a regex takes and what it runs again when it backtracks, where captures land, what a Match and `$/` hold and in which scope, what the adverbs of `.match` count, and in what order a grammar calls its actions.
---

A regex is code. `/…/` makes a `Regex` object, a kind of method that runs
against a string and answers a `Match`. A grammar is a class whose methods are
regexes, and an actions object is a class whose methods are called as the
grammar's rules succeed. The regex syntax is described at length on
docs.raku.org; this chapter is about what that description leaves open: which
alternative wins, when the engine goes back and what it runs again when it
does, where captures land and how they are numbered, what `$/` holds and in
which scope, what the adverbs of `.match` count, and in what order a grammar
calls its actions.

The string methods that also take a regex, `comb`, `split`, `subst`, `trans`
and `contains`, are in [Strings](#ch:strings) next to their string forms. This
chapter links to them where a regex form repeats one.

## `|` takes the longest alternative, `||` the first that matches
tags: trap

The two alternation operators decide differently. `||` tries its branches in
the order they are written and takes the first that matches. `|` is
*longest-token matching*: it starts with the branch that matches the most
characters, whatever its position, and falls back to shorter ones only if the
rest of the regex fails after it.

```raku
say ~("3.14" ~~ / \d+ | \d+ '.' \d+ /);
say ~("3.14" ~~ / \d+ || \d+ '.' \d+ /);
say ~("abc" ~~ / a | ab | abc /);
say ~("abc" ~~ / a || ab || abc /);
say ~("abc" ~~ / [ abc | ab ] c /);
say ("ab" ~~ / $<x>=[ab] | $<y>=[ab] /).keys;
```
```output
3.14
3
abc
a
abc
(x)
```

With `||` the order is the programmer's; with `|` it is the text's. In the
fifth line `abc` is tried first, the `c` after it fails, and the engine falls
back to `ab`. Branches that match the same length are tried in the order
written, as the last line shows.

## A code block ends the part of a branch that `|` measures
tags: trap

`|` does not run each branch to see how far it gets. It measures each branch's
*declarative prefix*, the part made of literals, character classes,
quantifiers and calls to other declarative rules, and a code block ends that
part. A branch with a block early in it counts only what comes before the
block, and can lose to a branch that matches less text in the end:

```raku
say ~("abcd" ~~ / a \w+ | ab /);
say ~("abcd" ~~ / a {} \w+ | ab /);
```
```output
abcd
ab
```

With the empty block, the first branch counts as one character long and the
second as two, so `ab` wins.

## A code block runs every time the engine reaches it
tags: trap

A block `{ … }` inside a regex runs when matching reaches it, and again each
time backtracking brings the engine back to it. Nothing undoes what the block
did when its branch is abandoned, and that includes a match that fails in the
end:

```raku
my @seen;
say "aaa" ~~ / a+ { @seen.push: $/.to } b /;
say @seen;
```
```output
Nil
[3 2 1 3 2 3]
```

`a+` first takes all three `a`s and the block records position 3; `b` fails,
and the engine gives back one `a` at a time, running the block at 2 and at 1.
Then it starts again from the second character and from the third. Six calls,
and no match. A block is the place to compute from the text matched so far,
not to count or to print. A grammar's actions have the same property
([below](#ch:regexes:actions-fire-for-branches-that-are-later-abandoned)).

## `token` and `rule` never backtrack; `regex` does

A plain `/…/` and a `regex` backtrack: `a+ a` gives an `a` back so that the
second `a` can match. The `:r` (`:ratchet`) adverb turns that off, and a
`token` or a `rule` is ratcheted from the start, so `a+` keeps what it took and
the match fails.

```raku
say ~("aaa" ~~ / a+ a /);
say ("aaa" ~~ / :r a+ a /).raku;
my token t { a+ a }
my regex r { a+ a }
say ("aaa" ~~ / <t> /).raku;
say ~("aaa" ~~ / <r> /);
```
```output
aaa
Nil
Nil
aaa
```

A subrule keeps its own kind. A token called from a regex that backtracks
still does not give anything back, while a `regex` subrule does:

```raku
my token digits { \d+ }
my regex rdigits { \d+ }
say ("123" ~~ / <digits> 3 /).raku;
say ~("123" ~~ / <rdigits> 3 /);
```
```output
Nil
123
```

## `:` stops backtracking into one atom, `!` allows it under a ratchet

The two modifiers on a quantifier work against the default around them. In a
backtracking regex, `a+:` keeps everything it took. Under `:r`, `a+!`
backtracks as in a plain regex. An alternation inside a ratcheted regex is not
retried either: `|` tries its longest branch first and `||` its first branch,
and whichever succeeded is kept.

```raku
say ("aaa" ~~ / a+: a /).raku;
say ~("aaa" ~~ / :r a+! a /);
say ~("aaa" ~~ / :r [ a | aa ] a /);
say ~("aaa" ~~ / :r [ a || aa ] a /);
```
```output
Nil
aaa
aaa
aa
```

In the last line `[ a || aa ]` takes one `a`, the final `a` matches the
second, and the match ends there: the engine never comes back to try `aa`.

## `rule` puts `<.ws>` after every atom, the last one included

In a `rule`, and under the `:s` (`:sigspace`) adverb, whitespace after an atom
is not ignored: it becomes a call to `<.ws>`, the rule that matches
whitespace. That includes the whitespace after the last atom, so a rule also
matches the blanks that follow it. In a `token`, spaces are ignored.

```raku
my rule pair { \w+ '=' \w+ }
say ("a = b" ~~ / <pair> /).Str.raku;
say ("a=b" ~~ / <pair> /).Str.raku;
say ("a =b  " ~~ / <pair> /).Str.raku;
say ("a = b" ~~ / :s \w+ '=' \w+ /).Str.raku;
my token tight { \w+ '=' \w+ }
say ("a = b" ~~ / <tight> /).raku;
```
```output
"a = b"
"a=b"
"a =b  "
"a = b"
Nil
```

`<.ws>` may match nothing, which is why `a=b` still matches. But it may match
nothing only in some places, and an optional atom shows where:

```raku
my rule opt { a? b }
say ("b" ~~ / ^ <opt> $ /).Str.raku;
say ("a b" ~~ / ^ <opt> $ /).Str.raku;
say ("ab" ~~ / ^ <opt> $ /).raku;
```
```output
"b"
"a b"
Nil
```

## `<ws>` cannot match between two word characters
tags: trap

`<ws>` matches a run of whitespace, or nothing where a word ends: next to a
character that is not a word character, or at either end of the string.
Between two word characters it needs at least one blank. The underscore is a
word character.

```raku
say ("a b" ~~ / a <ws> b /).Str.raku;
say ("ab"  ~~ / a <ws> b /).raku;
say ("a+b" ~~ / a <ws> '+' <ws> b /).Str;
say ("a_b" ~~ / a <ws> '_' /).raku;
```
```output
"a b"
Nil
a+b
Nil
```

That is the reason `a? b` in a rule fails on `ab`: the `<.ws>` between the
`a` and the `b` stands between two letters.

## `%` puts a separator between repetitions of one atom
tags: trap

`X+ % ','` matches `X` one or more times with a comma between each two.
`%%` allows one more separator at the end. The quantifier and the separator
belong to the atom just before them, so in `\d+ % ','` the atom is `\d`, a
single digit, and `12,34` stops after the `1`. Group the atom to repeat
numbers.

```raku
say ~("1,2,3," ~~ / \d+ % ',' /);
say ~("1,2,3," ~~ / \d+ %% ',' /);
say ~("12,34" ~~ / \d+ % ',' /);
say ~("12,34" ~~ / [\d+]+ % ',' /);
say ("12,34" ~~ / (\d+)+ % ',' /)[0]».Str;
say ~("1-2-3" ~~ / \d ** 2 % '-' /);
```
```output
1,2,3
1,2,3,
1
12,34
[12 34]
1-2
```

The separator is not captured unless it is written as a capture, and it works
with a counted quantifier too.

## `<(` and `)>` choose the part of the match that counts

`<(` marks where the reported match starts and `)>` where it ends. The rest
of the pattern must still match, but it is left out of the Match's text, its
`.from` and `.to`, its `.prematch` and `.postmatch`, and of what `subst` and
`comb` see:

```raku
"xxabcxx" ~~ / xx <( abc )> xx /;
say ~$/, " ", $/.from, " ", $/.to;
say $/.prematch, "|", $/.postmatch;
say "key=value".match(/ \w+ '=' <( \w+ /).Str;
say "price: 42 EUR".subst(/ \d+ <( \s EUR /, "");
```
```output
abc 2 5
xx|xx
value
price: 42
```

Either marker may be used alone. `)>` is one token, so a capture that closes
just before a `>` needs a space: `<?before (\d) >`, not `<?before (\d)>`.

## After `)>`, `.pos` is not `.to`
tags: quirk

`)>` sets `.to`, but `.pos`, the position where the whole pattern ended, stays
past the trailing context. `.raku` prints `:pos`, so a marked Match does not
survive a round trip through `.raku`: the copy spans the trailing text too.

```raku
"xxabcxx" ~~ / xx <( abc )> xx /;
say $/.to, " ", $/.pos;
say $/.raku;
say $/.raku.EVAL.Str;
```
```output
5 7
Match.new(:orig("xxabcxx"), :from(2), :pos(7))
abcxx
```

A `:g` match goes on from `.pos`, so the trailing context of one match cannot
be the leading context of the next. A lookahead does not consume its text,
and can:

```raku
say "XaXbX".match(/ X <( \w )> X /, :g)».Str;
say "XaXbX".match(/ X \w <?before X> /, :g)».Str;
```
```output
(a)
(Xa Xb)
```

## A capture can be matched again later in the same regex

A variable in a regex matches its current value as literal text. `$0` and
`$<name>` are variables too, and inside the regex they hold what has been
captured so far, so they match the same text again:

```raku
say ~("abccd" ~~ / (.) $0 /);
say ~("abccd" ~~ / $<c>=(.) $<c> /);
say ~("say 'hi' now" ~~ / $<q>=<['"]> .*? $<q> /);
say ("abcd" ~~ / $<c>=(.) $<c> /).raku;
```
```output
cc
cc
'hi'
Nil
```

The third line finds a quoted string that ends with the same kind of quote it
started with.

## `&` wants both sides to match the same stretch of text

`&` is a conjunction: the text at the current position must match both sides,
and both must end at the same place. A quantifier on one side gives back
characters until the other side can match exactly the same span.

```raku
say ~("abc123" ~~ / \w+ & \D+ /);
say ~("foobar" ~~ / <[a..z]>+ & . ** 3 /);
say ("abc" ~~ / a & b /).raku;
```
```output
abc
foo
Nil
```

`\w+` alone would take all six characters; the conjunction with `\D+` cuts
it back to the letters.

## A lexical regex hides a built-in rule, but not from `<.name>`
tags: trap

`<name>` looks for a lexical `my regex name` first, and only then for a
method. A lexical regex with the name of a built-in rule therefore replaces
it, in every regex in its scope, a grammar's rules included. `<.name>` does
not capture, and it also does not look for lexicals: it always calls the
method.

```raku
my regex ident { \d+ }
say ~("abc 123" ~~ / <ident> /);
say ~("abc 123" ~~ / <.ident> /);
grammar G { token TOP { <ident> } }
say G.parse("abc").raku;
say G.parse("123").Str;
```
```output
123
abc
Nil
123
```

For a name with no method behind it, the dot turns a working call into an
error:

```raku
my regex foo { \d+ }
say ~("a1" ~~ / <foo> /);
say ~("a1" ~~ / <.foo> /);
```
```output
1
```
```stderr
No such method 'foo' for invocant of type 'Match'
  in block <unit> at example.raku line 3

```

`<&foo>` is the form that calls the lexical regex without capturing.

## `$var` matches its text; `<$var>` compiles it

A scalar in a regex matches its value literally: metacharacters in it are
just characters, and a space in it must match a space, even under `:s`. `:i`
applies to it. `<$var>` compiles the value as a regex instead. An array is an
alternation of its elements, and like `|` it takes the longest one that
matches, whatever the order; an empty array matches nothing.

```raku
my $v = "a.c";
say ("abc" ~~ / $v /).raku;
say ~("a.c" ~~ / $v /);
say ~("abc" ~~ / <$v> /);
my $w = "abc";
say ~("ABC" ~~ / :i $w /);
my @words = <ab abc a>;
say ~("abcd" ~~ / @words /);
my @none;
say ("abc" ~~ / @none /).raku;
```
```output
Nil
a.c
abc
ABC
abc
Nil
```

## An interpolated regex keeps its captures to itself

A Regex value interpolated with `$r` or `<$r>` runs as a subrule. The
captures it makes are its own, and the outer match does not get them: its
`.elems` counts only its own parentheses. An alias, `<name=$r>`, stores the
inner match under a name, and its captures come with it.

```raku
my $inner = rx/ (b) /;
say ("abc" ~~ / a $inner c /).elems;
say ("abc" ~~ / a <$inner> c /).elems;
say ("abc" ~~ / a <in=$inner> c /)<in>[0].Str;
```
```output
0
0
b
```

## `<%h>` compiles and never matches
tags: quirk

A hash written bare in a regex is refused at compile time. In angle brackets
it compiles, but no hash was found that makes it match: keys that are a
prefix of the text, with values of `True`, the empty string or a regex, all
give Nil.

```raku
my %h = ab => True, a => True;
say ("abcd" ~~ / <%h> /).raku;
my %e = ab => "", a => "";
say ("abcd" ~~ / <%e> /).raku;
my %r = a => rx/b/;
say ("abcd" ~~ / <%r> /).raku;
```
```output
Nil
Nil
Nil
```

```raku
my %h;
say "a" ~~ / %h /;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
The use of hash variables in regexes is reserved
at example.raku:2
------> say "a" ~~ / %h<HERE> /;
```

## Nothing captured inside a lookaround survives
tags: quirk undocumented

A lookahead `<?before …>`, a negative lookahead `<!before …>` and a
lookbehind `<?after …>` test the text without consuming it, and whatever they
capture is thrown away with the position. The form without `?`,
`<before …>`, is an ordinary named subrule call: it captures a zero-width
Match called `before`, which has no captures of its own either.

```raku
say ("a1" ~~ / a <?before (\d) > /).elems;
say ("a1" ~~ / a <?before $<d>=\d > /)<d>.raku;
say ("ab" ~~ / (a) <?after (a) > b /).elems;
say ("a1" ~~ / a <before (\d) > /).keys;
say ("a1" ~~ / a <before (\d) > /)<before>.raku;
```
```output
0
Nil
1
(before)
Match.new(:orig("a1"), :from(1), :pos(1))
```

The space before each closing `>` matters. Without it, `)>` is read as the
end-of-match marker, and the parenthesis is never closed:

```raku
say "a1" ~~ / a <?before (\d)> /;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Unable to parse expression in metachar:sym<( )>; couldn't find final ')' (corresponding starter was at line 1)
at example.raku:1
------> say "a1" ~~ / a <?before (\d)> <HERE>/;
    expecting any of:
        horizontal whitespace
        infix stopper
        term
        whitespace
```

## Any quantifier makes a capture an Array, except `?`

An unquantified `( … )` gives one Match. Put any quantifier on it, even
`** 1`, and the capture becomes an Array of Matches, empty when there were no
repetitions. `?` is the exception: it gives one Match, or Nil.

```raku
say ("123" ~~ / (\d)+ /)[0].^name;
say ("12"  ~~ / (\d) ** 1 /)[0].^name;
say ("b"   ~~ / (a)* b /)[0].raku;
say ("aa"  ~~ / [ (a) ]* /)[0].^name;
say ("a"   ~~ / (a)? /)[0].^name;
say (""    ~~ / (a)? /)[0].raku;
```
```output
Array
Array
[]
Array
Match
Nil
```

The fourth line shows that a quantifier on a group around the capture has the
same effect.

## An absent capture prints as Mu in `.list`, but reads Nil
tags: quirk

An optional capture that did not match still has its slot, so the captures
after it keep their numbers and `.elems` counts it. Read directly, the slot is
Nil and does not exist; in the `.raku` of `.list` it shows as `Mu`.

```raku
"ab" ~~ / (a) (X)? (b) /;
say $/.elems;
say $1.raku;
say ($/[1]:exists);
say $/.list.raku;
```
```output
3
Nil
False
(Match.new(:orig("ab"), :from(0), :pos(1)), Mu, Match.new(:orig("ab"), :from(1), :pos(2)))
```

## Alternatives number their captures from the same index

Each branch of `|` or `||` starts numbering at the index where the
alternation starts, so `(a) | (b)` has one slot, whichever branch matched.
`.elems` goes up to the highest slot the winning branch filled. A quantified
group of alternatives gathers the captures of all its branches into one
Array.

```raku
say ~("b" ~~ / (a) | (b) /)[0];
"c" ~~ / (a) (b) | (c) /;
say $0.Str, " ", $/.elems, " ", $1.raku;
"ac" ~~ / (a) [ (b) | (c) ] /;
say $1.Str;
say ("ab" ~~ / [ (a) | (b) ]+ /)[0].elems;
```
```output
b
c 1 Nil
c
2
```

## A named group is not numbered, and a repeated name collects an Array

`$<x>=( … )` stores its capture under `x` only: the parentheses do not also
make it `$0`, so `.elems`, which counts positional captures, stays 0. A named
subrule called twice, `<a> <a>`, gives an Array, as a quantified one does;
`<a>*` that matched nothing is an empty Array.

```raku
"ab" ~~ / $<x>=(a) $<y>=[b] /;
say $<x>.Str, $<y>.Str, " ", $/.elems, " ", $/.hash.elems;
my regex a { a }
say ("aa" ~~ / <a> <a> /)<a>.^name;
say ("ab" ~~ / $<x>=(a)+ b /)<x>.^name;
say (""   ~~ / <a>* /)<a>.raku;
```
```output
ab 0 2
Array
Array
[]
```

## `.caps` and `.chunks` keep the order of the text; `.keys` does not

`.caps` lists every capture as a Pair of its name or number and its Match, in
the order they occur in the text. `.chunks` does the same and adds the text
between captures under the key `~`. `.keys`, `.values`, `.pairs` and `.kv`
give the positional captures first and then the named ones in hash order,
which changes from run to run; sort them.

```raku
"a1b2" ~~ / (a) $<n>=(\d) (b) $<m>=(\d) /;
say $/.caps.map({ .key ~ "=" ~ .value });
say $/.keys.sort;
"a-b" ~~ / (\w) '-' (\w) /;
say $/.chunks.map({ .key ~ "=" ~ .value });
```
```output
(0=a n=1 1=b m=2)
(0 1 m n)
(0=a ~=- 1=b)
```

## Two matches of the same text are `eqv`, never `===`

A Match's gist is its text in `｢ ｣`, followed by one line per capture in the
order of the text, a quantified capture repeating its key:

```raku
say "ab12" ~~ / (a) $<x>=(b) (\d)+ /;
```
```output
｢ab12｣
 0 => ｢a｣
 x => ｢b｣
 1 => ｢1｣
 1 => ｢2｣
```

A Match is an object, not a value: two matches of the same regex on the same
string are `eqv`, which compares the text, the positions and the captures,
but not `===`. As a key of an ordinary hash a Match turns into its string.

```raku
my $m1 = "ab" ~~ / b /;
my $m2 = "ab" ~~ / b /;
say $m1 eqv $m2;
say $m1 === $m2;
say ("1" ~~ / (\d) /) eqv ("1" ~~ / \d /);
my %h;
%h{$m1} = 1;
say %h.keys[0].^name;
```
```output
True
False
False
Str
```

## A Match computes with its text

A Match is a `Cool`: used as a number or a string it is its matched text.
`.from` and `.to` are positions in the whole string, `.prematch` and
`.postmatch` the text on either side, and `.replace-with` puts something in
the matched place. Text that is not a number numifies to a Failure.

```raku
"abc123def" ~~ / \d+ /;
say $/.from, " ", $/.to, " ", $/.chars;
say $/.prematch, " ", $/.postmatch;
say $/ + 1;
say $/.replace-with("X");
say ("abc" ~~ / b /).Int.^name;
```
```output
3 6 3
abc def
124
abcXdef
Failure
```

## A zero-width match is true; a Match that ends before it starts is false

A match of nothing, such as `^`, is still a successful Match: true, with an
empty text and the gist `｢｣`. A Match can also be built by hand with
`Match.new`; it is true when `:pos` is not before `:from`, and otherwise a
failed match. `:made` gives it a payload.

```raku
"abc" ~~ / ^ /;
say $/.Bool, " ", $/.Str.raku, " ", $/.gist;
my $m = Match.new(:orig("abc"), :from(2), :pos(1));
say $m.Bool, " ", $m.gist;
say Match.new(:orig("abc"), :from(1), :pos(2)).Str;
say Match.new(:orig("abc"), :from(1), :pos(2), :made(9)).made;
```
```output
True "" ｢｣
False #<failed match>
b
9
```

## `~~` and `.match` set the caller's `$/`, to Nil on failure

A successful smartmatch against a regex puts the Match into `$/`; a failed one
puts Nil there, so `$0` and `$<name>` read Nil after it. `.match` sets `$/` the
same way, with a regex or a string, and so do `.subst` with a regex and
`s///`. `.comb`, `.split`, `.contains`, and `.subst` with a string needle
leave it alone ([Strings](#ch:strings:with-a-string-needle-subst-leaves-alone)).

```raku
"abc" ~~ / b /;
say $/.raku;
"abc" ~~ / x /;
say $/.raku;
say $0.raku;
"abc".match(/ c /);
say ~$/;
"abc".match("a");
say ~$/;
"abc".comb(/ b /);
say ~$/;
```
```output
Match.new(:orig("abc"), :from(1), :pos(2))
Nil
Nil
c
a
a
```

After a failed match, `$/` is Nil and not a failed Match, so using it as a
string warns:

```raku
"abc" ~~ / x /;
say $/.Str.raku;
```
```output
""
```
```stderr
Use of Nil in string context
  in block <unit> at example.raku line 2
```

## Each routine has its own `$/`; its blocks share it

Every sub and method gets a fresh `$/`. A match inside a sub does not touch
the caller's, and a sub that matched nothing sees Nil. Blocks are not
routines: a bare block, a `for` loop, `given` and `when` all set the `$/` of
the routine around them, and it keeps its value after the block ends.

```raku
sub f { "xyz" ~~ / y /; ~$/ }
"zzz" ~~ / z /;
say f();
say ~$/;
{ "abc" ~~ / b / }
say ~$/;
for 1 { "abc" ~~ / c / }
say ~$/;
given "stu" { when / t / { } }
say ~$/;
sub g { $/ }
say g().raku;
```
```output
y
z
b
c
t
Nil
```

Inside a `for` over the result of `:g`, `$_` is each Match and `$/` is the
whole list, which `.match` put there:

```raku
for "a1b2".match(/ \d /, :g) {
    say .Str, " ", $/.^name;
}
```
```output
1 List
2 List
```

## Inside a code block, `$/` is the match so far

In a `{ … }` block within a regex, `$/` is the match in progress: its text
runs from the start of the match to the current position, and `$0` and the
other captures completed so far are there. `$¢` is another name for it, and
is Nil outside a regex. `:my` declares a variable for the blocks that follow.
Inside a named regex, `$/` is that regex's own match.

```raku
"abc" ~~ / (a) { say "so far: ", ~$/, ", \$0 = ", ~$0, ", pos ", $/.pos } bc /;
"ab" ~~ / a { say $/ === $¢ } b /;
say $¢.raku;
"ab" ~~ / :my $count = 5; a { say $count } b /;
my regex word { (\w+) { say "inside word: from ", $/.from } }
"say hello" ~~ / 'say ' <word> /;
```
```output
so far: a, $0 = a, pos 1
True
Nil
5
inside word: from 4
```

A block in `<?{ … }>` decides whether the match goes on: it continues when
the block returns a true value, and `<!{ … }>` when it returns a false one.
`<{ … }>` interpolates the block's result as regex source.

```raku
say ~("ab" ~~ / (a) <?{ $0 eq "a" }> b /);
say ("ab" ~~ / (a) <!{ $0 eq "a" }> b /).raku;
say ~("a1" ~~ / a <{ '\d' }> /);
```
```output
ab
Nil
a1
```

## `make` needs a Match, and the last `make` wins

`make` attaches a payload to the Match in `$/`, and `.made` reads it back. In a
code block it sees the captures so far, so it can compute from them. A second
`make` replaces the first. After a match, a bare `make` sets the payload of
`$/`; when `$/` holds no Match, `make` throws, and the exception's `.got` is
what `$/` held.

```raku
"2024-06" ~~ / (\d+) '-' (\d+) { make $0 * 12 + $1 } /;
say $/.made;
"x" ~~ / x { make "a" } { make "b" } /;
say $/.made;
"x" ~~ / x /;
make 7;
say $/.made;
"x" ~~ / y /;
try make 3;
say $!.^name, " ", $!.got.raku;
```
```output
24294
b
7
X::Make::MatchRequired Nil
```

## A list on the left of `~~` is matched element by element
tags: trap

A regex smartmatched against a List or an Array tries each element in turn
and returns the Match of the first that matches, so `.orig` is that element
and a pattern that spans two elements never matches. A Hash tries its keys. A
Junction gives a Junction of results. An Int topic is matched as its string,
but `.orig` keeps the Int.

```raku
say (<abc xyz bcd> ~~ / b /).orig;
say ((1, 2) ~~ / 2 /).raku;
say ((1, 2) ~~ / 1 \s 2 /).raku;
my %h = abc => 1;
say (%h ~~ / b /).orig;
say (42 ~~ / 4 /).orig.^name;
say (any("abc", "xyz") ~~ / b /).raku;
say so all("abc", "xyz") ~~ / b /;
say (~(1, 2) ~~ / 1 \s 2 /).Str;
```
```output
abc
Match.new(:orig(2), :from(0), :pos(1))
Nil
abc
Int
any(Match.new(:orig("abc"), :from(1), :pos(2)), Nil)
False
1 2
```

The last line shows the way to search the text of a list: stringify it
first.

## An undefined topic is matched as the empty string, with a warning
tags: trap

A regex smartmatched against a topic that is not a list or a hash
interprets it as a Str, as the documentation of `Regex.ACCEPTS` says. An
undefined topic, a type object or Nil, is no exception: it becomes the empty
string, with the usual warning, and the regex runs against that. So
`/ b /` fails with Nil rather than a quiet False:

```raku
my Str $s;
say ($s ~~ / b /).raku;
say (quietly $s ~~ / ^ $ /).raku;
```
```output
Nil
Match.new(:orig(""), :from(0), :pos(0))
```
```stderr
Use of uninitialized value of type Str in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 2
```

The second line shows that the type object is taken for the empty string: a
pattern that matches the empty string succeeds. `Nil ~~ / b /` does the same,
with the warning "Use of Nil in string context".

## A Match on the right of `~~` answers itself
tags: trap

A Match is not a pattern. Smartmatching anything against a concrete Match
returns that Match, whatever the topic, so a `when` with a Match always
succeeds. `!~~` negates it, so against a successful Match it is always
False.

```raku
my $m = "abc" ~~ / b /;
say ("zzz" ~~ $m).Str;
say (5 ~~ $m) === $m;
say "zzz" !~~ $m;
given 5 { when $m { say "when matched" } }
```
```output
b
True
False
when matched
```

## A regex in Boolean context matches `$_`, and in string context warns
tags: trap

A regex used as a condition, with `so`, `?`, `if` or `?? !!`, is matched
against `$_` at once, and `$/` is set. Its `.gist` and `.raku` are its source
text, adverbs included, and a named regex shows its declaration. As a string
it is empty, with a warning.

```raku
$_ = "abc";
say so / b /;
say / x / ?? "yes" !! "no";
if / c / { say "matched ", ~$/ }
my $r = rx:i/ a.b /;
say $r.gist;
my regex num { \d+ }
say &num.raku;
say "pattern: " ~ $r;
```
```output
True
no
matched c
rx:i/ a.b /
regex num { \d+ }
pattern: 
```
```stderr
Regex object coerced to string (please use .gist or .raku to do that)
  in block <unit> at example.raku line 9
```

## A regex called with a Match matches only at that position

A Regex is a method, and it can be called. Its one argument must be a Match,
which gives the string and the position: the regex matches there and only
there, and returns the new Match, false when it does not match at that
position. A string argument is refused, and a Regex cannot be made with
`.new`.

```raku
my $r = rx/ b /;
say $r(Match.new(:orig("abc"), :pos(1))).Str;
say $r(Match.new(:orig("abc"), :pos(0))).Bool;
try $r("abc");
say $!.^name;
try Regex.new;
say $!.^name;
```
```output
b
False
X::Method::NotFound
X::Cannot::New
```

## `m//` matches at once, with the adverbs of `.match`

`m/…/` matches against `$_` where it stands and gives the Match, or Nil; the
result stays as it was when `$_` changes later. The adverbs of `.match`,
described below, go after the `m`: `m:g` gives a List, which a `for` loop
walks and an array assignment stores.

```raku
$_ = "a1b2c3";
say (m:g/\d/).^name, " ", (m:g/\d/).elems;
say m:2nd/\d/;
say (m:x(2)/\d/)».Str;
say (m:c(3)/\d/).Str;
say (m:p(0)/\d/).raku;
my @all = m:g/\d/;
say @all.elems;
$_ = "a1";
my $m = m/ \d /;
$_ = "b2";
say $m.Str;
```
```output
List 3
｢2｣
(1 2)
2
Nil
3
1
```

## `.match` with a string searches for the text, and ignores `:i`
tags: quirk

A pattern that is not a Regex is turned into a string and searched for
literally: a dot is a dot, a list is its elements joined by spaces, a number
is its text, and the empty string matches at 0. A type object or Nil is
refused. `.match` accepts named arguments it does not know and ignores them,
`:i` among them; put the adverb inside the regex. A number as the invocant is
turned into a string, so `.orig` is a Str, where a smartmatch keeps the
number.

```raku
say "a.b".match(".").from;
say "1 2 3".match([1, 2, 3]).Str;
say "a1.5b".match(1.5).from;
say "abc".match("").raku;
say "abc".match(/B/, :i).raku;
say "abc".match(/:i B/).Str;
say 123.match(/2/).orig.^name;
say (123 ~~ /2/).orig.^name;
```
```output
1
1 2 3
1
Match.new(:orig("abc"), :from(0), :pos(0))
Nil
b
Str
Int
```

## `:g` returns a List, empty when nothing matches

`:g` (`:global`) returns every match that does not overlap the one before, as
a List, and sets `$/` to that List. When nothing matches the List is empty,
not Nil. A match of zero width moves the search on by one character, so a
pattern that can match nothing matches at every position, the end included.
A false value, `:!g` or `:g(0)`, asks for the single first match.

```raku
say "a1b2c3".match(/\d/, :g)».Str;
say "abc".match(/\d/, :g).raku;
"a1b2".match(/\d/, :g);
say $/.^name, " ", $/.elems;
"abc".match(/\d/, :g);
say $/.raku;
say "abc".match(/x*/, :g).map(*.from);
say "aaa".match(/a*/, :g).map(*.Str.raku);
say "abc".match(/\w/, :!g).raku;
```
```output
(1 2 3)
()
List 2
$( )
(0 1 2 3)
("aaa" "")
Match.new(:orig("abc"), :from(0), :pos(1))
```

## `:ov` finds one match per start position, `:ex` every match

`:ov` (`:overlap`) tries every start position and keeps the longest match at
each. `:ex` (`:exhaustive`) keeps every match at every position, all lengths
included. Both return a List, empty when nothing matches, and combine with
`:x` and `:nth`, which count in the list they produce.

```raku
say "aaa".match(/aa/, :g)».Str;
say "aaa".match(/aa/, :ov)».Str;
say "aaa".match(/a+/, :ov)».Str;
say "aaa".match(/a+/, :ex)».Str;
say "aaa".match(/a+/, :ex, :nth(2)).Str;
say "aaa".match(/a+/, :ov, :x(2))».Str;
```
```output
(aa)
(aa aa)
(aaa aa a)
(aaa aa a aa a a)
aa
(aaa aa)
```

## `:x` wants an exact count, and ignores a Range's excluded ends
tags: quirk

`:x(n)` returns the first *n* matches as a List, or an empty List when there
are fewer. A Range allows any count within it, taking as many as it can; `*`
and `Inf` take all, and a fraction is truncated. The excluded ends of a Range
are not excluded: `2^..^4` allows only 3, but takes 4.

```raku
my $s = "aaaa";
say $s.match(/a/, :x(2))».from;
say $s.match(/a/, :x(5)).raku;
say $s.match(/a/, :x(2..3))».from;
say $s.match(/a/, :x(5..6)).raku;
say $s.match(/a/, :x(2^..^4))».from;
say $s.match(/a/, :x(*)).elems;
say $s.match(/a/, :x(2.7)).elems;
```
```output
(0 1)
()
(0 1 2)
()
(0 1 2 3)
4
2
```

## An invalid `:x` is a Failure, and `:x(Nil)` dies
tags: bug

A count that is not a number or a Range, a numeric string included, makes
`.match` return a Failure of type `X::Str::Match::x`, as the documentation
says. Its `.got` holds the value, and `$/` is set to Nil. NaN dies at once.
Nil is neither a number nor a Range, so by the documentation it too gives a
Failure, and `:nth(Nil)` means no `:nth` at all. In Rakudo 2026.08 `:x(Nil)`
dies instead, with an arity error about a call made inside `.match`.

```raku
my $r = "aaaa".match(/a/, :x("2"));
say $r.^name, " ", $r.exception.^name, " ", $r.exception.got.raku;
say $/.raku;
try "aaaa".match(/a/, :x(NaN));
say $!.^name;
try "aaaa".match(/a/, :x(Nil));
say $!.message;
```
```output
Failure X::Str::Match::x "2"
Nil
X::AdHoc
Too many positionals passed; expected 3 arguments but got 4
```

## `:nth` counts from 1, from the end, or down a list
tags: quirk

`:nth(n)` returns the *n*th match, or Nil when there are fewer. It is also
written `:1st`, `:2nd`, `:3rd`, `:4th` and so on, or `:st(n)`, `:nd(n)`,
`:rd(n)`, `:th(n)`. `*` or `Inf` is the last match and `*-1` the one before
it; a block is called to get *n*; a fraction is truncated. A list or a Range
returns a List of the matches with those numbers, stopping quietly where the
matches run out. A string counts as a list of one, so `:nth("2")` returns a
List where `:nth(2)` returns a Match.

```raku
my $s = "abcd";
say $s.match(/./, :nth(2)).Str;
say $s.match(/./, :3rd).Str;
say $s.match(/./, :nth(5)).raku;
say $s.match(/./, :nth(*)).Str;
say $s.match(/./, :nth(*-1)).Str;
say $s.match(/./, :nth({ 2 })).Str;
say $s.match(/./, :nth(1, 3))».Str;
say $s.match(/./, :nth(2..*))».Str;
say $s.match(/./, :nth("2")).raku;
```
```output
b
c
Nil
d
c
b
(a c)
(b c d)
(Match.new(:orig("abcd"), :from(1), :pos(2)),)
```

With `:g` added, `:nth(2)` is still the single second match.

## `:nth` refuses 0 and a list that does not increase

Match numbers start at 1, so 0 and negative numbers die with `X::AdHoc`, and
so does a Range that starts at 0. A list of numbers must increase. That rule
is checked only when the result is read, so the call returns a List and the
error comes later:

```raku
my $s = "abcd";
try $s.match(/./, :nth(0));
say $!.message;
try $s.match(/./, :nth(-1));
say $!.message;
my $r = $s.match(/./, :nth(3, 1));
say $r.^name;
try $r.elems;
say $!.message;
```
```output
Attempt to retrieve before :1st match -- :nth(0)
Attempt to retrieve before :1st match -- :nth(-1)
List
Attempt to fetch match #1 after #3
```

## `:nth(2), :x(1)` answers an empty list
tags: bug

`:x` on top of a list or Range of `:nth` numbers checks that exactly that
many of them exist and returns them; a list of one number, `:nth((2,))`,
with `:x(1)` returns that one match. With a single `:nth` number, Rakudo
2026.08 returns an empty List, although the match exists and the
documentation describes `:x` as the number of matches to return:

```raku
my $s = "abcd";
say $s.match(/./, :nth(2)).Str;
say $s.match(/./, :nth(2..3), :x(1))».Str;
say $s.match(/./, :nth(2..3), :x(2))».Str;
say $s.match(/./, :nth(2), :x(1)).raku;
```
```output
b
(b)
(b c)
()
```

## `:c` scans from a position, `:p` anchors there, and Nil swaps them
tags: quirk

`:c(n)` (`:continue`) starts the search at position *n*; `:p(n)` (`:pos`)
requires the match to start exactly there. A position at the end of the
string is allowed, for a pattern that can match there; past the end nothing
matches. Given both, `:p` wins, and both combine with `:g`. A negative
position has a corner of its own ([Strings](#ch:strings:match-with-a-negative-c-matches-before-the-start)).
Given Nil, the two trade places: `:c(Nil)` anchors at 0, and `:p(Nil)` scans
as if it were absent.

```raku
my $s = "aXbXc";
say $s.match(/X/, :c(2)).from;
say $s.match(/X/, :p(1)).from;
say $s.match(/X/, :p(2)).raku;
say $s.match(/X/, :c(2), :p(1)).from;
say $s.match(/X/, :c(2), :g).elems;
say "ab".match(/$/, :p(2)).from;
say "abc".match(/b/, :c(Nil)).raku;
say "abc".match(/b/, :p(Nil)).from;
```
```output
3
1
Nil
1
1
2
Nil
1
```

## `:as(Str)` returns the text, but not with `:c` or `:p`
tags: quirk undocumented

`:as(Str)` asks for the matched text instead of the Match: a Str, a List of
Strs with `:g`, Nil when nothing matched. Any other type means the Match.
Combined with `:c` or `:p`, `:as` is ignored and the Match comes back.

```raku
say "a1b2".match(/\d/, :as(Str)).raku;
say "a1b2".match(/\d/, :as(Str), :g).raku;
say "a1b2".match(/\d/, :as(Str), :nth(2)).raku;
say "abc".match(/\d/, :as(Str)).raku;
say "a1b2".match(/\d/, :as(Int)).^name;
say "a1b2".match(/\d/, :as(Str), :c(1)).^name;
```
```output
"1"
("1", "2")
"2"
Nil
Match
Match
```

## A replacement string is built before `subst` runs
tags: trap

The arguments of a method are evaluated before the call, and a replacement
string is an argument like any other. `"<$0>"` interpolates the `$0` of
whatever matched *before* the `subst`, once, and that text goes into every
match. A block is called for each match, with the new `$/` set ([Strings](#ch:strings:a-replacement-block-receives-the-match)).
The replacement part of `s///` is also evaluated for each match.

```raku
"x9" ~~ / (\d) /;
say "a1b2".subst(/ (\d) /, "<$0>", :g);
say "a1b2".subst(/ (\d) /, { "<$0>" }, :g);
my $s = "a1b2";
$s ~~ s:g/ (\d) /<$0>/;
say $s;
```
```output
a<9>b<9>
a<1>b<2>
a<1>b<2>
```

Without an earlier match, `$0` is Nil, and the string version replaces every
match with `<>` and warns.

## `s///` returns the Match, or False when nothing matched

`$str ~~ s/…/…/` changes the variable and returns the Match. When nothing
matches, the variable is left alone and the result is `False`, not Nil.
`s:g` returns the List of Matches, empty when there were none.

```raku
my $s = "a1b2";
my $r = ($s ~~ s/ \d /X/);
say $r.^name, " ", $s;
my $t = "abc";
say ($t ~~ s/ \d /X/).raku;
my $u = "a1b2";
say ($u ~~ s:g/ \d /X/).elems, " ", $u;
```
```output
Match aXb2
Bool::False
2 aXbX
```

## `S///` works on `$_`, and `~~ S///` is never useful
tags: trap

`S/…/…/` leaves its target alone and returns the new string. It works on
`$_`, so the way to give it another string is `given`. A smartmatch makes its
left side `$_` too, and so `$s ~~ S///` does compute the new string, but then
it smartmatches the old string against it: False when anything was replaced,
True when nothing was. The compiler warns about each one.

```raku
my $s = "a1b2";
my $new = S/ \d /X/ given $s;
say $new, " ", $s;
$_ = "a1b2";
say S:g/ \d /Z/;
say $_;
```
```output
aXb2 a1b2
aZbZ
a1b2
```

```raku
my $s = "a1b2";
say $s ~~ S/ \d /X/;
say "abc" ~~ S/ x /y/;
say $s;
```
```output
False
True
a1b2
```
```stderr
Potential difficulties:
    Smartmatch with S/// is not useful. You can use given instead: S/// given $foo
    at example.raku:2
    ------> say $s ~~ <HERE>S/ \d /X/;
    Smartmatch with S/// is not useful. You can use given instead: S/// given $foo
    at example.raku:3
    ------> say "abc" ~~ <HERE>S/ x /y/;
```

## The replacement of `s///` is code, and some adverbs are refused

The replacement part of `s///` is a double-quoted string evaluated for each
match: `$0`, `{ … }` and method calls such as `$/.from()` interpolate. The
form `s[…] = …` takes an expression instead. The target must be a variable
that can be assigned: a literal is refused. `:ov` and `:ex`, which could give
overlapping matches, are refused at compile time.

```raku
my $s = "a1b2";
$s ~~ s:g[ \d ] = $/ * 10;
say $s;
my $t = "abc";
$t ~~ s/ b /$/.from()/;
say $t;
try { "abc" ~~ s/ b /x/ };
say $!.^name;
```
```output
a10b20
a1c
X::Assignment::RO
```

```raku
my $t = "abc";
$t ~~ s:ov/ b /x/;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Adverb ov not allowed on substitution
at example.raku:2
------> $t ~~ s:ov/ b /x/<HERE>;
```

## `index` and its relatives refuse a regex; `substr` dies trying
tags: quirk

`index`, `rindex`, `indices`, `starts-with` and `ends-with` have no form that
takes a regex, and refuse one with `X::Multi::NoMatch`. `contains` accepts a
regex ([Strings](#ch:strings:contains-pos-cannot-match-at-the-end)). In
Rakudo 2026.08 `substr` takes the regex for code that computes a position,
calls it with a number, and dies with a message that names `!cursor_start`,
a private method of the regex engine:

```raku
for "index", "starts-with", "ends-with" -> $method {
    try "abc"."$method"(/b/);
    say "$method: ", $!.^name;
}
try "abc".substr(/b/, 1);
say $!.^name;
say $!.message;
```
```output
index: X::Multi::NoMatch
starts-with: X::Multi::NoMatch
ends-with: X::Multi::NoMatch
X::Method::NotFound
No such method '!cursor_start' for invocant of type 'Int'. Did you try
to call a token / rule / regex directly?
```

## `trans` pairs a list of regexes, and skips the Regex type object

With regexes as keys, `trans` replaces each whole match
([Strings](#ch:strings:trans-replaces-a-regex-keys-whole-match-or-calls-code)).
A list of regexes pairs with a list of replacements, element by element.
`:d`, which deletes characters without a partner, changes nothing for a regex
key: each match is replaced as without it. The Regex type object as a key is
skipped without a word.

```raku
say "a1b2".trans([/\d/, /a/] => ["#", "A"]);
say "a11b2".trans(/\d/ => "#", :d);
say "a1b2".trans((Regex) => "x");
```
```output
A#b#
a##b#
a1b2
```

## `parse` must reach the end, and returns the grammar's own type

`G.parse($text)` runs the rule `TOP` from the start of the text and succeeds
only when the match reaches the end. Otherwise it returns Nil, and sets `$/`
to Nil; on success `$/` holds the result too. The result is an object of the
grammar's own class, which inherits from Grammar and Match.

```raku
grammar G { token TOP { a+ } }
my $m = G.parse("aaa");
say $m.^name, " ", $m ~~ Match;
say G.^mro.map(*.^name);
say G.parse("aab").raku;
say $/.raku;
```
```output
G True
(G Grammar Match Capture Cool Any Mu)
Nil
Nil
```

## A grammar without `TOP` cannot parse, and neither can `Grammar`
tags: undocumented unasserted

A grammar that declares no `TOP` dies when asked to parse, with the method
lookup's suggestion of a similar name. `Grammar` itself dies with an error
from the object system. An instance made with `.new` is an empty, successful
Match.

```raku
grammar Empty {}
try Empty.parse("x");
say $!.message;
try Grammar.parse("x");
say $!.message;
grammar G { token TOP { x } }
say G.new.raku;
```
```output
No such method 'TOP' for invocant of type 'Empty'. Did you mean 'to'?
P6opaque: no such attribute '%!hash' on type Capture in a Grammar when trying to bind a value
Match.new(:orig(""), :from(0), :pos(0))
```

## A failed `subparse` is a Match whose `.to` is -3
tags: quirk

`subparse` does not require the match to reach the end, and it never returns
Nil. When `TOP` fails, it returns a failed Match: false, with the gist
`#<failed match>` and an empty text, and with `.to` and `.pos` negative. The
number means nothing in itself; test the Match's truth, never its position.
`$/` is set to the failed Match, so it is false but not Nil.

```raku
grammar G { token TOP { a+ } }
say G.subparse("aab").Str;
my $failed = G.subparse("bbb");
say $failed.Bool, " ", $failed.gist;
say $failed.to, " ", $failed.pos;
say $failed.raku;
say $/.^name, " ", $/.Bool;
```
```output
aa
False #<failed match>
-3 -3
Match.new(:orig("bbb"), :from(0), :pos(-3))
G False
```

## `:rule`, `:args` and `:pos` choose where a parse starts

`:rule<name>` starts at another rule; the result is still of the grammar's
class. `:args` passes arguments to that rule, as a Capture or a list; a bare
string is refused, and a rule that takes arguments dies without them. `:pos`
starts at a position, and `parse` still has to reach the end. A rule that
does not exist dies.

```raku
grammar G {
    token TOP { a+ }
    token b { b+ }
    token rep($c) { $c+ }
}
say G.parse("bb", :rule<b>).^name;
say G.parse("ccc", :rule<rep>, :args(\("c"))).Str;
say G.parse("ccc", :rule<rep>, :args(("c",))).Str;
say G.parse("bbaa", :pos(2)).Str;
say G.parse("bbaa", :pos(2)).prematch;
try G.parse("x", :rule<nope>);
say $!.^name;
try G.parse("ccc", :rule<rep>);
say $!.^name;
try G.parse("ccc", :rule<rep>, :args("c"));
say $!.^name;
```
```output
G
ccc
ccc
aa
bb
X::Method::NotFound
X::AdHoc
X::Cannot::Capture
```

## A grammar parses any object, and `.orig` keeps it

The rules run against the object's string form, `.target`, while `.orig`
keeps the object itself, so a parsed Int stays an Int there. The result
numifies through the matched text. A number whose string form does not match
is refused like any other text. Type objects die, each with its own
exception.

```raku
grammar Digits { token TOP { \d+ } }
my $m = Digits.parse(123);
say $m.orig.^name, " ", $m.target.^name;
say $m.raku;
say Digits.parse(12.5).raku;
say Digits.parse(1e3).Str;
say Digits.parse(12) + 1;
for Any, Nil, Int -> \target {
    quietly try Digits.parse(target);
    say $!.^name;
}
```
```output
Int Str
Match.new(:orig(123), :from(0), :pos(3))
Nil
1000
13
X::Method::NotFound
X::AdHoc
X::Multi::NoMatch
```

## `parsefile` reads the file and hands the rest to `parse`

`parsefile` takes a path, as a string or an `IO::Path`, reads the whole file,
trailing newline included, and parses the text. Named arguments such as
`:rule`, `:actions` and `:pos` go through to `parse`, and `$/` is set. A
missing file dies.

```raku local
grammar Words { token TOP { \w+ \n? } }
"words.txt".IO.spurt("hello\n");
say Words.parsefile("words.txt").Str.raku;
say Words.parsefile("words.txt".IO, :rule<TOP>).orig.raku;
say $/.^name;
unlink "words.txt";
try Words.parsefile("missing.txt");
say $!.^name;
```
```output
"hello\n"
"hello\n"
Words
X::AdHoc
```

## `parse` retries `TOP` only if `TOP` can backtrack
tags: trap unasserted

When `TOP` matches without reaching the end, `parse` asks it for another way
to match before it gives up. A `regex TOP` can find one: `a || aa` first
matches `a`, and the retry takes `aa`. A `token TOP` does not backtrack, so the
same body fails. `|` finds `aa` in a token because it tries the longest branch
first. `subparse` never retries.

```raku
grammar R { regex TOP { a || aa } }
grammar T { token TOP { a || aa } }
grammar L { token TOP { a | aa } }
say R.parse("aa").Str;
say T.parse("aa").raku;
say L.parse("aa").Str;
say R.subparse("aa").Str;
```
```output
aa
Nil
aa
a
```

## Named arguments to `parse` set attributes the result forgets
tags: quirk unasserted

A grammar may declare attributes, and named arguments to `parse` initialise
them for that parse: a rule sees them through `self`. The attributes of an
object made with `.new` are not used by `parse`. And the Match that `parse`
returns, although it is of the grammar's class, has the attributes undefined.

```raku
grammar Limited {
    has $.limit = 0;
    token TOP { \d+ <?{ $/.Int <= self.limit }> }
}
say Limited.parse("42", :limit(50)).Str;
say Limited.parse("42", :limit(10)).raku;
say Limited.new(:limit(50)).parse("42").raku;
say Limited.parse("42", :limit(50)).limit.raku;
say Limited.parse("42", :limit(50), :nope(1)).Str;
```
```output
42
Nil
Nil
Any
42
```

The last line shows that a named argument that matches no attribute is
ignored.

## A rule is a method that runs on a Match
tags: undocumented unasserted

Every `token`, `rule` and `regex` of a grammar is a method of type Regex. Called
on the type object, or with an argument, it dies. Called on an instance made
with `.new(:orig(…))`, and optionally `:pos(…)`, it matches at that position,
without having to reach the end, and returns a Match of the grammar's class.

```raku
grammar G { token TOP { a+ }; token b { b } }
say G.^find_method("TOP").^name;
say G.^find_method("TOP").signature.raku;
my $m = G.new(:orig("aaab")).TOP;
say $m.Str, " ", $m.^name, " ", $m.pos;
say G.new(:orig("xb"), :pos(1)).b.Str;
say G.new(:orig("baa")).TOP.Bool;
try G.TOP("aaa");
say $!.^name;
```
```output
Regex
:(G $:: *%_)
aaa G 3
b
False
X::AdHoc
```

## A subgrammar overrides rules by name, and `<ws>` captures

`grammar B is A` inherits every rule of `A` and replaces the ones it
declares, so an inherited `TOP` calls the new `x`. The result is a B, and a
B is an A. A qualified call, `<.A::x>`, reaches the parent's rule.

```raku
grammar A { token TOP { <x> <y> }; token x { a }; token y { b } }
grammar B is A { token x { c } }
say B.parse("cb").Str;
say B.parse("ab").raku;
say B.parse("cb") ~~ A;
grammar J is A { token x { c | <.A::x> } }
say J.parse("ab").Str, " ", J.parse("cb").Str;
```
```output
cb
Nil
True
ab cb
```

`<ws>` is a rule like any other: written without the dot it is a named
capture, and two calls give an Array.

```raku
grammar S { token TOP { <ws> a <ws> b } }
my $m = S.parse(" a b");
say $m<ws>.elems, " ", $m<ws>[0].Str.raku;
grammar Q { token TOP { <.ws> a <.ws> b } }
say Q.parse(" a b").keys;
```
```output
2 " "
()
```

## An actions object is called after each named rule succeeds

`:actions` takes a class or an instance. Each time a named rule succeeds, the
method of the same name is called with the rule's Match as its one argument;
a rule without a method is skipped. `make` in the method attaches a payload,
which a later action reads with `.made`; `TOP` finishes last. `:rule` calls
only the actions of the rules it runs, and `$/` gets the payload too.

```raku
grammar Sum {
    token TOP { <num> '+' <num> }
    token num { \d+ }
}
class Calc {
    method TOP($/) { make $<num>[0].made + $<num>[1].made }
    method num($/) { make +$/ }
}
say Sum.parse("2+3", :actions(Calc)).made;
say Sum.parse("2+3").made.raku;
say Sum.parse("42", :actions(Calc), :rule<num>).made;
Sum.parse("4+5", :actions(Calc));
say $/.made;
```
```output
5
Nil
42
9
```

A method must accept the Match; one without a positional parameter dies when
it is called:

```raku
grammar G { token TOP { <a> }; token a { a } }
try G.parse("a", :actions(class { method a { make 1 } }));
say $!.message;
```
```output
Too many positionals passed; expected 1 argument but got 2
```

## `.actions` of a parse without actions is not a Raku object
tags: bug

`.actions` on the result returns the actions object that was given. Without
one it is documented to return `Mu`, but it returns an object of the
compiler's own `NQPMu` type, which has no `.gist`, so printing it dies
(Rakudo 2026.08):

```raku
grammar G { token TOP { a } }
say G.parse("a", :actions(class Acts { })).actions.^name;
say G.parse("a").actions.^name;
say G.parse("a").actions;
```
```output
Acts
NQPMu
```
```stderr
Method NQPMu.gist not found
  in block <unit> at example.raku line 4

```

## An action's `make` replaces the one in the rule's body

A rule may `make` in a code block of its own, during the match. The action
method runs after the rule, and its `make` overrides the body's. An action
method that makes nothing leaves the body's payload in place.

```raku
grammar G { token TOP { a { make "body" } } }
say G.parse("a").made;
say G.parse("a", :actions(class { method TOP($/) { make "action" } })).made;
say G.parse("a", :actions(class { method TOP($/) { } })).made;
```
```output
body
action
body
```

## The action is named after the rule, not the alias

An action fires whenever a named rule completes, whether its call captures or
not. `<.a>` fires `a`; so does `<b=.a>`, which stores its Match under `b` but
calls no `b` method. A call inside a lookahead fires too, so a rule that is
looked at and then matched fires twice. `TOP` fires last.

```raku
my @fired;
grammar G {
    token TOP { <.a> <b=.a> <c> <?before <d>> <d> }
    token a { a }
    token c { c }
    token d { d }
}
class A {
    method a($/)   { @fired.push: "a" }
    method b($/)   { @fired.push: "b" }
    method c($/)   { @fired.push: "c" }
    method d($/)   { @fired.push: "d" }
    method TOP($/) { @fired.push: "TOP" }
}
my $m = G.parse("aacd", :actions(A));
say @fired;
say $m.keys.sort;
```
```output
[a a c d d TOP]
(b c d)
```

A lexical regex called as `<&e>` fires the action `e`, although it captures
nothing; aliased as `<e2=&e>` it still fires `e`:

```raku
my @fired;
my regex e { e }
grammar H { token TOP { <&e> <e2=&e> } }
my $m = H.parse("ee", :actions(class {
    method e($/)  { @fired.push: "e" }
    method e2($/) { @fired.push: "e2" }
}));
say @fired;
say $m.keys;
```
```output
[e e]
(e2)
```

## A proto token takes the longest candidate, whose action fires

A `proto token op {*}` dispatches to its candidates `op:sym<…>` by
longest-token matching, declaration order breaking a tie. `<sym>` in a
candidate captures its symbol. The action that fires is the candidate's,
`op:sym<++>`, never the proto's `op`. A quantified `<op>+` gives an Array.

```raku
my @fired;
grammar G {
    token TOP { <op>+ }
    proto token op {*}
    token op:sym<+>  { <sym> }
    token op:sym<++> { <sym> }
    token op:sym<a>  { a }
    token op:sym<b>  { 'a' }
}
class A {
    method op($/)         { @fired.push: "op" }
    method op:sym<+>($/)  { @fired.push: "+" }
    method op:sym<++>($/) { @fired.push: "++" }
    method op:sym<a>($/)  { @fired.push: "a" }
    method op:sym<b>($/)  { @fired.push: "b" }
}
my $m = G.parse("++a", :actions(A));
say @fired;
say $m<op>.^name, " ", $m<op>.elems;
say $m<op>[0]<sym>.Str;
say $m<op>[1].keys;
```
```output
[++ a]
Array 2
++
()
```

`op:sym<a>` and `op:sym<b>` both match `a`, and the first declared wins. A
candidate that fails after its longest prefix gives way to the next one, and
a single candidate can be the start rule, by its full name:

```raku
grammar J {
    token TOP { <op> }
    proto token op {*}
    token op:sym<x> { x <?{ False }> }
    token op:sym<y> { x }
    token op:sym<+> { <sym> }
}
say J.parse("x")<op>.Str;
say J.parse("+", :rule("op:sym<+>")).Str;
say J.^methods.map(*.name).grep(*.starts-with("op")).sort;
```
```output
x
+
(op op:sym<+> op:sym<x> op:sym<y>)
```

## Actions fire for branches that are later abandoned
tags: undocumented unasserted

An action runs as soon as its rule succeeds, and nothing takes it back when
the rule around it fails afterwards. A parse that returns Nil may have called
actions; `||` fires a subrule once for each branch that called it; `|` fires
only for the branch it chose.

```raku
my @fired;
class A {
    method a($/)   { @fired.push: "a" }
    method TOP($/) { @fired.push: "TOP" }
}
grammar G { token TOP { <a> b }; token a { a } }
say G.parse("ac", :actions(A)).raku;
say @fired;
@fired = ();
grammar I { token TOP { <a> x || <a> y }; token a { a } }
I.parse("ay", :actions(A));
say @fired;
@fired = ();
grammar K { token TOP { <a> x | <a> y }; token a { a } }
K.parse("ay", :actions(A));
say @fired;
```
```output
Nil
[a]
[a a TOP]
[a TOP]
```

An exception thrown in an action method comes out of `parse` as it is:

```raku
grammar G { token TOP { <a> b }; token a { a } }
try G.parse("ab", :actions(class { method a($/) { die "boom" } }));
say $!.^name, ": ", $!.message;
```
```output
X::AdHoc: boom
```
