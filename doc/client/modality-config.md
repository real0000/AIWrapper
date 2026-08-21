# Modality Configs

A modality config points at something that generates a file rather than text:
an image, speech, audio, music, or a 3D mesh.

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
editor will only let you wire it somewhere that accepts that kind of file.

---

## Types

| Type | Produces |
|---|---|
| `image` | Images |
| `tts` | Spoken audio from text |
| `audio` | General audio |
| `music` | Music |
| `mesh` | 3D meshes |

## Local or remote

Local modality workers are on the server's **VRAM ledger** alongside every other
model, and they select GPUs per device the same way a text config does — there
is no separate GPU whitelist to keep in step.

**Local** configs name an alias from the server's `config.xml`. The server
starts the corresponding Python worker on first use and talks to it over a
pipe. All five types work this way — the server does not care what a worker
produces.

| Field | Meaning |
|---|---|
| Modality Alias | The `<modality alias="…">` entry on the server |

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

`ALL` gives every produced file as a comma-joined list of server-side paths;
where a single file is expected, the first one is also available on its own pin.

If an AI config and a modality config share a name, the AI config wins.

---

[← Logic Editor](logic-editor.md) · [AI Configs](ai-config.md) · [Client Guide](README.md)
