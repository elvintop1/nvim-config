# Templates & CP Snippets

## Layout

- `templates/files/` stores **full-file templates only**.
- `snippets/` stores **all CP data structures / algorithms**.
- `templates/ds/` was removed so templates and snippets do not duplicate the same DS/algo code anymore.

This makes `snippets/` the single source of truth for insertable competitive-programming code.

## Auto-fill on new files

When you create a new file, Neovim loads a default file template automatically:

- `*.cpp` -> `templates/files/cpp/cp.cpp`
- `*.py` -> `templates/files/python/cp.py`
- `*.java` -> `templates/files/java/Main.java`

## Trigger convention

Canonical triggers are standardized by category:

- `ds_*` data structures
- `gr_*` graph / tree / flow
- `mt_*` math / number theory
- `str_*` string
- `tc_*` techniques / DP / offline
- `geo_*` geometry

Examples:

```vim
ds_dsu
gr_dinic
mt_ntt
str_sa
tc_mo
geo_hull
```

Full trigger index: `SNIPPETS.md`

## Commands

Replace the whole current buffer with a file template:

```vim
:TemplateUse cpp/cp.cpp
:TemplateUse python/gen.py
:TemplateUse java/Main.java
```

Insert a CP snippet at the cursor (from `snippets/`):

```vim
:TemplateInsert ds_dsu
:TemplateInsert gr_dinic
:SnippetInsert mt_pollard
:CppInsert str_sa
```

Open a picker:

```vim
:TemplatePick
:TemplatePick files
:TemplatePick snippets
:TemplatePick ds
:TemplatePick graph
:TemplatePick math
:TemplatePick string
:TemplatePick tech
:TemplatePick geo
:SnippetPick
```

Shortcut for C++ file templates:

```vim
:CppTemplate cp.cpp
:CppTemplate stress.cpp
```

`TemplateInsert` / `SnippetInsert` replace the current line when that line is blank; otherwise they insert below the current line.

Use command-line completion with `<Tab>` after typing a template/snippet command.

## blink.cmp

Custom snippets are loaded from:

```lua
vim.fn.stdpath("config") .. "/snippets"
```

So the same JSON files are used by both:

- completion in `blink.cmp`
- command-based insertion (`TemplateInsert`, `SnippetInsert`, `CppInsert`)

## Notes

A few snippets intentionally keep small helper code inside the same snippet so that a single insert remains usable on its own. The duplication that used to exist between `templates/ds/` and `snippets/` is gone.
