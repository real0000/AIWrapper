# Staging & Flush

File-changing tool calls do not touch your workspace. They accumulate in a
per-session **staging area**, and the changes reach disk only when you commit
them — all at once, or file by file.

This is the safety model that lets `write_file` and `apply_patch` run without
asking permission every time: nothing they do is destructive until you say so.

---

## What is staged

| Tool | Effect |
|---|---|
| `write_file` | Stages a write. The reply says so explicitly: *staged, not yet on disk* |
| `apply_patch` | Applies the patch to the staged copy if there is one, otherwise to the file on disk, and stages the result |
| `run_terminal` | Runs inside a temporary shadow copy of the workspace; any files it changes are captured into staging |
| `read_file` | Reads from disk, then appends a unified diff of the staged version, so the model always sees the current state |

Because `apply_patch` reads through the staged copy, several patches to the same
file stack correctly instead of fighting each other.

## Committing

When the run reaches its end, the server checks whether anything is staged. If
so, it asks — and the client shows the staged files with their diffs:

| Choice | Effect |
|---|---|
| Accept all | Every staged change is written to disk |
| Reject all | Everything is discarded |
| Per file | Pick individually; the ones you skip are dropped |

Rejected changes are gone, not deferred. The session's staging area is cleared
either way.

The server can also ask mid-run, or discard the staging area outright when it
abandons a plan — for example when a graph decides an approach was wrong and
backs out.

## Surviving restarts

Staging is stored under the extension's storage directory, keyed by session, so
an unflushed session survives a VSCode restart or a crash. Reopening the session
finds the staged work still there.

## The model knows what is staged

Every [Send To AI](nodes.md#send-to-ai) node has a summary of the currently
staged files prepended to its prompt, so a later node knows what an earlier one
already wrote. There is also a server-side tool for listing staged paths without
pulling every diff into the context window.

This matters in multi-step graphs: a reviewer node can see that the coder node
produced three files without those files being pasted into its prompt.

## Working with it

- **Review at the end, not per call.** The point is to see the whole change set
  in one place. Leaving `write_file` on automatic approval is the intended
  configuration, not a shortcut.
- **A rejected flush loses the work.** If a run produced something you half
  want, take the files you want individually rather than rejecting everything.
- **`run_terminal` is the leaky one.** Its file changes are captured, but the
  command itself really ran — it can reach the network, install packages, or
  touch paths outside the workspace. That is why it stays on `ask`.

---

[← Tools & Approval](tools.md) · [Chat Panel](chat-panel.md) · [Client Guide](README.md)
