---
name: mydef-c
description: Write C code in MyDef.
---

## Overview
`module: c` (from the output_c module) compiles a `.def` page to `<page>.c`.
`mydef_page prog.def` writes `prog.c`; `mydef_run prog.def` also compiles and
runs it (`gcc -std=c99 -g -O2 -o ./prog ./prog.c && ./prog`). See the mydef
skill for general syntax and environment variables. `module: cpp` targets C++.

Plain C works, as long as it is indented properly. MyDef removes the noise:
* `#` starts a comment (replaces `//`). C preprocessor lines (`#include`,
  `#define`, `#ifdef`, ...) are recognized and passed through.
* Semicolons are optional. Don't break long lines.
* `$if` / `$elif` / `$else` / `$while` drop the parentheses and braces;
  `$dowhile cond` is a do-while. `$if a = 0` warns about `=` vs `==`.

```
page: t
    module: c
    $local int a = 3
    $if a > 2
        printf("a is big\n")
    $elif a > 1
        printf("a is medium\n")
    $else
        printf("a is small\n")
    $while a > 0
        a--
```

## Frames: programs, scripts, libraries
* `basic_frame` (in `std_c.def`) wraps the page code in `main()`. It is the
  default, so `page: t` means `page: t, basic_frame`.
* A `.def` file without any `page:` line is a page named after the file; its
  top-level code becomes `main`. Handy for quick scripts.
* `page: mylib, -` means no frame (no `main`), for libraries or files linked
  into another program. Since nothing calls the functions, include them with
  `$list f1, f2`, or `autolist: global` (all top-level `fncode`) or
  `autolist: page` (the `fncode` blocks defined inside the page).

## Variables and type inference
Inference exists so the code stays short and readable: the names carry the
types, and MyDef writes the declarations.
* `$local` declares at the top of the function, `$global` at the top of the
  file, `$my` in the current block. A variable assigned without a declaration
  is declared automatically.
* The type comes from the name first, then from the assigned value (`0.5` is
  `float`, `"text"` is `char *`).

| Name | Type |
|------|------|
| `i j k m n`, `n_...`, `i_...` | `int` |
| `f d`, `f_...`, `d_...` | `float` / `double` |
| `c`, `c_...` | `unsigned char` |
| `s`, `s_...` | `char *` |
| `b_...`, `is_...`, `has_...` | `bool` |
| `n4_...`, `u8_...`, `i64_...` | `int32_t`, `uint64_t`, `int64_t` |
| `size_...`, `time_...`, `file_...` | `size_t`, `time_t`, `FILE *` |
| `p` + a prefix, e.g. `pn_list` | pointer to that type (`int *`) |

```
$local i, n_count, f_scale, s_name, b_done
$global g_total = 0
k = 10
```
gives `int i; int n_count; float f_scale; char *s_name; bool b_done;`, a global
`int g_total = 0;`, and `int k;`.

### Project naming conventions
The real value comes when a project defines its own naming convention and
registers it. This keeps the code free of declarations and enforces the
convention, since a name that breaks it gets the wrong type:
```
subcode: _autoload
    $register_name(node) struct Node
    $register_prefix(pt) struct Point
    $register_prefix(len) size_t
```
Then `$local node, p_node, pt_start, len_name` declares `struct Node node;`,
`struct Node *p_node;`, `struct Point pt_start;`, `size_t len_name;`.

### Explicit types
Inference is heuristic: a name that matches no rule and has no value gets no
type (`foo;`), and a value from a function call may miss. Declare explicitly
when that happens, or whenever you prefer:
```
$local int count, char grade, double ratio = 0.5
$local foo: long
$my a: char[10]
```
A plain C declaration with a semicolon (`int a = 3;`) is passed through and
its type is not recorded. Without the semicolon, `double x = 0.5` is
recognized and moved to the top of the function.

