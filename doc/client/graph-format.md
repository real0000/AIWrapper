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
| Filename | `<graph id>.json`, where the id is the `id` field inside the file. They must match; the store renames the file if they do not |
| Getting one in | Write the file and restart the server, `POST` it over the API, or use **Import** in the Logic Editor |

The editor's **Export** writes exactly this format, so an existing graph is the
best reference for anything this page leaves ambiguous.

> Some examples below carry `//` comments to explain a field. **JSON has no
> comments** — strip them before writing a file. The
> [complete example](#a-complete-minimal-graph) at the end has none and can be
> copied as-is.

---

## The envelope

```json
{
  "id":                 "3c1f0b54-9e7a-4d02-8b61-5a2f7c0d91ae",
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
| `id` | UUID. Must equal the filename stem |
| `name` | Shown in the graph selector |
| `projectId` | Project folder this graph belongs to. Empty is fine |
| `owner` | Owning user id. **Empty means unowned — readable and writable by anyone.** Set it if the server runs with accounts |
| `ragEmbeddingConfig` | Name of an entry in `aiConfigs` to use for automatic retrieval. Empty disables it |
| `memoryAiConfig` | Name of an entry in `aiConfigs` used to judge memory rules. Empty skips the model-judged parts |
| `version` | Incremented by the editor on every save; the server rejects an update carrying a version older than its own. **Start at 1** |
| `updatedAt` | Unix milliseconds. `0` is accepted |
| `groups` | Visual grouping. `[]` unless you are reproducing an editor layout |

All eight list fields must be present, even when empty.

---

## Nodes

```json
{
  "id":       "cdadab82-91ad-4828-b588-c38a5b91ae7c",
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
| `type` | yes | One of the eleven types below |
| `title` | yes | Free text, shown on the node |
| `category` | yes | Lowercase form of the type; used for colouring |
| `position` | yes | Editor coordinates. Any numbers work; lay graphs out left to right, ~250 px apart, or they overlap |
| `inputs` / `outputs` | yes | Pin arrays — see each type. Each pin needs `name`, `type`, `direction`; `id` is optional |
| `config` | yes | Per-type settings. `{}` if the type has none |
| `singleton` | no | `true` on `Start` and `End`. Editor-only hint |
| `groupId` | no | Only when the node is inside a group |

### Pin types

`exec` is control flow. Everything else is data: `string` is the common case,
and `asset` / `image` / `audio` / `tts` / `music` / `mesh` carry a reference to
a produced file rather than text.

**The distinction matters.** An `exec` connection transfers control — it queues
the downstream node to run. A data connection only copies a value into the
downstream input slot and does **not** cause it to run. A node with no incoming
`exec` connection never executes, however many data connections it has.

---

## Connections

```json
{
  "id":         "d2ac1f0e-7577-4be2-b255-d0f5e5df9795",
  "fromNodeId": "cdadab82-…",
  "fromPinId":  "Exec",
  "toNodeId":   "fa6d001b-…",
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
template as `{{pinName}}`. `ALL` is the full reply. Add `string` output pins
named after keys of the structured output to have them split out for you.

```json
"config": {
  "ai_config": "planner",          // name from aiConfigs — required
  "format_config": "",             // name from formatConfigs; enables structured output
  "role": "",                      // system prompt
  "prompt_template": "Plan: {{Task}}",
  "tools_enabled": true,
  "allowed_tools": "*",            // "*" or a comma-separated list
  "max_tool_iters": 5,
  "rag_mode": "inherit",           // inherit | off | custom
  "rag_embedding_config": "",      // with rag_mode="custom"
  "memory_context": true,
  "memory_history_top_k": 0,       // 0 = server default
  "memory_filter_config": "",
  "chunking": false,
  "chunk_desc": ""
}
```

Load and sampling parameters may be overridden per node with `ai_model`,
`ai_ctx_size`, `ai_quantization`, `ai_n_gpu_layers`, `ai_split_mode`,
`ai_kv_cache_type`, `ai_flash_attn`, `ai_auto_fit`, `ai_n_cpu_moe`,
`ai_lookahead`, `temperature`, `top_k`, `top_p`. Omit them to use the AI config.

> Pointing `ai_config` at a `modalityConfigs` name instead turns the node into a
> generation call — image, speech and so on. The reply is a file reference on the
> `Asset` pin, not text.

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
      "source_type": "constant",            // constant | variable
      "source_value": "0" }
  ]
}
```

`add` means numeric addition, string concatenation, or logical OR depending on
the variable's declared `type`.

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
"config": { "ai_config": "", "token_budget": 0, "history_top_k": 0 }
```

One `Memory` node can feed several `SendToAi` nodes, which is the point of it.

### `Dispatch` — split work and run it item by item
`in[Exec, Input]` → `out[Step, Task, Index, Plan, End]`

A splitter model turns the input into a list; `Step` fires once per item with
`Task` and `Index` set, then `End` fires once at the finish.

```json
"config": {
  "splitter_ai_config": "planner",
  "splitter_max_tokens": 4096,
  "parallel_enabled": false,
  "max_parallel": 4
}
```

**End each `Step` branch with `Return`, not `End`.**

### `AskUser` — ask the operator
`in[Exec, Input]` → `out[Exec, Answers, Asked]`

```json
"config": {
  "ai_config": "",         // judges whether asking is warranted
  "criteria": "",
  "max_questions": 3,
  "allow_free_text": true,
  "answer_timeout_s": 600
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

Returns the result to the user and ends the run. **Reachable from the main path
only** — never from a `Dispatch` branch.

---

## The four configuration lists

### `aiConfigs`

```json
{
  "name": "planner",
  "model": "Qwen3-Coder-Next",
  "isRemote": false,
  "quantization": "",
  "ctxSize": 0,          // 0 = the model's own maximum, clamped to VRAM
  "nBatch": 0,
  "threads": 0,
  "flashAttn": true,
  "nGpuLayers": -1,      // -1 = auto
  "kvCacheType": "f16",
  "splitMode": "layer",  // layer | graph | attn | none
  "nCpuMoe": 0,
  "autoFit": false,
  "lookahead": false,
  "temperature": 0.7,
  "topK": 40,
  "topP": 0.9
}
```

For a hosted endpoint set `"isRemote": true` with `remoteUrl`, `remoteApiKey`
and `remoteFamily` (`openai` | `anthropic` | `gemini`); the load parameters are
then ignored while the sampling ones still apply.

`autoFit: true` is the easy choice for multi-GPU: it decides split mode, device
order and expert offload from the machine's actual topology.

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
{ "name": "sd35", "type": "image",      // image | tts
  "isRemote": false,
  "modalityAlias": "sd35",              // <modality alias> in the server config
  "cudaVisibleDevices": "",
  "defaults": {} }
```

---

## Rules that decide whether a graph runs

1. **Exactly one `Start` per entry point**, one of them named `Default`.
2. **Every node needs an incoming `exec` connection**, directly or through the
   chain. Data connections alone never make a node run.
3. **`End` finishes the whole run.** Branches from `Dispatch` end with `Return`.
4. **Names are references.** Every `ai_config`, `format_config`, variable and
   modality name in a node's `config` must exist in the matching list. A
   misspelling fails at run time, not load time.
5. **Pin names in connections must exist** on both nodes, spelled exactly.
6. **A back edge re-runs its target** — the visited set is cleared, which is how
   loops work. Make sure something can end the loop.
7. **`id`s must be unique** and the file's stem must equal the graph `id`.

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
the editor, then dropped into the server's graph store, where the server listed
it, the editor opened it and it answered a question. That is the shortest proof
the page is complete.

```json
{
  "id": "11111111-2222-3333-4444-555555555555",
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
      "type": "SendToAi", "title": "Answer", "category": "sendtoai",
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
        "tools_enabled": true, "allowed_tools": "*", "max_tool_iters": 5,
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

Most of the rules above are mechanically checkable. This script catches the
mistakes that otherwise surface as a graph that loads fine and then quietly does
nothing:

```python
import json, sys

# Only pins that must exist. The editor adds more to a new node (SendToAi's
# Asset, Start's ASSET, If's Input); graphs that do not wire them omit them.
PINS = {
 'Start': ([], ['Exec','PROMPT']),          'SendToAi': (['Exec'], ['Exec','ALL']),
 'CheckFormat': (['Exec','Input'], ['True','False','Output']),
 'If': (['Exec'], ['Else']),                'Variable': (['Exec'], ['Exec']),
 'Compose': (['Exec'], ['Exec','Output']),  'Memory': (['Exec','Input'], ['Exec','Memory']),
 'Dispatch': (['Exec','Input'], ['Step','Task','Index','Plan','End']),
 'AskUser': (['Exec','Input'], ['Exec','Answers','Asked']),
 'Return': (['Exec'], []),                  'End': (['Exec','Result'], []),
}

g = json.load(open(sys.argv[1], encoding='utf-8'))
byid = {n['id']: n for n in g['nodes']}
errs, warns = [], []

if not any(n['type'] == 'Start' and n.get('config', {}).get('start_name') == 'Default'
           for n in g['nodes']):
    errs.append("no Start node named 'Default'")

names = {k: {c['name'] for c in g.get(k, [])}
         for k in ('aiConfigs', 'modalityConfigs', 'formatConfigs', 'variableConfigs')}
for n in g['nodes']:
    want_in, want_out = PINS[n['type']]
    have = lambda side: {p['name'] for p in n.get(side, [])}
    for w in want_in:
        if w not in have('inputs'):  errs.append(f"{n['type']} {n['id'][:8]}: no input {w}")
    for w in want_out:
        if w not in have('outputs'): errs.append(f"{n['type']} {n['id'][:8]}: no output {w}")
    c = n.get('config', {})
    a = c.get('ai_config') or c.get('splitter_ai_config')
    if a and a not in names['aiConfigs'] | names['modalityConfigs']:
        errs.append(f"{n['id'][:8]}: ai_config '{a}' undefined")
    if c.get('format_config') and c['format_config'] not in names['formatConfigs']:
        errs.append(f"{n['id'][:8]}: format_config '{c['format_config']}' undefined")

has_exec_in = set()
for e in g['connections']:
    for side, key in (('fromNodeId', 'fromPinId'), ('toNodeId', 'toPinId')):
        if e[side] not in byid:
            errs.append(f"connection to missing node {e[side][:8]}"); break
    else:
        # a pin reference may be the pin's name or its id
        pins = lambda nid, s: {k for p in byid[nid].get(s, []) for k in (p['name'], p.get('id')) if k}
        if e['fromPinId'] not in pins(e['fromNodeId'], 'outputs'):
            errs.append(f"{byid[e['fromNodeId']]['type']}: no output pin '{e['fromPinId']}'")
        if e['toPinId'] not in pins(e['toNodeId'], 'inputs'):
            errs.append(f"{byid[e['toNodeId']]['type']}: no input pin '{e['toPinId']}'")
        src = next((p for p in byid[e['fromNodeId']].get('outputs', [])
                    if e['fromPinId'] in (p['name'], p.get('id'))), None)
        if src and src.get('type') == 'exec':
            has_exec_in.add(e['toNodeId'])

for n in g['nodes']:
    if n['type'] != 'Start' and n['id'] not in has_exec_in:
        warns.append(f"{n['type']} {n['id'][:8]} has no incoming exec — it will never run")

print('\n'.join('ERROR: ' + e for e in errs) or 'no errors')
print('\n'.join('warn:  ' + w for w in warns))
```

Run against the four graphs that ship with the server, this reports nothing for
two of them and finds dangling references in the other two — connections whose
target node or pin no longer exists, left behind by editing. Those are silent at
run time: the value simply never arrives.

---

[← Logic Editor](logic-editor.md) · [Node types](nodes.md) · [AI Configs](ai-config.md) · [Client Guide](README.md)
