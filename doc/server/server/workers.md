# Python Workers

The server binary is self-contained. The Python workers are not — and on a fresh
machine they are the part that actually needs setting up.

They serve the **modalities** — image, speech, audio, music, 3D. See
[Modalities](modalities.md).

Language models do not use them any more. GGUF runs in-process on the `llama`
backend, and safetensors runs either on **vLLM** or through **GGUF conversion**
— both optional, both installed separately and never through
`setup-workers.sh`: they pin their own torch and will fight with these
environments. See [Safetensors models](vllm.md).

> The `llm` and `llm-hf` families below belonged to the removed `unsloth`
> backend. They are documented here only for older installs; a current
> deployment does not build them.

A text-only deployment needs none of this.

---

## 2026-09-05: five families removed

`image`, `tts`, `audio`, `music` and `mesh-trellis` are gone, for two different
reasons.

**Replaced by C++.** `sd.cpp`, `audio.cpp` and `trellis.cpp` now share
`ik_llama.cpp`'s ggml and are built into the server itself, so they need no
venv, no torch and no cloned repository:

| Was | Now |
|---|---|
| `image` — `sd3_worker.py` | sd.cpp (`VERSION_SD3`) |
| `tts` — `f5_tts_worker.py` | audio.cpp (`community_models/f5_tts`) |
| `mesh-trellis` — `trellis_worker.py` | trellis.cpp (TRELLIS.2) |

TRELLIS **v1** was retired with the worker: trellis.cpp implements TRELLIS.2
only, and v1 is its predecessor rather than a separate capability.

**Non-commercial weights.** `audio` ran AudioLDM2 (CC-BY-NC-SA-4.0) and `music`
ran Stable Audio Open, which had already replaced MusicGen (CC-BY-NC-4.0) for
the same reason. Neither is worth a setup path.

A side effect worth recording: the whole "TRELLIS's copyleft dependencies"
problem is gone with it. `pymeshfix` (AGPL-3.0), `igraph` (GPL) and `plyfile`
(GPL) were module-scope imports that `patch_trellis_licence.py` had to rewrite
as lazy so a deployment need not install them. trellis.cpp has no counterpart to
decouple: hole filling is its own centroid-fan implementation, PLY writing is
its own `fprintf`, and the graph walk igraph did is an `unordered_map`.

⚠ The C++ side has **no C boundary yet** — the three projects expose C++ APIs
that `dlsym` cannot reach, so they are compiled but not yet called. Until that
layer lands the server has no image, TTS or 3D capability. This is an accepted
gap, not an oversight.

## Use the script

The package ships `setup-workers.sh`, which builds one virtualenv per family:

```bash
cd /opt/cage
./setup-workers.sh --list                       # what exists and what it needs
./setup-workers.sh                              # llm only — the text/code path
./setup-workers.sh --families llm,image,tts
./setup-workers.sh --families all
```

| Option | Meaning |
|---|---|
| `--prefix DIR` | Where the venvs go (default `<install dir>/venvs`) |
| `--python PATH` | Base interpreter (default `python3`) |
| `--families LIST` | Comma-separated, or `all` (default `llm`) |
| `--cuda-archs LIST` | Override GPU arch detection, e.g. `70-real;89-virtual` |

When it finishes it prints the exact `config.xml` lines to paste — the
`<python_exe>` for the LLM backend, and a `<python_exe>` plus `<extra><repo>`
for each modality.

## One environment per family

Not a stylistic choice. These families pin incompatible versions of torch,
transformers and CUDA extensions; a single shared environment reliably ends up
working for one and broken for another. The script keeps them apart, and
`config.xml` lets every modality name its own interpreter for the same reason.

| Family | Worker | Needs |
|---|---|---|
| `llm` | `unsloth_worker.py`, GGUF path | `llama-cpp-python` built for your GPUs, `jinja2` |
| `llm-hf` | `unsloth_worker.py`, safetensors path | `torch`, `transformers`, `unsloth`, `bitsandbytes`, `accelerate` |
| ~~`mesh-instantmesh`~~ | `instantmesh_worker.py` | **Disabled** — its multi-view model has no licence (below) |
| `mesh-hy3d` | `hy3d_worker.py` | The Hunyuan3D-2 repository (`hy3dgen`) |

