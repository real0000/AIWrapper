**English** · [繁體中文](verification-status.zh-TW.md)

# What has been verified

CAGE 0.2.0 is an evaluation build. This page says exactly how far each piece has
been tested, so that a field report can go where it is actually useful.

Three levels are used, and the difference between the first two matters more
than it sounds:

| | Means |
|---|---|
| **Runs** | Loaded on real hardware of that kind and produced output |
| **Loads** | The pack `dlopen`s in a clean environment, every symbol resolves, the ABI fingerprint matches and it reports its own identity — but no such GPU was present, so nothing was computed |
| **Not built** | No package exists |

**"Loads" is a real bar, not a formality.** It has caught packs that compiled
with zero errors and then failed to load, because a template that is never
instantiated produces no compile error and no symbol. But it says nothing about
whether the arithmetic is right.

Unless a row says otherwise, everything below was checked **against the 0.2.0
packages themselves** — unpacked into a fresh directory the way the install
guide describes, not against a development build.

---

## Backend packs

Verified on a machine with one RTX 4070 (compute capability 8.9) and eight
Tesla V100-SXM2 (7.0) in two NVLink groups of four, joined to each other only
by PCIe through the CPU.

| Pack | Level | Detail |
|---|---|---|
| `cuda-sm70_sm75` | **Runs** | Drives all eight V100s and correctly refuses the 4070, saying why. Qwen3-0.6B answered at about 172 tok/s on one V100, and identically on two V100s in one NVLink group (a `graph` split) and on two in different groups (a `layer` split). Installed as the install guide describes and started by the agent, and in Docker, the server answered on four V100s |
| `cuda-sm80_sm86` | **Runs** | Drives the 4070 (sm_86 code is forward-compatible within compute capability 8) |
| `cuda-sm89_sm90` | **Runs** | Drives the 4070 |
| `cpu` | **Runs** | Self-test passes |
| `vulkan` | **Runs** | Drives all nine cards here — the 4070 and the eight V100s. On AMD see below |
| `cuda-sm60_sm61` | **Loads** | **New in 0.2.0**, for the P40 and the rest of Pascal. No Pascal card here. 238 kernels present for each of sm_60 and sm_61, no PTX; correctly refused by every card in this machine |
| `cuda-sm120_sm121` | **Loads** | No Blackwell hardware here. Correctly refused by every card in this machine |
| `hip-*` (all five) | **Loads** | No AMD hardware here. Checked in clean AlmaLinux 8, Ubuntu 20.04, Ubuntu 22.04, Debian 13 and Fedora containers — no ROCm, no AMD driver — with only the host packages the [install guide](server/server/backend-packs.md) lists for each |

**Rebuilt on 2026-11-25.** The server and every pack were rebuilt at ik
`8c6a2b89f` on the Enterprise Linux 8 base first used on 2026-10-31 — AlmaLinux
8, NVIDIA's Rocky Linux 8 CUDA images and AMD's AlmaLinux 8 ROCm image — with
GCC 14 and the same CUDA 12.0, CUDA 12.9 and ROCm 6.4.4. They need nothing newer
than glibc 2.28: the server's executables ask for at most `GLIBC_2.28`, the
packs and the libraries they carry for `GLIBC_2.27`. Every pack had to be
rebuilt: the server's interface to the packs changed, and an older pack is
refused. Every pack was checked again: it dlopens, its ABI fingerprint matches
the server's, it reports `8c6a2b89f`, and on the machine above each gives
exactly the result its row states. The `cuda-sm70_sm75` row, the install and
Docker rows below, and the test suites further down were re-run on these
packages.

**Older and newer distributions, without a CUDA toolkit.** The machine above
has CUDA installed system-wide, which hides a missing library. So the server and
all twelve packs were also checked in clean AlmaLinux 8 (glibc 2.28), Ubuntu
20.04 (2.31), Ubuntu 22.04 (2.35), Debian 13 (2.41) and Fedora (2.43)
containers with no CUDA, no ROCm and no driver, and only the host packages the
install guide lists: the server starts, the CPU pack runs its self-test, the
HIP and Vulkan packs load, and everything the CUDA packs need resolves from
their own `lib/` except `libcuda.so.1`, which comes with the driver. An earlier
round of this check found that the packs had been shipping without `libcufft`;
they now carry it.

**Packs side by side.** `cuda-sm60_sm61` and `cuda-sm70_sm75` were installed
into the same `bin/` together, as a machine with a P40 next to V100s would have
them. Both load; the V100 pack takes the eight V100s, the Pascal pack is left
with nothing to drive here, and neither disturbs the other. The prompt above was
answered from that two-pack install. What could not be checked is the Pascal
pack actually driving a P40 — there is none in this machine.

