# Chat Panel

The chat panel lives in the AIWrapper container in the activity bar. It is where
you talk to the agent, and where tool calls stop for your approval.

![The chat panel](../images/chat-panel.png)

Open it with the activity bar icon, or **AIWrapper: Open Chat** from the command
palette.

---

## Anatomy

| Area | What it is |
|---|---|
| Message list | The conversation. Answers stream in token by token |
| Input box | Your message. Enter sends, Shift+Enter adds a line |
| Graph selector | Which logic graph answers you — see [below](#the-two-selectors) |
| Start selector | Which entry point in that graph the run begins at |
| Settings | Opens the extension's settings — see [Settings](settings.md) |
| Session buttons (top right) | History panel, and new session |
| Status chip (status bar) | `AIWrapper: Idle` / `Connecting…` / `Generating` / an error |

## The two selectors

The pair of dropdowns at the bottom decides what actually runs.

**Graph** picks the workflow, and through it the logic graph. Six workflows ship
built in — Text / Code, Speech-to-Text, Image / UI / 2D, Text-to-Speech,
Music / Sound Effects, and 3D Model / Texture / Animation — and each binds to a
logic graph. Selecting one here is what tells the server which graph to execute
for your next message.

**Start** picks the entry point. A graph always has a `Default` Start node, and
may have more; each has a name. Choosing a different Start runs the same graph
from a different place — for example a "plan only" entry alongside the full
coding flow. See [Start](nodes.md#start).

A `↓` beside a graph name means the graph exists on the server but not yet in
this workspace; selecting it downloads it.

## Sessions

A session is one conversation with its own message history and its own
approval state.

- **New Session** clears the conversation and resets session-level tool
  approvals (see [Tools & Approval](tools.md)).
- Each completed exchange is saved to history automatically.
- The history panel lists past conversations grouped by date, with search and
  import/export. Its title is the opening words of your first message.

History is stored by VSCode on your machine, not on the server. The server keeps
its own session records for token accounting when it has a database.

## Tool approval

When the model asks to run a tool, the request appears inline in the
conversation with four choices: allow once, allow this tool for the session,
allow everything for the session, or deny. Approval is covered in
[Tools & Approval](tools.md).

## Reviewing changes

File changes are not written as they happen — they collect in a staging area,
and at the end of a run the panel lists them with their diffs so you can accept
all, reject all, or pick file by file. See [Staging & Flush](staging.md).

## Interim steps

A graph often makes several model calls before it produces the answer you asked
for. Those intermediate messages are collapsed into a **Steps** block you can
expand, so a long tool-calling run does not bury the actual reply.

## Connection behaviour

The client does not hold a socket open. It connects when you send a message,
stays connected for the whole exchange including file transfers, and disconnects
when the exchange ends. A dropped connection during a run surfaces on the status
chip and in the panel.

---

Next: [Logic Editor](logic-editor.md) · [Tools & Approval](tools.md) · [Settings](settings.md)

[← Client Guide](README.md)
