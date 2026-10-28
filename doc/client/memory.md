# Project Memory

CAGE keeps notes about your project, and injects the relevant ones into a run.
Three kinds, with different rules about who writes them.

**History** is written for you: one file per source file, recording what was
changed and why. **The session record** is written for you too: what each step
of the current conversation did, so a step that runs again in a loop can see
what the last attempt found. **Rules** are written by you: standing
instructions, loaded when they apply — and, if you ask for it, added to by the
AI on your terms.

All three live in `.cage/` in your project, as plain Markdown you can read, edit
and commit. Which of them a run reads is decided by the memory AI — see
[What gets read](#what-gets-read). The model's file tools cannot open `.cage/`,
and retrieval does not index it, so what reaches a step is what the memory AI
chose.

---

## History, written automatically

At the end of a turn the server records one entry per file that was actually
written, into `.cage/files/<path>.md`. A later run reads it when the memory AI
picks it — see [What gets read](#what-gets-read).

- **Which files** comes from what `write_file` and `apply_patch` actually
  touched — not from the model's own account of the turn. Models routinely
  claim to have created files they never wrote, and recording those would
  invent history for files that do not exist.
- **Why** comes from the node's Summary output, flattened to one line so the
  file stays readable by a person.
- **Nodes with no Summary write nothing.** A build-verification pass that
  returns only a pass/fail report has no reason to record.

The `remember` tool lets the model add to the same files deliberately — useful
for what it *tried and rejected*, which no diff shows. History does not depend
on it: the server writes regardless.

This is deliberate. Earlier, `remember` was the only writer, and across three
test runs the model never once decided to call it. `.cage/files/` was never
created and every turn loaded nothing.

## The session record, written automatically

Every conversation has its own file, `.cage/sessions/<session id>.md`, which the
server writes as the graph runs:

- **After each Send To AI step**, one entry: the time, the node's title, and its
  Summary output as written — or its whole output, for a node without a
  Summary — plus the files that step wrote. Steps that produce images, audio or
  meshes record the files they produced.
- **Each message is one section**, headed by its start time and the first line
  of the message. When the run finishes, before the answer is marked done, the
  memory AI condenses that section into a short list, and the next message reads
  the condensed version. Without a memory AI config, or if condensing fails or is
  stopped, the section stays as written. An interrupted run is not condensed;
  resuming it writes into the same section, which is condensed when it finishes.
- **It follows the conversation, not the server.** The session id belongs to the
  conversation in your editor and survives a server restart, so the record does
  too. Starting a new chat starts a new file; the old one stays.

The point is loops. A graph that sends a step back to try again — a coder and a
build check, say — used to start every attempt from nothing: in one test the
coder ran three times and re-checked the same build environment each time,
although the first attempt's own summary already said what it had found. The
session record is where that summary goes.

Nothing is cut: a record longer than the node's memory budget is reported in the
debug pane, not truncated. Every read, write and condense is reported there too,
including an older extension that cannot write the record.

`.cage/sessions/` sits in your project folder, so it goes into git unless you
ignore it.

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

## What gets read

Before a step runs, the memory AI is given every candidate at once — every row
of the routing table, every history file in the project, and this
conversation's session record — together with the work the step is about to do,
and picks the ones that bear on it. Only those are read.

- **Rows with an empty `when` are always read**, whether or not the model picked
  them.
- **A row whose `when` could not be judged counts as applying** — missing a rule
  you wrote is worse than one too many.
- **History and the session record are read only when picked.** Whether the
  message names a file has no bearing on whether its history is read; what the
  step is doing does.
- **Without a memory AI config, no history and no session record are read.** The
  record is still written; rule rows are read as described above.

The debug pane lists everything that was not read, and why: not picked for this
task, no memory AI config, or the memory AI's pick failed.

**This changed in 0.2.0.** Before, a file's history was read when the file was
in play — named in the message, attached, or found by retrieval. A step that
named no file, which is most steps inside a loop, read no history at all.

## The memory AI config

Choosing what to read, condensing the session record and deciding what to write
back are model calls, configured by **Memory AI Config** at graph level. Nodes
inherit it and can override it. Leave it unset and every conditional row is
treated as applying, no history or session record is read, the session record
stays as written, and nothing is written to rule files automatically.

A small fast model is the right choice — the judgement is short and it runs
before the real work.

---

[← Logic Editor](logic-editor.md) · [Tools](tools.md) · [RAG](rag.md) · [Client Guide](README.md)
