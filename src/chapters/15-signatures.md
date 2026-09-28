---
title: Signatures and Introspection
part: Code
summary: A signature decides which arguments a call accepts and how each one is bound, multi dispatch picks the narrowest signature, and every code object, signature, parameter and attribute can be asked what it is.
---

A *signature* is the list of parameters of a routine or a block: the part in
parentheses after `sub name`, or after the arrow of a pointy block. When code
is called, the *binder* matches the arguments against it. It counts them,
checks their types and constraints, and decides for each parameter whether it
gets the argument itself, a read-only view of it, a copy or a converted
value. A mismatch is an error at the call, before the body runs.

The first half of this chapter is about those rules, and about multi
dispatch, which chooses between several signatures of one name. The second
half is about introspection. Code objects, signatures, parameters and
attributes are ordinary objects that can be asked about themselves, and some
of their answers are surprising, a few of them wrong.

Containers, and how `is rw` and `is raw` keep them, are in [Containers and
Binding](#ch:containers). The `.&` call form and calls without parentheses
are in [Whitespace, Terms and Blocks](#ch:whitespace); the exception classes
named here are described in [Exceptions and Failures](#ch:exceptions).

## `.arity` counts required positionals; `.count` counts all of them

`.arity` is the number of positional arguments a piece of code needs, and
`.count` the number it can take. An optional or defaulted positional raises
only the count. A named parameter raises neither, even a required one. A
positional slurpy makes the count infinite, and an infinite count is the
`Num` `Inf` rather than an `Int`.

```raku
sub two($x, $y) { }
sub opt($x, $y?) { }
sub dflt($x = 1) { }
sub named($x, :$n!) { }
sub slurpy($x, *@rest) { }
say (&two.arity, &two.count);
say (&opt.arity, &opt.count);
say (&dflt.arity, &dflt.count);
say (&named.arity, &named.count);
say (&slurpy.arity, &slurpy.count);
say &slurpy.count.^name;
```
```output
(2 2)
(1 2)
(0 1)
(1 1)
(1 Inf)
Num
```

A block with no signature can still take one argument, its topic `$_`, so
its arity is 0 and its count 1. Placeholder variables are parameters and
count, a named placeholder `$:x` does not, and a WhateverCode counts its
stars. A method counts its invocant as well, so `method m($x)` needs two
arguments. `&say` takes anything.

```raku
say { $_ }.arity, " ", { $_ }.count;
say { $^a + $^b }.arity;
say { $:x }.count;
my $w = * + *;
say $w.arity;
class C { method m($x) { } }
say C.^lookup('m').arity;
say &say.arity, " ", &say.count;
```
```output
0 1
2
0
2
2
0 Inf
```

The count is what `map` and `for` read to decide how many elements to hand to
each call: see [Lists, Arrays, Seqs and
Slips](#ch:lists:a-map-block-takes-as-many-elements-as-it-has-parameters).

## A call with the wrong arguments dies with `X::AdHoc`

The binder checks the arguments before the body runs. Too few positionals,
too many, a missing required named argument and a named argument that no
parameter takes are all errors of the same class, `X::AdHoc`, told apart only
by the message:

```raku
sub one($x) { $x }
my @none;
try one(|@none);
say $!.message;
try one(1, :verbose);
say $!.message;
sub need(:$name!) { $name }
my %none;
try need(|%none);
say $!.message;
say $!.^name;
```
```output
Too few positionals passed; expected 1 argument but got 0
Unexpected named argument 'verbose' passed
Required named parameter 'name' not passed
X::AdHoc
```

The empty slips `|@none` and `|%none` pass no arguments at all. They are
there to hide the missing arguments from the compiler, which would otherwise
refuse the program, as the next corner shows.

## A call that can never bind is refused before the program runs
tags: trap

When a named sub is called with arguments whose types the compiler can see,
such as literals, it checks them against the signature and rejects a call
that cannot work. The whole program is refused, even when the call is in a
branch that never runs, and a `try` around the call does not help:

```raku
sub one($x) { $x }
if False { one(1, 2) }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Calling one(Int, Int) will never work with declared signature ($x)
at example.raku:2
------> if False { <HERE>one(1, 2) }
```

The check covers the positional arguments and the required named ones, but
not a named argument that nobody takes, which waits until the call is made:

```raku
sub one($x) { $x }
say "running";
one(1, :verbose);
```
```output
running
```
```stderr
Unexpected named argument 'verbose' passed
  in sub one at example.raku line 1
  in block <unit> at example.raku line 3

```

To see the run-time error of a bad positional argument, pass it through a
variable, whose value the compiler does not track.

## A method takes any named argument; a sub refuses it

Every method has an implicit slurpy hash, `*%_`, at the end of its
signature. A named argument that no parameter asks for is collected there
and ignored. The same call to a sub dies:

```raku
class Greeter {
    method hello($who) { "hello, $who" }
}
say Greeter.hello("you", :loud);
say Greeter.^lookup('hello').signature;
sub hello($who) { "hello, $who" }
hello("you", :loud);
```
```output
hello, you
(Greeter $:: $who, *%_)
```
```stderr
Unexpected named argument 'loud' passed
  in sub hello at example.raku line 6
  in block <unit> at example.raku line 7

```

The printed signature also shows the invocant, the first parameter of every
method; its odd spelling is a [bug of its
own](#ch:signatures:a-methods-signature-prints-which-does-not-parse-back).

## A Pair written in a call is a named argument
tags: trap

`name => value` and `:name(value)` in an argument list are named arguments,
not Pairs passed as values. A Pair whose key is quoted, a Pair in
parentheses and a Pair in a variable are positional arguments, and a slip
`|` turns a Pair back into a named argument:

```raku
sub show($p?, *%n) { "positional: {$p.raku}, named: {%n.raku}" }
my $pair = a => 1;
say show(a => 1);
say show(:a(1));
say show("a" => 1);
say show((a => 1));
say show($pair);
say show(|$pair);
```
```output
positional: Any, named: {:a(1)}
positional: Any, named: {:a(1)}
positional: :a(1), named: {}
positional: :a(1), named: {}
positional: :a(1), named: {}
positional: Any, named: {:a(1)}
```

A sub whose only parameter is positional therefore dies with *Too few
positionals* when it is called as `f(a => 1)`.

## Named parameters are optional unless marked with `!`

A named parameter, `:$name`, is optional: left out, it is undefined, or it
takes its default. A trailing `!` makes it required. `:v(:$verbose)` gives
the parameter a second name, and either name sets it. `.named_names` lists
the names, innermost first.

```raku
sub greet(:$name = "world", :v(:$verbose)) {
    ($verbose ?? "Hello there, " !! "Hi, ") ~ $name
}
say greet;
say greet(:name<you>);
say greet(:v);
say greet(:verbose, name => "all");
say &greet.signature.params[1].named_names;
```
```output
Hi, world
Hi, you
Hello there, world
Hello there, all
(verbose v)
```

## A default is computed at each call, and may use earlier parameters

A default value is an expression, evaluated every time the argument is left
out, in the scope of the signature: a later parameter's default can use an
earlier parameter. A printed signature shows a literal default as written
and any other default as `Code.new`.

```raku
my $calls = 0;
sub stamp { ++$calls }
sub f($x = stamp()) { $x }
say (f(), f(), f(10), f()).join(" ");
sub span($from, $to = $from + 10) { "$from..$to" }
say span(1);
say span(1, 3);
say &f.signature;
say &span.signature;
```
```output
1 2 10 3
1..11
1..3
($x = Code.new)
($from, $to = Code.new)
```

A literal default of the wrong type is refused at compile time, *Default
value 's' will never bind to a parameter of type Int*. A default replaces
only a missing argument: an explicit `Nil` is an argument, as [Nil, Any and
the Undefined](#ch:nil-any:a-default-value-does-not-replace-a-nil-argument)
shows.

## A parameter is read-only; `is copy` makes a private copy

A plain parameter is a read-only view of its argument. Assigning to it dies,
even when the argument is a variable. `is copy` gives the routine a fresh
variable holding the argument's value, which it may change without touching
the caller's.

```raku
sub try-assign($x) { $x = 1 }
my $v = 3;
try try-assign($v);
say $!.message;
sub local($x is copy) { $x *= 10; $x }
say local($v), " ", $v;
```
```output
Cannot assign to a readonly variable or a value
30 3
```

The same read-only rule applies to the parameters of a pointy block and to
`my (…) :=`, as [Containers and
Binding](#ch:containers:my-binds-read-only-and-is-rw-makes-an-alias) shows.

## `is rw` needs a variable, and a typed one checks its type

`is rw` binds the parameter to the caller's container, so an assignment
inside the routine changes the variable. An argument without a container, a
literal, a List, `Any` or `Nil`, is refused with `X::Parameter::RW`:

```raku
sub bump($x is rw) { $x++ }
my $n = 1;
bump($n);
say $n;
try bump(5);
say $!.^name;
say $!.message;
try bump((1, 2));
say $!.^name;
try bump(Any);
say $!.^name;
```
```output
2
X::Parameter::RW
Parameter '$x' expects a writable container (variable) as an argument,
but got '5' (Int) as a value without a container.
X::Parameter::RW
X::Parameter::RW
```

A typed `is rw` parameter refuses a variable declared with another type, and
takes an untyped variable if the value inside fits. An assignment through a
typed `is rw` or `is copy` parameter is checked against the parameter's
type:

```raku
sub typed(Int $x is rw) { $x = 1 }
my Str $s = "a";
try typed($s);
say $!.^name;
my $untyped = 0;
typed($untyped);
say $untyped;
sub retype(Int $x is copy) { $x = "s" }
try retype(5);
say $!.message;
```
```output
X::TypeCheck::Binding::Parameter
1
Type check failed in assignment to $x; expected Int but got Str ("s")
```

## `\x` and `is raw` pass the argument as it is

A sigilless parameter `\x`, like a parameter marked `is raw`, is bound to
exactly what was passed: the variable's own container when the argument is a
variable, which it can then assign to, and the bare value when it is a
literal. `.VAR` of a plain parameter says `Scalar` in both cases.

```raku
sub raw(\x) { x.VAR.^name }
sub plain($x) { $x.VAR.^name }
my $v = 1;
say raw($v);
say raw(1);
say plain($v);
say plain(1);
sub write(\x) { x = 9 }
write($v);
say $v;
try write(1);
say $!.message;
```
```output
Scalar
Int
Scalar
Scalar
9
Cannot modify an immutable Int (1)
```

## `:D` and `:U` check definedness, with their own exception

A type smiley constrains a parameter to instances (`Int:D`) or to type
objects (`Int:U`). A failure is not a type-check failure but
`X::Parameter::InvalidConcreteness`, whose message guesses at the mistake:

```raku
sub defined(Int:D $x) { "got $x" }
sub undefined(Int:U $x) { "got {$x.^name}" }
my $type = Int;
my $five = 5;
say undefined(Int);
try defined($type);
say $!.^name;
say $!.message;
try undefined($five);
say $!.message;
```
```output
got Int
X::Parameter::InvalidConcreteness
Parameter '$x' of routine 'defined' must be an object instance of type
'Int', not a type object of type 'Int'. Did you forget a '.new'?
Parameter '$x' of routine 'undefined' must be a type object of type
'Int', not an object instance of type 'Int'. Did you forget a 'multi'?
```

On an invocant the smiley separates instance methods from class methods, and
calling an instance method on the class dies in the same way:

```raku
class Counter {
    has $.n = 0;
    method up(Counter:D:) { $!n + 1 }
    method make(Counter:U:) { self.new }
}
say Counter.make.up;
try Counter.up;
say $!.message;
```
```output
1
Invocant of method 'up' must be an object instance of type 'Counter',
not a type object of type 'Counter'. Did you forget a '.new'?
```

## A failed type check names the parameter, the value and the type

An argument of the wrong type throws `X::TypeCheck::Binding::Parameter`. The
exception carries what was passed in `.got`, the parameter's type in
`.expected` and the parameter's name in `.symbol`:

```raku
sub half(Int $x) { $x / 2 }
my $s = "4";
try half($s);
my $e = $!;
say $e.^name;
say $e.got.raku;
say $e.expected.^name;
say $e.symbol;
say $e.message;
```
```output
X::TypeCheck::Binding::Parameter
"4"
Int
$x
Type check failed in binding to parameter '$x'; expected Int but got Str ("4")
```

The string `"4"` is not converted: a type constraint only checks. A
coercion type, [below](#ch:signatures:int-calls-int-on-whatever-arrives),
converts.

## `where` smartmatches the argument against anything

A `where` clause is tested by smartmatching the argument against the
expression after it, so it takes a block or WhateverCode, a range, a
literal, a type or a regex. A failure throws the same class as a type
check, with a different message, and `.expected` then holds the constraint
itself:

```raku
sub small($x where 1..3) { "small $x" }
sub answer($x where 42) { "the answer" }
sub word($x where Str) { "word $x" }
sub digits($x where /^\d+$/) { "digits $x" }
sub big($x where * > 5) { $x }
say small(2);
say answer(42);
say word("hi");
say digits("123");
my $one = 1;
try big($one);
say $!.message;
say $!.expected.^name;
```
```output
small 2
the answer
word hi
digits 123
Constraint type check failed in binding to parameter '$x'; expected anonymous constraint to be met but got Int (1)
WhateverCode
```

## An optional parameter's `where` runs when the argument is left out
tags: trap

A `where` clause is checked even when an optional parameter receives no
argument. The parameter then holds its type object, and the test runs
against that. A numeric comparison on a type object throws, so calling the
routine without the argument dies:

```raku
sub maybe(Int $x? where { $_ > 5 }) { $x // "none" }
say maybe(9);
try maybe();
say $!.^name;
sub fixed(Int $x? where { !.defined || $_ > 5 }) { $x // "none" }
say fixed();
```
```output
9
X::Numeric::Uninitialized
none
```

The second sub lets an undefined value through explicitly.

## A `subset` is a named type with a `where`

`subset Name of Type where …` names a constraint so that it can be used
wherever a type can. A failing argument gets a message that names the
subset:

```raku
subset Positive of Int where * > 0;
sub root(Positive $n) { $n.sqrt }
say root(16);
my $neg = -4;
try root($neg);
say $!.message;
say 5 ~~ Positive;
say -5 ~~ Positive;
say 5.5 ~~ Positive;
```
```output
4
Constraint type check failed in binding to parameter '$n'; expected Positive but got Int (-4)
True
False
False
```

A subset works on variables too, and checks every assignment. A subset
without `of` refines `Any`, so its test sees whatever arrives: the string
`"4"` is `Even` below, because `%%` turns it into a number.

```raku
subset Small of Int where * < 10;
my Small $x = 5;
try { $x = 20 };
say $!.message;
subset Even where * %% 2;
say 4 ~~ Even;
say "4" ~~ Even;
```
```output
Type check failed in assignment to $x; expected Small but got Int (20)
True
True
```

In multi dispatch a subset is narrower than the type it refines, so its
candidate is tried first:

```raku
subset Positive of Int where * > 0;
multi kind(Positive $n) { "positive" }
multi kind(Int $n) { "int" }
say kind(5);
say kind(-5);
```
```output
positive
int
```

## `Int()` calls `.Int` on whatever arrives

A coercion type `Int()` accepts any argument and converts it by calling its
`.Int` method, so a string, a Rat or an object of a class with an `Int`
method all arrive as integers. An argument that is already an `Int` passes
untouched, the type object `Int` included, and so does a `Bool`, which is an
`Int`.

```raku
sub to-int(Int() $x) { $x.raku }
say to-int("42");
say to-int(4.7);
say to-int(" 7 ");
say to-int("0x10");
say to-int(True);
say to-int(Int);
class Money { method Int { 100 } }
say to-int(Money.new);
```
```output
42
4
7
16
Bool::True
Int
100
```

`Int(Str)` names the accepted source type as well: it takes a Str and
converts it, takes an Int as it is, and refuses anything else. `Str()`
converts with `.Str`, so a list arrives joined by spaces:

```raku
sub from-str(Int(Str) $x) { $x.raku }
say from-str("42");
say from-str(4);
my $rat = 4.7;
try from-str($rat);
say $!.^name;
sub to-str(Str() $x) { $x.raku }
say to-str(42);
say to-str([1, 2]);
```
```output
42
4
X::TypeCheck::Binding::Parameter
"42"
"1 2"
```

## A coercion that fails binds a Failure
tags: quirk

When the conversion itself fails, as `"x".Int` does, the binder does not
throw. The parameter receives the `Failure` that the conversion returned,
and the body runs with it. Smartmatching a Capture against the signature
agrees that the argument binds. Only a `where` clause on the same parameter
touches the Failure, and then its exception is thrown:

```raku
sub coerced(Int() $x) { $x.^name }
say coerced("x");
my $f = (sub (Int() $x) { $x })("x");
say $f.defined;
say $f.exception.^name;
say \("x") ~~ :(Int() $a);
sub checked(Int() $x where * > 3) { $x }
try checked("x");
say $!.^name;
```
```output
Failure
False
X::Str::Numeric
True
X::Str::Numeric
```

## A coercion from an undefined value warns; other bad sources throw

`Any` and `Nil` convert to 0, with the usual warning about an undefined
value in numeric context:

```raku
sub to-int(Int() $x) { $x.raku }
say to-int(Any);
say to-int(Nil);
```
```output
0
0
```
```stderr
Use of uninitialized value of type Any in numeric context
  in sub to-int at example.raku line 1
Use of Nil in numeric context
  in sub to-int at example.raku line 1
```

A source that cannot be converted at all throws at the call, each case with
its own class: a `Str` type object, a complex number, an object without an
`Int` method, and an `Int` method that returns something else.

```raku
sub to-int(Int() $x) { $x }
my $type = Str;
try to-int($type);
say $!.^name;
try to-int(1i);
say $!.^name;
try to-int(class { }.new);
say $!.^name;
try to-int(class { method Int { "not an Int" } }.new);
say $!.^name;
```
```output
X::AdHoc
X::Numeric::Real
X::Multi::NoMatch
X::Coerce::Impossible
```

## A coerced parameter has no container, and its elements are not coerced
tags: quirk

The converted value is new, so there is nothing for `is rw` to write back
to: the binding succeeds, but an assignment dies. `Int() @a` is an array
parameter whose elements must already be Ints; the coercion does not reach
inside. `Int:D()` adds a definedness check after the conversion, and a type
object fails it.

```raku
sub bump(Int() $x is rw) { $x = 1 }
my $s = "5";
try bump($s);
say $!.message;
sub each(Int() @a) { @a.raku }
try each(["1", 2]);
say $!.^name;
sub strict(Int:D() $x) { $x.raku }
say strict("9");
my $type = Str;
try strict($type);
say $!.^name;
```
```output
Cannot assign to an immutable value
X::TypeCheck::Binding::Parameter
9
X::Parameter::InvalidConcreteness
```

## `*@` flattens, `**@` keeps each argument, `+@` decides by the count

A positional slurpy collects the remaining positional arguments into an
array, in one of three ways. `*@a` flattens every list it receives. `**@a`
keeps each argument as one element. `+@a` follows the *single-argument
rule*: one argument that is a list is used as the list of arguments, and
several arguments are kept as they are.

```raku
sub flat(*@a)  { @a.raku }
sub keep(**@a) { @a.raku }
sub one(+@a)   { @a.raku }
say flat([1, 2], 3);
say keep([1, 2], 3);
say one([1, 2], 3);
say flat([1, 2]);
say keep([1, 2]);
say one([1, 2]);
```
```output
[1, 2, 3]
[[1, 2], 3]
[[1, 2], 3]
[1, 2]
[[1, 2],]
[1, 2]
```

The rule is the one that `for` and most list functions follow: a single
Range is spread, a single value is one element, and a list among several
arguments stays whole. `*@a` flattens lists inside lists as deep as they go,
but stops at an item, such as an Array inside an Array, as [`flat`
does](#ch:containers:flat-stops-at-a-scalar-container).

```raku
sub one(+@a) { @a.elems }
say one(1);
say one((1, 2));
say one((1, 2), 3);
say one(1..3);
say one();
sub flat(*@a) { @a.elems }
say flat(1..3, [4, 5]);
say flat(((1, (2, 3)), 4));
say flat([1, [2, 3]]);
```
```output
1
2
2
3
0
5
4
2
```

## A slurpy array is an Array, but `+a` and `is raw` give a List

`*@a`, `**@a` and `+@a` build a new `Array`: assigning to one of its
elements does not reach the caller's variable. The sigilless `+a` and
`*@a is raw` give a `List` instead, even when the argument was an Array.

```raku
sub a(*@a) { @a.^name }
sub b(+@a) { @a.^name }
sub c(+a) { a.^name }
sub d(*@a is raw) { @a.^name }
say a(1), " ", b(1), " ", c(1, 2), " ", c([1, 2]), " ", d(1);
sub change(*@a) { @a[0] = 99 }
my $v = 1;
change($v);
say $v;
```
```output
Array Array List List List
1
```

## A `*@` slurpy of literals has read-only elements
tags: quirk

The elements of an Array are normally containers that can be assigned to.
A `*@a` slurpy is an exception: when every argument is a literal value, its
elements are the bare values, and assigning to one dies. A single variable
among the arguments is enough to give every element a container. `+@a` and
`**@a` always give containers.

```raku
sub set-first(*@a) { @a[0] = 99; @a }
my $v = 1;
say set-first($v, 2);
try set-first(1, 2);
say $!.message;
sub set-plus(+@a) { @a[0] = 99; @a }
say set-plus(1, 2);
```
```output
[99 2]
Cannot assign to an immutable value
[99 2]
```

## A slurpy hash takes the named arguments; a capture takes everything

`*%h` collects every named argument that no other parameter takes, into a
`Hash`. `|c` takes the whole argument list, positional and named, as a
`Capture`, which can be passed on unchanged with `|c`:

```raku
sub opts(*%o) { %o.sort.raku }
say opts(:a, :b(2));
sub both($first, *@rest, *%named) { "$first | @rest[] | %named.sort()" }
say both(1, 2, 3, :x(4));
sub cap(|c) { c.raku }
say cap(1, 2, :n);
sub pass(|c) { opts(|c) }
say pass(:z);
```
```output
(:a, :b(2)).Seq
1 | 2 3 | x	4
\(1, 2, :n)
(:z,).Seq
```

A Pair interpolated into a string joins its key and value with a tab, which
is the gap in the second line.

## `is item` only chooses between candidates
tags: undocumented unasserted

`is item` on an `@` or `%` parameter does not change what it accepts or how
it binds. It matters only in multi dispatch: an itemized argument, such as
`$[1, 2]` or `$@arr`, prefers the `is item` candidate, and anything else the
plain one.

```raku
multi f(@a is item) { "item" }
multi f(@a)         { "plain" }
my @arr = 1, 2;
say f([1, 2]);
say f($[1, 2]);
say f(@arr);
say f($@arr);
say f((1, 2));
sub b(@x is item) { @x.^name }
say b((1, 2));
say b(1..3);
```
```output
plain
item
plain
item
plain
List
Range
```

On a `$` parameter the trait is refused, because a `$` parameter takes an
item anyway:

```raku
sub f($x is item) { }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Cannot use 'is item' on parameter '$x' because:
    only '@' or '%' sigiled parameters can be constrained to itemized arguments
at example.raku:1
------> sub f($x is item<HERE>) { }
    expecting any of:
        constraint
```

## `::T` captures the type of an argument

A parameter written `::T $x` binds the type of its argument to the name `T`,
which later parameters and the body can use like any type. Here it makes a
sub accept two arguments only when they have the same type:

```raku
sub same(::T $a, T $b) { "both {T.^name}" }
say same(1, 2);
say same("a", "b");
my $s = "s";
try same(1, $s);
say $!.message;
sub make(::T $x) { my T $y = $x; $y.VAR.of.^name }
say make(1.5);
say :(::T $x, T $y).raku;
```
```output
both Int
both Str
Type check failed in binding to parameter '$b'; expected Int but got Str ("s")
Rat
:(::T  $x, T $y)
```

The printed signature has two spaces after `::T`.

## A sub-signature unpacks an argument

Parentheses after a parameter give it a *sub-signature*, which is bound to
the argument in turn: a list is unpacked by position, a hash by name, and an
object by its accessors, as named arguments. The parameter itself may be
left anonymous. A pointy block takes sub-signatures too, which is how a
`for` loop unpacks a list of lists:

```raku
sub first-rest(@a ($first, *@rest)) { "$first then @rest[]" }
say first-rest([1, 2, 3]);
sub point(% (:$x, :$y)) { "x=$x y=$y" }
say point({ x => 1, y => 2 });
for (1, 2), (3, 4) -> ($a, $b) { say $a + $b }
sub pair-parts(Pair $ (:key($k), :value($v))) { "$k is $v" }
say pair-parts((a => 1));
```
```output
1 then 2 3
x=1 y=2
3
7
a is 1
```

A sub-signature is checked like any other: the wrong number of elements is
an error, and a Capture that does not fit does not smartmatch. Objects are
unpacked through their public attributes:

```raku
sub two(@ ($a, $b)) { "$a $b" }
my @three = 1, 2, 3;
try two(@three);
say $!.message;
say \([1, 2]) ~~ :(@a ($x, $y));
say \([1]) ~~ :(@a ($x, $y));
class Point { has $.x; has $.y }
sub show(Point $ (:$x, :$y)) { "($x, $y)" }
say show(Point.new(x => 1, y => 2));
```
```output
Too many positionals passed to 'two'; expected 2 arguments but got 3 in sub-signature
True
False
(1, 2)
```

Because a sub-signature takes part in multi dispatch, candidates can be
chosen by the shape of the argument:

```raku
multi len(@ ($)) { "one" }
multi len(@ ($, $)) { "two" }
multi len(@) { "many" }
say len([1]);
say len([1, 2]);
say len([1, 2, 3]);
```
```output
one
two
many
```

## Placeholders become parameters in alphabetical order

A block without an explicit signature gets one from its placeholder
variables. `$^a`-style placeholders become required positionals, sorted by
name, not by where they first appear. `$:x`-style placeholders become
*required* named parameters, in order of appearance. Using `@_` adds a
slurpy `*@_`, and `%_` a slurpy `*%_`. Any placeholder takes the place of
the implicit `$_` parameter, even when the block uses `$_` as well.

```raku
my $swap = { $^b ~ $^a };
say $swap.signature;
say $swap("x", "y");
say { $:y ~ $:x }.signature;
say { $^a ~ $:z }.signature;
say { $_ ~ $^a }.signature;
say sub { @_ }.signature;
say { %_ }.signature;
```
```output
($a, $b)
yx
(:$y!, :$x!)
($a, :$z!)
($a)
(*@_)
(*%_)
```

`$swap("x", "y")` binds `"x"` to `$a` and `"y"` to `$b`, and returns them
the other way round. A sub may use placeholders when it has no parameter
list. Code that already has a signature may not, and a method may not use
them at all:

```raku
sub f($x) { $^y }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Placeholder variable '$^y' cannot override existing signature
at example.raku:1
------> sub<HERE> f($x) { $^y }
```

## A block without a signature takes one optional argument

A bare block's signature is `(;; $_? is raw = OUTER::<$_>)`: one optional
positional parameter, the topic, which defaults to the `$_` of the code
around the block. A block called without an argument sees the caller's
topic, and with one argument it sees the argument, whether it uses `$_` or
not:

```raku
say {;}.signature;
$_ = "outer";
say { $_ }();
say { $_ }("argument");
say { "no topic used" }("an argument");
```
```output
(;; $_? is raw = OUTER::<$_>)
outer
argument
no topic used
```

Two arguments are one too many:

```raku
my $b = { $_ };
$b(1, 2);
```
```output
```
```stderr
Too many positionals passed; expected 0 or 1 arguments but got 2
  in block <unit> at example.raku line 1

```

A pointy block with no parameters, `-> { }`, takes no argument at all: its
arity and count are both 0.

## The topic parameter's default is the `Code` type object
tags: quirk

The implicit `$_` parameter prints its default as `OUTER::<$_>`, and it
behaves that way, but asked for its `.default`, it answers the `Code` type
object, which cannot be called:

```raku
say {;}.signature.params[0].raku;
my $p = { $_ }.signature.params[0];
say $p.default.raku;
say $p.optional;
say $p.raw;
try $p.default.();
say $!.message;
```
```output
Mu $_? is raw = OUTER::<$_>
Code
True
True
Cannot invoke a Code type object
```

`Code` is also what `.default` answers for a parameter that has no default,
so the two cannot be told apart this way.

## `&?ROUTINE` and `&?BLOCK` name the running code

`&?ROUTINE` is the innermost routine around the code that mentions it, and
`&?BLOCK` the innermost block. An anonymous sub can call itself through
`&?ROUTINE`, and a block inside a sub sees the sub:

```raku
my $fact = sub ($n) { $n <= 1 ?? 1 !! $n * &?ROUTINE($n - 1) };
say $fact(5);
sub outer-name { { &?ROUTINE.name }() }
say outer-name();
say { &?BLOCK.^name }();
```
```output
120
outer-name
Block
```

Outside every routine there is no `&?ROUTINE`, and the compiler says so:

```raku
say &?ROUTINE.name;
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Undeclared name:
    ?ROUTINE used at line 1. Did you mean 'Routine'?

```

## `-->`, `returns` and `of` declare one return constraint

A return constraint can be written inside the parentheses after `-->`, or
after them with `returns` or `of`. The three are the same thing and print the
same. `.returns` and `.of` answer the constraint, and `Mu` when there is
none.

```raku
sub a($x --> Int) { $x }
sub b($x) returns Int { $x }
sub c($x) of Int { $x }
say &a.signature;
say &b.signature;
say &c.signature;
say &a.returns.^name, " ", &b.of.^name;
sub d($x) { $x }
say &d.returns.^name;
```
```output
($x --> Int)
($x --> Int)
($x --> Int)
Int Int
Mu
```

Giving two of them is a redeclaration, even when they agree:

```raku
sub f(--> Int) returns Int { }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Redeclaration of return type for 'f' (previous return type was Int).
at example.raku:1
```

## A value that fails the return constraint throws `X::TypeCheck::Return`

The constraint is checked on every value the routine returns, whether it is
the last statement's value or comes from `return`. The exception carries the
value in `.got` and the constraint in `.expected`:

```raku
sub count(--> Int) { "three" }
try count();
my $e = $!;
say $e.^name;
say $e.message;
say $e.got.raku;
say $e.expected.^name;
```
```output
X::TypeCheck::Return
Type check failed for return value; expected Int but got Str ("three")
"three"
Int
```

A list of Ints is not an Int, and a value computed by a block inside the
routine is checked when the routine returns it. A type object of the right
type passes, and so does a value with a role mixed in, which keeps its type:

```raku
sub pair(--> Int) { 1, 2 }
try pair();
say $!.^name;
sub typeobj(--> Int) { Int }
say typeobj().raku;
sub mixed(--> Int) { 42 but "forty-two" }
say mixed();
sub inner(--> Int) { -> { "s" }() }
try inner();
say $!.^name;
```
```output
X::TypeCheck::Return
Int
forty-two
X::TypeCheck::Return
```

`Nil` and Failures always pass, even `--> Int:D`: see [Nil, Any and the
Undefined](#ch:nil-any:a-return-type-even-d-lets-nil-and-failures-through).

## `--> 42` and `--> Nil` return a constant whatever the body does

A literal after `-->` is not a type but the return value itself. The body
runs for its effects, and the call returns the constant. `--> Nil` is the
common case: a routine that returns nothing, whatever its last statement
computes.

```raku
sub answer(--> 42) { say "working" }
say answer();
sub nothing(--> Nil) { my $ignored = 2 }
say nothing().raku;
say &answer.signature;
```
```output
working
42
Nil
( --> 42)
```

Such a routine may use a bare `return` to leave early, but not `return` with
a value:

```raku
sub nothing(--> Nil) { return 5 }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
No return arguments allowed when return value Nil is already specified in the signature
at example.raku:1
------> sub nothing(--> Nil) { return 5 <HERE>}
```

The signature's `.returns` is the constant; the routine's `.returns` is the
constant's type:

```raku
sub answer(--> 42) { }
say &answer.signature.returns.raku;
say &answer.returns.raku;
say &answer.^name;
```
```output
42
Int
Sub+{Callable[Int]}
```

## A return constraint makes a routine a `Callable[T]`

A routine declared with a return type has the role `Callable` of that type
mixed in, which shows in its type name. It then matches `Callable[T]`, and it
may be stored in a variable declared as returning `T`. A routine without a
constraint matches no `Callable[T]`.

```raku
sub typed(--> Str) { "s" }
sub plain() { "s" }
say &typed.^name;
say &typed ~~ Callable[Str];
say &plain ~~ Callable[Str];
say &plain.^name;
my Int &counter = sub (--> Int) { 1 };
say &counter.^name;
try { &counter = &typed };
say $!.^name;
```
```output
Sub+{Callable[Str]}
True
False
Sub
Sub+{Callable[Int]}
X::TypeCheck::Assignment
```

An `&` variable is typed `Callable` even when nothing else is said, so it
refuses anything that cannot be called:

```raku
my &c;
say &c.raku;
my $five = 5;
try { &c = $five };
say $!.message;
&c = { $_ * 2 };
say c(21);
```
```output
Callable
Type check failed in assignment to &c; expected Callable but got Int (5)
42
```

A signature cannot be attached to such a variable: `my &c:(Int)` is a
compile-time error, *You can't adverb &c*.

## `return` leaves the innermost routine, through any blocks

`return` belongs to routines, not to blocks. Inside a `map` callback, a loop
body, a block called by hand or any other block, it leaves the routine
around them, and a nested sub returns only from itself:

```raku
sub find-first {
    (1..5).map({ return "found $_" if $_ == 3; $_ }).eager;
    "not found"
}
say find-first();
sub from-loop { for 1..3 { return $_ * 10 if $_ == 2 }; "end" }
say from-loop();
sub from-block { my $b = { return 7 }; $b(); "after" }
say from-block();
sub from-inner { sub inner { return "inner" }; inner(); "outer" }
say from-inner();
```
```output
found 3
20
7
outer
```

`return` takes a list as its argument, and it can sit at the end of a feed.
`.leave`, the method that would leave a given routine, is not implemented:

```raku
sub f { 5 ==> return }
say f();
sub g { return 1, 2 }
say g().raku;
sub h { &h.leave(1) }
h();
```
```output
5
(1, 2)
```
```stderr
Sub.leave() not yet implemented. Sorry.
  in sub h at example.raku line 5
  in block <unit> at example.raku line 6

```

## A `return` with no routine to leave throws

A block that contains `return` must run inside the routine it was written
in. At the top of the program there is no routine, and a block handed out by
a routine that has already returned has lost it. Both throw
`X::ControlFlow::Return`, told apart by `.out-of-dynamic-scope`:

```raku
my $top = { return 1 };
try $top();
say $!.^name;
say $!.out-of-dynamic-scope;
say $!.message;
sub make-block { return { return 3 } }
my $b = make-block();
try $b();
say $!.out-of-dynamic-scope;
say $!.message;
```
```output
X::ControlFlow::Return
False
Attempt to return outside of any Routine
True
Attempt to return outside of immediately-enclosing Routine (i.e. `return` execution is outside the dynamic scope of the Routine where `return` was used)
```

## `return` hands back a read-only container; `return-rw` a writable one
tags: quirk

A routine marked `is rw` returns the container of its last statement, as
[Containers and
Binding](#ch:containers:a-routine-strips-the-container-unless-declared-is-rw-or-is-raw)
shows. An explicit `return` inside it hands back a read-only view instead;
`return-rw` keeps the container writable, and works in a routine without the
trait too.

```raku
my $v = 1;
sub ret() is rw { return $v }
sub ret-rw() is rw { return-rw $v }
sub plain-rw() { return-rw $v }
try { ret() = 2 };
say $!.message;
ret-rw() = 3;
say $v;
plain-rw() = 4;
say $v;
say (sub { return my $x = 5 })().VAR.^name;
say (sub { my $x = 5 })().VAR.^name;
```
```output
Cannot assign to a readonly variable or a value
3
4
Scalar
Int
```

The last two lines show the other side of it: a plain routine strips the
container from its last statement, but a value that leaves through `return`
keeps one, read-only. [Values Nobody
Uses](#ch:sink:return-x-keeps-the-container-that-a-last-statement-drops)
shows where that difference becomes visible.

## `fail` in a block fails the routine around it, or throws

`fail` behaves like `return` with a Failure: from inside a block it leaves
the enclosing routine, which returns the Failure. A block that is not inside
any routine has nothing to return from, and there `fail` throws its
exception at once:

```raku
my $b = -> { fail "from a block" };
try $b();
say $!.^name;
say $!.message;
sub s { fail "from a sub" }
say s().^name;
sub t { my $b = -> { fail "from a block in a sub" }; $b(); "after" }
say t().^name;
```
```output
X::AdHoc
from a block
Failure
Failure
```

## Blocks, routines and WhateverCodes share one type tree

Every piece of code is a `Code`. A `Block` is a Code, a `Routine` is a Block,
and `Sub`, `Method` and `Submethod` are Routines, so a sub smartmatches
`Block`. A `WhateverCode` is a Code but not a Block. `ForeignCode`, the
virtual machine's own code, is not a Code at all.

```raku
say Block.^mro;
say Sub.^mro;
say WhateverCode.^mro;
say sub { } ~~ Block;
say {;} ~~ Routine;
say (* + 1) ~~ Block;
say ForeignCode ~~ Code;
say Regex ~~ Method;
```
```output
((Block) (Code) (Any) (Mu))
((Sub) (Routine) (Block) (Code) (Any) (Mu))
((WhateverCode) (Code) (Any) (Mu))
True
False
False
False
True
```

None of these types can be built with `.new`: code comes only from the
compiler.

```raku
try Code.new;
say $!.^name;
say $!.message;
try Sub.new;
say $!.^name;
```
```output
X::Cannot::New
Cannot make a Code object using .new
X::Cannot::New
```

## A code object knows its name; an anonymous one's is empty

`.name` is the declared name, and the empty string for an anonymous sub, a
block or a pointy block. `anon sub name { }` gives a sub a name without
installing it anywhere. `.gist` is the name with its `&` for a named routine
and `sub { }` for an anonymous one; a method's gist is its bare name.

```raku
sub foo($x) { }
my $anon = sub { };
my $nm = anon sub named-but-hidden { };
say &foo.name.raku;
say $anon.name.raku;
say { 1 }.name.raku;
say $nm.name;
say &foo.gist;
say $anon.gist;
class C { method bar { } }
say C.^lookup('bar').gist;
```
```output
"foo"
""
""
named-but-hidden
&foo
sub { }
bar
```

`.raku` rebuilds the declaration without its body, which it writes as
`...`. The comment before the dots holds the object's identity, which changes
from run to run, so the example below blanks it out. A bare block shows its
implicit topic parameter:

```raku
sub shape($code) { $code.raku.subst(/'#`(' <-[)]>* ')'/, '#`(…)') }
sub foo($x) { }
say shape(&foo);
say shape(-> $x, :$n { });
say shape({ 1 });
```
```output
sub foo ($x) { #`(…) ... }
-> $x, :$n { #`(…) ... }
-> ;; $_? is raw = OUTER::<$_> { #`(…) ... }
```

Using a code object as a string gives its name, with a warning that points
to `.gist` and `.raku`:

```raku
sub foo { }
say "name: " ~ &foo;
```
```output
name: foo
```
```stderr
Sub object coerced to string (please use .gist or .raku to do that)
  in block <unit> at example.raku line 2
```

## `.file`, `.line` and `.package` say where code was declared

A routine knows the file and line of its declaration and the package it
belongs to: `GLOBAL` for a sub in the main program, the class for a method.
Routines of the core setting name their source file under `SETTING::`. A
block has no package, and asking for one dies:

```raku
sub foo { }
say &foo.file;
say &foo.line;
say &foo.package.^name;
say &say.file;
class C { method m { } }
say C.^lookup('m').package.^name;
my $blk = { 1 };
try $blk.package;
say $!.^name;
```
```output
example.raku
1
GLOBAL
SETTING::src/core.c/io_operators.rakumod
C
X::Method::NotFound
```

A sub declared inside another routine is a new closure each time the outer
routine runs, so two of them are not the same object, although they share
their `.static_id`. Each closure has its own copy of the outer variables:

```raku
sub outer { my sub inner { }; &inner }
say outer() === outer();
say outer().static_id == outer().static_id;
sub counter { my $n = 0; sub { ++$n } }
my &a = counter();
my &b = counter();
say a(), a(), b();
```
```output
False
True
121
```

## Smartmatching against code calls it and takes the truth of the result

`$x ~~ $code` calls the code with `$x` as its argument and turns the result
into a `Bool`. Code that takes no argument is called without one. `.ACCEPTS`,
the method behind `~~`, returns the result as it is:

```raku
say 5 ~~ { $_ > 3 };
say 5 ~~ { 0 };
say 5 ~~ { "yes" };
say { 0 }.ACCEPTS(5).raku;
say (5 ~~ { 0 }).raku;
say 5 ~~ sub () { "no parameters" };
say 5 ~~ -> $a { $a == 5 };
```
```output
True
False
True
0
Bool::False
True
True
```

Code that needs two arguments cannot be smartmatched, and an exception
inside the code comes out of the smartmatch:

```raku
my $two = -> $a, $b { True };
try { 5 ~~ $two };
say $!.message;
try { 5 ~~ { die "inside" } };
say $!.message;
```
```output
Too few positionals passed; expected 2 arguments but got 1
inside
```

## `.cando` tells whether a Capture would bind; a routine's ignores extra nameds
tags: quirk

`.cando` takes a Capture and returns a list of the code objects that would
accept it: the code itself, or nothing. On a routine it overlooks a named
argument that no parameter takes, although the same Capture does not
smartmatch the signature and the call dies:

```raku
my $b = { $^a };
say $b.cando(\(1)).elems;
say $b.cando(\(1, 2)).elems;
my $typed = -> Int $x { };
say $typed.cando(\("s")).elems;
sub one($x) { }
say &one.cando(\(1, :n)).elems;
say \(1, :n) ~~ &one.signature;
try one(1, :n);
say $!.message;
```
```output
1
0
0
1
False
Unexpected named argument 'n' passed
```

On a multi, `.cando` lists the candidates that would accept the Capture,
[below](#ch:signatures:a-multis-name-is-its-proto-which-lists-the-candidates).

## A block lists its phasers, and they can be called by hand
tags: undocumented unasserted

`.has-phasers` says whether a block declares any phaser, `.has-loop-phasers`
whether it has a `FIRST`, `NEXT` or `LAST`. `.phasers('ENTER')` returns the
phasers of one kind as code objects, in the order they run: `ENTER`
phasers in the order written, `LEAVE` phasers in reverse. Each can be
called like any block.

```raku
my @log;
my $b = {
    ENTER @log.push("enter 1");
    ENTER @log.push("enter 2");
    LEAVE @log.push("leave 1");
    LEAVE @log.push("leave 2");
    "body"
};
say $b.has-phasers;
say $b.has-loop-phasers;
say $b.phasers('ENTER').elems, " ", $b.phasers('LEAVE').elems;
$b();
say @log;
@log = ();
$_() for $b.phasers('LEAVE');
say @log;
```
```output
True
False
2 2
[enter 1 enter 2 leave 2 leave 1]
[leave 2 leave 1]
```

A `KEEP` or an `UNDO` counts as a `LEAVE` for `.has-phaser('LEAVE')`, but
`.phasers('LEAVE')` does not list it. `CATCH` and `CONTROL` are not
phasers, and an unknown kind gives an empty list:

```raku
my $x = 0;
my $b = { KEEP $x++; UNDO $x--; 42 };
say $b.has-phaser('LEAVE');
say $b.phasers('LEAVE').elems;
say $b.phasers('KEEP').elems;
say { FIRST $x++; 42 }.has-loop-phasers;
say { CATCH { default { } }; 42 }.has-phasers;
say $b.phasers('NOPE').raku;
```
```output
True
0
1
True
False
()
```

## `KEEP` and `UNDO` look at the result; `PRE` and `POST` guard a call

`KEEP` runs when a block is left with a defined value, `UNDO` when it is left
with an undefined one, such as `Nil` or a Failure, or by an exception. A
`FIRST` phaser runs only in a loop: in a block that is called by hand it
never runs.

```raku
my @log;
my $ok   = -> { KEEP @log.push("keep"); UNDO @log.push("undo"); 1 };
my $fail = -> { KEEP @log.push("keep"); UNDO @log.push("undo"); Nil };
$ok();
$fail();
say @log;
my @once;
my $b = { FIRST @once.push("first"); "ran" };
$b(); $b();
say @once.elems;
```
```output
[keep undo]
0
```

`PRE` checks a condition before the body, `POST` one after it, with the
result in `$_`. A false condition throws `X::Phaser::PrePost`, whose message
quotes the condition:

```raku
sub positive($x) { PRE $x > 0; POST $_ > 1; $x }
say positive(5);
try positive(-1);
say $!.^name;
say $!.message;
try positive(1);
say $!.message;
```
```output
5
X::Phaser::PrePost
Precondition '$x > 0' failed
Postcondition '$_ > 1' failed
```

## A stub body dies when it runs; `???` only warns

A body of `...` or `!!!` marks code as not written yet. `.yada` is True for
it, and calling it throws `X::StubCode`, with the message given to `!!!` if
there is one. A `???` body warns and returns:

```raku
sub todo { ... }
say &todo.yada;
try todo();
say $!.^name;
say $!.message;
sub later { !!! "write me" }
try later();
say $!.message;
sub maybe { ??? }
maybe();
say "after ???";
```
```output
True
X::StubCode
Stub code executed
write me
after ???
```
```stderr
Stub code executed
  in sub maybe at example.raku line 9
```

## A multi's name is its proto, which lists the candidates

Declaring `multi` subs creates a *proto*, generated when none is written, and
`&f` names the proto. `.is_dispatcher` is True for it, `.candidates` lists
the candidates in the order they were declared, and a candidate's
`.dispatcher` leads back to the proto. `.cando` lists the candidates that
would accept a Capture, the narrowest first. A generated proto takes
anything: its signature is `(;; Mu |)`.

```raku
multi f(Int $x) { "Int" }
multi f(Str $x) { "Str" }
multi f($x) { "Any" }
say &f.is_dispatcher;
say &f.candidates.elems;
say &f.candidates.map(*.multi);
say &f.signature;
say &f.candidates[0].dispatcher.name;
say &f.cando(\(5)).map(*.signature);
say &f.raku;
```
```output
True
3
(True True True)
(;; Mu |)
f
((Int $x) ($x))
proto sub f (;; Mu |) {*}
```

`.candidates(:!local)` also descends into wrapped routines.
It returns a lazy sequence, which cannot be counted directly:

```raku
multi f(Int $x) { }
multi f(Str $x) { }
try &f.candidates(:!local).elems;
say $!.^name;
say &f.candidates(:!local, :with-proto).head(10).elems;
```
```output
X::Cannot::Lazy
3
```

With `:with-proto` the proto comes first, which is the third element.

## `.multi` is 0 on a proto, and a plain sub's `.dispatcher` is an `NQPMu`
tags: bug

A candidate answers `.multi` with `True`. A proto and a plain sub should
answer `False`, as the documentation of `Routine` says, but Rakudo 2026.08
answers the number 0. `.dispatcher` of a plain sub is not a Raku object at
all but the internal `NQPMu`, whose `.defined` is also 0 and which has no
`.raku`:

```raku
multi f(Int $x) { }
sub g($x) { }
say &f.multi.raku;
say &g.multi.raku;
say &f.candidates[0].multi.raku;
say &g.dispatcher.^name;
say &g.dispatcher.defined.raku;
try &g.dispatcher.raku;
say $!.^name;
```
```output
0
0
Bool::True
NQPMu
0
X::Method::NotFound
```

Both zeros are false, so `if &g.multi` works as intended; only code that
compares with `False` or prints the answer notices.

## The narrowest candidate wins

Multi dispatch ranks candidates by how narrow their parameters are. A
subtype is narrower than its parent, so `Int` beats `Numeric`, which beats
`Any`, which beats `Mu`. A candidate with a `where` clause beats the same
type without one, whatever the order of declaration.

```raku
multi kind(Int $x) { "int" }
multi kind(Numeric $x) { "numeric" }
multi kind(Any $x) { "any" }
multi kind(Mu $x) { "mu" }
say kind(1);
say kind(1.5);
say kind("s");
say kind(Mu);
multi big(Int $x) { "int" }
multi big(Int $x where * > 5) { "big" }
say big(3), " ", big(9);
```
```output
int
numeric
any
mu
int big
```

A candidate that takes exactly the arguments beats one with an optional or
slurpy parameter. A required named parameter rules a candidate out when the
named argument is missing. An optional named parameter changes nothing, so
the first candidate declared wins. An `@` parameter beats a `$` one for a
list or an array.

```raku
multi opt($x, $y?) { "optional" }
multi opt($x) { "exact" }
say opt(1);
multi sl($x, *@r) { "slurpy" }
multi sl($x) { "exact" }
say sl(1);
multi nm($x, :$n!) { "named" }
multi nm($x) { "plain" }
say nm(1), " ", nm(1, :n);
multi on($x, :$n) { "optional named" }
multi on($x) { "plain" }
say on(1), " ", on(1, :n);
multi arr(@a) { "array" }
multi arr($x) { "scalar" }
say arr([1]), " ", arr((1, 2)), " ", arr(1);
```
```output
exact
exact
plain named
optional named optional named
array array scalar
```

## A tie dies as ambiguous, unless one candidate `is default`

When no candidate is narrower than the others, the call throws
`X::Multi::Ambiguous`, whose message lists the tied signatures. Two
candidates with the same signature are allowed to be declared; the error
comes at the call. `is default` on one of them breaks the tie.

```raku
multi pick-one(Int $x) { "first" }
multi pick-one(Int $x) is default { "default" }
say pick-one(1);
multi g(Int $x, Any $y) { "a" }
multi g(Any $x, Int $y) { "b" }
try g(1, 1);
say $!.^name;
say $!.message;
```
```output
default
X::Multi::Ambiguous
Ambiguous call to 'g(Int, Int)'; these signatures all match:
  (Int $x, $y) from example.raku line 4
  ($x, Int $y) from example.raku line 5
```

Two candidates that are both `is default` are ambiguous again.

## `Int:D` and `Int` tie for a defined Int
tags: quirk

A type smiley does not make a candidate narrower. With one candidate for
`Int:D` and one for plain `Int`, only a type object has a single match; a
defined Int matches both equally, and the call is ambiguous. A coercion
type ties with the plain type in the same way:

```raku
multi d(Int:D $x) { "defined" }
multi d(Int $x) { "any Int" }
say d(Int);
try d(3);
say $!.^name;
multi c(Str(Int) $x) { "coerce" }
multi c(Int $x) { "int" }
try c(1);
say $!.^name;
```
```output
any Int
X::Multi::Ambiguous
X::Multi::Ambiguous
```

Writing `Int:U` for the second candidate instead of `Int` removes the
overlap. Values of two types at once, such as an IntStr, tie in the same
way, as [Strings](#ch:strings:an-allomorph-is-int-and-str-so-a-multi-cannot-choose)
shows.

## No matching candidate throws `X::Multi::NoMatch`

When no candidate accepts the arguments, the exception lists the candidates'
signatures, and `.capture` holds the arguments:

```raku
multi f(Int $x) { }
multi f(Str $x) { }
my $r = 1.5;
try f($r);
say $!.^name;
say $!.message;
say $!.capture.raku;
```
```output
X::Multi::NoMatch
Cannot resolve caller f(Rat:D); none of these signatures matches:
    (Int $x)
    (Str $x)
\(1.5)
```

As for a plain sub, a call whose literal arguments fit no candidate is
refused at compile time:

```raku
proto u(|) {*}
multi u(Int $x) { "int" }
u("s");
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Calling u(Str) will never work with any of these multi signatures:
    (Int $x)
at example.raku:3
------> <BOL><HERE>u("s");
```

## A proto can run code around `{*}`; a bare `{*}` checks nothing
tags: quirk

A written proto decides what every call goes through. Its body can do work
before and after `{*}`, the point where the chosen candidate runs, and use
the candidate's result:

```raku
proto area(|) {
    say "measuring";
    my $result = {*};
    "area: $result"
}
multi area(Int $side) { $side * $side }
multi area(Int $w, Int $h) { $w * $h }
say area(3);
say area(2, 5);
```
```output
measuring
area: 9
measuring
area: 10
```

A proto whose whole body is `{*}` is handled specially, and its parameter
list is not checked at all: `proto s(Int $x) {*}` lets a Str through to a
candidate that takes it. With anything more in the body, even `{ {*} }`, the
proto's signature is enforced:

```raku
proto s(Int $x) {*}
multi s($x) { "got {$x.^name}" }
my $v = "str";
say s($v);
proto t(Int $x) { {*} }
multi t($x) { "t got {$x.^name}" }
try t($v);
say $!.^name;
```
```output
got Str
X::TypeCheck::Binding::Parameter
```

A plain `sub` and a `multi` cannot share a name:

```raku
sub o(Int $x) { 1 }
multi o(Str $x) { 2 }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Redeclaration of routine 'o'. Did you mean to declare a multi-sub?
at example.raku:3
------> <BOL><HERE><EOL>
```

## `callsame` and `nextsame` go on to the next candidate

Inside a candidate, `callsame` calls the next candidate in the ranking with
the same arguments and returns its result; `callwith` does the same with new
arguments. `nextsame` and `nextwith` hand over for good: the current
candidate does not continue.

```raku
multi describe(Int $x) { "Int, then " ~ callsame() }
multi describe(Numeric $x) { "Numeric, then " ~ callsame() }
multi describe(Any $x) { "Any" }
say describe(5);
say describe(1.5);
multi f(Int $x) { nextsame; say "never printed" }
multi f(Any $x) { "Any got $x" }
say f(1);
multi g(Int $x) { callwith($x + 1) ~ "!" }
multi g(Any $x) { "g($x)" }
say g(1);
```
```output
Int, then Numeric, then Any
Numeric, then Any
Any got 1
g(2)!
```

In the last candidate there is nothing left to call, and both return `Nil`.
In a method they go on to the same method of the parent class:

```raku
multi last-one(Any $x) { callsame().raku }
say last-one(1);
multi last-two(Any $x) { nextsame }
say last-two(1).raku;
class Base { method hi { "Base hi" } }
class Kid is Base { method hi { "Kid hi, " ~ callsame } }
say Kid.new.hi;
```
```output
Nil
Nil
Kid hi, Base hi
```

`callwith` passes its new arguments to the next candidate in the list that
was made for the original arguments; it does not dispatch again. Below, the
list for `1` holds the `Int` and `Any` candidates, so the string goes to
`Any`, although a `Str` candidate exists:

```raku
multi g(Int $x) { callwith("s") }
multi g(Str $x) { "str" }
multi g(Any $x) { "any got $x" }
say g(1);
```
```output
any got s
```

## `samewith` dispatches again from the top

`samewith` calls the same multi with new arguments, and the dispatch starts
over, so any candidate can be chosen. It is the way to recurse without
writing the routine's name:

```raku
multi fact(0) { 1 }
multi fact(Int $n) { $n * samewith($n - 1) }
say fact(5);
multi len(Str $s) { samewith($s.chars) }
multi len(Int $n) { "length $n" }
say len("hello");
```
```output
120
length 5
```

The `0` in `fact(0)` is a literal parameter: it accepts only an argument
equal to 0.

## `.wrap` puts a new layer around a routine

`&f.wrap(&wrapper)` makes every call of `f` go through the wrapper first.
Inside the wrapper, `callsame` and `callwith` call the next layer, the
routine itself or an older wrapper, and a wrapper that calls neither
replaces the routine. The newest wrapper is the outermost. The routine keeps
its name and signature, but its type changes, and `.is-wrapped` says so.

```raku
sub f($x) { "f($x)" }
my $h1 = &f.wrap(-> $x { "w1<" ~ callsame() ~ ">" });
say f(1);
my $h2 = &f.wrap(-> $x { "w2<" ~ callwith($x + 1) ~ ">" });
say f(1);
say $h1.^name;
say &f.^name;
say &f.is-wrapped;
say &f.name, " ", &f.signature;
```
```output
w1<f(1)>
w2<w1<f(2)>>
Routine::WrapHandle
Sub+{Routine::Wrapped}
True
f ($x)
```

`.wrap` returns a handle. `&f.unwrap($handle)` takes that layer off and
returns `Empty`; `$handle.restore` does the same and answers True, and False
when there is nothing left to restore. Unwrapping with a handle that is
already used throws `X::Routine::Unwrap`.

```raku
sub f($x) { "f($x)" }
my $h = &f.wrap(-> $x { "wrapped" });
say f(1);
say &f.unwrap($h).raku;
say f(1);
try &f.unwrap($h);
say $!.^name;
my $h2 = &f.wrap(-> $x { "again" });
say $h2.restore;
say $h2.restore;
say f(1);
```
```output
wrapped
Empty
f(1)
X::Routine::Unwrap
True
False
f(1)
```

## `nextsame` in a pointy-block wrapper throws
tags: quirk

`nextsame` and `nextwith` pass control to the next layer and then *return*
from the wrapper with its result. A pointy block is not a routine and has
nothing to return from, so in a pointy-block wrapper they throw
`X::ControlFlow::Return`. `callsame` and `callwith` work there, and a `sub`
wrapper takes all four:

```raku
sub f($x) { "f($x)" }
&f.wrap(-> $x { nextsame });
try f(1);
say $!.^name;
say $!.message;
sub g($x) { "g($x)" }
&g.wrap(sub ($x) { nextsame });
say g(2);
sub h($x) { "h($x)" }
&h.wrap(sub ($x) { my $r = nextsame; "never here" });
say h(3);
```
```output
X::ControlFlow::Return
Attempt to return outside of any Routine
g(2)
h(3)
```

## A wrapper sees every call, recursive ones included

A recursive routine calls itself through its name, so each level of the
recursion passes through the wrapper again:

```raku
my $depth = 0;
sub countdown($n) { $depth++; $n > 0 ?? countdown($n - 1) !! "done" }
&countdown.wrap(-> $n { "[" ~ callsame() ~ "]" });
say countdown(2);
say $depth;
```
```output
[[[done]]]
3
```

A method can be wrapped through the class's metaobject, and its wrapper
receives the invocant first. Wrapping a multi's proto catches every call;
wrapping one candidate catches only the calls that candidate wins:

```raku
class C {
    method m($x) { "m($x)" }
    multi method n(Int $x) { "n Int" }
    multi method n(Str $x) { "n Str" }
}
C.^lookup('m').wrap(-> $self, $x { "W<" ~ callsame() ~ ">" });
say C.new.m(1);
C.^lookup('n').candidates[0].wrap(-> $self, $x { "C<" ~ callsame() ~ ">" });
say C.new.n(1);
say C.new.n("s");
```
```output
W<m(1)>
C<n Int>
n Str
```

A wrapper's own signature is not checked against the routine's when it is
installed; a wrapper that cannot take the arguments fails at each call.
Routines of the core setting can be wrapped too:

```raku
sub sig($x) { "sig" }
&sig.wrap(-> $x, $y { callsame });
try sig(1);
say $!.message;
my $h = &say.wrap(-> |c { callwith("wrapped: ", |c) });
say "hello";
$h.restore;
say "hello";
```
```output
Too few positionals passed; expected 2 arguments but got 1
wrapped: hello
hello
```

## `.assuming` fixes some arguments and leaves the rest

`.assuming` returns a new sub with some arguments already supplied, which is
called *priming*. Positional arguments are primed from the left, and a `*`
leaves a position open. A named argument primed by value becomes that
parameter's default, so a call can still override it. The new sub's
signature is what is left.

```raku
sub f($a, $b, $c) { "$a-$b-$c" }
my &first = &f.assuming(1);
my &middle = &f.assuming(*, 2);
say first(2, 3);
say middle(1, 3);
say &first.signature;
say &middle.signature;
sub g($x, :$n = "N") { "$x:$n" }
my &named = &g.assuming(n => "X");
say named(5);
say named(5, n => "Y");
say &named.signature;
```
```output
1-2-3
1-2-3
($b, $c)
($a, $c)
5:X
5:Y
($x, :$n = "X")
```

Any code can be primed: a block, a WhateverCode, a method (with a `*` for the
invocant). A coercion parameter coerces the primed value.

```raku
my $block = { $^a + $^b };
say $block.assuming(10)(5);
my $w = * * 2;
say $w.assuming(3)();
say Str.^lookup('comb').assuming(*, /\w/)("a b").raku;
sub cast(Int() $x) { $x.raku }
say &cast.assuming("4")();
```
```output
15
6
("a", "b").Seq
4
```

Priming checks the types of the primed arguments and their number at once.
It does not run a `where` clause: the primed sub is built, and it fails when
it is called.

```raku
sub typed(Int $x, $y) { "$x$y" }
try &typed.assuming("s");
say $!.^name;
sub big($x where * > 2) { $x }
my &small = &big.assuming(1);
say "primed";
try small();
say $!.^name;
sub pair($a, $b) { }
try &pair.assuming(1, 2, 3);
say $!.message;
```
```output
X::TypeCheck::Binding::Parameter
primed
X::TypeCheck::Binding::Parameter
Too many positionals
```

## A primed sub is named `assumed.f`, and holds on to variables
tags: quirk

The sub that `.assuming` makes gets a name built from the original's, with
`assumed.` in front, a name that no declaration could have:

```raku
sub f($a, $b, $c) { "$a-$b-$c" }
my &p = &f.assuming(1);
say &p.name;
say &p.gist;
say &p.^name;
```
```output
assumed.f
&assumed.f
Sub
```

A variable given to `.assuming` is kept as the variable, not as its value at
the time of priming. A later assignment to it, or a `push` onto an array,
changes what the primed sub passes on:

```raku
sub f($a, $b, $c) { "$a-$b-$c" }
my $v = 1;
my &p = &f.assuming($v, 2);
$v = 9;
say p(3);
sub h(*@a) { @a.join(",") }
my @list = 1, 2;
my &q = &h.assuming(@list);
@list.push(3);
say q();
```
```output
9-2-3
1,2,3
```

Prime with `$v<>` or a copy to fix the current value.

## A routine trait mixes a role into the routine

Traits such as `is pure`, `is nodal` and `is hidden-from-backtrace` change a
routine by mixing a role into it, which adds a method that answers True. The
role shows in the type name, and a routine without the trait does not have
the method at all:

```raku
sub pure-one() is pure { 1 }
sub nodal-pure() is nodal is pure { 1 }
sub hidden() is hidden-from-backtrace { 1 }
sub plain() { 1 }
say &pure-one.^name;
say &nodal-pure.^name;
say &pure-one.is-pure;
try &plain.is-pure;
say $!.^name;
say &hidden.is-hidden-from-backtrace;
say &plain.is-implementation-detail;
```
```output
Sub+{is-pure}
Sub+{is-nodal}+{is-pure}
True
X::Method::NotFound
True
False
```

`.is-implementation-detail` is the exception: every piece of code answers
it. A routine marked `is hidden-from-backtrace` is left out of the printed
backtrace, so an error seems to come from its caller:

```raku
sub inner() is hidden-from-backtrace { die "oops" }
sub outer() { inner() }
outer();
```
```output
```
```stderr
oops
  in sub outer at example.raku line 2
  in block <unit> at example.raku line 3

```

An unknown trait is a compile-time error that lists the traits a sub can
have. `is cached`, which remembers results, needs `use experimental
:cached`.

```raku
sub f() is bogus { }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Can't use unknown trait 'is' -> 'bogus' in sub declaration.
at example.raku:1
    expecting any of:
        rw raw default DEPRECATED inlinable onlystar export leading_docs
        trailing_docs revision-gated implementation-detail hidden-from-backtrace
        hidden-from-USAGE pure nodal equiv tighter looser assoc prec
```

## `is DEPRECATED` keeps a routine working and reports it at exit
tags: unasserted

A routine marked `is DEPRECATED("replacement")` runs as usual. The calls are
counted, and when the program ends a report goes to standard error, with the
lines the calls came from and the replacement to use. `.DEPRECATED` answers
the replacement.

```raku
sub old() is DEPRECATED("new-name") { 42 }
say old();
say old();
say &old.DEPRECATED;
```
```output
42
42
new-name
```
```stderr
Saw 1 occurrence of deprecated code.
================================================================================
Sub old (from GLOBAL) seen at:
  example.raku, lines 2,3
Please use new-name instead.
--------------------------------------------------------------------------------
Please contact the author to have these occurrences of deprecated code
adapted, so that this message will disappear!
```

The count is of deprecated routines, not of calls. Without an argument the
trait tells the reader to use "something else".

## `is export` files a symbol under tags

`is export` puts a symbol into the module's `EXPORT` package, under the tag
`DEFAULT`; `is export(:name)` puts it under the tag `name` instead, and
`(:DEFAULT, :name)` under both. Every exported symbol is also under `ALL`.
A sub declared without `our` cannot be called from outside by its long name,
`Shapes::square`, whether it is exported or not; an `our` sub can.

```raku
module Shapes {
    sub square($x) is export { $x * $x }
    sub cube($x) is export(:extra) { $x ** 3 }
    sub both($x) is export(:DEFAULT, :extra) { $x }
    sub hidden($x) { $x }
}
say Shapes::EXPORT::.keys.sort;
say Shapes::EXPORT::DEFAULT::.keys.sort;
say Shapes::EXPORT::extra::.keys.sort;
say Shapes::EXPORT::ALL::.keys.sort;
```
```output
(ALL DEFAULT extra)
(&both &square)
(&both &cube)
(&both &cube &square)
```

`import` and `use` without a tag take `DEFAULT` only; naming a tag takes
that tag, and a tag the module does not have is a compile-time error. The
`EVAL` below runs after compilation, when `cube` has not been imported:

```raku
module Shapes {
    sub square($x) is export { $x * $x }
    sub cube($x) is export(:extra) { $x ** 3 }
}
import Shapes;
say square(3);
say (try EVAL 'cube(2)') // $!.^name;
```
```output
9
X::Undeclared::Symbols
```

Two modules in one file cannot export the same name, even under different
long names:

```raku
module A { sub greet() is export { "A" } }
module B { our sub greet() is export { "B" } }
say "compiled";
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
A symbol '&greet' has already been exported
at example.raku:2
```

## `is tighter`, `is looser` and `is equiv` place a new operator

A new operator without a trait gets the precedence of additive operators,
associates to the left and folds left in a reduction. `is equiv` copies the
level of another operator. `is tighter` and `is looser` make a new level
just above or just below it, so an operator tighter than `+` is still looser
than `*`:

```raku
sub infix:<tight>($a, $b) is tighter(&infix:<+>) { "($a tight $b)" }
sub infix:<loose>($a, $b) is looser(&infix:<+>) { "[$a loose $b]" }
sub infix:<times>($a, $b) is equiv(&infix:<*>) { "$a×$b" }
say 1 tight 2 * 3;
say 1 loose 2 + 3;
say 2 times 3 ~ "!";
```
```output
(1 tight 6)
[1 loose 5]
2×3!
```

`is assoc` sets the associativity. `right` groups from the right, in
reductions as well; `non` refuses a chain of the operator at compile time.
When two operators of one level meet, the left one's associativity decides:

```raku
sub infix:<rr>($a, $b) is assoc<right> { "($a r $b)" }
sub infix:<ll>($a, $b) { "($a l $b)" }
say 1 rr 2 rr 3;
say 1 ll 2 ll 3;
say [rr] 1, 2, 3;
say 1 rr 2 ll 3;
say 1 ll 2 rr 3;
```
```output
(1 r (2 r 3))
((1 l 2) l 3)
(1 r (2 r 3))
((1 r 2) l 3)
(1 l (2 r 3))
```

How the built-in operators are ranked is the subject of [Who Takes the
Operand](#ch:precedence).

## An operator reports its precedence, and `.prec("prec")` dies
tags: bug

An operator's routine answers `.precedence`, a short code for its level
(`t=` for additive, `u=` for multiplicative), `.associative`, `.iffy`
(whether it can be negated with `!`) and `.prec`, a Hash of the three
properties. A new operator's level code is built from the one it is placed
against:

```raku
say &infix:<+>.precedence;
say &infix:<*>.precedence;
say &infix:<**>.associative;
say &infix:<==>.iffy;
say &infix:<+>.prec;
sub infix:<zz>($a, $b) { }
say &infix:<zz>.precedence, " ", &infix:<zz>.associative.raku;
sub infix:<tight>($a, $b) is tighter(&infix:<+>) { }
say &infix:<tight>.precedence;
```
```output
t=
u=
right
True
{assoc => left, dba => additive, prec => t=}
t= ""
t@=
```

`.prec` with a key should return that one property, but in Rakudo 2026.08
the method's own return type is `Hash:D`, and the string it computes fails
the check:

```raku
say &infix:<+>.prec<prec>;
try &infix:<+>.prec("prec");
say $!.^name;
say $!.message;
```
```output
t=
X::TypeCheck::Return
Type check failed for return value; expected Hash:D but got Str
```

Subscripting the Hash, as on the first line, works.

## A method's signature starts with its invocant and ends with `*%_`

A method's signature has two parameters that were never written: the
invocant, typed with the class and any smiley written after it, and the
slurpy hash `*%_` from [above](#ch:signatures:a-method-takes-any-named-argument-a-sub-refuses-it).
The invocant counts for arity, and a method taken from the class can be
called as a sub with the invocant as its first argument:

```raku
class C {
    method m($x) { "m($x)" }
    method n(C:D: $x) { }
}
my $m = C.^lookup('m');
say $m.signature;
say C.^lookup('n').signature;
say $m.arity, " ", $m.count;
say $m.signature.params[0].invocant;
say $m.(C, 1);
say $m.cando(\(C, 1)).elems;
say $m.cando(\(1)).elems;
```
```output
(C $:: $x, *%_)
(C:D $:: $x, *%_)
2 2
True
m(1)
1
0
```

A method declared with `my` outside a class can be called on any object of
the invocant's type with `.&`:

```raku
my method free(Int:D: $x) { self + $x }
say 5.&free(2);
say &free.signature;
```
```output
7
(Int:D $:: $x, *%_)
```

## A parameter can set an attribute directly

In a method, a parameter written with an attribute's name, `$!x`, binds the
argument straight into the attribute. It is the usual way to write `BUILD`,
and it works in any method:

```raku
class Point {
    has $.x;
    has $!y;
    submethod BUILD(:$!x, :$!y = 0) { }
    method set-y($!y) { }
    method y { $!y }
}
my $p = Point.new(x => 1, y => 2);
say $p.x, " ", $p.y;
$p.set-y(5);
say $p.y;
say Point.^lookup('set-y').signature;
```
```output
1 2
5
(Point $:: $!y, *%_)
```

Outside a class such a parameter is a compile-time error, *Variable $!x used
where no 'self' is available*.

## A method's signature prints `$::`, which does not parse back
tags: bug

The invocant marker is a colon after the invocant: `method m($self: $x)`. A
method's `.raku` and `.gist` print it with two colons, `$::`, a spelling the
documentation writes with one, and the printed signature does not compile:

```raku
use MONKEY-SEE-NO-EVAL;
class C { method m($x) { } }
my $printed = C.^lookup('m').signature.raku;
say $printed;
try EVAL $printed;
say $!.^name;
say (method ($self: $x) { }).signature;
```
```output
:(C $:: $x, *%_)
X::Syntax::Signature::InvocantMarker
($self:: $x, *%_)
```

The invocant marker is refused in a sub, which has no invocant:

```raku
sub f($s: $x) { }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Can only use the : invocant marker in the signature for a method
at example.raku:1
------> sub f($s: $x<HERE>) { }
    expecting any of:
        constraint
```

## A printed signature leaves out the default type and computed values

`.gist` of a signature is its parameter list in parentheses; `.raku` puts a
colon in front, as in a signature literal. A parameter's type is left out
when it is the default: `Mu` in a signature literal, `Any` in a routine. So
`:(Mu $x)` prints as `($x)`, while `:(Any $x)` keeps its `Any`, and the
parameter of `sub ($x)` is typed `Any` although it prints bare. In the gist
an anonymous typed parameter shows its type alone (`.raku` writes `Int $`),
and `Int:_` loses its smiley.

```raku
say :($x);
say :(Mu $x);
say :(Any $x);
say sub (Any $x) { }.signature;
say sub ($x) { }.signature.params[0].type.^name;
say :(Int $, Str $);
say :(Int:_ $x);
```
```output
($x)
($x)
(Any $x)
($x)
Any
(Int, Str)
(Int $x)
```

Code is never printed. A `where` clause is `where { ... }` whatever it was,
even a literal; a default is shown only when it is a literal, and otherwise
as `Code.new`. A literal parameter prints as itself, a coercion type shows
its source type, a type capture is followed by two spaces, and `is raw` on a
sigilless parameter is not printed, since such a parameter is raw anyway:

```raku
say :($x where { $_ > 1 });
say :($x where 42);
say :(42);
say :($x = 1);
say :($x = 1 + 1);
say :(::T $x);
say :(Int() $x);
say :(\x is raw);
say :(&c:(Int));
```
```output
($x where { ... })
($x where { ... })
(42)
($x = 1)
($x = Code.new)
(::T  $x)
(Int(Any) $x)
(\x)
(&c:(Int $))
```

The rest prints as written: `;;`, a return type, nested aliases, a
sub-signature and the traits `is rw`, `is copy` and `is item`. A lone `Mu`
becomes an anonymous `$`:

```raku
say :($a;; $b);
say :(Int:D $x --> Str);
say :(:x(:y($z)));
say :(@a ($first, *@rest));
say :($x is rw, $y is copy, @z is item);
say :(Mu);
```
```output
($a;; $b)
(Int:D $x --> Str)
(:x(:y($z)))
(@a ($first, *@rest))
($x is rw, $y is copy, @z is item)
($)
```

## Two spellings in a printed signature do not work as code
tags: bug

The `.raku` of a value is meant to be code that rebuilds the value. Besides
the invocant's `$::`, two spellings in a printed signature break that
promise in Rakudo 2026.08. A definite coercion type `Int:D()` prints as
`Int:D(Any):D`, which does not compile:

```raku
use MONKEY-SEE-NO-EVAL;
my $sig = :(Int:D() $x);
say $sig.raku;
try EVAL $sig.raku;
say $!.^name;
```
```output
:(Int:D(Any):D $x)
X::MultipleTypeSmiley
```

A computed default prints as `Code.new`, which compiles, but code rebuilt
from it dies the first time the default is needed:

```raku
use MONKEY-SEE-NO-EVAL;
sub f($x = 1 + 1) { $x }
say &f.signature;
my &g = EVAL 'sub ($x = Code.new) { $x }';
say g(5);
try g();
say $!.^name;
```
```output
($x = Code.new)
5
X::Cannot::New
```

## The compiler refuses a malformed signature

Most mistakes in a signature are caught at compile time, each with its own
exception class. The order of parameters is fixed: positionals before
nameds, required positionals before optional ones, the slurpy after the
positionals, and a capture last. A slurpy cannot be typed, a parameter has
one type, and a trait comes before the default.

```raku
use MONKEY-SEE-NO-EVAL;
for ':($a?, $b)', ':(*@a, $b)', ':(:$a, $b)', ':(|c, $x)', ':(Int *@a)',
    ':(Int Str $x)', ':($x = 1 is copy)', ':($x, $x)', ':(:$x, :x($y))',
    ':($!x)', ':($?x)', ':(Nonesuch $x)' -> $code {
    try EVAL $code;
    say "$code.fmt('%-18s') {$!.^name}";
}
```
```output
:($a?, $b)         X::Parameter::WrongOrder
:(*@a, $b)         X::Parameter::WrongOrder
:(:$a, $b)         X::Parameter::WrongOrder
:(|c, $x)          X::Parameter::WrongOrder
:(Int *@a)         X::Parameter::TypedSlurpy
:(Int Str $x)      X::Parameter::MultipleTypeConstraints
:($x = 1 is copy)  X::Parameter::AfterDefault
:($x, $x)          X::Redeclaration
:(:$x, :x($y))     X::Signature::NameClash
:($!x)             X::Syntax::NoSelf
:($?x)             X::Parameter::Twigil
:(Nonesuch $x)     X::Parameter::InvalidType
```

The messages say what is wrong in plain words:

```raku
sub f($a?, $b) { }
```
```output
```
```stderr
===SORRY!=== Error while compiling example.raku
Cannot put required parameter $b after optional parameters
at example.raku:1
------> sub f($a?, $b<HERE>) { }
    expecting any of:
        constraint
```

`is rw` is refused on an optional parameter and on an `@` parameter, and a
type capture cannot be declared twice. `is rw is copy` is accepted and keeps
only `is rw`. Several combinations that look doubtful are allowed: a capture
after positionals, two slurpy arrays, a slurpy hash before a slurpy array, a
required named after an optional positional, and a default of the right type
but the wrong definedness:

```raku
say :($x is rw is copy);
say :($a, |c);
say :(*@a, *@b);
say :(*%h, *@a);
say :($x?, :$y!);
say :(Int ::T $x);
say :(Int:D $x = Int);
```
```output
($x is rw)
($a, |c)
(*@a, *@b)
(*%h, *@a)
($x?, :$y!)
(::T Int $x)
(Int:D $x = Int)
```

## A Capture smartmatches a signature it would bind to

`\(…) ~~ :(…)` answers whether the arguments in the Capture would bind to
the signature, by the rules of a call: the number of positionals, the
required and the unexpected nameds, types, constraints, and for `is rw` a
container.

```raku
my $sig = :(Int $a, $b?, :$n);
say \(1) ~~ $sig;
say \(1, 2, :n) ~~ $sig;
say \("s") ~~ $sig;
say \(1, 2, 3) ~~ $sig;
say \(1, :other) ~~ $sig;
say \(my $v = 1) ~~ :($x is rw);
say \(1) ~~ :($x is rw);
say \() ~~ :();
say \(1) ~~ :();
```
```output
True
True
False
False
False
True
False
True
False
```

Any other value is turned into a Capture first: a list or an array gives its
elements as positionals, a hash or a Set its keys as nameds. A value that
cannot become a Capture, such as an Int, simply does not match, so a single
value must be put in a list:

```raku
say (1, 2) ~~ :($a, $b);
say [1, 2, 3] ~~ :($a, $b);
say { a => 1 } ~~ :(:$a);
say set(<a b>) ~~ :(:$a, :$b);
say 42 ~~ :(Int);
say (42,) ~~ :(Int);
try :($x).Capture;
say $!.^name;
```
```output
True
False
True
True
False
True
X::Cannot::Capture
```

A signature itself cannot become a Capture, as the last line shows.

## Signature against signature: `~~` asks for compatibility, `eqv` for sameness

With a signature on both sides, `~~` asks whether the left one accepts
everything the right one accepts. The left may have extra optional
parameters but not extra required ones, and each of its types must be at
least as wide as the right's. A slurpy on the right takes any number of
positionals, a required named on the left needs one on the right, and the
return types must be the same. A `where` or literal is compared only with an
identical literal.

```raku
say :($a, $b) ~~ :($foo, $bar, $baz?);
say :($foo, $bar, $baz?) ~~ :($a, $b);
say :(Int $n) ~~ :(Any $m);
say :(Any $n) ~~ :(Int $m);
say :($a) ~~ :(*@rest);
say :(:$a!) ~~ :(:$a);
say :(:$a) ~~ :(:$a!);
say :(42) ~~ :(42);
say :(42) ~~ :($ where 42);
say :($x --> Int) ~~ :($y);
```
```output
True
False
True
False
True
True
False
True
False
False
```

`eqv` asks for the same parameters: the same types and definedness, the same
flags and the same named-argument names, while positional names do not
matter. `===` is identity, so two signature literals are never `===`.

```raku
say :(Int $x) eqv :(Int $y);
say :(Int $x) eqv :(Int:D $x);
say :(:$a) eqv :(:$b);
say :(:$a) eqv :(:a($b));
say :(42) eqv :(42);
say :($a, $b) === :($a, $b);
say :(::T $x) eqv :(::U $y);
```
```output
True
False
False
True
True
False
True
```

## A `where` clause is equal to nothing, not even to itself
tags: quirk

A `where` clause is stored as a block, even when it is a literal such as
`where 42`, and two blocks are never equal. Two parameters written the same
way with `where 42` are neither `~~` nor `eqv`, and neither are signatures
that contain them. A literal parameter, `:(42)`, keeps its value and does
match its twin:

```raku
sub P($sig) { $sig.params[0] }
say :($x where 42) eqv :($x where 42);
say P(:($x where 42)) eqv P(:($x where 42));
say P(:($x where 42)) ~~ P(:($y where 42));
say P(:(42)) ~~ P(:(42));
say P(:($x where 42)).constraint_list.map(*.^name);
say P(:(42)).constraint_list;
```
```output
False
False
False
True
(Block)
(42)
```

## A signature built with `Signature.new` cannot bind anything
tags: bug unasserted

`Signature.new` and `Parameter.new` build a signature at run time. Its
`.raku` prints every type and an explicit return type, and its arity is the
number of parameters. Such a signature is not `eqv` to the literal it
imitates, and binding a Capture to it throws an internal error, even for an
empty signature and an empty Capture:

```raku
my $sig = Signature.new(params => (Parameter.new(name => '$x', type => Int),));
say $sig.raku;
say $sig.arity;
say $sig eqv :(Int $x);
try { \(1) ~~ $sig };
say $!.^name;
try { \() ~~ Signature.new };
say $!.^name;
```
```output
:(Int $x --> Mu)
1
False
X::AdHoc
X::AdHoc
```

The count is not worked out from the parameters either: a slurpy leaves it
at the arity unless `count => Inf` is passed.

```raku
say Signature.new(params => (Parameter.new(name => '*@a'),)).count;
say Signature.new(params => (Parameter.new(name => '*@a'),), count => Inf).count;
say Signature.new.raku;
```
```output
1
Inf
:( --> Mu)
```

## `Parameter.new` dies on `+@a` and doubles a bare name
tags: bug unasserted

`Parameter.new` reads the sigil, the twigil, a `:` for a named parameter,
the slurpy marks and a trailing `?` or `!` from the name it is given. Two
names go wrong in Rakudo 2026.08. A name without a sigil is accepted and
printed twice, and the single-argument slurpy `+@a` dies with an error from
inside the constructor:

```raku
say Parameter.new(name => '$x').raku;
say Parameter.new(name => ':$n!').raku;
say Parameter.new(name => '*@a').raku;
say Parameter.new(name => '$x', type => Int, :is-rw).raku;
say Parameter.new(name => '$x', default => 42).raku;
say Parameter.new(name => 'x').raku;
try Parameter.new(name => '+@a');
say $!.^name;
say $!.message;
```
```output
$x
:$n!
*@a
Int $x is rw
$x = 42
xx
X::OutOfRange
Start argument to substr out of range. Is: -1, should be in 0..2; use *-1 if you want to index relative to the end
```

## A Parameter answers questions about itself

`.signature.params` is the list of Parameter objects. `.name` has the sigil
and twigil; `.usage-name` drops them. `.sigil` is `\` for a sigilless
parameter, `.prefix` the slurpy mark, `.suffix` a `?` or `!` that was
written, and `.modifier` the smiley. `.type` is `Any` for an untyped
routine parameter, and the role an `&` or `@` sigil implies:

```raku
sub f(Int:D $x, &cb, \raw, $y?, :ali(:$named), *@rest) { }
for &f.signature.params {
    say .name.fmt('%-7s'), (.usage-name, .sigil, .prefix, .suffix, .modifier, .type.^name).map({ $_ || "-" }).join(" ");
}
```
```output
$x     x $ - - :D Int
&cb    cb & - - - Callable
raw    raw \ - - - Any
$y     y $ - ? - Any
$named named $ - - - Any
@rest  rest @ * - - Positional
```

`.positional` and `.named` tell the two kinds apart, and a slurpy array or a
capture is neither. `.optional` is True for a `?`, a default, or a named
parameter without `!`:

```raku
sub f($x, $y?, $z = 1, :$n, :$m!, *@a, |c) { }
for &f.signature.params {
    say .name.fmt('%-3s'), " ",
        (.positional ?? "positional" !! ""),
        (.named ?? "named" !! ""),
        (.optional ?? " optional" !! ""),
        (.slurpy ?? " slurpy" !! ""),
        (.capture ?? " capture" !! "");
}
```
```output
$x  positional
$y  positional optional
$z  positional optional
$n  named optional
$m  named
@a   slurpy
c    capture
```

The traits have their own predicates, and a parameter lists its type
captures, its named-argument names (innermost first), its sub-signature
(the `Signature` type object when there is none) and its `where` clauses:

```raku
say :($x is rw).params[0].rw;
say :($x is copy).params[0].copy;
say :($x is raw).params[0].raw;
say :($x).params[0].readonly;
say :(::T $x).params[0].type_captures;
say :(:a(:b($c))).params[0].named_names;
say :(@a ($b)).params[0].sub_signature;
say :($x).params[0].sub_signature.^name;
say :($x where * > 1).params[0].constraint_list.elems;
```
```output
True
True
True
True
(T)
(b a)
($b)
Signature
1
```

A coercion parameter's `.type` is the coercion type; `.coerce_type` and
`.nominal_type` split it. A signature attached to an `&` parameter is not
its sub-signature but its `.signature_constraint`:

```raku
my $p = :(Int() $x).params[0];
say $p.type.^name;
say $p.coerce_type.^name;
say $p.nominal_type.^name;
say $p.coercive;
say :(&c:(Int)).params[0].signature_constraint;
say :(&c:(Int)).params[0].sub_signature.^name;
```
```output
Int(Any)
Int
Int
1
(Int)
Signature
```

`.coercive` is the number 1, not `True`.

## An Attribute answers questions about itself

`.^attributes` lists a class's attributes as Attribute objects. `.name` is
always the private name, `$!x`, even for a public attribute; `.has_accessor`
tells the public ones. `.rw` reflects `is rw`, `.required` `is required`,
and `.is_built` whether `.new` may set the attribute. `.build` is the
initial value: `Mu` when there is none, the value for a literal, and a
`Method` for an expression, which is run for each new object.

```raku
class C {
    has $!hidden;
    has Int $.count is rw;
    has @.items;
    has $.name is required;
    has $!secret is built;
    has $.fixed is built(False) = 3;
    has $.five = 5;
    has $.sum = 1 + 1;
}
for C.^attributes {
    say .name.fmt('%-9s'), " ", .type.^name.fmt('%-10s'),
        (.has_accessor ?? " accessor" !! ""), (.rw ?? " rw" !! ""),
        (.required ?? " required" !! ""), (.is_built ?? " built" !! ""),
        " build:", .build.^name;
}
```
```output
$!hidden  Mu         build:Mu
$!count   Int        accessor rw built build:Mu
@!items   Positional accessor built build:Mu
$!name    Mu         accessor required built build:Mu
$!secret  Mu         built build:Mu
$!fixed   Mu         accessor build:Int
$!five    Mu         accessor built build:Int
$!sum     Mu         accessor built build:Method
```

An untyped attribute is typed `Mu`, not `Any`, although it starts as `Any`.

## `is required`, `is built` and `is default` on attributes

A missing `is required` attribute makes `.new` throw
`X::Attribute::Required`, whose message includes the reason when one was
given. A type object or `Nil` counts as a value:

```raku
class C { has $.a is required; has $.b is required("give a b") }
try C.new(b => 1);
say $!.^name;
say $!.message;
try C.new(a => 1);
say $!.message;
say C.new(a => Int, b => Nil).a.raku;
```
```output
X::Attribute::Required
The attribute '$!a' is required, but you did not provide a value for it.
The attribute '$!b' is required because give a b,
but you did not provide a value for it.
Int
```

`is built` lets `.new` set a private attribute, and `is built(False)` stops
it from setting a public one. `is built(:bind)` binds the value instead of
assigning it, so the attribute has no container of its own. `.raku` of the
object lists the attributes that `.new` can set:

```raku
class C {
    has $!secret is built;
    has $.shown is built(False) = "default";
    has $!bound is built(:bind);
    method secret { $!secret }
    method bound-kind { $!bound.VAR.^name }
}
my $c = C.new(secret => 1, shown => 2, bound => 3);
say $c.secret;
say $c.shown;
say $c.bound-kind;
say $c.raku;
```
```output
1
default
Int
C.new(secret => 1, bound => 3)
```

`is default` sets what the attribute returns to when `Nil` is assigned or
passed, separately from its initial value. An accessor without `is rw`
cannot be assigned through, and one with it checks the type:

```raku
class C { has Int $.h is default(7) is rw = 9; has $.plain }
my $c = C.new;
say $c.h;
$c.h = Nil;
say $c.h;
try { $c.h = "s" };
say $!.^name;
try { $c.plain = 1 };
say $!.^name;
say C.new(h => Nil).h;
```
```output
9
7
X::TypeCheck::Assignment
X::Assignment::RO
7
```

## A role's attribute belongs to `$?CLASS` until it is composed
tags: quirk

`.^attributes` lists a class's own attributes first, then those of its
parents; an attribute that a role brings in counts as the class's own. Read
from the role itself, an attribute's `.package` is not the role but the
placeholder `$?CLASS`, which stands for the class that will compose it;
through the class it is the class:

```raku
role R { has $.r }
class P { has $.p }
class K is P does R { has $.k }
say K.^attributes.map(*.name);
say K.^attributes(:local).map(*.name);
say R.^attributes[0].package.^name;
say K.^attributes.first(*.name eq '$!r').package.^name;
```
```output
($!k $!r $!p)
($!k $!r)
$?CLASS
K
```

## `set_value` writes an attribute without a type check

An Attribute object can read and write its slot in any object of its class.
`.get_value` boxes a native value. `.set_value` binds whatever it is given,
without the type check an assignment would do; only a native slot refuses a
value of the wrong kind:

```raku
class C { has Int $.n = 5; has int $!raw = 3 }
my $c = C.new;
my ($n, $raw) = C.^attributes;
say $n.get_value($c);
$n.set_value($c, "not an Int");
say $c.n;
say $raw.get_value($c).^name;
try $raw.set_value($c, "s");
say $!.^name;
```
```output
5
not an Int
Int
X::AdHoc
```

## A WhateverCode has one parameter per star

An expression with `*` as an operand, such as `* + 1`, is a *WhateverCode*:
a small function with one parameter for each star, in order. Its arity is
the number of stars, and a call with any other number of arguments dies. It
has no name, its `.raku` does not show the expression, and its parameters
have generated names numbered across the whole program:

```raku
my $one = * + 1;
my $two = * + *;
say $one.arity, " ", $two.arity;
say $one(4), " ", $two(1, 2);
say $one.raku;
say $two.signature;
say $one.name.raku;
try $one(1, 2);
say $!.message;
```
```output
1 2
5 3
WhateverCode.new
(;; $whatevercode_arg_2 is raw, $whatevercode_arg_3 is raw)
""
Too many positionals passed; expected 1 argument but got 2
```

It is a Code but not a Block. `.ACCEPTS` returns the raw result, and `~~`
turns it into a Bool, so `* + 1` smartmatches every number except -1:

```raku
my $w = * + 1;
say $w.line;
say $w ~~ Block;
say $w.ACCEPTS(5);
say 0 ~~ $w;
say -1 ~~ $w;
```
```output
1
False
6
True
False
```

## A method call on a `*` expression becomes part of it
tags: trap

A method called on a Whatever expression does not ask the WhateverCode
anything. It is added to the expression, and the result is a new
WhateverCode. Parentheses do not stop this, so `(* + 1).arity` is code, and
`say` prints its gist. Only `.WHAT` and `.HOW` are left alone. Put the
expression in a variable before asking about it:

```raku
say (* + 1).arity;
say (* + 1).^name;
my $w = * + 1;
say $w.arity;
say $w.^name;
say (* + 1).WHAT;
```
```output
WhateverCode.new
WhateverCode.new
1
WhateverCode
(WhateverCode)
```

The same happens to a range with a Whatever end, as [Ranges](#ch:ranges:1-1-is-code-that-makes-a-range-not-a-range)
shows.

## A `*` on the right of `~~` takes the whole smartmatch
tags: trap

`$x ~~ * > 3` looks like a smartmatch against the WhateverCode `* > 3`, but
the star makes the whole expression a WhateverCode instead, and no
smartmatch happens. Worse, `~~` and `>` are both chaining operators, so the
code built tests `$x ~~ $arg && $arg > 3` for its argument `$arg`. A method
call on the star, as in `*.uc`, does not do this, and parentheses around the
WhateverCode give the smartmatch that was meant:

```raku
my $v = 4;
my $m = $v ~~ * > 3;
say $m.^name;
say $m(4), " ", $m(10);
say $v ~~ (* > 3);
my $u = "s" ~~ *.uc;
say $u.^name;
my $any = 5 ~~ *;
say $any.^name;
```
```output
WhateverCode
True False
True
Bool
WhateverCode
```

`$m(10)` is False because `4 ~~ 10` fails, whatever `10 > 3` says.

## A WhateverCode's `.file` is a null string
tags: bug

Every other piece of code answers `.file` with the name of its source file.
A WhateverCode answers with a Str object that holds no string at all. It is
defined, but using it as a string dies with an error from the virtual
machine:

```raku
my $w = * + 1;
my $f = $w.file;
say $f.^name;
say $f.defined;
try say $f.raku;
say $!.message;
try say ~$f;
say $!.message;
sub named { }
say &named.file;
```
```output
Str
True
chars requires a concrete string, but got null
concatenate requires a concrete string, but got null
example.raku
```

## Code in an array subscript receives the length once per parameter
tags: quirk

A block, sub or WhateverCode inside `@a[…]` is called with the number of
elements, once for each of its parameters, and the result is the index. So
`* - *` is always 0, and a block with two placeholders gets the length
twice. Code can also return several indices:

```raku
my @a = 1, 2, 3;
say @a[* - 1];
say @a[* - *];
say @a[{ $^a - $^b }];
say @a[-> $a, $b, $c { 0 }];
say @a[{ ($_ - 1) xx 2 }];
```
```output
3
1
1
1
(3 3)
```

A range with a Whatever end is computed the same way, and one that reaches
past the end reads the missing elements. A range with a star at *both* ends
is not code, though, but the Range `-Inf..Inf`, and it dies; a sequence
operator with a star dies too:

```raku
my @a = 1, 2, 3;
try say @a[* .. *];
say $!.^name;
try say @a[* - 1 ... *];
say $!.^name;
say @a[* - 1 .. * + 1].raku;
```
```output
X::Numeric::CannotConvert
X::AdHoc
(3, Any, Any)
```

A hash subscript does not call code at all. It uses the code as a key,
turning it into a string with a warning, and finds nothing; only a bare `*`
means every value:

```raku
my %h = a => 1;
say %h{* - 1}.raku;
say %h{*}.raku;
```
```output
Any
(1,)
```
```stderr
WhateverCode object coerced to string (please use .gist or .raku to do that)
  in block <unit> at example.raku line 2
WhateverCode object coerced to string (please use .gist or .raku to do that)
  in block <unit> at example.raku line 2
```

Negative and out-of-range indices are covered in [Lists, Arrays, Seqs and
Slips](#ch:lists:a-computed-negative-index-is-a-failure-past-the-end-is-any).

## A ForeignCode's gist is not its name
tags: bug unasserted

`ForeignCode` is code that belongs to the virtual machine rather than to
Raku, such as some of the methods every routine has. It can be called, but
it is not a `Code`. Its documentation says that `.gist` and `.Str` return
its name, `<anon>`; in Rakudo 2026.08 `.gist` returns `ForeignCode.new` and
`.Str` the default form with an address, replaced by `N` below.

```raku
sub f() { }
my $fc = &f.^methods.first(* ~~ ForeignCode);
say $fc.^name;
say $fc.name;
say $fc.gist;
say $fc.raku;
say $fc.Str.subst(/\d+/, "N");
say $fc.signature;
say $fc ~~ Callable;
say $fc ~~ Code;
```
```output
ForeignCode
<anon>
ForeignCode.new
ForeignCode.new
ForeignCode<N>
(|)
True
False
```

The operators and routines of the core setting are ordinary Subs, with
traits mixed in, and `say` is a multi of three candidates:

```raku
say &infix:<+>.^name;
say &infix:<+>.file;
say &say.candidates.elems;
```
```output
Sub+{is-pure}
SETTING::src/core.c/Numeric.rakumod
3
```
