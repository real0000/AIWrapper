**English** · [繁體中文](backend-packs.zh-TW.md)

# Backend Packs

Every local model — GGUF or safetensors, text or generative — needs a **backend
pack**: a second download that carries the compiled GPU code for your hardware.
The server package does not contain any.

This is not an optional extra for most installations. Without a pack the server
starts and runs, but only the `remote` backend works; anything with
a local model fails to load with a message naming the pack to fetch.

> **The pack must match the server version.** A pack from an earlier release is
> refused at load time. The message depends on how old it is — a 0.1.1 pack
> reports `missing chat-template symbols […]`, a 0.1.2 pack
> `Missing the CAGE backend identity symbols […]` — and either way the fix is to
> download the backend pack that matches this server.
>
> This is deliberate. From 0.1.2 the tool-call format is taken from each model's
> own chat template, and the code that reads it lives **inside the pack**. An
> older pack has no such code, so the server would have to fall back to guessing
> the format — which is exactly the failure mode 0.1.2 removes. Refusing to load
> is easier to diagnose than tool calls that quietly stop working. Upgrading the
> server means re-downloading the pack.

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
1.2–1.5 GB unpacked — two architectures' kernels plus the CUDA libraries it
carries; the Vulkan and CPU packs are about 140 MB and 120 MB.

## Choosing one

| Pack | Hardware | Compute capability |
|---|---|---|
| `cage-backend-cuda-sm60_sm61` | P40, P100, P4, GTX 10xx | 6.0, 6.1 |
| `cage-backend-cuda-sm70_sm75` | V100, Titan V, T4, RTX 20xx, GTX 16xx, Quadro RTX | 7.0, 7.5 |
| `cage-backend-cuda-sm80_sm86` | A100, A30, A40, A10, RTX 30xx | 8.0, 8.6 |
| `cage-backend-cuda-sm89_sm90` | L40, L40S, L4, RTX 40xx, H100, H200 | 8.9, 9.0 |
| `cage-backend-cuda-sm120_sm121` | RTX 50xx, GB10 (DGX Spark) | 12.0, 12.1 |
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
> load, resolve every symbol and report their own identity correctly — checked
> in a clean container on a machine with no AMD hardware. Whether the Linux packs
> *compute correctly*, and how fast, has not been tested on AMD. A Windows build
> of the gfx1150 pack has run on a Radeon 890M — see
> [What has been verified](../../verification-status.md). Treat them as a request
> for field reports, not as a supported configuration.

**Host prerequisites for AMD.** Unlike the CUDA packs, which need only the
NVIDIA driver, the HIP packs need a few libraries that are not theirs to ship:

```bash
sudo apt install libdrm2 libdrm-amdgpu1 libnuma1 libelf1      # Debian, Ubuntu
sudo dnf install libdrm numactl-libs elfutils-libelf          # RHEL, AlmaLinux, Rocky, Fedora
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

NVIDIA cards of compute capability **5.x and older** (Maxwell: GTX 9xx, M40) are
not supported by any CUDA pack. The Vulkan pack may still drive them.

### Pascal, and the P40 in particular

A Tesla P40 is 24 GB for very little money, and its natural job here is **the
embedding model behind retrieval, or the model that summarises shared memory** —
not the chat model. Two properties of the card decide that:

- **FP16 runs at 1/64 of FP32.** The kernels know this and keep a P40 on its FP32
  and INT8 paths, so nothing breaks; but it rules out the half-precision tricks
  that make the newer cards fast at large models.
- **No tensor cores.** Same consequence, same handling.

An embedding model is small, runs one forward pass per chunk, and is far more
sensitive to having its own memory than to raw speed — which is what a P40 has.

A P40 is usually a **second** card next to a newer one, so it usually means two
packs installed side by side: this one, and the one for your main cards. That is
supported. Each AI config is served by whichever installed pack drives the GPUs
it selects; there is nothing to configure beyond picking the P40 on the AI
config that should use it.

**There is deliberately no catch-all pack.** A build carrying PTX for
"everything newer" would be compiled by the driver on first load, which is slow,
unpredictable, and under Windows WDDM runs into the display driver's timeout
watchdog. A pack that does not fit your card tells you so immediately instead.

## Installing

The pack has the same layout as the server package, so it merges into it:

```bash
tar -xzf cage-backend-cuda-sm89_sm90-0.2.0-linux-x64.tar.gz
cd cage-backend-cuda-sm89_sm90-0.2.0-linux-x64
cp bin/libcage-backend-*.so  /opt/cage/bin/
cp -r lib/*                /opt/cage/lib/
```

### More than one pack

Install as many as the machine needs — a P40 next to a V100, two AMD
generations, a CUDA pack next to the Vulkan one. **Each pack's library is named
after the pack** (`libcage-backend-cuda-sm60_sm61.so`,
`libcage-backend-cuda-sm70_sm75.so`, …), so they sit side by side in `bin/`. The
server loads all of them and serves each AI config with whichever one drives the
GPUs that config selects.

The packs' `lib/` directories overlap by name. Every CUDA pack except the
Blackwell one is built against the same CUDA runtime, so those files are
identical and the order does not matter. **If `cuda-sm120_sm121` is one of the
packs, copy its `lib/` last**: it carries a newer CUDA 12 runtime, which the
older packs can use, while theirs has no kernels for Blackwell.

**Upgrading from 0.1.x:** delete `bin/libcage-backend-cuda.so` and
`bin/libcage-backend-hip.so` if they are there. 0.1.x named every CUDA pack the
same, so a 0.2.0 pack no longer replaces that file. The server refuses it on its
own — it predates the current backend interface — but it stays in the probe's
report until it is removed.

**Copy `lib/` as well as `bin/`.** The CUDA packs carry their own
`libcudart.so.12`, `libcublas.so.12`, `libcublasLt.so.12` and `libcufft.so.11`, and the AMD packs
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

With no arguments it looks in its own directory — the `bin/` the packs are
installed into — and in the current directory; give it a path or directory to
check a specific pack. For each `.so` it reports:

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

The server starts normally. `remote` models work as usual. A model
that runs locally fails at load time with a message naming the pack to
download — it does not fail silently, and it does not fall back to CPU without
telling you.

If you genuinely want CPU inference, install `cage-backend-cpu`. That is a
supported configuration, not a degraded one — it is simply slow.

---

[← Inference Server](README.md) · [Backends](backends.md) · [Models](models.md) · [Server Guide](../README.md)
