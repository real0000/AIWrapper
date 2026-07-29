# Project Indexing

The client keeps the server aware of what is in your workspace. The index is
what [RAG](rag.md) retrieves from, and what lets a model reason about files it
has not been shown.

It runs on its own — there is nothing to start — but it is worth knowing what
leaves your machine and when.

---

## What is sent

A listing, not your source code: for each file, its path, whether it is a file
or directory, its size, its modification time, and the language guessed from its
extension. Alongside that, the detected build system and the key files that
identify the project — `CMakeLists.txt`, `*.uproject`, `ProjectSettings/`, and
so on.

File **contents** are sent only when something asks for them: the server pulling
a file to embed it for retrieval, or a tool call reading one.

## When it runs

| Trigger | Effect |
|---|---|
| Extension starts | Watchers registered |
| A file is created, deleted or renamed | Marked dirty |
| A file is saved | Marked dirty after the debounce period |
| You send a message | Pending changes are flushed before the run starts |

Nothing is sent while you type. The index syncs at the start of an exchange, so
the model sees the project as it is at that moment.

The first sync sends the whole index. Later ones send only what changed —
unless the proportion of changed files crosses
`aiwrapper.index.deltaFullThreshold` (40%), where a full index is cheaper than
describing the difference. A branch switch usually crosses it.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.index.enabled` | `true` | Turn indexing off entirely |
| `aiwrapper.index.excludePatterns` | `**/node_modules/**`, `**/.git/**`, `**/build/**`, `**/dist/**` | Globs never walked |
| `aiwrapper.index.maxDepth` | 8 | Directory depth limit |
| `aiwrapper.index.debounceMs` | 2000 | Quiet period after a save |
| `aiwrapper.index.deltaFullThreshold` | 0.4 | Change ratio above which a full index is sent |

**AIWrapper: Rebuild Index** forces a full re-index, which is the thing to try
when retrieval results look stale.

## Keeping it useful

Exclusions are the main lever. Generated output, vendored dependencies and
large binary assets make the index bigger without making it more useful, and
under [RAG](rag.md) they actively crowd out real matches. Adding them to
`excludePatterns` is usually the single most effective change you can make to
retrieval quality.

---

[← RAG](rag.md) · [Settings](settings.md) · [Client Guide](README.md)
