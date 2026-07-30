# Inference Server

`aiwrapper-server` is the process that does the work: it loads models, executes
logic graphs, retrieves from the project index, dispatches tool calls to the
connected editor, and streams answers back.

It is spawned by the [node agent](../agent/README.md), not run as a service of
its own.

---

## Contents

| Page | Covers |
|---|---|
| [Models](models.md) | Model directories, how quantizations are discovered, vision models, licence metadata |
| [Backends](backends.md) | In-process llama.cpp vs Python workers, the RAM/VRAM budget and eviction |
| [Python workers](workers.md) | Setting up the worker environments — the part a fresh machine actually needs |
| [Modalities](modalities.md) | Image, speech, audio, music and 3D generation workers |
| [Retrieval](rag.md) | Chunking, embedding, the vector store |
| [API](api.md) | HTTP endpoints and WebSocket messages |

## Running it

Normally the agent starts it. To run it directly — useful when diagnosing a
startup problem, because the output goes to your terminal:

```bash
cd /opt/aiwrapper && ./bin/aiwrapper-server
```

It reads `config.xml` from the working directory. Point it elsewhere with an
environment variable:

```bash
CONFIG_FILE=/opt/aiwrapper/config.xml ./bin/aiwrapper-server
```

There are no other command-line arguments — everything is in the config file.

## Startup

The log tells you what it decided, in order:

```
Config loaded from: /opt/aiwrapper/config.xml
Hardware topology: GPU0=…, GPU1=…; 6 NVLink pair(s); RAM 995 GiB
AIWrapper Server starting on port 15963 (threads: 112)
TLS disabled — traffic (including bearer tokens) is plaintext.
Model registered: my-coder (backend=unsloth, format=gguf, quants=3, …)
MySQL pool: 127.0.0.1:3306/aiwrapper (pool=4)
[auth] auth DISABLED (dev-open) (users=0, masterKey=no)
[BackendBudget] RAM cap=815483 MB, VRAM cap=129018 MB, eviction=lru
LlamaWorkerPool ready (lazy)
UnslothWorkerPool ready (lazy)
RAG VectorStore persist dir: data/vectors
Listening on port 15963
```

Four of those lines are worth reading every time:

- **Hardware topology** — the GPUs it can see and which pairs are NVLink
  connected. Automatic placement is decided from this.
- **Model registered** — one per model, with the quantizations found. A model
  whose path does not exist logs a warning here and is registered but
  unloadable.
- **auth** — `dev-open` means no authentication. See
  [Accounts](../control/accounts.md).
- **ready (lazy)** — no model is loaded at startup. The first request that
  targets a model loads it.

## Working directory

Several paths are relative to the process working directory, not the config:

| Path | Holds |
|---|---|
| `data/logic_graphs/` | Saved logic graphs, one JSON per graph |
| `data/workflows/` | Workflow definitions |
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
