# Models

How the server turns `<models>` in `config.xml` into the list clients see, and
into something it can load.

---

## An entry

```xml
<model alias="my-coder">
  <path>/mnt/models/Qwen3-Coder-Next</path>
  <quant>MXFP4_MOE</quant>
  <license name="Apache-2.0" commercial="free"
           url="https://huggingface.co/Qwen/Qwen3-Coder-Next"/>
</model>
```

| Element | Meaning |
|---|---|
| `alias` | The name everywhere else — in AI configs, in the API, in logs |
| `backend` | Usually omitted — it is derived from the weights found on disk. `llama` (GGUF or safetensors, in-process) or `remote` (cloud API). A declared value that disagrees with the scan is warned about and overridden. See [Backends](backends.md) |
| `<path>` | A **directory**. See below |
| `<quant>` | Default quantization for this alias. Optional |
| `<mmproj>` | Vision projector, for vision models. Found automatically when it sits in the model directory |
| `<source_repo>` | The Hugging Face repo the files came from. Written by the downloader; used to fetch the model card |
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
they are quantized while they load. So every option is offered from the same
files: 4bit (Q4_K_M), 8bit (Q8_0), bf16, fp16, fp32. `4bit-fp4` is accepted from
older configurations and loads as 4bit.

A projector file is recognised as such and not offered as a quantization.

`<quant>` seeds the default. Omit it and the smallest is chosen — the one most
likely to load. Users override it per AI config, so this is a starting point,
not a restriction.

An old-style `<path>` pointing at a specific `.gguf` still works: the server
scans its parent directory and treats that file as the default.

## When a path is wrong

```
[warning] Model 'my-coder' scan failed: path does not exist: /mnt/models/… - this model cannot load (…)
[error]   Model skipped: my-coder — no weights recognised under /mnt/models/… (…)
```

The alias is not registered and does not appear in `/api/models`, so it cannot
be picked and fail later. Usually a disk that is not mounted; the log names the
path it looked at.

## Vision models

One extra element:

```xml
<model alias="my-vision">
  <path>/mnt/models/llava-llama-3-8b-v1_1</path>
  <mmproj>/mnt/models/llava-llama-3-8b-v1_1/mmproj-f16.gguf</mmproj>
</model>
```

`<mmproj>` is the CLIP projector — it is what makes the model able to see. When
the projector sits in the model directory it is found without being named. The
projector's own metadata says what kind it is, so there is nothing else to set;
an older `<vision handler="…">` is ignored.

A text-only model is never handed an image: it gets a short note of what was
attached and where, so a node with file tools can still open it.

## Model licences are yours to check

**CAGE ships no model weights.** `config.example.xml` contains placeholder
paths only, and nothing is downloaded until you ask for it. Every weight on the
machine got there because an operator chose it, so the licence for it is the
operator's to read and comply with — CAGE's own licence says nothing about the
models you point it at, in either direction.

This matters more than it sounds. Model licences are not software licences and
several of the most popular weights carry restrictions that would surprise
anyone assuming "open weights" means "do what you like":

| Restriction pattern | Seen on | What it means in practice |
|---|---|---|
| **Non-commercial** | MusicGen, several TTS and audio checkpoints | Cannot be used in a commercial product at all, regardless of how it is deployed |
| **Revenue threshold** | Stable Diffusion 3.5, Stable Audio Open (Stability AI Community License) | Free commercially below a stated annual revenue; above it, an enterprise licence is required |
| **User-count threshold** | Llama 3/4 Community Licence | Free commercially until a monthly-active-user count, then a separate grant from Meta |
| **Territorial exclusion** | Hunyuan3D-2 (Tencent Community Licence) | Excludes the European Union, the United Kingdom and South Korea — *including the outputs*, not only the model |
| **Output restrictions** | Various | Limits on training other models on the outputs, or on the use of the outputs themselves |
| **Required attribution** | Llama 3/4 Community Licence | A service built on the weights must display a set string — "Built with Llama" — on its UI, about page or product documentation. Costs nothing, but it binds the *operator running the service*, not the software, so it is easy to miss entirely |
| **Terms that can change under you** | DINOv3 (Meta) | The licensor may amend the agreement at any time, effective immediately, with continued use counting as acceptance. What you audited is not necessarily what binds you next quarter — pin the licence text you actually accepted alongside the weights |
| **No reverse engineering** | DINOv3 (Meta) | Bars discovering the underlying components of the weights. Worth reading before building tooling that inspects or extracts from them |

The territorial one is the least expected and the easiest to breach without
noticing: it is not enough to avoid distributing the model in those regions,
because the licence also withholds permission to use its outputs there.

Two things follow for anyone running this commercially:

1. **Check each model before it goes into a workflow**, not after. A graph that
   quietly routes one node to a non-commercial model taints whatever that
   pipeline produces.
2. **Record what you found** using the `<license>` element below. It is the only
   place that knowledge survives; the alternative is rediscovering it during
   diligence.

The same reasoning applies to the generative models, some of which
carry non-commercial or revenue-capped terms of their own — see
[Modalities](modalities.md).

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
