# Manual Improvement Plan

## Goals

1. A new user can install MyDef and produce working output within 30 minutes
2. Each core concept is explained with input, generated output, and execution result
3. All output modules shipped in the base repo are documented (general, perl)
4. The reference sections are usable without reading source code

## Phase 1: Add a Tutorial Chapter (after Introduction, before Syntax)

Insert a new chapter "Getting Started" between Introduction and Installations.

### 1.1 Hello World (output_general)

- Create a minimal `hello.def` with one page
- Show running `mydef_page hello.def` and the resulting `.txt` file
- Explain the three things that happened: parse, compile, dump

### 1.2 Hello World (output_perl)

- Same idea but with `module: perl`
- Show `mydef_run hello.def` for the compile-and-execute cycle
- Show the generated `.pl` side by side with the `.def` source
- Point out what MyDef added (`#!`, `use strict;`, semicolons)

### 1.3 First Subcode

- Extract repeated code into a subcode, show before/after output
- Introduce `$call` and parameters

### 1.4 First Block Call

- Wrap open/close pattern with `&call` and `BLOCK`
- Show the generated output to demystify `BLOCK` replacement

### 1.5 First Macro

- Use `macros:` and `$(name)` for a value used in multiple places
- Show `$(set:...)` for local scope

### 1.6 Project Workflow

- Create a `config` file, run `mydef_make`, run `make`
- Explain the typical edit-compile-test cycle with `mydef_run`

## Phase 2: Improve the Syntax Chapter

### 2.1 Add a concept summary table

At the start of the Syntax chapter, add a quick-reference table:

| Concept | Definition syntax | Usage syntax | Scope |
|---------|-------------------|--------------|-------|
| Page | `page: name` | (compiled automatically) | file |
| Subcode | `subcode: name(params)` | `$call name, args` | global or page |
| Block call | (same subcode with `BLOCK`) | `&call name, args` | nested |
| Macro | `macros:` block | `$(name)` | global or page |
| Dynamic macro | `$(set:name=value)` | `$(name)` | current scope |
| fncode | `fncode: name(params)` | (target language call) | global |

### 2.2 Clarify `$call` vs `&call`

Add a dedicated short subsection:
- `$call` -- inline expansion, no indented block expected
- `&call` -- block expansion, requires indented block, replaces `BLOCK`
- Show both side by side with the same subcode

### 2.3 Replace source-code dumps with result tables for `$(if:...)`

Current text pastes `fncode: testcondition` source. Replace with a table:

| Condition | True when |
|-----------|-----------|
| `$(if:A)` | macro A is defined and non-empty |
| `$(if:!A)` | macro A is not defined or empty |
| `$(if:A=val)` | macro A equals "val" (string) |
| `$(if:A>10)` | macro A is numerically > 10 |
| `$(if:A~pat)` | macro A matches regex pat (head) |
| `$(if:0)` / `$(if:1)` | always false / always true |
| `$(if:A or B)` | either A or B is true |
| `$(if:A and B)` | both A and B are true |
| `$(if:hascode:name)` | subcode "name" is defined |

Keep the source pointer for those who want implementation details, but lead
with the table.

### 2.4 Add generated-output examples

For each key feature (`$call`, `&call`, `$map`, `$nest`, `DUMP_STUB`,
multiply-defined subcode), show a complete `.def` input and the corresponding
generated output file. Currently most examples only show the `.def` side.

## Phase 3: Improve the output_perl Chapter

### 3.1 Move `fncode` earlier

`fncode:` is a core MyDef concept (defined in parseutil, used by all modules).
Add a brief introduction in the Syntax chapter, then let output_perl elaborate
on the Perl-specific behavior (auto-listing, `$sub` vs `fncode`).

### 3.2 Add `$foreach` variant summary

The `$foreach` section currently only shows the basic `in` form. Add a
sub-table:

| Form | Example | Perl equivalent |
|------|---------|-----------------|
| basic | `$foreach $x in @list` | `foreach my $x (@list) {` |
| hash | `$foreach $k, $v in %hash` | `while (my ($k,$v) = each %hash) {` |
| indexed | `$foreach $i, $x in @list` | loop with `$i` counter |
| zip | `$foreach $x, $y in @a, @b` | parallel iteration |

