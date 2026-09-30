---
name: mydef
description: Write MyDef code
---

## Overview
MyDef is a template format for text, mainly used for writing source code.
MyDef files use extension `.def` and whitespace indentation similar to Python.
To convert e.g. `prog.def` to output, run `mydef_page prog.def`. For example, `mydef_page mymake.def` compiles and outputs to `mymake/mymake.pl` (the output directory is set by `output_dir:`). When in doubt about how MyDef syntax expands, run `mydef_page` and check the output to confirm.
Use `mydef_run prog.def` to compile and run the generated script in one step.

## Environment
`$HOME/.bashrc` exports `PERL5LIB`, `MYDEFLIB` and `MYDEFSRC`, which `mydef_page`,
`mydef_run`, `mydef_make`, etc. need. They are normally already set. If
`echo $MYDEFSRC` comes back empty, export them in the Bash call:

    export PERL5LIB=$HOME/lib/perl5 MYDEFLIB=$HOME/lib/MyDef MYDEFSRC=$HOME/projects/MyDef

## Installed modules
Each `module:` value needs a `MyDef::output_<module>` Perl module in
`$PERL5LIB/MyDef/`. Besides the built-in ones from MyDef itself (perl and
general), these are installed from separate repos in `$HOME/projects/`:

| Repo | Modules | Skill |
|------|---------|-------|
| output_www | www, php, js | mydef-html |
| output_c | c, cpp | mydef-c |
| output_python | python | mydef-python |
| output_sh | sh | mydef-sh |
| output_java | java | (none yet; see manual chapter) |

To install another module, or rebuild one after editing its repo, use the
mydef-modules skill.

In MyDef repos, `out/` is the conventional `output_dir`. It's untracked but
kept for examining generated output, and it is `mydef_run`'s scratch place.

## Top-level Directives

### page
Indented text below `page: name` generates a file named "name":

    page: t.sh
        echo "Hello World!"

A single .def file may contain multiple pages. Use `output_dir: path` to set where generated files go.

### module
`module: perl` or `module: c` sets the target language, which determines how keywords like `$if`, `$for`, `$local`, `$global` expand.

    page: t
        module: perl
        $print "Hello"

### include
`include: path.def` at top level includes other .def files for their macros and subcodes.

### macros
`macros:` defines text substitution macros as `key: value`. Use `$(key)` to expand:

    macros:
        project: startrek

    page: t.txt
        The project is $(project).

#### Macro parameters
Use `$1`, `$2`, ..., `$9` as placeholders:

    macros:
        add_one: $1 + 1

Then `$(add_one:10)` expands to `10 + 1`. Multiple parameters: `$(A:p1, p2)`.

## Subcodes

### subcode (single-line macro blocks)
`subcode: name(params)` defines a multi-line template invoked via `$call name, args`:

    subcode: greet(who)
        print "Hello, $(who)!\n"

    page: t.pl
        module: perl
        $call greet, World

### $call vs &call
- `$call name, args` — simple inline expansion of the subcode
- `&call name, args` — wraps the subsequent indented block as `BLOCK` inside the subcode

Example with `&call`:

    subcode: open_r(filename)
        open In, "$(filename)" or die
        while(<In>){
            BLOCK
        }
        close In

    page: t.pl
        module: perl
        &call open_r, data.txt
            chomp
            print "$_\n"

The indented code under `&call` replaces `BLOCK` in the subcode definition.

### subcode:: (double colon) — append
`subcode:: name` appends to an existing subcode rather than redefining it. This allows extending subcodes across files.

### $call @name — optional call
`$call @name` calls the subcode if it is defined, silently skips if not. Useful for extensibility hooks.

### Nested subcodes
Subcodes can be defined inside other subcodes (indented under them). They are scoped to the parent.

## Compile-time vs Runtime Directives

### Compile-time (MyDef expansion time)
These operate on macros during .def processing:

- `$(if:condition)` / `$(else)` — conditional expansion based on macro values
- `$(for:a, b, c)` — iterate over a list, expanding with `$1`
- `$(set:key=value)` / `$(setmacro:key=value)` — define macros within a page/subcode

Example:

    $(for:mpl, pmi)
        process_$1()

Expands to:

    process_mpl()
    process_pmi()

### Runtime (target language)
These generate code in the target language (Perl, C, etc.):

- `$if`, `$elif`, `$else` — if-statements (no parens/braces needed)
- `$for i = 0:n` — counted loop
- `$foreach $item in @list` — iteration over collections
- `$while condition` — while loop
- `$switch` / `$of` — switch/case

## Language Keywords (module-dependent)

Special syntax like `$if`, `$for`, `$foreach`, `$while` generates the correct corresponding syntax in whatever output language is specified by `module:`. This allows common patterns to be expressed consistently across languages (Perl, C, Python, etc.). You can assume they produce correct idiomatic code in the target language.

### Variables
- `$local varname` — local variable declaration
- `$global varname` — global variable declaration
- `$my` — alias for local (Perl style)

### Output
- `$print message` — print with automatic newline
- `$print message-` — print without newline (trailing `-`)

### Functions
- `fncode: funcname(params)` — define a function
- `fncode: funcname(params) : returntype` — with return type (C)

### Perl-specific
- `$use Module` — use statement
- `%hash` iteration with `$k`, `$v` in `$foreach`

### C-specific
- `$include "header.h"` — #include
- `$list func1, func2` — forward declarations
- `$param ...` — function parameters
- `$call fcall, expr` — function call with error checking

## Common Patterns

### File I/O (Perl)
Built-in subcodes for file operations:

    &call open_r, filename
        # $_ has each line
        chomp
        process($_)

    &call open_w, filename
        print Out "content\n"

    &call open_W, filename
        $print content

### Looping with $(for:...)
Compile-time loop useful for repetitive patterns:

    $(for:CC,CXX,F77,FC)
        $if $opts{$1}
            $ENV{$1} = $opts{$1}

### Conditional compilation
    $(if:_pagename=mymake)
        # only in mymake page
    $(else)
        # in other pages

### Pattern: subcode with BLOCK for wrapping

    subcode: with_lock(mutex)
        lock($(mutex))
        BLOCK
        unlock($(mutex))

    &call with_lock, my_mutex
        do_work()

## Comments
Use `#` for comments in MyDef (replaces `//` in C context).

## Standard Library

Builtin macros like `open_r`, `open_w` are defined in module autoload libraries at `$MYDEFLIB`. For `module: perl`, the file is `$MYDEFLIB/std_perl.def`. When unsure how a builtin macro expands, check the corresponding std file.

### Key builtins in std_perl.def

- `&call open_r, <file>` — opens file with filehandle `In`, iterates with `$while <In>` setting `$_`
- `&call open_w, <file>` — opens file with filehandle `Out` for writing (auto-prefixes `>`)
- `&call open_W, <file>` — variant of open_w
- When nesting `open_r` inside `open_w` (or vice versa), use a different filehandle to avoid conflicts (e.g. `In2`)
- Prefer simple `system` calls (e.g. `system "cp $src $dst"`) over pure-Perl reimplementations when appropriate
