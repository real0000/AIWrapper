# Retrieval

The server side of RAG: what happens between the client pushing a file listing
and a graph node getting relevant chunks in front of its prompt.

The user-facing half is in [the client guide](../../client/rag.md).

---

## The chain

```
client pushes a file listing (paths, sizes, mtimes — not contents)
        ↓
server decides what changed and pulls those files back over the connection
        ↓
ChunkPipeline splits them            tree-sitter, with a line-window fallback
        ↓
EmbedderPool embeds each chunk       the graph's embedding config
        ↓
VectorStore                          hnswlib index, one per project, on disk
        ↓
a Send To AI node queries top-k and prepends the results to its prompt
```

Nothing here is configured in `config.xml`. Retrieval is switched on by naming
an embedding config in the graph, which is why a server can host projects where
some graphs retrieve and others do not.

## Chunking

Files are split at top-level definitions using a tree-sitter grammar, so a
function or class tends to arrive whole rather than sliced through the middle.

Grammars ship for the common languages. A file in a language without one, or a
single definition too large to be one chunk, falls back to overlapping line
windows.

That fallback is worth remembering when retrieval on a particular language
looks worse than elsewhere — it is probably windowing rather than parsing.

## Embedding

The embedding model runs as a dedicated long-lived context, separate from the
generation workers: embedding models are small, and loading and unloading one
repeatedly costs more than keeping it resident.

Vectors are normalized, so similarity is a plain inner product. Text longer
than the context is truncated, with a warning in the log.

**Indexing and querying deliberately use the same config.** Vectors only mean
anything within one embedding space; there is a single setting rather than two
precisely so they cannot drift apart.

## The vector store

One hnswlib index per project, persisted under `data/vectors/`, loaded lazily
at startup.

Updating a file removes its old chunks — tombstoned, then compacted — and
inserts the new ones, so re-indexing does not accumulate stale copies of edited
code.

Because it is on disk, reopening a project does not re-embed it. Deleting
`data/vectors/` forces a full rebuild, which is the blunt fix if results look
wrong.

## What actually leaves the client

Worth being precise, since this is a private-deployment product:

- The client sends **a listing** — paths, sizes, modification times, detected
  languages, and the build system.
- The server **pulls file contents** only for files it needs to embed.
- A tool call reads contents on demand.

So the index is a map, and content crosses the wire when retrieval or a tool
requires it.

## When retrieval returns nothing

In rough order of likelihood:

1. **No embedding config on the graph.** Retrieval is off until one is named.
2. **The embedding model cannot serve embeddings.** The pool needs a model the
   backend can run in embedding mode; the log says so at the first attempt.
3. **Nothing indexed yet.** The first sync happens when a message is sent, not
   when the workspace opens.
4. **Everything relevant is excluded.** Check the client's exclude patterns.

---

[← Inference Server](README.md) · [Client-side RAG](../../client/rag.md) · [Server Guide](../README.md)
