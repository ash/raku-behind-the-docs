---
title: Whitespace, Terms and Blocks
part: Reading the code
summary: Where a space, a newline or a brace changes what the parser sees, from subscripts that must touch their term to blocks that turn out to be hashes.
---

In most languages spaces can go wherever they read well. In Raku they
cannot, because Raku uses whitespace to tell apart things that look alike.
After a term, `[` touching the term is a subscript and `[` after a space is
an operator; `f(1)` and `f (1)` pass different arguments; a `}` at the end
of a line ends the statement. A few rules explain most of it: a postfix
must touch its term, a term followed by whitespace expects an infix
operator, and a closing brace followed by a newline behaves like a
semicolon.

This chapter goes through those rules, then through the smaller decisions the
parser makes at the level of single tokens: which braces are hashes, which
words are identifiers, what a colonpair may contain, where comments and Pod
begin, and what counts as a number.

## `{ … }` is a Hash only when it looks like one

A pair of braces in term position is either a Block or a hash composer. The
compiler decides by looking inside: empty braces are a Hash, and so are
braces holding a single comma list whose first element is a pair or a `%`
variable. Anything else is a Block.

```raku
my %opts = x => 1;
say {}.^name;
say { a => 1, b => 2 }.^name;
say { :a(1), :b(2) }.^name;
say { %opts, b => 2 }.^name;
say { a => 1; }.^name;
say { "a", 1 }.^name;
say { (a => 1), (b => 2) }.^name;
```
```output
Hash
Hash
Hash
Hash
Hash
Block
Block
```

A trailing semicolon does not change the verdict, but a first element of
any other kind does: `"a", 1` is a list of two strings, and a
parenthesised pair is a parenthesised expression. Using the topic `$_` or a
placeholder variable anywhere inside, or adding a second statement, makes
the braces a Block even when they start with a pair. `%( … )` always builds
a Hash.

```raku
say { 3 => 4, :b($_) }.^name;
say { a => $^x }.^name;
say { say "hi"; a => 1 }.^name;
say %( 3 => 4, :b($_) ).^name;
say %().^name;
```
```output
Block
Block
Block
Hash
Hash
```

The third Block is never called, so nothing says "hi".

## A block that only returns a pair is a Hash, so `map` refuses it
tags: trap

The rule of the previous corner applies to the argument of `map` too. A
block meant to return a constant pair is a hash composer, and
`map` receives a Hash instead of code:

```raku
say (1..2).map({ "k" => 1 }).raku;
```
```output
```
```stderr
Cannot map a Range using a Hash
Did you mean to add a stub ({ ... }) or did you mean to .classify?
  in block <unit> at example.raku line 1

```

A block that mentions `$_` is a Block. When the pair does not need the
topic, a semicolon straight after the opening brace forces a Block; when
each element should become a hash, say so with `%( … )`:

```raku
say (1..2).map({ "k$_" => 1 }).raku;
say (1..2).map({; "k" => 1 }).raku;
say (1..2).map({ %( k => $_ ) }).raku;
```
```output
(:k1(1), :k2(1)).Seq
(:k(1), :k(1)).Seq
({:k(1)}, {:k(2)}).Seq
```

## A brace that touches a term is a subscript
tags: trap

`{` directly after a term opens a hash subscript, whatever the term is. A
condition written without a space before its block therefore swallows the
block as a subscript, and the statement is left without one:

```raku
my $x = 1;
if ($x){ say "yes" }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Missing block (whitespace needed before curlies taken as a hash subscript?)
at example.raku:3
------> <BOL><HERE><EOL>
    expecting any of:
        block or pointy block
```

`($x){ … }` subscripts the parenthesised value, so the compiler reads to the
end of the file looking for the block of the `if`. The same happens with
`if $x{`, `for @a{` and `when 'x'{`: a string literal takes a subscript as
readily as a variable. After the parameter of a pointy block, `-> $i{` is
read as a shape declaration, and the compiler reports that shapes are not
implemented. Where no term precedes the brace, as in `sub f(){ … }` or
`else{ … }`, no space is needed.

## A `}` that ends a line ends the statement
tags: trap

