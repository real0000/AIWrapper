# Models & Downloads

Everything about getting a model onto a machine and into its config, which is
the agent's other job besides supervising the server.

---

## Adding a model

Three ways, all ending in the same place — a `<model>` entry in the local
`config.xml`:

| Route | When |
|---|---|
| Control-plane web UI | Normal case. Search Hugging Face, pick a quantization group, download, and the entry is written for you |
| `cage-model-dl` | Scripted or headless installs |
| `cage-model-dl --scan` | Models already on disk — registers them, licence included |
| Editing `config.xml` | Paths none of the above can reach |

```bash
./bin/cage-model-dl Qwen/Qwen3-Coder-Next --dir models --config config.xml
```

| Option | Meaning |
|---|---|
| `--dir` | Download root (default `./models`); files land in `<dir>/<repo-name>/` |
| `--rev` | Branch or revision (default `main`) |
| `--config` | The `config.xml` to update |
| `--alias` | Name the model will have in configs. Derived from the repo name if omitted |
| `--backend` | `llama` (GGUF) or `vllm` (safetensors); otherwise the configured default |
| `--list` | List the downloadable groups and exit |
| `-y` | Skip the confirmation, still asks which group |

## Models already on disk

Weights that arrived by some other route — rsync, a manual download, a tool
that predates this one — used to be invisible: the downloader only ever went
one way (repo id → API → download → write `config.xml`), so the only option was
typing the entry in by hand, licence and all.

`--scan` runs that path backwards, from the files:

```bash
./bin/cage-model-dl --scan /mnt/models --config config.xml
```

| Option | Meaning |
|---|---|
| `--scan DIR` | Walk this directory and register what it finds |
| `--dry-run` | Report what would be registered, change nothing |
| `--offline` | Never reach the network; use only what is on disk |

Format, quantizations and the vision projector come from the same scanner the
server runs at startup — not a second implementation that could disagree with
it.

**Licence** is resolved in order: the GGUF's `general.license` metadata, the
model card's YAML front matter, the `.git` remote, then the upstream Hugging
Face card. What it cannot establish is written as `commercial=""` rather than
guessed — the control plane lists unknown and non-free entries for review.

Two traps it handles, both found in real files:

- **A repacker's embedded model name is whatever they felt like.** One llava
  GGUF calls itself `Downloads`, and searching Hugging Face for that finds a
  real, unrelated repository whose licence would then be attached to your
  model. Name searches are validated against the directory on disk, never
  against metadata.
- **Models distilled from restricted weights advertise the wrong licence.**
  `DeepSeek-R1-Distill-Llama-70B` says `license: mit` while the weights remain
  under the Llama 3.3 community licence. Those are promoted to the licence that
  actually governs them — and where the base is only *possibly* a Llama
  (TinyLlama really is Apache-2.0), `commercial` is cleared with a reason
  rather than a side being picked.

It also refuses what does not belong in `<models>`, with the reason: embedding
models in safetensors, diffusers pipelines (those need a `<modalities>` entry),
and GGUFs with no `block_count` — image and 3D weights are `.gguf` too, and all
three would otherwise become aliases that appear in the list and fail on first
use.

The same scan is available in the control plane's Models tab, under "Import
models that are already on disk". Import re-scans on the server rather than
trusting the fields the browser sends back.

## Quantization groups

A Hugging Face repo usually holds several quantizations, sometimes split into
many files each. The downloader groups the file list so you pick a
quantization, not files — and multi-part shards
(`-00001-of-00005`) come down as one unit.

That grouping is why `--list` is worth running first on a large repo: it shows
what the repo actually offers and how big each option is.

## Several disks

`<download_dir>` may be repeated:

```xml
<node>
  <download_dir>models</download_dir>
  <download_dir>/mnt/ssd2/models</download_dir>
  <download_dir>/mnt/bigdisk/models</download_dir>
</node>
```

The agent picks a target by free space, so a 400 GB model does not fail halfway
through because it landed on the wrong disk. Each directory's free and total
space is visible in the web UI.

Adding a disk later needs no migration — existing models keep their paths,
which are absolute in `config.xml`.

## How config.xml is edited

Worth knowing, because it explains a constraint.

The agent does **surgical text editing**: it locates the byte range of the
`<model>` element and replaces or inserts text, keeping a `.bak` copy and
checking comment markers pair up afterwards.

It deliberately does *not* parse and re-serialise the file, because that would
discard every comment — and this file is mostly comments, which are the
documentation for the deployment.

The practical consequence: **your comments and formatting survive** the web UI
writing to the file. Handwritten notes next to a model entry stay where you put
them.

## After downloading

The new entry is `pendingRestart` until the server restarts. The download
itself does not touch the running server, so a large download can proceed while
the server keeps serving.

Restart when convenient; the model becomes `live`.

## Model paths

`<path>` is a **directory**, not a file:

- **GGUF** — every `.gguf` in it is one quantization. Adding another
  quantization means dropping the file in the same directory; no config change.
- **safetensors** — quantization happens at load time, so the whole range is
  available from one set of weights.

See [Models](../server/models.md) for what the server does with that directory.

---

[← Node Agent](README.md) · [Node API](api.md) · [Server Guide](../README.md)
