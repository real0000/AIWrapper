**English** · [繁體中文](backends.zh-TW.md)

# Backends

Every model runs through one adapter interface. Which implementation a model
uses follows from the weights on disk; everything above that line — logic graphs,
tools, retrieval — is identical either way.

---

The server binary carries **no GPU code at all**. Running anything locally needs
a [backend pack](backend-packs.md) — a separate download matching your hardware.
Without one the server still starts, and `remote` models still work.

## The two

| | `llama` | `remote` |
|---|---|---|
| What | ik_llama.cpp, inside the server process | Somebody else's endpoint |
| Formats | GGUF **and** Hugging Face safetensors directories | n/a |
| Multimodal | Yes — text, vision and the generative types all run here | Provider-dependent |
| Needs | A [backend pack](backend-packs.md) for your GPU | Network + an API key |

```xml
<model alias="a"><path>/models/…</path></model>          <!-- local weights -->
<model alias="c"><remote_url>https://…</remote_url></model>   <!-- somebody else -->
```

**There is nothing to choose.** A `<path>` to weights is local; a `<remote_url>`
is remote. Which of the two adapters runs follows from that, and from what the
scan finds in the directory.

Safetensors are **read directly** by the in-process backend; there is no
conversion step and no second engine. Because the weights arrive unquantized,
every quantization is available at load time — see
[Safetensors models](safetensors.md).

Vision and the generative types are on the same side: a model with an `<mmproj>`
projector loads it alongside the weights, and image / audio / music / 3D models
run through in-process adapters that share this backend's ggml, CUDA context and
VRAM accounting. No separate service, no Python. See
[Modalities](modalities.md).

> **Upgrading from an older release.** The `vllm` and `unsloth` backends are both
> gone, along with the GGUF conversion fallback and every Python worker
> environment. Entries that still carry a `backend` attribute keep working: it is
> ignored, and where it disagrees with what the weights say the server logs that
> at startup and tells you to delete it. The
> `<ai><vllm>`, `<ai><convert>` and `<ai><unsloth>` blocks are no longer read.
> A `<modalities>` block is the one exception: the server **refuses to start** and
> tells you how to move those entries into `<models>`, because parsing it and
> ignoring it would show up as "the config is still there but the models are
> gone".

## Remote

A `<remote_url>` targets a cloud chat API. Nothing loads locally and every
load-time parameter is ignored.

```xml
<model alias="c">
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

A language model is planned as if its cards were idle: memory held by models
that can be evicted, idle or in use, counts as free, and only pinned models,
embedding models and what is used outside CAGE count against it. So where a
model's layers go never depends on what happens to be on the cards at the
moment. See [AI configs → GPU placement](../../client/ai-config.md#gpu-placement).

When a new model needs to load, the budget checks whether it fits alongside
what is already resident, card by card. If not:

- `lru` — evict idle, unpinned models from the cards it needs, least recently
  used first, and **wait** for models in use on those cards to finish —
  including any that started loading earlier. Nothing is evicted for a request
  that would still have to wait: it holds nothing while it waits and evicts at
  the moment it fits, so an idle model is never dropped for room that cannot be
  used yet. A model that can run partly on the CPU moves part of itself there
  only when the cards hold nothing more that could be evicted. It fails only
  when host RAM is short and nothing is in use that could free any — waiting
  would never help.
- `reject` — never evict and never wait. Whatever can move to the CPU does; if
  it still does not fit, the request fails at once.

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
one. Modality models are on this same ledger.

The fast links found there — NVLink, AMD's XGMI — also decide which cards may
read each other's memory directly. Only those pairs do; any other pair copies
through host memory, which is slower but correct. CUDA also offers direct
access between cards joined only by PCIe through the CPU, and on the machine
this was found on such copies arrived as zeros with no error reported, so a
model split across two NVLink groups answered with nothing but token 0.

### When a card runs out during a computation

An estimate can be low, and a program outside CAGE can take memory after a
model was placed. When a computation then runs out of VRAM, the request does
not fail. It gives back what it holds and **queues** with every other
placement:

- Its context (KV cache and compute buffers) is released, and the request is
  placed again by the same rules as a new one. Idle models on the card are
  evicted, and models in use are waited for. A queued request holds nothing,
  so two requests queued for the same card never wait for each other.
- When nothing on the card can make room, because what is left is pinned or is
  used outside CAGE, the model is placed again with a few layers on the CPU.
  The request continues more slowly instead of waiting for that program to
  leave.
- A model placed partly off its cards for lack of room is checked again each
  time it goes idle: its cards are measured once, and if the room is back, it
  is loaded onto them again while nobody is using it. A model that is simply
  larger than its cards is not checked.
- Once placed, it computes the prompt and the tokens it already produced again,
  then continues. Nothing already produced is lost or sent twice.

How much more the context needed than was measured is remembered, so later
placements of the same configuration leave that room. A generative model is
unloaded and queues the same way. It has no CPU to fall back to, so when
nothing in CAGE can make room it reports the error. Embedding models release
their context and queue the same way.

There is no time limit: a queued request waits until it is placed or
cancelled. Waiting does not query the driver.

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
| `--quant 4bit\|8bit\|bf16\|fp16\|fp32` | The quantization, when the model is a safetensors directory |
| `--ctx N` | Context size. **Required, and must be > 0** |
| `--batch N` | Prompt batch size |
| `--kv f16\|q8_0\|q4_0` | KV cache type |
| `--flash on\|off` | Flash attention |
| `--rpc host:port[,…]` | Include remote nodes in the placement |
| `--gpus GPU-…[,…]` | Only these cards, by UUID — what an AI config's GPU Visibility holds |

It reports the island split, the device order, `split_mode`, `max_gpu` and
whether expert offload is needed. Pass the UUIDs an AI config selects with
`--gpus` to answer the question for that config specifically.

It needs a [backend pack](backend-packs.md) beside it, for the same reason the
server does — the placement logic asks the backend what the cards are.

**Use it before a long load.** Asking a 400 GB model to load and watching it
fail after eight minutes tells you the same thing this tells you immediately.

## Two AI configs, one model, different parameters

It depends which parameters differ.

**Context size and batch size** cost nothing. A request whose context parameters
do not match the loaded slot's gets a context of its own for that request, built
and freed around it. The model stays put.

**Quantization, which GPUs, split mode, GPU layers, lookahead, MTP** are fixed at
load time. A request that wants different ones waits for the model to go idle,
unloads it, and loads it again its way. For a large model that is minutes.

A turn already running finishes on the settings it started with — the switch
happens between turns, not under one.

> This used to behave differently and worse: the mismatch was logged as *ignored
> (release + reload to apply)* and the already-loaded model was used anyway. Since
> `release` had no button anywhere, editing an AI config — new quantization, other
> cards, MTP on — meant restarting the server before it took effect, and until you
> did, runs silently used the old settings. **Editing a graph is now enough.**

If you need two quantizations of one model at once, give them separate aliases
pointing at the same directory. They load as separate slots and both stay
resident, at the cost of the VRAM for both.

---

[← Inference Server](README.md) · [Backend Packs](backend-packs.md) · [Models](models.md) · [Safetensors models](safetensors.md) · [Server Guide](../README.md)
