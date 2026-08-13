# Safetensors models: vLLM, or GGUF conversion

The in-process `llama` backend reads GGUF and nothing else. That is a hard
limit of the library, not a policy — there is no way to load unquantized
Hugging Face weights into it. Running a safetensors model therefore needs
something else, and there are two somethings:

| | **vLLM** | **GGUF conversion** |
|---|---|---|
| How | Weights are served by a vLLM subprocess speaking OpenAI-compatible HTTP | Weights are converted to GGUF, then run by the built-in `llama` backend |
| You install | An environment with `vllm` | An environment with CPU `torch` |
| Install difficulty | Has to match your GPU generation, CUDA toolkit and torch build | A CPU wheel; no GPU involvement |
| First request costs | Model load (minutes for large models) | Conversion (minutes to hours), then model load |
| Later requests | Fast, model stays resident | Fast, model stays resident |
| Survives eviction | Respawns and reloads from disk | **Reconverts** — the GGUF is never written to disk |
| Config | `<ai><vllm><python_exe>` | `<ai><convert><python_exe>` |

**Both are optional, and the server chooses between them for you.** A request
against a `backend="vllm"` model tries vLLM first; if the vLLM environment is
not configured or does not work, the model is converted to GGUF instead. You
only get an error when neither is set up — and that error names both.

A GGUF-only deployment can skip this whole page.

---

## What counts as "vLLM does not work"

The probe runs the first time a safetensors model is used, and the answer is
cached for the life of the process. Any of these falls back to conversion:

- `<python_exe>` is empty;
- the interpreter path does not exist (or the bare name is not on `PATH`);
- that interpreter has no `vllm` module;
- **vLLM starts up and dies, and it has never successfully served a model in
  this process.** This is the case that matters on older hardware: a `vllm`
  that imports fine but needs compute capability 8.0 only reveals itself at
  spawn time. One failure is enough — the backend is marked unusable and later
  requests go straight to conversion instead of re-paying a several-minute
  failure each time.

Once any model *has* come up on vLLM, the environment is proven, and a later
startup failure is treated as that model's problem (too large, OOM) rather than
the environment's. It is reported as an error and **not** converted: a model
vLLM cannot fit is not a model that conversion will fit either.

The log says which way it went, once per server run:

```
[Vllm] backend unavailable (<ai><vllm><python_exe> is not set) — safetensors
       models will be converted to GGUF instead (restart the server after
       fixing the environment to re-probe)
[Dispatch] 'my-hf-model' is safetensors and vLLM is not an option (…) —
       converting to GGUF for the llama backend
```

The probe result is cached, so after fixing an environment you have to restart
the server for it to be noticed.

---

# Option A — vLLM

vLLM was picked because it speaks an **OpenAI-compatible HTTP API**. The server
does not implement a protocol for it — streaming, tool calls and reasoning all
go through the same client that handles remote cloud endpoints. The pool only
starts the process, waits for `/health`, and hands back a URL.

## Install

vLLM is not part of the server package. Build it its own environment — it pins
specific torch and CUDA versions, and sharing an environment with the
multimodal workers will break one or the other.

```bash
python3 -m venv /opt/cage/venvs/vllm
/opt/cage/venvs/vllm/bin/pip install --upgrade pip
/opt/cage/venvs/vllm/bin/pip install vllm
```

Conda works equally well:

```bash
conda create -n cage-vllm python=3.12 -y
conda run -n cage-vllm pip install vllm
```

Check it before wiring it up. This is the same module the server spawns, so if
this fails the server will fail identically:

```bash
/opt/cage/venvs/vllm/bin/python -c "import vllm; print(vllm.__version__)"
```

### GPU requirements — read this before picking a version

**The current vLLM release does not run on Volta (V100, sm_70).** Its V1 engine
requires compute capability 8.0; the V0 engine that supported Volta was removed.
Installing `vllm` with no version pin gets you something that will not start on
a V100 box.

| Your GPUs | Install | Notes |
|---|---|---|
| Ampere or newer (A100, RTX 30/40/50, L4, H100…) | `pip install vllm` | Latest is fine |
| Volta (V100) | `pip install "vllm==0.9.2" "transformers==4.53.2"` | Last line with the V0 engine. Also set `VLLM_USE_V1=0` |
| Turing (T4, RTX 20) | `pip install "vllm==0.9.2" "transformers==4.53.2"` | Same constraint |

