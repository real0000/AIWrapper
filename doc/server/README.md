# Server Guide

The server side is three processes, not one. Understanding which does what
saves a lot of confusion later — particularly the part where editing a model
list changes nothing until something restarts.

Installation is covered separately in
[server-install.md](../server-install.md).

---

## The three pieces

```
[browser] ──HTTP──> aiw-launcher --control          one per deployment
                      │  accounts · web UI · the list of machines
                      │
                      └──HTTP /node/*──> aiw-launcher --agent      one per machine
                                           │  supervises the server on this box
                                           │  edits this box's config.xml
                                           │  downloads models to this box's disks
                                           │
                                           └──spawns──> aiwrapper-server
                                                          the actual inference
```

| Process | Binary | One per | Job |
|---|---|---|---|
| [Node agent](agent/README.md) | `aiw-launcher --agent` | machine | Starts, stops and restarts the local server; edits its config; downloads models |
| [Inference server](server/README.md) | `aiwrapper-server` | machine | Runs the models, executes logic graphs, serves the clients |
| [Control plane](control/README.md) | `aiw-launcher --control` | deployment | Web UI, accounts, and the list of machines it drives |

The server is **not** a service of its own. The agent spawns it, which is why
stopping the server leaves the agent running and able to bring it back.

Control talks to agents over plain HTTP, so it does not have to share a machine
with any of them. A single-machine install just has all three on one box with
the agent at `127.0.0.1`.

---

## Where to go

### [Node agent →](agent/README.md)

The resident supervisor on each machine.

| Page | Contents |
|---|---|
| [Overview](agent/README.md) | What it supervises, autostart, restart-to-apply, why config edits are not live |
| [Models & downloads](agent/models.md) | Adding models, Hugging Face downloads, spreading them over disks, how config.xml is edited |
| [Node API](agent/api.md) | The `/node/*` endpoints and the token that guards them |

### [Inference server →](server/README.md)

The process that actually loads models and answers clients.

| Page | Contents |
|---|---|
| [Overview](server/README.md) | Ports, startup sequence, working directory, logs |
| [Models](server/models.md) | Model directories, quantization discovery, vision models, licence metadata |
| [Backends](server/backends.md) | In-process llama.cpp vs Python workers, the RAM/VRAM budget, eviction |
| [Modalities](server/modalities.md) | Image, speech, audio, music and 3D workers |
| [Retrieval](server/rag.md) | Chunking, embedding, the vector store |
| [API](server/api.md) | HTTP endpoints and WebSocket messages |

### [Control plane →](control/README.md)

The web UI and the only piece that knows about more than one machine.

| Page | Contents |
|---|---|
| [Overview](control/README.md) | The web UI, what it can drive, what it needs |
| [Accounts](control/accounts.md) | Admin accounts, user accounts, tokens, the bootstrap account |
| [Multiple nodes](control/nodes.md) | Adding machines, tokens, what is shared and what is not |

---

## The one thing that trips everyone up

**Editing the model list does not affect the running server.** The agent writes
`config.xml`; the server is still running with what it read at startup. The
model list shows each entry as either `live` (loaded) or `pendingRestart` (in
the file, not in the server). Restarting the server from the web UI is what
applies it.

This is deliberate: restarting one process is more predictable than trying to
mutate a loaded model set in place.

---

Proprietary — Copyright (c) 2026 real0000. All Rights Reserved. See [LICENSE](../../LICENSE).