A closing brace followed by a newline terminates the statement, as if a
semicolon stood there. This is what lets a block-shaped statement such as
`if` or `sub` go without a `;`, but it applies to every brace, including
the end of a `do` block or a hash composer on the right of an assignment.
An operator on the next line then starts a new statement:

```raku
my $x = do { 1 }
    + 2;
say $x;
my $h = { a => 1, b => 2 }
    .keys.sort;
say $h.^name;
```
```output
1
Hash
```
```stderr
WARNINGS for example.raku:
Useless use of "+ " in expression "+ 2" in sink context (line 2)
```

`+ 2` becomes a statement of its own, and the compiler warns that its value
is thrown away. `.keys.sort` becomes a method call on `$_`, and nothing
warns: `$h` holds the Hash, not its sorted keys. A comment after the brace
does not help; the statement still ends at the newline. Keep the operator
on the brace's line, or end the line with an unspace, `}\`.

## Inside brackets, a line-ending `}` separates elements like `;`
tags: trap

Parentheses and square brackets hold statements, and a semicolon between
statements makes each one an element. A `}` at the end of a line counts as
that semicolon, so a list of hashes written one per line needs no commas,
and an operator at the start of a line starts a new element:

```raku
say [ { a => 1 }; { b => 2 } ].raku;
say [
    { a => 1 }
    { b => 2 }
].raku;
say (
    { a => 1 }
    + 0
).raku;
```
```output
[{:a(1)}, {:b(2)}]
[{:a(1)}, {:b(2)}]
({:a(1)}, 0)
```

A comma at the start of the next line, as in `({ a => 1 }` newline
`, 2)`, is not a way out: a statement cannot begin with a comma, and the
compiler reports a bogus statement.

## A keyword touching `(` is a function call
tags: trap quirk

`if`, `unless`, `while`, `until`, `for`, `loop`, `given`, `when`, `with`
and `without` are keywords only when no `(` follows them directly. With the
parenthesis touching, each one is read as a call to a sub of that name, and
the compiler refuses with two messages:

```raku
my $x = 1;
if($x) { say "yes" }
```
```output
```
```stderr
===SORRY!===
The word 'if' is interpreted as a 'if()' function call. Please use
whitespace instead of parentheses.
at example.raku:2
------> if<HERE>($x) { say "yes" }
Unexpected block in infix position (two terms in a row)
at example.raku:2
------> if($x)<HERE> { say "yes" }

```

For `loop(` the advice reads "whitespace around the parentheses", since the
parentheses of a C-style loop are required. The statement modifier form,
`say "yes" if($x)`, fails with a plain "Missing semicolon". The words that
continue an `if` or `with` chain are not checked at all:

```raku
my $x = 0;
if $x { say "if" } elsif($x == 0) { say "elsif with parentheses" }
```
```output
elsif with parentheses
```

## A space after a sub's name moves the parentheses into the argument
tags: trap

`f(…)` with the parenthesis touching the name is a call whose argument list
is inside the parentheses. `f (…)` with a space is a call without
parentheses, and `(…)` is only the start of its first argument. Everything
after it, up to the end of the list, joins in:

```raku
say sqrt(16) + 9;
say sqrt (16) + 9;
sub f(|c) { "f" ~ c.list.raku }
say f(1), 2;
say f (1), 2;
say f (1, 2);
say f [1, 2];
```
```output
13
5
f(1,)2
f(1, 2)
f((1, 2),)
f([1, 2],)
```

`sqrt (16) + 9` is the square root of 25. `f (1), 2` passes two arguments,
while `f (1, 2)` passes one: a list. `f [1, 2]` passes an Array; with a sub
that takes no arguments it fails at run time with "Too many positionals
passed".

## Parentheses touching the name end the call

The other side of the same rule: once `say(…)` has its parentheses, the
call is complete, and what follows applies to its result. A method call
after it goes to the value `say` returned, and a second parenthesised
group is a term with no operator before it:

```raku
say (1, 2).elems;
say(1, 2).elems;
```
```output
2
12
```

The second line prints `12`, the two arguments joined, and then asks
`True`, the value of `say`, for its number of elements.

```raku
say(1) (2);
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Two terms in a row
at example.raku:1
------> say(1)<HERE> (2);
    expecting any of:
        infix
        infix stopper
        statement end
        statement modifier
        statement modifier loop
```

