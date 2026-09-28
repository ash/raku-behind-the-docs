---
title: Files and Paths
part: Time and the outside world
summary: An IO::Path is text until something touches the disk; from there each file operation either fails or throws by its own rule, and handles translate newlines, share one position and keep their own separators.
---

An `IO::Path` is a name for a file, not the file. Most of its methods work
on the text of the name and never look at the disk: splitting, joining,
climbing to the parent, changing the extension. The disk is consulted by the
file tests, by the operations that create, copy and remove, and by reading
and writing.

Those operations report trouble in one of two ways. Most return a `Failure`,
an undefined value that throws only when it is used without being tested
(see [Exceptions and Failures](#ch:exceptions)). A few throw at once, and
which ones do is not always what the documentation says. Reading has rules
of its own: line endings are translated as the bytes are decoded, a handle
has one position shared by every kind of read, and a handle's separators
decide what a line is.

Every example that touches the disk or reads standard input is marked "run
it locally", because the editor in the page has no file system. Each one
creates its files in the current directory and deletes them before it ends,
so an empty directory is the place to try it. The examples never print a
full path, which would differ from machine to machine: they print relative
paths, base names or comparisons instead.

## `.IO` keeps the path exactly as written

`.IO` on a string, or on any other `Cool` value, makes an `IO::Path`. It
checks nothing and normalises nothing: the path keeps the text it was given,
doubled slashes and `./` included, and `.Str` gives that text back. The
gist puts it in quotes followed by `.IO`. `.raku` adds the rules of the
platform, `:SPEC`, and the current directory at the moment the path was made,
`:CWD`.

```raku
my $p = "docs//./notes.txt".IO;
say $p.^name;
say $p.Str;
say $p.gist;
say 42.IO.Str.raku;
say IO::Path.new(basename => "notes.txt", dirname => "/docs").Str;
say IO::Path.new("a/b.txt", :CWD("/home/ada")).raku;
```
```output
IO::Path
docs//./notes.txt
"docs//./notes.txt".IO
"42"
/docs/notes.txt
IO::Path.new("a/b.txt", :SPEC(IO::Spec::Unix), :CWD("/home/ada"))
```

The named form of `IO::Path.new` joins a `dirname` and a `basename` with one
separator. The `:CWD` a path remembers matters later, in
[A relative path remembers the directory it was made in](#ch:files:a-relative-path-remembers-the-directory-it-was-made-in).

## An empty path throws at once
tags: trap

An empty string is not a path. `.IO` on `""` throws `X::AdHoc`, and it
throws there and then: it does not return a Failure, nor a path that happens
not to exist. A NUL character in the text throws `X::IO::Null`, and `Any`
has no `.IO` method at all.

```raku
say (try "a\0b".IO) // $!.^name;
say (try Any.IO) // $!.^name;
my $p = "".IO;
say "not reached";
```
```output
X::IO::Null
X::Method::NotFound
```
```stderr
Must specify a non-empty string as a path
  in block <unit> at example.raku line 3

```

A program that builds a path from an optional argument, as in
`(@*ARGS[0] // "").IO.e`, therefore dies on the missing argument instead of
reporting a file that does not exist.

## `dirname` and `basename` split the text at the last slash

A path is split into its directory and its last part without looking at the
disk. A trailing slash is removed first, so `/usr/lib/` has the basename
`lib`. The root is its own dirname and basename, a name without a slash has
the dirname `.`, and `.` and `..` are their own basenames.

```raku
for </usr/lib/ bar.txt / . .. a/b/c.d.e> -> $p {
    say "$p: dirname {$p.IO.dirname}, basename {$p.IO.basename}";
}
```
```output
/usr/lib/: dirname /usr, basename lib
bar.txt: dirname ., basename bar.txt
/: dirname /, basename /
.: dirname ., basename .
..: dirname ., basename ..
a/b/c.d.e: dirname a/b, basename c.d.e
```

`.parts` returns the three parts together, the volume (always empty on
Unix), the dirname and the basename, as an `IO::Path::Parts`. It answers a
subscript by name, like a hash, and a subscript by position with a Pair.
Iterating it gives the three Pairs in order:

```raku
my $parts = "/a/b.txt".IO.parts;
say $parts.^name;
say $parts<dirname>, " ", $parts<basename>;
say $parts[2].raku;
.raku.say for "/a/b.txt".IO.parts;
say "/a/b.txt".IO.volume.raku;
```
```output
IO::Path::Parts
/a b.txt
:basename("b.txt")
:volume("")
:dirname("/a")
:basename("b.txt")
""
```

## `.cleanup` tidies the text and keeps every `..`

`.cleanup` returns a new path without doubled slashes, `/./`, a leading `./`
or a trailing slash. It works on the text alone, and the only `..` it
removes is one directly under the root, where `..` is the root itself. Any
other `..` stays: when `a` is a symbolic link, `a/..` is not the current
directory, and only the disk can tell.

```raku
put "a//b/./c/".IO.cleanup;
put "./a".IO.cleanup;
put "/../a".IO.cleanup;
put "a/../b".IO.cleanup;
put "../a".IO.cleanup;
```
```output
a/b/c
a
/a
a/../b
../a
```

## `.absolute` is canonical: `./a` and `a/` are the same path

For a relative path, `.absolute` prepends the directory the path was made
in, and it cleans the result up as `.cleanup` does. Two spellings of one path therefore have
the same absolute form, while `x/../a` keeps its `..` and stays different
from `a`. The result is a `Str`. With an argument, `.absolute` resolves
against that directory instead of the current one.

```raku local
say "a".IO.absolute eq $*CWD ~ "/a";
say "./a".IO.absolute eq "a".IO.absolute;
say "a/".IO.absolute eq "a".IO.absolute;
say "x/../a".IO.absolute eq "a".IO.absolute;
say "/a/./b//".IO.absolute;
say "/../etc".IO.absolute;
say "../a".IO.absolute("/x/y");
```
```output
True
True
True
False
/a/b
/etc
/x/y/../a
```

`.relative` goes the other way. It gives the path relative to the current
directory, or to the directory it is given, climbing with `..` as far as
needed, and `.` for the directory itself:

```raku local
say "/a/b".IO.relative("/a");
say "/a/b".IO.relative("/x/y");
say "/a/b".IO.relative("/a/b");
say "./sub//f".IO.relative;
say "sub/f".IO.absolute.IO.relative;
```
```output
b
../../a/b
.
sub/f
sub/f
```

## `.resolve` removes `..` only where the directory exists

`.resolve` asks the file system. It follows symbolic links and removes an
`x/..` where `x` is a real directory. Where `x` does not exist, `x/..` stays
and the result is still a path. With `:completely`, a part of the path that
cannot be resolved makes it return a Failure of type `X::IO::Resolve`
instead; only the last part may be missing. The example prints each result
relative to the current directory.

```raku local
say "x/../a".IO.resolve.relative;
mkdir "x";
say "x/../a".IO.resolve.relative;
say "x/./../a/".IO.resolve.relative;
rmdir "x";
my $r = "x/../a".IO.resolve(:completely);
say $r.defined, " ", $r.exception.^name;
```
```output
x/../a
a
a
False X::IO::Resolve
```

## A relative path remembers the directory it was made in
tags: trap

An `IO::Path` keeps the value `$*CWD` had when the path was created, and
every file operation on it resolves the relative text against that
directory, even after `$*CWD` has changed. Its string remembers nothing:
turned back into text, it names a file relative to wherever the program is
now.

```raku local
mkdir "sub";
spurt "here.txt", "found";
my $p = "here.txt".IO;
indir "sub", {
    say $p.slurp;
    say "here.txt".IO.e;
    say (try slurp ~$p) // "the string: " ~ $!.^name;
};
unlink "here.txt";
rmdir "sub";
```
```output
found
False
the string: X::AdHoc
```

Inside `indir` the path object still finds `here.txt` one level up, while a
new `"here.txt".IO` and the plain string look in `sub`. A path passed to
another program through `run` is passed as its string, and the program looks
in `$*CWD`, not where the path was made.

## `.parent` is textual, so `a/..` has the parent `a`
tags: trap

`.parent` removes the last part of the text. It never looks at the disk, and
it drops a final `.` or `..` like any other name. Only a path made of
nothing but `.` and `..` grows instead: the parent of `.` is `..`, and the
parent of `..` is `../..`. A bare name's parent is `.`, and the root is its
own parent. `.parent(n)` climbs n times, and a negative count throws
`X::OutOfRange`.

```raku
put "/usr/lib".IO.parent;
put "/".IO.parent;
put "notes.txt".IO.parent;
put ".".IO.parent;
put "..".IO.parent;
put "a/..".IO.parent;
put "/a/b/c".IO.parent(2);
say (try "/a".IO.parent(-1)) // $!.^name;
```
```output
/usr
/
.
..
../..
a
/a
X::OutOfRange
```

`a/..` is the current directory, whose parent is `..`, but `.parent` drops
the `..` and answers `a`. When a path may contain `..`, `.resolve` it first.

## `.child`, `.add` and `.sibling` join text with one slash

`.add` appends one or more parts with a single separator, whatever slashes
are already there. A part that starts with `/` is still appended, not taken
as an absolute path. `.child` does the same with one part, and it does not
check it either: a `..` climbs out of the directory. `.sibling` replaces the
basename. A path that is just `.` disappears from the result.

```raku
put "a".IO.child("x");
put "a/".IO.child("x");
put "a".IO.add("x", "y");
put "a".IO.add("/x");
put "a".IO.child("../x");
put "a/b".IO.sibling("z");
put ".".IO.child("x");
```
```output
a/x
a/x
a/x/y
a/x
a/../x
a/z
x
```

## `.extension` counts dot-parts from the right

The extension is the text after the last dot of the basename. `:parts(n)`
asks for the last n dot-separated parts, and a Range for as many as there
are within it. When there are fewer parts than asked for, the answer is the
empty string. A dotfile such as `.bashrc` has everything after its dot as
the extension, and a dot in a directory name does not count.

```raku
say "a.tar.gz".IO.extension;
say "a.tar.gz".IO.extension(:parts(2));
say "a.tar.gz".IO.extension(:parts(1..5));
say "a.tar.gz".IO.extension(:parts(3)).raku;
say "README".IO.extension.raku;
say ".bashrc".IO.extension;
say "a.".IO.extension.raku;
say "v1.2/notes".IO.extension.raku;
```
```output
gz
tar.gz
tar.gz
""
""
bashrc
""
""
```

## `.extension` with a value makes a path with a new extension

Given a string, `.extension` returns a new path with the extension replaced
and the directory kept. An empty string removes the extension together with
its dot. `:parts` says how many parts to replace, so `:parts(0)` appends;
`:joiner` puts something other than a dot in front of the new extension.

```raku
put "d/a.tar.gz".IO.extension("txt");
put "a.tar.gz".IO.extension("zip", :parts(2));
put "a.tar.gz".IO.extension("");
put "a.tar.gz".IO.extension("bak", :parts(0));
put "a.tar.gz".IO.extension("bak", :joiner("~"));
put ".bashrc".IO.extension("old");
```
```output
d/a.tar.txt
a.zip
a.tar
a.tar.gz.bak
a.tar~bak
.old
```

## An explicit `:parts(1)` does not add a missing extension
tags: trap

When the basename has fewer dot-parts than `:parts` asks for, a replacement
changes nothing. The documentation gives 1 as the default number of parts,
but without `:parts` the replacement behaves as if it were `0..1`: a name
without an extension gets one appended. Writing `:parts(1)` out leaves such a
name as it was.

```raku
put "README".IO.extension("md");
put "README".IO.extension("md", :parts(1));
put "README".IO.extension("md", :parts(0..1));
put "a.tar.gz".IO.extension("x", :parts(3));
```
```output
README.md
README
README.md
a.tar.gz
```

## `.succ` on a path increments the text before its first dot
tags: trap

`.succ` and `.pred` on a path apply the string versions to the whole path
and make a path of the result. String `succ` leaves everything from the
first dot onwards alone, taking it for an extension (see
[Strings](#ch:strings:succ-increments-the-last-run-of-letters-or-digits)),
so `file1.txt` becomes `file2.txt`. In a path, the first dot may belong to a
directory, and then the directory's name is incremented instead of the
file's. `.Numeric` numifies the basename.

```raku
put "file1.txt".IO.succ;
put "file1.txt".IO.pred;
put "img/photo9.jpg".IO.succ;
put "v1.2/notes".IO.succ;
say "data/42".IO + 1;
```
```output
file2.txt
file0.txt
img/photp0.jpg
v2.2/notes
43
```

`photo9` carries into `photp0`, as the string would.

## A smartmatch with a path compares paths; with a string, text
tags: trap

With an `IO::Path` on the right, `~~` compares the two canonical absolute
paths, so different spellings of one path match; a string on the left is
made into a path first. With a string on the right, the smartmatch is the
string's: the path on the left is compared as text, and `./a` does not
match `a`. A `when` with a string literal compares text in the same way.

```raku
say "./a".IO ~~ "a".IO;
say "a/".IO ~~ "a".IO;
say "/../etc".IO ~~ "/etc".IO;
say "x/../a".IO ~~ "a".IO;
say "./a".IO ~~ "a";
say "./a" ~~ "a".IO;
```
```output
True
True
True
False
False
True
```

## Two paths with the same text are two values
tags: trap

`eqv` compares the text and the directory each path was made in, so `./a`
and `a` differ. `===` compares identity, and every `.IO` makes a new object:
two paths are never `===`, however equal their text. `unique` and `Set`
compare by identity, so they keep both copies of one path. A `:with` or
`:as` function makes `unique` compare values again.

```raku
say "a".IO eqv "a".IO;
say "./a".IO eqv "a".IO;
say "a".IO === "a".IO;
say ("a".IO, "a".IO).unique.elems;
say set("a".IO, "a".IO).elems;
say ("a".IO, "./a".IO).unique(with => &[~~]).elems;
```
```output
True
False
False
2
2
1
```

## `.e` is a Bool; the other tests of a missing file fail

`.e` answers with a plain `True` or `False`. Every other test, `.f`, `.d`,
`.s`, `.z`, `.l`, `.r`, `.w`, `.x`, `.rw` and `.rwx`, and every other query
about the file, `.modified`, `.accessed`, `.changed`, `.mode`, `.user`,
`.group` and `.inode`, returns a Failure for a path that does not exist. Its
exception is `X::IO::DoesNotExist`: `.trying` names the test, and `.path`
holds the absolute path.

```raku local
my $m = "missing.txt".IO;
say $m.e;
my $d = $m.d;
say $d.^name, " ", $d.so;
say $d.exception.^name, " ", $d.exception.trying;
say $d.exception.path.IO.basename;
say $m.s // 0;
say $m.f ?? "a file" !! "not a file";
```
```output
False
Failure False
X::IO::DoesNotExist d
missing.txt
0
not a file
```

A Failure is false and undefined, so `if $path.f` and `$path.s // 0` do the
expected thing. Only code that uses the answer without testing it, such as
`$path.s + 1`, meets the exception.

## `.s` is a size, `.mode` an IntStr, and the times are Instants

On an existing file the tests answer Bools, `.s` the size in bytes, and `.z`
whether that size is zero. `.mode` is an `IntStr`: a number whose string is
four octal digits, such as `0644`. `.modified`, `.accessed` and `.changed`
are `Instant`s (see [Dates and Times](#ch:dates)).

```raku local
spurt "data.txt", "abc";
my $f = "data.txt".IO;
say $f.f, " ", $f.d, " ", $f.s, " ", $f.z;
say $f.r, " ", $f.w, " ", $f.x;
say $f.mode.^name, " ", $f.mode.Str.chars;
say $f.modified.^name, " ", $f.modified <= now;
unlink "data.txt";
```
```output
True False 3 False
True True False
IntStr 4
Instant True
```

## The standard handles' paths are IO::Special values

`$*IN`, `$*OUT` and `$*ERR` are ordinary `IO::Handle`s, but their `.path` is
an `IO::Special` named `<STDIN>`, `<STDOUT>` or `<STDERR>`. It exists, is
neither a file nor a directory, has size 0, and is readable for standard
input and writable for the other two. It has no mode, and its timestamps
are the `Instant` type object. Two `IO::Special`s with the same name are
`===`.

```raku local
my $in = $*IN.path;
say $in.^name, " ", $in.Str;
say $in.e, " ", $in.f, " ", $in.d, " ", $in.s;
say $in.r, " ", $in.w, " ", $*OUT.path.w;
say $in.mode.raku, " ", $in.modified.raku;
say $in === IO::Special.new("<STDIN>");
say $*OUT.gist;
```
```output
IO::Special <STDIN>
True False False 0
True False True
Nil Instant
True
IO::Handle<IO::Special.new("<STDOUT>")>(opened)
```

The handles start opened, in UTF-8, with chomping on, `\n` and `\r\n` as the
line separators, `\n` as the line ending they write, and the native
descriptors 0, 1 and 2. `.t` says whether a handle is a terminal:

```raku local
say $*IN.opened, " ", $*IN.encoding, " ", $*IN.chomp;
say $*IN.nl-in.raku;
say $*OUT.nl-out.raku;
say $*OUT.t;
say $*IN.native-descriptor, $*OUT.native-descriptor, $*ERR.native-descriptor;
```
```output
True utf8 True
$["\n", "\r\n"]
"\n"
False
012
```

## `mkdir` creates the parents and passes over an existing directory

`mkdir` returns the path, creating every missing directory on the way. On a
directory that already exists it does nothing and succeeds, and the mode it
is given is ignored. Where a file is in the way, it returns a Failure of
type `X::IO::Mkdir`, whose `.path` names the directory it could not make.

```raku local
say "d/x/y".IO.mkdir.^name;
say "d/x/y".IO.d;
my $mode = "d".IO.mode;
say "d".IO.mkdir(0o700) ?? "no-op" !! "failed";
say "d".IO.mode eq $mode;
spurt "f", "";
my $r = "f".IO.mkdir;
say $r.so, " ", $r.exception.^name, " ", $r.exception.path.IO.basename;
unlink "f";
rmdir "d/x/y", "d/x", "d";
```
```output
IO::Path
True
no-op
True
False X::IO::Mkdir f
```

## `unlink` of a missing file is True
tags: trap

`unlink` succeeds when the file is gone afterwards, so a path that never
existed answers `True`. A directory cannot be unlinked: the Failure is
`X::IO::Unlink`. `rmdir` is stricter. It fails with `X::IO::Rmdir` on a
directory that is not empty, on a path that does not exist, and on a file.

```raku local
say "never-was.txt".IO.unlink;
mkdir "d";
my $u = "d".IO.unlink;
say $u.so, " ", $u.exception.^name;
spurt "d/f", "x";
my $r = "d".IO.rmdir;
say $r.so, " ", $r.exception.^name;
unlink "d/f";
say "d".IO.rmdir;
my $again = "d".IO.rmdir;
say $again.so, " ", $again.exception.^name;
```
```output
True
False X::IO::Unlink
False X::IO::Rmdir
True
False X::IO::Rmdir
```

## The sub forms of `unlink`, `rmdir` and `chmod` return what worked

As subs, `unlink`, `rmdir` and `chmod` take a list of names and return an
Array of the names they succeeded on; a failure only leaves its name out.
`unlink` lists `never-was`, since removing a missing file succeeds. `rmdir`
leaves out the file and the missing name, `chmod` the missing name. With no
names at all, `unlink` and `rmdir` throw `X::NoZeroArgMeaning`.

```raku local
spurt $_, "" for <a b f>;
mkdir "d";
say unlink("a", "b", "never-was").raku;
say rmdir("f", "d", "never-was").raku;
say chmod(0o600, "f", "never-was").raku;
say "f".IO.mode;
say (try unlink()) // $!.^name;
unlink "f";
```
```output
["a", "b", "never-was"]
["d"]
["f"]
0600
X::NoZeroArgMeaning
```

## `copy`, `rename` and `move` give the reason in `.os-error`

The three methods return `True`, or a Failure whose exception, `X::IO::Copy`,
`X::IO::Rename` or `X::IO::Move`, carries the reason in `.os-error`. A copy
onto the source itself is refused, and so is overwriting with `:createonly`.
When the source is missing, the target is not created.

```raku local
spurt "src", "text";
say "src".IO.copy("dst");
say "dst".IO.slurp;
for "src".IO.copy("src"),
    "src".IO.copy("dst", :createonly),
    "missing".IO.copy("new") -> $r {
    say $r.so, " ", $r.exception.^name, ": ", $r.exception.os-error;
}
say "new".IO.e;
unlink "src", "dst";
```
```output
True
text
False X::IO::Copy: source and target are the same
False X::IO::Copy: :createonly specified and destination exists
False X::IO::Copy: Failed to copy file: no such file or directory
False
```

`rename` overwrites an existing target unless it is given `:createonly`.
`move` is a copy followed by an unlink of the source. Moving a file onto
itself fails and leaves the file as it was:

```raku local
spurt "a", "A";
spurt "b", "B";
say "a".IO.rename("c");
say "a".IO.e, " ", "c".IO.e;
my $r = "c".IO.rename("b", :createonly);
say $r.so, " ", $r.exception.os-error;
say "c".IO.move("m");
my $self = "m".IO.move("m");
say $self.so, " ", $self.exception.^name, ": ", $self.exception.os-error;
say "m".IO.slurp;
say "b".IO.rename("m");
say "m".IO.slurp;
unlink "m";
```
```output
True
False True
False :createonly specified and destination exists
True
False X::IO::Move: source and target are the same
A
True
B
```

## A second `symlink` fails; a dangling one does not

`symlink` and `link` return `True`, or a Failure of type `X::IO::Symlink` or
`X::IO::Link`. Both fail when the new name is taken. A symbolic link to a
target that does not exist is made all the same: it is a dangling link,
which answers `.l` but not `.e`. A hard link needs its target.

```raku local
spurt "target", "contents";
say "target".IO.symlink("link");
say "link".IO.l, " ", "link".IO.f, " ", "link".IO.slurp;
my $again = "target".IO.symlink("link");
say $again.so, " ", $again.exception.^name;
say "gone".IO.symlink("dangling");
say "dangling".IO.l, " ", "dangling".IO.e;
say "target".IO.link("hard");
say "hard".IO.l, " ", "hard".IO.slurp;
my $l = "gone".IO.link("hard2");
say $l.so, " ", $l.exception.^name;
unlink "target", "link", "dangling", "hard";
```
```output
True
True True contents
False X::IO::Symlink
True
True False
True
False contents
False X::IO::Link
```

A symbolic link reads through to its target, so `.f` and `.slurp` answer
for the target; a hard link is the file itself and is not `.l`.

## `symlink` stores an absolute target unless told otherwise

`$target.symlink($name)` makes the target absolute before it stores it, so
the link still points at the same file when it is moved elsewhere.
`:!absolute` stores the target as written, relative to the link's own
directory. `.readlink` returns the stored target, and `.resolve` follows the
link to the file:

```raku local
spurt "target", "x";
"target".IO.symlink("abs");
"target".IO.symlink("rel", :!absolute);
say "rel".IO.readlink.Str;
say "abs".IO.readlink.is-absolute, " ", "abs".IO.readlink.basename;
say "abs".IO.resolve.relative, " ", "rel".IO.resolve.relative;
say "abs".IO.basename, " ", "abs".IO.slurp;
unlink "target", "abs", "rel";
```
```output
target
True target
target target
abs x
```

## `dir` lists paths that start with the directory as written

`dir` returns a Seq of `IO::Path`s. Each entry is the directory as it was
written joined to the entry's name, so `./box` gives `./box/a.raku`; with no
argument, inside the directory, the entries are bare names. `.` and `..` are
left out and hidden files are included. The order is the file system's,
which is why the examples sort. A missing directory throws `X::IO::Dir` at
once, and `dir-with-entries` answers whether a directory has any entries.

```raku local
mkdir "box/sub";
spurt "box/$_", "" for <b.txt a.raku .hidden>;
say dir("box").sort.map(*.Str);
say dir("box/").sort.map(*.Str);
say dir("./box").sort.map(*.Str);
say indir("box", { dir.sort.map(*.Str) });
say dir("box").head.^name, " ", "box/sub".IO.dir-with-entries;
say (try dir("missing")) // $!.^name;
unlink "box/$_" for <b.txt a.raku .hidden>;
rmdir "box/sub", "box";
```
```output
(box/.hidden box/a.raku box/b.txt box/sub)
(box/.hidden box/a.raku box/b.txt box/sub)
(./box/.hidden ./box/a.raku ./box/b.txt ./box/sub)
(.hidden a.raku b.txt sub)
IO::Path False
X::IO::Dir
```

## `dir`'s test sees the bare name, and can let `.` and `..` in
tags: trap

`dir` smartmatches its `:test` against each entry's name as a string, before
the directory is joined to it. A regex or a string method works as expected.
A test that asks the file system, such as `.IO.d`, examines the name
relative to the current directory, not to the one being listed. The default
test is what hides `.` and `..`, so a test of one's own lets them through
whenever it accepts them.

```raku local
mkdir "box/sub";
spurt "box/$_", "" for <b.txt a.raku .hidden>;
say dir("box", test => /'.raku' $/).map(*.Str);
say dir("box", test => *.starts-with("s")).map(*.Str);
say dir("box", test => { .IO.d }).sort.map(*.Str);
say dir("box", test => { "box/$_".IO.d }).sort.map(*.Str);
say dir("box", test => /^ '.'/).sort.map(*.Str);
unlink "box/$_" for <b.txt a.raku .hidden>;
rmdir "box/sub", "box";
```
```output
(box/a.raku)
(box/sub)
(box/. box/..)
(box/. box/.. box/sub)
(box/. box/.. box/.hidden)
```

The third line found `.` and `..`, which are directories wherever they are
looked up, but not `sub`, which is a directory only inside `box`.

## `spurt` writes, replaces or appends, and returns True

`spurt` creates or overwrites a file and returns `True`. With `:append` it
adds to the end, and with `:createonly` it refuses an existing file with a
Failure of type `X::AdHoc`. Without any data it creates an empty file. A
number is written as its string and a `Blob` as its bytes. `slurp` reads the
whole file back as a Str, or as a `Buf[uint8]` with `:bin`.

```raku local
say spurt("f", "x");
spurt "f", "y", :append;
say slurp("f");
spurt "f", "z";
say slurp("f");
my $r = spurt("f", "q", :createonly);
say $r.so, " ", $r.exception.^name;
say $r.exception.message.ends-with("File exists");
"empty".IO.spurt;
say "empty".IO.s;
spurt "n", 42;
spurt "b", Blob.new(65, 66);
say slurp("n"), " ", slurp("b");
say slurp("b", :bin).raku;
unlink "f", "empty", "n", "b";
```
```output
True
xy
z
False X::AdHoc
True
0
42 AB
Buf[uint8].new(65,66)
```

## `slurp` of a missing file throws, while `open` fails
tags: quirk

`open` on a missing file returns a Failure, like the other operations in
this chapter. `slurp` does not: on a missing file or on a directory it throws
`X::AdHoc` at once, as a sub and as a method, although the documentation
says it fails. The path methods that read a whole file on their own, such as
`.lines` and `.words`, throw in the same way.

```raku local
my $h = open("missing.txt");
say "open: ", $h.^name, ", defined: ", $h.defined;
{
    my $s = slurp("missing.txt");
    say "not reached";
    CATCH { default { say "slurp threw ", .^name } }
}
{
    my @l = "missing.txt".IO.lines;
    say "not reached";
    CATCH { default { say "lines threw ", .^name } }
}
```
```output
open: Failure, defined: False
slurp threw X::AdHoc
lines threw X::AdHoc
```

A default after `//`, as in `$path.slurp // ""`, is therefore never reached.
Test `.e` first, or wrap the read in `try`.

## Reading turns `\r\n` into `\n`

Text read from a file has every `\r\n` translated into `\n`, while a lone
`\r` is kept. The bytes on the disk are not touched, as `:bin` shows, and
nothing is translated on the way out. `IO::Path.slurp` keeps the `\r\n` when
it is given `:!translate-nl`; `open` accepts the same option and ignores it.

```raku local
spurt "crlf.txt", "a\r\nb\rc\n";
say slurp("crlf.txt").raku;
say slurp("crlf.txt", :bin).elems;
say "crlf.txt".IO.slurp(:!translate-nl).raku;
say open("crlf.txt", :!translate-nl).slurp.raku;
unlink "crlf.txt";
```
```output
"a\nb\rc\n"
7
"a\r\nb\rc\n"
"a\nb\rc\n"
```

## `.lines` splits on `nl-in`, and `:!chomp` keeps the separators

`.lines` cuts the text at each of the separators in `nl-in`, `\n` and `\r\n`
by default, and removes the separator from each line (it *chomps*) unless it
is given `:!chomp`. A lone `\r` does not end a line. `:nl-in` names other
separators, one string or several, and then `\n` is no longer one of them.

```raku local
spurt "crlf.txt", "a\r\nb\rc\n";
say "crlf.txt".IO.lines.raku;
say "crlf.txt".IO.lines(:!chomp).raku;
say "crlf.txt".IO.lines(:nl-in("\r")).raku;
spurt "list.txt", "a;b,c\nd";
say "list.txt".IO.lines(:nl-in(";", ",")).raku;
unlink "crlf.txt", "list.txt";
```
```output
("a", "b\rc").Seq
("a\n", "b\rc\n").Seq
("a\nb", "c\n").Seq
("a", "b", "c\nd").Seq
```

With `:nl-in("\r")` the `\r\n` has already become `\n` by the time the text
is split, so the one cut is at the lone `\r`, and the `\n` at the end stays.

## `.words`, `.comb` and `.split` on a path read the file
tags: trap

`IO::Path` has its own `.lines`, `.words`, `.comb`, `.split` and `.slurp`,
and these read the file. The string methods it does not define itself work
on the path's name, because a path is `Cool` and turns into its string:
`.chars`, `.contains`, `.uc`, `.subst`, and a regex match with `~~`.

```raku local
spurt "notes.txt", "one two\nthree\n";
my $p = "notes.txt".IO;
say $p.words.raku;
say $p.split("\n").raku;
say $p.comb.elems;
say $p.chars;
say $p.contains("two"), " ", $p.contains("notes");
say so $p ~~ /three/;
unlink "notes.txt";
```
```output
("one", "two", "three").Seq
("one two", "three", "").Seq
14
9
False True
False
```

`.comb` counted the 14 characters of the file, `.chars` the 9 of its name.
`.split("\n")` keeps the empty piece after the final newline, as it would on
a string.

## The `lines` sub reads a file only when given a path
tags: trap

The subs `lines` and `words` call the method of the same name on their
argument. Given a string, they split the string, so `lines("notes.txt")` is a
single line of text: the name. Only an `IO::Path` or a handle makes them
read.

```raku local
spurt "notes.txt", "one\ntwo\n";
say lines("notes.txt").raku;
say lines("notes.txt".IO).raku;
say words("notes.txt").raku;
say "notes.txt".IO.lines.raku;
unlink "notes.txt";
```
```output
("notes.txt",).Seq
("one", "two").Seq
("notes.txt",).Seq
("one", "two").Seq
```

## A UTF-16 file begins with a byte-order mark

Writing with `:enc<utf16>` puts the byte-order mark `FF FE` in front of the
text, and appending to a file that already has content does not add another
one. Reading with `:enc<utf16>` consumes the mark. `encode("utf16")` gives no
mark, and neither does `:enc<utf16le>` (see
[Blobs and Bufs](#ch:buffers:utf-16-follows-a-byte-order-mark-utf-8-drops-one)).

```raku local
spurt "u16.txt", "é", :enc<utf16>;
say slurp("u16.txt", :bin).list;
spurt "u16.txt", "e", :enc<utf16>, :append;
say slurp("u16.txt", :bin).list;
say slurp("u16.txt", :enc<utf16>);
say "é".encode("utf16").list;
spurt "le.txt", "é", :enc<utf16le>;
say slurp("le.txt", :bin).list;
unlink "u16.txt", "le.txt";
```
```output
(255 254 233 0)
(255 254 233 0 101 0)
ée
(233)
(233 0)
```

`encode("utf16")` returns a buffer of 16-bit elements, so `é` is the single
element 233. Latin-1 writes one byte per character, and reading those bytes
without an encoding, as UTF-8, throws:

```raku local
spurt "l1.txt", "é", :enc<latin1>;
say slurp("l1.txt", :bin).list;
say slurp("l1.txt", :enc<latin1>);
{
    my $s = slurp("l1.txt");
    CATCH { default { say .^name, ": ", .message } }
}
unlink "l1.txt";
```
```output
(233)
é
X::AdHoc: Malformed termination of UTF-8 string
```

## Every output method returns True, and `.tell` counts bytes

On a handle opened for writing, `print`, `say`, `put`, `printf`,
`print-nl` and `write` return `True`. `say` and `put` with several arguments
join them without a separator. `.tell` is the number of bytes written so far.
The gist shows the path and whether the handle is open, and `close` returns
`True`, even on a handle that is already closed.

```raku local
my $fh = open("log.txt", :w);
say $fh.print("a");
say $fh.say("b", "c");
say $fh.put(1, 2);
say $fh.printf("%03d", 7);
say $fh.write(Blob.new(88));
say $fh.tell;
say $fh.gist;
say $fh.close, " ", $fh.close;
say $fh.gist;
say slurp("log.txt").raku;
unlink "log.txt";
```
```output
True
True
True
True
True
11
IO::Handle<"log.txt".IO>(opened)
True True
IO::Handle<"log.txt".IO>(closed)
"abc\n12\n007X"
```

## A closed handle refuses with two kinds of exception

After `close`, `print`, `get` and `lines` throw `X::IO::Closed`, whose
message names the operation. `tell`, `seek`, `read`, `slurp` and
`native-descriptor` throw an `X::AdHoc` instead, and for all but the last
the message comes from the virtual machine underneath. `.eof` answers
`True`.

```raku local
my $fh = open("log.txt", :w);
$fh.close;
for { $fh.print("x") }, { $fh.get }, { $fh.lines }, { $fh.tell }, { $fh.slurp } -> &op {
    op();
    CATCH { default { say .^name } }
}
say (try $fh.tell) // $!.message;
say $fh.eof;
unlink "log.txt";
```
```output
X::IO::Closed
X::IO::Closed
X::IO::Closed
X::AdHoc
X::AdHoc
tell requires an object with REPR MVMOSHandle (got VMNull with REPR Null)
True
```

## `.eof` is True before `get` returns Nil

`get` reads one line, chomped, and returns `Nil` when nothing is left.
`.tell` after it counts the bytes consumed, newline included. `getc` reads a
single character. `.eof` becomes `True` as soon as the last line has been
read, before any `get` has returned `Nil`.

```raku local
spurt "r.txt", "l1\nl2\r\nl3";
my $fh = open("r.txt");
say $fh.get.raku, " ", $fh.tell;
say $fh.getc.raku;
say $fh.get.raku, " ", $fh.eof;
say $fh.get.raku, " ", $fh.eof;
say $fh.get.raku;
$fh.close;
unlink "r.txt";
```
```output
"l1" 3
"l"
"2" False
"l3" True
Nil
```

The `\r\n` after `l2` is removed like a `\n`: it was translated before the
line was chomped.

## `lines($n)` stops after n lines and leaves the handle open

With a count, `.lines` reads that many lines and leaves the handle
positioned after them, so a following `get` goes on from there. With
`:close` it closes the handle once the count is reached.

```raku local
spurt "r.txt", "l1\nl2\nl3\n";
my $fh = open("r.txt");
my @two = $fh.lines(2);
say @two.raku;
say $fh.opened, " ", $fh.get.raku;
$fh.close;
$fh = open("r.txt");
say $fh.lines(2, :close).raku;
say $fh.opened;
unlink "r.txt";
```
```output
["l1", "l2"]
True "l3"
("l1", "l2").Seq
False
```

`.lines` returns a lazy Seq, and it reads a line only when the Seq is asked
for one. A `get` made before the Seq is read takes the line the Seq would
have had:

```raku local
spurt "r.txt", "l1\nl2\nl3\n";
my $fh = open("r.txt");
my $seq = $fh.lines;
say $fh.get;
say $seq.List.raku;
$fh.close;
unlink "r.txt";
```
```output
l1
("l2", "l3")
```

## On a handle, `.lines(:!chomp)` keeps every line end but the first
tags: quirk

The documented ways to keep line ends while reading a handle are
`open(:!chomp)` and assigning `False` to its `.chomp`. `.lines` on a handle
lists no `:chomp` argument, yet it accepts one, and it applies it only from
the second line on: the first line is still chomped.

```raku local
spurt "r.txt", "l1\nl2\nl3\n";
say open("r.txt").lines(:!chomp).raku;
say open("r.txt", :!chomp).lines.raku;
my $fh = open("r.txt");
$fh.chomp = False;
say $fh.lines.raku;
$fh.close;
unlink "r.txt";
```
```output
("l1", "l2\n", "l3\n").Seq
("l1\n", "l2\n", "l3\n").Seq
("l1\n", "l2\n", "l3\n").Seq
```

`.lines(:!chomp)` on an `IO::Path`, where the argument is documented, keeps
every line end.

## A handle's `:nl-in("\r\n")` never sees a `\r\n`
tags: trap

Line ends are translated while the bytes are decoded, before `nl-in` is
consulted. A handle opened with `:nl-in("\r")` or `:nl-in("\r\n")` therefore
never meets a `\r\n`: it has become `\n`, which is no longer a separator,
and the whole file is one line. Passed to `.lines` on a handle instead of to
`open`, `:nl-in` is ignored.

```raku local
spurt "r.txt", "l1\nl2\r\nl3";
say open("r.txt", :nl-in("\r")).lines.raku;
say open("r.txt", :nl-in("\r\n")).lines.raku;
say open("r.txt").lines(:nl-in("\r")).raku;
unlink "r.txt";
```
```output
("l1\nl2\nl3",).Seq
("l1\nl2\nl3",).Seq
("l1", "l2", "l3").Seq
```

## `read`, `readchars` and `slurp` go on from the current position

A handle has one position, shared by every way of reading it. `read` takes
bytes and returns a `Buf`, `readchars` takes characters, and `slurp` takes
the rest, after which `.eof` is `True`. `seek` moves the position, counting
from the beginning, the current position or the end, and returns `True`.

```raku local
spurt "r.txt", "abcdef\nghi";
my $fh = open("r.txt");
say $fh.read(2).raku;
say $fh.readchars(3);
say $fh.slurp.raku;
say $fh.eof;
say $fh.seek(-3, SeekFromEnd);
say $fh.slurp;
say $fh.seek(0), " ", $fh.tell;
say $fh.readchars(1), " ", $fh.seek(2, SeekFromCurrent), " ", $fh.get;
$fh.close;
unlink "r.txt";
```
```output
Buf[uint8].new(97,98)
cde
"f\nghi"
True
True
ghi
True 0
a True def
```

In the last line `readchars(1)` leaves the position at 1, and a relative
`seek` of 2 lands on `d`. `.tell` reports the bytes the decoder has taken,
which can be more than the characters it has returned: after `l2`, it has
already taken the `\r` of the `\r\n` that follows.

```raku local
spurt "r.txt", "l1\nl2\r\nl3";
my $fh = open("r.txt");
say $fh.read(3).raku;
say $fh.readchars(2), " ", $fh.tell;
$fh.close;
unlink "r.txt";
```
```output
Buf[uint8].new(108,49,10)
l2 6
```

## A `:bin` handle reads bytes and refuses lines

Opened with `:bin`, a handle has no encoding: `.encoding` is `Nil`. `read`
and `slurp` give `Buf`s, and every method that needs characters, `get`,
`lines` and `readchars`, throws `X::IO::BinaryMode`. A text handle gives
bytes too when asked with `.slurp(:bin)`. `.Supply(:size(n))` emits chunks
of n bytes from a binary handle and of n characters from a text one.

```raku local
spurt "r.txt", "l1\nl2";
my $b = open("r.txt", :bin);
say $b.encoding.raku;
say $b.read(2).raku;
say $b.slurp.raku;
$b.close;
for { open("r.txt", :bin).get }, { open("r.txt", :bin).lines.eager }, { open("r.txt", :bin).readchars(1) } -> &op {
    op();
    CATCH { default { say .^name } }
}
say open("r.txt").slurp(:bin).^name;
say open("r.txt", :bin).Supply(:size(2)).list.raku;
say open("r.txt").Supply(:size(2)).list.raku;
unlink "r.txt";
```
```output
Nil
Buf[uint8].new(108,49)
Buf[uint8].new(10,108,50)
X::IO::BinaryMode
X::IO::BinaryMode
X::IO::BinaryMode
Buf[uint8]
(Buf[uint8].new(108,49), Buf[uint8].new(10,108), Buf[uint8].new(50))
("l1", "\nl", "2")
```

## `open` fails when the system refuses, and throws on a bad argument

`open` returns a Failure when the operating system says no: for a missing
file (`X::AdHoc`), for a directory (`X::IO::Directory`, whose `.trying` is
`open`), and for an existing file opened with `:x` (`X::AdHoc`). A mistake
in the arguments throws instead: an unknown encoding throws
`X::Encoding::Unknown`, and `:bin` together with an encoding throws
`X::IO::BinaryAndEncoding`.

```raku local
mkdir "d";
spurt "f", "old";
for open("missing"), open("d"), open("f", :x) -> $h {
    say $h.so, " ", $h.exception.^name;
}
my $d = open("d");
say $d.so, " ", $d.exception.trying;
for { open("f", :enc<klingon>) }, { open("f", :bin, :enc<utf8>) } -> &bad {
    my $h = bad();
    say "not reached";
    CATCH { default { say "threw ", .^name } }
}
rmdir "d";
unlink "f";
```
```output
False X::AdHoc
False X::IO::Directory
False X::AdHoc
False open
threw X::Encoding::Unknown
threw X::IO::BinaryAndEncoding
```

## `:rw` creates without emptying; `:update` does not create

`open` reads by default. The other modes write, and they differ in what they
do with a missing file and with an existing one:

| mode | reads | a missing file | an existing file | writes at |
|---|---|---|---|---|
| `:r` or nothing | yes | fails | kept | — |
| `:w` | no | created | emptied | the start |
| `:a` | no | created | kept | the end |
| `:x` | no | created | fails | the start |
| `:rw` | yes | created | kept | the start |
| `:update` | yes | fails | kept | the start |

```raku local
spurt "f", "old";
given open("f", :a) { .print("+new"); .close }
say slurp("f");
open("f", :w).close;
say slurp("f").raku;
spurt "f", "abc";
given open("f", :rw) { .print("X"); .seek(0); say .get; .close }
given open("f", :update) { .print("Y"); .close }
say slurp("f");
my $u = open("new", :update);
say $u.so, " ", "new".IO.e;
open("new", :x).close;
say "new".IO.e;
given open("f") { say (try .print("z")) // $!.message; .close }
given open("f", :a) { say (try .get) // $!.message; .close }
unlink "f", "new";
```
```output
old+new
""
Xbc
Ybc
False False
True
Failed to write 1 bytes to filehandle: Bad file descriptor
Reading from filehandle failed: Bad file descriptor
```

`:rw` and `:update` overwrite from the start without emptying the file, so
`abc` became `Xbc` and then `Ybc`. Writing to a handle opened for reading, or
reading from one opened for writing, throws `X::AdHoc` with the operating
system's complaint.

## Encoding names are normalised, and `.encoding` switches in mid-file

`:enc` accepts the usual spellings of an encoding's name and reports it in
one form: `latin1` becomes `iso-8859-1`, `UTF-8` becomes `utf8`. Calling
`.encoding` with a name changes how the rest of the handle is decoded and
returns the normalised name. `.encoding("bin")` switches the handle to binary
mode and returns `Nil`.

```raku local
spurt "f", "é";
say open("f").encoding;
say open("f", :enc<latin1>).encoding;
say open("f", :enc<UTF-8>).encoding;
my $h = open("f");
say $h.encoding("latin1");
say $h.slurp.raku;
$h.close;
$h = open("f");
say $h.encoding("bin").raku;
say $h.slurp.raku;
$h.close;
unlink "f";
```
```output
utf8
iso-8859-1
utf8
iso-8859-1
"Ã©"
Nil
Buf[uint8].new(195,169)
```

`"Ã©"` is the two UTF-8 bytes of `é` read as Latin-1 characters.

## `prompt` returns an allomorph, and Nil at the end of input

`prompt` prints its message without a newline, flushes it, and reads one
line of standard input. The line is chomped and passed through `val`, so a
line of digits comes back as an `IntStr` (see
[Strings](#ch:strings:val-makes-an-allomorph-and-keeps-the-exact-text)). At
the end of the input `prompt` returns `Nil`, and so does `$*IN.get`; `.lines`
is then empty and `.slurp` the empty string.

```raku local stdin="Ada\n36"
my $name = prompt "Name? ";
my $age = prompt "Age? ";
say "|";
say $name.raku;
say $age.raku;
say prompt("More? ").raku;
say $*IN.get.raku, " ", $*IN.eof;
say $*IN.lines.raku, " ", $*IN.slurp.raku;
```
```output
Name? Age? |
"Ada"
IntStr.new(36, "36")
More? Nil
Nil True
().Seq ""
```

The messages share a line because standard input here is a file; at a
terminal, the reader's Enter key would end each line.

## `$*IN.lines($n)` leaves the rest of the input unread

Standard input is an ordinary handle, and its methods read only as much as
they need. `$*IN.lines(1)` takes the first line and leaves the rest for the
next reader, here `.words`. With no file names on the command line,
`$*ARGFILES` is `$*IN` itself, and it is what `lines()`, `words()` and
`slurp()` read when they are called without an argument.

```raku local stdin="name age\nAda 36\nAlan 41\n"
my @header = $*IN.lines(1);
say @header.raku;
say $*IN.words.raku;
say $*IN.eof, " ", slurp().raku;
say $*ARGFILES === $*IN;
```
```output
["name age"]
("Ada", "36", "Alan", "41").Seq
True ""
True
```

## `indir` runs a block in another directory, or fails

`indir` sets `$*CWD` to the directory for the duration of the block and
returns the block's value. Paths made inside the block resolve there, and
`$*CWD` outside it is unchanged. A missing directory, or a file, is a Failure
of type `X::IO::Chdir` whose `.os-error` says which, and the block does not
run.

```raku local
mkdir "sub";
say indir("sub", { $*CWD.basename });
say indir("sub", { "f".IO.absolute.ends-with("/sub/f") });
say indir("sub", { 42 });
say $*CWD.basename ne "sub";
my $r = indir("missing", { say "never runs" });
say $r.so, " ", $r.exception.^name, ": ", $r.exception.os-error;
spurt "file", "";
my $f = indir("file", {;});
say $f.so, " ", $f.exception.os-error;
rmdir "sub";
unlink "file";
```
```output
sub
True
42
True
False X::IO::Chdir: does not exist
False is not a directory
```

## `chdir` changes `$*CWD`, not the process's directory

`chdir` sets `$*CWD` and returns it as an absolute `IO::Path`. From then on
relative paths resolve against the new directory. A directory that does not
exist gives a Failure and leaves `$*CWD` where it was.

```raku local
mkdir "sub";
my $start = $*CWD;
my $new = chdir "sub";
say $new.^name, " ", $new.basename, " ", $new.is-absolute;
say "f".IO.absolute.ends-with("/sub/f");
my $bad = chdir "missing";
say $bad.so, " ", $bad.exception.^name, " ", $*CWD.basename;
chdir "..";
say $*CWD eq $start;
rmdir "sub";
```
```output
IO::Path sub True
True
False X::IO::Chdir sub
True
```

The process itself stays where it was. Raku's own file operations, and the
programs started with `run`, go by `$*CWD`, but a native library asks the
operating system. `&*chdir` changes both. Here the C library's `getcwd`
reports the process's directory:

```raku local
use NativeCall;
sub getcwd(Buf, size_t --> Pointer) is native {*}
sub process-dir { my $b = Buf.allocate(4096); getcwd($b, 4096); $b.decode.subst(/\0.*/, "") }
mkdir "sub";
chdir "sub";
say $*CWD.basename, " ", process-dir().IO.basename eq "sub";
chdir "..";
&*chdir("sub");
say $*CWD.basename, " ", process-dir().IO.basename eq "sub";
&*chdir("..");
rmdir "sub";
```
```output
sub False
sub True
```

## `IO::Path.chdir` only computes a path

The method `.chdir` on a path changes nothing. It returns a new path: the
argument joined to the path, or the argument alone when it is absolute, with
a leading `..` applied to the text. By default it checks that the result is
a directory and fails with `X::IO::Chdir` when it is not; `:!d` skips the
check.

```raku local
say "/a/b".IO.chdir("../c", :!d).Str;
say "/a/b".IO.chdir("/x", :!d).Str;
my $p = "/a/b".IO.chdir("c");
say $p.so, " ", $p.exception.os-error;
```
```output
/a/c
/x
False does not exist
```

## IO::Spec::Unix does the text work, and its `:parent` removes `x/..`

The string operations behind `IO::Path` live in `$*SPEC`, which is
`IO::Spec::Unix` on Unix-like systems, and they can be called directly.
`canonpath` is `.cleanup` for strings; with `:parent` it also removes every
`x/..` pair, which `.cleanup` refuses to do. `catdir` joins with single
separators, and `rel2abs` and `abs2rel` are `.absolute` and `.relative` on
strings, leaving `..` alone. Its `basename` does not drop a trailing slash,
unlike the method of `IO::Path`.

```raku
my $s = IO::Spec::Unix;
say $s.canonpath("a//b/./c/");
say $s.canonpath("a/../b");
say $s.canonpath("a/../b", :parent);
say $s.catdir("a/", "/b");
say $s.rel2abs("a/../b", "/x");
say $s.abs2rel("/y", "/x/a");
say $s.basename("/a/b/").raku, " ", "/a/b/".IO.basename;
say $s.splitdir("/a/b").raku;
say $*SPEC.^name;
```
```output
a/b/c
a/../b
b
a/b
/x/a/../b
../../y
"" b
("", "a", "b")
IO::Spec::Unix
```

## `say` prints a Junction; `put` and `print` print each value

`say` prints the gist of its arguments, and the gist of a Junction is the
whole junction. `put` and `print` want strings, so they autothread: each
eigenstate is printed by a call of its own, and the result is a junction of
the calls' return values.

```raku
say any(1, 2);
put any(1, 2);
print any(1, 2);
print "\n";
say (put "x" | "y").raku;
```
```output
any(1, 2)
1
2
12
x
y
any(Bool::True, Bool::True)
```

The methods of a handle behave the same way:

```raku local
my $fh = open("j.txt", :w);
$fh.say(any(1, 2));
$fh.put(any(1, 2));
$fh.say((1, 2));
$fh.put((1, 2));
$fh.close;
.say for "j.txt".IO.lines;
unlink "j.txt";
```
```output
any(1, 2)
1
2
(1 2)
1 2
```

## `nl-out` is what `say`, `put` and `print-nl` add

Each handle has an `nl-out`, `\n` unless `open` was given another, and
`say`, `put` and `print-nl` end their output with it. A `\n` inside the text
is written as it is. `nl-out` can be assigned at any time.

```raku local
my $fh = open("crlf.txt", :w, :nl-out("\r\n"));
$fh.say("a");
$fh.put("b");
$fh.print("c\n");
$fh.print-nl;
$fh.nl-out = "!";
$fh.say("z");
$fh.close;
say slurp("crlf.txt", :bin).list;
unlink "crlf.txt";
```
```output
(97 13 10 98 13 10 99 10 13 10 122 33)
```

That includes `$*OUT`, and the other handles keep their own:

```raku
$*OUT.nl-out = " <end>\n";
say "one";
put "two";
print "three\n";
note "four";
```
```output
one <end>
two <end>
three
```
```stderr
four
```

## `IO::Handle.new` makes a closed handle

A handle made with `IO::Handle.new` is not open: its gist says `(closed)`,
reading throws `X::IO::Closed`, and `close` returns `True`. Its encoding is
already `utf8`. The `.open` method opens it, with the same mode arguments as
the `open` sub.

```raku local
my $h = IO::Handle.new(path => "notes.txt");
say $h.opened, " ", $h.gist;
say $h.encoding, " ", $h.eof, " ", $h.close;
say (try $h.get) // $!.^name;
$h.open(:w);
$h.say("hello");
$h.close;
print slurp "notes.txt";
unlink "notes.txt";
```
```output
False IO::Handle<"notes.txt".IO>(closed)
utf8 True True
X::IO::Closed
hello
```

## `lock` and `flush` return a Failure when they cannot

`lock`, `unlock` and `flush` return `True` on an open handle. `lock` takes
an exclusive lock, which a handle opened for reading cannot hold: it returns
a Failure of type `X::IO::Lock`, while `lock(:shared)` succeeds. `flush` on
a closed handle fails with `X::IO::Flush`.

```raku local
spurt "f", "x";
my $w = open("f", :a);
say $w.lock, " ", $w.unlock, " ", $w.flush;
$w.close;
my $fl = $w.flush;
say $fl.so, " ", $fl.exception.^name;
my $ro = open("f");
my $ex = $ro.lock;
say $ex.so, " ", $ex.exception.^name;
say $ro.lock(:shared);
$ro.close;
unlink "f";
```
```output
True True True
False X::IO::Flush
False X::IO::Lock
True
```

## A command's output is an IO::Pipe whose `close` returns the Proc

`run` with `:out` connects the command's standard output to an `IO::Pipe`,
a kind of `IO::Handle` with `get`, `lines`, `slurp` and `eof`. Its `close`
waits for the command and returns the `Proc`, which `.proc` also gives. A
pipe has no path: `.path` is the `IO::Path` type object. Running commands is
the subject of [Processes](#ch:processes).

```raku local
my $p = run "printf", 'hi\nthere\n', :out;
my $pipe = $p.out;
say $pipe.^name, " ", $pipe ~~ IO::Handle;
say $pipe.get;
say $pipe.lines.raku;
say $pipe.get.raku, " ", $pipe.eof;
say $pipe.close.^name, " ", $pipe.proc.^name;
say $pipe.path.raku;
say $pipe.gist;
```
```output
IO::Pipe True
hi
("there",).Seq
Nil True
Proc Proc
IO::Path
IO::Pipe<(IO)>(closed)
```

A pipe made with `:in` is written with `print` and closed to end the
command's input. Printing to an output pipe throws `X::AdHoc`, and with
`:bin` an output pipe gives bytes:

```raku local
my $q = run "cat", :in, :out;
$q.in.print("via a pipe");
$q.in.close;
say $q.out.slurp(:close);
say (try run("printf", "x", :out).out.print("y")) // $!.^name;
say run("printf", "AB", :out, :bin).out.read(2).raku;
```
```output
via a pipe
X::AdHoc
Buf[uint8].new(65,66)
```

## IO::CatHandle reads several files as one

An `IO::CatHandle` reads its sources one after another, as if they were a
single file: `lines`, `slurp`, `readchars` and `read` all run across the
boundary between two files. A CatHandle without sources is at its end from
the start.

```raku local
spurt "a.txt", "a1\na2\n";
spurt "b.txt", "b1";
say IO::CatHandle.new("a.txt", "b.txt").lines.raku;
say IO::CatHandle.new("a.txt", "b.txt").slurp.raku;
say IO::CatHandle.new("a.txt", "b.txt").readchars(4).raku;
say IO::CatHandle.new("a.txt", "b.txt").read(4).raku;
my $empty = IO::CatHandle.new;
say $empty.get.raku, " ", $empty.eof;
unlink "a.txt", "b.txt";
```
```output
("a1", "a2", "b1").Seq
"a1\na2\nb1"
"a1\na"
Buf[uint8].new(97,49,10,97)
Nil True
```

## A CatHandle's on-switch runs per file, and once more with Nil

A CatHandle opens its first source as soon as it is made, so `.path` names
that file before anything has been read. `.path` then follows the reading
from file to file, and becomes `Nil` when the last one is used up. The
`:on-switch` code runs at every change: once when the first file is opened,
once for each file after it, and a last time with `Nil` when the sources run
out.

```raku local
spurt "a.txt", "a1\na2\n";
spurt "b.txt", "b1";
my @seen;
my $cat = IO::CatHandle.new("a.txt", "b.txt",
    on-switch => { @seen.push: .defined ?? .path.Str !! .raku });
say @seen;
say $cat.get, " ", $cat.path;
say $cat.get, " ", $cat.get, " ", $cat.path;
say $cat.get.raku, " ", $cat.path.raku, " ", $cat.eof;
say @seen;
unlink "a.txt", "b.txt";
```
```output
[a.txt]
a1 "a.txt".IO
a2 b1 "b.txt".IO
Nil Nil True
[a.txt b.txt Nil]
```

Because the first source is opened by `new`, a missing first file throws
there; a missing later file throws when the reading reaches it.
`next-handle` abandons the current file and returns the handle of the next:

```raku local
spurt "a.txt", "a1";
my $m = IO::CatHandle.new("a.txt", "missing.txt");
say $m.get;
say (try $m.get) // $!.^name;
say (try IO::CatHandle.new("missing.txt")) // $!.^name;
my $n = IO::CatHandle.new("a.txt", "a.txt");
say $n.next-handle.^name, " ", $n.get;
unlink "a.txt";
```
```output
a1
X::AdHoc
X::AdHoc
IO::Handle a1
```
