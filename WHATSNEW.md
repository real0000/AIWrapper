**English** · [繁體中文](WHATSNEW.zh-TW.md)

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
| Send To AI and Memory nodes no longer have a **Memory AI Config** of their own | Nothing, unless one of yours named a different model from the graph's: it is no longer read, so **set the graph's Memory AI Config** to the model you want. |
| A `config.xml` with a `<mysql>` block **waits for that database** when it cannot connect, instead of starting without accounts | **Remove the whole `<mysql>` block** if you meant to run without a database — pointing it at nothing no longer does that. |
| Requests from web pages are refused, and there is no CORS | Nothing, unless a tool of yours calls the API from a browser page: call it from a program instead. |
| The file tools ask before touching anything outside the project | Nothing. To allow more, add paths under **Settings → File access**. The native command line refuses outside paths unless given `--file-access`, `--allow-path` or `--outside`. |
| Server, approval and MCP settings in a workspace's `.vscode/settings.json` are no longer read | **Move them to your user settings.** |
| A graph's modality `out_dir` is a path in your project; generated files are written there after you approve them | Graphs that pointed `out_dir` at an absolute path on the server now write into the project instead. |
| Example passwords (`change-me…`, `CHANGE_ME`) are refused | **Set a real password.** The Docker entrypoint does not start with an example one. |
| A session record is written to `.cage/sessions/` in your project | Add `.cage/sessions/` to `.gitignore` if you do not want it committed. |
| Retrieval cuts files into chunks differently | Nothing — each project's index is rebuilt once, the first time the project is opened. For a large project that takes as long as its first indexing did. |
| Send To AI has no **Role** field any more. It put a short persona — "Coder", "Reviewer" — in front of the prompt as a system message | Nothing, unless a role of yours carried real instructions: it is no longer read, so **move those into the Prompt Template**. The example graphs had only names there. |
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

## Older Linux distributions

The server and every backend pack now need only **glibc 2.28**: RHEL, AlmaLinux
and Rocky 8, Ubuntu 20.04, Debian 11, Fedora, and anything newer. 0.1.x needed
Ubuntu 24.04 or newer, because a program asks for the C library of the system it
was built on, and it was built on a current one. The packages are now built on
Enterprise Linux 8 with GCC 14 and the same CUDA and ROCm versions as before, so
the GPU code is the same.

The CUDA packs are also about a third smaller: they no longer carry the source
line information that only profilers read.

**Verified:** the server package starts and every pack loads in clean AlmaLinux
8, Ubuntu 20.04, Ubuntu 22.04, Debian 13 and Fedora containers. On this machine
(Ubuntu 26.04) the rebuilt server passed the full test suite and answered on a
V100, installed natively and in Docker.

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
tools, tools you define yourself, and the tools of each MCP program — grouped by
where they come from. All of them run in your editor; the server has none of its
own. Every tool can be switched off or re-described; a **group** is a set of those
settings you can switch as a whole. You can add a tool of your own with a name, a
description, a parameter table and one command line. MCP requests no longer have a
timeout.

## Memory that follows the conversation

A graph that loops — a coder and a build check, say — used to start every
attempt from nothing. In one test the coder ran three times and re-checked the
same build environment each time, although its first summary already said what
it had found; that summary had nowhere to go.

- **The session record.** After each Send To AI step the server appends the
  step's Summary to `.cage/sessions/<session id>.md` in your project, with the
  files it wrote. When the message's run ends, the memory AI condenses that part
  into a short list for the next message. Nothing is truncated.
- **The memory AI chooses what to read, every time a step runs.** Each Send To
  AI step — each attempt in a loop, and a step wired to a Memory node as well —
  shows it every rule row, every file history in the project and the session
  record, together with the step's own prompt, and it picks what bears on it.
  Whether the message happens to name a file no longer decides whether its
  history is read.
- **A conversation keeps its session** across a server restart, and loading it
  from History later switches back to it, so the next message continues its
  record. Only a new chat, or a server that says it has no such session, starts
  a new one.

**Tested** against the packaged server with a scripted model standing in for the
LLM: a looping step reads its previous attempt's report, the record is condensed
before the run reports done, a new chat is isolated, and a session is recalled
from the database after a restart. A run with local models through a whole
coding graph found the problems listed under *Fixes* below; it has not been
repeated since they were fixed. See [Project memory](doc/client/memory.md).

## Models that need someone else's weights

Some models name parts of themselves by another repository — TRELLIS.2 points at
a DINOv3 feature extractor, a background remover and a decoder from TRELLIS v1.
The downloader now fetches those along with the model, into the model's own
`components/` folder, and the loader finds them there. No paths to write into the
config. One such part — TRELLIS's background remover, whose licence forbids
commercial use — is replaced by an equivalent under MIT, and the reason is
recorded with it.

