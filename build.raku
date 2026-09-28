#!/usr/bin/env rakupp
# build.raku — the generator for "All Corners of Raku".
#
#   rakupp build.raku                  build src/ -> out/ from the cached results
#   rakupp build.raku --verify         run every uncached example on both engines first
#   rakupp build.raku --verify --only=precedence    …only the chapters whose slug matches
#   rakupp build.raku --clean          remove out/ first
#   rakupp build.raku --rakudo=PATH    the oracle (default /opt/homebrew/bin/rakudo)
#   rakupp build.raku --rakupp=PATH    the engine behind the editors (default: rakupp)
#
# The book is a sequence of chapters, one Markdown file each under
# src/chapters/NN-slug.md, ordered by file name and grouped into parts by the
# `part:` line of their front matter. Every `## ` heading is a corner: one
# behaviour, stated as a claim, numbered chapter.corner and linkable. A
# `tags:` line directly under the heading marks what kind of corner it is.
#
# A ```raku fence is an example. The ```output fence after it is what Rakudo
# prints, byte for byte, and --verify fails the build when the oracle prints
# anything else: the book cannot drift from the language it describes. The
# same example also runs on Raku++, which is what the page's editors run in
# the browser; where Raku++ prints something else the page says so beside the
# example, so the reader is never surprised by the Run button.
#
# Fence variants:
#   ```raku                 runnable in the page (the editor loads on demand)
#   ```raku local           needs threads, files or processes: shown static,
#                           verified all the same, labelled "run it locally"
#   ```raku nocheck         shown, never run (use sparingly)
#   ```raku stdin="a\nb"    the program's standard input
#   ```output               expected standard output (required after a checked example)
#   ```stderr               expected standard error (optional; compared when present)
#   ```text                 any other fence is a plain preformatted block

constant SRC   = 'src';
constant OUT   = 'out';
constant CACHE = 'cache';

my %BOOK;
my $VERSION = '';
my $BASE = '';

my %TAGS =
    'undocumented' => 'Not in the docs',
    'unasserted'   => 'Not in Roast',
    'quirk'        => 'Quirk',
    'bug'          => 'Bug?',
    'trap'         => 'Trap',
    '6e'           => '6.e',
;
my @TAG-ORDER = <trap quirk bug undocumented unasserted 6e>;

# ---------------------------------------------------------------------------
# Text helpers
# ---------------------------------------------------------------------------

sub esc(Str $s --> Str) {
    $s.subst('&', '&amp;', :g).subst('<', '&lt;', :g).subst('>', '&gt;', :g)
}
sub esc-attr(Str $s --> Str) { esc($s).subst('"', '&quot;', :g) }

sub slugify(Str $s is copy --> Str) {
    $s = $s.subst(/ '<' <-[>]>* '>' /, '', :g).lc;
    $s = $s.subst(/ <-[ a..z 0..9 \s \- ]> /, '', :g);
    $s = $s.trim.subst(/ \s+ /, '-', :g).subst(/ '-' ** 2..* /, '-', :g);
    $s || 'corner'
}

# Code spans are cut out first and replaced by plain-ASCII sentinels, so that
# nothing inside them is read as a link, emphasis or a table separator. A span
# written with double backticks may contain a single one.
sub code-spans(Str $s) {
    my @spans;                 # alternating: prose, code, prose, code, ..., prose
    my $rest = $s;
    loop {
        my $i = $rest.index('`');
        last without $i;
        my $double = $rest.substr($i, 2) eq '``';
        my $end = $rest.index($double ?? '``' !! '`', $i + ($double ?? 2 !! 1));
        last without $end;
        @spans.push($rest.substr(0, $i));
        my $inner = $rest.substr($i + ($double ?? 2 !! 1), $end - $i - ($double ?? 2 !! 1));
        @spans.push($double ?? $inner.trim !! $inner);
        $rest = $rest.substr($end + ($double ?? 2 !! 1));
    }
    @spans.push($rest);
    @spans
}

sub protect-code(Str $s, @codes --> Str) {
    my @out;
    for code-spans($s).kv -> $idx, $part {
        if $idx %% 2 {
            @out.push($part);
        }
        else {
            @codes.push($part);
            @out.push('zXCODEXz' ~ @codes.end ~ 'zXENDXz');
        }
    }
    @out.join
}

sub fmt-prose(Str $s --> Str) {
    my $t = esc($s);
    $t = $t.subst(/ '**' (<-[*]>+) '**' /, { '<strong>' ~ (~$0) ~ '</strong>' }, :g);
    $t.subst(/ <!after <[\w\\]>> '*' (<-[*\s]> <-[*]>*?) '*' <!before \w> /, { '<em>' ~ (~$0) ~ '</em>' }, :g)
}

# Inline Markdown: code spans, links, bold, italic. A link target of the form
# `#ch:slug` or `#ch:slug:corner` is resolved against the book's chapters, and
# `#index` is the corners index.
my %CHAPTER-BY-SLUG;
sub inline(Str $text --> Str) {
    my @codes;
    my $t = protect-code($text, @codes);
    my @links;
    $t = $t.subst(/ '[' (<-[ \] ]>+) ']' '(' (<-[ ) \s ]>+) ')' /, {
        @links.push('<a href="' ~ esc-attr(link-target(~$1)) ~ '">' ~ fmt-prose(~$0) ~ '</a>');
        'zXLINKXz' ~ @links.end ~ 'zXENDXz'
    }, :g);
    $t = fmt-prose($t);
    $t = $t.subst(/ 'zXLINKXz' (\d+) 'zXENDXz' /, { @links[+$0] }, :g);
    $t.subst(/ 'zXCODEXz' (\d+) 'zXENDXz' /, { '<code>' ~ esc(@codes[+$0]) ~ '</code>' }, :g)
}

# A table row's cells: split on `|` outside code spans.
sub table-cells(Str $row --> List) {
    my @codes;
    my $t = protect-code($row.trim, @codes);
    $t = $t.substr(1) if $t.starts-with('|');
    $t = $t.substr(0, *-1) if $t.ends-with('|');
    $t.split('|').map({
        .trim.subst(/ 'zXCODEXz' (\d+) 'zXENDXz' /, { '`' ~ @codes[+$0] ~ '`' }, :g)
    }).List
}

sub link-target(Str $t --> Str) {
    return $BASE ~ '/corners/' if $t eq '#index';
    return $t unless $t.starts-with('#ch:');
    my @p = $t.substr(4).split(':');
    my $ch = %CHAPTER-BY-SLUG{@p[0]};
    unless $ch {
        # A chapter that is planned but not written yet: keep the text, drop the link.
        note "warning: link to a chapter that does not exist yet: $t";
        return '#';
    }
    if @p[1] && $ch.corners && !$ch.corners.first({ .id eq @p[1] }) {
        note "warning: link to a corner that does not exist: $t";
    }
    $BASE ~ '/' ~ $ch.slug ~ '/' ~ (@p[1] ?? '#' ~ @p[1] !! '')
}

