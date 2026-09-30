---
name: mydef-modules
description: Install or reinstall a MyDef output module (output_www, output_c, output_python, etc.) from its GitHub repo. Use when the user asks to install, build, rebuild, or refresh a MyDef module, or when a `module: xxx` page fails because MyDef::output_xxx is missing.
---

# Installing MyDef modules

MyDef output modules live in separate repos named `output_<name>` under
https://github.com/hzhou/ (e.g. `output_www` provides `module: www`, plus
`php` and `js`). Each module repo is itself written in MyDef and compiles to
Perl modules.

## Environment

`$HOME/.bashrc` exports `PERL5LIB`, `MYDEFLIB` and `MYDEFSRC`, so they are normally
already set. If `echo $MYDEFSRC` comes back empty (e.g. a session started
before `.bashrc` was loaded), export them in the Bash call:

```sh
export PERL5LIB=$HOME/lib/perl5 MYDEFLIB=$HOME/lib/MyDef MYDEFSRC=$HOME/projects/MyDef
```

Without `MYDEFSRC`, `mydef_make` fails with `MYDEFSRC not defined (in environment)!`.
MyDef itself must already be installed (`mydef_make`, `mydef_page`,
`mydef_install` in `$HOME/bin`).

## First-time install

Keep the module repo in `$HOME/projects/` — the user works on module repos later.

```sh
cd $HOME/projects && git clone https://github.com/hzhou/output_<name>
cd $HOME/projects/output_<name>
mydef_make </dev/null   # generates Makefile; accept defaults
make                    # compiles *.def -> out/lib/MyDef/*.pm
make install            # runs install_def.sh-style mydef_install steps
```

- If the repo has a `config` file (typically `module: perl`, `output_dir: out`),
  `mydef_make` does not prompt. Otherwise it asks questions — accept defaults
  (redirecting stdin from /dev/null does this).
- `make install` copies:
  - `out/lib/MyDef/*.pm` -> `$PERL5LIB/MyDef/`
  - `deflib/*.def` (std_*.def and subdirs) -> `$MYDEFLIB`
  - `out/script/*` (if the repo has script pages, e.g. output_python's
    `perl_to_python`) -> `$HOME/bin/`

## Refreshing an install

If no new `.def` source or new output `.pm` was added, just:

```sh
make && make install
```

If files were added, rerun `mydef_make` first to regenerate the Makefile.

## Verify

```sh
perl -MMyDef::output_<name> -e 'print "ok\n"'
```

Then compile a tiny page in the scratchpad. Page content goes directly under
`page:` (not in `subcode: main`), e.g. for www:

```
page: t
    module: www
    $h1
        Hello
```

`mydef_page t.def` should write `t.html` with the `<h1>` in the body. The
repo's `tests/` directory has more usage examples.

## After installing
Add the new module to the "Installed modules" table in the mydef skill
(`$HOME/.claude/skills/mydef/SKILL.md`).

## Notes

- `out/` and the generated `Makefile` are build artifacts; don't commit them.
  `out/` is the conventional `output_dir` for compiled `.def` files — keep it
  around to examine generated results; it also serves as `mydef_run`'s scratch
  place.
- Report which files were installed where (the `make install` output lists them).