**Pin `transformers` too.** vLLM 0.9.2 does not constrain it tightly enough, so a
plain install pulls the latest, which fails at startup with
`ValueError: 'aimv2' is already used by a Transformers config` — both libraries
try to register the same model name. 4.53.2 is known good.

This combination is verified working: Qwen3-0.6B safetensors on a V100,
streaming through the full graph path.

For Volta, three settings are not optional:

```xml
<vllm>
  <python_exe>/opt/cage/venvs/vllm-v100/bin/python</python_exe>
  <env>
    <!-- V1 engine requires sm_80; Volta needs the V0 path. -->
    <VLLM_USE_V1>0</VLLM_USE_V1>
  </env>
  <extra>
    <!-- Volta has no bfloat16 in hardware. A model whose config says
         bfloat16 will fail or degrade badly. -->
    <dtype>float16</dtype>
  </extra>
</vllm>
```

If you get this wrong, nothing is bricked — the model gets converted to GGUF
and runs on the `llama` backend instead. Check the log to see which happened.

FlashAttention also needs Ampere or newer; vLLM falls back to another backend
automatically on older cards. You lose throughput, not correctness.

**Mixed-GPU machines** (say four V100s and one RTX 4070) are the awkward case:
one vLLM version cannot serve both. `<python_exe>` is a single global setting,
so pick the environment that matches the cards you actually intend vLLM to use,
and pin models to those cards with the AI config's GPU visibility field — that
field does work for this backend, because it is a subprocess. A default for all
vLLM models can also go in `<env><CUDA_VISIBLE_DEVICES>`; the per-model AI
config value overrides it.

### Runtime dependencies people miss

vLLM JIT-compiles some kernels on first use, which means it shells out to
`ninja` **and** needs a CUDA toolkit that matches the torch build it pulled in.
Two failure modes, both of which surface only after the model has finished
loading:

- `No such file or directory: 'ninja'` — the package is installed but its
  executable is not on `PATH`. CAGE prepends the interpreter's directory to the
  child `PATH` for exactly this reason, so this should not happen; if it does,
  `pip install ninja` into that environment.
- `ninja: build stopped: subcommand failed` — the JIT compile itself failed,
  almost always a CUDA toolkit / torch version mismatch. Check that the CUDA
  version torch was built against (`python -c "import torch; print(torch.version.cuda)"`)
  is one your system toolkit can compile for, or install a torch build matching
  your toolkit.

## Wire it up

```xml
<ai>
  <vllm>
    <python_exe>/opt/cage/venvs/vllm/bin/python</python_exe>
    <port_base>18000</port_base>
    <ready_timeout_sec>900</ready_timeout_sec>
    <request_timeout_sec>600</request_timeout_sec>
    <extra>
      <tensor-parallel-size>4</tensor-parallel-size>
      <gpu-memory-utilization>0.90</gpu-memory-utilization>
    </extra>
  </vllm>
</ai>

<models>
  <model alias="my-hf-model" backend="vllm">
    <path>/mnt/models/Some-HF-Model</path>
    <quant>fp16</quant>
  </model>
</models>
```

`<path>` is the snapshot **directory** — the one containing `*.safetensors` and
`config.json`. The server scans it and offers the runtime quantizations
(`4bit`, `8bit`, `bf16`, `fp16`, `fp32`); which one is used comes from the AI
config that references the model, with `<quant>` as the seed default. That same
choice also drives conversion, mapped onto GGUF types — see the table below.

**Leaving `<python_exe>` empty is a normal configuration.** The server starts,
GGUF models are unaffected, and safetensors models fall back to conversion.

| Field | Default | Notes |
|---|---|---|
| `python_exe` | *(empty)* | Interpreter with `vllm` installed. Empty = fall back to conversion |
| `port_base` | `18000` | Each model takes a free port from here upward. 64 are probed |
| `ready_timeout_sec` | `900` | How long to wait for `/health`. Large models take minutes |
| `request_timeout_sec` | `600` | Per-inference ceiling |
| `extra` | — | Passed straight through as `--key value` |
| `env` | — | Exported to the subprocess (`VLLM_USE_V1`, `CUDA_VISIBLE_DEVICES`…) |

`<extra>` is not filtered. Any vLLM flag works, because a whitelist would
inevitably block the one you need. `tensor-parallel-size` is the usual one:
set it to how many GPUs the model should be split across.

