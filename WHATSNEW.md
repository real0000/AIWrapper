# What's New in CAGE 0.1.1

0.1.0 was the first evaluation build. 0.1.1 is the first release where the
product is shaped the way it will keep being shipped: a small server, GPU
support downloaded separately for your hardware, and files that land in your
workspace the moment you approve them.

It is also a **breaking release in both directions**. The project was renamed,
the workflow layer was removed, and GPU inference now requires a second
download. Update the server and the editor client together.

---

## Before you upgrade

| What changed | What you have to do |
|---|---|
| Everything is called `cage`, not `aiwrapper` | Edit `settings.json` — the old `aiwrapper.*` keys are silently ignored. Uninstall the old side-loaded VSIX; the extension id is new. |
| The MySQL database and user were renamed | Run `server/sql/migrate-aiwrapper-to-cage.sql` **before** starting the new server. |
| GPU inference moved out of the server binary | Download the backend pack for your GPU as well as the server package. See below. |
| The workflow layer is gone | Nothing to migrate — but an old client cannot talk to a new server, or the reverse. |
| Build environment variables are `CAGE_*` | Update any shell profile that exports `AIW_*`. |

Existing build directories cache the old option names. Reconfigure from scratch
rather than incrementally.

---

## GPU support is a separate download now

The server used to be a 1.7 GB binary, almost all of which was compiled GPU
kernels for architectures your machine does not have. It is now **49 MB with no
CUDA dependency at all** — verified: zero CUDA shared libraries, zero
unresolved `llama_` symbols. The GPU code lives in a backend pack that the
server opens at runtime.

What this buys you:

- **You download kernels for your card, not for everyone's.** One pack per GPU
  family instead of one binary carrying all of them.
- **Non-NVIDIA hardware is reachable.** There is a Vulkan pack, which runs on
  AMD, Intel and NVIDIA alike, and a CPU-only pack that needs no GPU at all.
- **New architectures do not require a new server.** A pack for a newer card is
  a separate, much smaller release.
- **Updating the server does not mean re-downloading a gigabyte of kernels.**
  The two halves version independently.

Packs are named `cage-backend-<hardware>-<version>-<platform>.tar.gz`. Unpack
one and put `libcage-llama-*.so` in the server's `bin/`.

| Pack | Covers |
|---|---|
| `cuda-sm70_sm75` | Volta, Turing — V100, T4, RTX 20xx, GTX 16xx |
| `cuda-sm80_sm86` | Ampere — A100, A40, RTX 30xx |
| `cuda-sm89_sm90` | Ada, Hopper — L40S, RTX 40xx, H100 |
| `cuda-sm120_sm121` | Blackwell — RTX 50xx, GB10 (DGX Spark) |
| `hip-*` | AMD via ROCm, one pack per ISA generation (RDNA2/3/4, CDNA) |
| `vulkan` | Any Vulkan 1.2 GPU — AMD, Intel, or NVIDIA |
| `cpu` | No GPU |

Exactly how far each piece has been tested is listed in
[verification status](doc/verification-status.md).

**The AMD packs are new and unproven.** They compile, load, resolve every symbol
and identify themselves correctly — but all of that was verified on a machine
with no AMD hardware. Nobody has yet confirmed they compute the right answers or
how fast they are. If you have an AMD card, that is exactly the report we need.
They also need four ordinary distribution packages the pack cannot ship for you:
`libdrm2 libdrm-amdgpu1 libnuma1 libelf1`.

**You can install more than one.** The server probes every pack it finds, per
device, and picks per AI config — so a machine with both an NVIDIA and an AMD
card can drive each with the backend that suits it.

If you download the wrong pack, you are told so directly: `cage-backend-probe`
reports that the pack carries no device code for your card, instead of the
server failing later when a model loads. A machine with no pack still starts
normally and still runs vLLM and remote endpoints — only in-process GGUF
inference is unavailable, and the error says which pack to fetch.

---

## Files land in your workspace as they are written

