# RAG

Retrieval gives a model the parts of your project that are relevant to the
question, without pasting the whole repository into the prompt.

The chain: the client indexes your workspace and pushes it to the server; the
server splits files into chunks, embeds them, and stores the vectors; and each
[Send To AI](nodes.md#send-to-ai) node can look up the top matches and put them in
front of its prompt.

**The query is the chat message, not the node's prompt.** Every node in a graph
therefore retrieves against the same text — the thing the user asked for — however
far down the graph it sits. That matters when deciding which nodes should retrieve
at all: see [When to turn it off](#when-to-turn-it-off).

---

## Turning it on

One setting, **Embedding Model** in the **Memory** section of the Logic Editor
sidebar:

| Field | Meaning |
|---|---|
| Embedding Model | An [AI Config](ai-config.md) — any of them — used to embed |

Leave it empty and retrieval is off for the whole graph. Set it and every Send
To AI node retrieves by default.

**Indexing and querying deliberately use the same config.** Vectors are only
comparable within one embedding space, so mixing models would silently return
nonsense. There is one setting, not two, for that reason.

The section shows *"Create an AI Config to enable RAG."* until at least one
config exists. The same config also ranks file histories when a node keeps only
the top N of them — see [Project Memory](memory.md).

## Per-node control

Each Send To AI node has a **RAG** setting:

| Value | Effect |
|---|---|
| Inherit | Use the graph's embedding config. The default |
| Off | No retrieval for this node |
| Custom | Use a different config, named in **RAG Embedding** |

Turn it off for nodes where it only adds noise — a node that reformats an
answer, or one that summarises text already in the prompt. Retrieval costs an
embedding call and prompt space on every run.

## When to turn it off

Retrieval helps a node that has to find its way around code it did not write —
a planner deciding what to change, a coder looking for the existing convention.

It hurts a node whose job is to **judge**: one that reads a report or an answer and
returns a verdict. Two reasons, and they compound:

1. The query is the chat message, so what comes back is code resembling the original
   request — not the thing being judged. For a judge that is noise at best.
2. Retrieved blocks are *excerpts*, chosen by similarity and cut at chunk boundaries.
   A model asked to find defects will find them in the cut.

The second one is not hypothetical. A filter node — no tools, whose entire input was a
verifier's transcript — ran with retrieval on and returned "fail" four rounds in a row
with errors like `packer.cpp:248-341: missing code after line 341`. Those line ranges
were exactly the chunk boundaries. The program compiled and ran correctly throughout,
and nothing anywhere reported an error; the loop just could not end.

The injected block now states that it contains excerpts, which reduces this. The rule
still stands: **set RAG to Off on nodes that grade, classify or decide.** The
[worked example](example-graph.md#3-rag_mode-off-on-the-filter--retrieval-poisons-a-judge)
shows both settings side by side in one graph.

---

## What gets indexed

The client walks the workspace and sends the server a file list; the server then
pulls the contents it needs.

| Setting | Default | Effect |
|---|---|---|
| `cage.index.enabled` | on | Index at all |
| `cage.index.excludePatterns` | `node_modules`, `.git`, `build`, `dist` | Globs never indexed |
| `cage.index.debounceMs` | 2000 | Quiet period after an edit before re-indexing |

The first sync sends everything; later ones send only what changed, unless too
much changed at once, in which case a full index is cheaper. See
[Project Indexing](indexing.md).

Chunking is syntax-aware: neighbouring top-level content is gathered into
chunks of up to 4000 bytes using a tree-sitter grammar, never cutting inside a
definition, so a function stays whole and a small file is one chunk. Files in
languages without a grammar, and oversized definitions, fall back to overlapping
line windows.

`.cage/` — the project's memory and session records — is never indexed; the
memory AI decides what of it a step reads. See [Project memory](memory.md).

Vectors are stored per project on the server and persist across restarts, so
re-opening a project does not re-embed it.

## Practical notes

- **Local embedding needs a model the embedding backend can load.** If
  retrieval silently returns nothing, check the server log — an embedding
  config pointing at a model the backend cannot serve as an embedder is the
  usual cause.
- **Exclude generated directories.** Build output and vendored dependencies
  crowd out real matches and cost embedding time.
- **The query is the chat message**, the same one for every node in the graph.
  A node deep in a loop does not retrieve against what it is currently working on.

---

[← Logic Editor](logic-editor.md) · [Project Indexing](indexing.md) · [Worked example](example-graph.md) · [Client Guide](README.md)