**AMD, on a different machine.** On 2026-09-28 a Windows build of the gfx1150
pack ran on a Radeon 890M, installed the way a user would: a 0.6B chat model at
about 91 tok/s, SD 1.5 images, speech, motion and a full TRELLIS mesh. The
Vulkan pack ran the chat model at about 23 tok/s on the same card, but crashed on
the first SD step, and its speech output was NaN. That was the Windows build of
an earlier tree; **the Linux AMD packs in this release have not run on AMD.**

## Installing

| | Level | Detail |
|---|---|---|
| Native, with `install.ps1` | **Runs** | The server package and two CUDA packs from `dist/`, merged and installed exactly as the [install guide](server-install.md) says (`pwsh ./install.ps1 --prefix … --no-service`), then started the way the systemd unit starts it, `cage-launcher --agent`: the server it launched found the packs in `bin/` and answered a prompt on four V100s, and everything stopped within a second of SIGTERM to the agent. The systemd units themselves were not installed |
| The extension, from `cage-0.2.0.vsix` | **Runs** | Installed into a fresh VS Code profile and connected to the native install above: the token in settings.json moved into VS Code's secret storage at startup, the server's only graph was selected and downloaded without a click, a local model answered on a V100, and loading an earlier conversation from History continued its session record |
| Docker | **Runs** | The quick start in [Docker](server/docker.md), with the 0.2.0 server package and the `cuda-sm70_sm75` pack: MySQL and the server come up, the server finds the pack, signing in the way the docs describe works (`Authorization: Basic`), a model answers on four V100s, HTTPS works from inside the container, a request carrying a web page's `Origin` is refused, the web UI serves, the config survives `down` and `up` |

Before these runs, neither route could run a local model. Natively, the
installer did not copy `lib/`, and a server started by the agent looked for packs
in the install directory instead of `bin/`. In Docker, the image did not build
and the seeded `config.xml` did not parse. Earlier tests had started the server
from inside `bin/`, where the native problems disappear.

## What runs end to end

| | Level | Detail |
|---|---|---|
| Chat | **Runs** | Local models answering on the V100s, including from the packaged 0.2.0 build above |
| Tools, file approval | **Runs** | As in 0.1.2 — against `glm-4.5-air` across the V100s. Not re-run for this release. Tool-call parsing for the Qwen3.5/3.6/3.8 and Nemotron templates — including a call written inside reasoning that was never closed — is covered by a test through the pack's own C boundary: 68 checks on four real templates, of which the earlier 0.2.0 build failed 5 |
| `run_code` on the client | **Runs** | **New in 0.2.0.** The installed extension in VS Code, with Qwen3.6-35B-A3B on one V100: the approval card showed the whole program and where it runs; the model read a project file with a shell command, then wrote a C program that read it by relative path, compiled and ran in the workspace root, and gave the right answer. Nothing was left in the workspace or the temporary folder |
| Remote models over HTTPS | **Runs** | Checked against `https://huggingface.co` from the packaged server, natively and inside the Docker image; a site with an expired certificate is refused. Before a fix in this release, every HTTPS remote config failed on Linux |
| Multi-GPU placement | **Runs** | Topology and both NVLink groups reported; only cards in the same group access each other's memory directly. On the packaged build the same model on one V100, on two in one group (a `graph` split) and on two in different groups (a `layer` split) gave the same answer — before this release the last answered with token 0. Every chosen card is used |
| A hybrid Mamba2 model | **Runs** | **New in 0.2.0.** NVIDIA-Nemotron-3-Ultra-550B-A55B: 12 attention, 48 MoE and 48 Mamba2 layers. Correct answers at temperature 0, on four V100s with the experts in host memory, 2.8 tok/s. Checked on a development build at ik `86e53daf5`; the packs carry `60d899d9b`, which adds a HIP header fix that CUDA builds do not compile and the Qwen3-Coder chat parser — neither touches the computation |
| Image and 3D | **Runs** | SD 3.5 Large images and TRELLIS.2 meshes (the mesh on a V100), in-process, on development builds during this release. TRELLIS's three borrowed components were found from the model's own `components/` folder with no paths in the config. On the packaged build, TRELLIS.2 registered with `cage-model-dl --scan` was recognised as a 3D model at startup and turned an SD 3.5 picture into a textured `.glb` on a V100 (351 s). Two earlier attempts, with SD 3.5 still resident on a second V100, were cut off by a driver lock-up on this machine |
| Retrieval | **Runs** | `nemotron-3-embed-1b`, read in-process from safetensors, matched the reference scores its model card lists. On the packaged build it indexed real projects across four V100s: an index saved by the previous build was rebuilt when its project was opened (17 chunks, among them one per line of `CMakeLists.txt` and the session record, became 7, without `.cage/`), and **CAGE: Rebuild Index** re-embedded a project from scratch. The new chunking itself is covered by tests |
| Multi-model logic graph with a feedback loop | **Runs** | As in 0.1.2 — DemoCoder converged on the first iteration. On the packaged 0.2.0 build, with Qwen3.8 across four V100s, the planner wrote checks that agree with each other and the coder wrote `packer.cpp` and a `Makefile` — the run behind the chat panel image — but each of the last three attempts was cut off by a driver lock-up on this machine before the verifier step, so the full loop has not been re-run |

