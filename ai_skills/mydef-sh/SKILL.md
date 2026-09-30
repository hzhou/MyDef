---
name: mydef-sh
description: Write shell scripts in MyDef using the output_sh module (module: sh).
---

## Overview
`module: sh` compiles a `.def` page to `<page>.sh`. It's a thin module: lines
pass through as plain shell, and MyDef mainly adds macros, subcodes, and
indentation-based `$if`. See the mydef skill for general syntax and the
required environment variables.

```
page: build
    module: sh
    \x23!/bin/sh
    x=3
    $if [ $x -gt 5 ]
        echo big
    $elif [ $x -gt 1 ]
        echo mid
    $else
        echo small
```

becomes

```sh
#!/bin/sh
x=3
if [ $x -gt 5 ]; then
    echo big
elif [ $x -gt 1 ]; then
    echo mid
else
    echo small
fi
```

## What MyDef provides
* `$if` / `$elif` / `$else` become `if ...; then` / `elif` / `else` / `fi`.
* Macros (`$(name)`), `$call` / `&call` subcodes, `$(for:a,b)`, and
  `$(if:...)` work as usual.
* `$print text` becomes `echo text`, with the text as written (no format
  handling, no quoting added). Bare `$print` is `echo`.
* `$for a in word list` and `$foreach a in word list` (aliases) become
  `for a in word list; do` ... `done`. That is the only supported form;
  `$for i=0:3` etc. are emitted literally.
* Nothing else is special. `$while` is NOT translated; it is emitted
  literally and breaks the script. Write `while ...; do ... done`.
  `$(for:...)` is fine because it's compile-time.
* Shell functions (`name() { ... }`) work as plain lines. `std_sh.def` is empty,
  so there are no builtin subcodes.
* No shebang is added and the output is not made executable. Run it with
  `sh file.sh`, or add a shebang line (see below).

## Gotchas
* **`#` lines are dropped.** A line starting with `#`, including a shebang, is
  a MyDef comment. To output one, start the line with `\x23`:
  `\x23!/bin/sh`, `\x23 a comment`. `$: #!/bin/sh` also works for the
  shebang, but not for `$: # comment` (a ` # ` still cuts the line).
* **Trailing ` # ` is stripped**, even inside quotes: `echo "x # y"` becomes
  `echo "x`. Avoid a space-hash-space in strings (e.g. `printf 'x \043 y\n'`).
  `#` without a following space (`"r#s"`, `$#`) is safe.
* **`$(cmd` clashes with MyDef macros.** `d=$(date)` is read as the macro
  `date` and expands to nothing (with a "Macro ... not defined" warning). Use
  one of these instead:
  - backticks: ``d=`date` ``
  - a space after the paren: `d=$( date )`
  - a literal line: `$: d=$(date)`

  `$((1+2))`, `$1`, `$x`, `${HOME}` are all safe.
* Always check `mydef_page` output for "Macro ... not defined" warnings. They
  usually mean a `$(...)` was swallowed.

## References
* Source repo: `$HOME/projects/output_sh`. `tests/sh_test.def` is a working
  example.
* The if/elif/else support comes from `$MYDEFSRC/macros_output/case.def`
  (`sh_style`).