0.1.0 accumulated `write_file` and `apply_patch` results in a staging area and
asked you to flush them in a batch, before any tool that would see the
workspace. In practice that failed three ways: the model was told its file did
not exist yet and rewrote it over and over trying to make it stick, sometimes
resorting to shell heredocs to get around it; a turn that never ran a terminal
command left every write suspended, so nothing happened at all; and when the
prompt did come, it asked you to review a pile of unrelated files at once.

**Staging is gone.** `write_file` and `apply_patch` now ask before each
individual file, write straight to your real workspace once approved, and tell
the model the file is on disk — or that you declined, in as many words.

Approvals are serialised: one question at a time, the rest queued in arrival
order, with later tool calls held until you answer. An `apply_patch` touching
five files asks five times, each with the diff for that file, syntax-coloured.

The working directory is always your workspace root. The server does not decide
where files go.

---

## GPU detection is no longer NVIDIA-only

Hardware detection shelled out to `nvidia-smi` and asked CUDA for PCI
addresses, so on anything else the GPU list came back empty and automatic
placement had nothing to work from.

There are now four detection backends chosen at runtime: `nvidia-smi`, AMD's
KFD interface (including XGMI links, with no `rocm-smi` dependency), Apple's
`sysctl`, and a Vulkan fallback that works on any vendor.
`CAGE_GPU_PROBE=nvidia|amd|apple|vulkan|none` forces one.

**Honest limits:** the AMD path has not been run against real AMD hardware. And
Vulkan reporting no interconnect is correct rather than missing — split modes
that need one are not available on Vulkan, so the choice there is made from
free VRAM instead of topology.

---

## vLLM is optional: safetensors convert themselves

`backend="vllm"` used to mean "unavailable unless you got a vLLM environment
working", which is not a given — it has to match your GPU generation, CUDA
toolkit and torch build simultaneously.

Now the server probes vLLM on first use and, if it is absent or broken, falls
back to converting the weights to GGUF and running them on the llama backend.
Quantization still follows your AI config; `4bit` converts to f16 and quantizes
to `Q4_K_M` in-process.

**The converted GGUF is never written to disk.** It goes to tmpfs and is
unlinked as soon as the model has loaded — no cache to manage, nothing to
invalidate. Budget eviction means reconverting, and the tmpfs directory needs
the room in RAM while it runs, which is checked before starting.

Verified end to end on Qwen3-0.6B safetensors with vLLM unset and with a
deliberately broken interpreter path: convert 10 s, quantize 6 s, 456 MiB
`Q4_K_M`, loaded and generating; the second request reused the loaded model in
1.3 s with no reconversion.

---

## The project remembers what it changed

Project memory had exactly one writer — a tool the model was asked to call
"when you have just done or learned something non-obvious and durable". Across
three test runs it never once decided to. The memory directory was never
created, and every turn injected zero memory files.

History is a log of how a file was changed and why. It should not depend on the
model remembering to write it. The server now records it directly: at the end
of a turn, one entry per file that was **actually written**, taken from the
tool arguments rather than from the model's own summary — summaries claim to
have created files that were never touched, and following them would invent
history for files that do not exist. The reason comes from the node's summary
output; nodes that produce no summary (a build-verification pass, for example)
write nothing, because they have no reason to give.

Both the local and remote tool loops write it, so a graph running against a
cloud endpoint keeps the same history.

---

## AI configs and modality configs are one list

Image, speech, audio, music and 3D configs used to be a separate list with
their own "+ New" and their own editor. For you they were the same thing as an
AI config — pick a model, decide how it loads — differing only in the property
sheet. They are now one **AI CONFIGS** list, with generative entries labelled by
type, and the property sheet switching to match the model you pick. Choosing a
different kind of model converts the config in place, keeping its name so the
nodes bound to it stay bound.

Multimodal workers are also on the same VRAM ledger as everything else now,
instead of being invisible to it, and they pick GPUs by device rather than by a
configuration whitelist.

---

## Register models that are already on disk

