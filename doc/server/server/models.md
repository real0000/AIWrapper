# Models

How the server turns `<models>` in `config.xml` into the list clients see, and
into something it can load.

---

## An entry

```xml
<model alias="my-coder" backend="unsloth">
  <path>/mnt/models/Qwen3-Coder-Next</path>
  <quant>MXFP4_MOE</quant>
  <license name="Apache-2.0" commercial="free"
           url="https://huggingface.co/Qwen/Qwen3-Coder-Next"/>
</model>
```

| Element | Meaning |
|---|---|
| `alias` | The name everywhere else — in AI configs, in the API, in logs |
| `backend` | `llama` (in-process) or `unsloth` (Python worker). See [Backends](backends.md) |
| `<path>` | A **directory**. See below |
| `<quant>` | Default quantization for this alias. Optional |
| `<mmproj>` | Vision projector, for vision models |
| `<vision handler="…">` | Which chat handler a vision model needs |
| `<license>` | Upstream licence, surfaced to users. Optional but recommended |
| `<pinned>` | Keep this model out of the eviction set |
| `<est_ram_mb>` / `<est_vram_mb>` | Override the size estimate |
| `<n_parallel>` | Concurrent inference slots. `llama` backend only |

## `<path>` is a directory

This is the design decision most worth understanding.

The server scans the directory at startup and works out what is loadable:

**GGUF** — every `*.gguf` file is one quantization. Multi-part shards
(`-00001-of-00005`) collapse into a single entry. Users can only pick a
quantization that is actually present; to offer another, download that file
into the same directory — no config change, just a server restart.

**safetensors** — the directory holds one set of unquantized tensors, and
quantization happens at load time. So every option is offered from the same
files: 4bit (NF4), 4bit-fp4, 8bit, bf16, fp16, fp32.

A projector file is recognised as such and not offered as a quantization.

`<quant>` seeds the default. Omit it and the smallest is chosen — the one most
likely to load. Users override it per AI config, so this is a starting point,
not a restriction.

An old-style `<path>` pointing at a specific `.gguf` still works: the server
scans its parent directory and treats that file as the default.

## When a path is wrong

```
[warning] Model 'my-coder' scan failed: path does not exist: /mnt/models/…
[info]    Model registered: my-coder (…, quants=0, default=, …)
```

The alias is still registered and still appears in `/api/models` — it simply
cannot load. `quants=0` in the registration line is the tell. Usually a disk
that is not mounted.

## Vision models

Two extra elements:

```xml
<model alias="my-vision" backend="unsloth">
  <path>/mnt/models/llava-llama-3-8b-v1_1</path>
  <mmproj>/mnt/models/llava-llama-3-8b-v1_1/mmproj-f16.gguf</mmproj>
  <vision handler="llava"/>
</model>
```

`<mmproj>` is the CLIP projector — it is what makes the model able to see.
`handler` selects the chat handler: `qwen2.5-vl`, `qwen2-vl`, `minicpmv`,
`llava-1.6`, `llava`, `moondream`, `nanollava`, `llama3-vision`.

Name one in `<ai><default_vision_model>` and it becomes the delegate: when a
text-only model is working and an image is produced, the vision model describes
it and the description is fed back into the conversation.

## Licence metadata

```xml
<license name="Llama 4 Community License" commercial="restricted"
         url="https://huggingface.co/…">Commercial use permitted, but over
700M monthly active users requires a separate grant from Meta.</license>
```

| Attribute | Values |
|---|---|
| `commercial` | `free` — permissive · `restricted` — allowed with conditions · `noncommercial` — not allowed without a separate licence |
| `name` | Display name |
| `url` | The model card |
| element text | The restriction, in your own words |

The Logic Editor console lists every model whose `commercial` is not `free`,
with your note. It is advisory — nothing is blocked — but it puts the
constraint in front of whoever is choosing a model for a workflow, which is
where the decision actually gets made.

## What clients see

`GET /api/models` returns both the LLMs and the modality entries, each with its
kind, context size, backend, available quantizations and licence. The Logic
Editor builds its dropdowns from exactly this.

---

[← Inference Server](README.md) · [Backends](backends.md) · [Server Guide](../README.md)
