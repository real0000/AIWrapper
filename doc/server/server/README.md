**English** · [繁體中文](README.zh-TW.md)

# Inference Server

`cage-server` is the process that does the work: it loads models, executes
logic graphs, retrieves from the project index, dispatches tool calls to the
connected editor, and streams answers back.

It is spawned by the [node agent](../agent/README.md), not run as a service of
its own.

---

## Contents

| Page | Covers |
|---|---|
| [Models](models.md) | Model directories, how quantizations are discovered, vision models, licence metadata |
| [Backends](backends.md) | The two backends, the RAM/VRAM budget, eviction, and what forces a model reload |
| [Backend Packs](backend-packs.md) | **The separate GPU download** — choosing one, installing it, verifying it, running several |
| [Safetensors models](safetensors.md) | Running Hugging Face weights: no conversion, and why every quantization is available |
| [Modalities](modalities.md) | Image, speech, audio, music, motion and 3D generation, in-process |
| [Retrieval](rag.md) | Chunking, embedding, the vector store |
| [API](api.md) | HTTP endpoints and WebSocket messages |

## Running it

Normally the agent starts it. To run it directly — useful when diagnosing a
startup problem, because the output goes to your terminal:

```bash
cd /opt/cage && ./bin/cage-server
```

It reads `config.xml` from the working directory. Point it elsewhere with an
environment variable:

```bash
CONFIG_FILE=/opt/cage/config.xml ./bin/cage-server
```

There are no other command-line arguments — everything is in the config file.

## Startup

The log tells you what it decided, in order:

```
Config loaded from: /opt/cage/config.xml
Hardware topology [nvidia]: GPU0=…, GPU1=…; 1 nvlink link(s); RAM … GiB
CAGE Server starting on port 15963 (threads: …)
TLS disabled — traffic (including bearer tokens) is plaintext. …
[CageBackendLib] loaded /opt/cage/bin/libcage-backend-cuda-sm89_sm90.so: backend=cuda, …
[LlamaApi] selected /opt/cage/bin/libcage-backend-cuda-sm89_sm90.so (backend=cuda, drives 2/2 devices, …)
Model registered: my-coder (backend=llama, format=gguf, quants=3, …)
MySQL pool: 127.0.0.1:3306/cage (pool=4)
[auth] auth ENABLED (users=…, masterKey=no)
[BackendBudget] RAM cap=… MB, VRAM cap=… MB, eviction=lru
LlamaWorkerPool ready (lazy)
RAG VectorStore persist dir: data/vectors
Listening on port 15963
```

The lines worth reading every time:

- **Hardware topology** — the GPUs it can see and which pairs are NVLink
  connected. Automatic placement is decided from this.
- **[LlamaApi] selected** — which [backend pack](backend-packs.md) drives which
  cards. `No backend library found` here means no local model can run.
- **Model registered** — one per model, with the quantizations found. A model
  whose directory is missing, or holds no weights the server recognises, is
  logged as `Model skipped` with the reason and does not appear in the model
  list.
- **auth** — `dev-open` means no authentication: every request is served as
  admin, to anyone who can reach the port. See
  [Accounts](../control/accounts.md).
- **Waiting for the database** — the config has a `<mysql>` block and that
  database is not answering yet. Nothing is served until it does; remove the
  block to run without a database.
- **ready (lazy)** — no model is loaded at startup. The first request that
  targets a model loads it.

## Working directory

Several paths are relative to the process working directory, not the config:

| Path | Holds |
|---|---|
| `data/logic_graphs/` | Saved logic graphs, one JSON per graph |
| `data/vectors/` | Per-project vector indexes |

This is why `<working_dir>` matters: point the agent at the build directory and
the server will create a fresh, empty `data/` there and appear to have lost
every graph.

## Ports

| Port | Set in | Purpose |
|---|---|---|
| 15963 | `<port>` | Clients: HTTP API and WebSocket, same port |
| 15972 | `<node><agent_port>` | The agent's API — a different process |

## Threads

The thread count in the startup line comes from the machine's core count. It
sizes the IO thread pool, not inference; per-model inference threads are set
per AI config.

---

[← Server Guide](../README.md)