Image models published as only the diffusion model are handled the same way. A
quantized GGUF repo often holds just the denoiser — Qwen-Image 2.1 Turbo's does —
and names the full pipeline as its `base_model`; the downloader now fetches that
pipeline's text encoder, VAE and scheduler into `components/` too. A copy made
by hand without them says what is missing instead of failing deep inside the
loader. Custom licences are recorded under their own name — Qwen-Image's is the
Qwen Research License, non-commercial — where before every one was filed as an
unnamed `other`. See [Models](doc/server/agent/models.md#parts-a-model-needs-from-other-repositories).

## Placement plans as if the cards were idle

Where a model's layers go no longer depends on what happens to be loaded at that
moment.

- **Every card you choose is used.** Auto Fit decides only how to split a model
  across the cards you selected, and no longer picks a single card because the
  model would fit on it. Image, speech, 3D and motion models do the same: they
  run on exactly the cards chosen in the graph, split by layer.
- **Room is made before anything moves to the CPU.** The plan counts each card
  as if nothing that could be evicted were on it. Idle models are evicted and
  busy ones waited for; only when the cards hold nothing more that could make
  room does part of the model move to the CPU. A request that still has to wait
  evicts nothing in the meantime.
- **A context that does not fit is placed again**, with part of the model on the
  CPU, instead of failing the request.

Before, a large model loaded while another happened to sit on one of its cards
was packed around it, and could then fail to fit its own context with nothing
left to evict. See [AI configs → GPU placement](doc/client/ai-config.md#gpu-placement).

**Verified** on the packaged build: a small model given two V100s in one NVLink
group was split across both with tensor parallelism, and given two V100s in
different groups was split by layer, both answering exactly as on one card. The
rest — models evicted to make room before anything moves to the CPU — is
covered by the ledger's unit tests, **not yet** by a run with several large
models competing for the same cards.

## Newer image, 3D, speech and motion engines

The four engines behind generation — sd.cpp, trellis.cpp, audio.cpp and
kimodo.cpp — are merged with their upstream projects, and audio.cpp's own
additions to ggml are carried into the backend packs. audio.cpp alone brings
about 70 more model families, among them further speech recognisers (Canary,
Moonshine, GigaAM) and voices (Kokoro, Piper, XTTS-v2).

**Measured** on one V100: an SD 3.5 Large image at 512², 4 steps, takes 7.7 s
instead of 19.1 s, and a kimodo motion 14.2 s instead of 22.4 s. Images, meshes
and motion otherwise match the previous engines, differing only where upstream
changed the method. **Not verified:** the new speech families — only ACE-Step
has been run end to end since the merge.

## A security review

The code was read against recent public incidents involving AI coding agents,
MCP servers, editor extensions and local inference servers. Fourteen problems
were found and fixed; sixteen more checks came out clean.

- **The server cannot end up open by accident.** With no accounts and no
  `<api_key>`, every request is treated as an administrator — handy for a first
  try, and now stated at startup and in the docs. It no longer happens by
  mistake: a `config.xml` with `<mysql>` waits for that database rather than
  starting open, and creating an account while the server is open makes login
  required from the next request on.
- **Web pages cannot use the API.** A request the browser marks as coming from a
  page is refused before its body is read, WebSocket handshakes and CORS
  preflights included, so a page cannot try passwords or act on your behalf. The
  node agent refuses them too. `<bind>` sets which address the server listens on.
- **File tools stay in the project** unless you allow more under
  [Settings → File access](doc/client/settings.md#file-access). Anything outside
  is asked about, once; symbolic links are resolved one step at a time, so a link
  inside the project that points out counts as outside.
- **Generated files come to you.** A graph's image, audio or mesh output is
  delivered to your editor and written into the project through the same
  per-file approval as code, instead of being written on the server machine.
- **A cloned repository cannot reconfigure your editor.** Server address, tool
  approval, MCP and native-client settings are machine-wide, and the extension's
  token lives in the operating system's keychain instead of settings.json.
- **Network and files.** HTTPS calls check the host name; a remote endpoint
  written into a graph reaches only public addresses unless an administrator
  runs it; malformed GGUF files are refused instead of crashing the loader; and
  everything the build downloads is checked against SHA-256.
- **Project memory is guarded.** Invisible characters are removed and reported;
  every line the AI writes says who wrote it and can be undone; and in a turn
  that read content from outside the repository, a new memory is only proposed,
  for you to approve.

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
- **A model that just fit on one card could fail its first request.** After a
  restart, the first model on a card was placed without the card's own runtime
  overhead — the CUDA context and cuBLAS, a few hundred MB — which the server
  could measure only after the first computation. With Auto Fit filling the
  card, the context then did not fit and the request failed. The server now
  warms each card it is about to use and measures that overhead before placing
  the model. If a context still does not fit because the numbers turned out
  wrong — another program took memory after they were measured — it plans the
  placement again and reloads once.
- **Running out of VRAM mid-reply no longer fails the reply.** When a
  computation cannot get memory, because an estimate was low or another program
  took some, the reply used to fail. Now it gives back its context and queues
  like a new placement. Idle models on the card are evicted, models in use are
  waited for, and if nothing can make room, part of the model moves to the CPU.
  Either way the reply continues where it stopped, without repeating what it
  already sent. A model moved to the CPU this way moves back the next time it is
  idle and the room is available again.
  Generative and embedding models queue the same way, but have no CPU to fall
  back to. See
  [Backends → When a card runs out](doc/server/server/backends.md#when-a-card-runs-out-during-a-computation).
- **Memory freed by other programs was not noticed until a restart.** The server
  only corrected its count of VRAM used outside CAGE when something failed. A
  program that had held memory and then exited kept the card looking full, so
  models went to the CPU or did not fit. The cards a model may use are now
  measured again just before it is placed.
- **A config whose GPUs were missing used every card instead.** When none of the
  cards an AI config names was present, such as a card that dropped off the bus
  or a config from another machine, the model was placed across every visible
  card, including any display card. The request now fails and says why. Embedding
  models behave the same way.
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
- **A model could read the session record on its own.** The memory AI's choice
  could be bypassed from inside the step as well: in one run a coder listed the
  project, found `.cage/sessions/`, and read the record with `read_file`. The
  file tools now refuse `.cage/` — reading, writing and patching alike, and a
  patch that touches it is not applied at all. `run_terminal` and `run_code` run
  real programs and cannot be held to this; `run_terminal`'s description asks
  the model to leave `.cage` out of searches.
- **"Rebuild Index" did nothing.** The command showed a message and stopped
  there. It now makes the server drop the project's index, including the copy
  saved on disk, and embed every file again — an ordinary sync skips every file
  that has not changed.
- **A new chat could carry on the previous one.** Choosing Discard or Resume on
  an interrupted run opened a connection for that conversation and left it open.
  A new chat started after that sent its first message down the same connection,
  so the server filed it under the old conversation — whose unanswered messages
  the first step then received as well. Switching conversations now reconnects.
  The native client already did.
- **HTTPS to a remote model failed on Linux.** Every remote AI, embedding or
  modality config with an `https://` URL failed with `certificate verify
  failed`. The server's OpenSSL looked for root certificates in a directory
  that exists on no machine, and the Linux build never loaded the system's own.
  It now loads the system CA bundle, from the same list of places the model
  downloader already used (`CAGE_CA_BUNDLE` or `SSL_CERT_FILE` override it).
  The tests had only ever talked to plain-`http` stand-ins.
- **`run_code` ran on the server, and did not ask.** It is the tool a model uses
  to check a result — work out an expected value, parse a file the project
  produced. It ran on the server machine, as the server's account: it could not
  reach your project's files, and nothing asked you before the code ran. It now
  runs on your machine like every other tool, in your workspace root, and asks
  first like `run_terminal`; the source goes to a temporary folder outside the
  workspace and is deleted afterwards. See
  [Tools](doc/client/tools.md#checking-results-with-run_code).
- **A message could stay unanswered in the shared conversation.** Your message
  joins the conversation that `shared` nodes see as soon as it arrives, but a
  reply is added only when such a node finishes. After a run that had no shared
  node, was stopped, failed, or never started, the next message's nodes saw two
  of your messages in a row and could not tell what became of the first. The end
  of the run now fills the gap — with the run's final answer, or a line saying it
  was stopped, failed (and in which node), or did not run (and why).
- **Sending with no folder open.** Without a workspace folder, `write_file` and
  `apply_patch` put relative paths wherever the editor's own process happened to
  be, and the index, project memory and session record had nowhere to live. The
  chat now asks you to open a folder before it sends anything, and keeps what you
  typed. The native client does the same.
- **A new chat showed the previous one's Resume / Discard banner.** The banner
  for an interrupted run survived **+**, and came back when the panel was
  rebuilt. It now goes with the conversation it belongs to.
- **Opening another folder continued the previous folder's conversation.** There
  was one current conversation for every folder: in project B you were still in
  project A's conversation, with its shared memory, its Resume banner and its
  session record. Each folder now keeps its own, in VS Code and in the native
  client; History still lists all of them. With two VS Code windows open, one
  could also drop a conversation the other had just started.
- **Importing a model from disk said "no loadable weights"** for TRELLIS.2,
  SD 3.5 Large and Ace-Step 1.5. The import used the chat-model loader's rule —
  weights at the top of the folder, named `model*.safetensors` — although what a
  model is gets decided by the server's probe. Any `.gguf` or `.safetensors` in
  the folder now counts. A folder with a model card or a `config.json`,
  `model_index.json` or `pipeline.json` at its top is taken as one model, not
  split into its subfolders. See [Models](doc/server/agent/models.md).
- **Server messages are in English.** Log lines, errors, and the placement
  reasons the Logic Editor's console shows were partly in Chinese.
- **The control plane caught up with the merged model list.** Its Models tab
  still had a separate, always-empty table for the old `<modalities>` block, and
  showed image and 3D models as an unknown format; they now show the type the
  server's probe found. The Server tab's VRAM bar never showed anything — it read
  a field the server does not send — and now sums the cards the server drives.
- **A model split across two NVLink groups answered with nothing but token 0.**
  Copies between cards joined only by PCIe through the CPU arrived as zeros,
  with no error. Only cards with a fast link between them — NVLink, AMD's XGMI —
  now access each other directly; any other pair copies through host memory.
- **Unloading a model split with `-sm graph` over an NVLink pair could leave the
  cards unusable** until the server restarted: one card's memory was freed while
  the other was still reading it. Freeing now waits for every card that can
  reach that memory.
- **Flash attention on V100s got some prompts wrong.** For sliding-window models
  (Gemma 2, 3 and 4, gpt-oss) every query but the first read another row's mask;
  attention sinks (gpt-oss) were ignored; and for the twelve architectures that
  ask for full precision because half precision overflows (Qwen2, GLM4, Phi 2
  and 3, Command-R and others) part of the sum was still kept in half precision.
- **A reply that failed inside a tool loop left the step on old text.** Your
  editor saw an error and stopped updating, while the server carried on with the
  last good reply. The failure is now shown in the step, and that turn runs
  again until it succeeds or you press Stop.
- **Code in a model's thinking could end a step.** The tool-call grammar was
  armed by text inside the reasoning: Qwen3.8 drafting `#include <functional>`
  matched the trigger `<function`, and the step stopped with a grammar error.
  Reasoning is now left alone, and a false trigger no longer stops generation.
- **A local model could call only one tool per reply**, so a step could spend its
  whole Max Tool Iterations reading one file at a time. A reply can now make
  several calls, and the prompt tells the model how many rounds it has.
- **A reply cut off because the context was full looked like a finished one.**
  It now ends with a note giving the token counts, and Logic Debug shows an
  error.
- **Loading a conversation from History started a new session**, so the next
  message could not read that conversation's session record.
- **Steps wired to a Memory node used one block for the whole run.** When the
  pick that made it came back empty, no step in the run had any memory.
- **A queued request evicted idle models before it could use the room**, and
  the ledger counted their memory as free while they were still loaded — another
  model was then placed onto it. Eviction now happens at the moment the request
  fits.
- **The startup probe took some chat models for speech models**: a GGUF with a
  vision projector for one speech family, a folder with a single safetensors
  file for another. Those never appeared as chat models.
- **The reason a model failed to load was cut off** just before the part that
  mattered: the message had 512 bytes to fit in.
- **A fresh install's Chat showed a graph it had not selected**, so the first
  message went out with none and was refused. The graph shown is now the one
  selected.
- **Backend packs shipped without the licences of four of their components** —
  sd.cpp, trellis.cpp, audio.cpp and kimodo.cpp — and two lists of changed files
  had gone stale after upstream merges. Each pack now carries the notices for
  exactly what is compiled into it, and the lists are computed from git.

## Known gaps

- **A model that only mentions `<tool_call>` while thinking.** Following upstream,
  the tag ends the reasoning wherever it appears. When tools are offered this
  cannot happen — the moment the model writes the tag it is held to a complete,
  valid call. With no tools offered, the rest of that thinking is shown as part
  of the answer.
- **The Pascal pack has never driven a Pascal card.** See above.
- **The memory AI's pick can go round in circles.** With Qwen3.6 as the memory
  model, a pick was seen repeating the same check in its thinking until the
  context filled — close to two hours — and then returning nothing usable. Two
  causes were found: the pick runs at a temperature capped at 0.2 with none of
  the config's other sampling settings, which Qwen3.6's own card warns leads to
  endless repetition when thinking; and the step's own output instructions sit
  inside what it is asked to judge. The fix has not been decided yet.
- **Since this build's memory fixes**, the memory changes have run against a
  scripted model only, not through a whole graph with real models.
- **Several tool calls in one reply** have been seen from GLM only; Qwen's and
  DeepSeek's templates have not been tried. Lookahead together with the
  reasoning budget or presence penalty has not been run with a real model.
- **sd.cpp lost two things in its merge:** INT8 tensorwise weights, and FP8
  weights kept as FP8 — an FP8 checkpoint now loads as F16, at twice the memory.
- **The new speech families have not been run**, other than ACE-Step; on the
  Vulkan pack, audio.cpp's new operations have no kernels and run on the CPU.
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
