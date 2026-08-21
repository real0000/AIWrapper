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
| `POST` | `/api/session` | Create a session, returns `{session_id}` |
| `POST` | `/api/session/resume` | Resume one |
| `GET` | `/api/models` | Models and modalities, with quantizations and licences |
| `GET` | `/api/hardware` | GPUs, NVLink topology, RAM — what the GPU picker draws |
| `GET` | `/api/modalities` | Registered modality aliases |
| `POST` | `/api/generate` | Invoke a modality directly. The Logic Editor's preview |
| `POST` | `/api/ai-config/test` | Validate an AI config, then actually load it and generate |
| `GET` | `/api/logic-graph?projectId=` | Fetch a graph |
| `PUT` | `/api/logic-graph` | Update a graph |
| `DELETE` | `/api/logic-graph` | Delete a graph |
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
calls in both directions, file transfers, and index updates.

Client to server:

| Message | Purpose |
|---|---|
| `message` | A user message. Carries `logic_graph_id` and `start_name`, naming the graph and entry point to run |
| `tool_result` | The result of a tool the server asked for |
| `cancel` | Abort the run |
| `project_index.full` / `.delta` | Index sync |
| `logic_graph.update` | Save a graph |
| `logic.execute` | Run a graph explicitly |
| `mcp_tools_register` / `_update` | Declare which tools this client can run |
| `file_response` | A file the server asked for |
| `file_transfer.init`, binary frames | Chunked upload. **Not supported** — use `POST /api/files/upload` instead |

Server to client:

| Message | Purpose |
|---|---|
| `chunk` | Streamed output |
| `tool_call` | Run this tool |
| `interim_commit` / `interim_text` | Intermediate steps, collapsed in the UI |
| `logic_result` | The End node's result |
| `logic_debug` | Per-node before/after/error events |
| `file_request` | Send me this file |
| `logic_graph.diverged` | Version conflict |
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
