**English** · [繁體中文](models.zh-TW.md)

# Models & Downloads

Everything about getting a model onto a machine and into its config, which is
the agent's other job besides supervising the server.

---

## Adding a model

Four ways, all ending in the same place — a `<model>` entry in the local
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
| `--list` | List the downloadable groups and exit |
| `-y` | Skip the confirmation, still asks which group |
| `--fetch-cards` | Fetch the model card for every configured model that has none — see below |

## Model cards

How far a model's context can be extended is stated only in its model card, and
the server reads local files only. A download therefore brings the card
(`README.md`) along with the weights. Models downloaded before that have none:
`cage-model-dl --fetch-cards --config config.xml` fetches each one from the
entry's `<source_repo>`. An entry with no recorded source repo is listed rather
than guessed at — a card from the wrong repo would give the model another
model's limit — so confirm its source in the control plane first.

The card is also where the licence comes from. A custom licence — `license:
other` with a `license_name` and a `license_link` — is recorded under its own
name and link, and classified when it is a known one: the Qwen Research License
as non-commercial, the Qwen License as commercial with conditions. The entry
records `<source_repo>` as well, which is what `--fetch-cards` reads.

## Parts a model needs from other repositories

Some models are published without everything they run with.

- **Parts a model names.** TRELLIS.2, for one, points at a DINOv3 feature
  extractor, a background remover and a decoder from TRELLIS v1. The downloader
  fetches those along with the model, into `<model folder>/components/<name>/`,
  where the loader finds them.
- **Image models published as only the diffusion model.** Quantized GGUF repos
  of image models often hold just the denoiser — Qwen-Image 2.1 Turbo's does.
  When a repo has no `model_index.json` and its card's `base_model` is a
  diffusers pipeline, the downloader also fetches that pipeline's
  `model_index.json` and every part it lists except the denoiser — text encoder,
  VAE, scheduler — into `<model folder>/components/<base model name>/`. A base
  model that is not a pipeline, such as the original of a quantized language
  model, brings nothing.

When those parts are missing — the model was copied over by hand, say — the
startup log says what is missing and that `cage-model-dl` fetches it, and
loading the model stops with the same message before any weights are read.

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

The scan itself refuses only one thing: a directory with no weights it
recognises — no `.gguf` and no `.safetensors` file anywhere inside it. Weights in
subfolders count (TRELLIS.2 keeps them in `ckpts/`), and so do safetensors not
named `model*` (`sd3.5_large.safetensors`); a quantization choice is offered only
where the chat-model loader reads the folder directly. It does not try to judge
whether something is a language model, because that is not a question you can
answer from a directory listing. `.pt`, `.bin` and `.ckpt` do not count as
weights at all: those are Python pickles, and nothing in the server reads them.

A folder with a model card (a README with YAML front matter) or a `config.json`,
`model_index.json` or `pipeline.json` at its top is one model. Its subfolders are
its parts, not models of their own.

Deciding what a set of weights actually *is* happens when the server starts, and
it refuses two more things there, each with the reason in the log:

- **Weights whose architecture this backend has no graph for.** Image, audio and
  3D models ship as `.gguf` too, and declare their own architecture name — a
  Hunyuan3D file says `pig`. Those used to register as chat models and fail only
  when someone selected them.
- **Component weights.** A feature extractor or a background remover that
  belongs to some larger pipeline is not a model you can point a config at.

Both would otherwise become aliases that appear in the list and fail on first
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
