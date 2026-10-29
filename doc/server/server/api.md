# Server API

What the server exposes to clients. Both the HTTP API and the WebSocket share
`<port>`.

You do not need this to use the product — the clients speak it for you. It
matters when scripting against a server, or when working out where a failure
happened.

---

## Authentication

`/api/*` requires a bearer token; `/health` does not.

The token is either a personal access token issued through the
[control plane](../control/accounts.md), a session token from logging in, or
the static `<api_key>` from `config.xml`.

With no database and no `<api_key>`, the server runs open and accepts
everything — the `auth DISABLED (dev-open)` line at startup. Appropriate for a
single-user local trial, not for anything reachable.

## HTTP

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness. No auth |
| `POST` | `/api/auth/login` | `{username, password}` → a session token |
| `POST` | `/api/auth/logout` | Revoke the token presented |
| `GET` | `/api/auth/me` | Who the token belongs to |
| `POST` | `/api/session` | Create a session, returns `{session_id}` |
| `POST` | `/api/session/resume` | Pick a session up again. `404` only when the server knows there is no such session |
| `GET` | `/api/session?id=` | One session's messages (its owner or an admin) |
| `GET` | `/api/sessions` | Your sessions; an admin gets everyone's |
| `GET` | `/api/session/interrupted?session_id=` | The run that stopped half-way in that session, if any — what a resume would continue |
| `GET` | `/api/models` | Models and modalities, with quantizations and licences |
| `GET` | `/api/hardware` | GPUs, NVLink topology, RAM — what the GPU picker draws |
| `GET` | `/api/modalities` | Registered modality aliases |
| `POST` | `/api/generate` | Invoke a modality directly. The Logic Editor's preview |
| `POST` | `/api/ai-config/test` | Validate an AI config, then actually load it and generate |
| `POST` | `/api/ai-config/placement` | Where an AI config would be placed, without loading it |
| `POST` | `/api/ai-config/budget` | Per-card memory the real load would plan, measured without loading |
| `POST` | `/api/modality-config/test` | The same test for a modality config |
| `POST` | `/api/files/upload` | Upload one file — a chat attachment. Returns the `file_id` a message refers to |
| `GET` | `/api/logic-graphs` | The graphs you can see |
| `GET` | `/api/logic-graph?name=` | Fetch one graph |
| `PUT` | `/api/logic-graph` | Save a graph |
| `DELETE` | `/api/logic-graph` | Delete a graph |
| `POST` | `/api/logic-graph/rename` | `{from, to}`. A graph's name is its identity, so renaming is its own operation |
| `GET` / `POST` / `DELETE` | `/api/logic-graph/share` | List, grant (`read` or `write`) and revoke sharing — owner or admin |
| `GET` | `/ws?session_id=` | Upgrade to WebSocket |

Two worth calling out:

**`/api/hardware`** is what makes the GPU picker show real cards with real
NVLink links rather than a text field. It is also the quickest way to confirm
the server sees the GPUs you think it does.

**`/api/ai-config/test`** runs in two stages — validate, then load and generate.
The second stage is the useful one: it answers "does this placement fit in
VRAM" before a real run depends on the answer.

## WebSocket

One connection carries a whole exchange: the prompt, streamed output, tool
calls in both directions, the files the server asks for, and index updates.

Client to server:

| Message | Purpose |
|---|---|
| `message` | A user message. Carries `logic_graph_name` and `start_name`, naming the graph and entry point to run, and the `file_id`s of any attachments |
| `tool_result` | The result of a tool the server asked for |
| `tool_stream_chunk` | Output of a tool that is still running |
| `cancel` | Abort the run |
| `run.resume` / `run.discard` | Continue the run that was interrupted, or give it up |
| `project_index.full` / `.delta` | Index sync |
| `memory.sync` | The project's memory routing table and rule files |
| `logic_graph.update` | Save a graph |
| `logic.execute` | Run a graph explicitly |
| `mcp_tools_register` / `_update` | Declare the tools this client runs. The model is offered exactly these; the server has none of its own |
| `file_response` | A file the server asked for |
| `conn_step.sync` / `.update` | Connection state bookkeeping |
| `file_transfer.init`, binary frames | Chunked upload. **Not supported** — use `POST /api/files/upload` instead |

Server to client:

| Message | Purpose |
|---|---|
| `chunk` | Streamed output |
| `reasoning` | Streamed thinking, shown apart from the answer |
| `tool_call` | Run this tool |
| `interim_commit` / `interim_text` | Intermediate steps, collapsed in the UI |
| `branch_begin` / `branch_end` | A parallel branch of a Dispatch node starting and finishing |
| `logic_result` | The End node's result |
| `logic_debug` | Per-node before/after/error events |
| `file_request` | Send me this file |
| `project_index.request` / `.ack` | Ask for, and acknowledge, the project index |
| `rag_index.progress` | How far embedding the project has got |
| `memory.ack` | The routing table was received |
| `logic_graph.ack` / `.diverged` | Graph saved, or a version conflict |
| `run_interrupted` / `run_resumed` / `run_discarded` | State of a run that stopped half-way |
| `cancelled` | The run was stopped |
| `done` / `error` | End of exchange |

**The tool list is entirely client-declared.** The server holds no static tool
set — `mcp_tools_register` is how it learns what this client can do, and a
model is offered exactly that. A client that never registers tools gets a model
with no tools.

## Notes for scripting

- The session is created over HTTP, then used to open the WebSocket.
- Clients connect on demand and disconnect when the exchange ends. There is no
  long-lived socket to keep alive.
- Model management is **not** here — that is the [node agent](../agent/api.md).
  This server has no `/admin` routes.

---

[← Inference Server](README.md) · [Server Guide](../README.md)