**GGUF and safetensors are separate families** because the GGUF path
deliberately never imports the `unsloth` library — importing it pulls in a torch
stack that the llama.cpp path does not need and that has produced spurious load
failures. If you only run GGUF models, `llm` alone is enough.

## The llm family, in detail

This is the one that matters most, and the one with a real build step.

`llama-cpp-python` is compiled from source against your GPUs. The script detects
the compute capabilities present with `nvidia-smi`, filters them against what
your `nvcc` supports, and passes the result through:

```bash
CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=<detected> -DGGML_CUDA_FA=on" \
FORCE_CMAKE=1 pip install --no-cache-dir llama-cpp-python
```

Expect several minutes of CUDA compilation.

**The arch list is not optional.** A wheel built without your card's
architecture loads and then fails at inference time, which is a confusing way to
discover the problem. If you move the install to different hardware, rebuild
this family.

With no `nvcc` on `PATH`, the script still builds — CPU-only, and says so. That
works, and it is slow enough that you will not want it for real use.

## What has been tested

Every family was installed from scratch into a new virtualenv on a machine with
CUDA 12.0 and Python 3.11, then checked by importing what its worker imports.

| Family | Result |
|---|---|
| `llm` | **Verified end to end** — built, then a 7.5 GB Q8_0 GGUF loaded and generated through the server |
| `llm-hf` | Installs; `unsloth`, `transformers` and `torch` import with CUDA available |
| ~~`mesh-instantmesh`~~ | **Disabled on licensing grounds** — installed cleanly before that, so this is not a build failure |
| `mesh-hy3d` | Installs; `hy3dgen` imports from the clone |

Getting there took six fixes to this script, which is the honest summary of what
a fresh machine runs into:

| What broke | Why |
|---|---|
| `venv` creation | Debian/Ubuntu ship `venv` without `ensurepip`; the module imports fine and creation still fails |
| Re-runs after a failure | A half-made venv has an interpreter but no pip, and was being silently reused |
| `nvdiffrast` | Compiles a torch CUDA extension, so it needs `--no-build-isolation` to see torch |
| `nvdiffrast`, again | Plain `pip install torch` fetched a **cu130** wheel against a **12.0** toolkit — a major mismatch it refuses to build against. The script now picks a torch wheel matching the local `nvcc` |
| `rembg` | Imports `onnxruntime`, which InstantMesh's requirements do not list |
| `pytorch-lightning` | Calls `pkg_resources`, removed in setuptools 81 — pinned below that |

### mesh-instantmesh is disabled

It does not install, `--families all` skips it, and `CMakeLists.txt` no longer
clones the repository. Asking for it by name prints the reason and exits
non-zero rather than failing obscurely.

InstantMesh's own code is Apache-2.0 and its checkpoints are Apache-2.0 — which
is why this took a second look to catch. The problem is what it loads at
runtime: the multi-view stage is `sudo-ai/zero123plus-v1.2`, whose repository
publishes **no licence at all** — no `LICENSE` file, no license field on the
model card.

**No licence is worse than a restrictive one.** A restrictive licence grants
something under conditions; silence grants nothing, so there is no basis on
which to copy, run or distribute the weights. Nothing on our side can fix a
property of the upstream model.

The worker script is kept rather than deleted, so the family can be revived in
one step if zero123plus is ever published under a licence. To install it anyway
— you have a grant from the authors, or you are in a non-commercial setting and
accept the risk:

```bash
CAGE_ALLOW_UNLICENSED_MODELS=1 ./setup-workers.sh --families mesh-instantmesh
```

**Use `mesh-trellis` instead.** MIT code, MIT weights, copyleft dependencies
decoupled — it is the better-licensed backend and the better model.

### Sizes, measured

