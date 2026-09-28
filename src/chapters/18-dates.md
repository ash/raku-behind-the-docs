---
title: Dates and Times
part: Time and the outside world
summary: An Instant counts atomic seconds with the leap seconds in them, a Date is a numbered day with a calendar on top, and a DateTime is a wall clock in a zone; the surprises lie where the three meet, and where a comparison falls back to text.
---

Raku has four types for time. An **Instant** is a point on the atomic time
scale: a count of seconds that includes every leap second. A **Duration** is
a length of time in seconds. A **Date** is a day of the Gregorian calendar,
and a **DateTime** is a day and a time of day in a time zone, where the zone
is an offset in seconds east of UTC. Date and DateTime share the role
`Dateish`, which holds the calendar methods: `year`, `day-of-week`,
`truncated-to` and the rest.

The types convert into one another along fixed roads, and most corners of
this chapter lie on those roads: where a leap second goes when a DateTime
becomes a POSIX number, in which zone a date is read, and what an operator
does when it has no candidate for a pair of time values. The current time
appears too, but no example prints it: the examples show what `now` and its
relatives return, never their value. They run on a machine whose local zone
is UTC. `sleep` and timers are in [Promises, Locks and
Awaiting](#ch:promises).

## `now` is an Instant, `time` an Int, and they are 37 seconds apart

`time` returns the POSIX time: whole seconds since the start of 1970 in UTC,
with leap seconds left out. `now` returns an Instant, which counts atomic
seconds with nanosecond resolution. Rakudo's atomic count starts 10 seconds
ahead of the POSIX count, the gap between atomic time and UTC when leap
seconds began in 1972, and gains one second for each of the 27 leap seconds
inserted since, the last at the end of 2016. An Instant is therefore 37
seconds ahead of the POSIX time of the same moment.

```raku
say time.^name;
say now.^name;
say (now - now).^name;
my $t = now;
say $t.Int - DateTime.new($t).posix;
say $*INIT-INSTANT <= now;
try Instant.new(5);
say $!.^name;
```
```output
Int
Instant
Duration
37
True
X::Cannot::New
```

The difference of two Instants is a Duration. `$*INIT-INSTANT` is the
Instant at which the program started. An Instant comes from `now`, from
`from-posix` or from a conversion; `Instant.new` refuses.

## `from-posix` adds 10 seconds, and one more per leap second so far

`Instant.from-posix` turns a POSIX time into an Instant. `.tai` returns the
atomic count as a Rat, and the Instant prints as `Instant:` followed by that
count; `.raku` shows the POSIX time instead. Before the first leap second, at
the end of 30 June 1972, the difference is 10; after the last it is 37. An
Instant holds whole nanoseconds: a third of a second is cut to nine decimals,
and anything finer than a nanosecond vanishes.

```raku
say Instant.from-posix(0);
say Instant.from-posix(0).raku;
say Instant.from-posix(-1).tai;
say Instant.from-posix(78796799).tai;
say Instant.from-posix(78796800).tai;
say Instant.from-posix(1483228800).tai;
say Instant.from-posix(1/3).tai.raku;
say (Instant.from-posix(0) + 1e-10).tai;
```
```output
Instant:10
Instant.from-posix(0.0)
9
78796809
78796811
1483228837
10.333333333
10
```

78796799 is the last second of 30 June 1972 and 78796800 the first of
1 July. The atomic count skips 78796810 between them: that number belongs to
the leap second. `to-nanos` returns the count in nanoseconds, as an Int.

## A POSIX time names two seconds when a leap second falls on it

A POSIX clock has no number of its own for a leap second: 23:59:60 and the
00:00:00 after it share one count. `from-posix` takes the later of the two
seconds by default, and a second argument of True asks for the leap second,
one atomic second earlier. `to-posix` goes back and returns two values, the
POSIX time and a flag that is True only inside a leap second; `.raku` writes
the flag when it is set.

```raku
my $leap = Instant.from-posix(1483228800, True);
my $after = Instant.from-posix(1483228800);
say $leap.tai, " ", $after.tai;
say $leap.to-posix.raku;
say $after.to-posix.raku;
say $leap.raku;
say $leap.DateTime;
say $after.DateTime;
```
```output
1483228836 1483228837
(1483228800.0, Bool::True)
(1483228800.0, Bool::False)
Instant.from-posix(1483228800.0,True)
2016-12-31T23:59:60Z
2017-01-01T00:00:00Z
```

## Adding to an Instant gives an Instant; subtracting two gives a Duration

An Instant plus or minus a number or a Duration is another Instant. One
Instant minus another is a Duration, negative when the second one is later.
Adding two Instants is refused with an `X::AdHoc`: a sum of two moments has
no meaning. The documentation leaves the other operators undefined, and
Rakudo answers them with the atomic count as a Num, so `$i * 2` doubles the
TAI seconds.

```raku
my $i = Instant.from-posix(5);
say ($i + 2).raku;
say ($i - 2.5).raku;
say ($i - Instant.from-posix(2)).raku;
say (Instant.from-posix(2) - $i).raku;
say ($i + Duration.new(1)).^name;
try $i + $i;
say $!.message;
say ($i * 2).^name, " ", $i * 2;
```
```output
Instant.from-posix(7.0)
Instant.from-posix(2.5)
Duration.new(3.0)
Duration.new(-3.0)
Instant
Adding two Instant values has no meaning.
Did you mean to subtract?  Perhaps you need to convert to .Numeric first?
Num 30
```

## An Instant equals its count of atomic seconds, not its POSIX time
tags: undocumented trap

An Instant is a Real number, and as a number it is its TAI count. Compared
with a plain number, `Instant.from-posix(1)` therefore equals 11, not 1.
The conversions use the same count: `.Int` is the whole part of the TAI
seconds and `.Rat` all of them. An Instant is Cool as well, so a string
operation sees its printed form.

```raku
my $i = Instant.from-posix(1);
say $i == 1;
say $i == 11;
say $i ~~ 11;
my $j = Instant.from-posix(5.5);
say $j.Int, " ", $j.Rat.raku;
say $j ~ "!";
say $j.chars;
```
```output
False
True
True
15 15.5
Instant:15.5!
12
```

## Equal Instants and equal Durations are not `===`
tags: undocumented quirk

`==`, `<`, `cmp` and `eqv` compare Instants by value, and sorting them works.
`===` does not: in Rakudo 2026.08 an Instant has no value identity, so two
Instants built from the same time are two different objects, and `unique`
keeps both. Durations behave the same way. `eqv` is the test that works.

```raku
my $a = Instant.from-posix(1);
my $b = Instant.from-posix(2);
say $a < $b, " ", ($a cmp $b).raku;
say ($b, $a).sort.map(*.Str);
say $a == Instant.from-posix(1);
say $a eqv Instant.from-posix(1);
say $a === Instant.from-posix(1);
say ($a, Instant.from-posix(1)).unique.elems;
say Duration.new(4) === Duration.new(4);
say Duration.new(4) eqv Duration.new(4);
```
```output
True Order::Less
(Instant:11 Instant:12)
True
True
False
2
False
True
```

## A Duration prints as a plain number and stores whole nanoseconds

`Duration.new` takes a number, or a string that holds one, and keeps it as a
whole number of nanoseconds: a third of a second gets nine decimals, and a
tenth of a nanosecond is lost. `.raku` always shows a Rat, even for an Int
or a Num argument, while `say` and `.Str` print the plain number. With no
argument the Duration is zero, and a string that is not a number throws.

```raku
say Duration.new(4).raku;
say Duration.new(4e0).raku;
say Duration.new(4.5);
say Duration.new(1/3).raku;
say Duration.new(1e-10).raku;
say Duration.new.raku;
say Duration.new("2.5").raku;
try Duration.new("meow");
say $!.^name;
```
```output
Duration.new(4.0)
Duration.new(4.0)
4.5
Duration.new(0.333333333)
Duration.new(0.0)
Duration.new(0.0)
Duration.new(2.5)
X::Str::Numeric
```

## `Duration.new(Inf)` is not a Duration
tags: quirk

An infinite or undefined length cannot be counted in nanoseconds. Rakudo
does not refuse it: it returns the Rat `1/0` (or `0/0` for NaN) with a small
role mixed in. The result passes for a number but fails a type check for
Duration.

```raku
my $d = Duration.new(Inf);
say $d.^name;
say $d.raku;
say $d ~~ Duration;
say Duration.new(NaN).raku;
say Duration.new(5) ~~ Duration;
```
```output
Rat+{Duration::add-tai}
<1/0>
False
<0/0>
True
```

## Only `+`, `-` and `%` keep a Duration

Adding a number or another Duration, in either order, subtracting one from
a Duration, negating, and taking `%` give a Duration, and so does `sum`. The
documentation leaves the other operators unspecified. Rakudo answers
multiplication and division with a Num, and a number minus a Duration too,
for that order has no candidate of its own.

```raku
my $d = Duration.new(4.5);
say ($d + 1).raku;
say (1 + $d).raku;
say ($d - Duration.new(1)).raku;
say (-$d).raku;
say ($d % 2).raku;
say (Duration.new(1), Duration.new(2)).sum.raku;
say ($d * 2).raku;
say ($d / Duration.new(1.5)).raku;
say (1 - $d).raku;
```
```output
Duration.new(5.5)
Duration.new(5.5)
Duration.new(3.5)
Duration.new(-4.5)
Duration.new(0.5)
Duration.new(3.0)
9e0
3e0
-3.5e0
```

The rounding methods give Ints, while `abs` keeps the type. Only a zero
Duration is false, and `% 0` throws.

```raku
my $d = Duration.new(4.5);
say $d.Int, " ", Duration.new(-4.5).Int;
say $d.round.^name, " ", $d.abs.^name;
say $d.fmt("%.2f");
say Duration.new(0).Bool;
try Duration.new(1) % 0;
say $!.^name;
```
```output
4 -4
Int Duration
4.50
False
X::Numeric::DivideByZero
```

## `Date.new` takes three parts, named parts, a string or an Instant

A Date is built from a year, a month and a day, given as positionals or as
`:year`, `:month` and `:day`; the named month and day default to 1. The year
and the month go through `Int()`, which accepts a string and truncates a
fraction, and a fractional day is truncated too. `Date.new` also parses a
`YYYY-MM-DD` string, and takes the UTC date of an Instant or the calendar
date of a DateTime, in the DateTime's own zone. `Str.Date` and the coercion
`Date(...)` do the same.

```raku
say Date.new(2015, 12, 24);
say Date.new("2015-12-24").raku;
say Date.new(:year(2015), :month(3)).raku;
say Date.new("2018", "1", "4").raku;
say Date.new(2010, 2.9, 3.7).raku;
say Date.new(Instant.from-posix(1234567890)).raku;
say Date.new(DateTime.new("2020-05-06T23:30:00-05:00")).raku;
say "2020-01-02".Date.raku;
```
```output
2015-12-24
Date.new(2015,12,24)
Date.new(2015,3,1)
Date.new(2018,1,4)
Date.new(2010,2,3)
Date.new(2009,2,13)
Date.new(2020,5,6)
Date.new(2020,1,2)
```

`2.9` is February. The DateTime of the seventh line is already 7 May in UTC,
but its own date is the 6th.

## The day may be `*`, or code that receives the month's length

A Whatever as the day means the last day of the month. A piece of code as
the day is called with the number of days in the month, and its result is
the day, so `*-1` is the day before the last.

```raku
say Date.new(2044, 2, *);
say Date.new(2042, 2, *);
say Date.new(2044, 2, *-1);
say Date.new(2044, 2, { $_ div 2 });
say Date.new(:year(2044), :month(2), :day(*));
```
```output
2044-02-29
2042-02-28
2044-02-28
2044-02-14
2044-02-29
```

## `Date.new` ignores names it does not know, `:timezone` included
tags: trap

A Date has no time zone, and `Date.new` does not say so when given one: an
unknown named argument is dropped without a word. One or two positionals
match no candidate, and `Date.new` with nothing at all returns a Failure
rather than throwing.

```raku
say Date.new("2020-01-02", :timezone(3600)).raku;
say Date.new(2020, 1, 2, :foo).raku;
try Date.new(2020, 1);
say $!.^name;
my $none = Date.new;
say $none.defined;
say $none.exception.message;
```
```output
Date.new(2020,1,2)
Date.new(2020,1,2)
X::Multi::NoMatch
False
Cannot call Date.new with no parameters
```

The date of a moment in a given zone comes from a DateTime:
`DateTime.new($instant, :timezone($offset)).Date`.

## A formatter changes `.Str` and `.gist`, never `.raku`

`:formatter` takes a piece of code that receives the Date and returns its
text. `say`, `put` and interpolation all use it, while `.raku` ignores it,
so that its output can still be read back as code. DateTime takes a
formatter in the same way. Without one, `.formatter` is the `Callable` type
object. The code must return a string: a formatter that returns a number
dies when the date is printed.

```raku
my $d = Date.new(2015, 12, 29, :formatter({ sprintf "%02d/%02d/%d", .day, .month, .year }));
say $d;
say "Due: $d";
say $d.raku;
say Date.new("2015-12-29").formatter.^name;
my $bad = Date.new("2020-01-02", :formatter({ .year }));
say $bad;
```
```output
29/12/2015
Due: 29/12/2015
Date.new(2015,12,29)
Callable
```
```stderr
Type check failed for return value; expected Str:D but got Int (2020)
  in block <unit> at example.raku line 7

```

## A Date made from a DateTime takes over its formatter
tags: quirk

`Date.new($datetime)` copies the year, the month and the day, and, unless it
is given a formatter of its own, the DateTime's formatter as well. That code
was written for a DateTime and now receives a Date, which has no time of
day: a formatter that asks for the time dies when the Date is printed.

```raku
my $dt = DateTime.new("2020-05-06T23:30:00Z", :formatter({ "at " ~ .hh-mm-ss }));
say $dt;
my $d = Date.new($dt);
say $d.raku;
say Date.new($dt, :formatter({ .yyyy-mm-dd("/") }));
say $d;
```
```output
at 23:30:00
Date.new(2020,5,6)
2020/05/06
```
```stderr
No such method 'hh-mm-ss' for invocant of type 'Date'
  in block <unit> at example.raku line 1

```

## A date string is exactly `YYYY-MM-DD`

The string form takes four digits of year, two of month and two of day,
joined by hyphens, and nothing else: no space around it, no newline, no time
of day, no other separator. A year of more than four digits, or one below
zero, carries a sign. Digits from other scripts count as digits.

```raku
for "2015-12-24", "+12345-01-01", "-1234-12-24", "0000-01-01", "٢٠١٠-٠١-٠٢",
    "2015-1-24", "999-01-01", " 2015-12-24", "2015-12-24\n", "20151224",
    "2015/12/24", "2015-12-24T00:00:00" -> $s {
    my $r = try Date.new($s);
    say $s.raku, ": ", $r // $!.^name;
}
```
```output
"2015-12-24": 2015-12-24
"+12345-01-01": +12345-01-01
"-1234-12-24": -1234-12-24
"0000-01-01": 0000-01-01
"٢٠١٠-٠١-٠٢": 2010-01-02
"2015-1-24": X::Temporal::InvalidFormat
"999-01-01": X::Temporal::InvalidFormat
" 2015-12-24": X::Temporal::InvalidFormat
"2015-12-24\n": X::Temporal::InvalidFormat
"20151224": X::Temporal::InvalidFormat
"2015/12/24": X::Temporal::InvalidFormat
"2015-12-24T00:00:00": X::Temporal::InvalidFormat
```

A line read with `get` or `lines` has already lost its newline. The
exception holds the string, the type it was meant for and the expected
format, and it is an `X::Temporal`:

```raku
try Date.new("24.12.2015");
say $!.invalid-str;
say $!.target;
say $!.format;
say $! ~~ X::Temporal;
say $!.message;
```
```output
24.12.2015
Date
yyyy-mm-dd
True
Invalid Date string '24.12.2015'; use yyyy-mm-dd instead
```

## A bad month or day throws `X::Temporal::OutOfRange`, with the valid range

The month is checked first, then the day against the length of that month in
that year, with the Gregorian rule for leap years: 2000 and 2016 have a
29 February, 1900 has not. The exception is both an `X::OutOfRange` and an
`X::Temporal`; `.what` names the field, `.got` the value and `.range` what
was allowed. A month that is not a number at all fails before any check,
with an `X::AdHoc` whose message comes from deep inside Rakudo.

```raku
try Date.new(2015, 13, 42);
say $!.^name, ": ", $!.what, " ", $!.got, " not in ", $!.range;
say $!.message;
try Date.new(2015, 2, 29);
say $!.what, " ", $!.got, " not in ", $!.range;
say Date.new(2016, 2, 29);
try Date.new(1900, 2, 29);
say $!.range;
try Date.new(2015, "x", 1);
say $!.^name, ": ", $!.message;
```
```output
X::Temporal::OutOfRange: Month 13 not in 1..12
Month out of range. Is: 13, should be in 1..12
Day 29 not in 1..28
2016-02-29
1..28
X::AdHoc: This type cannot unbox to a native integer: P6opaque, Failure
```

Day 0 and a negative day are out of range too. The string form checks the
same way: `Date.new("2015-02-30")` is an `X::Temporal::OutOfRange`, not a
format error.

## `day-of-week` counts from Monday, and `week` is the ISO week

`day-of-week` is 1 for Monday through 7 for Sunday, and `day-of-year` counts
from 1. `week` returns the ISO 8601 week as a list of two numbers, the
week's year and its number. A week belongs to the year that holds its
Thursday, so 31 December can be in week 1 of the next year and 2 January in
week 53 of the last. `week-year` and `week-number` are the two halves.
`weekday-of-month` tells which occurrence of its weekday a day is in its
month: 28 February 2000 is the fourth Monday.

```raku
my $d = Date.new("2000-02-28");
say $d.day-of-week;
say $d.day-of-year;
say $d.week.raku;
say $d.weekday-of-month;
say $d.days-in-month, " ", $d.is-leap-year;
say Date.new("2014-12-31").week.raku;
say Date.new("2016-01-02").week.raku;
say Date.new("2005-01-01").week-year, " ", Date.new("2005-01-01").week-number;
```
```output
1
59
(2000, 9)
4
29 True
(2015, 1)
(2015, 53)
2004 53
```

## A Date as a number is its Modified Julian Day

`daycount` numbers the days from 17 November 1858, day 0 of the Modified
Julian Day count used by astronomers; 1 January 1970 is day 40587. A Date
used as a number, with prefix `+`, `.Int` or `==`, is its daycount, and
`new-from-daycount` goes back.

```raku
my $d = Date.new("2000-02-28");
say $d.daycount;
say +$d;
say $d.Int;
say Date.new("1858-11-17").daycount;
say Date.new("1970-01-01").daycount;
say $d == 51602;
say Date.new-from-daycount(0);
```
```output
51602
51602
51602
0
40587
True
1858-11-17
```

## `yyyy-mm-dd` and its relatives take a separator

A Date's default text is its `yyyy-mm-dd`. That method and its reorderings,
`dd-mm-yyyy` and `mm-dd-yyyy`, take an optional separator, which may be
empty; `yyyy-mm` and `mm-dd` give two of the parts. `days-in-month` and
`days-in-year` also work on the class itself, for any year and month.

```raku
my $d = Date.new("2000-02-08");
say $d.yyyy-mm-dd;
say $d.yyyy-mm-dd("/");
say $d.dd-mm-yyyy(".");
say $d.mm-dd-yyyy("");
say $d.yyyy-mm;
say $d.mm-dd;
say Date.days-in-month(2024, 2);
say Date.days-in-year(1900);
```
```output
2000-02-08
2000/02/08
08.02.2000
02082000
2000-02
02-08
29
365
```

## Years outside 1000 to 9999 are padded or signed
tags: undocumented

A year below 1000 prints with leading zeros to four digits. A negative year,
or one above 9999, prints with its sign and at least five digits, so that the
text still parses back. `.raku` shows the plain number. The rule holds in
every format method and in a DateTime's text.

```raku
say Date.new(999, 1, 1);
say Date.new(5, 1, 1);
say Date.new(-1, 12, 27);
say Date.new(10000, 1, 1);
say Date.new(12345, 6, 7).mm-dd-yyyy;
say Date.new(999, 1, 1).raku;
say DateTime.new(-1, 1, 1, 0, 0, 0);
say Date.new("-0001-01-01").year;
```
```output
0999-01-01
0005-01-01
-0001-12-27
+10000-01-01
06-07-+12345
Date.new(999,1,1)
-0001-01-01T00:00:00Z
-1
```

## The calendar is Gregorian all the way back, and year 0 exists
tags: undocumented

Dates before the calendar reform of 1582 follow the Gregorian rules anyway,
the *proleptic* Gregorian calendar. There is no switch to the Julian
calendar, so the day after 4 October 1582 is 5 October, although the
countries that adopted the reform that year went on to 15 October. Year 0
exists and is a leap year, as in the astronomers' count of years, and the
daycount runs on below zero.

```raku
say Date.new(0, 1, 1).is-leap-year;
say Date.new(0, 2, 29);
say Date.new(0, 1, 1).day-of-week;
say Date.new(0, 1, 1).daycount;
say Date.new(-4713, 11, 24).daycount;
say Date.new(1582, 10, 4) + 1;
```
```output
True
0000-02-29
6
-678941
-2400001
1582-10-05
```

Year -4713 is 4714 BC, and its 24 November is where the unmodified Julian
Day count begins, 2400000.5 days before day 0 of the modified one.

## A Date plus an Int moves by days; a Date minus a Date counts them

`+` and `-` with an Int move a Date by that many days, and `+` works in
either order. One Date minus another is the signed number of days between
them, an Int. `succ` and `pred` step by one day, and they are what `++` uses;
`+=` works as well. `True` counts as 1.

```raku
my $d = Date.new("2000-02-28");
say $d + 1;
say 7 + $d;
say $d - 60;
say Date.new("2000-03-01") - $d;
say ($d - Date.new("2000-03-01")).raku;
say $d.succ, " ", $d.pred;
my $e = $d;
$e++;
$e += 2;
say $e;
say $d + True;
```
```output
2000-02-29
2000-03-06
1999-12-30
2
-2
2000-02-29 2000-02-27
2000-03-02
2000-02-29
```

## Any other arithmetic on a Date quietly uses its day count
tags: quirk

A Date has operators of its own only for adding and subtracting whole days
and for subtracting another Date. Everything else treats the Date as a
number, its daycount, and computes without an error: two Dates add up to a
large Int, a fractional day gives a Rat, and a Duration is added to the
daycount as if both were seconds. A string of digits does not move the date
either; it is turned into a number and added to the daycount.

```raku
my $d = Date.new("2020-01-01");
say ($d + $d).raku;
say ($d + 1.5).raku;
say ($d + "1").raku;
say ($d * 2).raku;
say ($d + Duration.new(60)).raku;
say ($d - Duration.new(60)).raku;
say (1 - $d).raku;
say ($d + 1e0).raku;
```
```output
117698
58850.5
58850
117698
Duration.new(58909.0)
58789e0
-58848
58850e0
```

## The sum of some Dates is a Date or an Int, depending on the count
tags: quirk

`sum` adds from left to right with `+`, and the previous corner decides each
step: two Dates make an Int, and an Int plus a Date is a Date again. The type
of the result therefore alternates with the number of Dates, and a range of
Dates sums the same way. Map the Dates to their daycounts first to add them
up.

```raku
my $d = Date.new("2019-05-01");
say ($d, $d + 1).sum.raku;
say ($d, $d + 1, $d + 2).sum.raku;
say ($d .. $d + 3).sum.raku;
say ($d .. $d + 4).sum.raku;
say ($d .. $d + 2).map(*.daycount).sum;
```
```output
117209
Date.new(2340,3,30)
234422
Date.new(2661,3,2)
175815
```

## Dates compare by day, but `cmp` and `sort` compare their text
tags: quirk

`==`, `<`, `<=>` and the other numeric comparisons compare daycounts, so a
Date also equals a plain number. `cmp` and `leg`, and with them `sort`, `min`
and `max`, compare the Dates' `.Str`. With the default text the two orders
agree, so the difference goes unseen until a Date meets a number, or a
formatter changes its text.

```raku
my $a = Date.new("1963-07-02");
my $b = Date.new("1964-02-01");
say $a < $b;
say ($a cmp $b).raku;
say $a == 38212;
say ($a cmp 38212).raku;
say ($a cmp "1963-07-02").raku;
say $a eq "1963-07-02";
```
```output
True
Order::Less
True
Order::Less
Order::Same
True
```

`$a cmp 38212` compares `"1963-07-02"` with `"38212"`. With a formatter,
`sort` orders the formatted texts, and two Dates whose formatter prints the
same text are `cmp` Same whatever their days:

```raku
my @days = <2021-03-09 2021-11-30 2021-02-14>.map: {
    Date.new($_, :formatter({ .day ~ "." ~ .month ~ "." }))
};
say @days.sort;
say @days.sort(*.daycount);
say @days.max;
say @days.max(*.daycount);
```
```output
(14.2. 30.11. 9.3.)
(14.2. 9.3. 30.11.)
9.3.
30.11.
```

Give `sort`, `min` or `max` the key `*.daycount` to get the calendar order.

## A Date's identity is its day: a formatter does not count, a subclass does

`===` and `unique` take two Dates of the same day as one value whatever their
formatters, even when their texts differ. A subclass of Date makes another
value: equal with `==`, but neither `===` nor `eqv` to the plain Date.
Smartmatching a Date against a string compares the Date's text, while a
string topic never matches a Date.

```raku
my $x = Date.new("2020-01-01", :formatter({ "some day" }));
say $x === Date.new("2020-01-01");
say ($x, Date.new("2020-01-01")).unique.elems;
class Day is Date { }
my $s = Day.new("2020-01-01");
say $s == $x, " ", $s === $x, " ", $s eqv $x;
say Date.new("2020-01-01") ~~ "2020-01-01";
say "2020-01-01" ~~ Date.new("2020-01-01");
```
```output
True
1
True False False
True
False
```

## A DateTime matches the Date of its own clock; a Date matches no DateTime
tags: trap

Smartmatching a DateTime against a Date compares the year, the month and
the day as the DateTime holds them, in its own zone: 23:30 at five hours
behind UTC matches its local day, although in UTC it is already the next.
The other direction never matches. A DateTime on the right compares
moments, and a Date is not one; `==` between the two is False as well.

```raku
my $late = DateTime.new("1963-07-02T23:30:00-05:00");
say $late.utc;
say $late ~~ Date.new("1963-07-02");
say $late ~~ Date.new("1963-07-03");
say Date.new("1963-07-02") ~~ $late;
say Date.new("1963-07-02") ~~ DateTime.new("1963-07-02T00:00:00Z");
say $late == Date.new("1963-07-02");
```
```output
1963-07-03T04:30:00Z
True
False
False
False
False
```

## A range of Dates walks one day at a time

Two Dates make a Range whose elements are the days from one to the other,
each found with `succ`, so the ends of months and the leap days take care of
themselves. It counts, indexes and tests membership like other ranges, and an
endless one is lazy. The general rules are in
[Ranges](#ch:ranges:anything-comparable-can-be-a-topic-and-a-date-range-walks-days).

```raku
my $r = Date.new("2019-05-01") .. Date.new("2019-05-04");
say $r.elems;
say $r.list;
say Date.new("2019-05-03") ~~ $r;
say $r[1];
say $r.raku;
say (Date.new("2019-05-01") .. *)[40];
say (Date.new("2020-02-27") .. Date.new("2020-03-01")).map(*.day);
```
```output
4
(2019-05-01 2019-05-02 2019-05-03 2019-05-04)
True
2019-05-02
Date.new(2019,5,1)..Date.new(2019,5,4)
2019-06-10
(27 28 29 1)
```

## A Date range compares by text, so a formatter cuts it short
tags: bug

A range decides both membership and where its iteration stops with `cmp`,
and `cmp` compares Dates [as
text](#ch:dates:dates-compare-by-day-but-cmp-and-sort-compare-their-text).
A string therefore matches a Date range whenever it sorts between the
endpoints, whatever else it says, and a string is accepted as an endpoint.
A formatter on the start goes further. The Date documentation offers
`$date .. $date.last-date-in-month` as the remaining dates of a month, yet
in Rakudo 2026.08 a formatter changes where such a range stops: below, the
days print as their day numbers, and the iteration ends as soon as `"3"`
sorts after `"2019-05-09"`, so a range of nine days has two elements.

```raku
my $r = Date.new("2019-05-01") .. Date.new("2019-05-05");
say "2019-05-03 and more" ~~ $r;
say (Date.new("2019-05-01") .. "2019-05-03").list;
my $start = Date.new("2019-05-01", :formatter({ ~.day }));
say ($start .. Date.new("2019-05-09")).list;
say ($start .. Date.new("2019-05-09")).elems;
```
```output
True
(2019-05-01 2019-05-02 2019-05-03)
(1 2)
2
```

`<`, `<=>` and subtraction still count the same Dates by day; only the
comparison by text stops early. Build a range from Dates without
formatters, and format the days when printing them.

## `later` and `earlier` move by one unit; a month clips the day

`later(unit => n)` moves a Date forward and `earlier` backwards. The units
are `day`, `week`, `month` and `year`, each also in the plural, and the count
may be negative. Days and weeks move by days. Months and years change the
month and the year and keep the day when the new month has it; otherwise the
day becomes the month's last. Two moves of one month therefore differ from a
single move of two.

```raku
my $d = Date.new("2015-01-31");
say $d.later(:1day);
say $d.later(:2weeks);
say $d.later(:1month);
say $d.later(:1month).later(:1month);
say $d.later(:2months);
say $d.earlier(:1year);
say Date.new("2016-02-29").later(:1year);
say Date.new("2016-02-29").later(:4years);
```
```output
2015-02-01
2015-02-14
2015-02-28
2015-03-28
2015-03-31
2014-01-31
2017-02-28
2020-02-29
```

`:1day` is the pair `day => 1`. Its number must be a plain integer, so
`:2.7days` and `:-1day` do not even parse ([Whitespace, Terms and
Blocks](#ch:whitespace:a-colonpairs-number-must-be-a-plain-integer)); write
`day => -1`. Two units in one call are refused, because the order of
application matters; a list of pairs states the order. A Date refuses the
units of a time of day.

```raku
my $d = Date.new("2021-01-30");
say $d.later((:1month, :2days));
say $d.later((:2days, :1month));
try $d.later(:1month, :2days);
say $!.message;
try $d.later(:1hour);
say $!.message;
```
```output
2021-03-02
2021-03-01
More than one time unit supplied. Please provide these as a List of
Pairs to indicate order of application if this is intended.
Cannot use '1 hour' as a unit on a Date
```

## An unknown unit dies on a Date and does nothing on a DateTime
tags: quirk

A misspelt unit meets no check of its own. On a Date the move produces
nothing, and the method's return type check is what complains. On a DateTime
the same unit is ignored and the invocant comes back unchanged. The counts
differ too: a Date needs a whole number and dies of a fraction, while a
DateTime truncates the count for every unit except seconds.

```raku
my $d = Date.new("2021-03-31");
my $t = DateTime.new("2021-03-31T12:00:00Z");
try $d.later(:1fortnight);
say $!.^name;
say $t.later(:1fortnight) === $t;
try $d.later(days => 2.7);
say $!.message;
say $t.later(days => 2.7);
say $t.later(seconds => 2.7);
```
```output
X::TypeCheck::Return
True
This type cannot unbox to a native integer: P6opaque, Rat
2021-04-02T12:00:00Z
2021-03-31T12:00:02.700000Z
```

## `truncated-to` accepts any word that begins with a unit
tags: quirk

`truncated-to` rounds a Date down to the first day of its year or month, or
to the Monday of its week. Only the beginning of the unit's name is
compared, so any word that starts with a unit is taken as that unit:
`"weekend"` means a week, and gives the Monday before. An abbreviation is not
accepted, nor a capital letter, and a Date has no `day` to truncate to.

```raku
my $d = Date.new("2012-12-24");
say $d.truncated-to("year");
say $d.truncated-to("month");
say Date.new("2000-03-01").truncated-to("week");
say $d.truncated-to("yearning");
say Date.new("2012-12-29").truncated-to("weekend");
try $d.truncated-to("mon");
say $!.^name;
try $d.truncated-to("day");
say $!.message;
```
```output
2012-01-01
2012-12-01
2000-02-28
2012-01-01
2012-12-24
X::AdHoc
Cannot truncate Date object to 'day'
```

## A DateTime truncates in its own zone

On a DateTime, `truncated-to` also takes `second`, `minute`, `hour` and
`day`. It works on the wall clock in the DateTime's zone and keeps the zone,
so midnight of a day at +02:00 is 22:00 UTC the day before. `second` drops
the fraction and leaves an Int, and a leap second stays at 60. The same
prefix rule applies: `"hourglass"` is an hour, but `"daily"` is refused.

```raku
my $t = DateTime.new("2012-02-29T00:34:56.75+02:00");
say $t.truncated-to("second");
say $t.truncated-to("second").second.^name;
say $t.truncated-to("hour");
say $t.truncated-to("day");
say $t.truncated-to("day").utc;
say $t.truncated-to("week");
say DateTime.new("2016-12-31T23:59:60.5Z").truncated-to("second");
```
```output
2012-02-29T00:34:56+02:00
Int
2012-02-29T00:00:00+02:00
2012-02-29T00:00:00+02:00
2012-02-28T22:00:00Z
2012-02-27T00:00:00+02:00
2016-12-31T23:59:60Z
```

## `clone` replaces fields and checks them again

`clone` takes the named fields of `new` and validates the result: moving
29 January to February fails, unless the same call makes the year a leap
year. The day may be `*`, `*-1` or a string, but the month and the year must
be Ints, and a string month is refused.

```raku
my $d = Date.new("2015-11-24");
say $d.clone(month => 12);
say $d.clone(:day(*));
say $d.clone(:day(*-1));
say $d.clone(:day("5"));
try $d.clone(:month("12"));
say $!.^name;
try Date.new("1999-01-29").clone(:month(2));
say $!.^name;
say Date.new("1999-01-29").clone(:month(2), :year(2000));
```
```output
2015-12-24
2015-11-30
2015-11-29
2015-11-05
X::AdHoc
X::Temporal::OutOfRange
2000-02-29
```

`first-date-in-month` and `last-date-in-month` are the common clones.
`new-from-daycount` takes only an Int, and called on a Date it keeps that
Date's formatter. Every one of them keeps the formatter unless given another;
`:formatter(Callable)` restores the default.

```raku
my $d = Date.new("2016-02-10");
say $d.first-date-in-month;
say $d.last-date-in-month;
say Date.new-from-daycount(-1);
try Date.new-from-daycount(49987.5);
say $!.^name;
my $f = Date.new("2020-01-01", :formatter({ "day " ~ .daycount }));
say $f.new-from-daycount(49987);
say $f.clone(:formatter(Callable));
```
```output
2016-02-01
2016-02-29
1858-11-16
X::AdHoc
day 49987
2020-01-01
```

## A Date becomes a DateTime at midnight UTC, without its formatter

`.DateTime` and the coercion `DateTime(...)` turn a Date into the DateTime
of its midnight, in UTC; the formatter stays behind. `DateTime.new` does not
take a Date as a positional argument. The named `:date` does, with the time
of day and the zone as further named arguments. `.Date` of a Date is the
Date itself.

```raku
my $d = Date.new("2015-12-24", :formatter({ "F" }));
my $dt = $d.DateTime;
say $dt;
say $dt.timezone;
say DateTime($d);
try DateTime.new($d);
say $!.^name;
say DateTime.new(:date($d), :hour(5), :timezone(3600));
say $d.Date === $d;
```
```output
2015-12-24T00:00:00Z
0
2015-12-24T00:00:00Z
X::Multi::NoMatch
2015-12-24T05:00:00+01:00
True
```

## `:year` beside `:date` throws the date away
tags: quirk

With `:date`, the named `:month` and `:day` replace those parts of the date.
A `:year` does something else: the date is ignored altogether, and the
DateTime is built from the named parts alone, with the month and the day at
their default of 1.

```raku
my $d = Date.new("2015-12-24");
say DateTime.new(:date($d), :month(5));
say DateTime.new(:date($d), :day(5));
say DateTime.new(:date($d), :year(2000));
say DateTime.new(:date($d), :year(2000), :hour(3));
```
```output
2015-05-24T00:00:00Z
2015-12-05T00:00:00Z
2000-01-01T00:00:00Z
2000-01-01T03:00:00Z
```

## `DateTime.new` reads ISO 8601, with a zone or without

The string form is a date, a `T` and a time to the second, optionally
followed by a fraction after `.` or `,`, and by `Z` or an offset written
`+hh`, `+hhmm` or `+hh:mm`. `T` and `Z` may be lower case. Without an offset
the time is taken as UTC, unless `:timezone` names a zone. A date alone is
its midnight. The zone is kept as seconds east of UTC, and printed as `Z`
when it is zero.

```raku
say DateTime.new("2009-12-31T22:33:44Z");
say DateTime.new("2009-12-31T22:33:44+0000");
say DateTime.new("2009-12-31T22:33:44+11");
say DateTime.new("2009-12-31T22:33:44-00:30").timezone;
say DateTime.new("2009-12-31t22:33:44z");
say DateTime.new("2009-12-31T22:33:44,5+05:30");
say DateTime.new("2009-12-31T22:33:44", :timezone(3600));
say DateTime.new("2009-12-31");
```
```output
2009-12-31T22:33:44Z
2009-12-31T22:33:44Z
2009-12-31T22:33:44+11:00
-1800
2009-12-31T22:33:44Z
2009-12-31T22:33:44.500000+05:30
2009-12-31T22:33:44+01:00
2009-12-31T00:00:00Z
```

The second is an Int when the string has no fraction, and a Rat that keeps
every digit, up to twelve, when it has one; the default text shows six.
`.raku` lists the fields with the second as stored, and the zone when it is
not zero. The hours of an offset have no upper limit.

```raku
say DateTime.new("2015-12-11T20:41:10Z").second.raku;
say DateTime.new("2015-12-11T20:41:10.000Z").second.raku;
say DateTime.new("2015-12-11T20:41:10.987654321Z").second.raku;
say DateTime.new("2015-12-11T20:41:10.987654321Z");
say DateTime.new("2009-12-31T22:33:44.5+01:00").raku;
say DateTime.new("2012-12-22T07:02:00+99:00").timezone;
```
```output
10
10.0
10.987654321
2015-12-11T20:41:10.987654Z
DateTime.new(2009,12,31,22,33,44.5,:timezone(3600))
356400
```

## Near misses of ISO 8601 are refused

The parser is strict. A space in place of the `T`, a time without seconds,
`UTC` in place of `Z`, a space before the `Z`, a one-digit offset, a trailing
colon, the compact form without hyphens and colons, and a fraction of
thirteen digits all throw `X::Temporal::InvalidFormat`. There is no
`24:00:00` either.

```raku
for "2012-12-22 07:02:00", "2012-12-22T07:02", "2012-12-22T07:02:00UTC",
    "2012-12-22T07:02:00 Z", "2012-12-22T07:02:00+7", "2012-12-22T07:02:00+01:",
    "20121222T070200Z", "2012-12-22T24:00:00Z", "2012-12-22T07:02:00+00:60",
    "2012-12-22T07:02:00.1234567890123Z" -> $s {
    my $r = try DateTime.new($s);
    say $s, ": ", $r // $!.^name;
}
```
```output
2012-12-22 07:02:00: X::Temporal::InvalidFormat
2012-12-22T07:02: X::Temporal::InvalidFormat
2012-12-22T07:02:00UTC: X::Temporal::InvalidFormat
2012-12-22T07:02:00 Z: X::Temporal::InvalidFormat
2012-12-22T07:02:00+7: X::Temporal::InvalidFormat
2012-12-22T07:02:00+01:: X::Temporal::InvalidFormat
20121222T070200Z: X::Temporal::InvalidFormat
2012-12-22T24:00:00Z: X::Temporal::OutOfRange
2012-12-22T07:02:00+00:60: X::OutOfRange
2012-12-22T07:02:00.1234567890123Z: X::Temporal::InvalidFormat
```

Offset minutes of 60 or more fail with a plain `X::OutOfRange`, which is not
an `X::Temporal`, so a handler for the temporal errors misses it:

```raku
try DateTime.new("2012-12-22T07:02:00+00:75");
say $!.^name, " ", $! ~~ X::Temporal;
say $!.message;
```
```output
X::OutOfRange False
minutes of timezone out of range. Is: 75, should be in 0..^60
```

## A `Z` gives way to `:timezone`, but an offset clashes with it
tags: trap

`:timezone` supplies the zone of a string that has none. It also overrides a
`Z`: the wall-clock time stays as written and only the label changes, so the
result is an hour away from the moment the string names. Only an explicit
offset beside `:timezone` is refused, with `X::DateTime::TimezoneClash`, even
when the two agree.

```raku
say DateTime.new("2012-12-22T07:02:00Z", :timezone(3600));
say DateTime.new("2012-12-22T07:02:00", :timezone(3600));
try DateTime.new("2012-12-22T07:02:00+01:00", :timezone(3600));
say $!.^name;
say $!.message;
```
```output
2012-12-22T07:02:00+01:00
2012-12-22T07:02:00+01:00
X::DateTime::TimezoneClash
DateTime.new(Str): :timezone argument not allowed with a timestamp offset
```

## A date-only string with a bad month dies with an internal error
tags: bug

A full timestamp with month 13 throws `X::Temporal::OutOfRange`, as
`Date.new` does, and so does a date-only string with day 32, although its
`.got` is the string that was read rather than a number. A date-only string
with month 13 is the exception: Rakudo 2026.08 dies with an `X::AdHoc` whose
message is about unboxing a type object, an internal step, where the two
neighbouring forms name the field that is out of range.

```raku
try DateTime.new("2012-13-22T07:02:00Z");
say $!.^name, ": ", $!.what, " ", $!.got.raku;
try DateTime.new("2012-12-32");
say $!.^name, ": ", $!.what, " ", $!.got.raku;
try DateTime.new("2012-13-22");
say $!.^name;
say $!.message;
```
```output
X::Temporal::OutOfRange: Month 13
X::Temporal::OutOfRange: Day "32"
X::AdHoc
Cannot unbox a type object (Nil) to int.
```

## A number is a POSIX time, and the second takes its type

`DateTime.new` with one number reads it as a POSIX time in UTC. Leap seconds
do not exist on that scale, so 1483228800 is the first second of 2017. The
fraction becomes the fraction of the second, in the number's own type: a Rat
gives a Rat second, and a Num a Num. `:timezone` moves the wall clock and
labels it without changing the moment. Only `:timezone` and `:formatter` are
accepted beside the number, and here the zone must be an Int. An allomorph
such as `<1234>` counts as a number, while the string `"1234"` is a
malformed timestamp.

```raku
say DateTime.new(0);
say DateTime.new(-1);
say DateTime.new(1483228800);
say DateTime.new(0.5).second.raku;
say DateTime.new(1e0).second.raku;
say DateTime.new(0, :timezone(3600));
say DateTime.new(0, :timezone(3600)).posix;
try DateTime.new(0, :timezone("3600"));
say $!.^name;
say DateTime.new(<1234>);
try DateTime.new("1234");
say $!.^name;
```
```output
1970-01-01T00:00:00Z
1969-12-31T23:59:59Z
2017-01-01T00:00:00Z
0.5
1e0
1970-01-01T01:00:00+01:00
0
X::AdHoc
1970-01-01T00:20:34Z
X::Temporal::InvalidFormat
```

## The six-part form keeps the second exactly as given, even a string
tags: quirk

`DateTime.new($year, $month, $day, $hour, $minute, $second)` turns the first
five into Ints, truncating fractions, and takes the day as `Date.new` does.
The second is stored as it arrives: a Rat stays a Rat, and a string stays a
string, although it prints like a number. The named form needs `:year` and
defaults the other parts, and there a string `:timezone` is converted. With
no arguments at all, `DateTime.new` returns a Failure.

```raku
my $dt = DateTime.new(2020, 1, 2, 3, 4, "5");
say $dt;
say $dt.second.^name;
say DateTime.new(2020, 1.9, 2.9, 3.9, 4.9, 5);
say DateTime.new(2020, 2, *-1, 3, 4, 5);
say DateTime.new(:year<2016>);
say DateTime.new(:2020year, :timezone("3600"));
my $none = DateTime.new;
say $none.defined;
say $none.exception.message;
```
```output
2020-01-02T03:04:05Z
Str
2020-01-02T03:04:05Z
2020-02-28T03:04:05Z
2016-01-01T00:00:00Z
2020-01-01T00:00:00+01:00
False
Cannot call DateTime.new with no parameters
```

## Hour and minute throw `X::Temporal::OutOfRange`; the second does not
tags: quirk

The month, day, hour and minute are checked like the fields of a Date, with
`X::Temporal::OutOfRange`. The second is checked in two steps, and both throw
a plain `X::OutOfRange`, which is not an `X::Temporal`. First the value as
given must lie below 61, so a string or NaN fails here; this step reports
its range as the string `^61` and its `.got` as a string too. Then a second
of 60 or more must be a leap second, which the next corner covers.

```raku
try DateTime.new(:1984year, :24hour);
say $!.^name, ": ", $!.what, " ", $!.got, " not in ", $!.range;
try DateTime.new(:1984year, :second(61));
say $!.^name, ": ", $!.what, " ", $!.got, " not in ", $!.range;
say $! ~~ X::Temporal;
try DateTime.new(:1984year, :second(-0.5));
say $!.got.raku, " ", $!.range.raku;
try DateTime.new(:1984year, :second(NaN));
say $!.^name;
```
```output
X::Temporal::OutOfRange: Hour 24 not in 0..23
X::OutOfRange: Second 61 not in ^61
False
"-0.5" "^61"
X::OutOfRange
```

## A second of 60 is accepted only at 23:59 UTC on a leap-second day

A leap second exists only as the last second of a day on which one was
inserted, and that day ends in UTC. `DateTime.new` checks the moment, not
the text: two hours east of UTC, the leap second is 01:59:60 the next
morning, and 23:59:60 there is refused. The message says which rule failed.

```raku
say DateTime.new("1998-12-31T23:59:60Z");
say DateTime.new("1999-01-01T01:59:60+02:00");
say DateTime.new(:1997year, :6month, :30day, :23hour, :59minute, :second(60.9));
try DateTime.new("1998-12-31T23:59:60+02:00");
say $!.message;
try DateTime.new("1999-06-30T23:59:60Z");
say $!.message;
```
```output
1998-12-31T23:59:60Z
1999-01-01T01:59:60+02:00
1997-06-30T23:59:60.900000Z
Second out of range. Is: 60, should be in 0..^60; a leap second can occur only at 23:59
Second out of range. Is: 60, should be in 0..^60; There is no leap second on UTC 1999-06-30
```

## `.posix` drops the fraction, `.Instant` keeps it, and `.Int` is refused

`.second` returns the second as it was stored, and `.whole-second` its whole
part. `.timezone` is the offset in seconds, and `offset-in-hours` gives it as
a Rat. `.posix` is the POSIX time as an Int, without the fraction unless
`:real` is given; with a True argument it reads the wall clock as though it
were UTC. `.Instant` keeps the fraction, and a DateTime used as a number is
its Instant. There is no `.Int`, and since an Instant as a number is its TAI
count, a DateTime equals its Instant but not its POSIX time.

```raku
my $dt = DateTime.new("2015-12-24T12:23:45.5+02:00");
say $dt.second.raku, " ", $dt.whole-second;
say $dt.timezone, " ", $dt.offset-in-hours.raku;
say $dt.posix, " ", $dt.posix(:real).raku;
say $dt.posix(True);
say $dt.Instant.raku;
say (+$dt).^name;
try $dt.Int;
say $!.^name;
say $dt == $dt.Instant, " ", $dt == $dt.posix;
```
```output
45.5 45
7200 2.0
1450952625 1450952625.5
1450959825
Instant.from-posix(1450952625.5)
Instant
X::Multi::NoMatch
True False
```

## The calendar methods follow the local date; the Julian dates follow UTC

A DateTime answers the Dateish methods, `daycount`, `day-of-week` and the
rest, for the date on its own wall clock. `day-fraction` is the part of that
local day gone by. `modified-julian-date` and `julian-date` are
astronomical, and use the UTC time, so they can be a day apart from
`daycount`.

```raku
my $dt = DateTime.new("2015-12-24T00:30:00+02:00");
say $dt.Date;
say $dt.utc.Date;
say $dt.daycount, " ", $dt.utc.daycount;
say $dt.day-of-week, " ", $dt.utc.day-of-week;
say $dt.day-fraction.raku;
say $dt.modified-julian-date.raku;
say $dt.julian-date.raku;
say DateTime.new("2016-12-31T12:00:00Z").day-fraction.raku;
```
```output
2015-12-24
2015-12-23
57380 57379
4 3
<1/48>
57379.9375
2457380.4375
<43200/86401>
```

The last line is not a half: 31 December 2016 had a leap second, and 86401
seconds.

## The default text shows the zone to the minute, and six decimals when needed

The default formatter writes the date, `T`, the time, six decimals if the
second is not whole, and then `Z` for a zone of zero or the offset as
`±hh:mm`. The seconds of an offset are left out of the text, so a zone of
30 seconds west prints as `-00:00`, though it is not UTC. The decimals are
rounded half up, and a Num second prints like a Rat.

```raku
say DateTime.new(:2000year, :timezone(3661));
say DateTime.new(:2000year, :timezone(-30));
say DateTime.new(:2000year, :timezone(360000));
say DateTime.new(:2000year, :timezone(-30)).raku;
say DateTime.new(:2000year, :second(1/3));
say DateTime.new(:2000year, :second(0.0000005));
say DateTime.new(:2000year, :second(0.0000004));
say DateTime.new(:2000year, :second(5e0));
```
```output
2000-01-01T00:00:00+01:01
2000-01-01T00:00:00-00:00
2000-01-01T00:00:00+100:00
DateTime.new(2000,1,1,0,0,0,:timezone(-30))
2000-01-01T00:00:00.333333Z
2000-01-01T00:00:00.000001Z
2000-01-01T00:00:00.000000Z
2000-01-01T00:00:05Z
```

## Rounding the second can print one that does not exist, or die
tags: bug

The six decimals are rounded half up, and in Rakudo 2026.08 two ranges of
seconds do not round like the rest. A second just below 60 prints as `:60.000000`,
a leap second that is not there, and one that `DateTime.new` refuses at that
time ([a second of
60](#ch:dates:a-second-of-60-is-accepted-only-at-2359-utc-on-a-leap-second-day)).
A second from 0.9999995 up to 1 makes `.Str` die on a value the constructor
accepted, with a message about a negative repeat count.

```raku
say DateTime.new(:2000year, :second(59.9999994));
say DateTime.new(:2000year, :second(59.9999999));
say DateTime.new(:2000year, :second(10.9999996));
my $odd = DateTime.new(:2000year, :second(0.9999999));
try say $odd;
say $!.message;
```
```output
2000-01-01T00:00:59.999999Z
2000-01-01T00:00:60.000000Z
2000-01-01T00:00:11.000000Z
Repeat count (-1) cannot be negative
```

Carried as `10.9999996` is carried to `11.000000` on the third line, the
two would read `00:01:00.000000` and `00:00:01.000000`.

## A DateTime's identity is its printed text
tags: bug

A DateTime is a value type, and its identity, which `===`, `unique` and sets
use, is made from its `.Str`. The documentation of `===` says that for value
types it behaves like `eqv`. In Rakudo 2026.08 the two part ways: two
DateTimes for the same moment in different zones are `==` and `eqv` but not
`===`. The text is also the formatted one, so DateTimes whose formatter
prints the same text are `===` whatever moments they hold, although they are
not `==`, and `unique` keeps one of them. A Date takes its identity from
its day instead, whatever its formatter
([above](#ch:dates:a-dates-identity-is-its-day-a-formatter-does-not-count-a-subclass-does)).

```raku
my $utc = DateTime.new("1971-10-28T10:45:00Z");
my $cest = DateTime.new("1971-10-28T12:45:00+02:00");
say $utc == $cest, " ", $utc eqv $cest, " ", $utc === $cest;
say ($utc, $cest).unique.elems;
my $f = { "a moment" };
my $a = DateTime.new(:2000year, :formatter($f));
my $b = DateTime.new(:2001year, :formatter($f));
say $a === $b, " ", $a == $b;
say ($a, $b).unique.elems;
```
```output
True True False
2
True False
1
```

## DateTimes compare by moment, except with `cmp`, `leg` and `sort`
tags: bug

`==`, `<`, `<=>`, `before`, `after` and smartmatching compare moments, so the
zone does not matter. `cmp` and `leg` compare the texts instead, and so do
`sort`, `min` and `max`, which use `cmp` unless told otherwise. The
documentation says that `cmp` on two DateTimes compares the equivalent
instants. In Rakudo 2026.08 it does not: below, three moments in three
zones sort in the reverse of their order in time, and `min` picks the
latest.

```raku
my @times = DateTime.new("2020-01-01T08:00:00+05:00"),
            DateTime.new("2020-01-01T06:00:00Z"),
            DateTime.new("2020-01-01T05:00:00-02:00");
say @times.map(*.utc.hh-mm-ss);
say @times.sort.map(*.utc.hh-mm-ss);
say @times.sort(* <=> *).map(*.utc.hh-mm-ss);
say @times.min.utc.hh-mm-ss;
say @times.min(*.Instant).utc.hh-mm-ss;
```
```output
(03:00:00 06:00:00 07:00:00)
(07:00:00 06:00:00 03:00:00)
(03:00:00 06:00:00 07:00:00)
07:00:00
03:00:00
```

Give `sort` the comparison `* <=> *`, or give `min` and `max` the key
`*.Instant`.

## `in-timezone` moves the clock and keeps the moment

`in-timezone` gives the same moment in another zone: the fields shift,
across days and months if need be, and the result is `==` the original. The
offset goes through `Int()`, so a numeric string or a fraction is accepted.
`utc` is `in-timezone(0)`, and `local` is `in-timezone($*TZ)`, the process's
own offset. Asking for the zone a DateTime already has gives it back
unchanged.

```raku
my $t = DateTime.new("2005-02-04T15:25:00+02:00");
say $t.in-timezone(4 * 3600);
say $t.in-timezone(-3600);
say $t.utc;
say $t.in-timezone(-13 * 60);
say $t.in-timezone("7200");
say $t.in-timezone(7200.9);
say $t.in-timezone(3600) == $t;
say $t.in-timezone(7200) === $t;
```
```output
2005-02-04T17:25:00+04:00
2005-02-04T12:25:00-01:00
2005-02-04T13:25:00Z
2005-02-04T13:12:00-00:13
2005-02-04T15:25:00+02:00
2005-02-04T15:25:00+02:00
True
True
```

## `clone(:timezone)` keeps the clock and moves the moment
tags: trap

`clone` with `:timezone` does not convert. It keeps every field as it was
and changes only the label, which makes a different moment, as far from the
original as the two offsets are apart. `in-timezone` is the conversion.

```raku
my $t = DateTime.new("2015-12-24T12:23:00+02:00");
my $moved = $t.in-timezone(0);
my $relabelled = $t.clone(:timezone(0));
say $moved;
say $relabelled;
say $moved == $t, " ", $relabelled == $t;
say $relabelled - $t;
```
```output
2015-12-24T10:23:00Z
2015-12-24T12:23:00Z
True False
7200
```

## `.local` follows `my $*TZ`, but `DateTime.now` does not
tags: quirk

`$*TZ` holds the process's offset from UTC in seconds, as an Int. Like any
dynamic variable it can be redeclared for a block with `my $*TZ`, and `local`
then uses the new value. `DateTime.now`, whose zone is the local one by
default, does not see the redeclaration: it follows only an assignment to
the process's own `$*TZ`. The comparison inside the block below is False
because the local zone of the machine is UTC.

```raku
say $*TZ.^name;
my $t = DateTime.new("2015-12-24T12:23:00+02:00");
{
    my $*TZ = -3600;
    say $t.local;
    say DateTime.now.timezone == $*TZ;
}
$*TZ = -3600;
say DateTime.now.timezone;
say $t.local;
```
```output
Int
2015-12-24T09:23:00-01:00
False
-3600
2015-12-24T09:23:00-01:00
```

## `DateTime.now` is local with a Num second; `now.DateTime` is UTC with a Rat
tags: quirk

Two roads lead to the current time, and they arrive at different places.
`DateTime.now` is in the local zone, or in the one given with `:timezone`,
and its second is a Num from the system clock. `now.DateTime`, like
`DateTime.new(now)`, is in UTC, with a Rat second from the Instant.
`Date.today` is the local date, so near midnight it can differ from
`now.Date`, which is the date in UTC. Both `DateTime.now` and `Date.today`
take a formatter.

```raku
say DateTime.now.^name;
say DateTime.now.second.^name;
say now.DateTime.second.^name;
say now.DateTime.timezone;
say DateTime.now(:timezone(3600)).timezone;
say Date.today.^name;
say DateTime.now(:formatter({ "tick" }));
say Date.today(:formatter({ "today" }));
```
```output
DateTime
Num
Rat
0
3600
Date
tick
today
```

## A leap second and the second after it share one POSIX time

In the POSIX count, 2016-12-31T23:59:60Z and 2017-01-01T00:00:00Z are both
1483228800. Their Instants are one second apart, and `to-posix` tells them
apart by its flag. A DateTime built from the POSIX number can never land on
the leap second; one built from the Instant does.

```raku
my $leap = DateTime.new("2016-12-31T23:59:60Z");
my $next = DateTime.new("2017-01-01T00:00:00Z");
say $leap.posix, " ", $next.posix;
say $leap.Instant.tai, " ", $next.Instant.tai;
say $leap.Instant.to-posix.raku;
say $leap < $next;
say DateTime.new($leap.posix);
say DateTime.new($leap.Instant);
```
```output
1483228800 1483228800
1483228836 1483228837
(1483228800.0, Bool::True)
True
2017-01-01T00:00:00Z
2016-12-31T23:59:60Z
```

## The Date of a leap-second Instant is the next day
tags: quirk

A DateTime on a leap second knows its day: its `.Date` is the day that the
leap second ends. Its Instant does not. `.Date` of an Instant, and
`Date.new` of one, work the day out from the POSIX time, which the leap
second shares with the following midnight, and so give the next day. The
DateTime's other methods agree with it: `hh-mm-ss` shows 60, and the day has
86401 seconds.

```raku
my $leap = DateTime.new("2016-12-31T23:59:60Z");
say $leap.hh-mm-ss, " ", $leap.whole-second;
say $leap.day-fraction.raku;
say $leap.raku;
say $leap.Date;
say $leap.Instant.Date;
say Date.new($leap.Instant);
say Date.new(Instant.from-posix(1483228799));
```
```output
23:59:60 60
<86400/86401>
DateTime.new(2016,12,31,23,59,60)
2016-12-31
2017-01-01
2017-01-01
2016-12-31
```

## A leap second keeps its `:60` in every zone

Converting a leap second to another zone moves the hours and minutes and
leaves the second at 60: an hour east of UTC, the leap second of 2016 is
00:59:60 on New Year's Day. Converting back finds the same moment.

```raku
my $leap = DateTime.new("2016-12-31T23:59:60Z");
say $leap.in-timezone(3600);
say $leap.in-timezone(-1800);
say $leap.in-timezone(3600).utc;
say $leap.in-timezone(3600) == $leap;
```
```output
2017-01-01T00:59:60+01:00
2016-12-31T23:29:60-00:30
2016-12-31T23:59:60Z
True
```

## `later` on a DateTime carries into days and keeps the zone

On a DateTime, `later` and `earlier` also take `second`, `minute` and
`hour`, and each carries into the larger fields. Months and years clip the
day as on a Date and keep the time of day. The zone and the formatter stay.
A move by seconds may be fractional, and always leaves a Rat second.

```raku
my $d = DateTime.new("2013-12-23T12:34:36Z");
say $d.later(:minutes(1500));
say $d.earlier(:13hours);
say $d.later(:1month);
say $d.later(:second(0.7));
say $d.later(:1second).second.^name;
say DateTime.new("2014-01-31T12:00:00+05:00").later(:1month);
```
```output
2013-12-24T13:34:36Z
2013-12-22T23:34:36Z
2014-01-23T12:34:36Z
2013-12-23T12:34:36.700000Z
Rat
2014-02-28T12:00:00+05:00
```

## Moving by seconds counts leap seconds; moving by days clips `:60` to `:59`

A move by seconds is made on the atomic scale, so one second after 23:59:59
on a leap-second day is 23:59:60, and one second before the next midnight is
the leap second again. A move by any larger unit keeps the wall clock, and a
`:60` survives only when it lands on 23:59 of another leap-second day;
anywhere else it becomes 59.

```raku
say DateTime.new("2016-12-31T23:59:59Z").later(:1second);
say DateTime.new("2016-12-31T23:59:60Z").later(:1second);
say DateTime.new("2017-01-01T00:00:00Z").earlier(:1second);
say DateTime.new("2016-12-31T23:59:60Z").later(:1day);
say DateTime.new("2016-12-31T23:59:60Z").later(:1minute);
say DateTime.new("1972-12-31T23:59:60Z").later(:1year);
say DateTime.new("2016-12-31T23:59:60.5Z").later(:1day);
```
```output
2016-12-31T23:59:60Z
2017-01-01T00:00:00Z
2016-12-31T23:59:60Z
2017-01-01T23:59:59Z
2017-01-01T00:00:59Z
1973-12-31T23:59:60Z
2017-01-01T23:59:59.500000Z
```

## DateTime minus DateTime is a Duration that counts leap seconds

The difference of two DateTimes is the atomic time between them, so a day
that ended with a leap second lasted 86401 seconds, and the 35 years from
1973 to 2008 hold 21 extra seconds. The zones do not matter, and fractions
are kept. A DateTime plus or minus a Duration is a DateTime in the same zone,
and lands on a leap second where one falls.

```raku
say DateTime.new("2017-01-01T00:00:00Z") - DateTime.new("2016-12-31T23:59:59Z");
say (DateTime.new("1997-07-01T00:00:00Z") - DateTime.new("1997-06-30T00:00:00Z")).raku;
say (DateTime.new("2008-01-01T00:00:00Z") - DateTime.new("1973-01-01T00:00:00Z")).raku;
say (DateTime.new("2013-12-23T12:34:36.25Z") - DateTime.new("2013-12-23T12:34:36Z")).raku;
say (DateTime.new(0, :timezone(3600)) - DateTime.new(0)).raku;
say DateTime.new("2016-12-31T23:59:59Z") + Duration.new(1);
say DateTime.new(0, :timezone(3600)) + Duration.new(1);
```
```output
2
Duration.new(86401.0)
Duration.new(1104451221.0)
Duration.new(0.25)
Duration.new(0.0)
2016-12-31T23:59:60Z
1970-01-01T01:00:01+01:00
```

## A DateTime plus a plain number is an Instant, and a Duration drops the formatter
tags: quirk

A DateTime plus a Duration is a DateTime, but its formatter is gone. With a
plain number there is no DateTime candidate at all: the DateTime is used as
its Instant, and the result is an Instant. Two DateTimes cannot be added.
Mixing in a Date goes further astray, since the Date takes part as its
daycount: subtracting one moves the Instant back by that many seconds, and a
Date minus a DateTime is the daycount minus the TAI seconds, a Num.

```raku
my $dt = DateTime.new(0, :formatter({ "F" }));
say $dt + Duration.new(1);
say ($dt + 1).raku;
say ($dt - 1.5).^name;
say ($dt * 2).^name;
try $dt + $dt;
say $!.^name;
say ($dt - Date.new("1970-01-02")).raku;
say (Date.new("1970-01-02") - $dt).raku;
```
```output
1970-01-01T00:00:01Z
Instant.from-posix(1.0)
Instant
Num
X::AdHoc
Instant.from-posix(-40588.0)
40578e0
```

## Instants and Durations are Cool; Dates and DateTimes are not

`Date` and `DateTime` do the role `Dateish` and inherit straight from `Any`.
`Instant` and `Duration` are Cool and Real numbers, and not Dateish. The
difference shows in the methods on offer: a Duration has `sqrt` and an
Instant has `chars`, while a Date has neither and must be turned into a
string first.

```raku
say Date ~~ Dateish, " ", DateTime ~~ Dateish, " ", Instant ~~ Dateish;
say Date ~~ Cool, " ", DateTime ~~ Cool;
say Instant ~~ Cool, " ", Duration ~~ Real;
say Instant.^mro.map(*.^name);
say Duration.new(90).sqrt;
try Date.new("2015-12-24").chars;
say $!.^name;
say Date.new("2015-12-24").Str.chars;
```
```output
True True False
False False
True True
(Instant Cool Any Mu)
9.486832980505138
X::Method::NotFound
10
```

## The fields are read-only, and the type objects refuse them

A Date or a DateTime cannot change: its fields are read-only, and every
method that seems to change one, `later`, `clone`, `in-timezone` or
`truncated-to`, returns a new object. The type objects print as `(Date)`
and `(DateTime)`, convert into each other's type objects, and refuse to
answer for a field. There is no `DateTime.today` and no `Date.now`, and a
Date has none of the time-of-day methods: no `hour`, no `in-timezone`, no
`posix` and no `Instant`.

```raku
my $d = Date.new("2015-12-24");
try $d.year = 2000;
say $!.^name;
say Date.gist, " ", Date.raku;
say Date.DateTime.^name;
try Date.year;
say $!.message;
try DateTime.today;
say $!.^name;
try $d.hour;
say $!.^name;
```
```output
X::Assignment::RO
(Date) Date
DateTime
Cannot look up attributes in a Date type object. Did you forget a '.new'?
X::Method::NotFound
X::Method::NotFound
```
