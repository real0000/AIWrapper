# MCP Servers

Every tool the model can see arrives over MCP. The server keeps no fixed tool
list of its own — what a model is offered is exactly what the connected client
declares. That includes the built-in tools, and it means adding a capability is
a matter of attaching a server rather than changing the product.

Manage them with **CAGE: Manage MCP Servers**, or by editing
`cage.mcp.servers` in settings.

![The MCP servers page](../images/mcp-tools.png)

*The MCP page. Third-party servers are configured at the top; the built-in tools
are listed read-only below, exactly as the model receives them.*

---

## Where tools come from

| Source | Named | Why it lives there |
|---|---|---|
| The client itself | plain (`read_file`, `apply_patch`, …) | Needs the editor: your workspace, your selection, your terminal |
| The server | plain (`run_code`, `list_staged`, …) | Needs the server's sandbox and its per-session staging area |
| Third-party MCP servers | `mcp__<server>__<tool>` | Yours to add. The prefix marks them as external |

The prefix is also how a call is routed back to the right server.

## Adding a server

Each entry needs a name, a command, and optionally arguments and environment:

```jsonc
"cage.mcp.servers": [
  {
    "name": "filesystem",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
  },
  {
    "name": "search",
    "command": "/usr/local/bin/my-search-mcp",
    "args": [],
    "env": { "API_KEY": "…" }
  }
]
```

Servers are launched as child processes and spoken to over stdio. The client
connects on startup, asks each one for its tool list, and forwards the combined
list to the CAGE server.

**Only stdio transport is supported.** SSE and streamable-HTTP entries are
rejected rather than silently ignored.

## Approval

Third-party tools go through the same approval flow as the built-in ones — see
[Tools & Approval](tools.md). They have no preset risk level, so they follow
your default mode. A server you did not write is a good reason to leave the
default at `ask`.

## Capabilities worth attaching

The product ships no web search on purpose — that kind of stateless capability
is exactly what MCP is for. Web search, issue trackers, documentation lookup and
database access are all things to attach rather than build in.

## When something does not appear

- The client sends its tool list once per connection. Add a server, then start a
  new exchange for the model to see it.
- A server that fails to start is reported in the extension's output channel.
- The tool list the model actually received is visible in the server's log.

---

[← Tools & Approval](tools.md) · [Settings](settings.md) · [Client Guide](README.md)