### New in 0.2.0, tested against a scripted model

These were run against the packaged 0.2.0 server with a scripted model in place
of the LLM. It answers from a script, so what is checked is the server's side:
what reaches the model, what is written and read, and in what order.

| | Checks | What |
|---|---|---|
| Session record | 49 | A step re-run in a loop reads its previous attempt's report; the record is condensed before the run reports done; the next message reads the condensed version; a new chat is isolated; without a memory AI config it is written but not read; a step wired to a Memory node scans for itself and sees its own previous report |
| What memory is read | 170 | The whole memory suite, including: with a memory AI, whether history is read does not depend on the message naming the file; without one, only rules are read; two Send To AI nodes wired to one Memory node each make their own pick; a Memory node assembles its block only when something reads the text; a node-level memory config left in a graph is ignored; the prompt states the limit on tool rounds |
| A session across a server restart | 20 | Three server restarts: the session is recalled from the database; an unknown id is refused with 404; without a database the client's id is taken |
| Tool calls in two sessions | 10 | Stop or a disconnect in one session leaves the other's waiting calls alone; two sessions with the same call id each get their own result; a reply from the wrong session is refused |
| Client tools end to end | 32 | The native client, headless, with a real MCP subprocess. `run_code` runs on the client, in the workspace root, in the group that switches it on — and not at all where it is off. A step that ran a command is not told its verification is unconfirmed. A Send To AI with tool calls on whose model does not exist reports the failure and runs the turn again until stopped, then ends with one `done`; with tool calls off it fails with exactly one error |
| Unanswered messages | 11 | A message whose run had no shared node, was stopped, failed, or never started gets one answer in the shared conversation — the run's final result, or what happened to it; a shared node's own answer is not doubled |
| Resuming an interrupted run | 39 | Stop pressed in the middle of a step: the run resumes from that node, and steps already done are not sent to the model again. Variables, the branch an If chose and a sub-graph survive the interruption. After the server is killed with `kill -9` and started again, the same session is offered the run, from the database |
| One graph handing work to another | 26 | Send Prompt runs another graph with the prompt it is given and returns that graph's result; the inner graph finishing does not end the outer turn |

**Not yet:** a real model through a whole graph since this build's memory
fixes — an earlier run with local models is what found them — and the installed
extension and native client restarting.

## Not built for 0.2.0

| | Why |
|---|---|
| **Windows** | Builds and runs (see the AMD note above), but on a different machine; no Windows packages were produced with this release |
| **aarch64** (DGX Spark, GH200) | nvcc's frontend cannot parse the aarch64 system headers when cross-compiling, and no native aarch64 machine was available. See [cross-building](https://github.com/real0000/AIWrapper/blob/main/server/cross/README.md) |
| **macOS** | Xcode SDK licence, the Metal compiler and codesigning all require a Mac |
| **`cage-rpc-worker`** (multi-node) | It is the one executable still linking CUDA statically, so it is GPU-architecture-specific. It belongs in the backend packs; that move has not been made, and the path was never verified anyway |

## The reports worth sending

Ranked by how much they would tell us:

1. **A P40, or any Pascal card.** The Pascal pack is new and has never driven
   one. Does an embedding model load, and does retrieval return sensible
   matches? Include `bin/cage-backend-probe` output.
2. **Any AMD card on Linux.** Does a model load, and are the answers right? The
   Windows build has run on one AMD card; the Linux packs never have.
3. **Blackwell (RTX 50xx).** Same question, same reason.
4. **Vulkan on AMD or Intel.** The pack exists so that non-NVIDIA hardware works
   without ROCm. On the one AMD card it has met, chat worked and image and speech
   did not.
5. **Anything where `cage-backend-probe` disagrees with reality** — it says a
   card is usable and loading fails, or the reverse. The probe is what the
   server trusts; if it is wrong, everything downstream is.

`bin/cage-backend-probe` with no arguments prints what it found. That output is
the single most useful thing to attach.
