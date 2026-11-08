**English** · [繁體中文](extension-install.zh-TW.md)

# VSCode Extension Installation

Installing the CAGE client and connecting it to a server.

Package: [`dist/cage-0.2.0.vsix`](../dist/)

---

## 1. Requirements

| | Required |
|---|---|
| VSCode | 1.85 or newer |
| Server | A reachable CAGE Server — see [server-install.md](server-install.md) |

The extension holds no models and no inference logic; everything runs on the
server.

## 2. Install

From the command line:

```bash
code --install-extension cage-0.2.0.vsix
```

Or in VSCode: **Extensions** view → **⋯** menu (top right of the panel) →
**Install from VSIX…** → pick the file.

Verify:

```bash
$ code --list-extensions --show-versions
real0000.cage@0.2.0
```

Installing a newer `.vsix` over the old one is the upgrade path. A side-loaded
extension is not updated automatically, whether or not the same version is also
listed on the Marketplace.

## 3. Connect to the server

Open **Settings** (`Ctrl+,`) and search for `cage`, or edit `settings.json`
directly:

```jsonc
{
  // Host only — no http:// or ws:// prefix. The protocol is derived from
  // cage.server.tls.
  "cage.server.host": "cage.example.lan",
  "cage.server.port": 15963,
  "cage.server.tls": false
}
```

| Setting | Default | Meaning |
|---|---|---|
| `cage.server.host` | `localhost` | Server hostname, without protocol prefix |
| `cage.server.port` | `15963` | Server `<port>` |
| `cage.server.tls` | `false` | Use `https://` / `wss://`. Requires `<tls_cert>`/`<tls_key>` on the server |
| `cage.server.tlsRejectUnauthorized` | `true` | Verify the server certificate |
| `cage.server.apiKey` | empty | Bearer token. Prefer **CAGE: Login** over setting this by hand |

## 4. Self-signed certificates

If the server uses a self-signed certificate (see
[server-install.md](server-install.md) §8), the client has to be told to accept
it:

```jsonc
{
  "cage.server.tls": true,
  "cage.server.tlsRejectUnauthorized": false
}
```

The connection stays encrypted, but it is no longer protected against a
man-in-the-middle. Use a real certificate for anything exposed beyond a trusted
network.

## 5. Log in

If the server has a database and accounts configured, run **CAGE: Login**
from the Command Palette (`Ctrl+Shift+P`) and enter the account created in the
control-plane web UI. The session token is stored by VSCode; you do not need to
fill in `cage.server.apiKey`.

If the server runs without a database and no `<api_key>` is set in its
`config.xml`, it accepts every request without authentication and this step is
skipped — and so does everyone else who can reach it; see
[Running without a database](server-install.md#7-running-without-a-database).
With an `<api_key>` set, put that key in `cage.server.apiKey` instead.

## 6. First use

Click the **CAGE** icon in the activity bar to open the Chat panel.

**No logic graph ships with CAGE.** Before the first message, create one in the
Logic Editor — or import one — and pick it in the chat panel's Graph selector. A
message with no graph selected is answered with an error. The
[worked example](client/example-graph.md) is a complete graph, explained.

Command Palette entries:

| Command | Purpose |
|---|---|
| `CAGE: Open Chat` | Chat panel |
| `CAGE: New Session` | Start a fresh conversation |
| `CAGE: Open Logic Editor` | Visual editor for the logic graph that drives the agent |
| `CAGE: Rebuild Index` | Drop the project's retrieval index and embed every file again |
| `CAGE: Tools` | The tool table: built-in, your own, MCP programs, groups |
| `CAGE: Open Logic Debug` | Inspect a graph run |
| `CAGE: Login` / `Logout` | Account session |

Tool calls the model makes — reading and writing files, applying patches,
running terminal commands — execute in your editor and ask for approval first.
Approval behaviour is configurable:

| Setting | Default |
|---|---|
| `cage.toolApproval.mode` | `ask` |
| `cage.toolApproval.perTool` | `run_terminal`, `run_code`, `build_project`, `run_tests` → `ask`. `write_file` and `apply_patch` are not here — every file they touch is approved individually |
| `cage.fileAccess.scope` / `.outside` | `project` / `ask` — the file tools stay in the workspace (plus `cage.fileAccess.allowedPaths`) and ask, each time, before touching anything else. See [File Approval](client/file-approval.md#outside-the-project) |

## 7. Troubleshooting

| Symptom | Cause |
|---|---|
| Connection refused | Server not running, or `cage.server.port` does not match `<port>` in `config.xml` |
| Connection closes immediately when TLS is on | Server has no `<tls_cert>`/`<tls_key>`, or the certificate is self-signed and `tlsRejectUnauthorized` is still `true` |
| `401` / login rejected | The server and the control plane point at different databases, so the account is invisible to the server |
| Model list is empty | `<models>` in the server's `config.xml` is empty, or every `<path>` failed to scan — check the server log |

## 8. Uninstall

```bash
code --uninstall-extension real0000.cage
```

---

Next: the **[Client Guide](client/README.md)** — every panel and setting, and
the logic graph in detail.

Back to [server-install.md](server-install.md) · [Documentation index](README.md)
