# Node Agent

`aiw-launcher --agent` is the resident process on each machine. It owns the
local `aiwrapper-server`: starting it, stopping it, restarting it, editing the
config it will read, and pulling models onto the local disks.

It is the only piece that has to be running all the time. The server it
supervises can be down and the machine is still manageable.

```bash
aiw-launcher --agent --config /opt/aiwrapper/config.xml
```

Installed as the `aiw-agent` service — see
[server-install.md](../../server-install.md).

---

## What it does

| Job | Detail |
|---|---|
| Supervise the server | Spawns `aiwrapper-server` as a child process, stops it with SIGTERM then SIGKILL, restarts on demand |
| Report status | Answers "is it up, what is loaded, how much VRAM is free" by asking the local server over HTTP |
| Edit the model list | Rewrites `<models>` in the local `config.xml` — see [Models & downloads](models.md) |
| Download models | Fetches from Hugging Face onto the local disks, choosing between them by free space |

Because the server is a child process, killing the agent takes the server with
it — the systemd unit uses `KillMode=control-group` so the pair stops together.

## Configuration

The agent reads the `<node>` block of the same `config.xml` the server uses:

```xml
<node>
  <server_binary>./bin/aiwrapper-server</server_binary>
  <working_dir></working_dir>
  <autostart>true</autostart>
  <bind>127.0.0.1</bind>
  <agent_port>15972</agent_port>
  <node_token></node_token>
  <download_dir>models</download_dir>
  <log_file>/tmp/aiwrapper/server.log</log_file>
</node>
```

| Field | Meaning |
|---|---|
| `server_binary` | Path to `aiwrapper-server` |
| `working_dir` | The server's working directory. Empty = the directory holding this file. **Not** the build directory — the server resolves `data/` and `models/` against its cwd |
| `autostart` | Start the server as soon as the agent comes up |
| `bind` / `agent_port` | Where the node API listens. `127.0.0.1` for a single machine; a reachable address when a remote control plane drives it |
| `node_token` | Bearer the control plane must present. Empty disables authentication — only acceptable on localhost |
| `download_dir` | Where downloaded models go. Repeat the element to use several disks |
| `log_file` | Where the server child's stdout and stderr land |

Every relative path in `config.xml` resolves against the directory the file
lives in, not the agent's working directory — so it does not matter where the
agent is started from.

**Binding the agent to a public address without setting `node_token` exposes
start/stop/restart and model management to anyone who can reach the port.**

![Models marked live or pending restart](../../images/control-models.png)

*The same rule seen from the web UI: the banner and the per-entry state come
from comparing `config.xml` against what the running server actually loaded.*

## Restart to apply

The agent edits `config.xml`. The server is running whatever it read at
startup. Nothing the agent writes reaches the running server.

The model list reflects this with a state per entry:

| State | Meaning |
|---|---|
| `live` | In the config *and* loaded by the running server |
| `pendingRestart` | In the config, not in the running server |

The state is worked out by comparing the config against the aliases the server
reports, so it is accurate rather than remembered.

Restart the server — one button in the web UI, or `POST /node/server/restart` —
and the pending entries become live.

## Watching it

```bash
systemctl status aiw-agent
journalctl -u aiw-agent -f          # the agent
tail -f /tmp/aiwrapper/server.log   # the server it spawned
```

The server's own output goes to `log_file`, not to the journal — the agent
captures the child's streams rather than passing them through.

---

Next: [Models & downloads](models.md) · [Node API](api.md) · [Server Guide](../README.md)
