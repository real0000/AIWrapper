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

Verified on a machine with one RTX 4070 (compute capability 8.9) and four
Tesla V100-SXM2 (7.0), NVLink between the V100s.

| Pack | Level | Detail |
|---|---|---|
| `cuda-sm70_sm75` | **Runs** | Drives all four V100s and correctly refuses the 4070, saying why. The 0.2.0 server with this pack, installed as the install guide describes and started by the agent, answered a prompt on a V100 at 174 tok/s (Qwen3-0.6B) |
| `cuda-sm80_sm86` | **Runs** | Drives the 4070 (sm_86 code is forward-compatible within compute capability 8) |
| `cuda-sm89_sm90` | **Runs** | Drives the 4070 |
| `cpu` | **Runs** | Self-test passes |
| `vulkan` | **Runs** | Drives all five cards here — the 4070 and the four V100s. On AMD see below |
| `cuda-sm60_sm61` | **Loads** | **New in 0.2.0**, for the P40 and the rest of Pascal. No Pascal card here. 236 kernels present for each of sm_60 and sm_61, no PTX; correctly refused by every card in this machine |
| `cuda-sm120_sm121` | **Loads** | No Blackwell hardware here. Correctly refused by every card in this machine |
| `hip-*` (all five) | **Loads** | No AMD hardware here. Checked in a clean Ubuntu 24.04 container — no ROCm, no AMD driver — with only the four host packages the install guide lists |

**Without a CUDA toolkit.** The machine above has CUDA installed system-wide,
which hides a missing library. So all five CUDA packs, and the server as the
installer lays it out, were also checked in a clean Ubuntu 24.04 container with
no CUDA and no driver: everything they need resolves from the package's own
`lib/` except `libcuda.so.1`, which comes with the driver. This check found
that the packs had been shipping without `libcufft`; they now carry it.

**Packs side by side.** `cuda-sm60_sm61` and `cuda-sm70_sm75` were installed
into the same `bin/` together, as a machine with a P40 next to V100s would have
them. Both load; the V100 pack takes the four V100s, the Pascal pack is left
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
| Native, with `install.ps1` | **Runs** | The server package and two CUDA packs from `dist/`, merged and installed exactly as the [install guide](server-install.md) says (`pwsh ./install.ps1 --prefix … --no-service`), then started the way the systemd unit starts it, `cage-launcher --agent`: the server it launched found the packs in `bin/` and answered a prompt on a V100. The systemd units themselves were not installed |
| Docker | **Runs** | The quick start in [Docker](server/docker.md), with the 0.2.0 server package and the `cuda-sm70_sm75` pack: MySQL and the server come up, the server finds the pack, a model answers on a V100, the web UI serves, the config survives `down` and `up` |

Before these runs, neither route could run a local model. Natively, the
installer did not copy `lib/`, and a server started by the agent looked for packs
in the install directory instead of `bin/`. In Docker, the image did not build
and the seeded `config.xml` did not parse. Earlier tests had started the server
from inside `bin/`, where the native problems disappear.

## What runs end to end

| | Level | Detail |
|---|---|---|
| Chat | **Runs** | Local models answering on the V100s, including from the packaged 0.2.0 build above |
| Tools, file approval | **Runs** | As in 0.1.2 — against `glm-4.5-air` across the V100s. Not re-run for this release |
| Multi-GPU placement | **Runs** | Topology and NVLink reported; placement across four V100s, a chosen subset, or one card |
| A hybrid Mamba2 model | **Runs** | **New in 0.2.0.** NVIDIA-Nemotron-3-Ultra-550B-A55B: 12 attention, 48 MoE and 48 Mamba2 layers. Correct answers at temperature 0, on four V100s with the experts in host memory, 2.8 tok/s. Checked on a development build at ik `86e53daf5`; the packs carry `083bb2713`, which differs only in a HIP header that CUDA builds do not compile |
| Image and 3D | **Runs** | SD 3.5 Large images and TRELLIS.2 meshes (the mesh on a V100), in-process, on development builds during this release. TRELLIS's three borrowed components were found from the model's own `components/` folder with no paths in the config |
| Retrieval | **Runs** | End to end as in 0.1.2, not re-run for this release. The embedding model itself, `nemotron-3-embed-1b`, is now read in-process from safetensors: on a development build during this release it loaded and its vectors matched the reference scores its model card lists |
| Multi-model logic graph with a feedback loop | **Runs** | As in 0.1.2 — DemoCoder converged on the first iteration. Not re-run for this release |

### New in 0.2.0, tested against a scripted model

These were run against the packaged 0.2.0 server with a scripted model in place
of the LLM. It answers from a script, so what is checked is the server's side:
what reaches the model, what is written and read, and in what order.

| | Checks | What |
|---|---|---|
| Session record | 43 | A step re-run in a loop reads its previous attempt's report; the record is condensed before the run reports done; the next message reads the condensed version; a new chat is isolated; without a memory AI config it is written but not read |
| What memory is read | 161 | The whole memory suite, including: with a memory AI, whether history is read does not depend on the message naming the file; without one, only rules are read |
| A session across a server restart | 19 | Three server restarts: the session is recalled from the database; an unknown id is refused with 404; without a database the client's id is taken |
| Tool calls in two sessions | 9 | Stop or a disconnect in one session leaves the other's waiting calls alone; two sessions with the same call id each get their own result; a reply from the wrong session is refused |
| Client tools end to end | 24 | The native client, headless, with a real MCP subprocess |

**Not yet:** a real model through a whole graph with the session record, and the
installed extension and native client restarting.

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
