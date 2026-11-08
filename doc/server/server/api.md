**English** · [繁體中文](api.zh-TW.md)

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

With no database (no `<mysql>` block) and no `<api_key>`, the server runs open
and accepts everything as admin — the `auth DISABLED (dev-open)` warning at
startup. Every endpoint here, the WebSocket included, then answers anyone who
can reach the port. That is deliberate for a single-user trial and will not be changed;
see [Running without a database](../../server-install.md#7-running-without-a-database).
A configured database that is not reachable makes the server wait for it rather
than run open.

**Requests from web pages are refused** with `403`, before the token is looked
at and without reading the body — the WebSocket handshake and CORS preflights
included, and no CORS headers are sent. The API is for programs: the CAGE
clients, the control plane, scripts. A request counts as a web page's when it
carries `Origin`, or `Sec-Fetch-Site` with any value but `none` (`none` is an
address typed into the browser). Node's built-in `fetch` and `WebSocket`, curl,
and the clients send neither. Otherwise any page you visit could make your
browser call a server only your network can reach — for example, try sign-in
passwords and read back the token.

The main port listens on `<bind>` (default `0.0.0.0`, every interface). Behind a
TLS reverse proxy on the same machine, set `<bind>127.0.0.1</bind>` so the
plain port is not reachable from outside.

A request body is read only after its bearer token checks out. Without a valid
token the body is read and thrown away in small pieces — never held in memory —
and the request is answered `401`. There is no size limit on the body of an
authenticated request.

## HTTP

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness. No auth |
| `POST` | `/api/auth/login` | Credentials in an `Authorization: Basic base64(username:password)` header → a session token. No body is read: this is the one POST handled before authentication |
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
| `GET` | `/api/delivery?session_id=&id=` | Download a file a graph generated for that session (the client saves it into the project). The session's owner or an admin |
| `POST` | `/api/delivery/result` | `{session_id, delivery_id, status}` — `written`, `rejected` or `failed`. The server removes its copy once the run is over and every file has been dealt with |
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
| `tool_result` | The result of a tool the server asked for: `content`, `is_error`, and `denied: true` when the tool did not run because the user or their settings refused it |
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
