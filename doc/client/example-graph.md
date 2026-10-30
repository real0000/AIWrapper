# A worked example: DemoCoder

`DemoCoder` is a **generic** build-and-check loop: plan the work, write the code, verify
it by running it, judge the report, and either finish or send the coder back with the
errors. Nothing in it names a task — what gets built is decided entirely by the chat
message.

**This is a reference, not a download.** Everything below is a real file, recorded field
by field so that nothing is invented for the sake of an example — but the parts that name
a model, a GPU or a context size describe *one particular machine*. On yours they are
wrong. Build the graph in the editor and set your own; the value of this page is the
*shape* — which node holds which setting, and why.

The machine-specific fields, so they are easy to spot as you read:

| Field | Here | On your machine |
|---|---|---|
| `aiConfigs[].model` | `qwen-coder-next`, `nemotron-3-embed-1b` | Whatever aliases your server's `config.xml` defines. The AI Config panel lists them |
| `aiConfigs[].cudaVisibleDevices` | placeholder UUIDs | Your own cards (`nvidia-smi --query-gpu=uuid --format=csv`), or empty to let the placer choose |
| `aiConfigs[].ctxSize` | `262144` | As much as your card and model allow — this graph needs headroom, see below |
| `ragEmbeddingConfig` | `rag` | Only if you have an embedding model. Leave empty and retrieval is off, which costs this graph nothing structural |

See [AI Configs](ai-config.md) for what each of those fields does and what your options
are. A fresh server also has no graphs at all — `data/logic_graphs/`, under the server's
working directory, fills up as clients upload them.