`cage-model-dl --scan <dir>` walks a directory and registers what it finds —
format, quantizations, vision projector and licence — using the same scanner
the server runs at startup. Previously the downloader only went one way (repo
id → download → config), so weights that arrived by any other route had to be
typed into `config.xml` by hand.

Licence is resolved from the GGUF metadata, then the model card, then the git
remote, then the upstream card. Two traps it handles: a repacker's embedded
model name is whatever they felt like — one GGUF calls itself `Downloads`, and
searching for that finds a real, unrelated repository whose licence would then
be attached to your model — so name searches are validated against the
directory on disk, never against metadata. And models distilled from restricted
weights advertise the upstream company's licence; those are promoted to the
licence that actually governs the weights, or cleared with a reason where it
cannot be established. Nothing in this path invents a licence it does not have.

Available as `cage-model-dl --scan` (with `--dry-run` and `--offline`) and as an
import panel in the control plane's Models tab.

---

## A message names the graph it runs

The workflow layer was an envelope that made no decisions. The graph that
actually ran always came from the chat panel's graph selector; the workflow's
own graph id was a branch that never executed, and its start/end prompts were
parsed, stored, persisted, and read by nothing.

A chat message now names its graph directly. One hop instead of two, and no
session state that can disagree with what you picked.

---

## Renamed: AIWrapper → CAGE

**C**omposable **A**gent **G**raph **E**ngine. The old name collided with too
many unrelated projects. This is a clean rename with no compatibility shims —
the right time is now, before 1.0 and while distribution is a side-loaded
`.vsix` and a tarball.

Settings keys, command ids, the extension id, the binary names, the systemd
units, the database, the runtime paths and the build variables all move. The
table at the top of this page lists the ones that need action from you.

---

## Licensing

CAGE is now sold as a **base product plus separately purchased modules**, each
with **perpetual updates** — buy it once and every future release of that
product is included. No maintenance period, no renewal, no version at which
your licence stops.

**A module never takes away what you already bought.** Whatever a product could
do when you licensed it stays part of that product; the boundary is fixed when
a module is first offered, never retroactively.

A commercial licence is organisation-wide: unlimited installations within one
company, no per-seat, per-GPU or per-server counting. Full terms in
[LICENSE](LICENSE); the components CAGE builds on are listed in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

Two multimodal families changed for licensing reasons: the music worker no
longer depends on a non-commercial component, and the image-to-3D worker was
decoupled from its copyleft dependencies. One 3D family whose multi-view model
carries no licence at all is disabled rather than shipped.

---

## Fixes worth naming

- **`write_file` could be swallowed whole.** A tool call whose arguments held a
  large block of code was parsed as prose and never dispatched, so the model
  believed it had written a file that was never requested.
- **Retrieved context had no ceiling.** A single log file could crowd the
  actual task out of the prompt.
- **A full re-index kept deleted files.** After clearing a workspace the model
  was still reading content that no longer existed.
- **Top-level `build/` and `node_modules/` were never actually excluded** from
  the index.
- **The VRAM ledger was per-machine, not per-card**, which was wrong in three
  separate places whenever more than one GPU was selected. Per-card estimates
  now use the real split ratios and account for context growth.
- **Tensor parallelism no longer requires a contiguous run of GPUs** — any
  subset of cards works, and a GPU whitelist is honoured.
- **A broken tool call no longer becomes an approval box you cannot dismiss.**
- **Terminal commands run in the workspace root** rather than wherever the
  process happened to be.
- **Embedding models work on any backend again**, not only the in-process one.

---

## Known gaps

- The server binary still reports no version of its own; `/health` does not
  return one.
- The AMD detection path has not been exercised on real AMD hardware.
- Multi-node exists in the control plane, but each client connects to a single
  server — there is no scheduling across machines.
- Server-side session history is recorded but not replayed into a conversation
  resumed after a restart.
- `mesh-trellis` still needs an upstream interactive setup step.
- Pascal and older NVIDIA cards are not supported.