### GPU selection

Unlike the in-process `llama` backend, **per-model GPU pinning works here**.
vLLM is a subprocess, so `CUDA_VISIBLE_DEVICES` can be set for it — the AI
config's GPU visibility field is applied at spawn. (The in-process backend
cannot do this: CUDA reads that variable when the server process starts.)

## Lifecycle

Same shape as the GGUF pool, deliberately:

- **Lazy.** Nothing spawns at startup. The first request against a model starts
  its server and blocks until `/health` answers.
- **Budgeted.** VRAM is reserved *before* spawning, so an over-subscribed box
  fails immediately instead of spending minutes loading and then hitting OOM.
  Eviction terminates the process.
- **Self-healing.** If the process dies on its own (OOM, CUDA fault), the next
  request notices and respawns rather than talking to a dead port.

Each model logs to `<modality_temp_dir>/vllm-<alias>.log`. When a startup
fails, that file has the real reason — the error surfaced to the client points
at it rather than repeating a truncated traceback.

---

# Option B — GGUF conversion

The fallback converts the Hugging Face weights to GGUF and hands them to the
`llama` backend that is already compiled into the server. Conversion runs
llama.cpp's own `convert_hf_to_gguf.py`, which knows several hundred
architectures and tokenizer layouts.

## Install

Much lighter than vLLM: no GPU, no CUDA matching, a CPU torch wheel is enough.

```bash
python3 -m venv /opt/cage/venvs/convert
/opt/cage/venvs/convert/bin/pip install torch \
    --index-url https://download.pytorch.org/whl/cpu
/opt/cage/venvs/convert/bin/pip install numpy transformers \
    sentencepiece protobuf
```

Only `torch` and `numpy` are probed up front. `transformers`, `sentencepiece`
and `protobuf` are needed by *some* architectures' tokenizer conversion; if one
is missing you get a conversion failure naming it in the log rather than a
blanket refusal.

An environment that already has torch works — including a vLLM environment that
turned out not to run on your cards.

## Wire it up

```xml
<ai>
  <convert>
    <python_exe>/opt/cage/venvs/convert/bin/python</python_exe>
    <script_path></script_path>
    <tmp_dir>/dev/shm/cage-convert</tmp_dir>
    <timeout_sec>7200</timeout_sec>
    <env>
      <!-- <HF_HOME>/mnt/models/hf-cache</HF_HOME> -->
    </env>
  </convert>
</ai>
```

| Field | Default | Notes |
|---|---|---|
| `python_exe` | *(empty)* | Interpreter, **or a full command** — `conda run -n cage-convert python` works. Empty = conversion unavailable |
| `script_path` | *(bundled)* | `convert_hf_to_gguf.py`. The path to the vendored copy is compiled in; set this only when the server is installed without its source tree |
| `tmp_dir` | `/dev/shm/cage-convert` | Where the GGUF is written. **Must be a memory filesystem** for the no-disk guarantee to hold |
| `timeout_sec` | `7200` | Per-conversion ceiling. Raise it for very large models |
| `env` | — | Exported to the conversion subprocess |

Because `python_exe` accepts a command, conda environments without a directly
executable `python` path are fine.

## The product is never written to disk

The converted GGUF goes to `tmp_dir`, which defaults to tmpfs — memory — and is
**unlinked as soon as llama has loaded it**. The mapping stays valid; the kernel
reclaims those pages when the model is released. Consequences worth knowing:

- Nothing of yours grows. No cache directory to manage, and no stale GGUF that
  disagrees with weights you have since replaced.
- Converted models load with **mmap off**. Otherwise the tmpfs pages and
  llama's own copy would both be resident and you would pay for the weights
  twice.
- **Eviction means reconversion.** When the budget evicts a converted model,
  its file is already gone, so the next request converts again. Pin models you
  cannot afford to reconvert (`<model pinned="true">`), or install vLLM.
- `tmp_dir` needs room *while converting*, and that room is RAM. `/dev/shm`
  defaults to half of physical memory on most distributions; the server checks
  free space first and refuses with the number it needed rather than dying
  three quarters of the way through.
- Leftovers from a hard kill (`SIGKILL`, power loss) are swept at startup —
  only files the server itself wrote (`cage-*.gguf`), so a shared `tmp_dir` is
  not clobbered.

