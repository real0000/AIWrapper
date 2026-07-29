# Settings

Every setting the extension contributes, as it appears under `aiwrapper.*` in
VSCode settings. Search `aiwrapper` in the settings UI, or edit `settings.json`
directly.

![The extension's settings](../images/settings.png)

---

## Server connection

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.server.host` | `localhost` | Hostname only — no `http://` or `ws://`. The protocol comes from `tls` |
| `aiwrapper.server.port` | `15963` | Must match `<port>` in the server's `config.xml` |
| `aiwrapper.server.tls` | `false` | Use `https://` / `wss://`. The server needs a certificate configured |
| `aiwrapper.server.tlsRejectUnauthorized` | `true` | Verify the certificate. `false` accepts self-signed ones — still encrypted, no longer protected against interception |
| `aiwrapper.server.apiKey` | empty | Bearer token. Prefer **AIWrapper: Login**, which manages this for you |
| `aiwrapper.server.connectMaxAttempts` | 3 | Connection attempts before reporting failure |
| `aiwrapper.server.connectRetryDelayMs` | 1000 | Delay between attempts |

## Tool approval

See [Tools & Approval](tools.md).

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.toolApproval.mode` | `ask` | Default mode: `ask`, `auto`, `deny` |
| `aiwrapper.toolApproval.perTool` | `run_terminal`, `write_file`, `build_project` → `ask` | Per-tool overrides |
| `aiwrapper.toolApproval.timeoutSeconds` | 30 | Wait before a request lapses. `0` waits forever |

## Tool execution

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.tool.outputThresholdKB` | 128 | Output past this is uploaded as a file instead of inlined |
| `aiwrapper.tool.commandTimeoutMs` | 120000 | Command timeout (2 minutes) |

## Build and test

Used by `build_project` and `run_tests`.

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.build.timeoutMs` | 600000 | Build/test timeout (10 minutes) |
| `aiwrapper.build.cmake.buildDir` | `build` | CMake build directory |
| `aiwrapper.build.cmake.buildType` | `Debug` | CMake build type |
| `aiwrapper.build.cmake.configureArgs` | empty | Extra configure arguments |
| `aiwrapper.build.node.packageManager` | `auto` | `auto` detects from the lockfile |
| `aiwrapper.build.node.buildScript` | `build` | Script for `build_project`; falls back to `tsc --noEmit` |
| `aiwrapper.build.node.testScript` | `test` | Script for `run_tests` |
| `aiwrapper.build.cargo.release` | `false` | Build with `--release` |
| `aiwrapper.build.go.buildArgs` | empty | Extra `go build` arguments |
| `aiwrapper.build.make.target` | empty | Make target; empty uses the default goal |
| `aiwrapper.build.make.testTarget` | `test` | Make target for tests |
| `aiwrapper.build.unity.editorPath` | empty | Unity Editor executable |
| `aiwrapper.build.unity.buildTarget` | `StandaloneWindows64` | Unity build target |
| `aiwrapper.build.unity.testPlatform` | `EditMode` | Unity test platform |
| `aiwrapper.build.unreal.enginePath` | empty | Unreal Engine installation |

## Indexing

See [Project Indexing](indexing.md).

| Setting | Default |
|---|---|
| `aiwrapper.index.enabled` | `true` |
| `aiwrapper.index.excludePatterns` | `**/node_modules/**`, `**/.git/**`, `**/build/**`, `**/dist/**` |
| `aiwrapper.index.maxDepth` | 8 |
| `aiwrapper.index.debounceMs` | 2000 |
| `aiwrapper.index.deltaFullThreshold` | 0.4 |

## Workflow

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.workflow.enabled` | `true` | Turn the workflow subsystem off |
| `aiwrapper.workflow.defaultId` | `text_code` | Workflow selected on a fresh workspace |
| `aiwrapper.workflow.judgeMaxTokens` | 200 | Token cap for the model calls that judge whether a workflow applies and whether it is finished |

## MCP

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.mcp.servers` | `[]` | Third-party MCP servers — see [MCP Servers](mcp.md) |

## Native acceleration

Optional. Routes some work to a compiled sidecar; off by default.

| Setting | Default | Meaning |
|---|---|---|
| `aiwrapper.native.enabled` | `false` | Master switch. Off means everything uses the TypeScript path |
| `aiwrapper.native.modules` | `[]` | Which modules to route, e.g. `["diff"]` |
| `aiwrapper.native.binaryPath` | empty | Explicit sidecar path; empty auto-resolves |

## Commands

| Command | Purpose |
|---|---|
| `AIWrapper: Open Chat` | Open the [chat panel](chat-panel.md) |
| `AIWrapper: New Session` | Start a fresh conversation and reset session approvals |
| `AIWrapper: Open Logic Editor` | Open the [Logic Editor](logic-editor.md) |
| `AIWrapper: Open Logic Debug` | Inspect a graph run node by node |
| `AIWrapper: Rebuild Index` | Force a full re-index |
| `AIWrapper: Manage MCP Servers` | Add or remove [MCP servers](mcp.md) |
| `AIWrapper: Login` / `Logout` | Sign in to a server that has accounts |

---

[← Client Guide](README.md)
