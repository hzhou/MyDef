# MyDef Design

MyDef is a self-bootstrapping meta-programming system. Its source is written in
its own `.def` format and compiles to Perl. The compiler transforms `.def` files
into output in any target language (Perl, C, Python, etc.) through a pluggable
module system.

## Pipeline

The compilation pipeline has four stages:

    .def file
       |
       v
    parseutil  -- parse indentation-based syntax into $def structure
       |
       v
    compileutil -- expand macros/subcodes, drive output module callbacks
       |
       v
    output_*   -- language-specific parsecode (syntax sugar -> target code)
       |
       v
    dumpout    -- flatten nested blocks, resolve indentation, emit text

### parseutil (parseutil.def)

Reads `.def` files and builds an internal data structure (`$def`) containing:

- `pages` -- hash of page definitions
- `pagelist` -- ordered list of page names
- `codes` -- subcodes and fncodes (merged at end)
- `macros` -- compile-time macro definitions

Key responsibilities:

- Indentation tracking (converts leading whitespace to `SOURCE_INDENT`/`SOURCE_DEDENT` markers)
- `include:` directive processing with search path (`@path`, `$MYDEFLIB`)
- `page:` block parsing (page-level attributes like `type`, `output_dir`, `package`)
- `macros:` block parsing
- `subcode:`/`fncode:` block parsing (with parameters, type tags)
- `template:` expansion
- Comment filtering (`#` lines, `/* */` blocks)
- Multi-file import with include ordering (main file first, then includes, then standard includes)

### compileutil (compileutil.def)

The compiler core. Drives the output module through a five-callback interface
and manages macro expansion and subcode invocation.

Key responsibilities:

- Macro expansion -- `$(name)` lookups through a `$deflist` scope chain
  (`[def_root, macros, page]` plus dynamically pushed scopes)
- Compile-time directives -- `$(if:...)`, `$(set:...)`, `$(for:...)`,
  `$(setmacro:...)`, `$(export:...)`
- Subcode invocation -- `$call name, args` resolves and inlines subcode bodies,
  with `BLOCK` insertion for caller-provided content
- Named blocks -- `DUMP_STUB name` for deferred insertion points
- Output block management -- multiple output streams via `fetch_output`/`set_output`
- `_autoload` subcodes -- run once per page before `main`
- Frame support -- `page._frame` or `basic_frame` wraps the main code
- Interface push/pop -- allows temporary switching of output modules (e.g. for
  embedded languages)

### Output modules (output.def, output_*.def)

Each output module provides five callbacks registered via `get_interface()`:

| Callback     | Purpose                                      |
|--------------|----------------------------------------------|
| `init_page`  | Per-page initialization, set file extension   |
| `parsecode`  | Line-by-line translation of MyDef syntax      |
| `set_output` | Switch the current output stream              |
| `modeswitch` | Handle mode changes (e.g. HTML vs JS vs PHP)  |
| `dumpout`    | Final output pass, add language boilerplate    |

`output.def` provides two base templates:

- **`output_main`** -- Full base implementation. Subcode hooks (`@on_init_page`,
  `@parsecode`, `@dumpout`, etc.) let modules inject behavior.
- **`inherit(M)`** -- Inheritance pattern. Delegates to a parent module and
  intercepts callbacks via `@on_*` hooks. Used by modules like `output_www`
  (inherits from `output_perl`).

Common `parsecode` features shared across modules (in `parsecode_common`):

- `DUMP_STUB` passthrough
- `$plugin` registration and dispatch
- `$eval` for runtime code evaluation
- `CALLBACK` handling
- `DEBUG` mode toggling

#### output_general (output_general.def)

Minimal module. Sets extension to `txt`. Its `parsecode` delegates entirely to
`parsecode_common`, which by default just pushes lines to the output buffer.

#### output_perl (output_perl.def)

Rich Perl code generation with syntax sugar:

- `$if`/`$elif`/`$else` with regex capture (`-> $var`)
- `$while`, `$for`, `$foreach` (with `in`, hash iteration, zip, index variants)
- `$global`, `$my` -- variable declarations (globals become `our`)
- `$sub name(params)` -- subroutine definitions
- `$print`/`$die`/`$warn` -- with color support (`$red{...}`, `$green{...}`)
- `$use` -- module imports
- `$dump` -- debug printing (auto-imports `Data::Dumper` for hash dumps)
- `fncode:` -- named functions with parameter unpacking
- Auto-semicolons -- appends `;` to lines that don't end with `,`, `(`, `[`, `{`, or `;`
- `break`/`continue` -- translated to `last`/`next`
- Package and `#!` preamble generation
- `$sumcode` for tensor-style summation loops

### dumpout (dumpout.def)

Final pass that converts the internal output list into indented text lines.
Processes directives:

- `INDENT`/`DEDENT` -- increment/decrement indentation (4 spaces per level)
- `PUSHDENT`/`POPDENT` -- save/restore indentation level
- `DUMP_STUB name` -- inline a named block (deferred insertion)
- `INSERT_STUB[sep] name` -- insert into a `{STUB}` placeholder
- `INCLUDE_FILE path` -- inline a file verbatim
- `INCLUDE_BLOCK name` -- inline a named block from the dump context
- `BLOCK_N` -- inline a numbered output block
- `NEWLINE` / `NEWLINE?` -- explicit/conditional blank lines
- `<-|` -- left-aligned output (no indentation, e.g. C preprocessor directives)
- `SOURCE_INDENT`/`SOURCE_DEDENT` -- from the parser, also adjusts indentation
- `\xNN` escape processing

