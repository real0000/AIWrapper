# Variables

Variables are named state that belongs to the graph rather than to any one node.
They exist for exactly one run: the server initialises each to its default value
when the run starts, and discards them when it ends.

They are declared in the **VARIABLES** section of the Logic Editor sidebar and
used by [Variable](nodes.md#variable) nodes, [If](nodes.md#if) cases, and
`{{name}}` placeholders in [Compose](nodes.md#compose) templates.

---

## Declaring one

| Field | Meaning |
|---|---|
| Name | How nodes refer to it |
| Type | `string`, `number`, `bool`, or `enum` |
| Default Value | The value at the start of every run |
| Description | What it is for |
| Enum Values | The allowed list, when the type is `enum` |

Values are stored as strings at runtime. The type decides what `add` means and
which comparison operators [If](nodes.md#if) offers.

## Writing

A [Variable](nodes.md#variable) node writes them. Each item picks a target, an
operation and a source:

| Operation | `string` | `number` | `bool` |
|---|---|---|---|
| `set` | replace | replace | replace |
| `add` | concatenate | sum | logical OR |

Sources are a constant, an input pin on the node, or another variable. Writes go
through an atomic read-modify-write, so a counter incremented from two branches
running in parallel does not lose an update.

## Reading

Two ways.

**Getter pins.** Add an output pin to a Variable node whose name matches a
variable. Downstream nodes read straight from it, with no exec wire — the value
is pulled when the reader runs, so it is the value at that moment, not the value
when some earlier node happened to execute. This is the normal way to feed a
variable into a prompt.

**Directly.** [Compose](nodes.md#compose) templates take `{{variableName}}`, and
[If](nodes.md#if) cases can name a variable as their comparison source.

## What they are good for

- **Counters.** A retry counter incremented on the `False` branch of a
  [Check Format](nodes.md#check-format) node, checked by an [If](nodes.md#if)
  before looping again — this is how you bound a retry loop.
- **Accumulators.** A work log that each pass appends to, rendered into the
  final report by a [Compose](nodes.md#compose) node.
- **Mode flags.** An enum set near the start that later `If` nodes branch on, so
  one graph serves "plan only" and "plan and build".
- **Carrying values across a fan-out.** Values written inside a
  [Dispatch](nodes.md#dispatch) subgraph are visible after it finishes, which is
  how per-task results get collected.

---

[← Logic Editor](logic-editor.md) · [Nodes](nodes.md) · [Client Guide](README.md)
