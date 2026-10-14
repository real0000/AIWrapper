# Project Memory

CAGE keeps notes about your project between sessions, and injects the relevant
ones into a run. Two kinds, with different rules about who writes them.

**History** is written for you: one file per source file, recording what was
changed and why. **Rules** are written by you: standing instructions, loaded
when they apply — and, if you ask for it, added to by the AI on your terms.

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
should be loaded, and — optionally — when the AI may add to it:

```json
{
  "version": 1,
  "rows": [
    { "when": "",                      "file": ".cage/memory.md",    "write": "" },
    { "when": "when editing C++ code", "file": ".cage/types/cpp.md",
      "write": "when we settle on a new C++ convention, or hit a trap worth avoiding, record the rule and why" },
    { "when": "anything about GPU placement or VRAM", "file": ".cage/gpu.md", "write": "" }
  ]
}
```

| Field | Meaning |
|---|---|
| `when` | **Plain language**, not a glob. Empty means always |
| `file` | Project-relative path to the rule file. No variables — name the file |
| `write` | **Plain language**: when the AI should write to this file, and what. Empty means read-only |

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

**Chat → 🧠 Memory** edits the table — one row is three fields: `when`, `file`,
`write`. Saving writes `.cage/memory-map.json`; a watcher pushes it to the
server, which sends back any parse warnings.

It sits next to Settings rather than inside the Logic Editor because it belongs
to the **project**, not to a graph: every graph in this project reads the same
table. What a graph does own is which model does the judging — the Memory AI
Config in the Logic Editor's Memory section.

Rows the server had to skip are reported rather than dropped quietly — a row that
vanishes takes a whole category of memory with it.

You can equally edit the JSON by hand. If the file does not exist, a built-in
default applies, so memory works before you configure anything.

## Letting the AI add to a rule file

`write` is the whole specification, in your own words — both the trigger and the
content, because that is how you would say it out loud: *"when we settle on a
new C++ convention, record the rule and why"*. Leave it empty and the file is
read-only; nothing ever writes there. That is the default, so an existing
routing table behaves exactly as it did.

A file you have marked writable is reached two ways, and they cover for each
other:

- **The model can write to it during the turn.** Writable files are listed in
  the memory block it receives, and `remember` takes a `target` naming one of
  them. Anything else is refused — the routing table is the only gate, and it is
  checked in the client, which is where the table lives.
- **The server checks when a Send To AI node finishes.** It asks the memory
  model whether what just happened matches your instruction, and if so, what one
  line to record — one call covering every writable file, and only when the node
  actually produced something. This exists because the model volunteering is not
  enough: when `remember` was the only writer, three test runs went by without it
  being called once. (In a graph with several Send To AI nodes, each one that
  runs gets that check, so keep the memory model small.)

Either way the line is timestamped and **appended** to the end of the rule file,
below whatever you wrote there. (File history is the other way round — newest
first — because that file is read as a log.) The two paths do not double up: a
file the model already wrote to this turn is skipped by the end-of-turn check.

A row's `when` gates both halves. A file loaded only "when editing C++ code" is
not written to in a turn that had nothing to do with C++.

**Without a memory AI config, nothing is written automatically.** This is the
opposite of the reading side, on purpose: failing to load a rule costs you one
missing instruction, while writing something nothing judged puts unreviewed text
into a file of yours that goes into git. The model can still write with
`remember` itself, since that is its own deliberate act.

Every decision is reported in the debug pane — which files were offered as
writable, what was written, and, when nothing was, why not. A row you filled in
that silently does nothing is the failure this feature has to avoid.

## The memory AI config

Judging which rows apply — and what, if anything, to write back — is a model
call, configured by **Memory AI Config** at graph level. Nodes inherit it and can
override it. Leave it unset and every conditional row is treated as applying,
and nothing is written automatically.

A small fast model is the right choice — the judgement is short and it runs
before the real work.

---

[← Logic Editor](logic-editor.md) · [Tools](tools.md) · [RAG](rag.md) · [Client Guide](README.md)