## Which GGUF type you get

The AI config's quantization choice is honoured; it maps onto the nearest GGUF
type. `4bit` cannot be produced by the script directly, so it is a two-step:
convert to f16, then quantize in-process with llama.cpp's own quantizer, and
delete the f16 the moment it is consumed.

| AI config quantization | GGUF type | Steps | Peak `tmp_dir` use (16-bit source) |
|---|---|---|---|
| `4bit`, `4bit-fp4` | `Q4_K_M` | convert → quantize | ~1.35× source |
| `8bit` | `Q8_0` | convert | ~0.55× source |
| `fp16` | `F16` | convert | ~1.05× source |
| `bf16` | `BF16` | convert | ~1.05× source |
| `fp32` | `F32` | convert | ~2× source |

`4bit-fp4` has no GGUF equivalent and produces `Q4_K_M` with a warning. The
quantization id you picked is what the model reports as loaded, so the UI still
shows your choice.

Progress goes to `<modality_temp_dir>/convert-<alias>.log`, and only one
conversion runs at a time — two large ones in parallel would just fight over
the same CPU and the same tmpfs.

---

## Docker

The image ships neither vLLM nor a conversion environment. Build whichever you
want into the mounted `/venvs` volume, the same place the multimodal worker
environments live, so it survives image upgrades:

```bash
# Option A
docker compose exec cage python3 -m venv /venvs/vllm
docker compose exec cage /venvs/vllm/bin/pip install vllm

# Option B (much smaller)
docker compose exec cage python3 -m venv /venvs/convert
docker compose exec cage /venvs/convert/bin/pip install torch \
    --index-url https://download.pytorch.org/whl/cpu
docker compose exec cage /venvs/convert/bin/pip install numpy \
    transformers sentencepiece protobuf
```

Then point the config at it. With the bundled compose file that means setting
`VLLM_PYTHON` in `.env`:

```
VLLM_PYTHON=/venvs/vllm/bin/python
```

The entrypoint substitutes it into `config.xml` on first start. If you already
have a generated `config.xml` in `${STATE_DIR}`, edit
`<ai><vllm><python_exe>` — or `<ai><convert><python_exe>` — there instead; the
template is only applied when the file does not exist yet.

Container specifics:

- **The image must be the `-devel` variant** if you build vLLM inside it. Some
  of its dependencies compile against `nvcc`. The conversion environment does
  not need this.
- **`/venvs` must be on ext4/xfs.** Same constraint as the rest of `STATE_DIR`
  — pip installs into a bind mount on exFAT or NTFS fail on symlinks.
- **`/dev/shm` must be big enough** for whichever path you use: vLLM wants a
  decent one for tensor-parallel setups, and conversion writes its GGUF there.
  The bundled compose file sets `shm_size`; if you wrote your own, add it — the
  default 64 MB is not enough for either.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `has no engine to run on` | Neither `<vllm><python_exe>` nor `<convert><python_exe>` is usable. The message states both reasons |
| Model converts when you expected vLLM to serve it | The probe rejected the environment. The `[Vllm] backend unavailable (…)` line at the top of the log says why |
| Environment fixed, still converting | The probe is cached per process — restart the server |
| `vLLM exited during startup` | Read the log path in the message. Usually `ModuleNotFoundError: No module named 'vllm'` — wrong interpreter |
| `vLLM did not become ready within Ns` | Model larger than the timeout allows, or it is silently stuck. The log tells which. Raise `ready_timeout_sec` |
| `no free port in [N, N+64)` | 64 consecutive ports from `port_base` are all occupied |
| Loads, then OOM mid-request | `gpu-memory-utilization` too high, or the budget's estimate was low. Set `est_vram_mb` on the model |
| Garbage output on a V100 | bfloat16 on hardware that lacks it — force `float16` |
| `not enough room in /dev/shm/…` | Conversion needs that much *memory*. Enlarge tmpfs, move `tmp_dir`, pick a smaller quantization, or install vLLM |
| `convert_hf_to_gguf.py exited N` | See the log path in the message. Commonly a missing `transformers` / `sentencepiece` / `protobuf`, or an architecture the bundled script does not know |
| Same model reconverts repeatedly | It is being evicted between requests. Pin it, or raise the budget |

---

[← Inference Server](README.md) · [Backends](backends.md) · [Python workers](workers.md) · [Server Guide](../README.md)