### 3.3 Document `$case` more clearly

Explain the state machine: `$case` emits `if` on first use and `elsif` on
subsequent uses within the same block. Show a concrete expansion.

### 3.4 Document `->` regex capture syntax

The `$if ... -> $var` and `$while ... -> $var` capture syntax is used
extensively in MyDef's own source but never explained in the manual.

## Phase 4: Fill in Stub Chapters

### 4.1 output_c

Even though output_c lives in a separate repo, document the key features that
differ from output_general:

- Auto-semicolons and curly braces (like output_perl)
- `fncode` generates C functions with declarations
- `$global` / `$local` variable management
- Type inference basics
- `$struct`, `$enum` support
- `$include`, `$define` passthrough
- Link to the output_c repository for full details

### 4.2 output_www

- Mode switching (HTML, CSS, JS, PHP)
- `$tag` syntax
- Template/frame support
- Link to the output_www repository

### 4.3 output_python, output_java

Brief descriptions of what they add beyond output_general. Can be short
since these are less mature. Link to their repositories.

### 4.4 output_sh

A short chapter; the module is thin (`module: sh` writes `<page>.sh`):

- Lines pass through as plain shell; MyDef adds macros, subcodes, and
  `$(for:...)` / `$(if:...)` at compile time
- `$if` / `$elif` / `$else` become `if ...; then` / `elif` / `else` / `fi`
- Nothing else is translated: `$for`, `$while`, and `$print` are emitted
  literally, so write `for ... do ... done`, `while`, and `echo`
- No shebang is added; write it as `\x23!/bin/sh`, since a line starting
  with `#` is a MyDef comment
- Collisions with shell syntax: `$(cmd)` is read as a macro (use backticks,
  `$( cmd )`, or a `$:` line), and ` # ` ends the line even inside quotes;
  point to the syntax chapter's collisions section
- `std_sh.def` is empty, so there are no library subcodes yet
- Link to the output_sh repository

## Phase 5: Add Reference Appendices

### 5.1 Page attribute reference

A single table listing all recognized `page:` attributes:

`type`, `output_dir`, `module`, `package`, `skiprun`, `arg`, `args`, `cmd`,
`run`, `exe`, `CC`, `CFLAGS`, `lib_list`, `make_dep`, `make_cmd`, `relax`,
`autolist`, `subpage`, `exe_type`

### 5.2 Compile-time directive reference

Quick reference for all `$(...)` directives:

`$(set:)`, `$(set-1:)`, `$(setmacro:)`, `$(mset:)`, `$(unset:)`,
`$(if:)`, `$(elif:)`, `$(else)`, `$(endif)`,
`$(for:)`, `$(block:)`, `$(export:)`,
`$(eval:)`, `$(join:)`, `$(x10:)`

### 5.3 Internal keywords reference

`BLOCK`, `DUMP_STUB`, `INDENT`, `DEDENT`, `NEWLINE`, `NOOP`,
`SOURCE_INDENT`, `SOURCE_DEDENT`, `INCLUDE_FILE`, `INCLUDE_BLOCK`

### 5.4 MyDef tools quick reference

One-paragraph summary of each tool with its most common flags:
`mydef_page`, `mydef_run`, `mydef_make`, `mydef_test`, `mydef_install`

## Phase 6: Structural / Formatting Improvements

### 6.1 Cross-references

Add forward/backward references between sections. E.g., when `subcode:`
mentions parameters, link to the "Subcode with parameters" subsection.

### 6.2 Consistent example format

Standardize all examples to follow this pattern:

1. `.def` input (labeled)
2. Command to compile/run
3. Generated output or program output

### 6.3 Index / glossary

Add a glossary of MyDef-specific terms: page, subcode, fncode, macro,
frame, module, block call, DUMP_STUB, named block.

## Priority Order

1. Phase 1 (tutorial) -- highest impact for new users
2. Phase 2.1-2.3 (concept table, `$call` vs `&call`, `$(if:)` table)
3. Phase 3.4 (`->` capture syntax)
4. Phase 5.1-5.2 (page attributes, directive reference)
5. Remaining Phase 2-3 items
6. Phase 4 (stub chapters)
7. Phase 6 (structural polish)