| Family | Installed |
|---|---|
| `llm` | 1.9 GB |
| `mesh-hy3d` | 6.1 GB |
| `mesh-instantmesh` | 6.3 GB |
| `llm-hf` | 9.5 GB |

(Measured before the 2026-09-05 removal below; the families that are left
come to roughly 18 GB.)

## A trap worth knowing: auto GPU layers

`n_gpu_layers = -1` means "estimate from free VRAM". On a host where that
estimate cannot read VRAM properly it resolves to **0**, and the model loads
entirely on the CPU — no error, just slow. In the test above the same model and
the same environment gave:

| GPU layers | Load + generate |
|---|---|
| `-1`, resolved to 0 | 43 s |
| `29`, explicit | 3.4 s |

The resolved value is in the server log, and it is the first thing to check when
inference is unexpectedly slow:

```
[unsloth] n_ctx=4096 n_gpu_layers=-1->0 flash_attn=True ...
                                  ^^^^ auto resolved to CPU-only
```

Fix it by setting GPU Layers explicitly, or by turning on **Auto Fit**, which
measures placement with a dry run instead of estimating. See
[AI Configs](../../client/ai-config.md#gpu-placement).

## Prerequisites

| | |
|---|---|
| Python | 3.10–3.12, with `venv`. On Debian/Ubuntu that is a separate package: `apt install python3-venv` |
| CUDA toolkit | `nvcc` on `PATH`, for GPU builds of `llama-cpp-python` and `stable-diffusion-cpp-python` |
| git | For the three mesh families |
| ffmpeg | Runtime dependency of `tts`; `music` additionally needs the `libav*-dev` headers to build |
| Disk | Measured per family below — about 46 GB for all of them |

The script checks each of these and tells you which are missing before it starts
building anything.

## The mesh families are different

`mesh-instantmesh`, `mesh-trellis` and `mesh-hy3d` need an upstream repository
on `sys.path`, not just pip packages — the worker imports `src`, `trellis` and
`hy3dgen` from the cloned tree. That path goes into `config.xml`:

```xml
<modality alias="trellis-image-large">
  <python_exe>/opt/cage/venvs/mesh-trellis/bin/python</python_exe>
  <extra><repo>/opt/cage/venvs/repos/TRELLIS</repo></extra>
</modality>
```

The script clones each repository and installs what it declares, but **upstream
is the authority** — these projects carry CUDA extensions, change their
requirements, and in TRELLIS's case ship an interactive `setup.sh` that the
script deliberately does not run for you. It prints the command instead.

Treat these three as "expect to read the upstream README". The other six are
ordinary pip installs.

## Checking a family without the server

Each worker runs standalone, which is the fastest way to find out whether an
environment is sound:

```bash
venvs/llm/bin/python python/unsloth_worker.py --help
venvs/mesh-hy3d/bin/python python/hy3d_worker.py --help
```

If the imports are wrong you get a traceback immediately, with the missing
package named. Going through the server instead gives you a generic worker
failure and sends you to the log.

Once a family is installed and named in `config.xml`, restart the server and use
the Logic Editor's ▶ test on an AI config that targets it. That loads the model
for real, which is the only check that proves the whole path.

## When a worker will not start

In order of likelihood:

1. **`<python_exe>` points at the wrong interpreter.** The single most common
   cause. It must be the venv's `bin/python`, not the system one.
2. **The family was never installed.** Run the worker by hand as above.
3. **`llama-cpp-python` was built without your GPU's architecture.** It loads,
   then fails during inference. Rebuild the `llm` family.
4. **A mesh repo is missing or its path is wrong.** Check `<extra><repo>`.
5. **TRELLIS specifically** — upstream's `setup.sh` was never run, so `trellis`
   does not import. See above.
6. **The model path is wrong** — that is a different failure, reported at
   startup as a scan error. See [Models](models.md).

The server captures each worker's stderr into its own log, so the real Python
traceback is there even though the client only sees a failed request.

---

[← Inference Server](README.md) · [Backends](backends.md) · [Modalities](modalities.md) · [Server Guide](../README.md)