A subscript touching the name also ends the call: `f[1]` calls `f` with no
arguments and indexes the result, which for a sub that requires one
argument is the compile-time error "Calling f() will never work".

## A sub called without parentheses takes the whole comma list

A sub name followed by a space is a *list operator*: its arguments run to
the end of the comma list, which is usually the end of the statement. Inside
a `say`, a named function without parentheses therefore takes every
argument after it. When the sub's signature cannot accept that many, the
compiler notices before the program runs:

```raku
say sqrt 4, 9;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Calling sqrt(Int, Int) will never work with signature of the proto ($, *%)
at example.raku:1
------> say <HERE>sqrt 4, 9;
```

A sub that accepts any number of arguments shows where the list ends:

```raku
sub f(|c) { "f" ~ c.list.raku }
say f 1, 2;
say (f 1), 2;
say f 1 ~ "!";
```
```output
f(1, 2)
f(1,)2
f("1!",)
```

Each argument is a whole expression, so `1 ~ "!"` is concatenated before
`f` sees it. The same looseness is behind two corners of the precedence
chapter: [a reduction takes everything to its
right](#ch:precedence:a-reduction-takes-everything-to-its-right), and
[`say 0 or …` prints 0](#ch:precedence:say-0-or-prints-0-the-word-operators-are-looser-than-a-list-call).

## A postfix must touch its term

Subscripts, argument lists and method calls are postfixes, and a postfix is
recognised only directly after its term. Separated by a space, `.<a>` is
not a method call, and the compiler says which detached forms it allows:

```raku
my %h = a => 1;
say %h .<a>;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Malformed postfix call (only basic method calls that exclusively use a dot can be detached)
at example.raku:2
------> say %h .<HERE><a>;
```

A "basic method call" is `.name`, which with a space before the dot is the
[dotty infix of the precedence
chapter](#ch:precedence:a-space-before-the-dot-turns-a-method-call-into-a-different-operator).
A bracket after a space is worse off. After a term the parser expects an
infix, and `[` in that position opens a bracketed infix such as `[+]` in
`1 [+] 2`:

```raku
my @a = 10, 20;
say @a [0];
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Missing infix inside []
at example.raku:2
------> say @a [<HERE>0];
    expecting any of:
        bracketed infix
        infix
        infix stopper
```

## A backslash unspace lets a postfix stand apart

A backslash followed by whitespace is an *unspace*: the parser skips it and
the whitespace as if neither were there. It may span lines and include
comments, so it can move a postfix onto the next line. A dot is also
allowed before any subscript, and a space is allowed after the dot of a
method call.

```raku
my @a = 10, 20;
my %h = a => 1;
say @a\ [1];
say %h\ .<a>;
say "abc"\   # a comment inside the unspace
    .uc;
say @a.[0..1];
say %h.{"a"};
say "abc". uc;
```
```output
20
1
ABC
(10 20)
1
ABC
```

The unspace works for argument lists too: `f\ (1), 2` calls `f` with the
single argument 1, exactly like `f(1), 2`.

## A line that starts with a dot continues at dotty-infix precedence
tags: trap

A method chain can be continued on the next line by starting the line with
`.method`. That works because a dot after whitespace is the dotty infix,
and like any infix it has a precedence: tighter than `..`, looser than a
postfix. On a parenthesised term it chains as expected; on a bare range it
binds to the endpoint:

```raku
my @r = (1..5)
    .grep(* > 2)
    .map(* * 10);
say @r;
my @s = 1..5
    .map(* * 10);
say @s;
```
```output
[30 40 50]
```
```stderr
Seq objects are not valid endpoints for Ranges
  in block <unit> at example.raku line 5

```

The second statement is `1 .. (5.map(* * 10))`, and a Seq cannot end a
range. Parenthesise the term the chain starts from.

## `.&` calls any sub as if it were a method

A postfix `.&name` calls the sub `&name` with the term as its first
argument. It sits on the method-postfix level, so it chains with real
method calls and can take further arguments; the sub can also be an
anonymous block.

```raku
sub double($n) { $n * 2 }
sub join-with($a, $sep, $b) { "$a$sep$b" }
say 5.&double;
say 5.&double.&double;
say "a".&join-with("-", "b");
say (1, 2, 3).map(*.&double);
say 4.&({ $_ + 1 });
```
```output
10
20
a-b
(2 4 6)
5
```

## `++` needs a container, and a method call returns a value

Postfix `++` is on the level just below the method postfixes, so
`$x.abs++` increments the result of `.abs`. That result is a plain value,
and the error is not the "cannot modify" of an assignment but a failed
dispatch: every candidate of `postfix:<++>` wants a writable argument.

```raku
my $x = -3;
try { $x.abs++ };
say $!.^name;
try { $x.abs = 5 };
say $!.^name;
$x++;
say $x;
```
```output
X::Multi::NoMatch
X::Assignment::RO
-2
```

## Spacing does not group operands
tags: trap

Whitespace around an infix operator is decoration. It cannot make an
operator bind tighter or looser, however strongly the layout suggests it:

```raku
say 1+2 * 3;
my $s = 1 ... 3;
say $s;
```
```output
7
1
```
```stderr
Potential difficulties:
    Useless use of ... in sink context
    at example.raku:2
    ------> my $s = 1 ...<HERE> 3;
```

`my $s = 1 ... 3` is `(my $s = 1) ... 3`, because item assignment is
tighter than the sequence operator, and the compiler warns that the
sequence is thrown away. Likewise `1 .. 5 xx 2` is `1 .. (5 xx 2)` and dies
because a Seq is not a valid range endpoint. The levels are in [the
precedence chapter](#ch:precedence).

## A hyphen or apostrophe joins an identifier only before a letter
tags: trap

Identifiers may contain `-` and `'`, as long as each is followed by a
letter. `$a-b` is therefore one variable, not a subtraction, while `$a-1`
and `$a-$b` subtract, because a digit or a sigil cannot continue a name.

```raku
my $a = 10;
my $b = 3;
my $a-b = "one variable";
say $a-b;
say $a - $b;
say $a-1;
my $don't = "fine";
say $don't;
```
```output
one variable
7
9
fine
```

A subtraction of a sub call from a variable runs into this rule. The
compiler reads one name and does not find it:

```raku
my $i = 10;
sub n { 3 }
say $i-n;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Variable '$i-n' is not declared. Perhaps you forgot a 'sub' if this was
intended to be part of a signature?
at example.raku:3
------> say <HERE>$i-n;
```

## A `<` touching a term opens a subscript
tags: trap

`<` directly after a term is the start of a `< >` subscript, and after a
space it is the less-than operator. In term position it starts a word
quote. The parser settles the question by the space alone:

```raku
my $x = 3;
say $x < 5;
say $x <5;
say <a b>;
```
```output
True
True
(a b)
```

When the `<` touches the term, the parser looks for the closing `>` of the
subscript. If there is none it asks for whitespace ("Whitespace required
before < operator"); if there is one later on the line, it takes
everything in between as the subscript's words:

```raku
my ($x, $y) = 3, 4;
say $x<5 && $y>2;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Two terms in a row
at example.raku:2
------> say $x<5 && $y><HERE>2;
    expecting any of:
        infix
        infix stopper
        postfix
        statement end
        statement modifier
        statement modifier loop
```

`$x<5 && $y>` is `$x{"5", "&&", '$y'}`, and the `2` after it has no
operator.

## A sub named after a type, even `X`, needs its `&`
tags: trap

A name followed by `(` is a call, unless the name is a type: then it is a
coercion. `X` is a type, the package that holds the exception classes such
as `X::AdHoc`, so a helper sub called `X` is never reached that way:

```raku
sub X($a) { "my X got $a" }
say X(1);
```
```output
```
```stderr
Impossible coercion from 'Int' into 'X': no acceptable coercion method found
  in block <unit> at example.raku line 2

```

Without parentheses, `X 1` is two terms in a row. The sub still exists as
`&X`, and the same holds for a sub named after any other type:

```raku
sub X($a) { "my X got $a" }
sub Int($a) { "my Int got $a" }
say &X(1);
say Int("42").raku;
say &Int("42");
say (1, 2) X (3, 4);
```
```output
my X got 1
42
my Int got 42
((1 3) (1 4) (2 3) (2 4))
```

`X` is the only single capital letter with this problem. Subs named `Z` or
`R` do not clash with the metaoperators, which need an operator right after
the letter, and the cross operator `X` keeps working between two lists.

## `=>` quotes the word on its left only on the same line
tags: trap

The fat arrow turns an identifier on its left into a string key. It looks
for that identifier across spaces and tabs only. Across a newline, or a
comment, or an unspace, the word is an ordinary name, here a call to a sub
`a` that would take `=> 1` as its argument:

```raku
my %h = a
    => 1;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Preceding context expects a term, but found infix => instead.
at example.raku:2
------>     =><HERE> 1;
```

A quoted key, `'a'` newline `=> 1`, is a string already and may be
followed by the arrow on the next line.

## A colonpair's number must be a plain integer
tags: quirk

`:3days` is the pair `days => 3`, a form meant for adverbs such as
`:2nd`. The number must be an unsigned integer made of digits. `:2<101>`
is not a pair at all but a number in base 2, and an underscore after the
digits starts the key:

```raku
say (:3days).raku;
say (:0days).raku;
say :2<101>;
say (:1_000days).raku;
```
```output
:days(3)
:days(0)
5
:_000days(1)
```

`:1_000days` is the pair `_000days => 1`: an underscore may begin an
identifier, and the digits stop before it. A decimal point sends the parser
to the radix form and fails there; a sign is not accepted at all
(`:-1day` is a "Bogus statement"):

```raku
say (:2.7days).raku;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Malformed radix number
at example.raku:1
------> say (:2<HERE>.7days).raku;
    expecting any of:
        number in radix notation
```

## A colonpair's value must touch its name

The value of a colonpair is a bracketed term directly after the name:
parentheses for an expression, angle brackets for words, square brackets
for an Array and braces for a Hash or a Block, decided as in [the first
corner](#ch:whitespace:is-a-hash-only-when-it-looks-like-one).

```raku
say (:foo(1)).raku;
say (:foo<bar>).raku;
say (:foo[1, 2]).raku;
say (:foo{ a => 1 }).raku;
say (:foo{ $_ * 2 }).value.^name;
```
```output
:foo(1)
:foo("bar")
:foo([1, 2])
:foo({:a(1)})
Block
```

With a space, `:foo` is complete on its own, the pair `foo => True`, and
the value becomes a second term:

```raku
say (:foo 1).raku;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Two terms in a row
at example.raku:1
------> say (:foo<HERE> 1).raku;
    expecting any of:
        infix
        infix stopper
        statement end
        statement modifier
        statement modifier loop
```

`:foo (1)` fails the same way.

## `#` starts a comment outside quotes; `` #` `` and a bracket embed one

A `#` outside any quote comments out the rest of the line. Inside a string
or a word quote it is an ordinary character. `#` followed by a backtick and
an opening bracket starts an *embedded* comment, which ends at the matching
closing bracket, may span lines, and can sit in the middle of an
expression. Doubled brackets let the comment contain single ones.

```raku
say "a # not a comment";
say 1 #`( an embedded comment ) + 2;
say 3 #`{{ doubled { braces } inside }} + 4;
say 5 #`[
    spans lines
] + 6;
say <x #y z>;
```
```output
a # not a comment
3
7
11
(x #y z)
```

A backtick that is not followed by a bracket is an error rather than a line
comment, while `#(` and `` # `( `` with a space are ordinary line comments:

```raku
say 1; #`not a bracket
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Opening bracket required for #` comment
at example.raku:1
------> say 1; #`<HERE>not a bracket
```

## `#|` and `#=` attach documentation to a declaration

`#|` before a declaration and `#=` after it are *declarator comments*: the
text is kept and returned by `.WHY` on the declared object. `#|(` with a
bracket spans lines, and the lines are joined with single spaces.

```raku
#| Adds one.
sub inc($x) { $x + 1 }
sub dec($x) { $x - 1 }  #= Subtracts one.
#|( Doubles,
    across two lines. )
sub double($x) { $x * 2 }
say &inc.WHY;
say &dec.WHY;
say &double.WHY;
```
```output
Adds one.
Subtracts one.
Doubles, across two lines.
```

A `#|` comment attaches to the next declaration, not to the next line.
Ordinary statements in between do not stop it:

```raku
#| Meant for nothing in particular.
say "a statement";
sub later { }
say &later.WHY;
```
```output
a statement
Meant for nothing in particular.
```

## Pod directives must start a line

A line whose first non-blank character is `=` followed by a word such as
`begin`, `for` or `comment` starts a Pod block, which the compiler skips.
Indentation before the `=` is allowed:

```raku
say 1;
=begin comment
say 2;
=end comment
say 3;
  =begin pod
  indented is fine too
  =end pod
say 4;
```
```output
1
3
4
```

After code on the same line, the `=` of `=begin` is read as an infix
operator where a term was expected, and the compiler suspects the Pod
mistake:

```raku
say 1; =begin comment
say 2;
=end comment
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
An error in Pod syntax is suspected. Perhaps an '=end comment' marker
was forgotten or was improperly nested? Alternately, an infix '=' was
seen where a term was expected.
at example.raku:1
------> say 1; =<HERE>begin comment
```

## A line starting `=word` then a space is Pod, even mid-statement
tags: trap

Any identifier works as the name of an abbreviated Pod block, not only the
standard ones, and such a block runs to the next blank line. A continued
assignment whose `=` touches a sub name followed by a space is therefore
Pod, and so is every line after it up to a blank one:

```raku
sub answer($n) { 42 + $n }
say "before";
my $x
    =answer 1;
say "x is $x";
```
```output
before
```

Nothing after `before` is printed and nothing warns: lines 4 and 5 are
documentation, and `my $x` is a complete statement ending at the end of the
file. `=answer(1);` and `=answer;` are code, because the name is not
followed by whitespace. A space after the `=` avoids the question.

## Every Unicode space is whitespace, but some do not split words

Between tokens, any character with the Unicode space property is
whitespace: the no-break space U+00A0, the em space U+2003, the ideographic
space U+3000 and the rest, and a line separator such as U+2028 ends a line.
Word quoting is the exception: `< >` does not split at the three no-break
spaces (U+00A0, U+2007, U+202F), which keep the words on either side
together, although `.words` does split there.

```raku
use MONKEY-SEE-NO-EVAL;
say EVAL "1\x[A0]+\x[A0]2";
say EVAL "my\x[3000]\$x = 3;\x[2028]\$x * 2";
say EVAL("<a\x[A0]b c>").map(*.chars);
say EVAL("<a\x[2003]b c>").map(*.chars);
say "a\x[A0]b".words.elems;
```
```output
3
6
(3 1)
(1 1 1)
2
```

The example builds its programs with `EVAL` so that the invisible
characters are visible in the source. In the third line the word quote
keeps `a`, the no-break space and `b` together as one three-character
word; with an em space the same quote has three words. A zero-width
space, U+200B, is not whitespace, and a program containing one between
tokens does not compile.

## Numeric literals allow `_` between digits, and `e` makes a Num

An underscore may separate digits anywhere, one at a time, including just
after a radix prefix such as `0x`. A literal with a decimal point is a Rat,
even without a leading digit; a literal with an exponent is a Num. A
leading zero does not make a number octal, and the compiler says so.

```raku
say 1_000_000;
say 0x_ff;
say 0b1010, " ", 0o17, " ", 0d19;
say .5.^name;
say 1e3.raku;
say 1E3.^name;
say 0777;
```
```output
1000000
255
10 15 19
Rat
1000e0
Num
777
```
```stderr
Potential difficulties:
    Leading 0 has no meaning. If you meant to create an octal number, use
    '0o' prefix; like, '0o777'. If you meant to create a string, please add
    quotation marks.
    at example.raku:7
    ------> say 0777<HERE>;
```

Doubled underscores (`1__000`) are refused with "Only isolated underscores
are allowed inside numbers", a trailing one (`1000_`) is simply confusing
to the parser, and the radix prefixes are lowercase only: `0XFF` does not
parse.

## A decimal point needs a digit after it
tags: trap

`.5` is a number, but `5.` is not: a dot after digits is the start of a
method call unless another digit follows. On its own at the end of a
number it is an error, and before a letter it calls a method, so `1.e3` is
not a thousand:

```raku
say 1.e3;
```
```output
```
```stderr
No such method 'e3' for invocant of type 'Int'
  in block <unit> at example.raku line 1

```

`say 5.;` fails at compile time with "Decimal point must be followed by
digit". Write `5.0` and `1.0e3`, or `1e3`.
