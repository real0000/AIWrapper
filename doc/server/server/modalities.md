# Modalities

Image, speech, audio, music and 3D generation. Each is a Python worker the
server spawns as a child process and drives over a pipe, registered in
`<modalities>` in `config.xml`.

None of this is needed for text-only use. Leave the block empty and nothing is
spawned.

---

## An entry

```xml
<modalities python_exe="python3" script_dir="python" cuda_visible_devices="">

  <modality alias="sd3.5-large">
    <type>image</type>
    <family>sd3</family>
    <model_path>/mnt/models/sd3.5_large-F16.gguf</model_path>
    <python_exe>/opt/venvs/sd/bin/python</python_exe>
    <device>cuda</device>
    <dtype>fp16</dtype>
    <timeout_sec>600</timeout_sec>
    <extra>
      <clip_l>/mnt/models/text_encoders/clip_l.safetensors</clip_l>
    </extra>
    <defaults>
      <steps>28</steps>
      <width>1024</width>
    </defaults>
  </modality>

</modalities>
```

| Field | Meaning |
|---|---|
| `alias` | The name a modality config in a graph references |
| `<type>` | `image`, `tts`, `audio`, `music`, `mesh` — decides the pin type in the editor |
| `<family>` | Which worker script handles it |
| `<model_path>` | A file, a directory, or a Hugging Face repo id, depending on the family |
| `<python_exe>` | Interpreter for this worker. Overrides the container attribute |
| `<device>` / `<dtype>` | Where and at what precision |
| `<timeout_sec>` | Per-request limit. Generation is slow; 3D especially |
| `<extra>` | Forwarded to the worker as `--extra key=value` |
| `<defaults>` | Per-request generation knobs, overridden by whatever the graph node sends |
| `auto_start` | Load at boot instead of on first use. Costs RAM and VRAM from startup |
| `<license>` | Same meaning as for [models](models.md#licence-metadata) |

## One environment per worker

Set these up with `setup-workers.sh` — see [Python workers](workers.md), which
covers what each family needs and how the three mesh families differ.

The `python_exe` attribute on `<modalities>` is the default; each entry usually
overrides it.

That is not incidental — these model families have genuinely conflicting
dependencies, and trying to serve them from one environment is how you end up
with a stack that works for one and breaks another. A venv per family is the
intended arrangement.

## GPU visibility

`cuda_visible_devices` on the container sets the default; per entry overrides
it. Accepts indices (`0,1,3`) or UUIDs (`GPU-xxxx`).

Use it to keep generation off the cards the LLMs are using. An image model that
takes 8 GB is not a problem until it takes 8 GB from a card that was holding
part of a large language model.

## Generation parameters

`<defaults>` are the same knobs the upstream project's own interface exposes —
steps, guidance scale, dimensions, sampler settings. They sit underneath
whatever a graph node passes, so a config can set sensible values once while
individual nodes vary what matters.

Values are forwarded as strings. Prefer numeric settings here; booleans are
read stringly by the workers and are unreliable.

## Using one

Graph-side, a [modality config](../../client/modality-config.md) names the
alias, and a Send To AI node selects that config. The node then generates a
file instead of text.

The server also exposes `POST /api/generate` for direct invocation, which is
what the Logic Editor's preview uses.

## When a worker will not start

The failure is nearly always the environment, not the config:

1. Check `<python_exe>` exists and is the venv you think it is.
2. Run the worker's imports in that interpreter by hand.
3. Check the server log — the child's stderr is captured there.

The pipe protocol reports a worker that dies during startup as a failed
request, so the message you see in the client is generic. The log has the real
error.

---

[← Inference Server](README.md) · [Server Guide](../README.md)
