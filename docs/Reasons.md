# Why MyDef

If you've wandered into this project and are wondering why anyone would put a
preprocessor in front of a perfectly good programming language, here are three
reasons.

## 1. Clean code

Clean code states its intentions clearly and directly, keeps local context
local, and is organized as a top-down, hierarchical flow.

Programming languages work against this. They make you write boilerplate that
does nothing for your meaning and exists only to satisfy the compiler. They
make you follow conventions and syntax that aren't natural, and those break up
a clean reading. The code ends up ordered the way the compiler needs it, not
the way a person would explain it.

MyDef gives you the basic facilities to push that boilerplate into a background
layer, set up your own conventions, and write code the way we explain and
understand things. Here is a word counter:

```
page: wc.py
    DUMP_STUB init
    &call each_line, sys.argv[1]
        $call count_lines
        $call count_words
    DUMP_STUB report
```

This reads like the description you would give a colleague: for each line of
the input, count lines and count words, then report. How to open a file and
loop over its lines is a convention. It is written once, in the background,
and every page can use it:

```
subcode: each_line(path)
    $(block:init)
        import sys
    with open($(path)) as f:
        for line in f:
            BLOCK
```

The `import sys` is declared right next to the code that needs it. MyDef moves
it to the top of the output, where Python wants it.

## 2. Design-first development

Real designs are priority-based, leaky, and ambiguous. A design says what
matters most and leaves the rest open. Programming makes you specify every
detail, so when you code a design directly, you have to fill in details at
every layer of it. The details dilute the design's goals, and soon they start
constraining the design instead of serving it.

MyDef lets you write ambiguous, design-level code using templates. The
important decisions float to the top layers and the details sink to the bottom
ones:

```
page: backup.py
    $call find_changed_files
    $call copy_files
    $call report
```

This top layer is the design. It stays the same whether "changed" means
timestamps or checksums, and whether copying goes to a local disk or over the
network. Those choices live in lower layers and can change without touching
the layers above them.

MyDef keeps the design layers separate, so each one stays small enough to
understand as the code grows.

## 3. AI-assisted software development

AI works from context. When the context is incomplete, AI hallucinates. When
the context conflicts, AI makes mistakes. And finding and assembling that
context is where most of the tokens go.

MyDef aims to keep all the context for one design idea or one feature in one
place, and to isolate features so they can be combined with minimal
complication. In the word counter, each feature holds its own setup, its own
per-line work, and its own report:

```
subcode: count_lines
    $(block:init)
        n_lines = 0
    $(block:report)
        print("lines:", n_lines)
    n_lines += 1

subcode: count_words
    $(block:init)
        n_words = 0
    $(block:report)
        print("words:", n_words)
    n_words += len(line.split())
```

MyDef puts each piece where the target language needs it:

```python
import sys
n_lines = 0
n_words = 0
with open(sys.argv[1]) as f:
    for line in f:
        n_lines += 1
        n_words += len(line.split())
print("lines:", n_lines)
print("words:", n_words)
```

To add a feature, such as counting characters, you (or an AI) write one new
subcode and add one `$call`. You don't have to edit code in three separate
places in the file. To remove the feature, you delete that same code.

When the relevant context is in one place, AI does good work. When components
can be combined cleanly, AI can build features without making a mess.

## Try it

- [README](../README.md): install and a first example
- [Manual](https://htmlpreview.github.io/?https://github.com/hzhou/MyDef/blob/master/manual/mydef.html):
  syntax and output modules
- [ai_skills/](../ai_skills/): skills that teach an AI coding assistant to
  write MyDef
