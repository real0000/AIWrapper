# Backends

Every model runs through one adapter interface with two implementations behind
it. Which one a model uses is an attribute on its entry; everything above that
line — logic graphs, tools, retrieval — is identical either way.

---

## The two

| | `llama` | `unsloth` |
|---|---|---|
| What | llama.cpp, in the server process | A Python worker process |
| Formats | GGUF | GGUF and safetensors |
| Started | With the server | Lazily, on first use |
| GPU visibility | Fixed at server start | Per model |
| Needs | Nothing extra | A Python environment with `llama-cpp-python` |

```xml
<model alias="a" backend="llama">…</model>
<model alias="b" backend="unsloth">…</model>
```

`<ai><default_backend>` sets the default for entries that do not say.

**Use `unsloth` unless you have a reason not to.** It handles both formats, and
GPU visibility can be set per model — the in-process backend fixes its device
list when the server starts, so a model cannot be pinned to particular cards
there. The cost is a subprocess and a Python environment.

`<ai><unsloth><python_exe>` must point at an interpreter that has
`llama-cpp-python` installed. Getting that wrong is the most common reason a
model never loads.

## Lazy loading

No model is loaded at startup, whichever backend it uses. A worker starts on
the first request that targets its model.

The first request against a large model therefore takes as long as loading
takes — minutes for a very large one. The worker heartbeats while loading, so
the timeout does not fire; `ready_timeout_sec` is an **idle** timeout that only
triggers after that many seconds of complete silence, meaning a hung worker.

Once loaded, a worker stays resident until it is evicted.

## The budget

One ledger across both backends caps how much can be resident at once.

```xml
<budget>
  <ram_mb>0</ram_mb>          <!-- 0 = detect -->
  <vram_mb>0</vram_mb>        <!-- 0 = sum of what nvidia-smi reports -->
  <ram_ratio>0.8</ram_ratio>
  <vram_ratio>0.9</vram_ratio>
  <eviction>lru</eviction>    <!-- lru | reject -->
</budget>
```

When a new model needs to load, the budget checks whether it fits alongside
what is already resident. If not:

- `lru` — evict the least recently used unpinned worker, repeat until it fits.
  If everything has been evicted and it still does not fit, the request fails.
- `reject` — never evict; the request fails immediately.

`<pinned>true</pinned>` on a model keeps it out of the eviction set. Worth it
for a small model that many graph nodes use — a fast utility model being
evicted to make room for a large one, then reloaded, then evicted again, is
pure overhead.

Sizes are estimated from file size with a margin when a model has no explicit
`est_ram_mb` / `est_vram_mb`, then corrected with the real figure once loaded.

Set `vram_mb` explicitly when some GPUs are reserved for other work — automatic
detection sums every card it can see, including ones you did not intend to use.

## Worker parameter conflicts

Two AI configs naming the same model with different **load-time** parameters
cannot share a worker: context size, quantization, GPU layers and the rest are
fixed when the model loads.

Both configs still work — but switching between them forces a worker restart
and a model reload, which for a large model means minutes. The Logic Editor
console warns when it sees that combination.

If you need two context sizes for one model, expect to pay for the switch, or
give one of them a different model.

## Remote models

An AI config can point at an OpenAI-compatible endpoint instead. The server
loads nothing locally, ignores every load-time parameter, and forwards to
`/v1/chat/completions`. Nothing in `config.xml` is involved — remote endpoints
are configured per AI config, in the graph.

---

[← Inference Server](README.md) · [Models](models.md) · [Server Guide](../README.md)