## $print (debug printing)
`$print` interpolates variables and adds the newline; the format comes from
each variable's type:
```
$print n = $n, x = $x, name = $s_name   # printf("n = %d, x = %g, name = %s\n", ...)
$print "x = %.2f", x                     # printf format; newline still added
$print Loading -                         # trailing "-": no newline
$print arr[2] = ${arr[2]}                # ${...} for an expression
$dump n, x                               # prints "    :n=3, x=1.5"
```
* Mixed form, for when one value needs a specific format: quote the text, put
  the `%` arguments after it, and `$var` is still filled in:
  `$print "x = %.2f, n = $n", x`. The quotes are required for mixing.
* `$(set:print_to=stderr)` prints to another stream.
* When the type can't be inferred (an expression like `${2*n}`, a function
  call, an unseen declaration), it warns `get_var_fmt: unhandled ...` and uses
  `%d`. Don't fight it: use the explicit format or a plain `printf`.

## Loops
`$for` takes `start:end:step`; the end is exclusive and the loop variable is
declared in the loop:
```
$for 10             # i = 0 ... 9
$for i=0:10         # i = 0 ... 9
$for j=0:10:3       # for (int j = 0; j < 10; j += 3)
$for k=9:0:-1       # k = 9 ... 0 (a decreasing range includes both ends)
$for i=9; i>=0; i-- # C form, passed through
```
`$foreach pn_array` loops over an array whose size MyDef knows (from
`$allocate`, or `$local pn_array[10]`). In the block, `$(i)` is the index and
`$(t)` the element:
```
$allocate(3, 0) pn_array
$foreach pn_array
    $(t) = $(i) * 10
    $print "%d: %d", $(i), $(t)
```

## Functions
Parameter types follow the naming rules or are given explicitly; the return
type is inferred from `return` or given after a colon. Prototypes are
generated, so functions can go in any order:
```
fncode: rect_area(n_w, n_h)          # int rect_area(int n_w, int n_h)
    return n_w * n_h

fncode: mean(a, b: double): double
    return (a+b)/2

fncode: A(c, f; int a1, a2; b1, b2: float)
```
In the last one, `;` separates groups: a leading (`int a1`) or trailing
(`b2: float`) type applies to its whole group.

Only functions that are called are included, detected by scanning for
`name(`. A function used only as a callback or through a function pointer is
missed; add it with `$list name`.

## Headers, structures, libraries
* `$include math` (or `math.h`) adds `#include <math.h>`. `stdint.h` and a
  `bool` typedef are added automatically when inferred types need them.
* `$struct(point) f_x, f_y, s_label` declares a struct; field types follow the
  naming rules.
* `lib_list: -lm` on the page is passed to the compiler's link line.

```
page: t
    module: c
    lib_list: -lm
    $include math
    $local double r = 2.0
    $print "sqrt = %f", sqrt(r)
```

## Library
* `$MYDEFLIB/std_c.def` is autoloaded for `module: c`. It has `basic_frame`,
  `$call assert, cond`, `$call die, msg`, `$call warn, msg`, and
  `$allocate(n) pn_array`, which allocates with `calloc` (`$allocate(n, 0)`
  also sets an initial value) and records the size for `$foreach`. Check it
  when unsure how a builtin expands.
* `$MYDEFLIB/c/*.def` are optional libraries pulled in with a top-level
  include, e.g. `include: c/string.def`. Available: array, backtrace, bignum,
  cmdline, colormap, complex, darray, dlist, file_glob, files, fitting,
  freetype, getopt, hash, image, layout, lex, matrix, mem, ogdl, omp,
  parser_common, permutation, regex, regex_simple, ring_buffer, save_bmp,
  save_ppm, simple_parse, slist, string, string_fmt, strpool, thread.
* `$MYDEFLIB/std_cpp.def` is the counterpart for `module: cpp`.

## References
* Source repo: https://github.com/hzhou/output_c (conventionally cloned to
  `$HOME/projects/output_c`; see the mydef-modules skill to install or
  rebuild). Its `tests/` has working examples of most features; `types.def`
  has the full naming rules.
* The MyDef manual's output_c chapter covers the same material with runnable
  examples.