This page lists every parameter and says why it is set that way. Three of them are not
obvious, and each came from a run that failed silently; those are called out in
[Three settings that are not obvious](#three-settings-that-are-not-obvious).

For the file format itself see [graph-format.md](graph-format.md); for what each node
type does see [nodes.md](nodes.md).

---

## The shape of a run

```
Start ──Exec──▶ Planner ──Exec──▶ Coder ──Exec──▶ Verifier ──Exec──▶ Filter ──Exec──▶ Shape ──True──▶ Gate ──Case 1──▶ End
  │                 ▲                ▲                                   │              │                  │
  └──PROMPT─────────┴────────────────┤                                   │              └──False───────────┤
                                     │                                   │                                 │
                                     └───────────────Errors──────────────┘                                 │
                                     ▲                                                                     │
                                     └──────────────────────────Else───────────────────────────────────────┘
```

Two edges leave the loop back to the coder: `Shape.False` (the filter's reply was not
valid JSON) and `Gate.Else` (it was valid, and said the checks failed). Both re-enter
`Coder`, which the executor allows — a back edge clears the visited mark and the node
runs again.

There is **no iteration limit**. The loop ends when the filter reports a pass. If you
want a cap, add a `Variable` counter and a second `If`; this graph deliberately does
not, so that a run either converges or is stopped by you.

---

## Envelope

```json
{
  "name": "DemoCoder",
  "projectId": "",
  "owner": "",
  "ragEmbeddingConfig": "rag",
  "memoryAiConfig": "",
  "version": 3,
  "updatedAt": 0,
  "modalityConfigs": [],
  "variableConfigs": [],
  "groups": []
}
```

`owner` and `updatedAt` are blanked here; in the real file they name the account
that saved it and when.

| Field | Why |
|---|---|
| `ragEmbeddingConfig: "rag"` | Names the AI config used to embed. **Empty means RAG is off, not "use a default"** — both the indexing side and the query side read this one field, so they can never end up in different vector spaces |
| `memoryAiConfig: ""` | No memory AI. Conditional rules all apply, and no file history or [session record](memory.md#the-session-record-written-automatically) is read — the record is still written. The graph carries what the coder needs between rounds through shared memory instead (`memory_mode` below) |
| `variableConfigs: []` | No graph state. Everything that crosses a node boundary does so on a pin |

---

## AI configs

Two, and they do very different jobs. **These values are this machine's** — read them for
which field matters and why, not as settings to copy. What to do instead is in
[Building it on your machine](#building-it-on-your-machine).

```json
{
  "name": "coder",
  "model": "qwen-coder-next",
  "quantization": "",
  "isRemote": false,
  "remoteUrl": "", "remoteApiKey": "", "remoteFamily": "",
  "ctxSize": 262144,
  "nBatch": 0, "threads": 0,
  "flashAttn": true,
  "nGpuLayers": -1,
  "kvCacheType": "f16",
  "splitMode": "layer",
  "nCpuMoe": 0,
  "autoFit": false,
  "lookahead": false,
  "cudaVisibleDevices": "GPU-<uuid-1>,GPU-<uuid-2>,GPU-<uuid-3>,GPU-<uuid-4>",
  "temperature": 0.7, "topK": 40, "topP": 0.9
}
```

| Field | Why this value |
|---|---|
| `ctxSize: 262144` | Every node shares one conversation (see `memory_mode` below), so the context grows with each round. 16K and 80K were both tried first and both overflowed — the failure is an explicit `Input tokens (…) exceed` error, not a silent truncation |
| `cudaVisibleDevices` | **Your own card UUIDs** — `nvidia-smi --query-gpu=uuid --format=csv`. The placeholders above are not real; a UUID that does not exist on the machine loading the graph resolves to nothing, and the model then loads with no device restriction (with a warning) rather than failing. The graph this example came from listed four compute cards and left out the display card on purpose, which is the usual reason to set this field at all |
| `autoFit: false` | Placement is set by hand here: a layer split across the four listed cards. With Auto Fit on — the default — the same card list would stand and the server would choose the split itself |
| `splitMode: "layer"` | Layer-split across the four cards. Auto Fit would pick `graph` (tensor parallelism) across a fully NVLink-connected set of cards |
| `lookahead: false` | Measured slower than plain decoding on Volta for every parameter set tried |

```json
{
  "name": "rag",
  "model": "nemotron-3-embed-1b",
  "quantization": "fp16",
  "ctxSize": 65536,
  "autoFit": true,
  "nGpuLayers": -1,
  "cudaVisibleDevices": "GPU-<uuid-1>,GPU-<uuid-2>,GPU-<uuid-3>,GPU-<uuid-4>",
  "…": "remaining fields as above"
}
```

The embedder is a separate config only because it is a separate model; it is named by
`ragEmbeddingConfig`, not by any node. It honours `cudaVisibleDevices` like every other
model — set it, or the embedder loads on whatever card comes first, which on a mixed
machine is usually the display card.

`nemotron-3-embed-1b` ships as safetensors, which the in-process backend reads
directly — no conversion step, and the quantization is applied as it loads.

---

## Format config

One, referenced by two nodes.

```json
{
  "name": "verdict",
  "type": "json_keys",
  "pattern": "",
  "fields": [
    { "key": "Pass",
      "description": "true if every check passed, otherwise false",
      "required": true },
    { "key": "Errors",
      "description": "on failure, only the real error lines with file and line; none on success",
      "required": true }
  ]
}
```

A `json_keys` format does double duty. On the `Filter` node it is the structured-output
schema — the field descriptions are given to the model, and the keys become output pins.
On the `Shape` node it is the validation rule. That is why both reference the same name:
the thing that produced the JSON and the thing that checks it agree by construction.

---

## Nodes

### Start

```json
{ "start_name": "Default" }
```

`out[Exec, PROMPT, ASSET]`. `PROMPT` is the chat message, verbatim. This graph feeds it
to two nodes.

### Planner — `SendToAi`

`in[Exec, Asset, Request]` → `out[Exec, ALL, Asset]`

```json
{
  "ai_config": "coder",
  "format_config": "",
  "prompt_template": "…{{Request}}…",
  "tools_enabled": false,
  "allowed_tools": "*",
  "max_tool_iters": 5,
  "rag_mode": "inherit",
  "rag_embedding_config": "",
  "memory_context": true,
  "memory_history_top_k": 0,
  "memory_filter_config": "",
  "memory_mode": "shared",
  "chunking": false,
  "chunk_desc": ""
}
```

`Request` is a named input pin, and the template references it as `{{Request}}`. **A
named pin reaches the model only if the template mentions it** — wiring alone does
nothing. This was the cause of an early failure where the planner invented its own task:
the pin was connected, the placeholder was missing, and the planner never saw the request.

`tools_enabled: false` because planning is not a tool job, and a planner with tools
spends its budget reading the workspace instead of writing the plan.

The prompt asks for three lists — WORK, DELIVERABLES, CHECKS. DELIVERABLES exists
because an early run produced a test script that deleted the atlas it had just created:
nothing had told anyone that the program's output was the point rather than scratch.
The CHECKS paragraph insists on checking contents rather than existence, because a run
that only asserted "the file is present and parses as JSON" passed a manifest whose
every coordinate was `-1`.

### Coder — `SendToAi`

`in[Exec, Asset, Request, Errors]` → `out[Exec, ALL, Asset]`

Same config shape, with:

| Field | Value | Why |
|---|---|---|
| `tools_enabled` | `true` | It writes files |
| `max_tool_iters` | `20` | Set when the default was 5, which is not enough to write a small program: the loop ended early and the node returned nothing. The default is now `0`, no limit |
| `memory_mode` | `"shared"` | On the second and later rounds it needs to know what it already wrote |

Two named input pins, both referenced in the template: `{{Request}}` (the original ask,
so a later round does not drift) and `{{Errors}}` (what the filter extracted). On the
first round `Errors` has no value and resolves to an empty string — deliberate
fail-open, see the note under [Three settings](#three-settings-that-are-not-obvious).

The prompt's rules are each the residue of a specific failure: *one file per job* and
*fix in place* after a round that produced thirty files including two implementations
and three test scripts; *the program's output is a deliverable* after the self-deleting
test script; *do not build or run anything* to keep the roles separate, because a coder
that also verifies will report its own work as passing.

The last rule — *DELIVERABLES are produced later, when the verifier builds and runs what
you wrote* — came from the two before it colliding. The coder reads the plan, where
DELIVERABLES says "produced by running the program", and is told not to run anything;
nothing said who produces them. A coder that stopped to reconcile the two spent one
generation of 20,000 tokens — forty minutes — weighing whether to hand-write a binary
image, whether a scratch tool counted as running, and writing the program over in its
reasoning, before making its first tool call. In the same context it did that three
times in four tries; with the rule added, it started work at once in both tries made.

### Verifier — `SendToAi`

`in[Exec, Asset]` → `out[Exec, ALL, Asset]`

`tools_enabled: true`, `max_tool_iters: 20`, `memory_mode: "shared"`, no named input
pins — it reads the workspace directly rather than being handed anything.

Its prompt is the longest in the graph, and every bullet is a rule that a run broke:

- Build from source every round, and run the program yourself. Do not assume the
  previous round's build or artefacts survive.
- Leave everything in place. No cleanup.
- If something the coder wrote deletes a deliverable, that is the defect — report it as
  a fault in the code, not as a missing file. Without this the loop cannot converge: the
  artefact is gone every round and nothing identifies why.
- Judge the result, not the run. A zero exit code and a success message are claims.
  Sentinel values where a real result belongs are a failure.
- Trace one value end to end: find something identifiable on the input side, find it on
  the output side, confirm it survived. Output with the right shape and wrong contents
  still fails.

### Filter — `SendToAi`

`in[Exec, Asset, Transcript]` → `out[Exec, ALL, Asset, Pass, Errors]`

```json
{
  "ai_config": "coder",
  "format_config": "verdict",
  "prompt_template": "…{{Transcript}}…",
  "tools_enabled": false,
  "max_tool_iters": 5,
  "rag_mode": "off",
  "memory_context": true,
  "memory_history_top_k": 0,
  "chunking": false
}
```

`Pass` and `Errors` are **output** pins named after the format's keys, so the structured
reply is split for you and each half can be wired somewhere different.

No tools and no shared memory: its whole input is `{{Transcript}}`, and its whole job is
to turn a page of verifier prose into one boolean and a short error list. `rag_mode` is
`off`, which is the third of the three non-obvious settings below.

### Shape — `CheckFormat`

`in[Exec, Input]` → `out[True, False, Output]`

```json
{ "format_config": "verdict", "error_message": "" }
```

It validates the filter's reply against the same schema the filter was given. `True`
continues to the gate; `False` goes back to the coder, treating an unparseable verdict
as a round that has to be redone.

### Gate — `If`

`in[Exec, Input, IfPass]` → `out[Case 1, Else]`

```json
{
  "cases": [{
    "name": "Case 1",
    "value_type": "bool",
    "operator": "is_true",
    "compare_value": "",
    "json_path": "",
    "source_type": "input",
    "source_key": "IfPass",
    "source_variable": "",
    "case_sensitive": true
  }]
}
```

`source_type: "input"` with `source_key: "IfPass"` reads the named input pin. The `Input`
pin is a built-in that this node does not use — that is normal for `If`, which addresses
its source by name.

### End

```json
{ "result_keys": [] }
```

---

## Connections

Fifteen. Four are data; the rest are control flow.

| From | To | Kind | Why |
|---|---|---|---|
| `Start.Exec` | `Planner.Exec` | exec | entry |
| `Start.PROMPT` | `Planner.Request` | data | the request |
| `Start.PROMPT` | `Coder.Request` | data | the same request, so a later round does not drift from it |
| `Planner.Exec` | `Coder.Exec` | exec | |
| `Coder.Exec` | `Verifier.Exec` | exec | |
| `Verifier.Exec` | `Filter.Exec` | exec | |
| `Verifier.ALL` | `Filter.Transcript` | data | the whole verifier reply becomes the filter's input |
| `Filter.Exec` | `Shape.Exec` | exec | |
| **`Filter.ALL`** | **`Shape.Input`** | **data** | **required — see below** |
| `Filter.Pass` | `Gate.IfPass` | data | the verdict the gate branches on |
| `Filter.Errors` | `Coder.Errors` | data | the feedback the next round works from |
| `Shape.True` | `Gate.Exec` | exec | valid JSON → decide |
| `Shape.False` | `Coder.Exec` | exec | invalid JSON → redo the round |
| `Gate.Case 1` | `End.Exec` | exec | pass → finish |
| `Gate.Else` | `Coder.Exec` | exec | fail → redo with the errors |

Note that `Start.PROMPT` feeds two nodes. Exec outputs have a single target; **data
outputs may fan out.**

---

## Three settings that are not obvious

### 1. `Filter.ALL → Shape.Input` — a `CheckFormat` needs its data edge

Connecting only `Filter.Exec → Shape.Exec` looks complete on the canvas and is
structurally valid. It is not enough. `CheckFormat` validates whatever arrives on
`Input`; with no edge there it validates the empty string, fails, and takes `False`
every single round.

The symptom is a loop that never converges **and an `If` node that never executes at
all** — `Shape.False` goes straight back to the coder, so the gate is never reached.
There is no error message anywhere, because data edges are
`ctx.set(toPort, ctx.get(fromPort))` and an unresolved key is deliberately treated as an
empty string. That fail-open is wanted elsewhere (`{{Errors}}` has no value on the first
round and should not print a placeholder at the model), and it is what makes this
particular mistake silent.

**When a loop will not converge, count how many times each node ran.** A node with zero
executions is a wiring fault, not a model problem.

### 2. `memory_mode` — shared for the actors, isolated for the judge

Planner, Coder and Verifier use `"shared"`. Each one's final answer is appended to one
session-level conversation, and each sees the projection of it before its own prompt. A
re-entered `Coder` therefore knows what it wrote last round and what the verifier said
about it, without any of that being threaded through pins.

The `Filter` stays `"isolated"` (the default). Its input is one transcript and its output
is one verdict; giving it the conversation would let a verdict it produced two rounds ago
influence the one it is producing now — the opposite of what a judge should do.

The observable effect is in the log: `memory=shared: seeded N messages`, with N growing
by one per node per round.

Your message joins that conversation as soon as it arrives. When the run ends without
a shared node having answered it — the run was stopped, failed, never started, or
answered from isolated nodes only — the server adds the answer itself: the run's final
result, or a line saying what happened to it. The next message's nodes never see two of
your messages in a row with nothing in between.

### 3. `rag_mode: "off"` on the Filter — retrieval poisons a judge

Retrieved context is prepended to the prompt as `### file (lines A-B)` blocks of code
chosen by similarity. For a node that acts on the codebase that is help. For a node whose
job is to grade an answer it is evidence of the wrong kind, and models draw conclusions
from fragments that fragments do not support.

With `rag_mode: "inherit"` this filter returned `Pass=false` four rounds running, with
errors like:

```
packer.cpp:169-173: incomplete code block: missing closing brace
packer.cpp:248-341: missing code after line 341
```

Those line ranges are, one for one, the RAG chunk boundaries printed in the same debug
ping. The program compiled and ran correctly the whole time. Nothing reported an error;
the loop simply could not end.

**A node that judges a piece of text rather than the codebase should have RAG off.**
The retrieval query is `PROMPT` — the original chat message — so what a judge gets back
is "code resembling the original request", which it can read directly with tools anyway.
The `Planner` and `Coder` keep `"inherit"`, because orienting in existing code is exactly
what retrieval is for.

---

## What it produced

One measured run, so the numbers mean something:

| | |
|---|---|
| Chat message | *"A C++17 texture packer: pack a folder of TGA files into one atlas image plus a JSON manifest. Standard library only."* |
| Hardware | 4 × Tesla V100-SXM2-32GB, `qwen-coder-next` at 262144 context |
| Result | Converged on the **first** iteration, `Pass=true` → `End` |
| Wall clock | 15 m 23 s — planner 12.7 s, coder 8 m 41 s, verifier 6 m 28 s, filter 1.0 s |
| Output | 7 TGAs of three sizes and two bit depths packed into a 720×256 atlas plus a JSON manifest |
| Checked afterwards | Pixel data byte-for-byte identical to the sources; manifest coordinates correct |
| Not caught by the pipeline | The output TGA's descriptor byte carries the opposite origin flag from the inputs, so a viewer shows the atlas vertically flipped. The pixels are right; the header is not |

That last row is the honest limit of the arrangement. The checks the planner wrote and
the verifier ran were about geometry and content, and both were satisfied. A one-byte
header flag was outside what anyone thought to check.

---

## Building it on your machine

The structure transfers; the AI configs do not. In order:

1. **One AI config is enough to start.** Name it, pick a model your server actually
   serves, and point all four `SendToAi` nodes at it. Different models per role is a
   refinement, not a requirement.
2. **Give it as much context as you can.** With `memory_mode: "shared"` the conversation
   grows by one message per node per round, so a loop that runs several times needs
   headroom. If your card cannot spare it, set the three actors to `"isolated"` and pass
   what they need through pins instead — the graph still works, it just forgets more
   between rounds. Overflow is an explicit `Input tokens (…) exceed` error, not silent
   truncation, so you will know.
3. **Retrieval is optional.** No embedding model, or no wish to index — leave
   `ragEmbeddingConfig` empty and every `rag_mode: "inherit"` becomes a no-op. Nothing
   structural depends on it. If you do enable it, keep the Filter at `"off"`.
4. **GPU selection is optional too.** Leave `cudaVisibleDevices` empty and the placer
   chooses. Set it when a card in the machine should be left alone — a display card, or
   one another job is using.

Then the task goes in the chat message, not in the graph.

## Changing how it behaves

| Want | Change |
|---|---|
| A different model per role | Add AI configs and point each node's `ai_config` at one. Nothing else has to change |
| An iteration cap | A `Variable` counter incremented on the back edge, plus an `If` before `Coder` |
| A cheaper judge | Point `Filter.ai_config` at a small model. It only classifies text |
| Fewer rounds | Strengthen the CHECKS paragraph in the planner. Most extra rounds come from checks that were too weak to fail the first time |
| A different pipeline shape | The four prompts are independent of the wiring. Swapping "verifier" for "test runner" or "security reviewer" is a prompt change, not a graph change |

---

[← Graph file format](graph-format.md) · [Node types](nodes.md) · [AI Configs](ai-config.md) · [RAG](rag.md) · [Client Guide](README.md)
