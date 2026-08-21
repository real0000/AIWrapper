# Client Guide

The CAGE client is a VSCode extension. It holds no models and runs no
inference — every model decision belongs to the server and to the logic graph.
What the client does is show you the conversation, let you design the agent's
behaviour, and execute the tool calls the model asks for, in your editor, with
your approval.

Installation is covered separately in
[extension-install.md](../extension-install.md).

---

## The two windows

![The CAGE chat panel in VSCode](../images/chat-panel.png)

### [Chat Panel →](chat-panel.md)

The everyday window: send a message, watch the answer stream in, approve tool
calls, switch sessions, browse history. The selectors along the bottom decide
*which* logic graph answers you and *where* in that graph the run starts.

### [Logic Editor →](logic-editor.md)

A visual editor for the graph that drives the agent. Nodes are the steps,
connections are the order, and the panel on the left holds the reusable
configurations those nodes reference. This is where CAGE differs most from
a normal chat extension: the agent loop is data you edit, not code you accept.

---

## What lives where

| Topic | What it covers |
|---|---|
| [Chat Panel](chat-panel.md) | Sending messages, sessions, history, the Graph and Start selectors, the status chip |
| [Logic Editor](logic-editor.md) | Canvas, node palette, inspector, toolbar, console, groups |
| [Nodes](nodes.md) | Every node type: what it does, its pins, its settings |
| [AI Configs](ai-config.md) | Model, quantization, GPU placement, context, sampling — every parameter and when it takes effect |
| [Modality Configs](modality-config.md) | The generative half of the AI Configs list — image / speech / audio / music / 3D, local workers and remote providers |
| [Format Configs](format-config.md) | Structured output schemas and output validation |
| [Variables](variables.md) | Graph-level state that survives across nodes within a run |
| [Graph file format](graph-format.md) | The JSON a graph is stored as — enough to write one without the editor |
| [Project Memory](memory.md) | History written automatically per file, plus your own rules and when they load |
| [RAG](rag.md) | Retrieval over your project: what gets indexed, how a node uses it |
| [Tools & Approval](tools.md) | The tools the model can run in your editor, and how approval works |
| [File Approval](file-approval.md) | How every file write is approved individually, before it is written |
| [MCP Servers](mcp.md) | Attaching third-party tool servers |
| [Project Indexing](indexing.md) | What the client sends to the server and when |
| [Settings](settings.md) | Every `cage.*` setting |

---

## How a message actually flows

Worth reading once — the rest of the guide assumes this shape.

```
you type a message in the Chat Panel
        │
        │  the message names the logic graph you picked and the Start
        │  node you selected
        ▼
   Start ──► SendToAi ──► CheckFormat ──► … ──► End
                │              │
                │              └─ validates the answer, branches True / False
                │
                └─ the model asks for a tool  ──►  the client runs it in VSCode
                   (read a file, apply a patch, run a command)  ──► result goes
                   back to the model, which continues
                                                      │
        at the end, anything the run wrote  ──────────┘
        is shown to you for approval before it reaches disk
```

The server executes the graph. The client supplies the prompt, answers tool
calls, and renders whatever streams back. If no graph exists for the project,
the server falls back to a plain agent loop.

Every file a tool writes is approved individually, immediately before it is
written to your workspace — see [File Approval](file-approval.md).

---

Proprietary — Copyright (c) 2026 real0000. All Rights Reserved. See [LICENSE](../../LICENSE).
