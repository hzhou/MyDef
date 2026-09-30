# MyDef

MyDef is a meta-programming preprocessor that adds a macro and code-factoring
layer on top of any programming language. You write `.def` files using
indentation-based syntax with reusable code blocks (subcodes) and compile-time
macros, and MyDef generates output in your target language.

```
# greet.def
page: greet.py
    $map greet, Alice, Bob, Carol

subcode: greet(name)
    print("Hello, $(name)!")
```

Compile it with `mydef_page`, then run the output:

```sh
$ mydef_page greet.def
PAGE: greet.py
  --> [./greet.py]

$ python greet.py
Hello, Alice!
Hello, Bob!
Hello, Carol!
```

The generated `greet.py`:

```python
print("Hello, Alice!")
print("Hello, Bob!")
print("Hello, Carol!")
```

Or use `mydef_run` to compile and run in one step:

```sh
$ mydef_run greet.def
Hello, Alice!
Hello, Bob!
Hello, Carol!
```

## Documentation

- [Manual](https://htmlpreview.github.io/?https://github.com/hzhou/MyDef/blob/master/manual/mydef.html)
  (Getting Started, syntax reference, output module guides)
- [Design](docs/Design.md) (architecture and internals)

## Features

- **Code factoring** -- define reusable blocks (`subcode`) and inline them with
  `$call`, eliminating boilerplate and repetition
- **Block calls** -- `&call` wraps open/close patterns (file I/O, loops, tags)
  around arbitrary content via `BLOCK` substitution; nesting allows scoped
  refactoring without side effects
- **Compile-time macros** -- `$(name)` substitution with scoping, conditionals
  (`$(if:...)`), iteration (`$(for:...)`), and arithmetic
- **Pluggable output modules** -- language-specific backends that add syntax
  sugar (auto-semicolons, indentation-based control flow, function signatures)
- **Works with any language** -- the general module passes text through; specialized
  modules exist for Perl, C/C++, Python, Java, Go, Rust, Fortran, and more

## Installation

Prerequisites: `perl`, `make`, `git`

```sh
git clone https://github.com/hzhou/MyDef.git
cd MyDef
sh bootstrap.sh
```

Set these environment variables (add to `~/.bashrc`):

```sh
export PATH=$HOME/bin:$PATH
export PERL5LIB=$HOME/lib/perl5
export MYDEFLIB=$HOME/lib/MyDef
export MYDEFSRC=/path/to/MyDef    # needed for installing output modules
```

If these variables are set before running `bootstrap.sh`, it will install to
those locations. Otherwise it defaults to `$HOME/bin`, `$HOME/lib/perl5`, and
`$HOME/lib/MyDef`.

To update after `git pull`:

```sh
make
make install
```

## Quick Start

Create a file `t.def`:

```
page: t.py
    print("Hello, World!")
```

Run it:

```sh
$ mydef_run t.def
PAGE: t.py
  --> [./t.py]
python ./t.py
Hello, World!
```

`mydef_run` compiles the `.def` file and executes the result. For projects with
multiple files, use `mydef_make` to generate a `Makefile`, then use `make`.

The output file extension determines the language. Try naming the page `t.c`,
`t.java`, `t.go`, `t.rs`, `t.f90`, or `t.sh` (assuming the language toolchain
is installed). Specialized output modules (e.g. `module: c`, `module: perl`)
add language-specific features like auto-semicolons and function signatures.

## Tools

| Command | Purpose |
|---------|---------|
| `mydef_page` | Compile `.def` files into output files |
| `mydef_run` | Compile and execute a single `.def` file |
| `mydef_make` | Generate a `Makefile` from `.def` files in the current directory |
| `mydef_test` | Run tests listed in a `TESTS` file |
| `mydef_install` | Install outputs to `$PERL5LIB`, `$MYDEFLIB`, or `$PATH` |

## Output Modules

This repository includes `output_general` (plain text, default) and
`output_perl`. Additional modules are available as separate repositories:

[output_c](https://github.com/hzhou/output_c),
[output_python](https://github.com/hzhou/output_python),
[output_java](https://github.com/hzhou/output_java),
[output_www](https://github.com/hzhou/output_www),
[output_go](https://github.com/hzhou/output_go),
[output_rust](https://github.com/hzhou/output_rust),
[output_fortran](https://github.com/hzhou/output_fortran),
[output_win32](https://github.com/hzhou/output_win32),
[output_xs](https://github.com/hzhou/output_xs),
[output_pascal](https://github.com/hzhou/output_pascal),
[output_tcl](https://github.com/hzhou/output_tcl),
[output_glsl](https://github.com/hzhou/output_glsl)

To install an output module:

```sh
git clone https://github.com/hzhou/output_c.git
cd output_c
mydef_make && make && make install
```

## AI Assistant Skills

[`ai_skills/`](ai_skills/) has skills that teach an AI coding assistant, such
as [Claude Code](https://claude.com/claude-code), to write and build MyDef
code:

| Skill | For |
|-------|-----|
| [mydef](ai_skills/mydef/SKILL.md) | General MyDef syntax, directives, and tools |
| [mydef-perl](ai_skills/mydef-perl/SKILL.md) | Perl with `module: perl` (built in) |
| [mydef-c](ai_skills/mydef-c/SKILL.md) | C with `module: c` (output_c) |
| [mydef-html](ai_skills/mydef-html/SKILL.md) | HTML, PHP, and JavaScript with output_www |
| [mydef-python](ai_skills/mydef-python/SKILL.md) | Python with `module: python` (output_python) |
| [mydef-sh](ai_skills/mydef-sh/SKILL.md) | Shell scripts with `module: sh` (output_sh) |
| [mydef-modules](ai_skills/mydef-modules/SKILL.md) | Installing or rebuilding an output module |

To use them with Claude Code, copy the folders into `~/.claude/skills/`:

```sh
cp -r ai_skills/* ~/.claude/skills/
```

They assume the environment from [Installation](#installation) (`PERL5LIB`,
`MYDEFLIB`, `MYDEFSRC`) and module repositories cloned under
`$HOME/projects/`; edit them to match your own setup.

## Vim Setup

```vim
" ~/.vim/filetype.vim
augroup filetypedetect
  au BufNewFile,BufRead *.def setf mydef
augroup END
```

```sh
ln -s /path/to/MyDef/docs/mydef.vim ~/.vim/syntax/
```

Recommended `.vimrc` settings:

```vim
set shiftwidth=4
set expandtab
nmap <F5> :!mydef_run %<CR>
```

## License

[MIT](LICENSE)
