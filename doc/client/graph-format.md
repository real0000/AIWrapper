**English** · [繁體中文](graph-format.zh-TW.md)

# Logic graph file format

A logic graph is one JSON file. This page specifies it completely enough that a
program — including an AI agent asked for "a graph that does X" — can write a
valid one without opening the editor.

Everything here is derived from the implementation:
`server/include/logic/LogicGraph.hpp` (the data model),
`server/src/logic/nodes/*.cpp` (what each node reads from `config`), and
`client/extension/src/logic/nodeLibrary.ts` (the pins and defaults the editor
writes).

---

## Where the file lives

| | |
|---|---|
| Path | The server's graph store — `data/logic_graphs/` under the server's working directory |
| Filename | `<name>.json`. A graph's `name` is its identity: unique, compared without regard to case, and its file name. A file named anything else is renamed to match its `name` when the server starts |
| Getting one in | Write the file and restart the server, `PUT` it to `/api/logic-graph`, or use **Import** in the Logic Editor |

The editor's **Export** writes this format too, plus a few editor-only layout
fields such as connection `waypoints`, so an existing graph is the best reference
for anything this page leaves ambiguous.

> Some examples below carry `//` comments to explain a field. **JSON has no
> comments** — strip them before writing a file. The
> [complete example](#a-complete-minimal-graph) at the end has none and can be
> copied as-is.

---

## The envelope

```json
{
  "name":               "SimpleCoder",
  "projectId":          "",
  "owner":              "",
  "ragEmbeddingConfig": "",
  "memoryAiConfig":     "",
  "version":            1,
  "updatedAt":          0,
  "nodes":              [],
  "connections":        [],
  "aiConfigs":          [],
  "modalityConfigs":    [],
  "formatConfigs":      [],
  "variableConfigs":    [],
  "groups":             []
}
```

| Field | Meaning |
|---|---|
| `name` | The graph's identity and file name, shown in the graph selector. Unique without regard to case. At most 250 bytes of UTF-8; none of `/` `\` `:` `*` `?` `"` `<` `>` `\|` or control characters; no space at either end, no trailing dot, and not `.` or `..`. Renaming is its own operation (`POST /api/logic-graph/rename`): saving under a new name creates a second graph |
| `projectId` | Project folder this graph belongs to. Empty is fine |
| `owner` | The account that owns the graph. **The server fills it in:** a graph uploaded with `PUT` or **Import** belongs to the account that uploaded it, and later saves never change it. Only a file placed straight into the folder keeps the value written in it, and there empty means unowned — readable and writable by anyone |
| `ragEmbeddingConfig` | Name of an entry in `aiConfigs` to use for automatic retrieval. Empty disables it |
| `memoryAiConfig` | Name of an entry in `aiConfigs`: the memory AI, which chooses what memory each step reads, condenses the session record and decides what to write back. Empty treats every conditional rule as applying and reads no file history or session record — see [Project Memory](memory.md) |
| `version` | Incremented by the editor on every save; the server rejects an update carrying a version older than its own. **Start at 1** |
| `updatedAt` | Unix milliseconds. `0` is accepted |
| `groups` | Visual grouping. `[]` unless you are reproducing an editor layout |

Write all seven lists, even when empty. A missing one is read as empty.

---

## Nodes

```json
{
  "id":       "5b0c1f2e-8d4a-4f7b-9c3e-2a6d8e1f4b70",
  "type":     "Start",
  "title":    "Start",
  "category": "start",
  "position": { "x": -420, "y": 400 },
  "inputs":   [],
  "outputs":  [ { "name": "Exec", "type": "exec", "direction": "output", "id": "…" } ],
  "config":   { "start_name": "Default" },
  "singleton": true
}
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | UUID, unique in the graph. Connections reference it |
| `type` | yes | One of the twelve types below |
| `title` | yes | Free text, shown on the node |
| `category` | yes | Used for colouring: `start`, `ai` (Send To AI, Dispatch, Send Prompt, Ask User), `check`, `logic`, `variable`, `compose`, `memory`, `end` (Return, End) |
| `position` | yes | Editor coordinates. Any numbers work; lay graphs out left to right, ~250 px apart, or they overlap |
| `inputs` / `outputs` | yes | Pin arrays — see each type. Each pin needs `name`, `type`, `direction`; `id` is optional |
| `config` | yes | Per-type settings. `{}` if the type has none |
| `singleton` | no | `true` on `End` and on the `Start` named `Default` — the two nodes the editor will not delete. Editor-only hint |
| `groupId` | no | Only when the node is inside a group |

### Pin types

`exec` is control flow. Everything else is data: `string` is the common case,
and `asset` / `image` / `audio` / `tts` / `music` / `mesh` / `motion` carry a
reference to a produced file rather than text.

**The distinction matters.** An `exec` connection transfers control — it queues
the downstream node to run. A data connection only copies a value into the
downstream input slot and does **not** cause it to run. A node with no incoming
`exec` connection never executes, however many data connections it has. The one
exception is a `Variable` node's getter pins, which are read when needed — see
`Variable` below.

---

## Connections

```json
{
  "id":         "9e4a7c21-3b5d-4e8f-a1c6-7d2b0f9e3a58",
  "fromNodeId": "5b0c1f2e-…",
  "fromPinId":  "Exec",
  "toNodeId":   "c3f81a96-…",
  "toPinId":    "Exec"
}
```

`fromPinId` and `toPinId` accept **either the pin's `name` or its `id`** — the
server resolves an id to the name it belongs to, and treats anything it cannot
resolve as a name. Names are clearer to write and are what this page uses; the
editor emits ids. Both appear in shipped graphs.

Use the canonical `connections` array. `edges` is a legacy load path that
assumes every connection is control flow.

---

## Node types

**The pin lists below are what the editor creates for a new node, not a minimum
requirement.** A pin only has to exist if something connects to it, and real
graphs routinely omit the ones they do not use — `SendToAi` without `Asset`
when nothing multimodal is wired, `Start` without `ASSET`, `If` without `Input`
when its cases read from a variable instead.

The one pin that is effectively always required is `Exec`: without an incoming
`exec` connection a node never runs. Where a type lets you add your own pins,
that is stated.

### `Start` — entry point
`in[]` → `out[Exec, PROMPT, ASSET]`

`PROMPT` carries the user's message; `ASSET` any attachment.

```json
"config": { "start_name": "Default" }
```

A graph may have several `Start` nodes with different `start_name` values; the
chat panel's Start selector chooses among them. One must be named `Default`.

### `SendToAi` — a model call
`in[Exec, Asset]` → `out[Exec, ALL, Asset]`

**Add one `string` input pin per prompt variable**, then reference it in the
template as `{{pinName}}`. A `{{name}}` that matches no pin falls back to the
graph variable of that name; one that matches neither becomes an empty string.
`ALL` is the full reply. Add `string` output pins named after keys of the
structured output to have them split out for you.

```json
"config": {
  "ai_config": "planner",          // name from aiConfigs — required
  "format_config": "",             // name from formatConfigs; enables structured output
  "prompt_template": "Plan: {{Task}}",
  "tools_enabled": true,
  "allowed_tools": "*",            // "*" or a comma-separated list
  "max_tool_iters": 0,             // 0 = no limit
  "rag_mode": "inherit",           // inherit | off | custom
  "rag_embedding_config": "",      // with rag_mode="custom"
  "memory_context": true,
  "memory_history_top_k": 0,       // 0 = keep every file history
  "memory_mode": "isolated",       // isolated | shared — see below
  "chunking": false,
  "chunk_desc": ""
}
```

`memory_mode: "shared"` puts the node in the conversation that the session's
shared nodes have in common: before its prompt it sees the user's messages and
what earlier shared nodes answered, and its own answer is added for the next
one. That is how a node that runs again in a loop remembers its last round.
`"isolated"`, the default, sees only its own prompt. Neither editor has a field
for this setting — write it into the file. The
[worked example](example-graph.md) uses both.

The model's load and sampling values come from the named AI config every time
the node runs. Keys such as `ai_model` or `temperature` written into a node's
`config` are not a per-node override — the server replaces them with the AI
config's values. To vary them for one node, give it an AI config of its own.

> Pointing `ai_config` at a `modalityConfigs` name instead turns the node into a
> generation call — image, speech and so on. The template becomes the
> generation prompt, and input pins it does not reference are passed as
> generation parameters. The produced files come out on `Asset`, and as
> server-side paths on `ALL` (speech recognition and voice detection put their
> text there instead). Pin names with a fixed meaning — `image`, `audio`,
> `out_dir`, `OutputFile` — are listed in
> [Modality Configs](modality-config.md#using-one-in-a-graph).

### `CheckFormat` — validate a string
`in[Exec, Input]` → `out[True, False, Output]`

```json
"config": { "format_config": "plan_json", "error_message": "" }
```

### `If` — branch
`in[Exec, Input]` → `out[Case 1, Else]`

Add one output pin per case; pin names must match the case `name`s in order.
`Input` is only needed when a case has `source_type: "input"` — cases reading a
variable do not require it.

```json
"config": {
  "cases": [
    {
      "name": "Case 1",
      "source_type": "input",       // input | variable
      "source_key": "Input",        // which input pin, when source_type=input
      "source_variable": "",        // which variable, when source_type=variable
      "value_type": "string",       // string | number | bool | json | enum
      "operator": "is_not_empty",
      "compare_value": "",
      "json_path": "",              // value_type=json
      "case_sensitive": true
    }
  ]
}
```

Operators by `value_type`:

| `value_type` | Operators |
|---|---|
| `string` (default) | `equals`, `not_equals`, `contains`, `not_contains`, `starts_with`, `ends_with`, `regex`, `is_empty`, `is_not_empty` |
| `number` | `equals`, `not_equals`, `less_than`, `less_or_equal`, `greater_than`, `greater_or_equal`, `is_empty`, `is_not_empty` |
| `bool` | `is_true`, `is_false`, `is_empty`, `is_not_empty` |
| `json` | `has_key`, `path_equals`, `is_valid`, `is_empty`, `is_not_empty` |
| `enum` | `equals`, `not_equals`, `is_empty`, `is_not_empty` — always case-sensitive |

Cases are tried in order; the first match wins, otherwise `Else`.

### `Variable` — read and write graph state
`in[Exec]` → `out[Exec]`

```json
"config": {
  "items": [
    { "variable": "counter", "op": "set",   // set | add
      "source_type": "constant",            // constant | node | variable
      "source_value": "0" }
  ]
}
```

`add` means numeric addition, string concatenation, or logical OR depending on
the variable's declared `type`.

`source_value` depends on `source_type`: with `"constant"` it is the value
itself, with `"variable"` the name of another variable, and with `"node"` the
name of a `string` input pin on this node — add that pin, and the value arriving
on it is what gets stored.

**Getter pins** go the other way. Add a `string` output pin named after a
variable, and nodes wired to it receive the variable's current value, read at
the moment they run. A `Variable` node used only for its getter pins needs no
`exec` connection.

### `Compose` — build a string
`in[Exec]` → `out[Exec, Output]`

Add one `string` input pin per value. The template references input pins **and**
graph variables by the same `{{name}}` syntax.

```json
"config": { "template": "Task: {{Task}}\nGoal: {{goal}}" }
```

### `Memory` — project memory as text
`in[Exec, Input]` → `out[Exec, Memory]`

```json
"config": { "token_budget": 0, "history_top_k": 0 }
```

A `SendToAi` node scans memory itself each time it runs and does not read a
`Memory` pin, so this node is for nodes that read its text — `Compose`'s
`{{Memory}}`, or a prompt that references `{{Memory}}`. The graph's
`memoryAiConfig` does the choosing.

### `Dispatch` — split work and run it item by item
`in[Exec, Input]` → `out[Step, Task, Index, Plan, End]`

A splitter model turns the input into a list; `Step` fires once per item with
`Task` and `Index` set, then `End` fires once at the finish.

```json
"config": {
  "splitter_ai_config": "planner",
  "parallel_enabled": false,
  "max_parallel": 0               // 0 = no limit
}
```

**End each `Step` branch with `Return`, not `End`.**

### `SendPrompt` — hand the work to another graph
`in[Exec, Prompt, Asset]` → `out[Exec, Result, Asset]`

Runs another graph once, in the same session, and takes back its result.

```json
"config": {
  "graph_name": "Coder",          // the other graph's name — required
  "entry": "",                    // its Start's start_name; empty = its first Start
  "max_depth": 0                  // how deep SendPrompt calls may nest; 0 = no limit
}
```

### `AskUser` — ask the operator
`in[Exec, Input]` → `out[Exec, Answers, Asked]`

```json
"config": {
  "ai_config": "",         // judges whether asking is warranted
  "criteria": "",
  "max_questions": 0,      // 0 = no limit
  "allow_free_text": true
}
```

### `Return` — end a branch
`in[Exec]` → `out[]`

```json
"config": { "note": "" }
```

Declares that this path stops deliberately. It does not return a result and does
not close the run.

### `End` — finish the run
`in[Exec, Result]` → `out[]`

```json
"config": { "result_keys": [] }
```

Returns the result to the user and ends the run: what arrives on `Result` is the
answer. Leave `result_keys` empty. **Reachable from the main path only** — never
from a `Dispatch` branch.

---

## The four configuration lists

### `aiConfigs`

```json
{
  "name": "planner",
  "model": "Qwen3-Coder-Next",
  "isRemote": false,
  "quantization": "",
  "ctxSize": 0,          // 0 = the default: 32K, or the model's maximum if shorter
  "nBatch": 0,
  "threads": 0,
  "flashAttn": true,
  "nGpuLayers": -1,      // -1 = auto
  "kvCacheType": "f16",
  "splitMode": "layer",  // layer | graph | attn | none — used only with autoFit off
  "nCpuMoe": 0,
  "autoFit": true,
  "lookahead": false,
  "mtp": false,
  "cudaVisibleDevices": "",   // GPU UUIDs, comma-separated; empty = every GPU
  "temperature": 0.7,
  "topK": 40,
  "topP": 0.9,
  "reasoningBudget": -1,      // -1 = no limit
  "presencePenalty": 0        // 0 = off
}
```

For a hosted endpoint set `"isRemote": true` with `remoteUrl`, `remoteApiKey`
and `remoteFamily` (`openai` | `anthropic` | `gemini`); the load parameters are
then ignored while the sampling ones still apply.

`autoFit: true`, the default, decides split mode, device order and expert
offload from the machine's actual topology. With it off, `splitMode` chooses:
`layer` splits the model by layer, `graph` splits every layer's computation
across the cards (tensor parallelism), `attn` splits the self-attention
computation across them, and `none` keeps the model on one card. `row` and
`tensor`, the names older graphs use, run as `graph`.

### `variableConfigs`

```json
{ "name": "counter", "type": "number", "defaultValue": "0",
  "description": "", "enumValues": [] }
```

`type` is `string` | `number` | `bool` | `enum`. Variables live for one run.

### `formatConfigs`

```json
{ "name": "plan_json", "type": "json",   // json | json_keys | regex | non_empty
  "pattern": "",
  "fields": [ { "key": "steps", "description": "…", "required": true } ] }
```

Naming one in a `SendToAi` node's `format_config` also turns on structured
output, so `fields` is worth filling in.

### `modalityConfigs`

```json
{ "name": "sd35", "type": "image",
  "isRemote": false,
  "modalityAlias": "sd35",              // <model alias> in the server config
  "cudaVisibleDevices": "",
  "remoteFamily": "openai", "remoteUrl": "", "remoteApiKey": "", "remoteModel": "",
  "defaults": {} }
```

`type` is one of `image`, `tts`, `audio`, `music`, `mesh`, `motion`, `asr`, `vad`
and `separation`. For a local model the server goes by what the alias is
registered as, and this field is only a fallback. A remote config sets
`"isRemote": true` with `remoteFamily` (`openai` | `stability` | `elevenlabs` |
`replicate` | `fal`), `remoteUrl`, `remoteApiKey` and `remoteModel`; only `image`
and `tts` work remotely. `defaults` holds the model's generation parameters —
steps, size and so on — which a node can override through its pins. See
[Modality Configs](modality-config.md).

---

## Rules that decide whether a graph runs

1. **Exactly one `Start` per entry point**, one of them named `Default`.
2. **Every node needs an incoming `exec` connection**, directly or through the
   chain. Data connections alone never make a node run. A `Variable` node used
   only for its getter pins is the exception: it is read, not run.
3. **`End` finishes the whole run.** Branches from `Dispatch` end with `Return`.
4. **Names are references.** Every `ai_config`, `format_config`, variable and
   modality name in a node's `config` must exist in the matching list. A
   misspelling fails at run time, not load time.
5. **Pin names in connections must exist** on both nodes, spelled exactly.
6. **A back edge re-runs its target** — the visited set is cleared, which is how
   loops work. Make sure something can end the loop.
7. **Node and connection `id`s must be unique.** The graph's own identity is its
   `name`, which is also its file name.

---

## A complete minimal graph

Takes the user's message, sends it to a model, returns the reply.

Copy it, change one thing, and it runs: **`aiConfigs[0].model` must name a model
your server actually has.** The name below is a placeholder. A graph naming a
model that is not configured loads fine and then fails when the node runs, which
is a confusing way to find out.

No example graph is installed for you, for that reason — a starter graph would
name a model you may not have, and a broken example is worse than none. This is
the example.

It is also the test: this graph was written from this page rather than drawn in
the editor. For 0.2.0 the block below was read straight out of this page, sent
to the server with `PUT /api/logic-graph`, and run: it answered, with one `done`
and no errors. That is the shortest proof the page is complete.

```json
{
  "name": "Minimal",
  "projectId": "", "owner": "",
  "ragEmbeddingConfig": "", "memoryAiConfig": "",
  "version": 1, "updatedAt": 0,
  "groups": [], "modalityConfigs": [], "formatConfigs": [], "variableConfigs": [],
  "aiConfigs": [
    { "name": "main", "model": "Qwen3-Coder-Next", "isRemote": false,
      "ctxSize": 0, "nGpuLayers": -1, "autoFit": true,
      "temperature": 0.7, "topK": 40, "topP": 0.9 }
  ],
  "nodes": [
    { "id": "aaaaaaaa-0000-0000-0000-000000000001",
      "type": "Start", "title": "Start", "category": "start",
      "position": { "x": 0, "y": 0 },
      "inputs": [],
      "outputs": [
        { "name": "Exec",   "type": "exec",   "direction": "output" },
        { "name": "PROMPT", "type": "string", "direction": "output" },
        { "name": "ASSET",  "type": "asset",  "direction": "output" }
      ],
      "config": { "start_name": "Default" }, "singleton": true },

    { "id": "aaaaaaaa-0000-0000-0000-000000000002",
      "type": "SendToAi", "title": "Answer", "category": "ai",
      "position": { "x": 300, "y": 0 },
      "inputs": [
        { "name": "Exec",  "type": "exec",   "direction": "input" },
        { "name": "Asset", "type": "asset",  "direction": "input" },
        { "name": "Task",  "type": "string", "direction": "input" }
      ],
      "outputs": [
        { "name": "Exec",  "type": "exec",   "direction": "output" },
        { "name": "ALL",   "type": "string", "direction": "output" },
        { "name": "Asset", "type": "asset",  "direction": "output" }
      ],
      "config": {
        "ai_config": "main",
        "prompt_template": "{{Task}}",
        "tools_enabled": true, "allowed_tools": "*", "max_tool_iters": 0,
        "rag_mode": "inherit", "memory_context": true
      } },

    { "id": "aaaaaaaa-0000-0000-0000-000000000003",
      "type": "End", "title": "End", "category": "end",
      "position": { "x": 600, "y": 0 },
      "inputs": [
        { "name": "Exec",   "type": "exec",   "direction": "input" },
        { "name": "Result", "type": "string", "direction": "input" }
      ],
      "outputs": [],
      "config": { "result_keys": [] }, "singleton": true }
  ],
  "connections": [
    { "id": "c1", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000001", "fromPinId": "Exec",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000002", "toPinId": "Exec" },
    { "id": "c2", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000001", "fromPinId": "PROMPT",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000002", "toPinId": "Task" },
    { "id": "c3", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000002", "fromPinId": "Exec",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000003", "toPinId": "Exec" },
    { "id": "c4", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000002", "fromPinId": "ALL",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000003", "toPinId": "Result" }
  ]
}
```

Note the shape of it: `Exec` carries control from Start to SendToAi to End,
while `PROMPT` and `ALL` carry data alongside. Both are needed — control without
data gives an empty prompt, data without control never runs.

---

## Checking your work

Most of the rules above can be checked by reading the file, and these are the
mistakes that otherwise surface as a graph that loads fine and then quietly does
nothing:

- **A `Start` named `Default`** exists.
- **Every connection's nodes and pins exist** — `fromNodeId` / `toNodeId` name
  nodes in the file, and `fromPinId` / `toPinId` name a pin of that node, by
  `name` or by `id`. A connection left behind by editing, pointing at a node or
  pin that is gone, is silent at run time: the value simply never arrives.
- **Every `ai_config`, `splitter_ai_config` and `format_config` names an entry**
  of `aiConfigs` (or `modalityConfigs`) and `formatConfigs`.
- **Every node except `Start` has an incoming connection from an `exec` pin.**
  Without one it never runs. The only exception is a `Variable` used just for
  its getter pins.

One silent class passes every check above, because it is structurally valid: a
pin that exists and is simply never connected. `CheckFormat` with no edge into
`Input` validates the empty string and fails every time; a `{{placeholder}}` with
no producer expands to nothing. See
[the worked example](example-graph.md#three-settings-that-are-not-obvious) for what
that looks like from the outside.

---

[← Logic Editor](logic-editor.md) · [Node types](nodes.md) · [Worked example](example-graph.md) · [AI Configs](ai-config.md) · [Client Guide](README.md)
