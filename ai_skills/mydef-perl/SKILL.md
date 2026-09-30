---
name: mydef-perl
description: Write Perl code in MyDef using the output_perl module (module: perl).
---

## Overview
`module: perl` is built into MyDef (MyDef itself is written with it). A page
compiles to `<page>.pl` with `#!/usr/bin/perl` and `use strict;` added.
`mydef_page prog.def` writes `prog.pl`; `mydef_run prog.def` also runs it. See
the mydef skill for general syntax and environment variables.

Plain Perl works as long as it is indented properly. On top of it:
* Semicolons are optional for ordinary statements.
* `$if` / `$elif` / `$else`, `$while`, `$for`, `$foreach` drop the
  parentheses and braces.
* `$if $i = 15` warns `assignment in condition`, the classic `=` vs `==` bug.
* `relax: 1` on the page leaves out `use strict;`.

```
page: t
    module: perl
    my $name = "Alice"
    $if $name eq "Alice"
        $print Howdy, $name
    $else
        $print Nice to meet you, $name!
```

## $print (debug printing)
`$print` adds the quotes, the newline, and the semicolon. Perl interpolates
`$var` in the string as usual:
```
$print Howdy, world!             # print "Howdy, world!\n";
$print Howdy, world!\n           # a newline is added only when missing
$print "Howdy, world!"           # quotes are fine too
$print Howdy, -                  # trailing "-": no newline
$print Howdy, $green{$name}!     # color: red green yellow blue magenta cyan
$print "Pi = %.2f", 3.1415926    # printf "Pi = %.2f\n", 3.1415926;
```
* `$(set:print_to=STDERR)` (or a file handle such as `Out`) prints there.
* `${...}` is not an expression form here: it is passed into the Perl string,
  where Perl reads it as a dereference. For an expression, use the printf
  form (`$print "sum = %d", sum(@list)`) or a plain `print`.

## Conditions and $case
```
$if $line=~/^(\w+):\s*(.*)/ -> $key, $value
    $print key=$key, value=$value
```
`->` captures the match groups into new `my` variables (`$if`, `$elif`,
`$while`): `$while $text=~/(\w+)/g -> $word`.

`$case` becomes `if` for the first case in a block and `elsif` after that, so
cases can be reordered or spread over `subcode::` definitions:
```
foreach my $l (@lines){
    $call @check_cases
    $else
        $print nothing special
}

subcode:: check_cases
    $case $l=~/^\s*$/
        # empty

subcode:: check_cases
    $case $l=~/^special: (.*)/ -> $what
        $print special $what
```

## Loops
```
$for $i=0:10          # for (my $i = 0; $i<10; $i++)
$for $i=0:10:2        # step 2
$for 0:10             # $i is the default variable
$for 10               # same as $for 0:10
$for $i=10:0:-1       # 10 down to 0: a decreasing range includes both ends
```
The range form always scopes its loop variable to the loop: `output_perl`
adds the `my`, so don't write `my` in it.

The C-style form `$for init; cond; step` is the fallback for loops the range
form can't express. It is passed through as written, with no implied loop
variable: write `my` in `init` to scope it to the loop, or declare the
variable before the loop to use its value afterwards:
```
my $i
$for $i=0; $i<10 && $i*$i<30; $i++
    NOOP
$print stopped at $i
```

`$foreach` supplies the `my` and reads with `in`:

| MyDef | Perl |
|-------|------|
| `$foreach $x in @list` | `foreach my $x (@list) {` |
| `$foreach @list` | `foreach (@list) {` (in `$_`) |
| `$foreach $k, $v in %hash` | `while (my ($k, $v) = each %hash) {` |
| `$foreach $_i, $x in @list` | loop with index `$_i` |
| `$foreach $_i, $a, $b in @x, @y` | parallel loop over two arrays |

The index variable must be `$_i`, `$_j`, or `$_k`.

`$while cond` is the same, without braces.

## Functions
`fncode:` defines a sub with named parameters, unpacked from `@_`:
```
page: t
    module: perl
    $print "3: %d", F(3)

fncode: F($x)
    $global $Offset = 10
    return $x * $x + $Offset
```
gives `sub F { my ($x) = @_; ... }` after the main code, under
`# ---- subroutines ----`.
* In a `.pl` script, only the subs that are called are included, detected by
  scanning for `name(`. Add a sub used another way (e.g. `\&F`) with
  `$list F`.
* `$global $Offset = 10` declares `our $Offset = 10;` at the top of the file,
  once, wherever it is written.
* `$use List::Util qw(sum)` adds a `use` line at the top, from anywhere.
* `$sub F($x)` defines the sub inline, as an ordinary statement.

## Modules (.pm)
`package: MyPkg` on the page writes `MyPkg.pm` with `package MyPkg;`, every
`fncode` (whether called or not), and the final `1;`:
```
page: MyPkg
    module: perl
    package: MyPkg

fncode: hello
    return "hi"
```

## std_perl.def
`$MYDEFLIB/std_perl.def` is loaded automatically. File names can be written
bare or quoted.
* `&call open_r, file` loops over the lines in `$_`, with file handle `In`.
* `&call open_w, file` opens `Out` for writing (`>` is added); use
  `$(set:print_to=Out)` inside to `$print` to it.
* `&call open_W, file` is `open_w` that also prints `--> [file]` and sends
  `$print` to the file.
* `$call get_file_in_t, file` reads the whole file into `$t`;
  `$call get_file_lines, file` reads it into `@lines`.
* When nesting `open_r` inside `open_w` or the reverse, set the other file
  handle, e.g. `$(set:In=In2)`.
* Small helpers: `$call update_max, $max, $a` (also `update_min`,
  `update_minmax`), `$call swap, $a, $b`, `$call assert, cond`,
  `$call dump, $a, $b`, `$call dump_hash, h`, and `&call bench, n` to time a
  block.

```
page: io
    module: perl
    &call open_w, t.txt
        $(set:print_to=Out)
        $print Alice, Smith
        $print Bob, Jones
    &call open_r, t.txt
        $if /(\w+), (\w+)/
            $print Hello $2 $1!
    $call get_file_lines, t.txt
    $print "Got %d lines", $#lines+1
```
prints `Hello Smith Alice!`, `Hello Jones Bob!`, `Got 2 lines`.

Prefer simple `system` calls (e.g. `system "cp $src $dst"`) over pure-Perl
reimplementations when appropriate.

## References
* Source: `output_perl.def` and `macros_output/` in the MyDef repository
  (`$MYDEFSRC`); `std_perl.def` in `$MYDEFLIB`.
* The MyDef manual's output_perl chapter covers the same material with
  examples.
