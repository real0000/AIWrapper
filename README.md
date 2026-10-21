# CAGE — Composable Agent Graph Engine

**A self-hosted AI coding assistant: a C++20 inference server plus a VSCode client.
Models, sessions, project index and generated artifacts all stay on your own hardware.**

The name is the design: the agent loop is a **graph** you compose from nodes and
edit, not a fixed loop inside the binary. Each node picks its own model, so one
run can plan with a small fast model and write code with a large one.

> **Proprietary software.** Copyright (c) 2026 real0000. All Rights Reserved.
> This repository distributes compiled packages and documentation; it does not
> contain the source code, and the source code is not for sale.

## Licensing

CAGE is sold as a **base product plus separately purchased modules**, and every
product carries **perpetual updates** — buy it once and every future release of
that product is included. No maintenance period, no renewal, no version at which
your licence stops.

A **Commercial Licence** is organisation-wide: install and run it on as many
machines as you like within one company, for your own internal use. No per-seat,
per-GPU or per-server counting.

| | |
|---|---|
| Scope | One legal entity and the entities it controls; unlimited installations |
| Use | Your own internal business purposes, including building your own products |
| Updates | Perpetual. Every future release of what you bought, at no further charge |
| Modules | Major new capabilities are sold separately, each with its own perpetual updates. A module needs a licensed base product to run |
| Not included | Offering CAGE's functionality to third parties as a hosted service, API, or service bureau — that needs a separate agreement |

**A module never takes away what you already bought.** Whatever a product could
do when you licensed it stays part of that product; modules only ever add to it.

Free evaluation builds are available for testing, and may not be used in
production.

Full terms: **[LICENSE](LICENSE)**. Enquiries, including hosted-service and OEM
terms: <https://github.com/real0000>

---

## Downloads

| Package | Platform | Contents | Where |
|---|---|---|---|
| `cage-server-0.2.0-linux-x64.tar.gz` | Linux x86-64 | Inference server, node agent, control plane, model downloader | [Releases](../../releases) |
| `cage-backend-*-0.2.0-linux-x64.tar.gz` | Linux x86-64 | **GPU support — one pack for your hardware.** See below | [Releases](../../releases) |
| [`cage-0.2.0.vsix`](dist/cage-0.2.0.vsix) | VSCode ≥ 1.85 | The editor client | `dist/` in this repository |

