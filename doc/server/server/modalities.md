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
  <type>image</type>
  <family>sd</family>
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
| `<type>` | `image`, `tts`, `audio`, `music`, `mesh`, `motion`. Decides the pin type in the editor |
| `<family>` | Which adapter handles it |
| `<dtype>` | Weight type. Read by the image adapter only |
| `<defaults>` | Generation knobs, overridden by whatever the graph node sends |
| `<extra>` | Extra loader settings for that family |
| `auto_start` | Load at boot instead of on first use. Costs VRAM from startup |
| `<license>` | Same meaning as for [models](models.md#licence-metadata) |

**`<type>` and `<family>` are hints.** What a model can actually do is probed at
startup; a declared value is used only when the probe cannot tell, and is
respected when it falls inside what the probe found. That last part is the point
of still writing it: a model that can do both TTS and ASR takes `<type>tts</type>`
as "this alias is for TTS", which is a preference, not a correction.

Many entries need neither. `<path>` and `<license>` are often the whole thing.

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

## GPU visibility

`<ai><cuda_visible_devices>` sets the server-wide default; an entry can override
it. Indices (`0,1,3`) or UUIDs (`GPU-xxxx`).

Use it to keep generation off a card you want left alone — a display card, or
one holding part of a large language model.

## Generation parameters

`<defaults>` are the knobs the upstream project's own interface exposes — steps,
guidance scale, dimensions, sampler settings. They sit underneath whatever a
graph node passes, so a config sets sensible values once and individual nodes
vary what matters.

## Using one

Graph-side, a [modality config](../../client/modality-config.md) names the alias,
and a Send To AI node selects that config. The node then produces a file instead
of text.

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
