# AIWrapper

**A self-hosted AI coding assistant: a C++20 inference server plus a VSCode client.
Models, sessions, project index and generated artifacts all stay on your own hardware.**

> **Proprietary software.** Copyright (c) 2026 real0000. All Rights Reserved.
> The binaries published here are licensed for **evaluation and testing only** —
> see [LICENSE](LICENSE). This repository distributes compiled packages and
> documentation; it does not contain the source code.

## Commercial Availability

This software is proprietary. Evaluation binaries are available for testing.
Acquisition of the complete source code, intellectual property, and commercial rights is available upon request.

---

## Downloads

| Package | Platform | Contents | Where |
|---|---|---|---|
| `aiwrapper-server-0.1.0-linux-x64.tar.gz` | Linux x86-64 | Inference server, node agent, control plane, model downloader, Python workers | [Releases](../../releases) (113 MB) |
| [`aiwrapper-0.1.0.vsix`](dist/aiwrapper-0.1.0.vsix) | VSCode ≥ 1.85 | The editor client | `dist/` in this repository |

Installation: **[doc/server-install.md](doc/server-install.md)** →
**[doc/extension-install.md](doc/extension-install.md)**

---

## Overview

```
   VSCode extension ──┐
                      ├── WebSocket + HTTP ──► AIWrapper Server ──► local models / GPUs
   native client    ──┘                              │
                                                     ├── llama.cpp (in-process)
                                                     ├── Python workers (unsloth)
                                                     └── multimodal workers
```

The server owns everything expensive: model loading and placement, the agent
loop, retrieval, and the multimodal pipelines. The client is a thin editor
front end that renders the conversation and executes tool calls locally.

## Features

### Local inference, multiple backends

Models run through one adapter with two backends: in-process **llama.cpp** for
GGUF, and lazily spawned **Python workers** for safetensors and GGUF under an
unsloth chat template. A model's worker only starts on the first request that
targets it, and a RAM/VRAM budget evicts the least recently used worker when a
new model does not fit.

A model's `<path>` is a *directory*: every `*.gguf` inside it becomes a
selectable quantization, and safetensors directories can be quantized at load
time (4bit NF4 / fp4, 8bit, bf16, fp16, fp32).

### Multi-GPU placement

Placement is decided from the machine's actual topology — NVLink cliques, free
VRAM per card, and whether the model is dense or mixture-of-experts. Layer
split, tensor split and expert CPU offload are chosen automatically; you pick
the GPUs, per AI config.

### Logic Graph instead of one fixed agent loop

The agent's behaviour is an explicit, executable graph edited visually in
VSCode: prompt nodes, format checks, dispatch, loops with re-entry, and
user-decision nodes that pause the run to ask you a question. Each node can
choose its own model, quantization, GPU set and sampling parameters — so a
cheap fast model can plan and a large model can write the code, in one run.

### Tools run in your editor

Reading and writing files, applying patches, running terminal commands,
building projects and opening files all execute in VSCode, with per-tool
approval. **MCP** servers (stdio, SSE, streamable-HTTP) can be attached, and
their tools are offered to the model alongside the built-in ones.

### Retrieval over your project

The client pushes a full index and then incremental deltas as you edit. Chunking
is tree-sitter AST-aware with a line-window fallback, embeddings are computed
on the server, and vectors persist per project in an hnswlib store. Any node in
the graph can retrieve top-k chunks for its prompt.

### Multimodal

Image generation, text-to-speech, audio and music generation, and image-to-3D
mesh pipelines, each isolated in its own Python worker process with its own
environment and GPU visibility.

### Multi-user

Accounts, personal access tokens and per-user sessions with token accounting,
logic graphs that are either private to their owner or shared, and a
control-plane web UI for managing accounts, nodes and model downloads across
several machines.

---

## Requirements

| | |
|---|---|
| Server | Linux x86-64; NVIDIA driver + CUDA 12 runtime for GPU inference (CPU-only works, slowly) |
| Client | VSCode 1.85+ |
| Optional | MySQL for accounts and sessions; Python 3.10+ for the unsloth backend and multimodal workers |

## Documentation

| Document | Contents |
|---|---|
| [doc/server-install.md](doc/server-install.md) | Server requirements, install, configuration, first start, TLS, troubleshooting |
| [doc/extension-install.md](doc/extension-install.md) | Installing the `.vsix`, connecting to a server, logging in, first use |

## License

Proprietary — Copyright (c) 2026 real0000. All Rights Reserved.
See [LICENSE](LICENSE) for the full terms.
