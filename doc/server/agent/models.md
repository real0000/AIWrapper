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
| `aiw-model-dl` | Scripted or headless installs |
| Editing `config.xml` | Models already on disk, or paths the downloader cannot reach |

```bash
./bin/aiw-model-dl Qwen/Qwen3-Coder-Next --dir models --config config.xml
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
