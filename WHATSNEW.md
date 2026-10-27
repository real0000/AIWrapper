# What's New in CAGE 0.2.0

0.2.0 is two months of work and has no single theme, but four changes shape it:

- **There is no Python anywhere.** Hugging Face safetensors models are read
  directly, and image, speech, music, motion and 3D models run inside the server
  process. Nothing to install, no environments, no worker processes.
- **Models say what they are.** You point the config at a folder; the server works
  out whether it is a chat model, an embedding model or an image generator. The
  separate `<modalities>` list is gone.
- **More hardware.** A backend pack for Pascal — the Tesla P40 in particular — and
  packs can now be installed side by side, so a P40 can sit next to your main
  cards.
- **Memory that follows the conversation.** Every step's report goes into a
  session record that the next attempt in a loop can read, and a small model —
  not a fixed rule — chooses which notes each step reads.

It is a **breaking release for backend packs and for `config.xml`**. See below.

---

## Before you upgrade

| What changed | What you have to do |
|---|---|
| Backend packs are rebuilt for this server | **Re-download the backend pack(s) for your GPUs.** A 0.1.x pack is refused at load time. |
| Each pack's library is now named after the pack (`libcage-backend-cuda-sm70_sm75.so`) | **Delete `bin/libcage-backend-cuda.so` and `bin/libcage-backend-hip.so`** if they are left from 0.1.x. The new pack no longer overwrites them. They are refused anyway, but they stay in the probe's report until removed. |
| `<modalities>` merged into `<models>` | **Move every `<modality>` entry into `<models>` as a `<model>`, and rename `<model_path>` to `<path>`.** The server refuses to start while a `<modalities>` block is present, and says so. |
| `<type>`, `<family>`, the `backend=` attribute, `<ai><default_backend>`, `<ai><cuda_visible_devices>`, `<ai><default_vision_model>`, `<vision handler="…">`, `<task_planning_enabled>`, and `<compressor>`'s `base_url`, `model` and `*_compress_tokens` are no longer read | Nothing — they are ignored. Delete them when convenient. |
| Python is not used | Nothing. Any `<vllm>` or `<convert>` block is ignored, and the Python environments of 0.1.x can be deleted. |
| One new database table (`runs`, for resuming interrupted runs) | Nothing — the server creates it at startup. |
| The extension and the server exchange tool settings in a new way | **Update the extension to 0.2.0** together with the server. |
| The installer is now `install.ps1`, a PowerShell script | **Install PowerShell 7.4 or newer and run `pwsh ./install.ps1`.** The options are the ones `install.sh` had. |
| File history is read only when the memory AI picks it | **Set a Memory AI Config on your graphs** if you rely on file history. Without one, a file's history is no longer read just because the message names the file. |
| A session record is written to `.cage/sessions/` in your project | Add `.cage/sessions/` to `.gitignore` if you do not want it committed. |
| Retrieval cuts files into chunks differently | Nothing — each project's index is rebuilt once, the first time the project is opened. For a large project that takes as long as its first indexing did. |
| Upgrading straight from AIWrapper 0.1.0: the database and its account were renamed in 0.1.1 | **Edit `sql/migrate-aiwrapper-to-cage.sql`** — replace `CHANGE-ME` with the password in `<mysql><password>` — **and run it as a database administrator before starting the new server.** |

---

## No Python, anywhere

0.1.x needed Python for two things: converting a safetensors model to GGUF before
it could be loaded, and running every image, speech and 3D model in a worker
process. Both are gone.

- **Safetensors are read in place.** The backend builds the tensor table from
  `config.json`, `tokenizer.json` and the shards directly, in memory, and writes
  no intermediate file. The quantization you pick on the AI config is applied
  while loading, using the same per-tensor rules as offline quantization — so a
  safetensors model loaded at `4bit` is byte-for-byte the tensors a `4bit` GGUF
  of it would contain.
- **Image, speech, music, motion and 3D run in-process,** on the same GPU
  context and the same VRAM budget as the language models. A busy image model is
  visible to the loader deciding whether a chat model fits, and can be evicted by
  it.

## Models say what they are