sub tsv-esc(Str $s --> Str) {
    $s.subst('\\', '\\\\', :g).subst("\n", '\\n', :g).subst("\t", '\\t', :g).subst("\r", '\\r', :g)
}
my %UNESC = 'n' => "\n", 't' => "\t", 'r' => "\r", '\\' => '\\';
sub tsv-unesc(Str $s --> Str) {
    $s.subst(/ '\\' (.) /, { %UNESC{~$0} // ~$0 }, :g)
}

# ---------------------------------------------------------------------------
# Document model
# ---------------------------------------------------------------------------

class Example {
    has Str $.code;
    has Str $.stdin = '';
    has Str $.kind = 'run';          # run | local | nocheck
    has $.expected is rw;            # Str or Nil
    has $.expected-err is rw;        # Str or Nil
    has Str $.file;
    has Int $.line;
    has Str $.id is rw = '';
    has $.rakudo is rw;              # [exit, out, err] once run
    has $.rakupp is rw;
}

class Corner {
    has Str $.id;
    has Str $.num;
    has Str $.title;
    has @.tags;
}

class Chapter {
    has Str $.slug;
    has Str $.title;
    has Str $.part;
    has Str $.summary;
    has Str $.path;
    has Str $.kind = 'chapter';      # chapter | appendix
    has Int $.num is rw = 0;
    has Str $.label is rw = '';      # "3" or "A"
    has @.blocks is rw;
    has @.corners is rw;
    has @.examples is rw;
}

sub parse-frontmatter(Str $text, Str $path) {
    die "$path: missing '---' front matter" unless $text.starts-with('---');
    my $end = $text.index("\n---", 3);
    die "$path: unterminated front matter" without $end;
    my $head = $text.substr(3, $end - 3).trim;
    my $body = $text.substr($end + 4).subst(/ ^ \n+ /, '');
    my %meta;
    for $head.lines -> $raw {
        my $line = $raw.trim;
        next if !$line || $line.starts-with('#');
        die "$path: bad front matter line: $line" unless $line.contains(':');
        my ($k, $v) = $line.split(':', 2);
        %meta{$k.trim} = $v.trim;
    }
    $(%meta), $body
}

# Fence info like `raku local stdin="Ada\nGrace"` -> (lang, %opts).
sub parse-info(Str $info) {
    my @w = $info.words;
    my $lang = @w ?? @w[0] !! '';
    my %opts;
    my $rest = $info.subst(/ ^ \s* \S+ /, '');
    for $rest ~~ m:g/ (<[\w-]>+) [ '="' (<-[\x22]>*) '"' ]? / -> $m {
        %opts{~$m[0]} = $m[1].defined ?? (~$m[1]).subst('\n', "\n", :g) !! True;
    }
    $lang, %opts
}

# Split a chapter body into blocks. Examples are paired with the output and
# stderr fences that follow them.
sub parse-blocks(Chapter $ch, Str $body) {
    my @lines = $body.lines;
    my @blocks;
    my $i = 0;
    my $n = @lines.elems;
    my $last-example;
    my $corner-count = 0;
    my $example-count = 0;
    my @para;
    my sub flush-para() {
        if @para {
            @blocks.push({ type => 'p', text => @para.join(' ') });
            @para = ();
        }
    }
    while $i < $n {
        my $line = @lines[$i];
        if $line ~~ / ^ '```' (.*) $ / {
            flush-para();
            my ($lang, $opts) = parse-info(~$0);
            my $start = $i + 1;
            my @code;
            $i++;
            while $i < $n && !@lines[$i].starts-with('```') {
                @code.push(@lines[$i]);
                $i++;
            }
            die "{$ch.path}:{$start}: unterminated fence" if $i >= $n;
            $i++;
            my $text = @code.join("\n");
            if $lang eq 'raku' {
                my $kind = $opts<local> ?? 'local' !! $opts<nocheck> ?? 'nocheck' !! 'run';
                $example-count++;
                my $ex = Example.new(code => $text, stdin => ($opts<stdin> // ''), :$kind,
                                     file => $ch.path, line => $start);
                $ex.id = 'ex-' ~ $ch.label ~ '-' ~ $example-count;
                $ch.examples.push($ex);
                @blocks.push({ type => 'example', ex => $ex });
                $last-example = $ex;
            }
            elsif $lang eq 'output' {
                die "{$ch.path}:{$start}: output fence without an example" without $last-example;
                die "{$ch.path}:{$start}: second output fence" if $last-example.expected.defined;
                $last-example.expected = $text;
            }
            elsif $lang eq 'stderr' {
                die "{$ch.path}:{$start}: stderr fence without an example" without $last-example;
                $last-example.expected-err = $text;
            }
            else {
                @blocks.push({ type => 'pre', lang => $lang, text => $text });
                $last-example = Nil;
            }
            next;
        }
        if $line ~~ / ^ '## ' (.+) $ / {
            flush-para();
            my $title = (~$0).trim;
            my @tags;
            if $i + 1 < $n && @lines[$i + 1] ~~ / ^ 'tags:' (.*) $ / {
                @tags = (~$0).split(/ <[\s,]>+ /).grep(*.chars);
                for @tags -> $t { die "{$ch.path}:{$i + 2}: unknown tag '$t'" unless %TAGS{$t}:exists }
                $i++;
            }
            $corner-count++;
            my $id = slugify($title.subst('`', '', :g));
            $id = $id ~ '-' ~ $corner-count if $ch.corners.first({ .id eq $id });
            my $c = Corner.new(:$id, num => $ch.label ~ '.' ~ $corner-count, :$title, :@tags);
            $ch.corners.push($c);
            @blocks.push({ type => 'h2', corner => $c });
            $last-example = Nil;
            $i++;
            next;
        }
        if $line ~~ / ^ '### ' (.+) $ / {
            flush-para();
            @blocks.push({ type => 'h3', text => (~$0).trim });
            $last-example = Nil;
            $i++;
            next;
        }
        if $line ~~ / ^ \s* [ '-' | '*' ] \s+ / || $line ~~ / ^ \s* \d+ '.' \s+ / {
            flush-para();
            my $ordered = so $line ~~ / ^ \s* \d /;
            my @items;
            while $i < $n && @lines[$i].trim ne '' {
                my $l = @lines[$i];
                if $l ~~ / ^ \s* [ '-' | '*' | \d+ '.' ] \s+ (.*) $ / {
                    @items.push(~$0);
                }
                else {
                    @items[*-1] ~= ' ' ~ $l.trim;
                }
                $i++;
            }
            @blocks.push({ type => ($ordered ?? 'ol' !! 'ul'), items => @items });
            $last-example = Nil;
            next;
        }
        if $line.starts-with('>') {
            flush-para();
            my @q;
            while $i < $n && @lines[$i].starts-with('>') {
                @q.push(@lines[$i].subst(/ ^ '>' ' '? /, ''));
                $i++;
            }
            @blocks.push({ type => 'aside', text => @q.join(' ') });
            $last-example = Nil;
            next;
        }
        if $line.starts-with('|') {
            flush-para();
            my @rows;
            while $i < $n && @lines[$i].starts-with('|') {
                my $r = @lines[$i].trim;
                unless $r ~~ / ^ '|' [ \s* ':'? '-'+ ':'? \s* '|' ]+ $ / {
                    @rows.push(table-cells($r).Array);
                }
                $i++;
            }
            @blocks.push({ type => 'table', rows => @rows });
            $last-example = Nil;
            next;
        }
        if $line.trim eq '' {
            flush-para();
            $i++;
            next;
        }
        @para.push($line.trim);
        $i++;
    }
    flush-para();
    for $ch.examples -> $ex {
        if $ex.kind ne 'nocheck' && !$ex.expected.defined {
            die "{$ex.file}:{$ex.line}: example has no ```output fence (mark it `nocheck` if it is meant to have none)";
        }
    }
    @blocks
}

sub load-chapter(Str $path, Int $pos) {
    my ($meta, $body) = parse-frontmatter(slurp($path), $path);
    die "$path: front matter needs a title" unless $meta<title>;
    die "$path: front matter needs a part"  unless $meta<part>;
    my $base = $path.IO.basename.subst(/ '.md' $ /, '').subst(/ ^ \d+ <[a..z]>? '-' /, '');
    my $ch = Chapter.new(
        slug    => $meta<slug> // $base,
        title   => $meta<title>,
        part    => $meta<part>,
        summary => $meta<summary> // '',
        kind    => $meta<kind> // 'chapter',
        :$path,
    );
    $ch, $body
}

# ---------------------------------------------------------------------------
# Running examples
# ---------------------------------------------------------------------------

my %CACHE;          # engine -> key -> [exit, out, err]
my %USED;           # engine -> key -> True
my %NEW;            # engine -> key -> result produced by this run
my $RUN-DIR = CACHE ~ '/run-' ~ $*PID;

sub engine-version(Str $engine --> Str) {
    my $p = run $engine, '--version', :out, :err;
    my $v = $p.out.slurp(:close).lines.head // '';
    $p.err.slurp(:close);
    die "cannot run $engine" unless $v;
    $v
}

sub cache-file(Str $label --> Str) { CACHE ~ '/' ~ $label ~ '.tsv' }

sub load-cache(Str $label) {
    my %c;
    my $f = cache-file($label);
    if $f.IO.e {
        for $f.IO.lines -> $l {
            my @f = $l.split("\t");
            next unless @f.elems == 4;
            %c{@f[0]} = [ +@f[1], hide-run-dir(cap(tsv-unesc(@f[2].substr(0, 2 * OUTPUT-CAP)))), hide-run-dir(cap(tsv-unesc(@f[3].substr(0, 2 * OUTPUT-CAP)))) ];
        }
    }
    %CACHE{$label} = %c;
}

# Several builds may run at once (one per chapter being written), so the
# cache is written under a lock, merged with whatever another build saved in
# the meantime, and swapped in whole. `mkdir` from the shell is the lock: it
# fails when the directory exists. With --prune, entries this build did not
# use are dropped (only meaningful for a full build).
sub save-cache(Str $label, Bool $prune) {
    mkdir CACHE unless CACHE.IO.d;
    my $lock = CACHE ~ '/.lock-' ~ $label;
    my $tries = 0;
    until run('mkdir', $lock, :err).exitcode == 0 {
        die "cache lock $lock held for a minute; remove it if no build is running" if ++$tries > 600;
        sleep 0.1;
    }
    load-cache($label);
    my %c = %CACHE{$label};
    %c{.key} = .value for %NEW{$label}.pairs;
    my @keys = %c.keys.sort;
    @keys = @keys.grep({ %USED{$label}{$_} }) if $prune;
    my $tmp = cache-file($label) ~ '.' ~ $*PID;
    my $fh = open $tmp, :w;
    for @keys -> $k {
        my $r = %c{$k};
        $fh.say: $k ~ "\t" ~ $r[0] ~ "\t" ~ tsv-esc($r[1]) ~ "\t" ~ tsv-esc($r[2]);
    }
    $fh.close;
    my $ok = run('mv', $tmp, cache-file($label)).exitcode == 0;
    run 'rmdir', $lock;
    die "could not replace " ~ cache-file($label) unless $ok;
}

sub cache-key(Str $version, Example $ex --> Str) {
    tsv-esc($version ~ "\x1F" ~ $ex.code ~ "\x1F" ~ $ex.stdin)
}

sub run-one(Str $engine, Example $ex, Int $timeout) {
    my $dir = $RUN-DIR;
    mkdir $dir unless $dir.IO.d;
    spurt "$dir/example.raku", $ex.code ~ "\n";
    spurt "$dir/in.txt", $ex.stdin;
    my $script = 'TZ=UTC perl -e "alarm shift; exec @ARGV" "$0" "$1" example.raku < in.txt > out.txt 2> err.txt';
    my $p = run 'sh', '-c', $script, ~$timeout, $engine, :cwd($dir);
    my $exit = $p.exitcode;
    # Some messages name the program by its absolute path; the book shows the
    # file as the reader would have it, `example.raku` in the current directory.
    my $abs = $*CWD.Str ~ '/' ~ $dir ~ '/';
    [ $exit, cap(hide-run-dir(slurp("$dir/out.txt").subst($abs, '', :g))), cap(hide-run-dir(slurp("$dir/err.txt").subst($abs, '', :g))) ]
}

# No example in the book prints more than a screenful, but a program that
# loops while printing (an engine bug, say) can produce hundreds of megabytes
# before the alarm stops it. Keep a bounded prefix, so one runaway run cannot
# bloat the cache that every build reads and rewrites.
# Any run directory of any build (cache/run-PID), written as an absolute path,
# becomes `.`: it is where the example ran, and the reader's own directory.
sub hide-run-dir(Str $s --> Str) {
    my $root = $*CWD.Str ~ '/' ~ CACHE ~ '/run-';
    $s.contains($root) ?? $s.subst(/ $root \d+ '/'? /, { $/.ends-with('/') ?? '' !! '.' }, :g) !! $s
}
constant OUTPUT-CAP = 20_000;
sub cap(Str $s --> Str) {
    $s.chars > OUTPUT-CAP
        ?? $s.substr(0, OUTPUT-CAP) ~ "\n… (cut: the program printed " ~ $s.chars ~ " characters)"
        !! $s
}

# With --fresh, a cached Rakudo result is run again and compared: an example
# whose output changes between runs (hash order, timing) would make the book
# flicker the next time the cache is rebuilt.
my $FRESH = False;
my @FLICKER;
sub result-for(Str $label, Str $engine, Str $version, Example $ex, Bool $run-missing, Int $timeout) {
    my $key = cache-key($version, $ex);
    %USED{$label}{$key} = True;
    if %CACHE{$label}{$key}:exists {
        return %CACHE{$label}{$key} unless $FRESH && $run-missing && $label eq 'rakudo';
        my $old = %CACHE{$label}{$key};
        my $new = run-one($engine, $ex, $timeout);
        @FLICKER.push($ex.file ~ ':' ~ $ex.line) if $new[1] ne $old[1] || $new[2] ne $old[2];
        return $old;
    }
    return Nil unless $run-missing;
    my $r = run-one($engine, $ex, $timeout);
    %CACHE{$label}{$key} = $r;
    %NEW{$label}{$key} = $r;
    $r
}

sub strip-nl(Str $s --> Str) { $s.subst(/ \n $ /, '') }

# Raku++ disagrees when its standard output differs, or when one engine
# rejects the program (a non-zero exit) and the other runs it.
sub engines-differ(Example $ex --> Bool) {
    return False unless $ex.rakupp.defined && $ex.rakudo.defined;
    return True if strip-nl($ex.rakupp[1]) ne $ex.expected;
    so ($ex.rakudo[0] == 0) != ($ex.rakupp[0] == 0)
}

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

sub highlight(Str $code, Str $rakupp --> Str) {
    state %memo;
    return %memo{$code} if %memo{$code}:exists;
    my $p = run $rakupp, '--highlight', :in, :out, :err;
    $p.in.print($code);
    $p.in.close;
    my $html = $p.out.slurp(:close);
    $p.err.slurp(:close);
    # Keep the spans, drop the <div class="highlight"><pre><span></span> wrapper.
    $html = $html.subst(/ ^ .*? '<pre>' ('<span></span>')? /, '').subst(/ '</pre></div>' \s* $ /, '');
    %memo{$code} = $html.subst(/ \n $ /, '');
}

sub tag-chips(@tags --> Str) {
    return '' unless @tags;
    '<span class="tags">' ~ @tags.map({ '<span class="tag tag-' ~ $_ ~ '">' ~ esc(%TAGS{$_}) ~ '</span>' }).join ~ '</span>'
}

sub render-example(Example $ex, Str $rakupp, Str $rakupp-version --> Str) {
    my $code-html = highlight($ex.code, $rakupp);
    my @h;
    @h.push: '<figure class="ex ex-' ~ $ex.kind ~ '" id="' ~ $ex.id ~ '">';
    my $stdin-attr = $ex.stdin ?? ' data-stdin="' ~ esc-attr($ex.stdin) ~ '"' !! '';
    if $ex.kind eq 'run' {
        @h.push: '<div class="code"><pre class="src" data-src' ~ $stdin-attr ~ '>' ~ $code-html ~ '</pre>'
               ~ '<button class="run" type="button" title="Edit and run this example here: Raku++ runs it in your browser">▶ Run in Raku++</button></div>';
    }
    else {
        my $label = $ex.kind eq 'local' ?? 'run it locally' !! 'not run';
        @h.push: '<div class="code"><pre class="src">' ~ $code-html ~ '</pre>'
               ~ '<span class="local-label">' ~ $label ~ '</span></div>';
    }
    if $ex.stdin {
        @h.push: '<div class="stdin"><span class="lbl">standard input</span><pre>' ~ esc($ex.stdin) ~ '</pre></div>';
    }
    if $ex.expected.defined {
        my $out = $ex.expected;
        @h.push: '<div class="out" data-hidden="0">'
               ~ '<div class="lbl">Reference output</div>'
               ~ '<pre class="out-text">' ~ (esc($out) || '<span class="empty">(nothing)</span>') ~ '</pre>'
               ~ ($ex.expected-err.defined
                    ?? '<div class="lbl err">and on standard error</div><pre class="err-text">' ~ esc($ex.expected-err) ~ '</pre>'
                    !! '')
               ~ '<button class="reveal" type="button">What does it print? <span>Reveal</span></button>'
               ~ '</div>';
    }
    # The Run button runs Raku++, so say where Raku++ prints something else.
    if $ex.kind eq 'run' && $ex.rakupp.defined && $ex.expected.defined {
        my ($exit, $out, $err) = |$ex.rakupp;
        if engines-differ($ex) {
            my $shown = strip-nl($out);
            $shown = $shown.lines.head(30).join("\n") ~ "\n…" if $shown.lines > 30;
            $shown = $shown.substr(0, 3000) ~ " …" if $shown.chars > 3000;
            if $shown eq '' && $err.trim {
                $shown = '(nothing on standard output; standard error says:)' ~ "\n" ~ $err.lines.head(4).join("\n");
            }
            elsif $shown eq '' {
                $shown = '(nothing: Raku++ accepts the program and prints nothing)';
            }
            @h.push: '<details class="engine-note"><summary>The editor’s engine, Raku++, prints something else here</summary>'
                   ~ '<pre>' ~ esc($shown) ~ '</pre>'
                   ~ '<p>Measured with ' ~ esc($rakupp-version) ~ '. The book shows the reference compiler’s output; the editor runs Raku++ compiled to WebAssembly.</p>'
                   ~ '</details>';
        }
    }
    @h.push: '</figure>';
    @h.join("\n")
}

sub render-blocks(Chapter $ch, Str $rakupp, Str $rakupp-version --> Str) {
    my @h;
    my $open = False;
    for $ch.blocks -> %b {
        given %b<type> {
            when 'h2' {
                my $c = %b<corner>;
                @h.push('</section>') if $open;
                $open = True;
                @h.push: '<section class="corner" id="' ~ $c.id ~ '" data-tags="' ~ $c.tags.join(' ') ~ '">'
                       ~ '<h2><a class="num" href="#' ~ $c.id ~ '">' ~ $c.num ~ '</a> '
                       ~ '<span class="t">' ~ inline($c.title) ~ '</span>' ~ tag-chips($c.tags) ~ '</h2>';
            }
            when 'h3'      { @h.push: '<h3>' ~ inline(%b<text>) ~ '</h3>' }
            when 'p'       { @h.push: '<p>' ~ inline(%b<text>) ~ '</p>' }
            when 'aside'   { @h.push: '<aside class="note"><p>' ~ inline(%b<text>) ~ '</p></aside>' }
            when 'ul'      { @h.push: '<ul>' ~ %b<items>.map({ '<li>' ~ inline($_) ~ '</li>' }).join ~ '</ul>' }
            when 'ol'      { @h.push: '<ol>' ~ %b<items>.map({ '<li>' ~ inline($_) ~ '</li>' }).join ~ '</ol>' }
            when 'pre'     { @h.push: '<pre class="plain">' ~ esc(%b<text>) ~ '</pre>' }
            when 'example' { @h.push: render-example(%b<ex>, $rakupp, $rakupp-version) }
            when 'table' {
                my @rows = |%b<rows>;
                my $head = @rows.shift;
                @h.push: '<div class="table-wrap"><table><thead><tr>' ~ $head.map({ '<th>' ~ inline($_) ~ '</th>' }).join ~ '</tr></thead><tbody>'
                       ~ @rows.map(-> $r { '<tr>' ~ $r.map({ '<td>' ~ inline($_) ~ '</td>' }).join ~ '</tr>' }).join
                       ~ '</tbody></table></div>';
            }
        }
    }
    @h.push('</section>') if $open;
    @h.join("\n")
}

# ---------------------------------------------------------------------------
# Page shell
# ---------------------------------------------------------------------------

my $SHELL = q:to/HTML/;
<!doctype html>
<html lang="en" data-theme="system">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%%TITLE%%</title>
<meta name="description" content="%%DESC%%">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;0,8..60,700;1,8..60,400&family=JetBrains+Mono:wght@400;600&display=swap">
<link rel="stylesheet" href="/theme/shell.css">
<link rel="stylesheet" href="%%BASE%%/assets/book.css?v=%%VER%%">
<script>%%THEME-SCRIPT%%</script>
</head>
<body class="%%BODY-CLASS%%">
<header class="top">
  <button class="nav-toggle" type="button" aria-label="Contents">☰</button>
  <a class="brand" href="%%BASE%%/">%%BOOK-TITLE%%</a>
  <span class="spacer"></span>
  <label class="predict" title="Hide every output until you reveal it"><input type="checkbox" id="predict-toggle"> <span>Predict<span class="wide"> mode</span></span></label>
  <a class="corners-link" href="%%BASE%%/corners/">All corners</a>
  <div class="theme-switch">
    <button class="theme-btn" type="button" aria-haspopup="true" aria-expanded="false" aria-label="Theme">◐</button>
    <ul class="theme-menu" role="menu" hidden>
      <li><button data-theme-set="system">◐ System</button></li>
      <li><button data-theme-set="light">☀ Light</button></li>
      <li><button data-theme-set="dark">☾ Dark</button></li>
    </ul>
  </div>
</header>
<div class="layout">
<nav class="toc" aria-label="Contents">%%TOC%%</nav>
<main class="page">
%%CONTENT%%
<footer class="site-foot">%%FOOT%%</footer>
</main>
</div>
<script src="/raku.js" data-selector="[data-raku-never]" data-playground="off" defer></script>
<script src="%%BASE%%/assets/book.js?v=%%VER%%" defer></script>
<script src="/theme/shell.js" defer></script>
</body>
</html>
HTML

my $THEME-SCRIPT = q:to/JS/;
(function () {
  var KEY = 'raku-theme', mql = window.matchMedia('(prefers-color-scheme: dark)');
  function stored() { try { return localStorage.getItem(KEY) || 'system'; } catch (e) { return 'system'; } }
  function eff(s) { return (s === 'dark' || (s === 'system' && mql.matches)) ? 'dark' : 'light'; }
  function apply(s) {
    var d = document.documentElement;
    d.setAttribute('data-theme', s);
    d.setAttribute('data-theme-active', eff(s));
  }
  apply(stored());
  mql.addEventListener('change', function () { if (stored() === 'system') apply('system'); });
  window.__applyTheme = apply;
  try { if (localStorage.getItem('corners-predict') === '1') document.documentElement.classList.add('predict-on'); } catch (e) {}
  try { if (localStorage.getItem('corners-toc-folded') === '1') document.documentElement.classList.add('toc-folded'); } catch (e) {}
})();
JS

sub page(Str :$title!, Str :$desc = '', Str :$toc!, Str :$content!, Str :$body-class = '' --> Str) {
    $SHELL.subst('%%THEME-SCRIPT%%', $THEME-SCRIPT.trim)
          .subst('%%TITLE%%', esc($title))
          .subst('%%DESC%%', esc-attr($desc))
          .subst('%%BOOK-TITLE%%', esc(%BOOK<title>))
          .subst('%%TOC%%', $toc)
          .subst('%%CONTENT%%', $content)
          .subst('%%FOOT%%', site-foot())
          .subst('%%BODY-CLASS%%', $body-class)
          .subst('%%BASE%%', $BASE, :g)
          .subst('%%VER%%', $VERSION, :g)
}

# Who made the book, on every page: the text is Claude's, the book is the
# Raku++ project's, and the editor initiated and coordinated it.
sub site-foot(--> Str) {
    my $colophon = %CHAPTER-BY-SLUG<colophon>;
    '<p><b>' ~ esc(%BOOK<title>) ~ '</b> · ' ~ esc(%BOOK<project>) ~ ' · Edited by ' ~ esc(%BOOK<editor>) ~ '</p>'
    ~ '<p>The text was written by Claude, Anthropic’s model, from the Raku++ project’s findings. '
    ~ 'Every output is checked against the reference compiler, ' ~ esc(%BOOK<oracle>) ~ '.'
    ~ ($colophon ?? ' <a href="' ~ $BASE ~ '/colophon/">Colophon</a>' !! '')
    ~ (%BOOK<repo> ?? ' · <a href="https://' ~ esc-attr(%BOOK<repo>) ~ '">Source</a>' !! '')
    ~ '</p>'
}

sub label-prefix($ch --> Str) { $ch.label ?? $ch.label ~ '. ' !! '' }

sub toc-html(@chapters, $current --> Str) {
    my @h;
    my $part = '';
    @h.push: '<a class="toc-home" href="' ~ $BASE ~ '/">Contents</a>';
    for @chapters -> $ch {
        if $ch.part ne $part {
            @h.push('</ol>') if $part;
            $part = $ch.part;
            @h.push: '<div class="toc-part">' ~ esc($part) ~ '</div><ol class="toc-list">';
        }
        my $is-cur = $current.defined && $current === $ch;
        my $fold = $is-cur && $ch.corners;
        @h.push: '<li' ~ ($is-cur ?? ' class="current' ~ ($fold ?? ' has-corners' !! '') ~ '"' !! '') ~ ' data-slug="' ~ $ch.slug ~ '">'
               ~ '<a href="' ~ $BASE ~ '/' ~ $ch.slug ~ '/"><span class="n">' ~ $ch.label ~ '</span><span class="t">' ~ inline($ch.title) ~ '</span></a>';
        if $fold {
            @h.push: '<button class="toc-fold" type="button" aria-expanded="true" aria-label="Hide this chapter’s corners" title="Hide the corners">▾</button>';
            @h.push: '<ol class="toc-corners">' ~ $ch.corners.map({
                '<li><a href="#' ~ .id ~ '"><span class="n">' ~ .num ~ '</span><span class="t">' ~ inline(.title) ~ '</span></a></li>'
            }).join ~ '</ol>';
        }
        @h.push: '</li>';
    }
    @h.push('</ol>') if $part;
    @h.join("\n")
}

sub chapter-page(@chapters, Int $idx, Str $rakupp, Str $rakupp-version --> Str) {
    my $ch = @chapters[$idx];
    my $prev = $idx > 0 ?? @chapters[$idx - 1] !! Nil;
    my $next = $idx < @chapters.end ?? @chapters[$idx + 1] !! Nil;
    my $kicker = $ch.kind eq 'colophon' ?? 'Colophon'
              !! esc($ch.part) ~ ' · ' ~ ($ch.kind eq 'appendix' ?? 'Appendix ' !! 'Chapter ') ~ $ch.label;
    my @h;
    @h.push: '<article class="chapter" data-slug="' ~ $ch.slug ~ '">';
    @h.push: '<header class="chapter-head"><div class="kicker">' ~ $kicker ~ '</div>'
           ~ '<h1>' ~ inline($ch.title) ~ '</h1>'
           ~ ($ch.summary ?? '<p class="summary">' ~ inline($ch.summary) ~ '</p>' !! '')
           ~ ($ch.corners ?? '<p class="meta">' ~ $ch.corners.elems ~ ' corners · ' ~ $ch.examples.elems ~ ' examples</p>' !! '')
           ~ '</header>';
    @h.push: render-blocks($ch, $rakupp, $rakupp-version);
    @h.push: '<footer class="chapter-foot">'
           ~ '<label class="done"><input type="checkbox" data-done="' ~ $ch.slug ~ '"> I have read this chapter</label>'
           ~ '<nav class="pager">'
           ~ ($prev ?? '<a class="prev" href="' ~ $BASE ~ '/' ~ $prev.slug ~ '/">← ' ~ label-prefix($prev) ~ inline($prev.title) ~ '</a>' !! '<span></span>')
           ~ ($next ?? '<a class="next" href="' ~ $BASE ~ '/' ~ $next.slug ~ '/">' ~ label-prefix($next) ~ inline($next.title) ~ ' →</a>' !! '<span></span>')
           ~ '</nav></footer>';
    @h.push: '</article>';
    page(title => $ch.title ~ ' — ' ~ %BOOK<title>, desc => $ch.summary,
         toc => toc-html(@chapters, $ch), content => @h.join("\n"), body-class => 'is-chapter')
}

sub home-page(@chapters, %stats --> Str) {
    my @h;
    @h.push: '<section class="cover">'
           ~ '<h1>' ~ esc(%BOOK<title>) ~ '</h1>'
           ~ '<p class="subtitle">' ~ esc(%BOOK<subtitle>) ~ '</p>'
           ~ '<p class="byline">' ~ esc(%BOOK<project>) ~ '</p>'
           ~ '<p class="editor"><i>Edited by</i> ' ~ esc(%BOOK<editor>) ~ '</p>'
           ~ '</section>';
    @h.push: '<section class="stats">'
           ~ '<div><b>' ~ %stats<corners> ~ '</b><span>corners</span></div>'
           ~ '<div><b>' ~ %stats<examples> ~ '</b><span>examples, each checked against the reference compiler, ' ~ esc(%BOOK<oracle>) ~ '</span></div>'
           ~ '<div><b>' ~ %stats<undocumented> ~ '</b><span>behaviours not in the official docs</span></div>'
           ~ '</section>';
    my %parts = %BOOK<parts>.list;
    my $part = '';
    @h.push: '<section class="contents">';
    for @chapters -> $ch {
        if $ch.part ne $part {
            @h.push('</ol></div>') if $part;
            $part = $ch.part;
            @h.push: '<div class="part"><h2>' ~ esc($part) ~ '</h2>'
                   ~ (%parts{$part} ?? '<p class="part-intro">' ~ inline(%parts{$part}) ~ '</p>' !! '')
                   ~ '<ol class="chapters">';
        }
        @h.push: '<li data-slug="' ~ $ch.slug ~ '"><a href="' ~ $BASE ~ '/' ~ $ch.slug ~ '/">'
               ~ '<span class="n">' ~ $ch.label ~ '</span>'
               ~ '<span class="t">' ~ inline($ch.title) ~ '</span>'
               ~ '<span class="c">' ~ ($ch.corners ?? $ch.corners.elems ~ ' corners' !! '') ~ '</span></a>'
               ~ ($ch.summary ?? '<p>' ~ inline($ch.summary) ~ '</p>' !! '') ~ '</li>';
    }
    @h.push('</ol></div>') if $part;
    @h.push: '</section>';
    page(title => %BOOK<title>, desc => %BOOK<subtitle>, toc => toc-html(@chapters, Nil),
         content => @h.join("\n"), body-class => 'is-home')
}

sub corners-page(@chapters, %stats --> Str) {
    my @h;
    @h.push: '<header class="chapter-head"><div class="kicker">Index</div><h1>All corners</h1>'
           ~ '<p class="summary">Every corner in the book, by chapter. Filter by kind or search the titles.</p></header>';
    @h.push: '<div class="filters"><input type="search" id="corner-search" placeholder="Search corners…" aria-label="Search corners">'
           ~ '<div class="chips">' ~ '<button class="chip on" data-tag="">All</button>'
           ~ @TAG-ORDER.grep({ %stats<tag>{$_} }).map({
                 '<button class="chip tag-' ~ $_ ~ '" data-tag="' ~ $_ ~ '">' ~ esc(%TAGS{$_}) ~ ' <span>' ~ %stats<tag>{$_} ~ '</span></button>'
             }).join
           ~ '</div></div>';
    @h.push: '<div class="corner-index">';
    for @chapters.grep(*.corners) -> $ch {
        @h.push: '<div class="ci-chapter"><h2><a href="' ~ $BASE ~ '/' ~ $ch.slug ~ '/">' ~ $ch.label ~ '. ' ~ inline($ch.title) ~ '</a></h2><ul>';
        for $ch.corners -> $c {
            @h.push: '<li data-tags="' ~ $c.tags.join(' ') ~ '"><a href="' ~ $BASE ~ '/' ~ $ch.slug ~ '/#' ~ $c.id ~ '">'
                   ~ '<span class="n">' ~ $c.num ~ '</span> ' ~ inline($c.title) ~ '</a>' ~ tag-chips($c.tags) ~ '</li>';
        }
        @h.push: '</ul></div>';
    }
    @h.push: '</div>';
    page(title => 'All corners — ' ~ %BOOK<title>, toc => toc-html(@chapters, Nil),
         content => @h.join("\n"), body-class => 'is-index')
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

sub asset-version(@paths --> Str) {
    # A cheap content fingerprint: total length and a rolling sum of code points.
    my $sum = 0;
    my $len = 0;
    for @paths.sort -> $p {
        my $s = slurp($p);
        $len += $s.chars;
        $sum = ($sum * 31 + $s.ords.sum) % 4294967291;
    }
    ($sum.base(36) ~ $len.base(36)).lc.substr(0, 10)
}

# The divergence report: for every verified chapter, each example on which
# Raku++ disagrees with Rakudo, with the code and both outputs. Rakudo's side
# is the verified one. Chapters that are not fully verified are listed and
# skipped, so nothing in the report rests on an unchecked output.
sub fence(Str $s --> Str) { "```\n" ~ ($s eq '' ?? '(nothing)' !! $s) ~ "\n```" }
sub excerpt(Str $s, Int $lines = 12 --> Str) {
    my @l = strip-nl($s).lines;
    @l.elems > $lines ?? (|@l.head($lines), "… (" ~ (@l.elems - $lines) ~ " more lines)").join("\n") !! @l.join("\n")
}
sub write-report(Str $path, @chapters, %unverified, Str $rakudo-version, Str $rakupp-version) {
    my @rows;
    my @body;
    my ($all-n, $all-diff) = 0, 0;
    for @chapters -> $ch {
        next unless $ch.examples;
        if %unverified{$ch.slug} {
            @rows.push: '| ' ~ label-prefix($ch) ~ $ch.title ~ ' | — | — | not fully verified yet |';
            next;
        }
        my @both = $ch.examples.grep({ .rakupp.defined && .rakudo.defined });
        my @diff = @both.grep({ engines-differ($_) });
        $all-n += @both.elems;
        $all-diff += @diff.elems;
        @rows.push: '| ' ~ label-prefix($ch) ~ $ch.title ~ ' | ' ~ @both.elems ~ ' | '
                  ~ (@both.elems - @diff.elems) ~ ' | ' ~ @diff.elems ~ ' |';
        next unless @diff;
        @body.push: '## ' ~ label-prefix($ch) ~ $ch.title, '';
        # The corner each example belongs to: the last corner heading before it.
        my %corner-of;
        my $cur;
        for $ch.blocks -> %b {
            $cur = %b<corner> if %b<type> eq 'h2';
            %corner-of{%b<ex>.id} = $cur if %b<type> eq 'example' && $cur.defined;
        }
        for @diff -> $ex {
            my $c = %corner-of{$ex.id};
            @body.push: '### ' ~ ($c ?? $c.num ~ ' ' ~ $c.title !! $ex.id) ~ ($ex.kind eq 'local' ?? ' (local)' !! ''), '';
            @body.push: '`' ~ $ex.file ~ ':' ~ $ex.line ~ '`', '';
            @body.push: "```raku\n" ~ $ex.code ~ "\n```", '';
            my ($rx, $ro, $re) = |$ex.rakudo;
            my ($px, $po, $pe) = |$ex.rakupp;
            @body.push: 'Rakudo' ~ ($rx ?? " (exit $rx)" !! '') ~ ':', '', fence(excerpt($ro)), '';
            @body.push: 'stderr:', '', fence(excerpt($re, 6)), '' if $re.trim;
            @body.push: 'Raku++' ~ ($px ?? " (exit $px)" !! '') ~ ':', '', fence(excerpt($po)), '';
            @body.push: 'stderr:', '', fence(excerpt($pe, 6)), '' if $pe.trim;
        }
    }
    my $head = qq:to/END/;
    # Raku++ against the examples of *Raku Behind the Docs*

    Generated by `rakupp build.raku --verify --report=…` in the
    raku-behind-the-docs repository (github.com/ash/raku-behind-the-docs) on
    {Date.today}. Do not edit by hand; regenerate it.

    - Oracle: Rakudo {$rakudo-version ~~ / v\d+ [\.\d+]+ / ?? ~$/ !! $rakudo-version} — every Rakudo output below is the one the book
      prints and the build verifies.
    - Raku++: {$rakupp-version}.

    An example counts as a divergence when Raku++'s standard output differs from
    Rakudo's, or when one engine rejects the program and the other runs it.
    Standard error is shown for context; its wording is not compared. Examples
    marked *(local)* touch files, processes or threads: the book shows them
    without a Run button, and they were run here natively.

    In total Raku++ matches Rakudo on {$all-n - $all-diff} of {$all-n} examples.

    | chapter | examples run on both | Raku++ matches | differs |
    |---|---|---|---|
    END
    spurt $path, $head ~ @rows.join("\n") ~ "\n\n" ~ @body.join("\n") ~ "\n";
    note "report: $all-diff divergences in $all-n examples -> $path";
}

sub MAIN(
    Bool :$verify = False,         #= run uncached examples on both engines
    Bool :$clean = False,          #= remove out/ before building
    Str  :$rakudo = '/opt/homebrew/bin/rakudo',   #= the oracle
    Str  :$rakupp = 'rakupp',      #= the engine the editors run
    Str  :$only = '',              #= work on the chapters whose slug contains this; others may be mid-edit
    Bool :$prune = False,          #= drop cache entries this build did not use (full builds only)
    Bool :$fresh = False,          #= with --verify: run cached examples again and report any whose output changed
    Int  :$timeout = 20,           #= seconds per example run
    Str  :$report = '',            #= write a Markdown list of every example where Raku++ differs from Rakudo
    Str  :$out = OUT,              #= where to write the site
    Str  :$exclude = '',           #= leave out, entirely, the chapters whose slug contains any of these comma-separated words
) {
    %BOOK = EVAL slurp(SRC ~ '/book.raku');
    $BASE = %BOOK<mount> // '';
    my &selected = -> $ch { !$only || $ch.slug.contains($only) };
    $FRESH = $fresh;

    my $OUT = $out;
    my @files = dir(SRC ~ '/chapters').map(*.Str).grep(*.ends-with('.md')).sort;
    # A chapter still being written can be left out of a publishable build.
    my @drop = $exclude.split(',').grep(*.chars);
    @files = @files.grep(-> $f { my $b = $f.IO.basename; !@drop.first({ $b.contains($_) }) }) if @drop;
    my @chapters;
    my @bodies;
    for @files.kv -> $pos, $f {
        my ($ch, $body) = load-chapter($f, $pos);
        @chapters.push($ch);
        @bodies.push($body);
    }
    # Chapters are numbered by position; appendices are lettered A, B, ...;
    # the colophon has no number.
    my $cn = 0;
    my $an = 0;
    for @chapters -> $ch {
        if $ch.kind eq 'appendix' {
            $ch.label = ('A'.ord + $an++).chr;
        }
        elsif $ch.kind eq 'colophon' {
            $ch.label = '';
        }
        else {
            $ch.num = $cn;
            $ch.label = ~$cn;
            $cn++;
        }
        %CHAPTER-BY-SLUG{$ch.slug} = $ch;
    }
    # With --only, a chapter somebody else is still writing must not stop
    # this build: its parse errors become warnings and it is left out.
    my @keep;
    for @chapters.kv -> $i, $ch {
        if $only && !selected($ch) {
            my $ok = True;
            try {
                $ch.blocks = parse-blocks($ch, @bodies[$i]);
                CATCH { default { note "skipping {$ch.path}: {.message}"; $ok = False } }
            }
            @keep.push($ch) if $ok;
        }
        else {
            $ch.blocks = parse-blocks($ch, @bodies[$i]);
            @keep.push($ch);
        }
    }
    @chapters = @keep;

    my $rakudo-version = engine-version($rakudo);
    my $rakupp-version = engine-version($rakupp);
    note "oracle: $rakudo-version";
    note "editor engine: $rakupp-version";
    load-cache('rakudo');
    load-cache('rakupp');

    my @failures;
    my @warnings;
    my $elsewhere = 0;
    my $ran = 0;
    my $missing = 0;
    my %unverified;
    for @chapters -> $ch {
        my $mine = selected($ch);
        my $run-missing = $verify && $mine;
        for $ch.examples -> $ex {
            next if $ex.kind eq 'nocheck';
            my $before = %CACHE<rakudo>{cache-key($rakudo-version, $ex)}:exists;
            $ex.rakudo = result-for('rakudo', $rakudo, $rakudo-version, $ex, $run-missing, $timeout);
            $ran++ if $ex.rakudo.defined && !$before;
            if $ex.kind eq 'run' || ($report && $ex.kind eq 'local') {
                $ex.rakupp = result-for('rakupp', $rakupp, $rakupp-version, $ex, $run-missing, $timeout);
            }
            unless $ex.rakudo.defined {
                $missing++ if $mine;
                %unverified{$ch.slug} = True;
                next;
            }
            my ($exit, $out, $err) = |$ex.rakudo;
            my $where = $ex.file ~ ':' ~ $ex.line;
            my @f;
            # A path under the build directory would publish this machine's layout.
            @f.push: "$where: the output contains the build's absolute path; print a relative path or a test instead"
                if $out.contains($*CWD.Str) || $err.contains($*CWD.Str) || $out.contains($*HOME.Str) || $err.contains($*HOME.Str);
            if strip-nl($out) ne $ex.expected {
                @f.push: "$where: Rakudo printed\n" ~ $out.lines.map({ '    | ' ~ $_ }).join("\n")
                       ~ "\n  the book says\n" ~ $ex.expected.lines.map({ '    | ' ~ $_ }).join("\n");
            }
            if $ex.expected-err.defined {
                if strip-nl($err) ne $ex.expected-err {
                    @f.push: "$where: Rakudo's stderr was\n" ~ $err.lines.map({ '    | ' ~ $_ }).join("\n")
                           ~ "\n  the book says\n" ~ $ex.expected-err.lines.map({ '    | ' ~ $_ }).join("\n");
                }
            }
            elsif $err.trim && $mine {
                @warnings.push: "$where: undeclared stderr: " ~ $err.lines.head;
            }
            if $exit != 0 && !$ex.expected-err.defined && $mine {
                @warnings.push: "$where: exit code $exit";
            }
            %unverified{$ch.slug} = True if @f;
            if $mine {
                @failures.append: @f;
            }
            else {
                $elsewhere += @f.elems;
            }
        }
    }
    save-cache('rakudo', $prune) if $verify;
    save-cache('rakupp', $prune) if $verify;
    run 'rm', '-rf', $RUN-DIR if $RUN-DIR.IO.d;

    note "ran $ran new example(s) on the oracle" if $ran;
    if @FLICKER {
        note "\n" ~ @FLICKER.elems ~ " example(s) printed something different when run again:";
        note "    $_" for @FLICKER;
        exit 1;
    }
    note "every re-run example printed the same output again" if $fresh && $verify;
    note "$missing example(s) have no cached result yet — build with --verify" if $missing;
    note "$elsewhere example(s) outside --only=$only disagree with the oracle (not checked here)" if $elsewhere;
    .note for @warnings;
    write-report($report, @chapters, %unverified, $rakudo-version, $rakupp-version) if $report;
    if @failures {
        note "\n" ~ @failures.elems ~ " example(s) disagree with the oracle:\n";
        .note for @failures;
        exit 1;
    }

    my %stats = corners => 0, examples => 0, undocumented => 0, tag => {};
    for @chapters -> $ch {
        %stats<corners> += $ch.corners.elems;
        %stats<examples> += $ch.examples.elems;
        for $ch.corners -> $c {
            %stats<tag>{$_}++ for $c.tags;
        }
    }
    %stats<undocumented> = %stats<tag><undocumented> // 0;

    run 'rm', '-rf', $OUT if $clean && $OUT.IO.d;
    mkdir $OUT unless $OUT.IO.d;
    mkdir $OUT ~ '/assets' unless ($OUT ~ '/assets').IO.d;
    my @theme = dir(SRC ~ '/assets').map(*.Str);
    $VERSION = asset-version([|@theme, |@files]);
    for @theme -> $t { copy $t, $OUT ~ '/assets/' ~ $t.IO.basename }
    spurt $OUT ~ '/CNAME', %BOOK<domain> ~ "\n" if %BOOK<domain>;

    spurt $OUT ~ '/index.html', home-page(@chapters, %stats);
    mkdir $OUT ~ '/corners' unless ($OUT ~ '/corners').IO.d;
    spurt $OUT ~ '/corners/index.html', corners-page(@chapters, %stats);
    for @chapters.kv -> $i, $ch {
        next if $only && !selected($ch);
        my $dir = $OUT ~ '/' ~ $ch.slug;
        mkdir $dir unless $dir.IO.d;
        spurt $dir ~ '/index.html', chapter-page(@chapters, $i, $rakupp, $rakupp-version);
    }

    my $differs = 0;
    my $runnable = 0;
    for @chapters -> $ch {
        for $ch.examples.grep({ .kind eq 'run' && .rakupp.defined && .expected.defined }) -> $ex {
            $runnable++;
            $differs++ if engines-differ($ex);
        }
    }
    note "built {+@chapters} chapter(s), {%stats<corners>} corners, {%stats<examples>} examples -> {$OUT}/";
    note "Raku++ matches Rakudo on {$runnable - $differs} of $runnable runnable examples" if $runnable;
}
