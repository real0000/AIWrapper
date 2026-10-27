# Modality Configs

A modality config points at something that generates a file rather than text:
an image, speech, audio, music, motion or a 3D mesh. Speech recognition and
voice-activity detection go the other way, from a recording to text, and are
configured the same way.

**It lives in the same AI CONFIGS list as everything else.** Picking a model is
one decision, not two — the list is one section, generative entries are labelled
with their type (`image`, `tts`, …), and the Inspector's property sheet switches
to match whichever kind of model the config names. A [Send To AI](nodes.md#send-to-ai)
node picks it in the same **AI Config** dropdown as a text config.

The model dropdown lists both kinds. Choosing a generative model in a text
config — or the reverse — converts the config in place and keeps its name, so
every node already bound to it stays bound.

When a node runs a modality config, the model call becomes a generation call:
no tool loop, no retrieval, no structured output. The node's `ALL` pin carries
the resulting file paths, and its type changes to match the modality, so the
editor will only let you wire it somewhere that accepts that kind of file. For
`asr` and `vad` the result is text, and `ALL` is an ordinary text pin.

---

## Types

| Type | Produces |
|---|---|
| `image` | Images |
| `tts` | Spoken audio from text |
| `audio` | General audio |
| `music` | Music |
| `mesh` | 3D meshes |
| `motion` | Motion clips |
| `asr` | Text recognised from a recording |
| `vad` | The stretches of a recording that contain speech, as JSON segments |
| `separation` | Separate tracks split out of a recording |

A local config takes its type from the model. The server works out what each
model is at startup, and picking the model in the config sets the type, so
there is nothing to match up by hand.

## Local or remote

Local modality models are on the server's **VRAM ledger** alongside every other
model. A config can be limited to particular GPUs the same way a text config is;
leave that empty and the server picks a card with room. A modality model always
sits on a single card.

**Local** configs name an alias from the server's `config.xml`. The server
loads it in-process on first use, on the same backend the language models use.
All the generative types work this way; there is no separate service and no
Python.

| Field | Meaning |
|---|---|
| Modality Alias | The `<model alias="…">` entry on the server |

**Remote** configs call a hosted provider directly. Only `image` and `tts` are
available remotely, since those are the ones with standard endpoints.

| Field | Meaning |
|---|---|
| Provider | Which API shape and auth header to use |
| Remote URL | Endpoint base URL |
| API Key | Provider credential |
| Model | Meaning depends on the provider — see the table |

| Provider | Auth | Model field means |
|---|---|---|
| OpenAI | Bearer | Model name, e.g. `dall-e-3`, `tts-1` |
| Stability | Bearer | Endpoint variant: `core`, `sd3`, `ultra` |
| ElevenLabs | `xi-api-key` | Voice ID |
| Replicate | Token | `owner/name[:version]` |
| fal | Key | Model path, e.g. `fal-ai/fast-sdxl` |

## Generation parameters

**Defaults** holds the per-request knobs for this config — steps, guidance
scale, dimensions, whatever the underlying model exposes. They are the same
parameters the model's own interface offers.

Values sent by the node override these defaults, so a config can set sensible
values once while individual nodes vary the ones that matter.

## Using one in a graph

Point a [Send To AI](nodes.md#send-to-ai) node's AI Config at the modality
config. The prompt template works as usual — it becomes the generation prompt.
Input pins that the template does not reference are passed through as
generation parameters, which is how you drive things like a seed or a step count
from elsewhere in the graph.

Models that work on an existing file read it from an input pin with a fixed
name: `mesh` takes its picture from a pin named `image`, and `asr`, `vad` and
`separation` take their recording from a pin named `audio`. The pin can be an
asset pin, or a text pin holding a server-side path such as the `OutputFile` of
an earlier node.

`ALL` gives every produced file as a comma-joined list of server-side paths, or
the text when the model produced text and no file (`asr`, `vad`). An output pin
you name `OutputFile` carries the first file on its own, and the `Asset` output
carries the files as files, ready to wire into another node's asset input.

If an AI config and a modality config share a name, the AI config wins.

---

[← Logic Editor](logic-editor.md) · [AI Configs](ai-config.md) · [Client Guide](README.md)
