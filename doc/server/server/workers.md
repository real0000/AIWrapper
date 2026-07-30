# Python Workers

The server binary is self-contained. The Python workers are not — and on a fresh
machine they are the part that actually needs setting up.

Two things use them:

- the **unsloth backend**, which is how most models are run — see [Backends](backends.md)
- every **modality** (image, speech, audio, music, 3D) — see [Modalities](modalities.md)

A text-only deployment using the in-process `llama` backend needs none of this.
Anything else needs at least the `llm` family below.

---

## Use the script

The package ships `setup-workers.sh`, which builds one virtualenv per family:

```bash
cd /opt/aiwrapper
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
| `image` | `sd3_worker.py` | `stable-diffusion-cpp-python`, `diffusers`, `torch` |
| `tts` | `f5_tts_worker.py` | `f5-tts` |
| `audio` | `audioldm2_worker.py` | `diffusers`, `transformers`, `torch`, `scipy` |
| `music` | `musicgen_worker.py` | `audiocraft`, `torch`, `torchaudio` |
| `mesh-instantmesh` | `instantmesh_worker.py` | The InstantMesh repository and its requirements |
| `mesh-trellis` | `trellis_worker.py` | The TRELLIS repository and its own setup script |
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

Being explicit, because "it should work" is not the same as "it ran":

| Family | Status |
|---|---|
| `llm` | **Verified end to end.** Built from scratch into a new virtualenv, then a 7.5 GB Q8_0 GGUF loaded and generated through the server — on CPU with the auto layer count, and on a single V100 with an explicit one |
| everything else | Dependency sets are taken from what each worker imports. The installs are not verified on a clean machine |

If a family other than `llm` fails to install, the fastest diagnosis is running
its worker by hand (below) and reading the import error.

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
| Disk | A torch-based family is 5–8 GB installed; all of them together is tens of GB |

The script checks each of these and tells you which are missing before it starts
building anything.

## The mesh families are different

`mesh-instantmesh`, `mesh-trellis` and `mesh-hy3d` need an upstream repository
on `sys.path`, not just pip packages — the worker imports `src`, `trellis` and
`hy3dgen` from the cloned tree. That path goes into `config.xml`:

```xml
<modality alias="trellis-image-large">
  <python_exe>/opt/aiwrapper/venvs/mesh-trellis/bin/python</python_exe>
  <extra><repo>/opt/aiwrapper/venvs/repos/TRELLIS</repo></extra>
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
venvs/image/bin/python python/sd3_worker.py --help
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
5. **The model path is wrong** — that is a different failure, reported at
   startup as a scan error. See [Models](models.md).

The server captures each worker's stderr into its own log, so the real Python
traceback is there even though the client only sees a failed request.

---

[← Inference Server](README.md) · [Backends](backends.md) · [Modalities](modalities.md) · [Server Guide](../README.md)
