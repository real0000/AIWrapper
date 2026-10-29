# Settings

Every setting the extension contributes, as it appears under `cage.*` in
VSCode settings. Search `cage` in the settings UI, or edit `settings.json`
directly.

![The extension's settings](../images/settings.png)

---

## Server connection

| Setting | Default | Meaning |
|---|---|---|
| `cage.server.host` | `localhost` | Hostname only — no `http://` or `ws://`. The protocol comes from `tls` |
| `cage.server.port` | `15963` | Must match `<port>` in the server's `config.xml` |
| `cage.server.tls` | `false` | Use `https://` / `wss://`. The server needs a certificate configured |
| `cage.server.tlsRejectUnauthorized` | `true` | Verify the certificate. `false` accepts self-signed ones — still encrypted, no longer protected against interception |
| `cage.server.apiKey` | empty | Bearer token. Prefer **CAGE: Login**, which manages this for you |
| `cage.server.connectRetryDelayMs` | 1000 | Delay between attempts |

## Tool approval

See [Tools](tools.md).

| Setting | Default | Meaning |
|---|---|---|
| `cage.toolApproval.mode` | `ask` | Default mode: `ask`, `auto`, `deny` |
| `cage.toolApproval.perTool` | `run_terminal`, `run_code`, `build_project`, `run_tests` → `ask` | Per-tool overrides. `write_file` and `apply_patch` are absent because they do not use this setting: every file is approved individually before it is written — see [File Approval](file-approval.md) |

## Build and test

Used by `build_project` and `run_tests`.

| Setting | Default | Meaning |
|---|---|---|
| `cage.build.cmake.buildDir` | `build` | CMake build directory |
| `cage.build.cmake.buildType` | `Debug` | CMake build type |
| `cage.build.cmake.configureArgs` | empty | Extra configure arguments |
| `cage.build.node.packageManager` | `auto` | `auto` detects from the lockfile |
| `cage.build.node.buildScript` | `build` | Script for `build_project`; falls back to `tsc --noEmit` |
| `cage.build.node.testScript` | `test` | Script for `run_tests` |
| `cage.build.cargo.release` | `false` | Build with `--release` |
| `cage.build.go.buildArgs` | empty | Extra `go build` arguments |
| `cage.build.make.target` | empty | Make target; empty uses the default goal |
| `cage.build.make.testTarget` | `test` | Make target for tests |
| `cage.build.unity.editorPath` | empty | Unity Editor executable |
| `cage.build.unity.buildTarget` | `StandaloneWindows64` | Unity build target |
| `cage.build.unity.testPlatform` | `EditMode` | Unity test platform |
| `cage.build.unreal.enginePath` | empty | Unreal Engine installation |

## Indexing

See [Project Indexing](indexing.md).

| Setting | Default |
|---|---|
| `cage.index.enabled` | `true` |
| `cage.index.excludePatterns` | `**/node_modules/**`, `**/.git/**`, `**/build/**`, `**/dist/**` |
| `cage.index.debounceMs` | 2000 |
| `cage.index.deltaFullThreshold` | 0.4 |

## Tools

| Setting | Default | Meaning |
|---|---|---|
| `cage.mcp.tools` | `[]` | Every row of the tool table — the defaults and each group's differences. Written by the Tools page |
| `cage.mcp.activeGroup` | `""` | Which tool group is active. `""` = defaults only |
| `cage.mcp.servers` | `[]` | The [MCP programs](mcp.md) you attached |

## Native acceleration

Routes some work to a compiled sidecar. The released extension does not include
the sidecar, so unless you build one and point `binaryPath` at it, every module
falls back to the TypeScript path whatever these say.

| Setting | Default | Meaning |
|---|---|---|
| `cage.native.enabled` | `true` | Master switch. Off means everything uses the TypeScript path |
| `cage.native.modules` | `["logic"]` | Which modules to route. Known: `diff`, `patch`, `buildparse`, `transport`, `logic` |
| `cage.native.binaryPath` | empty | Explicit sidecar path; empty auto-resolves |

## Commands

| Command | Purpose |
|---|---|
| `CAGE: Open Chat` | Open the [chat panel](chat-panel.md) |
| `CAGE: New Session` | Start a fresh conversation and reset session approvals |
| `CAGE: Open Logic Editor` | Open the [Logic Editor](logic-editor.md) |
| `CAGE: Open Logic Debug` | Inspect a graph run node by node |
| `CAGE: Rebuild Index` | Drop this project's retrieval index on the server and embed every file again |
| `CAGE: Tools` | The [tool table](tools.md) — built-in, your own, MCP programs, groups |
| `CAGE: Switch Tool Group` | Switch the active [tool group](tools.md#groups) |
| `CAGE: Open Memory` | The project [routing table](memory.md) |
| `CAGE: Resume Interrupted Run` | Continue the previous turn |
| `CAGE: Login` / `Logout` | Sign in to a server that has accounts |

---

[← Client Guide](README.md)