Every `<model>` entry is just a folder and, optionally, a licence. At startup the
server asks each model what it is — every adapter in the backend pack is handed
the path and answers whether those weights are its own and what it can do. The
test lives in the code that understands the format, so there is no table of model
names to fall out of date.

`<type>` and `<family>` used to be declarations. They are not read any more, and
that is deliberate: a declaration that is wrong has nothing to contradict it, and
one entry in our own test configuration had been carrying `<family>sd</family>`
for months while the probe had never once recognised that model. It worked only
because of the declaration — which also hid the bug.

Two more things that used to reach the model list and fail when chosen are now
caught at startup, with the reason in the log: weights whose architecture the
backend has no graph for (3D and image generators ship as GGUF too), and
directories whose only weights are `.pt` / `.bin` pickles, which nothing in CAGE
reads.

## A backend pack for the P40, and packs side by side

New: `cage-backend-cuda-sm60_sm61`, covering the Pascal generation — P40, P100,
P4 and the GTX 10xx cards.

A P40 is 24 GB for very little money, and its natural job is **the embedding
model behind retrieval, or the summariser behind shared memory**, rather than the
chat model. Its FP16 runs at 1/64 of FP32 and it has no tensor cores; the kernels
know both and keep it on its FP32 and INT8 paths.

A P40 is usually a second card next to newer ones, which means two packs at once.
That works now: each pack's library is named after the pack, they sit side by side
in `bin/`, and each AI config is served by whichever pack drives the GPUs it
selected. There is nothing to configure beyond choosing the P40 on the AI config
that should use it.

**Verified:** the Pascal pack loads, identifies itself, and correctly refuses
every non-Pascal card. Installed next to the V100 pack, both load, each takes only
its own cards, and the V100 pack answered prompts from that two-pack install.
**Not verified:** a P40 actually running a model — there was none to test on. A
report from a P40 owner is the most useful one this release could get.

## Hybrid Mamba2 models: Nemotron-3-Ultra

NVIDIA-Nemotron-3-Ultra-550B-A55B now runs. It is a hybrid: of its 108 layers, 12
are attention, 48 are mixture-of-experts and 48 are Mamba2 state-space layers, and
it needed a new state-space operation (with a CUDA kernel) because the existing one
could not express Mamba2's grouped form.

**Measured:** correct answers at temperature 0 on four V100s, with the 512 experts
in host memory, at 2.8 tokens/s. That speed is set by the experts running on the
CPU — the state-space scan itself is about 0.2% of the work.

## Stopping and resuming a run

- **Stop takes effect within milliseconds.** Pressing Stop on a local model used
  to take 80 to 115 seconds to take effect, because the cancel signal never
  reached the generation loop — the node only noticed after the whole generation
  had finished. **Measured:** 7 to 13 ms, on one V100 and across two; the whole run
  is cleaned up in 155 ms. The exception is a long prompt on a large model: a stop
  pressed while the prompt is still being read waits for that to finish, which
  can take seconds.
- **An interrupted run can be resumed** from the last node boundary, whether it
  was stopped by you, by a dropped connection, or by the server going down. A node
  that failed outright is not offered for resuming; running it again unchanged
  would fail the same way.

## Faster decoding with MTP

Models that ship multi-token-prediction heads can use them for speculative
decoding — a switch on the AI config. Where the heads are published separately,
as with Qwen3.8-Flash-Next, the file only has to be in the model's folder.
**Measured:** Qwen3.8-Flash-Next is about 1.7× faster with 93% of drafted tokens
accepted.

## Context length is decided per model

Whether a model's context can be extended, and by how much, now comes from the
model: its architecture (some apply position scaling only to windowed layers, some
not at all) and the limit its model card states. A model whose card says nothing is
not extended. When no length is chosen, the default is **32K**.

## Presence penalty

