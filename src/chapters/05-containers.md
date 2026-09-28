---
title: Containers and Binding
part: Reading the code
summary: Assignment copies a value into a container, binding shares the container itself, and itemization wraps a value in one; together they decide what is copied, what is shared and what counts as a single item.
---

A Raku variable is a name for a *container*, and the container holds the
value. Most of the time the difference is invisible: `$x = 5` puts 5 into the
container that `$x` names, and reading `$x` takes it out again. It becomes
visible when two names share one container, when a list must count as a
single thing, and when a change has to be undone later.

Three operations are behind all of it. *Assignment*, `=`, copies a value into
a container. *Binding*, `:=`, makes a name refer directly to a container or a
value, without copying anything. *Itemization* wraps a value in a container so
that it counts as one item in a list. Whether `=` is item or list assignment
is decided by the target's sigil, which is covered in [Who Takes the
Operand](#ch:precedence:the-sigil-of-the-target-decides-between-item-and-list-assignment);
the methods of lists and hashes are in [Lists, Arrays, Seqs and
Slips](#ch:lists) and [Hashes, Maps and Pairs](#ch:hashes). This chapter is
about the containers underneath.

## A `$` variable keeps its value in a Scalar container

Method calls and operators look through a container to the value inside, so
`$x.^name` names the type of the value. `.VAR` is the way to reach the
container itself. An Array is its own container and keeps one Scalar per
element, which is what makes `@a[0] = 5` possible; a List, built by the
comma, holds its values bare.

```raku
my $x = 42;
say $x.^name;
say $x.VAR.^name;
my @a = 1, 2;
say @a.VAR.^name;
say @a[0].VAR.^name;
say (1, 2)[0].VAR.^name;
```
```output
Int
Scalar
Array
Scalar
Int
```

A container is more than a box. It knows the variable's name, its type
constraint and its default, and assigning `Nil` to it puts the default back:

```raku
my Int $count is default(0) = 5;
say $count.VAR.name;
say $count.VAR.of.^name;
$count = Nil;
say $count;
```
```output
$count
Int
0
```

## `:=` gives a container a second name; `=` copies the value

Assignment reads the value on the right and stores it in the container on
the left. Binding stores nothing: it makes the name on the left refer to
whatever the right side is, here the container of `$a`. After `my $b := $a`
the two names are one variable.

```raku
my $a = 1;
my $b := $a;
my $c = $a;
$b = 2;
say "$a $b $c";
say $a =:= $b;
say $a =:= $c;
```
```output
2 2 1
True
False
```

`=:=` asks whether two names lead to the same container. It chains like any
comparison, and it is not `===`: two elements that hold equal values are
`===`, but they live in different containers.

```raku
my $a = 1;
my $b := $a;
my $c := $b;
say $a =:= $b =:= $c;
my @x = 1;
my @y = 1;
say @x[0] === @y[0];
say @x[0] =:= @y[0];
```
```output
True
True
False
```

## A name bound to a value cannot be assigned to

The right side of `:=` does not have to be a variable. When it is any other
expression, the name is bound to the resulting value itself, and there is no
container to receive a later assignment:

```raku
my $x = 5;
my $y := $x + 1;
say $y.VAR.^name;
$y = 7;
```
```output
Int
```
```stderr
Cannot assign to an immutable value
  in block <unit> at example.raku line 4

```

The operator `::=` parses, but Rakudo refuses it at compile time:

```raku
my $x ::= 1;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
"::=" not yet implemented. Sorry.
at example.raku:1
------> my $x ::= 1<HERE>;
```

## A sigilless name is a binding

`my \x = …` looks like an assignment but is a binding: a name without a sigil
never gets a container of its own. Given a variable, it becomes another name
for that variable's container. Given a value, it is that value, and a list
bound this way is iterated element by element.

```raku
my $y = 1;
my \x = $y;
x = 5;
say $y;
my \z = 42;
say z.VAR.^name;
my \w = (1, 2, 3);
my $n = 0;
$n++ for w;
say $n;
```
```output
5
Int
3
```

## A `$` name bound to a list is not an item
tags: trap

Assigning a list to a `$` variable puts the list inside a Scalar, and a list
inside a Scalar counts as one item, so `for` sees one thing. Binding skips
the container: the same list bound to a `$` name is iterated element by
element, and list assignment spreads it. `.raku` shows the difference as a
leading `$`.

```raku
my $assigned = (1, 2, 3);
my $bound   := (1, 2, 3);
say $assigned.raku;
say $bound.raku;
for $assigned { say "assigned: $_" }
for $bound    { say "bound: $_" }
my @a = $bound;
say @a.elems;
```
```output
$(1, 2, 3)
(1, 2, 3)
assigned: 1 2 3
bound: 1
bound: 2
bound: 3
3
```

## Assignment returns the container it assigned to

The value of an assignment is its left side, the container itself, not a
copy of the value that went in. That is why assignments chain from the
right, and why the result of an assignment can be used, incremented or
assigned to again:

```raku
my $x;
my $y = ($x = 5) + 1;
say "$x $y";
($x = 10)++;
say $x;
my $a = my $b = 3;
say "$a $b";
say ($a = 7).VAR.^name;
```
```output
5 6
11
3 3
Scalar
```

## An assignment metaoperator takes a whole expression on its right

`$x op= y` applies `op` to the variable and the right side, then assigns the
result. The right side is everything down to the item-assignment level, so a
ternary, a `min` or a concatenation on the right is finished before `op` is
applied:

```raku
my $s = "ab";
$s x= 1 + 1;
say $s;
my $m = 5;
$m max= 3 min 1;
say $m;
my $n = 1;
$n += 1 ?? 10 !! 20;
say $n;
my $c = "a";
$c ~= "b" ~ "c";
say $c;
```
```output
abab
5
11
abc
```

`$m max= 3 min 1` compares 5 with `3 min 1`, which is 1, and keeps 5. Had
`max=` taken only the 3, the result would have been `(5 max 3) min 1`, which
is 1.

## An assignment metaoperator is an item assignment, even on an array
tags: trap

A plain `=` becomes list assignment, looser than the comma, when its target
has an `@` or `%` sigil, even when the target is a single element such as
`@a[0]` ([the sigil of the target
decides](#ch:precedence:the-sigil-of-the-target-decides-between-item-and-list-assignment)).
The metaoperators do not follow that rule: `+=`, `~=` and the rest always
sit on the item-assignment level, tighter than the comma, whatever the sigil
of the target.

```raku
my @a = 1, 2;
@a[0] = 10, 20;
say @a.raku;
my @b = 1, 2;
@b[0] += 10, 20;
say @b.raku;
```
```output
[(10, 20), 2]
[11, 2]
```
```stderr
WARNINGS for example.raku:
Useless use of constant integer 20 in sink context (lines 5, 5)
```

The `= 10, 20` stores a list in the slot; the `+= 10, 20` adds 10 and leaves
the `20` behind, which the compiler reports as useless.

## `.=` assigns a method's result, on the method-call level

`$s .= uc` is `$s = $s.uc`: the method is called on the variable's value and
the result is assigned back. Unlike the other metaoperators, `.=` sits on
the method-postfix level, the tightest of all, so it is done before any
infix around it:

```raku
my $s = "ab";
$s .= uc;
say $s;
my $t = "ab";
say ($t .= uc ?? "yes" !! "no");
say $t;
my @a = 3, 1, 2;
@a .= sort;
say @a;
```
```output
AB
yes
AB
[1 2 3]
```

In the second `say` the ternary tests the result of `$t .= uc`, the string
`"AB"`, and the assignment has already happened.

## `//=`, `||=` and `&&=` evaluate their right side only when needed

The short-circuit operators keep their short circuit in the assignment form.
`$u //= f()` calls `f` only when `$u` is undefined, `||=` only when it is
false, and `&&=` only when it is true:

```raku
my $calls = 0;
sub fallback { $calls++; 99 }
my $u = 0;
$u //= fallback;
say "$u, calls: $calls";
$u ||= fallback;
say "$u, calls: $calls";
my $v = 1;
$v &&= fallback;
say "$v, calls: $calls";
```
```output
0, calls: 0
99, calls: 1
99, calls: 2
```

0 is defined, so `//=` leaves it alone; it is false, so `||=` replaces it.

## A List holds bare values, unless it was given containers

A List is immutable: its slots cannot be assigned to or bound, and `push`
refuses to grow it. A List built from variables, though, holds their
containers, and assigning through such a slot changes the variable:

```raku
my $l = (1, 2);
try { $l[0] = 5 };
say $!.message;
try { $l[0] := 5 };
say $!.^name;
try { $l.push(3) };
say $!.message;
my $x = 1;
my $m = ($x, 2);
$m[0] = 5;
say $x;
```
```output
Cannot modify an immutable List ((1 2))
X::Bind
Cannot call 'push' on an immutable 'List'
5
```

Turning an Array into a List with `.List` copies the values out of the
element containers. The List is a snapshot: later writes to the Array do not
reach it.

```raku
my @a = 1, 2;
my $snapshot = @a.List;
@a[0] = 9;
say $snapshot;
say $snapshot[0].VAR.^name;
```
```output
(1 2)
Int
```

## Iterating an Array hands out its containers

`for` and `.map` set `$_` to each element's own Scalar, so a loop over an
array can change it. A pointy-block parameter is read-only even when the
element is a container, unless it is introduced with `<->` (or declared
`is rw`); `is copy` gives the block a private copy.

```raku
my @a = 1, 2;
for @a { $_ *= 10 }
say @a;
@a.map({ $_ = 0 });
say @a;
for @a <-> $x { $x = 5 }
say @a;
for @a -> $x is copy { $x = 7 }
say @a;
```
```output
[10 20]
[0 0]
[5 5]
[5 5]
```

A loop over literal values gets the values, which cannot be assigned, and a
plain `-> $x` refuses too, with a different message. A comma list of
variables is not an Array, but it holds the variables' containers, so a loop
over it writes through:

```raku
my @a = 1, 2;
try { for 1, 2 { $_ = 0 } };
say $!.message;
try { for @a -> $x { $x = 0 } };
say $!.message;
my ($p, $q) = 1, 2;
for $p, $q { $_ *= 3 }
say "$p $q";
```
```output
Cannot assign to an immutable value
Cannot assign to a readonly variable or a value
3 6
```

## Iterating a Hash hands out its containers too

Every value of a Hash lives in its own Scalar. `.values`, the Pairs of plain
iteration and `.kv` all hand out those containers:

```raku
my %h = a => 1, b => 2;
for %h.values { $_ *= 10 }
say %h.sort;
for %h { .value += 1 }
say %h.sort;
for %h.kv -> $k, $v is rw { $v = 0 }
say %h.sort;
```
```output
(a => 10 b => 20)
(a => 11 b => 21)
(a => 0 b => 0)
```

Without `is rw`, the `$v` of the last loop would be read-only, as for arrays.

## `:=` between elements makes two slots one

An array or hash element can be bound like a variable. Binding one element
to another makes the two slots share a container; binding a variable to an
element, or an element to a variable, makes an alias in the same way.

```raku
my @a = 1, 2;
@a[0] := @a[1];
@a[1] = 7;
say @a;
my $x := @a[0];
$x = 9;
say @a;
my %h;
my $v = 1;
%h<k> := $v;
$v = 3;
say %h<k>;
```
```output
[7 7]
[9 9]
3
```

Binding a slot to a plain value leaves it with no container, and the slot
then refuses assignment:

```raku
my %h;
%h<k> := 5;
%h<k> = 6;
```
```output
```
```stderr
Cannot assign to an immutable value
  in block <unit> at example.raku line 3

```

## `my (…) :=` binds read-only, and `is rw` makes an alias

Parentheses after `my` on the left of `:=` are a signature, and binding a
list to it works like passing arguments to a routine: each parameter takes
one element, read-only, even when the element is an Array's container. A
parameter declared `is rw` is bound to the container itself.

```raku
my @a = 1, 2;
my ($x, $y) := @a;
say "$x $y";
try { $x = 9 };
say $!.message;
my ($p is rw, $q) := @a;
$p = 9;
say @a;
```
```output
1 2
Cannot assign to a readonly variable or a value
[9 2]
```

## `my (…) :=` checks the count; `my (…) =` does not

Assigning to a list of variables fills them in order, resets any left over
to their default and drops extra values. Binding is a signature match, so
the counts must fit, unless the signature allows otherwise with a slurpy or
an optional parameter:

```raku
my ($a, $b) = 1, 2, 3;
say ($a, $b).raku;
my ($c, $d) = 1;
say ($c, $d).raku;
my ($e, *@rest) := (1, 2, 3);
say ($e, @rest).raku;
my ($x, $y) := (1, 2, 3);
```
```output
(1, 2)
(1, Any)
(1, [2, 3])
```
```stderr
Too many positionals passed to '<unit>'; expected 2 arguments but got 3
  in block <unit> at example.raku line 7

```

The message calls the signature's owner `<unit>`, the name of the program's
mainline, because no routine is involved.

## A bound `@` or `%` name takes the object's own type

`my @a = …` creates an Array and copies values into it. `my @a := …` makes
`@a` a name for the object on the right, which only has to be Positional: a
List, a Range or an Array will do. The variable then behaves as that object
does. A Seq is not Positional, and binding one to an `@` name is a type
error.

```raku
my @l := (1, 2);
say @l.^name;
my @r := 1..3;
say @r.^name;
my %m := Map.new((a => 1));
say %m.^name;
try { my @s := (1, 2).map(* + 1) };
say $!.message;
```
```output
List
Range
Map
Type check failed in binding; expected Positional but got Seq ((2, 3).Seq)
```

Assigning to a bound List does not replace it. The values on the right are
assigned to the List's elements one by one, the same element-by-element
assignment that `($a, $b) = 3, 4` performs. A List of plain values fails at
its first element; a List of variables passes the values on to them:

```raku
my @k := (1, 2);
try { @k = 3, 4 };
say $!.message;
my ($a, $b);
my @l := ($a, $b);
@l = 3, 4;
say "$a $b";
```
```output
Cannot modify an immutable Int (1)
3 4
```

## `=` gives an array new containers but shares what they hold

List assignment creates a fresh Scalar for each element and copies the value
into it. The copy is one level deep: when the value is itself an Array, the
new container holds the same Array object. Binding shares everything.

```raku
my @a = 1, [2, 3];
my @copy = @a;
my @alias := @a;
@a[0] = 9;
@a[1][0] = 8;
say @copy;
say @alias;
```
```output
[1 [8 3]]
[9 [8 3]]
```

The same holds for a Scalar that holds an array, and for an array that
appears as one element of the list on the right of an assignment:

```raku
my $r = [1, 2];
my $s = $r;
$s.push(3);
say $r;
my @b = 4, 5;
my @nested = @b, 6;
@b.push(7);
say @nested.raku;
```
```output
[1 2 3]
[[4, 5, 7], 6]
```

## `@a = @a, 3` puts the array inside itself
tags: trap

An array on the right of a list assignment is stored as one element, not
copied, as the previous corner showed. So an array that appears in its own
assignment ends up containing itself. `@b ,= 3` is the same assignment
written shorter, and it does the same:

```raku
my @a = 1, 2;
@a = @a, 3;
say @a.elems;
say @a[0] === @a;
my @b = 1, 2;
@b ,= 3;
say @b[0] === @b;
my @c = 1, 2;
@c = |@c, 3;
say @c;
```
```output
2
True
True
[1 2 3]
```

A slip, `|@c`, spreads the old elements into the new list, which is what
was meant; `@c.push(3)` does it without building a new list.

## `$(…)` and `.item` make a value one item

Putting a value in a Scalar *itemizes* it: whatever is inside, the Scalar
counts as a single item in any list. `$( … )`, the method `.item` and the sub
`item` all do it, and `$@a` and `$%h` itemize an array or hash variable. A
list assignment then stores the item as one element:

```raku
my @a = (1, 2);
my @b = $(1, 2);
my @c = (1, 2).item;
say @a.raku;
say @b.raku;
say @c.raku;
my @d = 3, 4;
say $@d.raku;
say item(1, 2).raku;
```
```output
[1, 2]
[(1, 2),]
[(1, 2),]
$[3, 4]
$(1, 2)
```

A `$` variable that holds a list is an item already, which is the difference
between the two assignments below:

```raku
my @x = [1, 2, 3];
my $r = [1, 2, 3];
my @y = $r;
say @x.elems;
say @y.elems;
```
```output
3
1
```

## `for` iterates an item once
tags: trap

`for` walks through a list, but it does not walk into an item. A list, an
array or a hash held in a `$` variable is one item, so the loop body runs
once, with the whole thing in `$_`:

```raku
my $list = (1, 2, 3);
for $list { say "got: $_" }
for @$list { say "each: $_" }
my $h = { a => 1, b => 2 };
my $n = 0;
$n++ for $h;
say $n;
```
```output
got: 1 2 3
each: 1
each: 2
each: 3
1
```

`@$list`, or `$list.list`, asks for the list inside the item; `%$h` does the
same for a hash.

## `<>` takes a value out of its container

The zen slice `<>` *decontainerizes*: it returns the value that a Scalar
holds, without the Scalar. It is the shortest way to make an item behave as
a list again, and it works on array elements, which are all Scalars:

```raku
my $list = (1, 2, 3);
say $list.VAR.^name;
say $list<>.VAR.^name;
for $list<> { say $_ }
my @a = (1, 2), 3;
for @a[0] { say "once: $_" }
for @a[0]<> { say "each: $_" }
```
```output
Scalar
List
1
2
3
once: 1 2
each: 1
each: 2
```

## `.raku` marks an item with `$`, except inside an Array

`say` and `.gist` never show containers. `.raku` does: an itemized list
prints with a leading `$`, and so does a hash value that holds a list. Inside
an Array every element is in a Scalar, so the marker would tell nothing, and
`.raku` leaves it out:

```raku
say $(1, 2);
say $(1, 2).raku;
say (1, $(2, 3)).raku;
say [1, $(2, 3)].raku;
my %h = a => [1, 2];
say %h.raku;
say (a => [1, 2]).raku;
```
```output
(1 2)
$(1, 2)
(1, $(2, 3))
[1, (2, 3)]
{:a($[1, 2])}
:a([1, 2])
```

The last two lines differ because a hash stores each value in a Scalar of
its own, while a Pair holds exactly what it was given, here a bare Array.

## `flat` stops at a Scalar container

`flat` descends into every list it meets, except those in a Scalar. Array
elements are all in Scalars, so `.flat` on an array of arrays flattens
nothing, while the same arrays sitting directly in a List are spread:

```raku
say (1, (2, (3, 4))).flat.raku;
say (1, [2, 3]).flat.raku;
say [1, [2, 3]].flat.raku;
say (1, $(2, 3)).flat.raku;
say [1, [2, 3]].flat(:hammer).raku;
```
```output
(1, 2, 3, 4).Seq
(1, 2, 3).Seq
(1, $[2, 3]).Seq
(1, $(2, 3)).Seq
(1, 2, 3).Seq
```

`:hammer` breaks through the containers. A slip does not: `|@a` puts the
elements into a new list, but each one is still in its Scalar. Taking the
lists out of their containers first works:

```raku
my @a = [1, 2], [3, 4];
say @a.flat.elems;
say (|@a).flat.elems;
say @a.map(*.Slip).elems;
say @a>>.list.flat.elems;
```
```output
2
2
4
4
```

## `($a, $b) = …` reads the whole right side first

`($a, $b) = …` is a list assignment to each variable in turn. The right side
is read into values before any variable changes, so a swap needs no
temporary. A `*` in the list skips a value, a variable with no value left is
reset to its default (a typed variable to its type object), and an array
target takes all the rest:

```raku
my $x = 1;
my $y = 2;
($x, $y) = ($y, $x);
say "$x $y";
my ($p, $q);
($p, *, $q) = 1, 2, 3;
say "$p $q";
my Int $i = 5;
($i, my $z) = ();
say ($i, $z).raku;
my ($first, @rest) = 1, 2, 3;
say ($first, @rest).raku;
```
```output
2 1
1 3
(Int, Any)
(1, [2, 3])
```

The `*` works only with variables declared beforehand. Parentheses after
`my` are a signature, and `my ($a, *, $c)` is a compile-time error,
*Malformed parameter*.

## A nested group in `my (…) =` does not destructure
tags: quirk

Inside `my (…)` on the left of `=`, a parenthesised group of variables does
not receive a sublist. Its variables are declared but left as `Mu`, not even
`Any`, and the value in its position is dropped. With `:=` the same
declaration is a signature with a sub-signature, and it unpacks as expected:

```raku
my ($a, ($b, $c), $d) = 1, (2, 3), 4;
say ($a, $b, $c, $d).raku;
my ($e, ($f, $g), $h) := 1, (2, 3), 4;
say ($e, $f, $g, $h).raku;
```
```output
(1, Mu, Mu, 4)
(1, 2, 3, 4)
```

## A routine strips the container unless declared `is rw` or `is raw`

A `do` block hands back the container of its last expression, so it can be
assigned to. A routine strips the container: the caller receives the value,
and assigning to the call fails. A routine declared `is rw` or `is raw`
returns the container itself.

```raku
my $n = 1;
(do { $n }) = 2;
say $n;
sub raw is raw { $n }
raw() = 3;
say $n;
sub number { $n }
number() = 4;
```
```output
2
3
```
```stderr
Cannot modify an immutable Int (3)
  in block <unit> at example.raku line 8

```

Being an item survives the stripping. A routine that returns a `$` variable
holding a list returns one item, which a `for` loop does not walk into:

```raku
my $l = (1, 2);
sub items { $l }
say items().raku;
for items() { say "got: $_" }
```
```output
$(1, 2)
got: 1 2
```

## A Pair keeps the container of its value

`key => $x` does not copy `$x`: the Pair holds the container of `$x`, and
writing through `.value` changes the variable. The Pairs that a hash hands
out hold the hash's own containers in the same way. A Pair built from a
literal holds a plain value, and its `.value` is read-only; the key is
always read-only.

```raku
my $x = 1;
my $p = a => $x;
$p.value = 5;
say $x;
$x = 7;
say $p.value;
my %h = a => 1;
%h.pairs[0].value = 9;
say %h<a>;
my $q = a => 1;
try { $q.value = 2 };
say $!.^name;
try { $p.key = "b" };
say $!.^name;
```
```output
5
7
9
X::Assignment::RO
X::Assignment::RO
```

Storing the Pair in a hash is different: hash assignment copies each value
into a new container, so after `my %g = a => $x`, assigning to `%g<a>`
leaves `$x` alone.

## Pairs that hold the same variable are not identical

`===` compares two Pairs by key and value only when the values are plain
values. A Pair that holds a container compares by identity, so two Pairs
built from the same variable are different, although `eqv` finds them
equal. `.unique` goes by `===`:

```raku
my $x = 1;
say (a => 1) === (a => 1);
say (a => $x) === (a => $x);
say (a => $x) eqv (a => 1);
say ((a => 1), (a => 1)).unique.elems;
say ((a => $x), (a => $x)).unique.elems;
```
```output
True
False
True
1
2
```

## A Map is immutable, but the containers inside it are not
tags: quirk

A Map refuses to change: adding a key, deleting one, binding one and
assigning to one that holds a plain value all die. What a Map stores,
though, is whatever its Pairs held. A Pair built from a variable brings the
variable's container, and `Map.new(%h)` takes over the hash's containers,
so a write through the Map, or through the hash, still gets through. New
keys added to the hash do not appear. `%h.Map` copies the values instead.

```raku
my $x = 1;
my $m = Map.new((a => $x, b => 2));
$m<a> = 5;
say $x;
try { $m<b> = 5 };
say $!.message;
my %h = k => 1;
my $live = Map.new(%h);
my $snap = %h.Map;
%h<k> = 2;
%h<new> = 3;
say $live<k>;
say $snap<k>;
say $live.elems;
```
```output
5
Cannot change key 'b' in an immutable Map
2
1
1
```

## `temp` restores a variable when its block is left

`temp $x` saves the current value of `$x` and puts it back when the
enclosing block is left, normally or by an exception. In between the
variable can be changed freely, and every routine called from inside the
block sees the new value:

```raku
our $level = 1;
sub show { say "level $level" }
sub deeper {
    temp $level = 2;
    show;
}
deeper;
show;
```
```output
level 2
level 1
```

It works on whole arrays and hashes as well as on scalars and single
elements:

```raku
my $x = 1;
try { temp $x = 2; die "oops" };
say $x;
my @a = 1, 2;
{ temp @a; @a.push(3); say @a.elems }
say @a.elems;
my %h = a => 1;
{ temp %h<a> = 9; say %h<a> }
say %h<a>;
```
```output
1
3
2
9
1
```

## `temp` takes one term, and it must be a container

`temp` and `let` are prefix operators on the autoincrement level. They take
a single term, so in `temp $x = 2 ~ "z"` the assignment gets the whole
concatenation. `temp` returns the container it saved, so it can be the
target of any assignment, and without one the variable keeps its current
value until it is changed. Applied to something that is not a container,
`temp` dies at run time:

```raku
my $x = 1;
{ temp $x = 2 ~ "z"; say $x }
say $x;
{ (temp $x) ~= "!"; say $x }
say $x;
try { temp 42 };
say $!.^name;
```
```output
2z
1
1!
1
X::Localizer::NoContainer
```

## A `do` block returns a `temp` variable already restored
tags: trap

A `do` block returns the container of its last expression, not a copy of
its value, as shown [above](#ch:containers:a-routine-strips-the-container-unless-declared-is-rw-or-is-raw).
When that container was localized with `temp`, the caller reads it after the
block has been left, and by then the old value is back. A routine strips the
container before it leaves, so it returns the temporary value:

```raku
my $x = 1;
say do { temp $x = 5; $x };
say do { temp $x = 5; $x<> };
say do { temp $x = 5; +$x };
sub f { temp $x = 5; $x }
say f();
```
```output
1
5
5
5
```

Decontainerizing with `<>`, or any expression that computes a new value,
fixes the value before the block ends.

## `let` keeps its change only if the block succeeds
tags: trap

`let` is `temp` with a condition. The old value comes back when the block is
left by an exception, or when it ends with an undefined value such as `Nil`,
`Any` or a Failure. Any defined value counts as success and keeps the
change, even `0` or `False`, and it does not matter whether the caller uses
the value.

```raku
my $x;
sub ends-zero  { let $x = 2; 0 }
sub ends-false { let $x = 2; False }
sub ends-nil   { let $x = 2; Nil }
sub ends-fail  { let $x = 2; fail "no" }
$x = 1; ends-zero;           say "0:       $x";
$x = 1; ends-false;          say "False:   $x";
$x = 1; ends-nil;            say "Nil:     $x";
$x = 1; my $f = ends-fail;   say "Failure: $x";
$x = 1; try { let $x = 2; die "oops" }; say "die:     $x";
$x = 1; { let $x = 2; Any }; say "Any:     $x";
```
```output
0:       2
False:   2
Nil:     1
Failure: 1
die:     1
Any:     1
```

The last line shows that the rule is not limited to routines: a bare block
that ends with `Any` restores as well.
