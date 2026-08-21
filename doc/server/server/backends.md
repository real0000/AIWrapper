# Backends

Every model runs through one adapter interface. Which implementation a model
uses is an attribute on its entry; everything above that line — logic graphs,
tools, retrieval — is identical either way.

---

The server binary carries **no GPU code at all**. In-process GGUF inference
needs a [backend pack](backend-packs.md) — a separate download matching your
hardware. Without one, `vllm` and `remote` still work and `llama` does not.

## The three

| | `llama` | `vllm` | `remote` |
|---|---|---|---|
| What | llama.cpp, in the server process | vLLM in a subprocess | Somebody else's endpoint |
| Formats | GGUF | safetensors (HF directory) | n/a |
| Multimodal | Yes, via `<mmproj>` | Model-dependent | Provider-dependent |
| GPU visibility | Fixed at server start | Per model | n/a |
| Needs | A [backend pack](backend-packs.md) for your GPU | A Python environment with `vllm` — **or** one with `torch`, and the model is converted to GGUF instead | Network + an API key |

```xml
<model alias="a" backend="llama">…</model>
<model alias="b" backend="vllm">…</model>
<model alias="c" backend="remote">…</model>
```

`<ai><default_backend>` sets the default for entries that do not say.

**Pick by format, not preference.** GGUF goes to `llama`, which runs inside the
server process and needs only a backend pack — no Python, no separate service. Unquantized Hugging Face weights
cannot be loaded by llama.cpp at all, so they go to `vllm`.

`backend="vllm"` names the *format*, not a hard dependency on vLLM. Both engines
for that format are optional and you install whichever suits the machine: vLLM
itself, or a `torch` environment, in which case the weights are converted to
GGUF in memory on first use and run on the `llama` backend. The server picks —
vLLM when its environment works, conversion otherwise. See
[Safetensors models](vllm.md).

Vision is on the `llama` side: a model with an `<mmproj>` projector loads it
alongside the weights, and requests carrying images are tokenized and evaluated
through it. No separate vision service.

> **Upgrading from an older release:** the `unsloth` backend is gone. Entries
> that said `backend="unsloth"` with a `.gguf` directory become `backend="llama"`;
> ones pointing at a safetensors directory become `backend="vllm"`. The
> `<ai><unsloth>` block and its Python worker environment are no longer read.

## Remote

`backend="remote"` targets a cloud chat API. Nothing loads locally and every
load-time parameter is ignored.

```xml
<model alias="c" backend="remote">
  <remote_family>anthropic</remote_family>   <!-- openai | anthropic | gemini -->
  <remote_url>https://api.anthropic.com</remote_url>
  <remote_model>claude-sonnet-4-5</remote_model>
  <remote_api_key></remote_api_key>          <!-- empty = supply it in the AI config -->
</model>
```

The three families differ in more than a URL — message shape, tool-call
encoding and streaming events are all different — but that is handled inside
the server. Leave `<remote_api_key>` empty and set the key in the AI config
instead if you would rather not have it in a file under version control.

An AI config can also point at an endpoint directly without any `config.xml`
entry, which is the usual way to reach a locally-hosted OpenAI-compatible
server.

## Lazy loading

No model is loaded at startup, whichever backend it uses. Loading starts on the
first request that targets that model.

The first request against a large model therefore takes as long as loading
takes — minutes for a very large one. `remote` models have no load step at all.

Once loaded, a model stays resident until it is evicted.

## The budget

One ledger across the local backends caps how much can be resident at once.
`remote` models are not in it — they consume nothing here.

```xml
<budget>
  <ram_mb>0</ram_mb>          <!-- 0 = detect -->
  <vram_mb>0</vram_mb>        <!-- 0 = sum of every detected card -->
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

Detection is not NVIDIA-only: `nvidia-smi`, AMD's KFD interface, Apple's
`sysctl` and a Vulkan fallback are tried in turn, and `CAGE_GPU_PROBE` forces
one. Multimodal workers are on this same ledger.

## Asking where a model would go, without loading it

`cage-llama-fit` runs the same placement logic the server uses and prints what
it decided, as one line of JSON. Nothing is loaded, so it answers in seconds
instead of minutes.

```bash
bin/cage-llama-fit --model /models/Qwen3-Coder-Next --ctx 32768
```

| Option | |
|---|---|
| `--model PATH` | Model directory or file. Required |
| `--ctx N` | Context size. **Required, and must be > 0** |
| `--batch N` | Prompt batch size |
| `--kv f16\|q8_0\|q4_0` | KV cache type |
| `--flash on\|off` | Flash attention |
| `--rpc host:port[,…]` | Include remote nodes in the placement |

It reports the island split, the device order, `split_mode`, `max_gpu` and
whether expert offload is needed. `CUDA_VISIBLE_DEVICES` is inherited, so
restricting it to the cards an AI config selects answers the question for that
config specifically.

It needs a [backend pack](backend-packs.md) beside it, for the same reason the
server does — the placement logic asks the backend what the cards are.

**Use it before a long load.** Asking a 400 GB model to load and watching it
fail after eight minutes tells you the same thing this tells you immediately.

## Worker parameter conflicts

Two AI configs naming the same model with different **load-time** parameters
cannot share a worker: context size, quantization, GPU layers and the rest are
fixed when the model loads.

Both configs still work — but switching between them forces a worker restart
and a model reload, which for a large model means minutes. The Logic Editor
console warns when it sees that combination.

If you need two context sizes for one model, expect to pay for the switch, or
give one of them a different model.

---

[← Inference Server](README.md) · [Backend Packs](backend-packs.md) · [Models](models.md) · [vLLM](vllm.md) · [Server Guide](../README.md)
