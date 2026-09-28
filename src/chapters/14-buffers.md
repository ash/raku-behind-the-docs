---
title: Blobs and Bufs
part: Collections
summary: A Blob is an immutable run of native integers and a Buf a mutable one; they index like arrays but are neither lists nor strings, compare and print in their own way, and carry the encoders, decoders and binary readers.
---

A **Blob** holds a fixed run of native integers, bytes unless its type says
otherwise, and never changes. A **Buf** is the same thing made mutable: its
elements can be assigned, pushed, spliced and overwritten with binary
numbers. Buffers are what `encode` returns and what `decode` reads, and what
a binary read from a file gives back. They index like arrays, but they are
neither lists nor strings, and much of this chapter is about the places where
that shows: which operators walk through a buffer, which take it as one item,
and which refuse it.

What `encode` does to the text, composition and unencodable characters
included, is in [Strings](#ch:strings:encode-composes-first-and-refuses-what-it-cannot-encode);
this chapter takes up the buffer that comes back. The precedence of the
bitwise operators is in [Who Takes the
Operand](#ch:precedence:the-ladder-from-tightest-to-loosest). `say` shows a
buffer as a hex dump, so the examples print `.raku` or `.list` wherever the
exact type or the values matter.

## `blob8` and `buf16` are short names for parameterised roles

`Blob` and `Buf` are roles that take the element type as a parameter, `uint8`
unless one is given. `blob8`, `blob16`, `blob32` and `blob64`, and `buf8` to
`buf64`, are constants that name the unsigned parameterisations, and `.^name`
gives the long form. `Buf` does `Blob`, so every Buf is a Blob, but not the
other way round. `utf8`, `utf16` and `utf32` are classes built on
`Blob[uint8]`, `Blob[uint16]` and `Blob[uint32]`: what `encode` returns is a
`blob8` that cannot be changed.

```raku
say blob8.^name;
say blob8 === Blob[uint8];
say buf16.^name;
say Buf ~~ Blob;
say Blob ~~ Buf;
say utf8 ~~ blob8;
say utf8 ~~ Buf;
say Buf[int32].of.^name;
```
```output
Blob[uint8]
True
Buf[uint16]
True
False
True
False
int32
```

`.of` gives the element type.

## A plain `Blob` is not a `blob8`
tags: quirk

`Blob.new` builds a buffer of bytes, as `blob8.new` does, but the two are
different types. The instance of the plain role is named `Blob`, prints as
`Blob.new(…)` and does not match `blob8`, while a `blob8` matches `Blob`, as
every parameterisation does. The instance's type is not even the `Blob` type
object:

```raku
say Blob.new(1).^name;
say Blob.new(1).raku;
say blob8.new(1).raku;
say Blob.new(1) ~~ blob8;
say blob8.new(1) ~~ Blob;
say Blob.new(1).WHAT === Blob;
```
```output
Blob
Blob.new(1)
Blob[uint8].new(1)
False
True
False
```

A `blob8` parameter therefore refuses a plain `Blob.new(…)` ([below](#ch:buffers:blob-coerces-through-new-buf-and-blob-copy)).
`Blob` is the type to ask for when any buffer will do.

## A buffer is Positional and Stringy, but not a list

A buffer does the `Positional` role, so it can be indexed and bound to an `@`
variable, and the `Stringy` role, which `~` between two buffers relies on. It
is not `Iterable` and not a `List`. It is not `Cool` either, so the string
and number methods that most built-in values share are missing; only the
`Blob` type object answers True to `~~ Cool`.

```raku
my $b = Blob.new(1, 2);
say $b ~~ Positional;
say $b ~~ Stringy;
say $b ~~ Iterable;
say $b ~~ Cool;
say Blob ~~ Cool;
say $b ~~ Positional[uint8];
```
```output
True
True
False
False
True
True
```

## Only native integers can be elements

The type parameter must be a native integer type. Any other type is accepted
where the name is written, so `Blob[Int]` compiles and has a name, but the
first use of it dies with `X::Role::Instantiation`. `int` and `uint` are
accepted and store 64 bits.

```raku
say Blob[Int].^name;
try { Blob[Int].new(1) };
say $!.^name;
say $!.message.lines[2].trim;
say Blob[int].new(-1).raku;
say Blob[uint].new(2**64 - 1).list;
```
```output
Blob[Int]
X::Role::Instantiation
Can only parameterize with native int types, not 'Int'.
Blob[int].new(-1)
(18446744073709551615)
```

## `.new` flattens lists and ranges, and accepts only integers

`.new` takes its arguments as one flat list of elements: an Array, nested
lists and ranges are all spread. Every element must be an integer. A `Bool`
counts as one, and so does an allomorph from `< >`.

```raku
say Blob.new(1, 2, 3).raku;
say Blob.new([1, 2, 3]).raku;
say Blob.new((1, 2), (3, 4)).raku;
say Blob.new(1..3, 5).raku;
say Blob.new(<1 2>).raku;
say Blob.new(True).raku;
```
```output
Blob.new(1,2,3)
Blob.new(1,2,3)
Blob.new(1,2,3,4)
Blob.new(1,2,3,5)
Blob.new(1,2)
Blob.new(1)
```

Anything else throws `X::TypeCheck`, a string of digits included. Its
`operation` names the position of the offending element, `got` holds it and
`expected` is the element type. A lazy list throws `X::Cannot::Lazy`.

```raku
try { Blob.new(1, 2, "3") };
say $!.^name;
say $!.operation;
say $!.got.raku;
say $!.expected.^name;
try { Blob.new(1.5) };
say $!.^name;
try { Blob.new(1..*) };
say $!.^name;
```
```output
X::TypeCheck
initializing element #2 to Blob
"3"
uint8
X::TypeCheck
X::Cannot::Lazy
```

## A value too wide for the element wraps around
tags: undocumented unasserted

Elements are stored modulo the width of the element type: 256 in a byte is 0,
-1 is 255, and 128 in an `int8` is -128. Building one buffer from another of
a different type goes through the same narrowing, value by value. Only a
value that does not fit a native 64-bit integer at all is refused, with an
`X::AdHoc` from the virtual machine. Elements always read back as `Int`.

```raku
say blob8.new(256, 300, -1).list;
say Blob[int8].new(127, 128, 200).list;
say blob16.new(65536, -1).list;
say Blob.new(blob16.new(300)).raku;
say buf16.new(Blob[int8].new(-1)).raku;
try { blob64.new(2**64) };
say $!.message;
say Blob[int8].new(-1)[0].^name;
```
```output
(0 44 255)
(127 -128 -56)
(0 65535)
Blob.new(44)
Buf[uint16].new(65535)
Cannot unbox 65 bit wide bigint into native integer. Did you mix int and Int or literals?
Int
```

The `int8` -1 copied into a 16-bit buffer becomes 65535, not 255: the value
-1 is narrowed to the new width, not the old bits.

## `.bytes` of a `Blob[int]` counts one byte per element
tags: bug unasserted

The documentation says `.bytes` returns the number of bytes used by the
elements: their number times 1, 2, 4 or 8, and 24 for three elements of a
`blob64`. `Blob[int]` and `Blob[uint]` store 64 bits per element, as the hex
dump shows, but Rakudo 2026.08 counts one byte for each, where a `buf64` of
the same two values counts 16:

```raku
say buf8.new(1, 2).bytes;
say buf16.new(1, 2).bytes;
say buf64.new(1, 2).bytes;
say Blob[int].new(1, 2).bytes;
say Blob[uint].new(1, 2).bytes;
say Blob[int].new(1, 2);
```
```output
2
4
16
2
2
Blob[int]:0x<0000000000000001 0000000000000002>
```

## `allocate` fills with a value or repeats a pattern

`allocate(n)` makes a buffer of n zeros. A second argument fills it: an
integer is repeated, wrapped to the width like any element, and a list, an
Array or another buffer is repeated as a pattern and cut off at n elements.

```raku
say Blob.allocate(3).raku;
say Blob.allocate(3, 42).raku;
say Blob.allocate(3, 256).raku;
say Blob.allocate(5, (1, 2)).raku;
say Blob.allocate(4, Blob.new(1, 2, 3)).raku;
say Blob.allocate(2, (1, 2, 3)).raku;
say blob16.allocate(2, 70000).list;
say Buf.allocate(2).^name;
```
```output
Blob.new(0,0,0)
Blob.new(42,42,42)
Blob.new(0,0,0)
Blob.new(1,2,1,2,1)
Blob.new(1,2,3,1)
Blob.new(1,2)
(4464 4464)
Buf
```

The errors come in three kinds. A fill value that is not an integer gives a
Failure, while a bad element inside a pattern throws at once. A negative
count dies with an `X::AdHoc` whose message shows it read as an unsigned
number. A fractional count, and `allocate` called on an instance, find no
candidate at all.

```raku
my $f = Blob.allocate(2, "x");
say $f.^name;
say $f.exception.operation;
try { Blob.allocate(2, (1, "x")) };
say $!.^name;
try { Blob.allocate(-1) };
say $!.message;
try { Blob.allocate(2.7) };
say $!.^name;
try { Blob.new(1).allocate(2) };
say $!.^name;
```
```output
Failure
allocate to Blob
X::TypeCheck
Unable to allocate an array of 18446744073709551615 elements
X::Multi::NoMatch
X::Multi::NoMatch
```

## `allocate` with an empty pattern never returns
tags: bug

The documentation says the pattern is repeated until the buffer is full. An
empty list has nothing to repeat, and in Rakudo 2026.08 the call never
returns, running until it is killed:

```raku nocheck
say Blob.allocate(3, ()).raku;
```

## `say` prints a buffer in hex, and `~` refuses it

The gist of a buffer is its type name, `:0x`, and the elements in upper-case
hex between angle brackets: two digits for a byte, four for a 16-bit element,
and so on, with a negative element in two's complement. `.raku` gives the
constructor call with decimal values and no spaces.

```raku
say Blob.new(1, 2, 255);
say buf8.new(10);
say blob16.new(1);
say Blob[int8].new(-1, 127);
say utf8.new(97, 98);
say Blob.new(1, 2).raku;
say Blob.new;
```
```output
Blob:0x<01 02 FF>
Buf[uint8]:0x<0A>
Blob[uint16]:0x<0001>
Blob[int8]:0x<FF 7F>
utf8:0x<61 62>
Blob.new(1,2)
Blob:0x<>
```

A buffer is a run of numbers, not text, and Rakudo does not guess an
encoding. `.Str`, prefix `~`, interpolation and `.chars` throw
`X::Buf::AsStr`, whose message points to `decode` and whose `method` names
what was called. Methods such as `uc` do not exist on a buffer at all:

```raku
my $b = Blob.new(97);
try { say ~$b };
say $!.^name;
say $!.message;
try { $b.chars };
say $!.method;
try { $b.uc };
say $!.^name;
say $b.decode;
```
```output
X::Buf::AsStr
Stringification of a Blob is not done with 'Stringy', which the '~'
operator uses. The 'decode' method should be used to convert a Blob to a
Str.
chars
X::Method::NotFound
a
```

The `utf8` and `utf16` buffers are the exception: they decode themselves
([below](#ch:buffers:a-utf8-becomes-its-text-wherever-a-string-is-wanted)).

## The hex dump stops after 200 digits

`say` shows at most 200 hex digits of a buffer, followed by ` ...`: 100
elements of a byte buffer, 50 of a 16-bit one, 12 of a 64-bit one. `.raku` is
never shortened.

```raku
say Blob.new(1..100).gist.words.elems;
say Blob.new(1..101).gist.words.elems;
say Blob.new(1..101).gist.substr(*-12);
say blob16.new(1..51).gist.words.elems;
say blob64.new(1..13).gist.words.elems;
say Blob.new(1..1000).gist.chars;
say Blob.new(1..1000).raku.chars;
```
```output
100
101
2 63 64 ...>
51
13
312
3571
```

## Two equal Blobs are one value; two equal Bufs are not
tags: undocumented

A Blob cannot change, so Rakudo treats it as a value: its identity is
computed from its type and its contents. Two Blobs with the same elements are
`===`, and `unique`, a Set or an object hash counts them once. A Buf can
change, so each one is an object of its own, as arrays are ([Lists, Arrays,
Seqs and Slips](#ch:lists:arrays-and-lists-are-identical-only-to-themselves)).

```raku
say Blob.new(1, 2) === Blob.new(1, 2);
say Buf.new(1, 2) === Buf.new(1, 2);
say (Blob.new(1), Blob.new(1)).unique.elems;
say (Buf.new(1), Buf.new(1)).unique.elems;
say set(Blob.new(1), Blob.new(1)).elems;
my %h{Any};
%h{Blob.new(1)} = "first";
%h{Blob.new(1)} = "second";
say %h.elems;
say Blob.new(1).WHICH.^name;
say Buf.new(1).WHICH.^name;
```
```output
True
False
1
2
1
1
ValueObjAt
ObjAt
```

## `eqv` wants the same type, `eq` compares values, `==` counts
tags: undocumented

`eqv` is True only for two buffers of the same type with the same elements:
a `Blob` and a `blob8` holding the same bytes are not `eqv`, nor are a Blob
and a Buf. `eq` compares the elements' values across any two buffer types,
so an `int8` holding -1 is not `eq` a byte holding 255, although both are
the bits FF. `==` numifies both sides, and a buffer's number is its count of
elements, so it compares lengths. `<` has no candidate for buffers at all.

```raku
say Blob.new(1, 2) eqv Blob.new(1, 2);
say Blob.new(1, 2) eqv blob8.new(1, 2);
say Blob.new(1, 2) eqv Buf.new(1, 2);
say Blob.new(1, 2) eq Buf.new(1, 2);
say Blob.new(1, 2) eq blob16.new(1, 2);
say Blob[int8].new(-1) eq blob8.new(255);
say Blob.new(1, 2) == Blob.new(8, 9);
try { Blob.new(1) < Blob.new(1, 2) };
say $!.^name;
```
```output
True
False
False
True
True
False
True
X::Multi::NoMatch
```

An ordinary hash turns its keys into strings, which a buffer refuses; an
object hash, `%h{Any}` as in the previous corner, keeps a Blob key as it is.
A `utf8` key becomes its text:

```raku
my %h;
try { %h{Blob.new(97)} = 1 };
say $!.^name;
%h{utf8.new(97)} = 1;
say %h.keys.raku;
```
```output
X::Buf::AsStr
("a",).Seq
```

## `cmp` compares lengths before contents
tags: quirk undocumented

`cmp` between two buffers, and with it `lt`, `gt`, `before`, `sort` and
`max`, first compares the numbers of elements; only buffers of equal length
are compared element by element. So a one-element buffer sorts before any
two-element one, whatever the bytes are, which is not the order of the
strings the bytes might encode:

```raku
say Blob.new(1, 2, 4) cmp Blob.new(1, 2, 3);
say Blob.new(2) cmp Blob.new(1, 9, 9);
say Blob.new(1, 3) gt Blob.new(1, 2, 9);
say Blob.new cmp Blob.new(0);
say (Blob.new(9), Blob.new(1, 1)).sort.raku;
say (Blob.new(9), Blob.new(1, 1)).max.raku;
```
```output
More
Less
False
Less
(Blob.new(9), Blob.new(1,1)).Seq
Blob.new(1,1)
```

`cmp` also wants both sides to be of the same type, although `eq` does not
mind. A buffer against a string is refused, except for a `utf8`, which
compares as its text; `<=>` has no candidate, and `leg` wants strings:

```raku
say Blob.new(1) eq blob8.new(1);
try { Blob.new(1) cmp blob8.new(1) };
say $!.^name;
try { Blob.new(97) cmp "a" };
say $!.^name;
try { Blob.new(1, 2) <=> Blob.new(1, 2) };
say $!.^name;
try { Blob.new(1, 2) leg Blob.new(1, 2) };
say $!.^name;
say utf8.new(97) cmp "b";
```
```output
True
X::TypeCheck::Binding::Parameter
X::Buf::AsStr
X::Multi::NoMatch
X::Buf::AsStr
Less
```

## A buffer is its number of elements in numeric context

A buffer is true when it has at least one element, even if every element is
zero. As a number it is its count of elements, which is what `+`, `*`, `==`
and a smartmatch against a number see. `.sum` adds the elements themselves.
`<` and `%` have no candidate for a buffer, `.Num` does not exist, and `max`
against a number compares strings, which a buffer refuses.

```raku
say ?Blob.new;
say ?Blob.new(0);
my $b = Blob.new(10, 20, 30);
say +$b;
say $b + 1;
say $b * $b;
say $b.sum;
say $b ~~ 3;
try { $b < 5 };
say $!.^name;
try { $b.Num };
say $!.^name;
try { $b max 5 };
say $!.^name;
```
```output
False
True
3
4
9
60
True
X::Multi::NoMatch
X::Method::NotFound
X::Buf::AsStr
```

## Smartmatching a buffer compares its elements, across types
tags: undocumented

Two buffers smartmatch when they have the same length and each pair of
elements is `==`, whatever the two types are; as with `eq`, an `int8` -1 is
not a byte 255. A list on the right never matches, since a buffer is not a
list. A number on the right compares the count, and a Set compares the
elements as a set. A string on the right does not match a plain buffer,
while a `utf8` compares as its text.

```raku
say Blob.new(1, 2) ~~ Buf.new(1, 2);
say Blob.new(1) ~~ blob16.new(1);
say Blob[int8].new(-1) ~~ blob8.new(255);
say Blob.new(1, 2) ~~ (1, 2);
say Blob.new(1, 2) ~~ 2;
say Blob.new(97) ~~ "a";
say utf8.new(97) ~~ "a";
say Blob.new(1, 2) ~~ set(1, 2);
```
```output
True
True
False
False
True
False
True
True
```

Against a type, a buffer matches its role and its own parameterisation: a
`utf8` from `encode` is a `blob8`, a plain `Blob.new` is not
([above](#ch:buffers:a-plain-blob-is-not-a-blob8)).

```raku
say Blob.new(1) ~~ Blob;
say Blob.new(1) ~~ blob8;
say "a".encode ~~ blob8;
say Blob.new(1) ~~ Buf;
say Buf.new(1) ~~ Blob;
```
```output
True
False
True
False
True
```

## A regex against a buffer matches one element's digits
tags: trap undocumented

A regex on the right of `~~` is not applied to the bytes, nor to the text
they encode. It is tried against the decimal digits of each element in turn,
and the first element that matches gives the Match. The element 10 matches
`/10/`, not `/0A/`, and two elements are never seen together. A `utf8` is
not decoded for this either:

```raku
say (Blob.new(10, 11) ~~ /.+/).Str;
say so Blob.new(1, 2) ~~ /12/;
say so Blob.new(0x0A) ~~ /10/;
say so Blob.new(0x0A) ~~ /0A/;
say so utf8.new(97) ~~ /a/;
say so utf8.new(97) ~~ /97/;
```
```output
10
False
True
False
False
True
```

Decode the buffer first to match text.

## A Blob refuses every change, each with its own exception

Assigning to an element of a Blob throws `X::Assignment::RO`, and assigning
past its end `X::OutOfRange`. The list mutators `push`, `append`, `unshift`,
`prepend` and `splice` exist for any value but have no candidate for a Blob,
so they throw `X::Multi::NoMatch`, as does `++` on an element; `pop` and
`shift` are not there at all. `:delete` returns a Failure. The variable that
holds the Blob can still be given a new one.

```raku
my $b = Blob.new(1, 2, 3);
try { $b[0] = 5 };
say $!.^name;
try { $b[5] = 5 };
say $!.^name;
try { $b.push(4) };
say $!.^name;
try { $b.pop };
say $!.^name;
try { $b[0]++ };
say $!.^name;
say ($b[0]:delete).exception.message;
$b = Blob.new(9);
say $b.raku;
```
```output
X::Assignment::RO
X::OutOfRange
X::Multi::NoMatch
X::Method::NotFound
X::Multi::NoMatch
Can not remove elements from a Blob
Blob.new(9)
```

A Buf made from the Blob, with `.Buf` ([below](#ch:buffers:blob-coerces-through-new-buf-and-blob-copy)),
can be changed.

## A Blob index past the end is a Failure; a slice past the end throws
tags: undocumented

Reading one element past the end of a Blob, or at a negative index, returns
a Failure carrying `X::OutOfRange`, unlike an array, which answers `Any`. A
slice that reaches past the end does not return Failures in those positions;
it throws. `:exists` is False past the end, and a slice with an endless range
stops at the last element. The elements themselves are plain values, so
assigning through `.list` is refused too.

```raku
my $b = Blob.new(5, 6);
my $i = -1;
say $b[2].^name;
say $b[2].exception.message;
say $b[$i].exception.message;
try { $b[0, 5] };
say $!.message;
say $b[5]:exists;
say $b[0..*].raku;
try { $b.list[0] = 9 };
say $!.^name;
```
```output
Failure
Index out of range. Is: 2, should be in 0..1
Index out of range. Is: -1, should be in 0..1
Index out of range. Is: 5, should be in 0..1
False
(5, 6)
X::Assignment::RO
```

## A Buf reads zeros past its end, and grows when written there

Assigning to an element of a Buf stores the integer modulo the width, `True`
as 1. Assigning past the end grows the buffer and fills the gap with zeros.
Reading past the end gives 0 and does not grow it, even in a slice. A
fractional index is truncated and a string index converted, as for arrays.

```raku
my $b = Buf.new(1, 2, 3);
$b[0] = 256;
$b[1] = -1;
$b[2] = True;
say $b.raku;
$b[5] = 7;
say $b.raku;
say $b[20];
say $b[4..8].raku;
say $b.elems;
say $b[1.7];
say $b["2"];
```
```output
Buf.new(0,255,1)
Buf.new(0,255,1,0,0,7)
0
(0, 7, 0, 0, 0)
6
255
1
```

Only an integer can be stored. A string, even `"7"`, a Rat or Nil throws an
`X::AdHoc` from the virtual machine. A negative index gives a Failure, for
reading and for writing alike, and `Inf` cannot be an index:

```raku
my $b = Buf.new(1, 2, 3);
my $i = -1;
say $b[$i].^name;
say ($b[$i] = 5).^name;
try { $b[0] = "7" };
say $!.message;
try { $b[0] = Nil };
say $!.message;
try { $b[Inf] };
say $!.^name;
say $b.raku;
```
```output
Failure
Failure
This type cannot unbox to a native unsigned integer: P6opaque, Str
Cannot unbox a type object (Nil) to an unsigned int.
X::Numeric::CannotConvert
Buf.new(1,2,3)
```

## Every element view of a Buf writes back into it
tags: quirk undocumented

The elements that a Buf hands out are not copies. `.list`, `.sort`, `.head`,
`.grep`, `.values`, the topic of a `for` over `.list` or `@$buf`, and a
variable bound to `$buf[i]` all refer to places in the buffer: assigning to
them changes the buffer, wrapping the value to the width. A bound element
stays attached after the buffer grows.

```raku
my $b = Buf.new(1, 2, 3);
for $b.list { $_ *= 10 }
say $b.raku;
$b.sort[0] = 7;
say $b.raku;
$b.head = 300;
say $b.raku;
my $r := $b[1];
$b.push(4);
$r = 99;
say $b.raku;
```
```output
Buf.new(10,20,30)
Buf.new(7,20,30)
Buf.new(44,20,30)
Buf.new(44,99,30,4)
```

`.sort[0] = 7` sorted the elements and then wrote to the smallest of them,
which was the 10 in position 0. `.Array` and assignment to an array make
copies. Assigning a Buf to a second `$` variable does not copy it: both
variables hold the same buffer. A `map` block that assigns to its topic
changes the buffer too. A Blob's elements are plain values, so all of this
is refused on a Blob.

```raku
my $b = Buf.new(1, 2);
$b.Array[0] = 9;
say $b.raku;
my @copy = $b.list;
@copy[0] = 9;
say $b.raku;
my $c = $b;
$c[0] = 5;
say $b.raku;
$b.map({ $_ = 0 });
say $b.raku;
```
```output
Buf.new(1,2)
Buf.new(1,2)
Buf.new(5,2)
Buf.new(0,0)
```

Use `.clone`, `.subbuf` or `Buf.new($b)` for an independent copy.

## `push` takes values; `append` also spreads a list

`push` and `unshift` take integers, buffers, or a Slip of integers. A single
list argument is not spread: it is refused, with a Failure carrying
`X::TypeCheck`. `append` and `prepend` also spread one list, Array or Range.
All four return the buffer, and the values wrap to the width.

```raku
my $b = Buf.new(1);
$b.push(2, 3);
$b.push(Blob.new(4, 5));
$b.push(|(6, 7));
say $b.raku;
my $f = $b.push((8, 9));
say $f.^name;
say $f.exception.message;
$b.append((8, 9));
$b.append(10..11);
say $b.raku;
say $b.push(300) === $b;
say $b.tail;
```
```output
Buf.new(1,2,3,4,5,6,7)
Failure
Type check failed in push to Buf; expected uint8 but got List ((8, 9))
Buf.new(1,2,3,4,5,6,7,8,9,10,11)
True
44
```

`pop` and `shift` return the element. On an empty Buf they return a Failure
carrying `X::Cannot::Empty`, as they do on an empty array, and `append`
refuses a lazy list with a Failure:

```raku
my $e = Buf.new;
my $f = $e.pop;
say $f.^name;
say $f.exception.message;
say $e.shift.exception.^name;
say $e.append(1..*).exception.^name;
my $b = Buf.new(1, 2);
say $b.pop;
say $b.shift;
say $b.raku;
```
```output
Failure
Cannot pop from an empty Buf
X::Cannot::Empty
X::Cannot::Lazy
2
1
Buf.new()
```

## A bad value among several grows the Buf, then throws
tags: bug

A single bad argument to `push` returns a Failure and leaves the buffer as it
was. Among several arguments, Rakudo 2026.08 throws at the bad one, but only
after the buffer has grown by one slot for each argument before it and one
for itself, the latter holding 0, a value no argument asked for. An integer
too large for a native integer does the same. The one-argument and the
several-argument forms of the call disagree, and `splice` with a bad element
in its list ([below](#ch:buffers:splice-removes-inserts-and-pads-past-the-end))
leaves the buffer as it was:

```raku
my $b = Buf.new(7, 7);
try { $b.push(1, "x") };
say $!.^name;
say $b.raku;
my $f = $b.push("x");
say $f.^name;
say $b.raku;
try { $b.append(5, 2**70) };
say $!.^name;
say $b.raku;
```
```output
X::TypeCheck
Buf.new(7,7,1,0)
Failure
Buf.new(7,7,1,0)
X::AdHoc
Buf.new(7,7,1,0,5,0)
```

## `splice` removes, inserts, and pads past the end
tags: quirk

`splice(offset, size, replacement)` removes `size` elements at `offset` and
returns them as a buffer of the same type. The size may be left out or `*`
for the rest of the buffer, and a fraction is truncated. The replacement may
be an integer, a buffer or a list of integers.

```raku
my $b = Buf.new(1, 2, 3, 4, 5);
say $b.splice(1, 2).raku;
say $b.raku;
say $b.splice(1, 1, Blob.new(8, 8)).raku;
say $b.raku;
say $b.splice(0, 1, (6, 6)).raku;
say $b.raku;
say $b.splice(3).raku;
say $b.raku;
say $b.splice(1, 1.9).raku;
say $b.raku;
```
```output
Buf.new(2,3)
Buf.new(1,4,5)
Buf.new(4)
Buf.new(1,8,8,5)
Buf.new(1)
Buf.new(6,6,8,8,5)
Buf.new(8,5)
Buf.new(6,6,8)
Buf.new(6)
Buf.new(6,8)
```

An offset past the end with a size of 0 pads the buffer with zeros up to the
offset before inserting. `splice` with no arguments at all behaves in two
ways. On a Buf in a variable it returns the buffer itself and puts a new,
empty Buf into the variable. On a Buf with no container, bound to a
sigilless name or with `:=`, it empties that buffer and returns it, empty:

```raku
my $b = Buf.new(1, 2, 3);
my $orig = $b;
say $b.splice.raku;
say $b.raku;
say $orig.raku;
my $c := Buf.new(1, 2, 3);
say $c.splice.raku;
my $d = Buf.new(1, 2);
say $d.splice(5, 0, 9).raku;
say $d.raku;
```
```output
Buf.new(1,2,3)
Buf.new()
Buf.new(1,2,3)
Buf.new()
Buf.new()
Buf.new(1,2,0,0,0,9)
```

A replacement that is not an integer returns a Failure, a bad element inside
a list throws, and either way the buffer is left alone. A string offset has
no candidate:

```raku
my $b = Buf.new(1, 2, 3);
my $f = $b.splice(1, 1, "x");
say $f.exception.message;
try { $b.splice(1, 1, (1, "x")) };
say $!.^name;
say $b.raku;
try { $b.splice("1", 1) };
say $!.^name;
```
```output
Type check failed in splice to Buf; expected uint8 but got Str ("x")
X::TypeCheck
Buf.new(1,2,3)
X::Multi::NoMatch
```

## A failed `splice` still changes the Buf
tags: bug

An offset past the end with a nonzero size, a negative offset and a negative
size are out of range, and `splice` returns a Failure carrying
`X::OutOfRange`. Its message names another method, `subbuf`, one of them with
a stray quote at the front. A bad replacement, above, returns a Failure and
leaves the buffer alone; these three return a Failure and, in Rakudo 2026.08,
change the buffer as well. The offset past the end pads the buffer up to the
offset, a negative offset removes the element that many places from the end,
as a Perl programmer might expect, and a negative size makes the buffer
longer, at offset 0 by a leading zero.

```raku
my $b = Buf.new(1, 2, 3);
my $f = $b.splice(5, 1);
say $f.exception.message;
say $b.raku;
my $c = Buf.new(1, 2, 3);
say $c.splice(-1, 1).^name;
say $c.raku;
my $d = Buf.new(1, 2, 3);
say $d.splice(0, -1).exception.message;
say $d.raku;
```
```output
"From argument to subbuf out of range. Is: 5, should be in 0..3
Buf.new(1,2,3,0,0)
Failure
Buf.new(1,2)
Len element to subbuf out of range. Is: -1, should be in 0..3
Buf.new(0,1,2,3)
```

An infinite list as the replacement is not refused as lazy, and the call
never returns, running until it is killed:

```raku nocheck
my $b = Buf.new(1, 2, 3);
say $b.splice(0, 2, 1..*).raku;
```

## `is buf8` makes an array variable a Buf
tags: undocumented

`my @a is buf8` declares an `@` variable whose container is a `Buf[uint8]`.
Assigning a list to it stores the values, wrapped to the width, and `push`
wraps as well. `is blob8` gives a Blob, which takes its first assignment and
refuses any later one. A lazy list is refused.

```raku
my @a is buf8 = 1, 2, 300;
say @a.raku;
@a = 7, 8;
say @a.raku;
@a.push(256);
say @a.raku;
my @b is blob8 = 1, 2;
say @b.raku;
try { @b = 3 };
say $!.^name;
try { my @c is buf8 = 1..* };
say $!.^name;
```
```output
Buf[uint8].new(1,2,44)
Buf[uint8].new(7,8)
Buf[uint8].new(7,8,0)
Blob[uint8].new(1,2)
X::Assignment::RO
X::Cannot::Lazy
```

A `$` variable typed `Blob` takes any buffer, a Buf or a `utf8` included. A
more specific type is strict: a `buf8` variable refuses a plain `Buf.new`, a
`utf8` one refuses the `Blob[uint8]` that `encode("ascii")` returns, and no
buffer variable takes an Array.

```raku
my Blob $x = "hi".encode;
say $x.^name;
my Blob $y = Buf.new(1);
say $y.^name;
try { my buf8 $z = Buf.new(1) };
say $!.^name;
try { my utf8 $u = "a".encode("ascii") };
say $!.^name;
try { my Blob $w = [1, 2] };
say $!.^name;
```
```output
utf8
Buf
X::TypeCheck::Assignment
X::TypeCheck::Assignment
X::TypeCheck::Assignment
```

## `subbuf` takes a start and a length, a range, or code

`subbuf` returns a part of a buffer as a new buffer of the same type. It
takes a start and an optional length, a Range, or WhateverCode for either
number. A length that runs past the end is cut short, a fractional length is
truncated, and a start equal to the length gives an empty buffer.

```raku
my $b = Blob.new(^10);
say $b.subbuf(7).raku;
say $b.subbuf(2, 3).raku;
say $b.subbuf(2..4).raku;
say $b.subbuf(2^..^5).raku;
say $b.subbuf(*-3, 2).raku;
say $b.subbuf(2, *-6).raku;
say $b.subbuf(8, 5).raku;
say $b.subbuf(8, 1.9).raku;
say $b.subbuf(5..50).raku;
say $b.subbuf(10).raku;
```
```output
Blob.new(7,8,9)
Blob.new(2,3,4)
Blob.new(2,3,4)
Blob.new(3,4)
Blob.new(7,8)
Blob.new(2,3,4)
Blob.new(8,9)
Blob.new(8)
Blob.new(5,6,7,8,9)
Blob.new()
```

`subbuf(2, *-6)` computes the length from the number of elements left after
the start, 8, minus 6. A start past the end or below zero, and a negative
length, return a Failure carrying `X::OutOfRange`, whose message for the
start begins with a stray quote. A Range with a fractional bound is a
Failure too. A string start has no candidate. The result keeps the type, so
a subbuf of a `utf8` is a `utf8`, and two equal subbufs of a Blob are `===`.

```raku
my $b = Blob.new(^10);
my $f = $b.subbuf(11);
say $f.^name;
say $f.exception.message;
say $b.subbuf(-1).exception.message;
say $b.subbuf(0, -2).exception.message;
say $b.subbuf(1.5..3).exception.message;
try { $b.subbuf("2") };
say $!.^name;
say "abc".encode.subbuf(1).raku;
say buf8.new(1, 2).subbuf(1).^name;
say $b.subbuf(0, 3) === $b.subbuf(0, 3);
```
```output
Failure
"From argument to subbuf out of range. Is: 11, should be in 0..10
"From argument to subbuf out of range. Is: -1, should be in 0..10
Len element to subbuf out of range. Is: -2, should be in 0..10
Must specify a Range with integer bounds to subbuf
X::Multi::NoMatch
utf8.new(98,99)
Buf[uint8]
True
```

## `subbuf` with a string start and a length never returns
tags: bug

A string start alone, a string length and a fractional start all have no
candidate and throw `X::Multi::NoMatch` straight away:

```raku
try { Blob.new(1, 2).subbuf("1") };
say $!.^name;
try { Blob.new(1, 2).subbuf(1, "1") };
say $!.^name;
try { Blob.new(1, 2).subbuf(1.5) };
say $!.^name;
```
```output
X::Multi::NoMatch
X::Multi::NoMatch
X::Multi::NoMatch
```

A string start followed by an integer length is not refused. In Rakudo
2026.08 the call never returns, running until it is killed:

```raku nocheck
say Blob.new(1, 2).subbuf("1", 1).raku;
```

## `subbuf-rw` replaces a stretch of a Buf, and reads back the old one
tags: quirk

`subbuf-rw(from, n)` returns a container for `n` elements at `from`.
Assigning a buffer to it replaces that stretch, and the Buf grows or shrinks
to fit, so a size of 0 inserts and an empty buffer deletes. Without a size it
reaches to the end, and without arguments it covers the whole buffer; the sub
form `subbuf-rw($buf, …)` does the same. The quirk is in reading the
container back after assigning to it: it still gives the stretch as it was
before, not the new one.

```raku
my $b = Buf.new(0..5);
$b.subbuf-rw(3, 1) = Buf.new(100, 101);
say $b.raku;
$b.subbuf-rw(1, 0) = Blob.new(9);
say $b.raku;
$b.subbuf-rw(0, 2) = Buf.new;
say $b.raku;
subbuf-rw($b, 1) = Buf.new(7);
say $b.raku;
my $p := $b.subbuf-rw(0, 1);
$p = Buf.new(2, 2);
say $p.raku;
say $b.raku;
```
```output
Buf.new(0,1,2,100,101,4,5)
Buf.new(0,9,1,2,100,101,4,5)
Buf.new(1,2,100,101,4,5)
Buf.new(1,7)
Buf.new(1)
Buf.new(2,2,7)
```

Only a buffer can be assigned, and a wider one is narrowed on the way in. A
start past the end cannot be stored, and a Blob has no `subbuf-rw`:

```raku
my $b = Buf.new(1, 2, 3);
try { $b.subbuf-rw(0, 1) = 8 };
say $!.^name;
try { $b.subbuf-rw(9, 1) = Buf.new(1) };
say $!.^name;
try { Blob.new(1).subbuf-rw(0, 1) };
say $!.^name;
$b.subbuf-rw(1, 0) = blob16.new(300);
say $b.raku;
```
```output
X::TypeCheck::Binding::Parameter
X::TypeCheck::Assignment
X::Method::NotFound
Buf.new(1,44,2,3)
```

## `reallocate` sets the length, padding with zeros

`reallocate(n)` makes a Buf n elements long, dropping the tail or adding
zeros, and returns the buffer itself. What was dropped is gone: growing again
adds zeros. A negative length throws `X::AdHoc` and a fraction is refused;
a Blob has no `reallocate`.

```raku
my $b = Buf.new(1, 2, 3);
say $b.reallocate(5).raku;
say $b.reallocate(2).raku;
say $b.reallocate(4).raku;
say $b.reallocate(1) === $b;
try { $b.reallocate(-1) };
say $!.^name;
say $b.raku;
try { $b.reallocate(2.5) };
say $!.^name;
try { Blob.new(1).reallocate(2) };
say $!.^name;
```
```output
Buf.new(1,2,3,0,0)
Buf.new(1,2)
Buf.new(1,2,0,0)
True
X::AdHoc
Buf.new(1)
X::TypeCheck::Binding::Parameter
X::Method::NotFound
```

## `~` keeps the type only when both sides share it

`~` between two buffers joins them into a new one. When both are of the same
type the result is of that type, a Blob for two Blobs and a `utf8` for two
`utf8`s. When the types differ, the result is a plain `Buf` of bytes, and
each value is narrowed to a byte on the way: the `int8` -1 becomes 255 and
the 16-bit 300 becomes 44. The operands are not changed.

```raku
say (Blob.new(1) ~ Blob.new(2)).raku;
say (blob8.new(1) ~ blob8.new(2)).raku;
say ("a".encode ~ "b".encode).raku;
say (Blob.new(1) ~ blob8.new(2)).raku;
say (Blob[int8].new(-1) ~ blob16.new(300)).raku;
say (Buf.new(1) ~ Buf.new(2)).raku;
my $x = Buf.new(1);
my $y = $x ~ Buf.new(2);
say $x.raku;
```
```output
Blob.new(1,2)
Blob[uint8].new(1,2)
utf8.new(97,98)
Buf.new(1,2)
Buf.new(255,44)
Buf.new(1,2)
Buf.new(1)
```

With a string on one side, a `utf8` is decoded and the result is a string;
any other buffer refuses, as it does with a number. `[~]` of no buffers is
the empty string, and `~=` works.

```raku
say (utf8.new(97) ~ "b").raku;
say ("b" ~ utf8.new(97)).raku;
try { Blob.new(97) ~ "b" };
say $!.^name;
try { Buf.new(1) ~ 2 };
say $!.^name;
say ([~] Blob.new(1), Blob.new(2), Buf.new(3)).raku;
say ([~] ()).raku;
my $b = Blob.new(1);
$b ~= Blob.new(2);
say $b.raku;
```
```output
"ab"
"ba"
X::Buf::AsStr
X::Buf::AsStr
Buf.new(1,2,3)
""
Blob.new(1,2)
```

## `X` takes a buffer as one item; `Z` walks through it
tags: quirk undocumented

The list operators do not agree on what a buffer is. `X` treats it as a
single item, so `Blob.new(1, 2) X 3` has one combination. `Z` walks through
its elements, as do `Z+` and the hyper operators; a hyper operator returns a
buffer of the same type. A buffer held in a `$` variable is an item, and `Z`
then takes it whole as well ([Containers and Binding](#ch:containers)); `@$b`
gives the elements to both.

```raku
say (Blob.new(1, 2) X 3).raku;
say (Blob.new(1, 2) Z 3).raku;
say (Blob.new(1, 2) Z+ (10, 20)).raku;
say (Blob.new(1, 2) >>+>> 1).raku;
say (-<< Blob.new(1, 2)).raku;
my $b = Blob.new(1, 2);
say ($b Z 3).raku;
say (@$b X 3).raku;
```
```output
((Blob.new(1,2), 3),).Seq
((1, 3),).Seq
(11, 22).Seq
Blob.new(2,3)
Blob.new(255,254)
((Blob.new(1,2), 3),).Seq
((1, 3), (2, 3)).Seq
```

The negation in the fifth line wraps: -1 and -2 stored in bytes are 255 and
254. A reduction sees the buffer as one operand, so `[+]` of a buffer is its
count. `x` wants a string and refuses a buffer, except a `utf8`, whose text
it repeats; `xx` repeats the buffer object. Two buffers under `<<+>>` find
two candidates at once:

```raku
say [+] Blob.new(10, 20, 30);
say ([max] Blob.new(1, 2, 3)).raku;
try { Blob.new(1, 2) x 2 };
say $!.^name;
say (utf8.new(97) x 3).raku;
say (Blob.new(1, 2) xx 2).raku;
try { Blob.new(1, 2) <<+>> Blob.new(3, 4) };
say $!.^name;
```
```output
3
Blob.new(1,2,3)
X::Buf::AsStr
"aaa"
(Blob.new(1,2), Blob.new(1,2)).Seq
X::Multi::Ambiguous
```

## `~&`, `~|` and `~^` combine buffers element by element
tags: undocumented

The string bitwise operators, given two buffers, apply `+&`, `+|` and `+^`
to each pair of elements. The result has the type of the left operand and
the length of the longer one: `~&` pads the shorter operand with zeros, while
`~|` and `~^` copy the longer operand's tail. Values are stored in the
result's width. Prefix `~^` complements every element within its width.

```raku
say (Blob.new(0xF0, 0x0F) ~& Blob.new(0xFF, 0x00)).raku;
say (Blob.new(1, 1, 1, 1) ~& Blob.new(1, 1)).raku;
say (Blob.new(1, 1, 1, 1) ~| Blob.new(2, 2)).raku;
say (Blob.new(1, 1) ~^ Blob.new(1, 1, 3, 3)).raku;
say (~^Blob.new(0, 1, 255)).raku;
say (~^blob16.new(0)).raku;
say (~^Blob[int8].new(0, 1, -1)).raku;
say (blob8.new(255) ~& Blob[int8].new(-1)).raku;
say (Blob[int8].new(-1) ~& blob8.new(255)).raku;
say (Buf.new(1) ~| Blob.new(2)).raku;
```
```output
Blob.new(240,0)
Blob.new(1,1,0,0)
Blob.new(3,3,1,1)
Blob.new(0,0,3,3)
Blob.new(255,254,0)
Blob[uint16].new(65535)
Blob[int8].new(-1,-2,0)
Blob[uint8].new(255)
Blob[int8].new(-1)
Buf.new(3)
```

A `utf8` stays a `utf8` with another `utf8`. With a string on the right, a
plain buffer refuses, and a `utf8` is decoded and the string operator used.
The shifts `~<` and `~>` have no buffer candidate, and the numeric bitwise
operators numify the buffer to its count
([Strings](#ch:strings:and-combine-strings-code-point-by-code-point) has the
string forms):

```raku
say ("foo".encode ~^ "bar".encode).raku;
try { Blob.new(1) ~& "x" };
say $!.^name;
say (utf8.new(97) ~& "a").raku;
try { Blob.new(1, 2) ~< 1 };
say $!.^name;
say Blob.new(1, 2) +& 3;
```
```output
utf8.new(4,14,29)
X::Buf::AsStr
"a"
X::Multi::NoMatch
2
```

## `~&` and `~|` die on signed buffers of unequal length
tags: bug

For unsigned buffers, and for `~^` with any, the shorter operand is padded.
Between two signed buffers of different lengths, `~&` and `~|` die in Rakudo
2026.08 with an internal error from the virtual machine, whose message names
its array type `MVMArray`, and so does `~&` with a signed left operand and an
unsigned right one of another length. `~^` works, buffers of equal length
work, and so does an unsigned left operand.

```raku
my $long  = Blob[int8].new(-1, -1);
my $short = Blob[int8].new(1);
try { $long ~& $short };
say $!.^name;
say $!.message;
try { $short ~| $long };
say $!.message;
say ($long ~^ $short).raku;
say ($long ~& Blob[int8].new(1, 1)).raku;
try { $long ~& blob8.new(1) };
say $!.message;
say (blob8.new(1) ~& $long).raku;
```
```output
X::AdHoc
MVMArray: bindpos I8 expected int register
MVMArray: bindpos I8 expected int register
Blob[int8].new(-2,-1)
Blob[int8].new(1,1)
MVMArray: bindpos I8 expected int register
Blob[uint8].new(1,0)
```

## List methods see the elements; `reduce` sees one buffer
tags: quirk

The list methods work on a buffer's elements: `map`, `grep`, `sort`, `join`,
`min`, `max`, `sum`, `kv`, `head`, `unique`, `rotor` and the rest. `reverse`
returns a buffer of the same type, not a Seq. `reduce` and `produce` are the
exception: they see the buffer as one item, so `reduce(&[+])` numifies that
one item to the count. `rotate` and `contains` do not exist, and a buffer is
never lazy.

```raku
my $b = Blob.new(3, 1, 2);
say $b.map(* * 10);
say $b.grep(* > 1);
say $b.sort;
say $b.join("-");
say $b.min, " ", $b.max, " ", $b.sum;
say $b.kv;
say $b.reverse.raku;
say $b.reduce(&[+]);
say $b.produce(&[+]).raku;
say $b.list.reduce(&[+]);
say $b.is-lazy;
```
```output
(30 10 20)
(3 2)
(1 2 3)
3-1-2
1 3 6
(0 3 1 1 2 2)
Blob.new(2,1,3)
3
(Blob.new(3,1,2),).Seq
6
False
```

`for` iterates the elements of a buffer value, but a buffer in a `$` variable
is one item and the loop runs once, as for an itemized list; `@$b` or
`$b.list` gives the elements.

```raku
my $b = Blob.new(3, 1, 2);
my $n = 0;
for Blob.new(3, 1, 2) { $n++ }
say $n;
$n = 0;
for $b { $n++ }
say $n;
$n = 0;
for @$b { $n++ }
say $n;
try { $b.rotate };
say $!.^name;
```
```output
3
1
3
X::Method::NotFound
```

## `encode` returns a `utf8`, a `utf16` or a `Blob[uint8]`

The type of what `encode` returns depends on the encoding. UTF-8, the
default, gives a `utf8`, and UTF-16 a `utf16`, whose elements are 16-bit code
units, so a character outside the Basic Multilingual Plane takes two. Every
other encoding gives a `Blob[uint8]` of bytes: Latin-1, ASCII, the Windows
code pages, `utf8-c8`, and also `utf16le` and `utf16be`, which spell out the
two bytes of each unit in the named order. No UTF-16 form writes a byte-order
mark.

```raku
say "é".encode.raku;
say "é".encode("utf16").raku;
say "é".encode("latin-1").raku;
say "é".encode("utf8-c8").raku;
say "é".encode("utf16le").raku;
say "é".encode("utf16be").raku;
say "😀".encode("utf16").raku;
say "a".encode("utf16").bytes;
```
```output
utf8.new(195,169)
utf16.new(233)
Blob[uint8].new(233)
Blob[uint8].new(195,169)
Blob[uint8].new(233,0)
Blob[uint8].new(0,233)
utf16.new(55357,56832)
2
```

Only the `utf8`, `utf16` and `utf32` types know their encoding; `.encoding`
of any other buffer is `Any`, even one that `encode("ascii")` returned.
`encode` works on any Cool value, through its string. `:translate-nl`, which
is meant to write `\n` as `\r\n` on Windows, changes nothing on other
systems.

```raku
say "a".encode.encoding;
say "a".encode("utf16").encoding;
say utf32.new(97).encoding;
say "a".encode("ascii").encoding.raku;
say 42.encode.raku;
say 1.5.encode("ascii").raku;
say "a\nb".encode(:translate-nl).list;
```
```output
utf-8
utf-16
utf-32
Any
utf8.new(52,50)
Blob[uint8].new(49,46,53)
(97 10 98)
```

## Encoding names ignore case; an unknown name throws

Encoding names are matched without regard to case, and most have several
spellings: `utf8` and `utf-8`, `utf16le` and `utf-16-le`, `latin1`,
`latin-1`, `iso-8859-1`, `l1` and `cp819` among others, `windows-1252` and
`windows1252`. There is no UTF-32 encoder. An unknown name, a trailing space
included, throws `X::Encoding::Unknown`, whose `name` is the name as given.
A named `:enc` argument is ignored, and a second positional argument is
refused.

```raku
say "a".encode("UTF-8").^name;
say "a".encode("Latin1").^name;
say "a".encode("cp819").^name;
say "a".encode("UTF-16-LE").^name;
try { "a".encode("utf-32") };
say $!.^name;
try { "a".encode("ASCII ") };
say $!.name.raku;
say $!.message;
say "a".encode(:enc<utf16>).^name;
try { "a".encode("utf8", "utf8") };
say $!.^name;
```
```output
utf8
Blob[uint8]
Blob[uint8]
Blob[uint8]
X::Encoding::Unknown
"ASCII "
Unknown string encoding 'ASCII '
utf8
X::AdHoc
```

## `encode` with a number as the encoding never returns
tags: bug

An unknown encoding name is refused with `X::Encoding::Unknown`. Given a
number, Rakudo 2026.08 never returns: the call runs until it is killed. An
undefined encoding does the same ([Strings](#ch:strings:encode-with-an-undefined-encoding-never-returns)),
while `decode` takes an undefined name to mean UTF-8
([below](#ch:buffers:decode-uses-the-buffers-own-encoding-or-utf-8)).

```raku nocheck
say "a".encode(42).raku;
```

## Without `:strict`, a code point below 256 is written as its byte
tags: quirk

A Windows code page maps its 256 byte values to characters of its own, so
many code points below 256 have no byte in it. Without `:strict`, the
encoder writes any such code point as the byte of the same number, and that
byte usually decodes as a different character. For windows-1252 these are
the control characters U+0080 to U+009F: U+0080 becomes the byte 0x80, which
is `€`. For windows-1251, the Cyrillic code page, it is most of Latin-1:
`é` is written as 233, which is `й`, and `À` as 192, which is `А`.

```raku
say "€".encode("windows-1252").list;
say "a\x[81]".encode("windows-1252").list;
say "\x[80]".encode("windows-1252").decode("windows-1252");
say "Ж".encode("windows-1251").list;
say "é".encode("windows-1251").list;
say Blob.new(233).decode("windows-1251");
say "\x[C0]\x[FF]".encode("windows-1251").decode("windows-1251");
try { "\x[100]".encode("windows-1251") };
say $!.message;
```
```output
(128)
(97 129)
€
(198)
(233)
й
Ая
Error encoding Windows-1251 string: could not encode codepoint 256
```

A code point of 256 or more that the code page lacks is refused, as the last
line shows. `:strict` makes the encoder refuse every code point the code
page has no character for:

```raku
try { "a\x[81]".encode("windows-1252", :strict) };
say $!.^name;
say $!.message;
try { "é".encode("windows-1251", :strict) };
say $!.message;
say "a".encode("windows-1252", :strict).list;
```
```output
X::AdHoc
Error encoding Windows-1252 string: could not encode codepoint 129
Error encoding Windows-1251 string: could not encode codepoint 233
(97)
```

## `:replacement` also applies under `:strict`, and takes any value

`:replacement` gives what an unencodable character becomes: `?` for `True`,
the string itself for a string, even an empty one or several characters, and
the string form of anything else. `False` and Nil mean no replacement. For a
UTF encoding nothing is unencodable, so the text comes out whole. The
replacement is encoded in its turn, and one that the encoding cannot hold
either dies.

```raku
say "a☺b".encode("ascii", :replacement("")).list;
say "a☺b".encode("ascii", :replacement(42)).list;
try { "a☺b".encode("ascii", :replacement(False)) };
say $!.^name;
try { "a☺b".encode("ascii", :replacement(Nil)) };
say $!.^name;
say "a☺b".encode("utf16", :replacement).list;
try { "a☺b".encode("ascii", :replacement("é")) };
say $!.message;
```
```output
(97 98)
(97 52 50 98)
X::AdHoc
X::AdHoc
(97 9786 98)
Error encoding ASCII string: could not encode codepoint 233
```

`:strict` decides which characters count as unencodable, and `:replacement`
what happens to them. Without `:strict`, `é` in windows-1251 is not
unencodable and passes through as 233; with it, the replacement is used:

```raku
say "é".encode("windows-1251", :replacement("?")).list;
say "é".encode("windows-1251", :strict, :replacement("?")).list;
say "a\x[81]".encode("windows-1252", :strict, :replacement("?")).list;
say "☺".encode("ascii", :strict, :replacement).list;
```
```output
(233)
(63)
(97 63)
(63)
```

## `decode` uses the buffer's own encoding, or UTF-8
tags: quirk

`decode` with no argument decodes a `utf8` or a `utf16` as what it is, and
any other buffer as UTF-8. An undefined name means UTF-8 as well, and a named
`:enc` argument is ignored. A name is matched as for `encode`, but an unknown
one throws `X::AdHoc`, not `X::Encoding::Unknown`. An empty buffer decodes to
the empty string under any name at all, even one that does not exist.

```raku
say Blob.new(195, 169).decode;
say Blob.new(233).decode("latin-1");
say Blob.new(0x80).decode("windows-1252");
say Blob.new(0xC0).decode("windows-1251");
say utf16.new(0xD83D, 0xDE00).decode.ords;
say Blob.new(195, 169).decode(Str);
try { Blob.new(1).decode("nope") };
say $!.^name;
say $!.message;
say Blob.new.decode("nope").raku;
```
```output
é
é
€
А
(128512)
é
X::AdHoc
Unknown string encoding: 'nope'
""
```

## Malformed bytes die, and `:replacement` does not rescue UTF-8
tags: quirk

A lone continuation byte, a truncated sequence, an overlong form or an
encoded surrogate make UTF-8 decoding throw `X::AdHoc`, and so does a byte
above 127 in ASCII:

```raku
for Blob.new(255), Blob.new(195), Blob.new(0xC0, 0x80), Blob.new(0xED, 0xA0, 0x80) -> $b {
    try { $b.decode };
    say $!.^name, ": ", $!.message;
}
try { Blob.new(200).decode("ascii") };
say $!.message;
```
```output
X::AdHoc: Malformed UTF-8 at line 1 col 1
X::AdHoc: Malformed termination of UTF-8 string
X::AdHoc: Malformed UTF-8 at line 1 col 1
X::AdHoc: Malformed UTF-8 near byte a0 at line 1 col 1
Will not decode invalid ASCII (code point (-56) < 0 found)
```

`:replacement` is accepted by `decode` but does not help with any of these.
It has an effect only on a byte that an 8-bit code page leaves unmapped, and
only together with `:strict`. Without `:strict`, such a byte decodes to the
code point of the same number:

```raku
try { Blob.new(97, 255).decode("utf8", :replacement("?")) };
say $!.^name;
try { Blob.new(97, 255).decode("utf8", :replacement("?"), :strict) };
say $!.^name;
say Blob.new(0x81).decode("windows-1252").ord;
try { Blob.new(0x81).decode("windows-1252", :strict) };
say $!.message;
say Blob.new(0x81).decode("windows-1252", :replacement("?")).ord;
say Blob.new(0x81).decode("windows-1252", :strict, :replacement("?"));
```
```output
X::AdHoc
X::AdHoc
129
Error decoding Windows-1252 string: could not decode codepoint 129
129
?
```

To get through malformed UTF-8, decode with `utf8-c8` ([below](#ch:buffers:utf8-c8-keeps-every-byte-in-synthetic-characters)).

## UTF-16 follows a byte-order mark; UTF-8 drops one

A UTF-8 byte-order mark at the start is dropped. `utf16` honours a mark of
either byte order and drops it; without one it reads the machine's own order,
little-endian on the machine that ran these examples. `utf16le` and
`utf16be` fix the order. An odd number of bytes is refused. UTF-8 output is
composed, so an `e` followed by a combining accent comes back as one `é`,
and `\r\n` is not translated.

```raku
say Blob.new(0xEF, 0xBB, 0xBF, 97).decode.ords;
say Blob.new(255, 254, 72, 0, 105, 0).decode("utf16");
say Blob.new(254, 255, 0, 72, 0, 105).decode("utf16");
say Blob.new(72, 0, 105, 0).decode("utf16le");
say Blob.new(0, 72, 0, 105).decode("utf16be");
try { Blob.new(72, 0, 105).decode("utf16") };
say $!.message;
say Blob.new(101, 204, 129).decode.ords;
say Blob.new(97, 13, 10).decode.ords;
```
```output
(97)
Hi
Hi
Hi
Hi
Malformed UTF-16; odd number of bytes (3)
(233)
(97 13 10)
```

## `utf8-c8` keeps every byte, in synthetic characters

The `utf8-c8` decoder never throws. Valid UTF-8 comes back as text; a byte
that is not valid UTF-8, and a sequence that composition would change,
become synthetic characters that remember their bytes. Encoding the string
with `utf8-c8` gives the original bytes back. Each synthetic character is
made of the code point U+10FFFD, an `x` and two hex digits.

```raku
my $s = Blob.new(97, 255, 101, 204, 129).decode("utf8-c8");
say $s.chars;
say $s.encode("utf8-c8").list;
say $s.substr(1, 1).ords;
say Blob.new(195, 169).decode("utf8-c8");
```
```output
5
(97 255 101 204 129)
(1114109 120 70 70)
é
```

The five characters are `a`, the synthetic for 255, `e`, and synthetics for
the two bytes of the combining accent, kept apart because composing them
with the `e` would change the bytes.

## A 16-bit buffer decodes its bytes, not its elements
tags: trap

`decode` reads the bytes a buffer stores, whatever its element type. A
`blob16` of 97 and 98 is the four bytes 97, 0, 98, 0 on a little-endian
machine, which UTF-8 decodes to four characters, two of them NUL. Decoding it
as UTF-16 gives `ab` on such a machine. A `utf16` knows its elements are code
units. A `utf32` has an encoding name that `decode` does not know:

```raku
say blob16.new(97, 98).decode.raku;
say blob16.new(97, 98).decode("utf16").raku;
say utf16.new(97, 98).decode.raku;
try { utf32.new(97).decode };
say $!.message;
say Blob[int8].new(97, -1).decode("latin-1").ords;
```
```output
"a\0b\0"
"ab"
"ab"
Unknown string encoding: 'utf-32'
(97 255)
```

## A `utf8` becomes its text wherever a string is wanted

A `utf8` or `utf16` decodes itself when a string is asked for: `.Str`,
prefix `~`, interpolation, `eq` and `cmp` against a string, a smartmatch with
a string on the right, and `~` or `x` with a string. Everything else still
treats it as a buffer: `+` is the number of bytes, `.chars` throws, it is not
a `Str`, and a string on the left of `~~` does not match it.

```raku
my $u = "héllo".encode;
say $u.Str;
say "[$u]";
say $u eq "héllo";
say $u ~~ "héllo";
say "héllo" ~~ $u;
say +$u;
try { $u.chars };
say $!.^name;
say $u ~~ Str;
```
```output
héllo
[héllo]
True
True
False
6
X::Buf::AsStr
False
```

Malformed bytes make `.Str` throw, as `decode` would. A `utf8` is a Blob, so
it cannot grow; `.Buf` copies it into a plain Buf, and it has no `.Blob`.
`reverse` keeps the type, even though reversed UTF-8 bytes are rarely valid:

```raku
try { utf8.new(255).Str };
say $!.^name;
say utf8.new(97).Buf.raku;
try { utf8.new(97).Blob };
say $!.^name;
try { utf8.new(97).push(98) };
say $!.^name;
say utf8.new(97, 98).reverse.raku;
say (utf16.new(97) ~ "b").raku;
```
```output
X::AdHoc
Buf.new(97)
X::Method::NotFound
X::Multi::NoMatch
utf8.new(98,97)
"ab"
```

## An `Encoding` object makes encoders and incremental decoders

`Encoding::Registry.find` looks an encoding up by any of its names, without
regard to case, and returns an `Encoding::Builtin`. Its `name` is the
canonical one and `alternative-names` the others. An unknown name throws
`X::Encoding::Unknown` here too, and an `Encoding::Builtin` cannot be
created directly. `.encoder` takes the options `encode` takes and returns an
object whose `encode-chars` does the work.

```raku
my $enc = Encoding::Registry.find("Latin1");
say $enc.^name;
say $enc.name;
say $enc.alternative-names.head(4);
say Encoding::Registry.find("ascii").alternative-names.raku;
say Encoding::Registry.find("ascii").encoder(:replacement).encode-chars("£5").raku;
try { Encoding::Registry.find("utf32") };
say $!.^name;
try { Encoding::Builtin.new };
say $!.^name;
```
```output
Encoding::Builtin
iso-8859-1
(iso_8859-1:1987 iso_8859-1 iso-ir-100 latin1)
()
Blob[uint8].new(63,53)
X::Encoding::Unknown
X::Cannot::New
```

`.decoder` returns a decoder that takes bytes as they arrive, with
`add-bytes`, and hands out text as far as it can. It holds back the last
character, because a byte still to come could add a combining mark to it.
`consume-line-chars` gives a line, or the Str type object when no complete
line is there yet, and `consume-all-chars` gives the rest.

```raku
my $d = Encoding::Registry.find("utf8").decoder;
$d.add-bytes(Blob.new(0x61, 0xC3));
say $d.consume-available-chars.raku;
$d.add-bytes(Blob.new(0xA9, 0x0A, 0x62));
say $d.consume-line-chars(:chomp).raku;
say $d.bytes-available;
say $d.consume-line-chars.raku;
say $d.consume-all-chars.raku;
say $d.is-empty;
```
```output
""
"aé"
1
Str
"b"
True
```

A decoder made with `:translate-nl` turns `\r\n` into `\n`. The same option
given to `decode` is accepted and does nothing:

```raku
my $d = Encoding::Registry.find("utf8").decoder(:translate-nl);
$d.add-bytes("a\r\nb".encode);
say $d.consume-all-chars.ords;
say Blob.new(97, 13, 10).decode(:translate-nl).ords;
```
```output
(97 10 98)
(97 13 10)
```

## `Encoding::Registry.register` teaches `encode` a new name

A class that does the `Encoding` role, with a `name`, `alternative-names`,
an `encoder` and a `decoder`, can be registered. `register` returns Nil, and
from then on `encode` finds the encoding under any of its names, without
regard to case. Registering a name that is already taken, a built-in one
included, throws `X::Encoding::AlreadyRegistered`.

```raku
class Shout does Encoding {
    method name { "shout" }
    method alternative-names { ("loud",) }
    method encoder(*%) {
        class :: does Encoding::Encoder {
            method encode-chars(Str $s) { $s.uc.encode("ascii") }
        }.new
    }
    method decoder(*%) { die "no decoder" }
}
say Encoding::Registry.register(Shout).raku;
say "hi".encode("LOUD").raku;
try { Encoding::Registry.register(Shout) };
say $!.^name;
try { Encoding::Registry.register(Encoding::Registry.find("utf8")) };
say $!.message;
```
```output
Nil
Blob[uint8].new(72,73)
X::Encoding::AlreadyRegistered
An encoding with name 'utf8' has already been registered
```

## `read-uint16` and its kin read bytes at an offset, in a chosen order

`read-int8` to `read-int128` and `read-uint8` to `read-uint128` read 1, 2,
4, 8 or 16 bytes starting at a byte offset, and return an `Int`, signed in
two's complement or unsigned. The optional second argument is an
`Endian`: `NativeEndian`, the default, `LittleEndian` or `BigEndian`.
`Kernel.endian` says what native is.

```raku
my $b = blob8.new(1, 2, 3, 4, 255);
say $b.read-uint8(4);
say $b.read-int8(4);
say $b.read-uint16(0, BigEndian);
say $b.read-uint16(0, LittleEndian);
say $b.read-uint32(1, BigEndian);
say $b.read-int16(3, LittleEndian);
say $b.read-uint16(0) == $b.read-uint16(0, NativeEndian);
say Kernel.endian;
say Endian.enums.sort(*.value);
```
```output
255
-1
258
513
33752319
-252
True
LittleEndian
(NativeEndian => 0 LittleEndian => 1 BigEndian => 2)
```

The 64- and 128-bit forms return big integers where needed. Reading past the
end or at a negative offset dies with an `X::AdHoc` from the virtual machine,
not an `X::OutOfRange`, and a number where an `Endian` belongs is refused by
the signature:

```raku
my $b = blob8.new(1, 2, 3);
try { $b.read-uint16(2) };
say $!.^name;
say $!.message;
try { $b.read-uint16(0, 2) };
say $!.^name;
say blob8.new(255 xx 8).read-uint64(0);
say blob8.new(255 xx 16).read-int128(0);
```
```output
X::AdHoc
MVMArray: read_buf out of bounds offset 2 start 0 elems 3 count 2
X::TypeCheck::Binding::Parameter
18446744073709551615
-1
```

## On a wide buffer, `read-*` and `write-*` count the offset in elements
tags: quirk undocumented

The `read-*` and `write-*` methods exist on every buffer, not only byte
buffers. On a 16-, 32- or 64-bit buffer the offset is an element index,
while the width read or written is still in bytes, taken from the raw
storage, which is little-endian on the machine that ran these examples. So
`read-uint8(1)` on a `blob16` is the low byte of element 1, and a write grows
the buffer by one element for each byte it writes.

```raku
my $w = blob16.new(0x1234, 0x5678);
say $w.read-uint8(1).base(16);
say $w.read-uint16(1, LittleEndian).base(16);
say $w.read-uint16(0, BigEndian).base(16);
say $w.read-uint32(0, LittleEndian).base(16);
say buf16.new.write-uint16(0, 0x0102, LittleEndian).raku;
say buf16.new.write-uint16(1, 1).raku;
```
```output
78
5678
3412
56781234
Buf[uint16].new(258,0)
Buf[uint16].new(0,1,0)
```

The two bytes written by the first `write-uint16` land in element 0, as the
value 0x0102, and the buffer has grown by two elements, not one.

## `read-num32` and `read-num64` decode IEEE floats

`read-num32` and `read-num64` read a single- or double-precision float at a
byte offset, with the same `Endian` argument. A single is returned widened to
a `Num`, which shows the digits the widening adds. Infinities, NaN and
negative zero come back as themselves, and a buffer too short throws
`X::AdHoc`.

```raku
say buf8.new(0, 0, 128, 63).read-num32(0, LittleEndian);
say buf8.new(0xDB, 0x0F, 0x49, 0x40).read-num32(0, LittleEndian);
say buf8.new(0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18).read-num64(0, BigEndian);
say buf8.new(0, 0, 128, 127).read-num32(0, LittleEndian);
say buf8.new(0, 0, 0, 0, 0, 0, 0, 128).read-num64(0, LittleEndian).raku;
say buf8.new(0, 0, 128, 63).read-num32(0).^name;
try { buf8.new(0, 0, 128).read-num32(0) };
say $!.^name;
```
```output
1
3.1415927410125732
3.141592653589793
Inf
-0e0
Num
X::AdHoc
```

## `read-ubits` counts bits from the top of the first byte

`read-ubits(position, count)` reads `count` bits starting at a bit position,
where bit 0 is the most significant bit of the first byte, and returns them
as an unsigned integer of any size. `read-bits` reads the same bits as a
two's-complement number. A negative count reads 0, and a run that would pass
the end throws `X::AdHoc`, with a message that names the buffer's variable.

```raku
my $b = blob8.new(0x12, 0x34, 0x56);
say $b.read-ubits(0, 8);
say $b.read-ubits(4, 8).base(16);
say $b.read-ubits(0, 4);
say $b.read-ubits(20, 4);
say $b.read-bits(3, 5);
say blob8.new(0x80).read-bits(0, 1);
say blob8.new(1..9).read-ubits(0, 65);
say $b.read-ubits(0, -1);
try { $b.read-ubits(0, 25) };
say $!.message;
```
```output
18
23
1
6
-14
-1
145247719580765712
0
Can only read 1..24 bits from position 0 in buffer '$b', you tried: 25
```

`read-ubits(4, 8)` takes the low half of 0x12 and the high half of 0x34.

## `read-bits` of zero bits is -1
tags: quirk

Zero bits hold the number 0, and `read-ubits(p, 0)` says so, but in Rakudo
2026.08 `read-bits`, its signed counterpart, answers -1. The documentation
declares both methods on `blob8` and describes the result as the value of
the given number of bits. On a wide buffer Rakudo 2026.08 takes each element
as if it were a byte, without masking, so 8 bits from position 0 of a
`blob16` are the whole first element, a number wider than 8 bits:

```raku
my $b = blob8.new(0x12, 0x34);
say $b.read-ubits(0, 0);
say $b.read-bits(0, 0);
my $w = blob16.new(0x1234, 0x5678);
say $w.read-ubits(0, 8).base(16);
say $w.read-ubits(8, 8).base(16);
```
```output
0
-1
1234
5678
```

## `write-*` grows the buffer and cuts the value to size

`write-uint8` to `write-int128`, `write-num32` and `write-num64` take an
offset, a value and an optional `Endian`, write at that byte offset, grow the
buffer with zeros as needed, and return it. Called on a type object such as
`buf8`, they return a new buffer. The value is cut to the width: 256 is
written as 0, and -1 as all ones.

```raku
my $b = buf8.new;
$b.write-uint16(0, 0x1234, BigEndian);
say $b.raku;
$b.write-uint8(4, 1);
say $b.raku;
say $b.write-uint32(0, -1) === $b;
say $b.raku;
say buf8.write-uint16(0, 258, BigEndian).raku;
say Buf.write-uint8(0, 1).raku;
say buf8.new.write-uint8(0, 256).raku;
say buf8.new.write-int8(0, 200).raku;
say buf8.new.write-uint16(0, 70000, BigEndian).raku;
```
```output
Buf[uint8].new(18,52)
Buf[uint8].new(18,52,0,0,1)
True
Buf[uint8].new(255,255,255,255,1)
Buf[uint8].new(1,2)
Buf.new(1)
Buf[uint8].new(0)
Buf[uint8].new(200)
Buf[uint8].new(17,112)
```

The 64-bit forms are typed: a negative value for `write-uint64` fails the
signature, and a value wider than 64 bits dies. A fraction, a string, an
integer given to `write-num32` and a negative offset all die with
`X::AdHoc`, and a Blob has no `write-*` methods:

```raku
try { buf8.new.write-uint64(0, -1) };
say $!.^name;
try { buf8.new.write-uint64(0, 2**64) };
say $!.^name;
try { buf8.new.write-uint8(0, 1.5) };
say $!.^name;
try { buf8.new.write-num32(0, 1) };
say $!.message;
try { buf8.new.write-uint8(-1, 1) };
say $!.^name;
try { blob8.new(1).write-uint8(0, 1) };
say $!.^name;
say buf8.new.write-num64(0, 1e0, BigEndian).raku;
```
```output
X::TypeCheck::Binding::Parameter
X::AdHoc
X::AdHoc
This type cannot unbox to a native number: P6opaque, Int
X::AdHoc
X::Method::NotFound
Buf[uint8].new(63,240,0,0,0,0,0,0)
```

## `write-ubits` writes the low bits of a value at a bit position

`write-ubits(position, count, value)` writes the low `count` bits of the
value starting at a bit position, most significant bit first, and grows the
buffer as needed. `write-bits` does the same with a signed value. Both return
the buffer, or a new `Buf[uint8]` when called on the type object. A zero
count writes nothing, and a negative value is refused by `write-ubits`.

```raku
say buf8.new.write-ubits(4, 8, 0xAB).raku;
say buf8.new.write-ubits(0, 12, 0xABC).raku;
say buf8.new.write-bits(0, 4, -1).raku;
say buf8.new.write-bits(0, 4, 8).read-bits(0, 4);
say buf8.write-ubits(0, 8, 0x1FF).raku;
say buf8.new.write-ubits(0, 0, 1).raku;
try { buf8.new.write-ubits(0, 1, -1) };
say $!.^name;
```
```output
Buf[uint8].new(10,176)
Buf[uint8].new(171,192)
Buf[uint8].new(240)
-8
Buf[uint8].new(255)
Buf[uint8].new()
X::TypeCheck::Binding::Parameter
```

`0xAB` written at bit 4 fills the low half of the first byte with `A` and the
high half of the second with `B`: 0x0A and 0xB0. The value 8 in four bits is
`1000`, which reads back as -8.

## `write-ubits` clears the bits after the run in its last byte
tags: bug

The documentation describes `write-ubits` as writing a value to the given
number of bits from the given offset. When the run ends inside a byte, Rakudo
2026.08 also changes bits outside it: of the bits of that byte to the right
of the run, only the first survives, and the rest become zeros. The bits to
the left of the run are kept, and a run that ends on a byte boundary leaves
every other bit alone.

```raku
say buf8.new(0xFF).write-ubits(0, 4, 0).raku;
say buf8.new(0xFF).write-ubits(2, 4, 0).raku;
say buf8.new(0xFF, 0xFF).write-ubits(4, 8, 0).raku;
say buf8.new(0xFF).write-ubits(4, 4, 0).raku;
say buf8.new(1, 2, 3).write-bits(8, 8, -1).raku;
```
```output
Buf[uint8].new(8)
Buf[uint8].new(194)
Buf[uint8].new(240,8)
Buf[uint8].new(240)
Buf[uint8].new(1,255,3)
```

With the bits outside the run kept, the first three results would be 15, 195
and `(240, 15)`.

## `pack` and `unpack` need `use experimental :pack`

The `pack` sub and the `unpack` method are experimental. Without the pragma,
`unpack` throws `X::Experimental` at run time, and a call of `pack` does not
compile:

```raku
try { Blob.new(1, 2).unpack("C*") };
say $!.^name;
say $!.message;
```
```output
X::Experimental
Use of the 'unpack' method is experimental; please 'use experimental :pack;'
```

```raku
say pack("C", 1);
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Use of pack is experimental; please 'use experimental :pack;'
at example.raku:2
------> <BOL><HERE><EOL>
```

With the pragma both work, and an unknown directive throws `X::Buf::Pack`. A
repeat count after a directive is not honoured: `C*` and `C2` pack only the
first value, and each value needs its own letter.

```raku
use experimental :pack;
say pack("n", 258).raku;
say pack("CC", 1, 2).raku;
say pack("C*", 1, 2).raku;
say Blob.new(1, 2, 3, 4).unpack("N");
say pack("A3", "hi").list;
try { pack("q", 1) };
say $!.^name;
```
```output
Buf.new(1,2)
Buf.new(1,2)
Buf.new(1)
16909060
(104 105 32)
X::Buf::Pack
```

## The type object `Blob` is a list of one element
tags: undocumented

Like any undefined value, the `Blob` type object answers the list methods as
a list of one element, itself, and is False. The methods that need a buffer
refuse it in two ways: some have no candidate for a type object, others say
that they need an instance. `allocate`, called on the type object, is the
way to make a filled buffer. As a number it is 0, with a warning.

```raku
say Blob.elems;
say Blob.list.raku;
say Blob.Bool;
try { Blob.decode };
say $!.^name;
try { Blob.bytes };
say $!.^name;
try { Buf.push(1) };
say $!.^name;
say Buf.allocate(2, 1).raku;
say +Blob;
```
```output
1
(Blob,)
False
X::Multi::NoMatch
X::Parameter::InvalidConcreteness
X::Multi::NoMatch
Buf.new(1,1)
0
```
```stderr
Use of uninitialized value of type Blob in numeric context
  in block <unit> at example.raku line 11
```

## `Blob(…)` coerces through `.new`; `.Buf` and `.Blob` copy
tags: unasserted

`Blob(x)` returns x unchanged when it already is a Blob, a Buf included.
Anything else goes to `.new`, so a list becomes a buffer and a string is
refused with `X::TypeCheck`. `.Buf` copies any buffer into a Buf, plain for
bytes and `Buf[T]` otherwise; `.Blob` exists only on a Buf. Both always make
a copy, even of a buffer that already has the type.

```raku
say Blob([1, 2]).raku;
say Blob(1, 2).raku;
say Blob(Buf.new(1)).raku;
say utf8(Blob.new(97)).raku;
try { Blob("abc") };
say $!.^name;
say Blob.new(1, 2).Buf.raku;
say Buf.new(1, 2).Blob.raku;
say Blob[int16].new(1).Buf.^name;
try { Blob.new(1).Blob };
say $!.^name;
my $b = Buf.new(1);
say $b.Buf === $b;
```
```output
Blob.new(1,2)
Blob.new(1,2)
Buf.new(1)
utf8.new(97)
X::TypeCheck
Buf.new(1,2)
Blob.new(1,2)
Buf[int16]
X::Method::NotFound
False
```

In a signature, `Blob()` accepts a Buf as it is. A `Buf` parameter refuses a
Blob, and a `blob8` parameter refuses a plain `Blob.new`, while it takes a
`buf8`. `Int(…)` of a buffer is its count, `List(…)` its elements, and
`Str(…)` is refused:

```raku
sub takes-blob(Blob() $b) { $b.^name }
say takes-blob(Buf.new(3));
sub takes-buf(Buf $b) { $b.^name }
try { takes-buf(Blob.new(1)) };
say $!.^name;
sub takes-blob8(blob8 $b) { $b.^name }
try { takes-blob8(Blob.new(1)) };
say $!.^name;
say takes-blob8(buf8.new(1));
say Int(Blob.new(7, 8));
say List(Blob.new(7, 8)).raku;
try { Str(Blob.new(97)) };
say $!.^name;
```
```output
Buf
X::TypeCheck::Binding::Parameter
X::TypeCheck::Binding::Parameter
Buf[uint8]
2
(7, 8)
X::Buf::AsStr
```
