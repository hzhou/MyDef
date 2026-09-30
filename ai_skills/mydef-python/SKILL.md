---
name: mydef-python
description: Write Python code in MyDef using the output_python module (module: python).
---

## Overview
`module: python` compiles a `.def` page to `<page>.py` (Python 3). Build with
`mydef_page prog.def`, or build and run with `mydef_run prog.def`. See the mydef
skill for general syntax and the required environment variables.

```
page: hello
    module: python
    $print Hello World!
```

The page body becomes `def main():`, with the usual
`if __name__ == "__main__": main()` appended (from `basic_frame` in
`$MYDEFLIB/std_python.def`). `fncode:` functions are emitted as module-level
`def`s after `main`.

Plain Python works as long as it is properly indented. MyDef adds conveniences
on top of it.

## Syntax conveniences
* The trailing `:` after `if/elif/else/while/for/def` is optional.
* `print x` becomes `print(x)`.
* `n++` / `n--` become `n+=1` / `n-=1`.
* `$if`, `$elif`, `$else`, `$while` work like in the Perl and C modules.
  `$if !cond` becomes `if not cond:`.
* `$while cond; step` puts `step` at the end of the loop body.

## Functions
```
fncode: add(a, b)
    return a + b
```
Nested `def` inside the page body works as plain Python.

## Loops
| MyDef | Python |
|-------|--------|
| `$for i=0:10` | `for i in range(10):` |
| `$for i=2:10` | `for i in range(2,10):` |
| `$for N` | `for _i in range(N):` |
| `$for i in L` | `for i in L:` |
| `$for i, x in A, B` | `for i, x in zip(A, B):` |
| `$for i, x in L` | `for i, x in enumerate(L):` (first var named i..n) |
| `$for i, a, b in A, B` | `for i, a, b in zip(range(len(A)), A, B):` |

`$foreach` is the same as `$for`.

### $do
`$do` makes a block you can `break` out of (or `continue` to rerun). It
becomes `while 1:` with an automatic `break` at the end.

## Printing
`$print` interpolates `$var` and `${expr}` into a `%`-format string and adds a
newline:
```
$print n=$n, root=${sqrt(n)}     # print("n=%s, root=%s" % (n, sqrt(n)))
$print no newline-               # trailing - : print("no newline", end='')
$dump n, L                       # print("n = %s, L = %s" % (n, L))
$warn message                    # print("message", file=sys.stderr)
$die message                     # raise Exception("message")
```
Inside `&call open_W, "file"`, `$print` writes to that file.

## Imports and globals
* `$import re` / `$import numpy as np` / `$import sqrt from math` go at the
  top of the file (`from math import sqrt`). You can put them anywhere in the
  source; duplicates are merged.
* `$try_import mod` wraps the import in try/except and sets `has_mod`.
* `re.`, `os.`, `sys.`, `copy.`, `glob.` usage is auto-imported.
* `$global cnt = 5` emits `cnt = 5` at module level and `global cnt` in the
  current function. Use `$global cnt` in each other function that assigns it.

## Regex
Perl-style matching, with capture groups bound to names:
```
$if s=~/Hello\s+(\w+)/ -> world
    $print Match! $world
$elif s=~/(test)/i -> t
    ...
```
This becomes `re.search(...)` with `m = ...` and `world = m.group(1)`.

`$if_match pattern` is for lexers. It matches at `src_pos` in `src`,
precompiles the regex globally, and on success advances `src_pos` and leaves
the result in `m`.

## Standard subcodes (std_python.def)
* `&call open_r, fname` loops over lines in `line`.
* `&call open_w, fname` writes via the file handle `Out`.
* `&call open_W, fname` is the same as `open_w`, plus it prints
  `--> [fname]` and sends `$print` to `Out`.
* `$call dict_inc, D, key` counts occurrences.
* `$(ternary:cond, a, b)` expands to `a if cond else b`.
* `$call start_time` / `$call print_time, msg` time a section.

Also available: `include: python/parse.def` and `include: python/tkinter.def`.

## Gotchas
* ` # ` (space, hash, space) starts a MyDef comment, even inside a string:
  `s = "a # b"` is truncated to `s = "a`. Write `"a \x23 b"` instead (Python
  decodes the escape).
* `$(word...` inside a string is taken as a MyDef macro. Use the
  `$: literal line` bypass if you need it literally.
* An `obj.method: args` call (without parentheses) is not translated. It's
  emitted as-is, and Python silently accepts it as a type annotation, so it
  does nothing (e.g. `stack.append: cur` never appends). Write normal calls:
  `stack.append(cur)`.

## References
* Source repo: `$HOME/projects/output_python` (`output_python.def`, `macros/`).
  `test/` has examples such as `calc.def`, `test_for.def` and `re.def`.
* `perl_to_python in.def out.def` (in `$HOME/bin`) converts a `module: perl`
  `.def` into a `module: python` one.