The AI config has a new sampling field, **Presence Penalty**: every token that
already appears in the reply — the reasoning included — is made less likely,
once, however often it appeared. Model cards for reasoning models recommend it
against thinking that goes round in circles; Qwen3.6's, for example, recommends
1.5 for thinking on general tasks. It is `0`, off, unless you set it. See
[AI configs](doc/client/ai-config.md#sampling).

## One Tools page

The MCP page became **Tools**: one table of everything the model can call — built-in
tools, tools you define yourself, the server's own `run_code`, and the tools of each
MCP program — grouped by where they come from. Every tool can be switched off or
re-described; a **group** is a set of those settings you can switch as a whole. You
can add a tool of your own with a name, a description, a parameter table and one
command line. MCP requests no longer have a timeout.

## Memory that follows the conversation

A graph that loops — a coder and a build check, say — used to start every
attempt from nothing. In one test the coder ran three times and re-checked the
same build environment each time, although its first summary already said what
it had found; that summary had nowhere to go.

- **The session record.** After each Send To AI step the server appends the
  step's Summary to `.cage/sessions/<session id>.md` in your project, with the
  files it wrote. When the message's run ends, the memory AI condenses that part
  into a short list for the next message. Nothing is truncated.
- **The memory AI chooses what to read.** Before a step runs it is shown every
  rule row, every file history in the project and the session record, together
  with the work at hand, and picks what bears on it. Whether the message happens
  to name a file no longer decides whether its history is read.
- **A conversation keeps its session across a server restart.** The session id
  belongs to the conversation in your editor; only a new chat, or a server that
  says it has no such session, starts a new one. The record follows it.

**Tested** against the packaged server with a scripted model standing in for the
LLM: a looping step reads its previous attempt's report, the record is condensed
before the run reports done, a new chat is isolated, and a session is recalled
from the database after a restart. **Not yet run** with a real model through a
whole graph. See [Project memory](doc/client/memory.md).

## Models that need someone else's weights

Some models name parts of themselves by another repository — TRELLIS.2 points at
a DINOv3 feature extractor, a background remover and a decoder from TRELLIS v1.
The downloader now fetches those along with the model, into the model's own
`components/` folder, and the loader finds them there. No paths to write into the
config. One such part — TRELLIS's background remover, whose licence forbids
commercial use — is replaced by an equivalent under MIT, and the reason is
recorded with it.

---

## Fixes worth naming

- **A native install could not run local models**, for three reasons, each
  enough on its own. The installer never copied `lib/`, so on a machine without
  CUDA installed the server did not start and no pack loaded. The server looked
  for backend packs only in its working directory, which under the agent — and
  in Docker — is the install directory, not `bin/`. And the CUDA packs lacked
  `libcufft`, which they have needed since speech models came in-process. The
  build machine has CUDA installed system-wide and the tests started the server
  from `bin/`, which hid all three. All three are fixed. The install was re-run
  exactly as the guide describes and answered a prompt through the agent, and in
  a container with no CUDA at all every library the server and the CUDA packs
  need now resolves, except the driver's own `libcuda.so.1`.
- **The Docker setup did not build.** The compose files still named the 0.1.1
  package, the image build stopped at a `chmod` of an installer that is no longer
  a shell script, and the seeded `config.xml` did not parse — the template had a
  comment inside a comment. Fixed, and the quick start was run as written: the
  stack comes up and a model answers on the GPU.
- **Tool calls in two sessions at once could cross.** Stop, or a dropped
  connection, in one session cancelled the tool calls every other session was
  waiting on, and two sessions given the same call id could swap results or wait
  forever. Waiting calls are now kept per session.
- **A fast tool reply could hang the turn.** The server sent the call before it
  was ready for the answer, so a client that answered at once had its reply
  dropped.
- **The Linux AMD packs had not compiled since September.** Two CUDA names — one
  in pinned-memory registration, one in out-of-memory reporting — had no ROCm
  equivalent declared. The Windows AMD build happened not to reach either, which
  is how it went unnoticed; nobody had built a Linux one since August.
- **Running out of VRAM** no longer reports a failed computation as success, no
  longer aborts in two places, and no longer places the output layer on a card
  that was not selected.
- **Stopping the agent left the server running.** The agent had no handler for
  SIGINT or SIGTERM, so stopping it ended the agent at once and left the server
  it had started behind, still holding its port and its VRAM. The agent now stops
  the server and waits for it to unload its models before exiting.
- **Speech recognition and motion configs turned into `image`.** The editor knew
  five modality types; a config of any other type the server reports was
  rewritten as `image` when the graph loaded again. It now knows all of them —
  speech recognition, voice-activity detection, source separation and motion are
  new. Three server-side faults on the same path are fixed as well: the text a
  speech-recognition model returned never reached the node's output;
  voice-activity detection, which returns only time segments, was always
  reported as having produced nothing; and music generation from a graph was
  refused because the prompt was not passed to the model as its text. The
  editor's part is covered by its tests. The three server-side fixes have **not
  yet run** with a real speech-recognition, voice-activity or music model.
- **Tool calls from Qwen3.5, 3.6 and 3.8 could vanish.** These models sometimes
  write a tool call inside their reasoning without closing it first. The parser
  took only `</think>` as the end of reasoning, so the call was filed as
  reasoning, the step reported no call, and a graph moved on as if the step were
  done — in one run, forty minutes of a coder's work ended without the file it
  was about to write. A tool call now ends the reasoning, as in upstream
  llama.cpp (#26252), vLLM and Ollama. The same change accepts a call whose
  required arguments come in a different order than declared, which used to fail
  to parse. Every backend pack is rebuilt with it.
- **The worked example's coder could think for forty minutes before writing
  anything.** Its rules said the program's output was the point and that it must
  not run anything, and nothing said the verifier produces that output. A coder
  that stopped to reconcile the two weighed hand-writing a binary image and
  rewrote the whole program in its reasoning before its first tool call. One rule
  now says the deliverables come from the verifier's run. If you built DemoCoder
  from the [worked example](doc/client/example-graph.md), add it to your coder's
  prompt.
- **Retrieval handed steps the session record behind the memory AI's back.**
  `.cage/` was indexed like any other folder, so the session record and file
  histories came back as retrieved excerpts — in one run, a verifier was given
  earlier attempts' reports while the log said the memory AI had chosen not to
  read the record. `.cage/` is no longer indexed, and an existing index drops it
  the next time the project is opened.
- **Small files were indexed one line at a time.** The chunker made one chunk
  per top-level definition and never joined them, so a `CMakeLists.txt` became
  one chunk per command — four of that verifier's five excerpts were single lines
  of one — and `#include` lines, top-level comments and globals in C and C++
  were not indexed at all. Neighbouring top-level content is now gathered into
  chunks of up to 4000 bytes, never cut inside a definition.
- **Server messages are in English.** Log lines, errors, and the placement
  reasons the Logic Editor's console shows were partly in Chinese.
- **The control plane caught up with the merged model list.** Its Models tab
  still had a separate, always-empty table for the old `<modalities>` block, and
  showed image and 3D models as an unknown format; they now show the type the
  server's probe found. The Server tab's VRAM bar never showed anything — it read
  a field the server does not send — and now sums the cards the server drives.

## Known gaps

- **`run_code` is not sandboxed and does not ask.** It runs the code a model
  writes on the server machine, as the server's account, with no approval step.
  The documentation used to say it ran in a sandbox; it does only in the narrow
  sense described under [Tools](doc/client/tools.md#the-tool-that-runs-on-the-server).
  It is offered unless you switch it off.
- **A model that only mentions `<tool_call>` while thinking.** Following upstream,
  the tag ends the reasoning wherever it appears. When tools are offered this
  cannot happen — the moment the model writes the tag it is held to a complete,
  valid call. With no tools offered, the rest of that thinking is shown as part
  of the answer.
- **The Pascal pack has never driven a Pascal card.** See above.
- **The session record and the memory AI's choice** have been tested against a
  scripted model, not yet in a real run through a whole graph.
- **The Linux AMD packs have never run on AMD.** A Windows build of the gfx1150
  pack did, on a Radeon 890M — chat, images, speech, motion and 3D.
- **Blackwell** (RTX 50xx) has never been tried.
- **Vulkan on AMD** ran chat, but crashed on the first image step and produced NaN
  for speech.
- **No Windows packages** ship with this release, although Windows builds and runs.
- **No aarch64 or macOS packages**, and `cage-rpc-worker` (multi-node) is still not
  shipped.

The full list of what was and was not tested is in
[What has been verified](doc/verification-status.md).
