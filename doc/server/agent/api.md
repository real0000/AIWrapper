# Node API

The HTTP surface the agent exposes. The control plane is its only intended
caller, but it is a plain HTTP API — useful for scripting a deployment, and
worth understanding before you expose the port.

Base URL: `http://<bind>:<agent_port>` — `127.0.0.1:15972` by default.

---

## Authentication

Every `/node/*` route requires the bearer configured as `<node_token>`:

```bash
curl -H "Authorization: Bearer $NODE_TOKEN" http://127.0.0.1:15972/node/status
```

`/health` is exempt.

An empty `<node_token>` disables the check entirely. That is fine when the
agent binds to `127.0.0.1` and is only reached from the same machine. It is not
fine on any address another machine can reach: these endpoints start and stop
processes and rewrite configuration.

## Status

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness. No auth |
| `GET` | `/node/status` | Everything the dashboard shows |

`/node/status` combines what the agent knows about its child process — state,
pid, uptime — with what it learns by asking the local server for `/health`,
`/api/hardware` and `/api/models`. So it reports both "the process is up" and
"these models are loaded, this much VRAM is in use".

If the server is down, the process fields are still returned and the live
fields are absent. That distinction is the point: it tells you whether the
server crashed or was never started.

## Controlling the server

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/node/server/start` | Spawn the server |
| `POST` | `/node/server/stop` | SIGTERM, then SIGKILL if it does not exit |
| `POST` | `/node/server/restart` | Stop then start — how config changes are applied |

## Models

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/node/models` | The config's model list, each marked `live` or `pendingRestart` |
| `POST` | `/node/models/edit` | Add or change an entry |
| `POST` | `/node/models/remove` | Remove an entry |

These edit `config.xml` only. See [Restart to apply](README.md#restart-to-apply).

## Downloads

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/node/dirs` | Download directories with free and total space |
| `POST` | `/node/hf/list` | List the downloadable groups in a Hugging Face repo |
| `POST` | `/node/download` | Start a download; returns an id |
| `GET` | `/node/download?id=` | Progress for that download |

Downloads are asynchronous: start one, poll it. A large model takes as long as
it takes, and the agent stays responsive throughout.

## Scripting a deployment

The API is enough to drive a machine without the web UI — add a model, restart,
confirm it came up:

```bash
AUTH="Authorization: Bearer $NODE_TOKEN"
N=http://127.0.0.1:15972

curl -s -H "$AUTH" $N/node/dirs
curl -s -H "$AUTH" -X POST $N/node/download -d '{"repo":"Qwen/Qwen3-Coder-Next", ...}'
curl -s -H "$AUTH" "$N/node/download?id=<id>"      # until it completes
curl -s -H "$AUTH" -X POST $N/node/server/restart
curl -s -H "$AUTH" $N/node/status
```

---

[← Node Agent](README.md) · [Models & downloads](models.md) · [Server Guide](../README.md)
