# Project Memory

CAGE keeps notes about your project between sessions, and injects the relevant
ones into a run. Two kinds, with different rules about who writes them.

**History** is written for you: one file per source file, recording what was
changed and why. **Rules** are written by you: standing instructions, loaded
when they apply.

Both live in `.cage/` in your project, as plain Markdown you can read, edit and
commit.

---

## History, written automatically

At the end of a turn the server records one entry per file that was actually
written, into `.cage/files/<path>.md`. When that file is in play again in a
later session, its history comes back with it.

- **Which files** comes from what `write_file` and `apply_patch` actually
  touched — not from the model's own account of the turn. Models routinely
  claim to have created files they never wrote, and recording those would
  invent history for files that do not exist.
- **Why** comes from the node's Summary output, flattened to one line and
  capped so the file stays readable by a person.
- **Nodes with no Summary write nothing.** A build-verification pass that
  returns only a pass/fail report has no reason to record.

The `remember` tool lets the model add to the same files deliberately — useful
for what it *tried and rejected*, which no diff shows. History does not depend
on it: the server writes regardless.

This is deliberate. Earlier, `remember` was the only writer, and across three
test runs the model never once decided to call it. `.cage/files/` was never
created and every turn loaded nothing.

## Rules, and when they apply

`.cage/memory-map.json` is a **routing table**. Each row says when one rule file
should be loaded:

```json
{
  "version": 1,
  "rows": [
    { "when": "",                            "file": ".cage/memory.md"    },
    { "when": "when editing C++ code",       "file": ".cage/types/cpp.md" },
    { "when": "anything about GPU placement or VRAM", "file": ".cage/gpu.md" }
  ]
}
```

| Field | Meaning |
|---|---|
| `when` | **Plain language**, not a glob. Empty means always |
| `file` | Project-relative path to the rule file. No variables — name the file |

An empty `when` is deterministic: the file is always loaded, with no model call.
Put unconditional rules there. "Always reply in British English" is not a
judgement call, and asking a model whether to obey it each time is the wrong
question.

A non-empty `when` is judged by a model at run time. If no memory AI config is
set, so nothing can judge, **the row is treated as applying** — missing
something you wrote is worse than injecting one rule too many.

### Why plain language

`when` used to be a glob. Users kept writing descriptions into it, and
`minimatch` compiled those into a pattern that matched nothing — the row
silently never fired, with no warning anywhere. What people want to express is
usually "when I am doing this kind of work", not "when the path looks like
this".

Old glob-style rows are still read, and the editor warns you to rewrite them.
`*` and `**` are converted silently, since "always" is exactly what they meant.

### Editing it

The **Memory → Map** tab in the Logic Editor sidebar edits the table. Saving
writes `.cage/memory-map.json`; a watcher pushes it to the server, which sends
back any parse warnings. Rows it had to skip are reported rather than dropped
quietly — a row that vanishes takes a whole category of memory with it.

You can equally edit the JSON by hand. If the file does not exist, a built-in
default applies, so memory works before you configure anything.

## The memory AI config

Judging which rows apply is a model call, configured by **Memory AI Config** at
graph level. Nodes inherit it and can override it. Leave it unset and every
conditional row is treated as applying.

A small fast model is the right choice — the judgement is short and it runs
before the real work.

---

[← Logic Editor](logic-editor.md) · [Tools & Approval](tools.md) · [RAG](rag.md) · [Client Guide](README.md)
