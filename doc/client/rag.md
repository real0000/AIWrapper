# RAG

Retrieval gives a model the parts of your project that are relevant to the
question, without pasting the whole repository into the prompt.

The chain: the client indexes your workspace and pushes it to the server; the
server splits files into chunks, embeds them, and stores the vectors; and each
[Send To AI](nodes.md#send-to-ai) node can look up the top matches for its
prompt and put them in front of it.

---

## Turning it on

One setting, in the **RAG** section of the Logic Editor sidebar:

| Field | Meaning |
|---|---|
| Embedding Model | An [AI Config](ai-config.md) — any of them — used to embed |

Leave it empty and retrieval is off for the whole graph. Set it and every Send
To AI node retrieves by default.

**Indexing and querying deliberately use the same config.** Vectors are only
comparable within one embedding space, so mixing models would silently return
nonsense. There is one setting, not two, for that reason.

The section shows *"Create an AI Config to enable RAG"* until at least one
config exists.

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

## What gets indexed

The client walks the workspace and sends the server a file list; the server then
pulls the contents it needs.

| Setting | Default | Effect |
|---|---|---|
| `cage.index.enabled` | on | Index at all |
| `cage.index.excludePatterns` | `node_modules`, `.git`, `build`, `dist` | Globs never indexed |
| `cage.index.maxDepth` | 8 | How deep to walk |
| `cage.index.debounceMs` | 2000 | Quiet period after an edit before re-indexing |

The first sync sends everything; later ones send only what changed, unless too
much changed at once, in which case a full index is cheaper. See
[Project Indexing](indexing.md).

Chunking is syntax-aware: files are cut at top-level definitions using a
tree-sitter grammar, so a function tends to stay whole. Files in languages
without a grammar, and oversized definitions, fall back to overlapping line
windows.

Vectors are stored per project on the server and persist across restarts, so
re-opening a project does not re-embed it.

## Practical notes

- **Local embedding needs a model the embedding backend can load.** If
  retrieval silently returns nothing, check the server log — an embedding
  config pointing at a model the backend cannot serve as an embedder is the
  usual cause.
- **Exclude generated directories.** Build output and vendored dependencies
  crowd out real matches and cost embedding time.
- **Retrieval uses the node's prompt as the query.** A node whose prompt is
  mostly boilerplate retrieves poorly; a node that puts the user's actual
  question in the prompt retrieves well.

---

[← Logic Editor](logic-editor.md) · [Project Indexing](indexing.md) · [Client Guide](README.md)
