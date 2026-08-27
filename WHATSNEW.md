# What's New in CAGE 0.1.2

0.1.2 has one theme: **tool calls stop being a guessing game.** The format a
model uses to call a tool is now taken from that model's own chat template, and
the model is constrained at sampling time so it cannot produce anything else.

It is a **breaking release for backend packs**: a pack built before 0.1.2 is
refused. See below.

---

## Before you upgrade

| What changed | What you have to do |
|---|---|
| Tool-call parsing moved into the backend pack | **Re-download the backend pack for your GPU.** A 0.1.1 pack will not load. |
| Nothing else | The server configuration, database schema and extension settings are unchanged from 0.1.1. |

The server package was rebuilt on 2026-08-28 for the retrieval and timeout fixes
below. The backend packs and the extension are unchanged by them — if you already
have the 0.1.2 packs, only the server tarball is worth fetching again.

The extension and server are compatible across this bump; the pack is the only
mandatory download.

---

## Tool calls now come from the model's own template

Every model family writes tool calls differently — Qwen tags them, GLM tags them
differently, Kimi uses its own control tokens, Llama-3 emits bare JSON. Until now
CAGE told the model *its own* format in the system prompt and then tried to
recognise whatever came back with five competing regular expressions.

That was the wrong shape, and it produced exactly the failure you would expect:
the model's chat template already declared a format, our prompt declared a
different one, and the model drifted between them. When it drifted, one of the
five parsers usually matched something — but not always the right thing.

0.1.2 removes the guesswork in three steps:

- **The prompt is generated from the chat template.** No hand-written
  instructions about tool syntax, no invented example call ids.
- **The reply is parsed by the parser that template ships with**, not by pattern
  matching over prose.
- **The model is constrained while sampling.** A GBNF grammar built from the
  template means a malformed tool call is not merely detected, it is
  *unrepresentable* — the tokens that would produce one are never candidates.

The five hand-rolled parsers, the hold-back heuristic that guessed how many
trailing bytes might be a partial tool marker, and the model-specific special
casing are all deleted — about 1200 lines.

**Measured, not assumed:** 14 of 14 local models are recognised by their
template; 11 of 14 can additionally be grammar-constrained (the other three fall
back to template-driven parsing without the grammar). Constrained decoding costs
almost nothing — 33 tok/s against ~36 unconstrained — because sampling stays on
the fast path until the unconstrained pick is rejected.

---

## Backend packs must match the server

The code that reads a chat template lives in the backend pack, next to the
inference code it belongs with. A pack from 0.1.1 does not contain it, so the
server refuses to load one:

```
missing chat-template symbols […]. This backend pack predates the
chat-template shim (0.1.1 or earlier). Download the backend pack that
matches this server.
```

This walks back a claim made in 0.1.1's notes — that the server and the pack
version independently and upgrading one would not mean re-downloading the other.
That holds for pure kernel updates. It does not hold here, because 0.1.2 moves a
*capability* across that boundary. Loading an old pack would mean falling back to
the guessing behaviour this release exists to remove, and a silent regression in
tool calling is far harder to diagnose than a refused load.

All eleven packs are rebuilt for 0.1.2.

---

## Long generations are no longer cut off

The generation timeout was a deadline for the whole turn: five minutes from the
first token, no matter what. Any legitimately long reply hit it and was reported
as a stall.

It is now a **stall timeout** — the clock resets on every token, and fires only
when nothing has been produced for the timeout window. A 2894-token file that
used to be truncated at the 300-second wall now completes in 88 seconds and is
written out whole.

The same mistake was found on the way *in*: reading a long prompt had its own
three-minute deadline, so a large context was reported as a stall even while every
batch was making progress. That is now a stall timeout too, and the message says how
far it got.

---

## Retrieval no longer takes a GPU you did not give it

If you enabled RAG, the embedding model ignored the GPUs you picked for it and
loaded onto the first one it found. On a machine with a display card and compute
cards, that is usually the display card — and nothing said so.

Every other model in CAGE honours the GPU selection on its AI config. The embedder
was the one that did not, on both the in-process and vLLM paths. It does now, and it
says which devices it took.

---

## Retrieved code is labelled as excerpts

Context retrieved for a prompt is a set of fragments chosen by similarity — not whole
files, not in order. That was never stated in the prompt, and models drew conclusions
from it that the fragments do not support: in one direction assuming a project was
already finished, in the other reporting a snippet that ends mid-statement as broken
code. The second one is worth naming because it is convincing: a reviewing step
produced a list of compiler errors whose line numbers were exactly the chunk
boundaries, for a program that compiled and ran correctly.

The block now says what it is. If you are building a logic graph, also note the
matching rule: **a node that judges a piece of text rather than the codebase should
have RAG turned off on that node.** Retrieval helps the steps that act on code; it
misleads the ones that grade an answer.

---

## Fixes worth naming

- **A backend pack that is too old fails at load, with the reason and the fix**,
  instead of loading and then behaving incorrectly.
- **Tool arguments that contain a JSON object are no longer mis-split** by a
  parser looking for the next closing brace.
- **Streaming no longer holds back trailing text** waiting to see whether it was
  the start of a tool marker.

---

## Known gaps

Unchanged from 0.1.1 except where noted:

- Three of fourteen models expose a chat template but no usable grammar; they
  run with template-driven parsing only.
- The server binary still reports no version of its own; `/health` does not
  return one.
- The AMD detection path has not been exercised on real AMD hardware.
- Multi-node exists in the control plane, but each client connects to a single
  server — there is no scheduling across machines.
- Server-side session history is recorded but not replayed into a conversation
  resumed after a restart.
- `mesh-trellis` still needs an upstream interactive setup step.
- Pascal and older NVIDIA cards are not supported.
