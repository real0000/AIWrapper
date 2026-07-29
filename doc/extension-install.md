# VSCode Extension Installation

Installing the AIWrapper client and connecting it to a server.

Package: [`dist/aiwrapper-0.1.0.vsix`](../dist/)

---

## 1. Requirements

| | Required |
|---|---|
| VSCode | 1.85 or newer |
| Server | A reachable AIWrapper Server — see [server-install.md](server-install.md) |

The extension holds no models and no inference logic; everything runs on the
server.

## 2. Install

From the command line:

```bash
code --install-extension aiwrapper-0.1.0.vsix
```

Or in VSCode: **Extensions** view → **⋯** menu (top right of the panel) →
**Install from VSIX…** → pick the file.

Verify:

```bash
$ code --list-extensions --show-versions
aiwrapper.aiwrapper@0.1.0
```

The extension is not published on the Marketplace, so VSCode will not update it
automatically. Installing a newer `.vsix` over the old one is the upgrade path.

## 3. Connect to the server

Open **Settings** (`Ctrl+,`) and search for `aiwrapper`, or edit `settings.json`
directly:

```jsonc
{
  // Host only — no http:// or ws:// prefix. The protocol is derived from
  // aiwrapper.server.tls.
  "aiwrapper.server.host": "192.168.1.10",
  "aiwrapper.server.port": 15963,
  "aiwrapper.server.tls": false
}
```

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.server.host` | `localhost` | Server hostname, without protocol prefix |
| `aiwrapper.server.port` | `15963` | Server `<port>` |
| `aiwrapper.server.tls` | `false` | Use `https://` / `wss://`. Requires `<tls_cert>`/`<tls_key>` on the server |
| `aiwrapper.server.tlsRejectUnauthorized` | `true` | Verify the server certificate |
| `aiwrapper.server.apiKey` | empty | Bearer token. Prefer **AIWrapper: Login** over setting this by hand |

## 4. Self-signed certificates

If the server uses a self-signed certificate (see
[server-install.md](server-install.md) §8), the client has to be told to accept
it:

```jsonc
{
  "aiwrapper.server.tls": true,
  "aiwrapper.server.tlsRejectUnauthorized": false
}
```

The connection stays encrypted, but it is no longer protected against a
man-in-the-middle. Use a real certificate for anything exposed beyond a trusted
network.

## 5. Log in

If the server has a database and accounts configured, run **AIWrapper: Login**
from the Command Palette (`Ctrl+Shift+P`) and enter the account created in the
control-plane web UI. The session token is stored by VSCode; you do not need to
fill in `aiwrapper.server.apiKey`.

If the server runs without a database it accepts every request without
authentication, and this step is skipped.

## 6. First use

Click the **AIWrapper** icon in the activity bar to open the Chat panel.

Command Palette entries:

| Command | Purpose |
|---|---|
| `AIWrapper: Open Chat` | Chat panel |
| `AIWrapper: New Session` | Start a fresh conversation |
| `AIWrapper: Open Logic Editor` | Visual editor for the logic graph that drives the agent |
| `AIWrapper: Rebuild Index` | Re-index the workspace for retrieval |
| `AIWrapper: Manage MCP Servers` | Add / remove MCP servers |
| `AIWrapper: Open Logic Debug` | Inspect a graph run |
| `AIWrapper: Login` / `Logout` | Account session |

Tool calls the model makes — reading and writing files, applying patches,
running terminal commands — execute in your editor and ask for approval first.
Approval behaviour is configurable:

| Setting | Default |
|---|---|
| `aiwrapper.toolApproval.mode` | `ask` |
| `aiwrapper.toolApproval.perTool` | `run_terminal`, `write_file`, `build_project` → `ask` |
| `aiwrapper.toolApproval.timeoutSeconds` | `30` |

## 7. Troubleshooting

| Symptom | Cause |
|---|---|
| Connection refused | Server not running, or `aiwrapper.server.port` does not match `<port>` in `config.xml` |
| Connection closes immediately when TLS is on | Server has no `<tls_cert>`/`<tls_key>`, or the certificate is self-signed and `tlsRejectUnauthorized` is still `true` |
| `401` / login rejected | The server and the control plane point at different databases, so the account is invisible to the server |
| Model list is empty | `<models>` in the server's `config.xml` is empty, or every `<path>` failed to scan — check the server log |

## 8. Uninstall

```bash
code --uninstall-extension aiwrapper.aiwrapper
```

---

Next: the **[Client Guide](client/README.md)** — every panel and setting, and
the logic graph in detail.

Back to [server-install.md](server-install.md) · [Documentation index](README.md)
