# File Approval

`write_file` and `apply_patch` write straight into your workspace — but not
before you approve the individual file they are about to touch. One file, one
question, asked at the moment of writing.

There is no staging area and no batch review at the end. The file is either on
disk when the tool returns, or it was declined and the model is told so.

---

## What you see

Each pending write appears in the chat panel as its own card:

| | |
|---|---|
| Path | Relative to the workspace root |
| Kind | Write, patch, or delete |
| Size | Bytes the file will be after the write |
| Diff | Unified diff against what is on disk now, syntax-coloured. Empty for a delete or a binary file |

Approve it and the tool writes, then reports the file is on disk. Decline it and
nothing is written; the model is told it was declined, in as many words, and
carries on.

## One question at a time

Approvals are **serialised**. Only one request waits on you at any moment; the
rest queue in arrival order, and tool calls that arrive meanwhile are held until
you have answered the one in front.

This matters more than it sounds. An `apply_patch` touching five files asks five
times, each with that file's own diff — without serialisation you would get five
simultaneous cards with no way to tell which belonged to which. Models also emit
two tool calls milliseconds apart, and those queue rather than race.

File approvals and [tool approvals](tools.md) share the one queue, so a
`run_terminal` request cannot jump ahead of a write you are still deciding on.

## Where files go

Always your workspace root. The server does not decide where files land — the
path comes from the client, and every write is checked to be inside the
workspace before you are even asked.

## Why it works this way

An earlier design accumulated writes in a per-session staging area and asked you
to flush them as a batch. It failed three ways in practice:

- The model was told its file was *staged, not yet on disk*, so it rewrote the
  same file repeatedly trying to make it stick — and sometimes resorted to shell
  heredocs to get around the tool entirely.
- A turn that never ran a terminal command left every write suspended. The run
  finished and nothing had happened.
- When the prompt did come, it asked you to review a pile of unrelated files at
  once.

Immediate, per-file approval costs more clicks and removes all three failures.
The model's picture of the workspace is now simply true.

## Working with it

- **Turning `run_terminal` down does not affect this.** File approval is not a
  tool-approval mode; there is no setting that makes writes automatic.
- **Declining is cheap.** The model is told and can propose something else. It
  is not an error and does not end the run.
- **`run_terminal` remains the one that reaches outside.** It runs a real
  command on your machine, which can touch paths no file gate sees. That is why
  it defaults to `ask`.

---

[← Tools & Approval](tools.md) · [Chat Panel](chat-panel.md) · [Client Guide](README.md)
