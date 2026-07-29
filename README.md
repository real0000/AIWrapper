# AIWrapper

**AIWrapper** is a self-hosted AI coding assistant platform: a high-performance C++20 inference
server paired with a VSCode extension and a native desktop client. Everything — models, sessions,
project index, and generated artifacts — stays on your own hardware.

This repository is the **distribution channel**: compiled installers and documentation are
published here. The source code is not part of this repository.

---

## Downloads

Evaluation builds are published on the [Releases](https://github.com/real0000/AIWrapper/releases)
page:

| Package | Description |
|---|---|
| `aiwrapper-server-*` | Inference server (C++20 / Boost) |
| `aiwrapper-*.vsix` | VSCode extension client |
| `aiwrapper-native-*` | Standalone native desktop client |

See [`docs/`](docs/) for installation and configuration guides.

---

## Overview

```
   VSCode extension  ─┐
                      ├─ WebSocket + HTTP ─►  AIWrapper Server  ─►  local models / GPUs
   Native client     ─┘
```

- **Server** — C++20 / Boost. Routes every request through a unified adapter to either an
  in-process llama.cpp backend or lazily spawned Python workers, with a VRAM/RAM budget manager
  and LRU model eviction.
- **Clients** — a VSCode extension (chat panel, visual logic-graph editor, tool approval UI) and
  a Node-free native C++ client built on a custom retained-mode GUI toolkit.

## Features

**Inference**
- Local LLM inference via in-process llama.cpp (GGUF) or Python workers (safetensors and GGUF)
- Multi-GPU placement with automatic topology-aware layer/tensor splitting and MoE CPU offload
- Reasoning-model support with chain-of-thought separated into its own channel

**Agent workflow**
- **Logic Graph** — a visual node editor that replaces the usual single agentic loop: chain
  prompts, format checks, dispatch, and user-decision nodes into an explicit executable graph
- Tools run inside the editor: read/write files, apply patches, run terminal commands, open files
- **MCP** — connect stdio, SSE, and streamable-HTTP MCP servers; their tools are exposed to the model
- Human-in-the-loop approval for every tool invocation

**Retrieval**
- Full and incremental project indexing pushed from the client
- Tree-sitter AST-aware chunking with line-window fallback
- Persistent per-project vector store (hnswlib) with per-node top-k retrieval

**Multimodal**
- Image generation, text-to-speech, audio and music generation, and image-to-3D mesh pipelines,
  each running as an isolated Python worker process

**Multi-user**
- Accounts, tokens, and per-user sessions with token accounting
- Shared or owner-private logic graphs, plus an administration console

## Requirements

- Linux or Windows host with an NVIDIA GPU (CUDA); CPU-only operation is supported at reduced speed
- VSCode ≥ 1.85 for the extension client
- Python 3.10+ on the server host for the multimodal and Unsloth workers

---

## Commercial Availability

This software is proprietary. Evaluation binaries are available for testing.
Acquisition of the complete source code, intellectual property, and commercial rights is available upon request.

---

## License

Proprietary — Copyright (c) 2026 real0000. All Rights Reserved.
See [LICENSE](LICENSE) for the full terms.
