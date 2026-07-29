# Format Configs

A format config describes a shape a string is supposed to have. It does two
jobs, and it is worth keeping them apart:

- On a [Send To AI](nodes.md#send-to-ai) node it becomes **structured output** —
  the model is constrained to answer in that shape.
- On a [Check Format](nodes.md#check-format) node it becomes **validation** —
  a string is tested against the shape and the graph branches on the result.

The same config can do both, which is the usual pattern: ask for a shape, then
verify you got it.

---

## Types

| Type | Passes when |
|---|---|
| `json` | The string parses as valid JSON |
| `json_keys` | It parses as a JSON object and contains every required field |
| `regex` | It matches the pattern |
| `non_empty` | It is not blank |

## Fields (`json_keys`)

For `json_keys` you list the fields the object should have:

| Field property | Used for |
|---|---|
| Key | The property name in the JSON object |
| Description | Told to the model when this config drives structured output |
| Required | Whether [Check Format](nodes.md#check-format) fails if it is missing |

Descriptions matter more than they look. Under structured output they are the
only explanation the model gets of what each key means, so "one-sentence summary
of what changed" produces something quite different from "summary".

## Split outputs

When a `json_keys` config is set on a Send To AI node, you can add output pins
named after the keys. The answer arrives already split — each key on its own
pin — instead of one JSON blob you have to take apart downstream.

## Validate and retry

The standard arrangement:

```
Send To AI ──► Check Format ──True──► carry on
                    │
                    └──False──► back to Send To AI
```

The `False` branch feeds the model call again, so a malformed answer costs a
retry instead of breaking the run. Give the node a **custom error message** when
the default is not specific enough to help the model correct itself.

Keep an eye on the retry path: wire it back through a [Variable](variables.md)
counter and an [If](nodes.md#if) node if you want a bounded number of attempts
rather than a loop that can spin.

---

[← Logic Editor](logic-editor.md) · [Nodes](nodes.md) · [Client Guide](README.md)
