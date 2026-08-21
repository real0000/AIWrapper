# What has been verified

CAGE 0.1.1 is an evaluation build. This page says exactly how far each piece has
been tested, so that a field report can go where it is actually useful.

Three levels are used, and the difference between the first two matters more
than it sounds:

| | Means |
|---|---|
| **Runs** | Loaded on real hardware of that kind and produced output |
| **Loads** | The pack `dlopen`s in a clean environment, every symbol resolves, the ABI fingerprint matches and it reports its own identity — but no such GPU was present, so nothing was computed |
| **Not built** | No package exists |

**"Loads" is a real bar, not a formality.** It found four separate cases during
this release where a pack compiled with zero errors and then failed to load,
because a template that is never instantiated produces no compile error and no
symbol. But it says nothing about whether the arithmetic is right.

---

## Backend packs

Verified on a machine with one RTX 4070 (compute capability 8.9) and four
Tesla V100-SXM2 (7.0), NVLink between the V100s.

| Pack | Level | Detail |
|---|---|---|
| `cuda-sm70_sm75` | **Runs** | Drives all four V100s. Correctly refuses the 4070 and says why — the mixed-architecture path works |
| `cuda-sm80_sm86` | **Runs** | Drives the 4070 (sm_86 SASS is forward-compatible within compute capability 8) |
| `cuda-sm89_sm90` | **Runs** | Drives the 4070 |
| `vulkan` | **Runs** | Drives the 4070. **Not tried on AMD or Intel**, which is the case it exists for |
| `cpu` | **Runs** | Self-test passes |
| `cuda-sm120_sm121` | **Loads** | No Blackwell hardware here. 227 kernels present for each of sm_120 and sm_121, no PTX; correctly refused by this machine's cards |
| `hip-*` (all five) | **Loads** | No AMD hardware here. Checked in a container with no ROCm and no AMD driver installed |

## What runs end to end

| | Level | Detail |
|---|---|---|
| Chat, tools, file approval | **Runs** | Against `glm-4.5-air` across the V100s |
| Multi-GPU placement | **Runs** | Topology and NVLink reported; placement across four V100s |
| Retrieval, project memory | **Runs** | |
| Multimodal workers | **Loads** | Environments build; not exercised this release |

## Not built for 0.1.1

| | Why |
|---|---|
| **aarch64** (DGX Spark, GH200) | nvcc's frontend cannot parse the aarch64 system headers when cross-compiling, and no native aarch64 machine was available. See [cross-building](https://github.com/real0000/AIWrapper/blob/main/server/cross/README.md) |
| **macOS** | Xcode SDK licence, the Metal compiler and codesigning all require a Mac |
| **`cage-rpc-worker`** (multi-node) | It is the one executable still linking CUDA statically, so it is GPU-architecture-specific. It belongs in the backend packs; that move has not been made, and the path was never verified anyway |

## The reports worth sending

Ranked by how much they would tell us:

1. **Any AMD card.** Does a model load, and are the answers right? Everything
   about the AMD path beyond "it loads" is unknown. Include the pack name and
   `bin/cage-backend-probe` output.
2. **Blackwell (RTX 50xx).** Same question, same reason.
3. **Vulkan on AMD or Intel.** The pack exists so that non-NVIDIA hardware works
   without ROCm, and that is exactly the case never tried.
4. **Anything where `cage-backend-probe` disagrees with reality** — it says a
   card is usable and loading fails, or the reverse. The probe is what the
   server trusts; if it is wrong, everything downstream is.

`bin/cage-backend-probe` with no arguments prints what it found. That output is
the single most useful thing to attach.