> **What is on GitHub is the evaluation build.** Releases here carry preview and
> evaluation packages, for trying CAGE out and reporting what breaks. They are
> not the licensed product and are not for production use — see
> [Licensing](#licensing).
>
> Purchases go through Gumroad, which acts as merchant of record, and a licensed
> copy is delivered from there. A purchase carries perpetual updates for that
> product; this repository is not the update channel for it.

**The server package contains no GPU code.** Every local model needs a backend
pack as well — a second download carrying the compiled kernels for your cards.
Pick by compute capability:

| Pack | Hardware |
|---|---|
| `cage-backend-cuda-sm60_sm61` | P40, P100, P4, GTX 10xx |
| `cage-backend-cuda-sm70_sm75` | V100, Titan V, T4, RTX 20xx, GTX 16xx |
| `cage-backend-cuda-sm80_sm86` | A100, A30, A40, A10, RTX 30xx |
| `cage-backend-cuda-sm89_sm90` | L40, L40S, L4, RTX 40xx, H100, H200 |
| `cage-backend-cuda-sm120_sm121` | RTX 50xx, GB10 (DGX Spark) |
| `cage-backend-hip-*` | AMD via ROCm, split by ISA generation (RDNA2/3/4, CDNA) |
| `cage-backend-vulkan` | Any Vulkan 1.2 GPU — AMD, Intel, or NVIDIA |
| `cage-backend-cpu` | No GPU |

You can install several; the server probes each one per card. Without any, the
server still runs, but only `remote` models work. Full detail:
**[Backend Packs](doc/server/server/backend-packs.md)**.

Installation: **[doc/server-install.md](doc/server-install.md)** — Docker or
native — then **[doc/extension-install.md](doc/extension-install.md)** for the
editor client.

---

## Overview

```
   VSCode extension ──┐
                      ├── WebSocket + HTTP ──► CAGE Server ──► local models / GPUs
   native client    ──┘                              │
                                                     ├── backend pack (in-process):
                                                     │     text, vision, safetensors,
                                                     │     image, speech, music, motion, 3D
                                                     └── remote chat APIs
```

The server owns everything expensive: model loading and placement, the agent
loop, retrieval, and the multimodal pipelines. The client is a thin editor
front end that renders the conversation and executes tool calls locally.

![The CAGE chat panel in VSCode](doc/images/chat-panel.png)

*The chat panel runs inside VSCode. The selector at the bottom picks which
logic graph drives the conversation.*

## Features

### Local inference, multiple backends

Models run through one adapter with two backends: in-process **ik_llama.cpp**,
from the backend pack, for GGUF and Hugging Face safetensors alike (vision
included, via an `mmproj` projector), and **remote** cloud endpoints (OpenAI,
Anthropic, Gemini). There is no Python anywhere. Nothing loads until the first
request that targets it, and one RAM/VRAM ledger across every local model evicts
the least recently used idle one when a new one does not fit.

A model's `<path>` is a *directory*: every `*.gguf` inside it becomes a
selectable quantization, and a safetensors directory is quantized while it loads
(4bit, 8bit, bf16, fp16, fp32). What kind of model it is — chat, embedding, image
generator — is worked out from the weights, not declared.

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

![The Logic Editor](doc/images/logic-editor.png)

*A coding workflow in the Logic Editor. Left: the node palette, the AI configs
the graph's nodes bind to, and its variables. Each config names its own model
and parameters.*

### Tools run in your editor

Reading and writing files, applying patches, running terminal commands,
building projects and opening files all execute in VSCode, with per-tool
approval and per-file approval for writes. One **Tools** table holds every tool
the model can call — built-in ones, tools you define with a command line, and
the tools of attached **MCP** programs (stdio or Streamable HTTP).

### Retrieval over your project

The client pushes a full index and then incremental deltas as you edit. Chunking
is tree-sitter AST-aware with a line-window fallback, embeddings are computed
on the server, and vectors persist per project in an hnswlib store. Any node in
the graph can retrieve top-k chunks for its prompt.

### Multimodal

Image generation, text-to-speech, audio and music generation, motion, and
image-to-3D meshes run in-process too, through the backend pack, on the same GPU
context and the same VRAM ledger as the language models.

### Project memory

Each file's history of what was changed and why, a record of what every step of
the current conversation did — so a step that runs again in a loop sees what the
last attempt found — and your own standing rules. A small model picks which of
them each step actually reads.

### Multi-user

Accounts, personal access tokens and per-user sessions with token accounting,
logic graphs that are either private to their owner or shared, and a
control-plane web UI for managing accounts, nodes and model downloads across
several machines.

---

## Requirements

| | |
|---|---|
| Server, either way | Linux x86-64, plus a [backend pack](doc/server/server/backend-packs.md) for your GPU. NVIDIA needs only the driver — the packs carry their own CUDA libraries. AMD through the HIP packs or Vulkan, Intel through Vulkan. CPU-only works, slowly |
| …via Docker | Docker with Compose v2, and the NVIDIA Container Toolkit for GPU access. Nothing else on the host |
| …natively | glibc 2.38+ (Ubuntu 24.04 or newer), PowerShell 7.4+ to run the installer, and MySQL if you want accounts |
| Client | VSCode 1.85+ |

## Documentation

| Document | Contents |
|---|---|
| [WHATSNEW.md](WHATSNEW.md) | **Upgrading from 0.1.x?** What changed, and what needs action from you |
| [doc/verification-status.md](doc/verification-status.md) | **How far each piece has been tested** — and which reports would help most |
| [doc/server-install.md](doc/server-install.md) | **Start here** — Docker or native, then the native path in full: configuration, database, TLS, troubleshooting |
| [doc/server/docker.md](doc/server/docker.md) | The Docker path — one `docker compose up`, with models, database and config as host folders |
| [doc/extension-install.md](doc/extension-install.md) | Installing the `.vsix`, connecting to a server, logging in, first use |
| [doc/server/](doc/server/README.md) | Server guide — node agent, inference server, control plane: what each owns, models, backends, modalities, retrieval, accounts, multi-node |
| [doc/client/](doc/client/README.md) | Client guide — both windows panel by panel, every node type, every configuration parameter, RAG, tools and file approval, all settings |

## License

Proprietary — Copyright (c) 2026 real0000. All Rights Reserved.
Licensed, not sold; no source code is included or sold. See [LICENSE](LICENSE)
for the full terms, and [Licensing](#licensing) above for what a purchase covers.

CAGE incorporates open-source components, all under permissive licences; they
are listed with their copyright notices in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Model weights are **not**
covered by either document — they are chosen and installed by the operator, and
several carry commercial restrictions. See
[model licences](doc/server/server/models.md#model-licences-are-yours-to-check).
