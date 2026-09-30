---
name: mydef-html
description: Write HTML code in MyDef using the output_www module.
---

## Overview
MyDef's `output_www` module generates HTML from `.def` files. Use `module: www` under a page, or compile with `mydef_page -mwww file.def`. The output file extension is `.html`.

```
page: mypage, basic_frame
    module: www
    title: My Page
    $h1
        Hello World
```

To convert: `mydef_page mypage.def` produces `mypage.html`. Page content goes
directly under `page:`; it is not picked up from a `subcode: main`.

The output_www repo (`$HOME/projects/output_www`) also provides `module: php`
and `module: js`. Its `tests/` directory has working examples. To rebuild the
module after editing it, use the mydef-modules skill.

## HTML Tag Syntax

Tags are invoked with `$` prefix: `$div`, `$p`, `$table`, `$tr`, `$td`, `$th`, `$ul`, `$ol`, `$li`, `$h1`–`$h6`, `$a`, `$span`, `$pre`, `$form`, `$input`, `$img`, etc.

### Attribute Parsing (comma-separated after tag name)

| Syntax | Meaning | Example |
|--------|---------|---------|
| bare word | CSS class | `$div myclass` → `<div class="myclass">` |
| `#name` | ID | `$div #myid` → `<div id="myid">` |
| `key:value` | attribute | `$a href:url` → `<a href="url">` |
| `"text"` | inline content | `$td "hello"` → `<td>hello</td>` |
| `/` | empty quick-close | `$div /` → `<div></div>` |

Multiple params: `$div #myid, myclass, data-x:5`

### Content: Inline vs Block

**Inline** — use double quotes for short content:
```
$td "cell content"
$button "Click Me"
$th "Header"
```

**Block** — indent content below the tag:
```
$div
    Line 1
    Line 2
$td
    $(code:page: name)
```

**IMPORTANT**: When content contains colons (e.g. from `$(code:...)` macro expansion), use block form. Colons in inline content get misinterpreted as `key:value` attributes by the tag parser.

```
# WRONG - colon breaks parsing
$td "$(code:page: name)"

# RIGHT - block form
$td
    $(code:page: name)
```

### Self-Closing Tags

`$input` and `$img` are self-closing. `$input` auto-adds `type="text"` if no type given. Quoted text on `$input` becomes the `placeholder` attribute.

```
$input type:text, name:user, "Enter name"
$img src:photo.jpg
```

### Form Defaults

`$form` auto-adds `method="POST"` if not specified. There is no default `action`; the form submits to the current URL.

## CSS Declarations

```
CSS: body {padding: 50px}
CSS: .hint {color:#888}
CSS: pre {background-color: #ddd; margin: 4px 10px}
```

Vendor prefixes are auto-added for `transition`, `user-select`, `linear-gradient`.

## Standard HTML Macros (from deflib/std_html.def)

| Macro | Output |
|-------|--------|
| `$(a:text,url)` | `<a href="url">text</a>` |
| `$(url:u)` | `<a href="u">u</a>` |
| `$(anchor:name)` | `<a name="name"></a>` |
| `$(code:text)` | `<code>text</code>` |
| `$(em:text)` | `<em>text</em>` |
| `$(b:text)` | `<strong>text</strong>` |
| `$(img:src)` | `<img src="src" />` |

## Form Helper Subcodes (from deflib/std_html.def)

- `input_text(name)` — text input with textinput class
- `input_pass(name)` — password input
- `input_checkbox(name, label)` — checkbox with label
- `input_radio(name, value, label)` — radio button with label
- `input_hidden(name, value)` — hidden input
- `input_submit(label)` — submit button
- `input_option(value)` — select option
- `form_input(prompt, varname)` — label + input row

## Tables

```
$table
    $tr
        $th "Header 1"
        $th "Header 2"
    $tr
        $td "Cell 1"
        $td
            Content with $(code:special: chars)
```

## Lists

```
$ul
    $li
        First item
    $li
        Second item
```

## Common Patterns

### Page with frame and styling
```
page: mypage, basic_frame
    module: www
    title: My Page
    CSS: body {margin: 20px}
    $h1
        $(title)
    $p
        Welcome to the page.
```

### Link with attributes
```
$a href:https://example.com, target:_blank
    Visit Example
```

### Div with ID and class
```
$div #container, main-content
    $p highlight
        Important text here.
```

## Source Reference

- Main module: `$HOME/projects/output_www/output_www.def`
- Tag parser: `$HOME/projects/output_www/macros_www/tags.def`
- HTML helpers: `$HOME/projects/output_www/deflib/std_html.def`