## Core Abstractions

### Pages

A page is the top-level compilation unit. Each `page:` block becomes one output
file. Page attributes:

    page: name
        type: pl          # file extension
        output_dir: lib   # output directory
        module: perl      # which output module to use
        package: Foo::Bar # language-specific (Perl package name)

Multiple pages can exist in one `.def` file. Pages can reference a `_frame`
subcode that wraps the main content.

### Subcodes

Reusable code fragments, the primary abstraction mechanism:

    subcode: greet(name)
        print "Hello, $(name)\n"

- Invoked via `$call greet, World`
- Support parameters (positional, expanded as macros)
- `BLOCK` keyword -- replaced by caller-provided indented content (`&call`)
- `subcode::` (double colon) -- append to existing subcode
- `subcode:@` -- marks extension points (`$call @hook` is a no-op if undefined)
- Scope: page-local subcodes override def-level subcodes

### Fncodes

Like subcodes but generate actual functions in the target language:

    fncode: add($a, $b)
        return $a + $b

In Perl output, this becomes `sub add { my ($a, $b) = @_; ... }`.

### Macros

Compile-time text substitution via `$(name)`:

    macros:
        greeting: Hello

    $print $(greeting), World!

Compile-time directives:

- `$(if:cond)` / `$(elif:...)` / `$(else)` / `$(endif)` -- conditional compilation
- `$(set:name=value)` -- set macro in current scope
- `$(setmacro:name=value)` -- set macro with re-expansion
- `$(for:a,b,c)` -- compile-time iteration
- `$(export:name=value)` -- propagate macro to outer scope

### Modules

Language backends registered in `modules.def`. The module list is built at
compile time using `$(setmacro:...)`:

    macros:
        module_list: general, perl

    subcode: _autoload
        $map add_module, c, sh, xs, cpp, java, go, ...

Each module name maps to `MyDef::output_NAME` and is loaded on demand via
`require`. The `check_module` function in `mydef.def` dispatches to the correct
module using a compile-time `$map` over `$(module_list)`.

## Tool Scripts

All tool scripts are themselves `.def` files that compile to Perl scripts
(placed in `script/`).

### mydef_page (mydef_page.def)

Main compiler CLI:

    mydef_page source.def

Reads `config` file for defaults, parses the `.def` file, and generates output
for each page. Supports `-m` (module override), `-o` (output dir), `-f` (find
subcode), `-dump` (dump structure), `-pipe` (stdin/stdout mode).

### mydef_run (mydef_run.def)

Compile-and-execute:

    mydef_run source.def

Compiles the `.def` file then runs the result. Dispatches by output file type:

- Compiled languages (C, Fortran, Rust, etc.) -- compile then execute
- Scripted languages (Perl, Python, etc.) -- run with interpreter
- Supports `/* expect: ... */` blocks for inline test assertions

Module guessing: scans the source for hints (e.g. `module:` directive,
`include: perl/`, or Perl-like syntax like `my $var`).

### mydef_make (mydef_make.def)

Build system generator:

    mydef_make

Scans the current directory for `.def` files, reads their page definitions and
include dependencies, and generates a `Makefile`. Features:

- Recursive subdirectory processing
- Dependency tracking across includes
- Groups pages by output directory into Makefile variables
- Module-specific Makefile generation (e.g. C compilation rules)
- Copylist support for static assets

### mydef_test (mydef_test.def)

Test runner. Reads a `TESTS` file listing `.def` files and runs each via
`mydef_run`. Reports pass/fail counts.

### mydef_install (mydef_install.def)

Installs compiled outputs to system directories:

- `*.def` -> `$MYDEFLIB`
- `*.pm` -> `$PERL5LIB`
- Scripts -> `$PATH` (or `$MYDEFBIN`)

### mydef_update (mydef_update.def)

Pulls latest source from git, rebuilds, and reinstalls MyDef and all
`output_*` extension modules.

## Supporting Modules

### utils (mydef_utils.def)

Utility functions used throughout:

- `proper_split` -- comma-split respecting balanced brackets and quotes
- `expand_macro` -- recursive `$(...)` expansion with nested parenthesis handling
- `get_tlist` / `get_range` -- range expansion (`0..9`, `a..z`, `0x0..0xf`)
- `for_list_expand` -- pattern expansion with `$1`/`*` replacement, `and`/`mul` combinators

### ext (mydef_ext.def)

Extension API for user `perlcode:` blocks to interact with compiler internals:

- `grab_codelist` -- retrieve the last grabbed code block
- `inject_sub` -- programmatically define new subcodes
- `run_src` -- compile and run a source array
- `grab_ogdl` -- parse structured data (OGDL-like key-value format)

### dumpout (dumpout.def)

See the pipeline section above.

## Self-Bootstrapping

MyDef compiles itself. The `.def` source files use MyDef syntax (`$if`,
`$foreach`, `$call`, `$(macro)`, subcodes) to generate the Perl `.pm` modules
that implement the MyDef compiler. The bootstrap process:

1. `bootstrap.sh` uses a pre-compiled copy (in `mydef_boot/`) to compile the
   `.def` sources
2. The compiled output replaces the running compiler
3. The new compiler can then recompile itself

The `macros_*` directories contain the reusable subcode libraries that implement
the compiler's own features -- parsing, macro expansion, compilation, and output
generation.
