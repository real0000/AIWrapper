**English** · [繁體中文](modalities.zh-TW.md)

# Modalities

Image, speech, audio, music, 3D and motion generation. Each one is a `<model>`
entry like any other, and runs **inside the server process** on the same
[backend pack](backend-packs.md) the language models use.

There is no separate service, no child process and no Python.

None of this is needed for text-only use. Declare no such models and nothing
loads.

---

## An entry

```xml
<model alias="sd3.5-large">
  <path>/mnt/models/stable-diffusion-3.5-large</path>
  <defaults>
    <steps>28</steps>
    <cfg_scale>7.0</cfg_scale>
    <width>1024</width>
    <height>1024</height>
  </defaults>
  <license name="Stability AI Community License" commercial="restricted" url="…"/>
</model>
```

| Field | Meaning |
|---|---|
| `alias` | The name a modality config in a graph references |
| `<path>` | The weights — a file or a directory, as that family expects |
| `<dtype>` | Weight type. Read by the image adapter only |
| `<defaults>` | Generation knobs, overridden by whatever the graph node sends |
| `<extra>` | Extra loader settings for that family |
| `auto_start` | Load at boot instead of on first use. Costs VRAM from startup |
| `<license>` | Same meaning as for [models](models.md#licence-metadata) |

**You do not say what kind of model it is.** There is no `<type>` and no
`<family>` field — writing them does nothing. At startup the server asks each
model what it is: every adapter in the backend pack is handed the path and
answers whether those weights are its own and what it can drive them for. The
test lives in the code that understands the format, so there is no table here to
fall out of date.

**Language models answer first.** The language-model loader is asked before any
adapter: a GGUF whose architecture it knows, or a Hugging Face folder whose
`config.json` names one, becomes a chat model and goes no further. A folder with
a `config.json` and one `model.safetensors` is exactly what dozens of speech
models look like too; only the architecture tells them apart, and only the
language-model loader knows the architectures. The speech adapter, for its part,
accepts a folder only when every file its model spec names is there. Three kinds
of folder fall outside that: weights under another file name than the spec's; a
third-party GGUF the speech code reads directly (`nemotron_transcribe`, for one);
and an any-to-any GGUF whose architecture is a language model's (LFM2.5-Audio,
for one), which becomes a chat model.

For most entries `<path>` and `<license>` are the whole thing.

This is why the fields are gone rather than optional. A declared kind that is
wrong has nothing to contradict it, and one that is *right* is worse: an SD 3.5
entry carried `<family>sd</family>` for months, and it quietly covered for a
probe that had never once recognised that model. Everything looked fine until
the line was deleted. If you want one alias of a multi-task model pinned to a
particular task, that is a runtime preference and belongs in the modality config,
not here.

## They share one process, one context and one ledger

The adapters are compiled into the backend pack and share ggml with the language
models — the same CUDA context and the same VRAM accounting.

That is what makes the budget honest. An image model holding 8 GB is visible to
the loader that is deciding whether a language model fits, and can be evicted by
it, because there is one ledger rather than one per process. See
[Backends → The budget](backends.md#the-budget).

It also means a generative model is subject to the same lazy loading and
eviction as everything else: loaded on first use, unloaded when something else
needs the room.

## Which GPUs it may use

Chosen in the graph, on the [modality config](../../client/modality-config.md),
the same way an AI config picks cards: by GPU UUID. The model runs on exactly the
cards chosen — all of them, even when one would hold it. Leave it empty and it
uses every card the backend can drive, the same rule as an AI config. If none of
the chosen cards exists on this machine, the request fails rather than quietly
landing somewhere else.

With more than one card, the server splits the model by layer, as a pipeline.
Tensor parallelism moves activations between the cards on every matrix multiply,
and these models compute hundreds to thousands of positions at once, so for them
it usually costs more than it saves: SD 3.5 Large measured 10% slower split by
layer and 40% slower split by row than on one card. A model that one card could
hold is therefore a little slower on several — choosing them is yours to decide.

- If the chosen cards together cannot hold the model, the request fails at once
  and says to choose more.
- A model already loaded is reused only when the cards chosen this time are the
  same ones; otherwise it is unloaded and placed again.

Set it to keep generation off a card you want left alone — a display card, or one
holding part of a large language model.

There is no server-wide version of this. `<ai><cuda_visible_devices>` used to be
one, and it was removed: it could only decide for the whole machine, while "this
model must not touch that card" is per model by nature.

## Generation parameters

`<defaults>` are the knobs the upstream project's own interface exposes — steps,
guidance scale, dimensions, sampler settings. They sit underneath whatever a
graph node passes, so a config sets sensible values once and individual nodes
vary what matters.

## Using one

Graph-side, a [modality config](../../client/modality-config.md) names the alias,
and a Send To AI node selects that config. The node then produces a file instead
of text — or, for speech recognition and voice-activity detection, the text the
model returned.

`POST /api/generate` invokes one directly; that is what the Logic Editor's
preview uses.

## When one will not load

1. **Check the backend pack.** These adapters live in it. Without a pack, local
   inference of every kind is unavailable, not just text.
2. **Check VRAM.** It competes with the language models for the same cards, and
   the server log says what it tried to reserve and what refused.
3. **Check the probe.** The startup log records what each model was found to be;
   a model that probed as something unexpected explains an alias that does not
   appear where you expect it.

---

> **If you are coming from an older release.** Modality models used to be Python
> workers, spawned per family, declared in a separate `<modalities>` block with
> `python_exe`, `script_dir` and `timeout_sec`, and set up with a script that
> built one virtual environment per family. All of it is gone — the generation
> code is in the backend pack now.
>
> `<modalities>` is **not** silently migrated: a config.xml that still has the
> block makes the server **refuse to start**, with a message saying how to move
> the entries into `<models>`. Parsing it and ignoring it would have shown up as
> "the config is still there but the models vanished", which is far worse to
> diagnose than a refusal.
>
> Moving an entry is mostly deletion: `<modality>` → `<model>`, `<model_path>` →
> `<path>`, and drop `<python_exe>`, `<device>` and `<timeout_sec>`. Generation
> is no longer on a per-request timer.

---

[← Inference Server](README.md) · [Backends](backends.md) · [Models](models.md) · [Server Guide](../README.md)
