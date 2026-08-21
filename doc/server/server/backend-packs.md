# Backend Packs

In-process GGUF inference needs a **backend pack** — a second download that
carries the compiled GPU code for your hardware. The server package does not
contain any.

This is not an optional extra for most installations. Without a pack the server
starts and runs, but only the `vllm` and `remote` backends work; anything with
`backend="llama"` fails to load with a message naming the pack to fetch.

---

## Why it is separate

The GPU kernel set is large — far larger than the rest of the server — and
almost all of it is for architectures your machine does not have. Shipping one
binary covering everything meant a 1.7 GB download of which 91% was dead weight
on any given machine, and it could no longer be linked at all once the kernel
set grew past two architectures.

Splitting it means:

- you download kernels for your card, not for everyone's;
- non-NVIDIA hardware is reachable, through the Vulkan pack;
- a new GPU architecture is a new pack, not a new server;
- updating the server does not re-download a gigabyte of kernels.

The server is **49 MB** and has no CUDA dependency of its own. A CUDA pack is
about 1.6 GB unpacked (two architectures' kernels); the Vulkan and CPU packs are
roughly 50 MB and 30 MB.

## Choosing one

| Pack | Hardware | Compute capability |
|---|---|---|
| `cage-backend-cuda-sm70_sm75` | V100, Titan V, T4, RTX 20xx, GTX 16xx, Quadro RTX | 7.0, 7.5 |
| `cage-backend-cuda-sm80_sm86` | A100, A30, A40, A10, RTX 30xx | 8.0, 8.6 |
| `cage-backend-cuda-sm89_sm90` | L40, L40S, L4, RTX 40xx, H100, H200 | 8.9, 9.0 |
| `cage-backend-hip-*` | AMD, via ROCm — see below | n/a |
| `cage-backend-vulkan` | Any Vulkan 1.2 GPU — AMD, Intel, or NVIDIA | n/a |
| `cage-backend-cpu` | No GPU at all | n/a |

### AMD packs

AMD packs are split by **ISA generation**, because AMD device code is not
compatible across generations the way NVIDIA's is within a major compute
capability:

| Pack | Cards |
|---|---|
| `cage-backend-hip-gfx1100_gfx1101_gfx1102` | RDNA3 — RX 7000 |
| `cage-backend-hip-gfx1030_gfx1031_gfx1032` | RDNA2 — RX 6000 |
| `cage-backend-hip-gfx1200_gfx1201` | RDNA4 — RX 9000 |
| `cage-backend-hip-gfx908_gfx90a_gfx942` | CDNA — MI100 / MI200 / MI300 |
| `cage-backend-hip-gfx1103_gfx1150_gfx1151_gfx1152` | RDNA3 APUs — Phoenix / Strix / Strix Halo |

Vega and older (gfx900, gfx906 — Vega 64, Radeon VII, MI50/60) are **not
covered**: ROCm ships no rocBLAS kernels for them. MI350 (gfx950) is not covered
either, for the opposite reason — it is newer than the rocPRIM in the ROCm we
build against, which has no 128-bit atomics for it. The Vulkan pack may still
drive those cards.

> **Verified as far as we can verify it, and no further.** These packs compile,
> load, resolve every symbol and report their own identity correctly — all
> checked on a machine with no AMD hardware. Whether they *compute correctly*
> and how fast they run has not been tested, because we have no AMD GPU. Treat
> them as a request for field reports, not as a supported configuration.

**Host prerequisites for AMD.** Unlike the CUDA packs, which need only the
NVIDIA driver, the HIP packs need a few libraries that are not theirs to ship:

```bash
sudo apt install libdrm2 libdrm-amdgpu1 libnuma1 libelf1
```

`libdrm*` comes with the amdgpu driver stack — the AMD equivalent of
`libcuda.so.1`, which is the driver's to provide, not ours. `libnuma1` and
`libelf1` are ordinary distribution packages; a missing one produces a clear
"cannot open shared object file" rather than something subtler, which is why
they are not bundled.

An AMD pack carries rocBLAS's Tensile kernel files as well as the shared
libraries. Those kernels live in separate files rather than inside
`librocblas.so`, so a pack without them loads and then fails on the first
matrix multiply. They are the bulk of the download — roughly 290 MB per GPU
generation — which is why the packs are split rather than combined.

Check what you have:

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv   # NVIDIA
vulkaninfo --summary | head -30                        # anything else
```

NVIDIA cards of compute capability **6.x and older** (GTX 10xx, P100) are not
supported by any CUDA pack. The Vulkan pack may still drive them.

**There is deliberately no catch-all pack.** A build carrying PTX for
"everything newer" would be compiled by the driver on first load, which is slow,
unpredictable, and under Windows WDDM runs into the display driver's timeout
watchdog. A pack that does not fit your card tells you so immediately instead.

## Installing

The pack has the same layout as the server package, so it merges into it:

```bash
tar -xzf cage-backend-cuda-sm89_sm90-0.1.1-linux-x64.tar.gz
cd cage-backend-cuda-sm89_sm90-0.1.1-linux-x64
cp bin/libcage-llama-*.so  /opt/cage/bin/
cp lib/*                   /opt/cage/lib/
```

**Copy `lib/` as well as `bin/`.** The CUDA packs carry their own
`libcudart.so.12`, `libcublas.so.12` and `libcublasLt.so.12`, and the AMD packs
their ROCm equivalents plus `lib/rocblas/library/`, all found through a
`RUNPATH` of `$ORIGIN/../lib`. That is why no CUDA toolkit has to be installed
on the machine — but it only works if the libraries land next to the `.so` in
the layout it expects.

To keep packs somewhere else, point the server at that directory:

```bash
export CAGE_LLAMA_BACKEND_DIR=/opt/cage/backends
```

That variable is **exclusive**: it replaces the search path rather than adding
to it, so a pack in `bin/` is ignored while it is set.

## Verifying

`cage-backend-probe` ships in the server package and runs the identical load
path the server uses — what it reports is what the server will do.

```bash
/opt/cage/bin/cage-backend-probe
```

With no arguments it searches the usual locations; give it a path or directory
to check a specific pack. For each `.so` it reports:

| | |
|---|---|
| ABI fingerprint | Whether the pack matches this server build. A mismatch is refused rather than loaded |
| Backend | Which backend it is — derived from the symbols it exports, not from its filename |
| Build id | Which build it came from |
| Tensor parallelism | Whether split mode `graph` is available, or only layer split |
| Devices | How many cards it can see, how many it can actually drive, and free/total VRAM for each |

A card marked unusable is reported as *this `.so` has no device code for this
card* — which is the answer to "I downloaded the wrong pack", delivered before
you spend time loading a model.

> The probe currently prints in Traditional Chinese.

## More than one pack

You can install several. The server probes each pack it finds, per device, and
records which backend can drive which card. An AI config then binds to the
backend that suits the GPUs it selected — so a machine with an NVIDIA card and
an AMD card can drive each with the right backend, in one server.

Probing runs in a subprocess, so a pack that is broken or incompatible cannot
take the server down with it.

**One limit, stated plainly: a single AI config cannot span two architectures.**
No backend supports tensor parallelism across different GPU architectures;
mixing them would be slow *and* wrong. Select GPUs of one architecture per
config.

## Without a pack

The server starts normally. `vllm` and `remote` models work as usual. A model
with `backend="llama"` fails at load time with a message naming the pack to
download — it does not fail silently, and it does not fall back to CPU without
telling you.

If you genuinely want CPU inference, install `cage-backend-cpu`. That is a
supported configuration, not a degraded one — it is simply slow.

---

[← Inference Server](README.md) · [Backends](backends.md) · [Models](models.md) · [Server Guide](../README.md)
