# Book configuration, EVAL'd by build.raku. Every key is quoted: a bare key
# named like a declarator (`sub`, `class`) would parse as a declaration.
{
    'title'    => 'Raku Behind the Docs',
    'subtitle' => 'What the language actually does, one checked example at a time',
    'project'  => 'The Raku++ project',
    'editor'   => 'Andrew Shitov',
    'oracle'   => 'Rakudo v2026.08',
    'url'      => 'https://raku.online/deep/',
    'repo'     => 'github.com/ash/raku-behind-the-docs',
    'mount'    => '/deep',
    'parts'    => [
        'Reading the code' =>
            'How the compiler decides what a line means: which operator takes the operand, what a quote does to its text, how whitespace changes a parse, and what happens to a value nobody uses.',
        'Nothing and numbers' =>
            'Undefined values, the numeric tower and strings: the values every program starts from, and the edges where they surprise.',
        'Collections' =>
            'Lists, arrays, hashes, ranges, sequences, sets and buffers: what each container holds, when it is lazy, and what an empty one answers.',
        'Code' =>
            'Signatures, exceptions, regexes and grammars: the behaviour of the code you write rather than the data it handles.',
        'Time and the outside world' =>
            'Dates, files and processes: the parts of Raku that talk to the machine.',
        'Concurrency' =>
            'Promises, locks, supplies: what runs when, and in which order the events arrive.',
        'Appendices' =>
            'Reference material gathered from the chapters.',
    ],
}
