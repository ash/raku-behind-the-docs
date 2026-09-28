---
title: Lists, Arrays, Seqs and Slips
part: Collections
summary: A List is immutable, an Array keeps a container per element, a Seq can be read only once and a Slip dissolves into its neighbours; the single-argument rule, holes and laziness decide the rest.
---

Raku has four kinds of list, and `say` prints them almost alike. A **List**
is what the comma builds: immutable, holding its values as they are. An
**Array** is what `[ ]` and `my @a` build: mutable, with a container for each
element. A **Seq** produces its values on demand and can be walked through
only once. A **Slip** is a list that dissolves into whatever list it lands
in. `.raku` tells them apart, which is why most examples here use it.

The containers inside an Array, itemization with `$( )`, and what `flat` does
with them are covered in [Containers and Binding](#ch:containers). The
precedence of `,`, `Z`, `X` and the hyper operators is in [Who Takes the
Operand](#ch:precedence); what a sunk list, Seq or `xx` does is in [Values
Nobody Uses](#ch:sink); calling list methods on Nil or a single value is in
[Nil, Any and the Undefined](#ch:nil-any). The sequence operator `...` and
ranges have chapters of their own, [The Sequence Operator](#ch:sequences) and
[Ranges](#ch:ranges). This chapter is about building lists, indexing them,
changing them, the methods that walk them, and the rules of laziness.

## The comma makes a list, and a one-element list keeps it

Parentheses only group; the comma is what builds a List. `(1)` is the number
1, and a list of one element needs a trailing comma, which `.raku` prints
back. An Array needs no comma for one element, except when that element is
itself a list: `[[1, 2]]` would be read back as a two-element array (see the
next corner), so `.raku` writes `[[1, 2],]`.

```raku
say (1).raku;
say (1,).raku;
say ().raku;
say [1].raku;
say [[1, 2],].raku;
say ((1, 2), [3]).gist;
say $().raku;
```
```output
1
(1,)
()
[1]
[[1, 2],]
((1 2) [3])
$( )
```

`.gist`, which `say` uses, drops the commas and keeps the brackets, so a List
and an Array can still be told apart, but a List and a Seq cannot. The empty
itemized list prints as `$( )`, with a space.

## One list argument is the list; several are its elements
tags: trap

Array constructors, the `list` sub and many list methods follow the
*single-argument rule*. When they receive exactly one argument and it is
iterable, its elements become the elements of the result. When they receive
several arguments, each one is one element, lists included. The `[ ]`
composer follows the rule too, so the inner brackets of `[[1, 2]]` disappear:

```raku
say [[1, 2]].raku;
say [[1, 2], [3, 4]].raku;
say Array.new((1, 2)).raku;
say Array.new((1, 2), (3, 4)).raku;
say list((1, 2)).raku;
say list(1).raku;
say cache(1, 2).raku;
```
```output
[1, 2]
[[1, 2], [3, 4]]
[1, 2]
[(1, 2), (3, 4)]
(1, 2)
(1,)
[1, 2]
```

To keep a single list as one element, add a comma, `[[1, 2],]`, or itemize
it with `$( )`, which counts as one element whatever it holds ([Containers
and Binding](#ch:containers:and-item-make-a-value-one-item)). The sub `cache`
returns an Array, not a List.

## A Hash spreads into its Pairs; a Seq in `$s` does not

Assigning to an array applies the same rule. A Hash or a Set on the right is
one iterable, so it spreads into its Pairs, and a Seq spreads into its
values. A string is not a list and stays one element. A Seq stored in a `$`
variable is an item, and an item is one element, although the same Seq
written directly would have spread:

```raku
my @h = { a => 1 };
say @h.raku;
my @s = set(1);
say @s.raku;
my @str = "abc";
say @str.raku;
my @q = (1, 2).Seq;
say @q.raku;
my $seq = (1, 2).Seq;
my @one = $seq;
say @one.raku;
```
```output
[:a(1)]
[1 => Bool::True]
["abc"]
[1, 2]
[(1, 2).Seq,]
```

`my @all = @$seq`, or `$seq<>`, takes the Seq out of its container first.

## A list numifies to its length and stringifies with spaces

A List or an Array used as a number is its number of elements. Used as a
string it is its elements joined with single spaces, nested lists included.
So `==` between two lists compares their lengths, not their contents; `eqv`
compares contents ([below](#ch:lists:arrays-and-lists-are-identical-only-to-themselves)).

```raku
say +(10, 20, 30);
say (10, 20).Int;
say [1, 2] == (3, 4);
say ~[1, [2, 3]];
say ("a", (1, 2)).Str.raku;
say ().end;
say (Empty,).Bool;
```
```output
3
2
True
1 2 3
"a 1 2"
-1
False
```

`.end`, the last index, is -1 for an empty list. A list is true when it has
at least one element, and `Empty` does not count as one ([below](#ch:lists:empty-is-a-slip-and-it-is-not-defined)).

## A Slip dissolves into the list around it

A Slip is a List whose elements are inserted into the surrounding list
instead of becoming one nested element. Prefix `|` turns a list into a Slip,
even an itemized list that a comma would otherwise keep whole; `slip(…)` and
`.Slip` build one directly. A Slip with no list around it stays a Slip, and
in an argument list `|` passes the elements as separate arguments:

```raku
say (1, |(2, 3), 4).raku;
say (1, (2, 3).Slip).raku;
say (1, |$(2, 3)).raku;
say (1, |[2, 3]).raku;
say (|(1, 2)).raku;
say slip((1, 2)).raku;
say |(1, 2);
```
```output
(1, 2, 3, 4)
(1, 2, 3)
(1, 2, 3)
(1, 2, 3)
slip(1, 2)
slip(1, 2)
12
```

`slip((1, 2))` follows the single-argument rule. The last line hands `1` and
`2` to `say` as two arguments, which it prints with nothing between them.

A block that returns a Slip adds several values to the result of `map`, and
one that returns `Empty` adds none:

```raku
say (1..3).map({ slip $_, $_ * 10 });
say (1..6).map({ $_ %% 2 ?? $_ !! Empty });
```
```output
(1 10 2 20 3 30)
(2 4 6)
```

## A Slip slips even out of a Scalar container
tags: trap

An item counts as one element, and `$( )` around a list keeps it whole
([Containers and Binding](#ch:containers:for-iterates-an-item-once)). A Slip
ignores its container: stored in a `$` variable or wrapped in `$( )`, it
still spreads into the list it is put in, and `for` walks through it.

```raku
my $s = slip(2, 3);
say $s.raku;
say (1, $s).raku;
say (1, $(slip(2, 3))).raku;
for $s { say "got $_" }
my $l = (2, 3);
say (1, $l).raku;
```
```output
$(slip(2, 3))
(1, 2, 3)
(1, 2, 3)
got 2
got 3
(1, $(2, 3))
```

## `Empty` is a Slip, and it is not defined
tags: quirk

`Empty` is the Slip with no elements, and `slip()` returns that very object.
Unlike every other list it is undefined, so `//` replaces it and `with` skips
it, while `slip(0)`, holding one false element, is defined. List methods
called on `Empty` answer with `Empty`, Nil or an empty string.

```raku
say slip() === Empty;
say Empty.defined;
say slip(0).defined;
say Empty // "default";
say (with Empty { "ran" } else { "skipped" });
say Empty.map({ $_ }).raku;
say Empty.head.raku;
say Empty.join("-").raku;
```
```output
True
False
True
default
skipped
Empty
Nil
""
```

## `.Array` copies, and `.eager` returns the list itself

`.Array` builds a new Array with fresh containers, so writing to it leaves
the original alone. `.eager` computes every element and returns the list it
was called on, not a copy; on a Seq it returns a List of the values. A lazy
Array cannot become a List: `.List` throws `X::Cannot::Lazy`. (`.List` of an
ordinary Array is a snapshot of its values; see [Containers and
Binding](#ch:containers:a-list-holds-bare-values-unless-it-was-given-containers).)

```raku
my $l = (1, 2);
my $a = $l.Array;
$a[0] = 9;
say $l.raku;
say $a.raku;
my @b = 1, 2;
say @b.eager =:= @b;
say (1..3).map(* * 2).eager.raku;
my @lazy = 1..*;
try { @lazy.List };
say $!.^name;
```
```output
$(1, 2)
$[9, 2]
True
(2, 4, 6)
X::Cannot::Lazy
```

`.eager` on an infinite list does not refuse. It starts computing and never
returns; each of these lines runs until it is killed:

```raku nocheck
say (1..*).eager.elems;
my @a = 1..*; say @a.eager.elems;
say (1..*).map(* + 1).eager.elems;
```

## Slipping a list passes its Pairs as positionals; `.Capture` makes them named

`|` in an argument list passes a list's elements as positional arguments,
Pairs included. `.Capture` sorts the elements first: Pairs become named
arguments and everything else stays positional. A lazy list has no Capture,
and `.Capture` returns a Failure.

```raku
sub show(*@pos, *%named) { say "pos {@pos.raku}, named {%named.raku}" }
show |(1, a => 2);
show |(1, a => 2).Capture;
say (1, a => 2).Capture.raku;
say ().Capture.raku;
say (a => 1).Capture.raku;
say (1..*).list.Capture.^name;
```
```output
pos [1, :a(2)], named {}
pos [1], named {:a(2)}
\(1, :a(2))
\()
\(:key("a"), :value(1))
Failure
```

A Pair on its own is not a list. Its Capture is the one every object has:
its public attributes, `key` and `value`, as named arguments.

## `.gist` stops at 100 elements, and a lazy list prints `(...)`
tags: undocumented unasserted

`say` shows at most the first 100 elements of a list, followed by `...`. A
lazy list is not evaluated for `say` at all: a lazy Seq or List prints
`(...)`, a lazy Array `[...]` however much of it has been computed, and a
lazy Seq turned into a string is `...`.

```raku
my @big = 1..200;
say @big.gist.words.elems;
say @big.gist.substr(*-11);
my @lazy = 1..*;
say @lazy[5];
say @lazy.gist;
say (1..*).map(* * 2).gist;
say (1..*).map(* * 2).Str;
```
```output
101
99 100 ...]
6
[...]
(...)
...
```

The 101 words are the hundred numbers and the closing `...]`. `.raku` does
evaluate a lazy Seq, but only its first hundred values (the block runs 101
times, to find out that there is more), and marks the result `.lazy`. A lazy
Array's `.raku` is `[...]`, and a lazy Seq that is finite prints in full:

```raku
my $n = 0;
my $code = (1..*).map({ $n++; $_ * 2 }).raku;
say $n;
say $code.substr(0, 12);
say $code.substr(*-16);
my @lazy = 1..*;
say @lazy.raku;
say (1..3).lazy.raku;
```
```output
101
(2, 4, 6, 8,
200...).lazy.Seq
[...]
(1, 2, 3).lazy.Seq
```

## A literal negative index does not compile

Raku has no negative indices. Counting from the end is written with a
WhateverCode, `*-1`, and a literal negative index is rejected before the
program runs, with a message that names the replacement:

```raku
my @a = 10, 20;
say @a[-1];
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Unsupported use of a negative -1 subscript to index from the end. In
Raku please use: a function such as *-1.
at example.raku:2
------> say @a[-1]<HERE>;
```

## A computed negative index is a Failure; past the end is `Any`

A negative index that is known only at run time does not throw straight
away: reading returns a Failure carrying `X::OutOfRange`, which throws when
it is used. `:exists` answers False, and assigning to the position throws. A
`*-n` that reaches before the start is a Failure too.

```raku
my @a = 10, 20;
my $i = -1;
my $f = @a[$i];
say $f.^name;
say $f.exception.message;
say @a[$i]:exists;
say @a[*-5].^name;
try { @a[$i] = 5 };
say $!.^name;
```
```output
Failure
Index out of range. Is: -1, should be in 0..^Inf
False
Failure
X::OutOfRange
```

Reading beyond the end is not an error at all. An Array answers with its
default, `Any`, a List answers Nil, and neither grows. Assigning beyond the
end does grow the array, and the positions it skips become holes:

```raku
my @a = 10, 20;
say @a[5].raku;
say @a.elems;
say (10, 20)[5].raku;
@a[4] = 50;
say @a.raku;
```
```output
Any
2
Nil
[10, 20, Any, Any, 50]
```

## An index is truncated to an integer; a type object is refused

A fractional index is truncated and a string index is converted to a number,
so `@a[1.9]` is `@a[1]` and `@a["2"]` is `@a[2]`. An undefined index has no
number to give, and the subscript dies:

```raku
my @a = 10, 20, 30;
say @a[1.9];
say @a["2"];
try { @a[Int] };
say $!.message;
```
```output
20
30
Unable to call postcircumfix @a[ (Int) ] with a type object
Indexing requires a defined object
```

## An endless range stops at the end of the array; a finite one does not
tags: trap

A slice with a range that ends in `*` or `Inf` is cut off at the last
element that exists. A finite range is taken as written, and indices past
the end read as `Any`, or `Nil` for a List. The same cut applies when a slice
is assigned to, so `@a[1..*] = …` never makes the array longer:

```raku
my @a = 10, 20, 30;
say @a[1..*].raku;
say @a[1..4].raku;
say (10, 20, 30)[1..4].raku;
@a[1..*] = 7, 8, 9, 10;
say @a.raku;
```
```output
(20, 30)
(20, 30, Any, Any)
(20, 30, Nil, Nil)
[10, 7, 8]
```

## `:delete` leaves a hole, except at the end

`@a[i]:delete` returns the element and leaves a *hole*: the array keeps its
length, `:exists` is False there, and reading the position gives the array's
default. Deleting the last element is different: the array shrinks, and it
keeps shrinking past any holes that are now at its end. Deleting beyond the
end changes nothing.

```raku
my @a = 1, 2, 3;
say @a[1]:delete;
say @a.raku;
say @a[1]:exists;
@a[2]:delete;
say @a.raku;
say (@a[7]:delete).raku;
say @a.elems;
```
```output
2
[1, Any, 3]
False
[1]
Any
1
```

`pop` removes the last element but does not shrink past a hole. An array
declared with `is default` reads its holes as that default, and a delete on a
lazy array computes it up to the position and leaves a hole there:

```raku
my @a = 1, 2;
@a[3] = 4;
say @a.pop;
say @a.raku;
my Int @b is default(0) = 1, 2, 3;
@b[1]:delete;
say @b.raku;
my @c = 1..*;
@c[1]:delete;
say @c.head(3).raku;
```
```output
4
[1, 2, Any]
Array[Int].new(1, 0, 3)
(1, Any, 3).Seq
```

## `:kv`, `:p`, `:k` and `:v` skip positions that do not exist

The subscript adverbs return the index, the value, or both, for each
position of a slice, and they leave out positions that hold no element.
Negated, as `:!kv` or `:!v`, they keep them. `:exists` gives a Bool for every
position, but combined with `:kv` it drops the missing ones again.
`:delete:exists` reports whether the element existed before it was deleted.

```raku
my @a = <a b c>;
say @a[0, 5]:kv;
say @a[0, 5]:p;
say @a[0, 5]:k;
say (@a[0, 5]:!kv).raku;
say @a[0, 5]:exists;
say @a[0, 5]:exists:kv;
say @a[1]:delete:exists;
say @a[1]:exists;
```
```output
(0 a)
(0 => a)
(0)
(0, "a", 5, Any)
(True False)
(0 True)
True
False
```

An adverb that does not exist is a dispatch failure on an array element, and
it throws at once. On a hash element, and on a zen slice of either, it is a
Failure carrying `X::Adverb`:

```raku
my @a = 1, 2;
my %h = a => 1;
try { my $x = @a[0]:foo };
say $!.^name;
my $f = %h<a>:foo;
say $f.exception.^name;
my $g = @a[]:foo;
say $g.exception.message;
```
```output
X::Multi::NoMatch
X::Adverb
Unexpected adverb 'foo' passed to zen slice on '@a'.
```

## A slice assignment gives one value to each slot

Assigning to a slice is a list assignment. The values on the right go to the
selected positions in order; a position with no value left gets Nil, which
resets it to the default; extra values are dropped; a nested list is one
value. The right side is read completely before any slot changes, so two
positions can be swapped. The assignment returns the slice.

```raku
my @a = 1, 2, 3;
@a[0, 1] = 5;
say @a.raku;
@a[0, 1] = 7, 8, 9;
say @a.raku;
@a[1, 0] = @a[0, 1];
say @a.raku;
@a[0, 1] = (5, 6), 7;
say @a.raku;
my @r = @a[1, 2] = 8, 9;
say @r.raku;
```
```output
[5, Any, 3]
[7, 8, 3]
[8, 7, 3]
[(5, 6), 7, 3]
[8, 9]
```

## `@a[*] = …` keeps the length; `@a[] = …` replaces the array
tags: trap

`@a[*]` is a slice of every position the array has now, so assigning to it
behaves like any slice assignment: missing values become the default, extra
ones are dropped, and the length does not change. The zen slice `@a[]` is
the array itself, and assigning to it is a plain array assignment:

```raku
my @a = 1, 2, 3;
@a[*] = 0;
say @a.raku;
@a[*] = 7, 8, 9, 10;
say @a.raku;
@a[] = 5, 6;
say @a.raku;
@a = 0 xx @a;
say @a.raku;
```
```output
[0, Any, Any]
[7, 8, 9]
[5, 6]
[0, 0]
```

`@a[*] = 0` does not fill the array with zeros; `0 xx @a`, which repeats 0 as
many times as `@a` has elements, does.

## A semicolon subscript goes one level deeper per dimension

`@a[1;0]` is `@a[1][0]`, and each dimension may be a slice or `*`. Reading
past the end at any level gives `Any` without creating anything, while
assigning creates the missing levels. `:exists` and `:delete` apply to the
innermost position.

```raku
my @a = [1, 2], [3, 4];
say @a[1;0];
say @a[*;0].raku;
say @a[5;0].raku;
say @a.elems;
@a[2;1] = 7;
say @a.raku;
say @a[1;1]:delete;
say @a.raku;
```
```output
3
(1, 3)
Any
2
[[1, 2], [3, 4], [Any, 7]]
4
[[1, 2], [3], [Any, 7]]
```

A value that is not a list answers index 0 with itself ([Nil, Any and the
Undefined](#ch:nil-any)), so extra dimensions on a flat array return the
element:

```raku
my @flat = 1, 2;
say @flat[0;0];
say @flat[1;0;0];
```
```output
1
2
```

## A shaped array has a fixed size in every dimension

`my @a[2;2]` declares a two-by-two array. Its `.elems` is the size of the
first dimension, `.shape` lists all of them, and `.keys` lists the index
pairs. An index outside the shape throws, `push` and `pop` throw
`X::IllegalOnFixedDimensionArray`, and taking one row, `@a[1]`, of a
two-dimensional array is not implemented.

```raku
my @a[2;2];
say @a.shape;
say @a.elems;
@a[1;1] = 5;
say @a.raku;
say @a.keys.raku;
try { @a[2;0] = 1 };
say $!.message;
try { @a.push(3) };
say $!.^name;
try { @a[1][1] };
say $!.message;
```
```output
(2 2)
2
Array.new(:shape(2, 2), [Any, Any], [Any, 5])
((0, 0), (0, 1), (1, 0), (1, 1)).Seq
Index 2 for dimension 1 out of range (must be 0..1)
X::IllegalOnFixedDimensionArray
Partially dimensioned views of shaped arrays not yet implemented. Sorry.
```

A shaped array can be initialised from nested lists, and `say` prints a
two-dimensional one row by row. An ordinary array's `.shape` is `(*,)`, one
dimension of any size:

```raku
my @m[2;2] = (1, 2), (3, 4);
say @m[1;0];
say @m;
say [1, 2].shape.raku;
say Array.new(:shape(2)).raku;
```
```output
3
[[1 2]
 [3 4]]
(*,)
Array.new(:shape(2,), [Any, Any])
```

## `my @a[Int]` is an ordinary array, with a warning
tags: trap

What stands in brackets after an array's name is a shape, not an element
type. A type object makes no sense as a shape, so Rakudo warns, suggests the
declaration that was probably meant, and creates an ordinary array. A Range
is not accepted as a shape either, and that dies.

```raku
my @a[Int];
@a.push("text");
say @a.raku;
try { Array.new(:shape(1..2)) };
say $!.message;
```
```output
["text"]
Setting a shape with a Range not allowed: 1..2
```
```stderr
Ignoring [Int] as shape specification, did you mean 'my Int @foo' ?
  in block <unit> at example.raku line 1
```

## A typed array shows its type in `.raku` but not in `.gist`

`my Int @a` makes an `Array[Int]`. `say` prints it like any array, while
`.raku` names the type. `.of` is the element type and `.default` the value
of an empty slot, which for a typed array is the type object; assigning Nil
to an element stores that default. An untyped array has element type `Mu`
and default `Any`, and `.name` gives the variable's name.

```raku
my Int @a = 1, 2;
say @a;
say @a.raku;
say @a.of.raku;
@a[0] = Nil;
say @a.raku;
try { @a.push("x") };
say $!.message;
my @plain;
say @plain.of.raku, " ", @plain.default.raku, " ", @plain.name;
```
```output
[1 2]
Array[Int].new(1, 2)
Int
Array[Int].new(Int, 2)
Type check failed for an element of @a; expected Int but got Str ("x")
Mu Any @plain
```

`is default` sets what holes, positions past the end and `Nil` assignments
read as, for typed and untyped arrays alike. The type in `Array[…]` must be a
type: `Array[42]` is rejected at compile time.

```raku
my @d is default(7);
@d[2] = 1;
say @d.raku;
say @d[5];
my Int @z is default(0);
@z[1] = 5;
say @z.raku;
say Array[Str].new("a").raku;
```
```output
[7, 7, 1]
7
Array[Int].new(0, 5)
Array[Str].new("a")
```

## `push` adds each argument whole; `append` spreads a single list

`push` and `unshift` add every argument as one element, so a list or an
array arrives nested, and only a Slip spreads. `append` and `prepend` follow
the single-argument rule: one iterable argument is spread, several arguments
are each one element, and an itemized list stays whole. All four return the
array itself.

```raku
my @p;
@p.push((1, 2));
@p.push([3, 4]);
@p.push(5, 6);
@p.push(|(7, 8));
say @p.raku;
my @a;
@a.append((1, 2));
@a.append([3, 4]);
@a.append(5, 6);
@a.append($(7, 8));
say @a.raku;
```
```output
[(1, 2), [3, 4], 5, 6, 7, 8]
[1, 2, 3, 4, 5, 6, (7, 8)]
```

A Hash given to `append` spreads into Pairs, and a Range given to `push`
stays one element:

```raku
my @a;
@a.append({ a => 1 });
@a.push(1..3);
@a.append(1..3);
say @a.raku;
my @e = 3;
@e.unshift((1, 2));
@e.prepend((1, 2));
say @e.raku;
say @e.push(4) =:= @e;
```
```output
[:a(1), 1..3, 1, 2, 3]
[1, 2, (1, 2), 3]
True
```

## `pop` and `shift` on an empty array return a Failure

An empty array has nothing to give, and `pop` and `shift` say so with a
Failure carrying `X::Cannot::Empty` rather than an exception: the program
goes on until the result is used. A hole comes out as the array's default.

```raku
my @e;
my $f = @e.pop;
say $f.^name;
say $f.exception.message;
say @e.shift.exception.^name;
my @d is default(9) = 1, 2;
@d[0]:delete;
say @d.shift;
say @d.raku;
```
```output
Failure
Cannot pop from an empty Array
X::Cannot::Empty
9
[2]
```

## `splice` accepts `*` and code for its offset and size

`splice(offset, size, replacement…)` removes `size` elements at `offset`,
puts the replacement in their place and returns what it removed, as an Array
of the same type. Either number may be `*`, the end, or code: the offset code
receives the array's length, the size code the number of elements after the
offset. A size past the end is clamped, and a replacement Array is spread.

```raku
my @a = 1..5;
say @a.splice(1, 2, <a b c>).raku;
say @a.raku;
@a = 1..5;
say @a.splice(*-2).raku;
@a = 1..5;
say @a.splice(1, * - 1).raku;
@a = 1..3;
say @a.splice(*, 0, 9).raku;
say @a.raku;
@a = 1..3;
say @a.splice(1, 99).raku;
```
```output
[2, 3]
[1, "a", "b", "c", 4, 5]
[4, 5]
[2, 3, 4]
[]
[1, 2, 3, 9]
[2, 3]
```

Unlike `pop`, `splice` throws its errors straight away: an offset past the
end, a negative offset or size, and a replacement of the wrong type for a
typed array.

```raku
my @a = 1..3;
try { @a.splice(9) };
say $!.message;
try { @a.splice(1, -1) };
say $!.message;
my Int @t = 1, 2;
try { @t.splice(0, 1, "x") };
say $!.^name;
say @t.splice(0, 1).raku;
```
```output
Offset argument to splice out of range. Is: 9, should be in 0..3
Size argument to splice out of range. Is: -1, should be in 0..^2
X::TypeCheck::Splice
Array[Int].new(1)
```

The range in the second message is one short: at offset 1 of a
three-element array, a size of 2 is accepted.

## A lazy array takes `shift` and `unshift`, but not `push` or `pop`

An array assigned from an infinite range is lazy: it computes its elements
as they are asked for. Operations at the front work: `unshift` adds before
the computed part, and `shift` computes one element and takes it. Operations
at the end refuse: `push` and `append` throw `X::Cannot::Lazy`, and `pop`
returns a Failure carrying it. `append` refuses a lazy argument too, while
`push` stores it as one element.

```raku
my @lazy = 1..*;
@lazy.unshift(0);
say @lazy.head(3).raku;
say @lazy.shift;
try { @lazy.push(9) };
say $!.^name;
say @lazy.pop.exception.^name;
my @plain;
try { @plain.append(1..*) };
say $!.^name;
@plain.push(1..*);
say @plain.raku;
```
```output
(0, 1, 2).Seq
0
X::Cannot::Lazy
X::Cannot::Lazy
X::Cannot::Lazy
[1..Inf,]
```

## `splice` without a size removes only what a lazy array has computed
tags: bug

`splice(offset, size)` works on a lazy array, since it needs only the
elements up to `offset + size`. Without a size, or with `*`, it is meant to
remove everything from the offset on. On a lazy array Rakudo 2026.08 removes
only the elements computed so far, leaves the lazy rest in place, and
reports no error:

```raku
my @a = 1..*;
say @a.splice(1, 2).raku;
say @a.head(3).raku;
my @b = 1..*;
say @b.splice(1).raku;
say @b.head(3).raku;
my @c = 1..*;
@c[3];
say @c.splice(2).raku;
say @c.head(3).raku;
```
```output
[2, 3]
(1, 4, 5).Seq
[]
(1, 2, 3).Seq
[3, 4]
(1, 2, 5).Seq
```

The operations that need the end of the array, `push` and `pop`, refuse a
lazy array with `X::Cannot::Lazy`; this one does part of the job instead.

## `grab` removes random elements and returns them

`grab` takes an element at random out of an Array; a List, being immutable,
has no such method. `grab(n)` takes up to n elements, `grab(*)` all of them,
and code receives the number of elements. An empty array answers Nil for one
element and an empty Seq for several; a lazy array refuses.

```raku
my @a = 1..5;
my $one = @a.grab;
say $one ∈ 1..5, " ", @a.elems;
say @a.grab(10).elems, " ", @a.elems;
say [].grab.raku;
say [].grab(2).raku;
my @b = 1..5;
say @b.grab(* - 1).elems, " ", @b.elems;
my @lazy = 1..*;
try { @lazy.grab };
say $!.^name;
```
```output
True 4
4 0
Nil
().Seq
4 1
X::Cannot::Lazy
```

## `clone` is shallow, and a lazy clone shares its source

`.clone` gives an Array with new containers, so assigning to its elements or
pushing onto it leaves the original alone, but an array nested inside is the
same object in both. The clone keeps the element type.

```raku
my @a = 1, [2, 3];
my @b := @a.clone;
@b[0] = 9;
@b[1][0] = 8;
@b.push(4);
say @a.raku;
say @b.raku;
my Int @t = 1;
say @t.clone.^name;
```
```output
[1, [8, 3]]
[9, [8, 3], 4]
Array[Int]
```

The clone of a lazy array shares its source of values with the original.
Each value is computed once, by whichever array asks for it first, and both
then have it; an assignment to one array still stays in that array:

```raku
my $n = 0;
my @a = (1..*).map({ $n++; $_ * 10 });
my @b := @a.clone;
say @b[3], " after $n calls";
say @a[3], " after $n calls";
@b[0] = 0;
say @a.head(2).raku;
say @b.head(2).raku;
```
```output
40 after 4 calls
40 after 4 calls
(10, 20).Seq
(0, 20).Seq
```

## A lazy list can be indexed, but not counted

A lazy list computes its elements as they are needed, so anything that needs
only a beginning works: indexing, `.head`, the truth test. Anything that
needs the end refuses with `X::Cannot::Lazy`: `.elems`, `.sum`, `.reverse`,
`.rotate` and `.pick` return a Failure, while `.sort`, `.tail` and `.end`
throw at once. `.join` joins what has been computed and adds `...`.

```raku
my @lazy = 1..*;
say @lazy.is-lazy;
say @lazy[9];
say @lazy.head(3);
say @lazy.Bool;
say @lazy.join(",");
say @lazy.elems.^name;
say @lazy.sum.^name;
try { @lazy.sort };
say $!.^name;
```
```output
True
10
(1 2 3)
True
1,2,3,4,5,6,7,8,9,10,...
Failure
Failure
X::Cannot::Lazy
```

A Failure throws only when it is used, so the error can surface far from its
cause. The message says where each of the two happened:

```raku
my @lazy = 1..*;
my $count = @lazy.elems;
say "counted";
say $count;
```
```output
counted
```
```stderr
Cannot .elems a lazy list
  in block <unit> at example.raku line 2

Actually thrown at:
  in block <unit> at example.raku line 4

```

## `is-lazy` is False for a `gather`, even an endless one
tags: trap

`is-lazy` does not ask whether a list computes its values on demand; a
`gather`, a `map` and every Seq do that. It asks whether the list should be
treated as possibly infinite. A `gather`, or a `map` over a finite range,
says False, and an array assignment, which is eager unless `is-lazy` is
True, then runs its source to the end. The `lazy` prefix marks a list lazy:

```raku
my $g = gather { for 1..3 { say "taking $_"; take $_ } };
say $g.is-lazy;
say $g[0];
say (gather { loop { take 1 } }).is-lazy;
my @a = lazy gather { my $i = 0; loop { take $i++ } };
say @a[3];
say (1..*).map(* + 1).is-lazy;
```
```output
False
taking 1
1
False
3
True
```

Without `lazy`, the same assignment never returns:

```raku nocheck
my @a = gather { my $i = 0; loop { take $i++ } };
say @a[3];
```

## A Seq can be iterated only once

A Seq hands out its values one at a time and does not keep them. Once
something has iterated it, a second attempt throws `X::Seq::Consumed`, and
the message suggests the two remedies, `.cache` or an array.

```raku
my $s = (1..3).map(* * 2);
say $s.sum;
try { say $s.sum };
say $!.^name;
say $!.message;
```
```output
12
X::Seq::Consumed
The iterator of this Seq is already in use/consumed by another Seq (you
might solve this by adding .cache on usages of the Seq, or by assigning
the Seq into an array)
```

Assigning a Seq to an array iterates it: the array has the values, and the
Seq has none left. A Seq held in a `$` variable would be assigned as one
element instead, without being iterated ([above](#ch:lists:a-hash-spreads-into-its-pairs-a-seq-in-s-does-not));
a sigilless name holds the Seq itself. A consumed Seq prints as `Seq.new()`,
which is also what a `Seq.new` without an iterator is.

```raku
my \s = (1..3).map(* * 2);
my @a = s;
say @a;
try { s.elems };
say $!.^name;
say s.raku;
```
```output
[2 4 6]
X::Seq::Consumed
Seq.new()
```

## Some methods keep a Seq's values; most use them up

Methods that answer a number or a string about the whole Seq, and indexing,
*cache* it: they keep the values, and the Seq can be used again. Methods
that return a new list, including `.list`, `.eager` and `.head`, take over
its iterator and leave it consumed. So does `.join`, although `.Str` does
not.

```raku
for <elems Bool Str gist raku cache join sum head list eager sort> -> $method {
    my $s = (1..3).map(* * 2);
    my $result = $s."$method"();
    say "$method: ", (try $s.join(",")) // $!.^name;
}
my $t = (1..3).map(* * 2);
say $t[1];
say $t.join(",");
```
```output
elems: 2,4,6
Bool: 2,4,6
Str: 2,4,6
gist: 2,4,6
raku: 2,4,6
cache: 2,4,6
join: X::Seq::Consumed
sum: X::Seq::Consumed
head: X::Seq::Consumed
list: X::Seq::Consumed
eager: X::Seq::Consumed
sort: X::Seq::Consumed
4
2,4,6
```

## `.head(-1)` is empty; `.head(*-1)` drops the last element

A negative count is not a count from the end: `.head` and `.tail` with a
negative number, or with 0, return nothing. Counting from the end takes a
WhateverCode, `*-1`. `.head(*)` is the whole list, even a lazy one.

```raku
my @l = 1, 2, 3, 4;
say @l.head(-1).raku;
say @l.head(*-1).raku;
say @l.tail(-1).raku;
say @l.tail(*-1).raku;
say @l.head(0).raku;
say (1..*).map(* * 2).head(*).^name;
say (1..*).map(* * 2).skip(2).head(2).raku;
```
```output
().Seq
(1, 2, 3).Seq
().Seq
(2, 3, 4).Seq
().Seq
Seq
(6, 8).Seq
```

`.slice` picks positions from a list in a single pass, so it needs its
indices in increasing order. It is lazy as well, and a wrong order is noticed
only when the result is read:

```raku
my $s = (1, 2, 3).slice(2, 0);
say "made it";
try { $s.eager };
say $!.message;
say (1, 2, 3, 4).slice(0, 2).raku;
```
```output
made it
Provided index 0, which is lower than 3
(1, 3).Seq
```

## A `map` block takes as many elements as it has parameters

`map` calls its block with as many elements as the block has positional
parameters, so a block with two parameters walks through the list in pairs.
When the elements do not divide evenly, the last call dies, unless the
parameters left over are optional. With `:item`, `map` treats the whole
invocant as one element. (A single value is mapped as a list of one: see
[Nil, Any and the Undefined](#ch:nil-any:map-calls-its-block-once-for-a-single-value).)

```raku
say (1, 2, 3, 4).map(-> $a, $b { $a + $b });
say (1, 2, 3).map({ $^x + $^y + $^z });
say (1, 2, 3).map(-> $a, $b? { $b // "none" });
try { (1, 2, 3).map(-> $a, $b { $a + $b }).eager };
say $!.message;
say ((1, 2), (3, 4)).map(:item, *.elems).raku;
```
```output
(3 7)
(6)
(2 none)
Too few positionals passed; expected 2 arguments but got 1
(2,).Seq
```

Anything that is not code is refused with `X::Cannot::Map`, and the message
guesses at the mistake. A block that holds only a pair is a Hash, which is
refused in the same way ([Whitespace, Terms and Blocks](#ch:whitespace:a-block-that-only-returns-a-pair-is-a-hash-so-map-refuses-it)).

```raku
try { (1, 2).map(1) };
say $!.^name;
say $!.message;
```
```output
X::Cannot::Map
Cannot map a List using '1'
Did a * (Whatever) get absorbed by a list?
```

## `deepmap` itemizes what it builds for an inner list

`nodemap` applies its code to each element of the top level, nested lists
included, and returns a List. `deepmap` descends into nested lists and
applies the code to the leaves; each inner list it rebuilds comes back
itemized, and the result is an Array for an Array and a List for a List or a
Seq. `duckmap` applies the code where the code's signature accepts the
element, passes other elements through, and descends into lists. `flatmap`
maps and then flattens the results.

```raku
say (1, (2, 3)).nodemap(*.elems).raku;
say (1, (2, 3)).deepmap(* * 10).raku;
say [1, [2, 3]].deepmap(* * 10).raku;
say (1, "a", (2, "b")).duckmap(-> Int $x { $x * 10 }).raku;
say (1, 2).flatmap({ $_, $_ * 10 }).raku;
say (1, (2, 3)).Seq.deepmap(* + 1).^name;
```
```output
(1, 2)
(10, $(20, 30))
[10, [20, 30]]
(10, "a", $(20, "b"))
(1, 10, 2, 20).Seq
List
```

`map` with one named argument instead of code hands over to these:
`map(deep => &f)` is `deepmap(&f)`, and `flat`, `node` and `duck` work the
same way. In `deepmap`, a Slip result spreads and `Empty` removes the leaf.
The code may take one parameter only, and phasers such as `FIRST` do not run,
with a warning:

```raku
say (1, (2, 3)).map(deep => * * 10).raku;
say (1, (2, 3)).deepmap({ $_ == 2 ?? Empty !! $_ }).raku;
say (1, (2, 3)).deepmap({ slip $_, $_ }).raku;
try { (1, 2).deepmap(-> $a, $b { $a }) };
say $!.message;
say (1, 2).deepmap({ FIRST { say "first" }; $_ * 2 }).raku;
```
```output
(10, $(20, 30))
(1, $(3,))
(1, 1, $(2, 2, 3, 3))
.deepmap only supports Callables with a single parameter, got 2
(2, 4)
```
```stderr
.deepmap ignores FIRST phaser(s)
  in block <unit> at example.raku line 6
```

## `deepmap` on a hash unwraps a one-element array
tags: quirk

On a Hash, `deepmap` and `nodemap` map the values and return a Hash. A value
that is an Array of several elements comes back from `deepmap` as an
itemized Array, but a value that is a list of one element comes back as that
element alone, no longer in a list:

```raku
say { a => [1, 2] }.deepmap(* + 1).raku;
say { a => [5] }.deepmap(* + 1).raku;
say { a => (5,) }.deepmap(* + 1).raku;
say { a => 1, b => 2 }.nodemap(* + 1).sort.raku;
```
```output
{:a($[2, 3])}
{:a(6)}
{:a(6)}
(:a(2), :b(3)).Seq
```

## `grep` judges what its code returns

`grep` given a regex matches it against each element's string; given a type
or a value it smartmatches. Given code, it looks at what the code returns: a
returned regex is matched against the element, a Junction is collapsed, and
anything else is taken by its truth. `next` and `last` inside the code work
as in a loop: `next` drops the element, and `last` ends the whole `grep`.

```raku
say (10, 20, 30).grep(/2/);
say (1, 2, 3).grep({ /2/ });
say (1, 2, 3).grep({ $_ == 1 | 3 });
say (1..3).grep(1..2);
say (1..5).grep({ next if $_ == 2; last if $_ == 4; True });
say (1..*).grep(* %% 3).head(3);
```
```output
(20)
(2)
(1 3)
(1 2)
(1 3)
(3 6 9)
```

`grep` is as lazy as its source, so it works on an infinite list as long as
only a beginning of the result is read.

## `:k`, `:kv`, `:p` and `:v` choose what `grep` and `first` return

`grep` and `first` return the matching elements. With `:k` they return their
indices, with `:kv` index and value, with `:p` Pairs, and `:v` is the
default made explicit. Negated, `:!k`, `:!kv` and `:!p` mean the default
too. Two of them at once, or an adverb that `grep` does not know, is an
`X::Adverb`:

```raku
my @l = <a b c d>;
say @l.grep(/<[bd]>/, :k);
say @l.grep(/<[bd]>/, :kv);
say @l.grep(/<[bd]>/, :p);
say @l.grep(/<[bd]>/, :!k);
try { @l.grep(/b/, :k, :v) };
say $!.message;
try { @l.grep(/b/, :zap) };
say $!.message;
```
```output
(1 3)
(1 b 3 d)
(1 => b 3 => d)
(b d)
Unsupported combination of adverbs ('k', 'v') passed to grep on '@l'.
Unexpected adverb 'zap' passed to grep on '@l'.
```

`:!v`, which should mean the default as well, is refused as *Unexpected
adverb 'v'*. `first` does not throw for two adverbs; it returns a Failure,
as it does for a Bool test ([Nil, Any and the
Undefined](#ch:nil-any:first-answers-nil-when-nothing-matches)).

## `first(:end)` searches from the end, and refuses a lazy list

`:end` makes `first` look for the last match instead of the first. Combined
with `:k`, it still counts the index from the start. On an infinite list,
`first` without `:end` works, since it stops at the first match; with `:end`
it throws `X::Cannot::Lazy`.

```raku
my @l = 1, 2, 3, 4;
say @l.first(* > 1, :end);
say @l.first(* > 1, :k);
say @l.first(* > 1, :end, :k);
say @l.first(* > 1, :p);
say @l.first(:end);
say (1..*).first(* > 3);
try { (1..*).first(* > 3, :end) };
say $!.^name;
```
```output
4
1
3
1 => 2
4
4
X::Cannot::Lazy
```

## A one-parameter block sorts by key; two parameters compare

`sort` looks at the code it is given. Code with one parameter is a key
extractor: it is called for each element, and the elements are ordered by
the results. Code with two parameters is a comparator that returns an
`Order`. `collate` sorts strings by the Unicode collation algorithm, so case
matters only between otherwise equal letters.

```raku
my @w = <pear Fig apple>;
say @w.sort;
say @w.sort(*.lc);
say @w.sort(-> $a, $b { $b.chars <=> $a.chars });
say @w.sort({ $^b cmp $^a });
say @w.collate;
say <b A a B>.collate;
```
```output
(Fig apple pear)
(apple Fig pear)
(apple pear Fig)
(pear apple Fig)
(apple Fig pear)
(a A b B)
```

Plain `sort` compares with `cmp`, which puts every uppercase letter before
the lowercase ones. Sorting needs every element, but an infinite Range is
already in order, and `sort` without code returns it as a lazy Seq. With
code, or on any other lazy list, it throws:

```raku
my $s = (1..*).sort;
say $s.is-lazy;
say $s.head(3);
try { (1..*).sort(-*) };
say $!.^name;
try { (1..*).map(* * 2).sort };
say $!.^name;
```
```output
True
(1 2 3)
X::Cannot::Lazy
X::Cannot::Lazy
```

## `sort(:k)` returns positions, and `reverse` keeps inner lists whole

`sort` with `:k` returns the indices that would put the list in order, as a
List, and takes a key extractor like any sort. The subs `reverse` and
`rotate` take their arguments as a list of elements, so an inner list stays
one element, while a single list argument is spread. `rotate` converts its
count to a number, and `reverse` with no arguments is refused.

```raku
say (30, 10, 20).sort(:k).raku;
say (30, 10, 20).sort(-*, :k);
say reverse((1, 2), 3).raku;
say reverse((1, 2)).raku;
say (1, 2, 3).rotate("2").raku;
say rotate((1, 2, 3), -1).raku;
try { reverse() };
say $!.^name;
```
```output
(1, 2, 0)
(0 2 1)
(3, $(1, 2)).Seq
(2, 1).Seq
(3, 1, 2).Seq
(3, 1, 2).Seq
X::NoZeroArgMeaning
```

## `unique` compares with what it kept; `squish` with the previous element

`unique` drops every element that equals one it has already kept, comparing
with `===`, so `1`, `"1"` and `1.0` are all different. `squish` drops only
runs of equal neighbours. `:as` compares a transformed value but returns the
original, and `:with` replaces the comparison. `repeated` returns the
elements that `unique` drops.

```raku
say (1, "1", 1.0, 1).unique.raku;
say <a A b B a>.unique(:as(&lc));
say (1, 1, 2, 2, 1).squish;
say <a A b>.squish(:as(&lc));
say (1, 2, 2, 3, 3, 3).repeated;
```
```output
(1, "1", 1.0).Seq
(a b)
(1 2 1)
(a b)
(2 3 3)
```

The two differ in what `:with` receives. `unique` passes the new element
first and then each element kept so far; `squish` passes the previous
element, whether it was kept or not, and then the new one:

```raku
my @u = (1, 2, 3).unique(:with(-> $a, $b { say "unique $a $b"; $a == $b + 1 }));
say @u;
my @s = (1, 2, 3, 7).squish(:with(-> $a, $b { say "squish $a $b"; $b == $a + 1 }));
say @s;
```
```output
unique 2 1
unique 3 1
[1 3]
squish 1 2
squish 2 3
squish 3 7
[1 7]
```

`unique` never compares 3 with 2, because 2 was dropped. `squish` compares 3
with 2, although 2 was dropped, so a whole run of consecutive numbers
collapses to its first.

## `pick` stops at the size of the list; `roll` can go on for ever

`pick` draws without replacement, so `pick(5)` from three elements gives
three, and `pick(0)` gives none. `roll` draws with replacement, and
`roll(*)` never stops. Code given as the count receives the number of
elements. An empty list gives Nil for a single draw; for several, `pick`
returns an empty List and `roll` an empty Seq:

```raku
say (1, 2, 3).pick(5).elems;
say (1, 2, 3).pick(* - 1).elems;
say (1, 2).roll(*).head(5).elems;
say (1, 2, 3).pick(0).raku;
say ().pick.raku;
say ().pick(3).raku;
say ().roll(3).raku;
```
```output
3
2
5
().Seq
Nil
()
().Seq
```

On a lazy list, `.pick` and `.roll` return a Failure and `.roll(n)` throws,
all with `X::Cannot::Lazy`.

## `combinations` leaves out sizes that cannot be made

`combinations(n)` gives every way of choosing n elements, in their original
order. A Range asks for several sizes at once, and sizes below zero or above
the length are left out; a single size that cannot be met gives an empty Seq.
An empty list has exactly one combination and one permutation, the empty one.
The subs take a number n to mean the list `^n`.

```raku
say (1, 2, 3).combinations(2);
say (1, 2, 3).combinations(-1..1);
say (1, 2, 3).combinations(2..5);
say (1, 2, 3).combinations(4).raku;
say ().combinations.raku;
say ().permutations.raku;
say combinations(3, 2);
say permutations(2);
```
```output
((1 2) (1 3) (2 3))
(() (1) (2) (3))
((1 2) (1 3) (2 3) (1 2 3))
().Seq
((),).Seq
((),).Seq
((0 1) (0 2) (1 2))
((0 1) (1 0))
```

## `pairup` keeps Pairs and pairs up everything else
tags: unasserted

`pairup` turns consecutive elements into key-value Pairs. An element that
already is a Pair is kept as it is, and a Hash spreads into its Pairs; an
itemized list is an ordinary element and becomes a key. An odd number of
elements is an error, but only when the result is read:

```raku
say (1, 2, 3, 4).pairup.raku;
say (a => 1, 2, 3).pairup.raku;
say ({ a => 1, b => 2 }, 3, 4).pairup.sort.raku;
say ($(a => 1, b => 2), 3).pairup.raku;
my $odd = (1, 2, 3).pairup;
say "built";
try { $odd.eager };
say $!.message;
```
```output
(1 => 2, 3 => 4).Seq
(:a(1), 2 => 3).Seq
(3 => 4, :a(1), :b(2)).Seq
((:a(1), :b(2)) => 3,).Seq
built
Odd number of elements found for .pairup()
```

## `toggle` switches between conditions, and stays put after the last

`toggle` lets elements through while it is *on*. It starts on and tests each
element with the first condition; the first element that fails switches it
off and is dropped, and the next condition then waits for an element that
passes, which switches it on again. Once the conditions run out, the last
state holds for the rest of the list. With `:off` it starts off, waiting for
the first condition to pass.

```raku
say (1..8).toggle(* < 3);
say (1..8).toggle(* < 3, * > 5);
say (1..8).toggle(* < 3, * > 2);
say (1..8).toggle(* > 5, :off);
say (1..8).toggle(* < 3, * > 5, :off);
```
```output
(1 2)
(1 2 6 7 8)
(1 2 4 5 6 7 8)
(6 7 8)
(1)
```

The third line shows that the element that switched `toggle` off, 3, is not
tested again by the next condition, although `3 > 2`.

## `rotor` cuts a list into pieces and drops a short last one

`rotor(n)` cuts a list into lists of n elements and drops what is left at
the end, unless `:partial` is given; `batch(n)` keeps it. A Pair `n => gap`
skips `gap` elements after each piece, and a negative gap makes the pieces
overlap. Several sizes are used in turn.

```raku
say (1..7).rotor(3);
say (1..7).rotor(3, :partial);
say (1..7).batch(3);
say (1..7).rotor(2 => 1);
say (1..6).rotor(3 => -1);
say (1..10).rotor(1, 2, 3);
```
```output
((1 2 3) (4 5 6))
((1 2 3) (4 5 6) (7))
((1 2 3) (4 5 6) (7))
((1 2) (4 5))
((1 2 3) (3 4 5))
((1) (2 3) (4 5 6) (7) (8 9))
```

In the last line the sizes 1, 2, 3 repeat, and the final 10 is dropped
because it does not fill a piece of size 3.

## `classify` builds a hash of arrays whose keys keep their type

`classify` calls its test on each element and puts the element into an
Array under the key the test returned. The result is an *object hash*, so
the keys keep their type: `(1, 2, 3).classify(* % 2)` has the Int keys 0
and 1. The test may also be a Hash or a List, looked up with each element.
`:as` transforms the stored values, not the keys, and a test that returns
several keys builds nested hashes, one level per key.

```raku
my %c = (1..6).classify({ $_ %% 2 ?? "even" !! "odd" });
say %c.sort;
say (1, 2, 3).classify(* % 2).keys.sort.map(*.^name);
say (1, 2, 3).classify(* % 2, :as(* * 10)).sort;
say (0, 1, 0).classify(<zero one>).sort;
my $nested = (1..4).classify({ $_ %% 2 ?? "even" !! "odd", $_ > 2 ?? "big" !! "small" });
say $nested<even><big>;
say $nested<odd>.sort;
```
```output
(even => [2 4 6] odd => [1 3 5])
(Int Int)
(0 => [20] 1 => [10 30])
(one => [1] zero => [0 0])
[4]
(big => [3] small => [1])
```

`:into` adds to an existing hash, appending to Arrays that are already there.
`categorize` is `classify` for a test that returns a list of keys, each of
which gets the element. Without a test, `classify` dies.

```raku
my %into = even => [0];
(1..4).classify({ $_ %% 2 ?? "even" !! "odd" }, :into(%into));
say %into.sort;
say (1..4).categorize({ $_ %% 2 ?? "even" !! "odd", $_ > 2 ?? "big" !! "small" }).sort;
try { (1, 2).classify };
say $!.message;
```
```output
(even => [0 2 4] odd => [1 3])
(big => [3 4] even => [2 4] odd => [1 3] small => [1 2])
Must specify something to classify with, a Callable, Hash or List
```

## `tree` turns nested lists into nested items
tags: unasserted

`.tree` rebuilds a nested list as nested Seqs, each one itemized, so that the
structure survives `flat` and list assignment. `tree(n)` goes n levels deep,
and `tree(0)` leaves the list alone. Given code, `tree` applies the first
block to the whole list, the second to each list one level down, and so on,
innermost first.

```raku
say (1, (2, 3)).tree.raku;
say (1, (2, 3)).tree(1).raku;
say (1, (2, 3)).tree(0).raku;
say (1, (2, 3)).flat.elems;
say (1, (2, 3)).tree.flat.elems;
my @whole = (1, (2, 3)).tree;
say @whole.elems;
say (1, (2, (3, 4))).tree(*.join("|"), *.join("-"), *.elems);
```
```output
$((1, $((2, 3).Seq)).Seq)
$((1, (2, 3)).Seq)
(1, (2, 3))
3
2
1
1|2-2
```

`flat` stops at the itemized inner Seq, and an array assignment takes the
whole tree as one item. In the last line `(3, 4)` becomes its count 2,
`(2, 2)` becomes `"2-2"`, and the outer list `"1|2-2"`.

## `.join` separates only the top-level elements

The separator goes between the elements of the list itself. A nested list is
turned into a string on its own, with spaces, like any list. The separator is
coerced to a string, and a hole in an array reads as the array's default: an
empty string, with a warning, for a plain array, and the declared value for
one with `is default`. (Undefined values in general are in [Nil, Any and the
Undefined](#ch:nil-any:join-of-one-value-is-its-string-undefined-joins-as-empty).)

```raku
say (1, (2, (3, 4))).join(",");
say ([1, 2], 3).join("-");
say (1, 2).join(3);
my Int @zeros is default(0);
@zeros[2] = 3;
say @zeros.join(",");
my @holes;
@holes[1] = 3;
say @holes.join(",");
```
```output
1,2 3 4
1 2-3
132
0,0,3
,3
```
```stderr
Use of uninitialized value of type Any in string context.
Methods .^name, .raku, .gist, or .say can be used to stringify it to something meaningful.
  in block <unit> at example.raku line 9
```

A Junction among the elements does not become a string. The whole `join`
runs once for each of its values, and the result is a Junction of strings:

```raku
say (1, any(2, 3)).join("-").raku;
say (1, 2).join(any("+", "-")).raku;
```
```output
any("1-2", "1-3")
any("1+2", "1-2")
```

## `.fmt` formats each element on its own

`.fmt` applies a `sprintf` format to every element separately and joins the
results with its second argument, a space by default. A nested list is
formatted element by element too, so it is flattened into the result. Since
each call sees one element, a format with two directives cannot work:

```raku
say (1, 2).fmt("%02d");
say (1, 2).fmt("%d", "-");
say (1, (2, 3)).fmt("<%s>", ",");
say (1, 2).fmt("%d%%");
say ().fmt("%d").raku;
try { (1, 2).fmt("%d and %d") };
say $!.message;
```
```output
01 02
1-2
<1>,<2>,<3>
1% 2%
""
Your printf-style directives specify 2 arguments, but 1 argument was supplied
```

## `.sum` counts a nested list instead of adding it
tags: quirk

`.sum` adds its elements as numbers, and a nested list used as a number is
its length. Nothing descends into the inner list:

```raku
say (1, 2, 3).sum;
say (1, (2, 3)).sum;
say (1, [10, 20, 30]).sum;
say (1, (2, 3)).flat.sum;
say (1, 2.5, 3/2).sum.raku;
say ().sum;
```
```output
6
3
4
6
5.0
0
```

Flatten first when the inner values should count. A sum of rational numbers
stays a `Rat`, and `.raku` writes the whole number 5 as `5.0`.

## `xx` evaluates its left side again for every repetition

`xx` repeats an expression, not a value: its left side is evaluated anew for
each element. A counter counts, and `[0, 0] xx 2` builds two separate
arrays. A variable that holds an array evaluates to the same array every
time, so its copies are all one object. A block on the left is a value like
any other, repeated without being called. What a sunk `xx` does is in [Values
Nobody Uses](#ch:sink:a-sunk-list-sinks-every-element-a-sunk-xx-sinks-none).

```raku
my $n = 0;
say ($n++ xx 3).raku;
my @rows = [0, 0] xx 2;
@rows[0][0] = 1;
say @rows.raku;
my $row = [0, 0];
my @shared = $row xx 2;
@shared[0][0] = 1;
say @shared.raku;
my @blocks = { say "called" } xx 2;
say @blocks.map(*.^name);
```
```output
(0, 1, 2).Seq
[[1, 0], [0, 0]]
[[1, 0], [1, 0]]
(Block Block)
```

A list on the left becomes one element of the result, a Slip is spread into
it, and a Seq is kept as a List so that each copy can be read more than
once. `xx` groups to the left, so `1 xx 2 xx 2` repeats the list `(1, 1)`:

```raku
say ((1, 2) xx 2).raku;
say ((1, 2).Slip xx 2).raku;
say ((1..2).map(* * 1) xx 2).raku;
say (1 xx 2 xx 2).raku;
```
```output
((1, 2), (1, 2)).Seq
(1, 2, 1, 2).Seq
((1, 2), (1, 2)).Seq
((1, 1), (1, 1)).Seq
```

## `xx` truncates its count, and `*` repeats without end

The right side of `xx` is a count. A fraction is truncated, a string is
converted to a number, `True` counts as 1, and zero or a negative count gives
an empty Seq. `*` or `Inf` makes an endless, lazy Seq that can be indexed and
taken from but not counted. A string that is not a number, and `NaN`, are
refused straight away.

```raku
say (1 xx 2.7).raku;
say (1 xx "2").raku;
say (1 xx True).raku;
say (1 xx -1).raku;
say (1 xx *).is-lazy;
say (1 xx *)[1000];
say (1 xx Inf).head(2).raku;
say (1 xx *).elems.^name;
try { my $s = 1 xx "b" };
say $!.^name;
try { my $s = 1 xx NaN };
say $!.^name;
```
```output
(1, 1).Seq
(1, 1).Seq
(1,).Seq
().Seq
True
1
(1, 1).Seq
Failure
X::Str::Numeric
X::Numeric::CannotConvert
```

`xx` with no operands at all, `infix:<xx>()`, is `X::NoZeroArgMeaning`.

## `x` repeats a string, and `x *` makes a WhateverCode

`x` turns its left side into a string and repeats it, so a list is repeated
as its space-separated string. The count is truncated as for `xx`, and zero
or a negative count gives an empty string. There is no endless string:
`x Inf` gives a Failure, and `x *` is not a repetition at all but a
WhateverCode that waits for its count. `x NaN` throws
`X::Numeric::CannotConvert`.

```raku
say 1 x 3;
say "ab" x 2.7;
say ("ab" x -1).raku;
say (1, 2) x 2;
my $f = "a" x Inf;
say $f.exception.message;
my $rep = "a" x *;
say $rep(3);
```
```output
111
abab
""
1 21 2
Cat object not yet implemented. Sorry.
aaa
```

## `Z` stops at the shortest list; `X` is lazy if any operand is

`Z` zips lists into tuples and stops when the shortest list runs out, so an
infinite list can be zipped with a finite one. `X` builds every combination,
varying the last list fastest. Both accept an operator, which is applied to
each tuple, and both return a Seq. `roundrobin` interleaves like `Z` but goes
on with the longer lists, and `:slip` flattens its tuples.

```raku
say (1, 2, 3) Z (4, 5);
say (1..*) Z <a b>;
say (1, 2) Z+ (10, 20, 30);
say (1, 2) X <a b>;
say (1, 2) X~ <a b>;
say roundrobin((1, 2, 3), (4, 5));
say roundrobin((1, 2, 3), (4, 5), :slip);
say ((1, 2) Z ()).raku;
```
```output
((1 4) (2 5))
((1 a) (2 b))
(11 22)
((1 a) (1 b) (2 a) (2 b))
(1a 1b 2a 2b)
((1 4) (2 5) (3))
(1 4 2 5 3)
().Seq
```

Laziness follows from those rules: `Z` is lazy only when every operand is,
and `X` whenever any operand is. A cross with an infinite last list can be
taken from, but it never gets past the first element of the lists before it:

```raku
say ((1, 2) Z (1..*)).is-lazy;
say ((1..*) Z (1..*)).is-lazy;
say ((1, 2) X (1..*)).is-lazy;
say ((1, 2) X (1..*)).head(3);
say [Z] (1, 2), (3, 4), (5, 6);
```
```output
False
True
True
((1 1) (1 2) (1 3))
((1 3 5) (2 4 6))
```

The last line reduces with `Z`, which transposes a list of rows.

## A list pattern matches element by element, with `*` and `**` as wildcards

Smartmatching a list against a list compares element by element, each with
the pattern element's own `ACCEPTS`, so a type in the pattern matches any
value of that type. `*` in the pattern matches exactly one element and `**`
any run of them. A Seq matches the same way, but a lazy one never matches. A
value that is not a list does not match a list pattern, even one that
contains it.

```raku
say (1, 2, 3) ~~ (1, *, 3);
say (1, 2, 3, 4) ~~ (1, **, 4);
say (1, 2, 3) ~~ (Int, Str, Int);
say (1, 2) ~~ (1, 2, 3);
say (1, 2).Seq ~~ (Int, Int);
say (Int, Int).Seq ~~ (1, 2);
say (1..*).map(* + 0) ~~ (1, 2);
say 42 ~~ (1, 42);
```
```output
True
True
False
False
True
False
False
False
```

## A Range on the right of `~~` checks a list's length
tags: trap

A Range is not a list pattern. It accepts a number that lies inside it, and
a list used as a number is its length, so a list matches a Range when its
length falls in the range, whatever its elements are:

```raku
say (5, 6) ~~ 1..2;
say [7, 8, 9] ~~ 1..3;
say (1, 2, 3, 4) ~~ 1..3;
say (1, 2).Seq ~~ 1..*;
say (5, 6) ~~ (1..2).list;
```
```output
True
True
False
True
False
```

Turning the Range into a list with `.list` makes an element-by-element
pattern of it. The other things a Range accepts are in [Ranges](#ch:ranges).

## Arrays and lists are identical only to themselves

`===` asks whether two values are the same object, and an Array or a List is
only ever the same as itself, so two equal literals are not `===`. `eqv`
compares structure, and it compares types as well: an Array is never `eqv`
to a List or a Seq with the same elements. Smartmatch compares element by
element, and `==` compares lengths. `.unique` uses `===` unless told
otherwise:

```raku
say [1, 2] === [1, 2];
say (1, 2) === (1, 2);
say [1, [2]] eqv [1, [2]];
say [1, 2] eqv (1, 2);
say (1, 2) eqv (1, 2).Seq;
say [1, 2] ~~ (1, 2);
say ((1, 2), (1, 2)).unique.elems;
say ((1, 2), (1, 2)).unique(:with(&[eqv])).elems;
```
```output
False
False
True
False
False
True
2
1
```
