**English** · [繁體中文](mcp.zh-TW.md)

# MCP programs

An **MCP program** is a ready-made set of tools you attach. Attaching one is the
way to give the model a capability the product does not ship — web search, an
issue tracker, documentation lookup, a database — without changing the product.

Its tools join the same table as everything else and are configured the same way.
This page is only about the connection; for what you can then set on each tool,
see [Tools](tools.md).

Attach one with **+ Tools from an MCP program** on the Tools page
(**CAGE: Tools**), or by editing `cage.mcp.servers` in settings.

> The page does not use the word "server" for these. It is the term MCP itself
> uses for the thing at the other end of the connection, and it reads as if it
> were something you have to run and administer. You attach a program; its tools
> appear under its name.

---

## Attaching one

| Field | |
|---|---|
| **Name** | How its tools are prefixed: `mcp__<name>__<tool>`. Must be unique, and cannot be `built-in` or `cage-server` — those name the two sources that are always there |
| **Enabled** | A disabled program is not connected and its tools are not offered |
| **How to connect** | A child process over stdio, or Streamable HTTP |

For a child process: **command**, **args**, **env**, **cwd**.
For HTTP: **URL** and **headers**.

**List its tools** actually starts it and asks. What comes back is added to the
table under that program's heading, and stays listed between sessions — so you
can set them up before the next connection.

## In settings

```jsonc
"cage.mcp.servers": [
  {
    "name": "filesystem",
    "transport": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
  },
  {
    "name": "search",
    "transport": "stdio",
    "command": "/usr/local/bin/my-search-mcp",
    "env": { "API_KEY": "…" },
    "cwd": "/opt/search"
  },
  {
    "name": "docs",
    "transport": "http",
    "url": "https://example.internal/mcp",
    "headers": { "Authorization": "Bearer …" }
  }
]
```

`"disabled": true` keeps an entry without connecting it.

**Two transports: `stdio` and `http`.** `http` is Streamable HTTP — each JSON-RPC
message is POSTed to the URL. `sse` is reported as unsupported rather than
silently ignored.

## What happens on connection

The client connects each enabled program, asks it for its tool list, and declares
the combined list — built-in, yours, and every program's — to the CAGE server.
That declaration is filtered through the tool table first: a disabled tool is not
declared, and one with a custom description is declared with yours.

MCP connections live across turns and are reused. The declaration is sent on
every connection, so a change to the table takes effect on the next exchange.

**There is no request timeout.** A request ends when the reply arrives, when the
program exits (stdio), or when the connection drops (HTTP, noticed by TCP
keepalive). A tool that takes ten minutes is a tool that takes ten minutes.

## Approval

An MCP program's tools go through the same approval flow as everything else, and
are set in the same table — see [Tools](tools.md). They carry no preset risk
level, so they follow your default mode. A program you did not write is a good
reason to leave that at `ask`.

You can also give one **custom behaviour**: keep the name and parameters the
model sees, but run your own command line instead of calling the program.

## When something does not appear

- **The tool list is declared once per connection.** Attach a program, then start
  a new exchange for the model to see it.
- **Check it is enabled** — in the entry itself, and for the tool in the table.
  A tool that is off appears under *Not currently provided*.
- **A program that fails to start** is reported in the extension's output channel.
  **List its tools** is the quickest way to find out why.
- **The list the model actually received** is in the server's log.

---

[← Tools](tools.md) · [Settings](settings.md) · [Client Guide](README.md)
