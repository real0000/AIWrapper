# vLLM (safetensors models)

The in-process `llama` backend reads GGUF and nothing else. That is a hard
limit of the library, not a policy — there is no way to load unquantized
Hugging Face weights into it. Running a safetensors model therefore needs a
second engine, and a second engine necessarily means a second process: it
brings its own CUDA context and its own Python runtime.

vLLM was picked because it speaks an **OpenAI-compatible HTTP API**. The server
does not implement a protocol for it — streaming, tool calls and reasoning all
go through the same client that handles remote cloud endpoints. The pool only
starts the process, waits for `/health`, and hands back a URL.

You only need this if you actually run safetensors models. A GGUF-only
deployment can skip the whole page.

---

## Install

vLLM is not part of the server package. Build it its own environment — it pins
specific torch and CUDA versions, and sharing an environment with the
multimodal workers will break one or the other.

```bash
python3 -m venv /opt/aiwrapper/venvs/vllm
/opt/aiwrapper/venvs/vllm/bin/pip install --upgrade pip
/opt/aiwrapper/venvs/vllm/bin/pip install vllm
```

Conda works equally well:

```bash
conda create -n cage-vllm python=3.12 -y
conda run -n cage-vllm pip install vllm
```

Check it before wiring it up. This is the same module the server spawns, so if
this fails the server will fail identically:

```bash
/opt/aiwrapper/venvs/vllm/bin/python -c "import vllm; print(vllm.__version__)"
```

### GPU requirements

vLLM needs compute capability 7.0 or newer. Two things bite on older cards:

- **Volta (V100, sm_70) has no bfloat16 in hardware.** A model whose config
  says `bfloat16` will fail or fall back badly. Force half precision — either
  pick the `fp16` quantization in the AI config, or set a default:
  `<vllm><extra><dtype>float16</dtype></extra></vllm>`.
- **FlashAttention needs Ampere or newer.** vLLM falls back automatically on
  older cards; you lose throughput, not correctness.

---

## Wire it up

```xml
<ai>
  <vllm>
    <python_exe>/opt/aiwrapper/venvs/vllm/bin/python</python_exe>
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
config that references the model, with `<quant>` as the seed default.

**Leaving `<python_exe>` empty disables the backend.** The server still starts
and everything else works; a request against a `vllm` model returns a message
telling you to set it.

| Field | Default | Notes |
|---|---|---|
| `python_exe` | *(empty)* | Interpreter with `vllm` installed. Empty = backend disabled |
| `port_base` | `18000` | Each model takes a free port from here upward. 64 are probed |
| `ready_timeout_sec` | `900` | How long to wait for `/health`. Large models take minutes |
| `request_timeout_sec` | `600` | Per-inference ceiling |
| `extra` | — | Passed straight through as `--key value` |

`<extra>` is not filtered. Any vLLM flag works, because a whitelist would
inevitably block the one you need. `tensor-parallel-size` is the usual one:
set it to how many GPUs the model should be split across.

### GPU selection

Unlike the in-process `llama` backend, **per-model GPU pinning works here**.
vLLM is a subprocess, so `CUDA_VISIBLE_DEVICES` can be set for it — the AI
config's GPU visibility field is applied at spawn. (The in-process backend
cannot do this: CUDA reads that variable when the server process starts.)

---

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

## Docker

The image does not ship vLLM. It is several GB of wheels on top of a specific
torch build, and most deployments do not need it.

Build it into the mounted `/venvs` volume, the same place the multimodal worker
environments live, so it survives image upgrades:

```bash
docker compose exec aiwrapper python3 -m venv /venvs/vllm
docker compose exec aiwrapper /venvs/vllm/bin/pip install vllm
```

Then point the config at it. With the bundled compose file that means setting
`VLLM_PYTHON` in `.env`:

```
VLLM_PYTHON=/venvs/vllm/bin/python
```

The entrypoint substitutes it into `config.xml` on first start. If you already
have a generated `config.xml` in `${STATE_DIR}`, edit
`<ai><vllm><python_exe>` there instead — the template is only applied when the
file does not exist yet.

Two container specifics:

- **The image must be the `-devel` variant** if you build vLLM inside it. Some
  of its dependencies compile against `nvcc`.
- **`/venvs` must be on ext4/xfs.** Same constraint as the rest of `STATE_DIR`
  — pip installs into a bind mount on exFAT or NTFS fail on symlinks.

vLLM also wants a decent `/dev/shm`; the bundled compose file already sets
`shm_size`. If you wrote your own, add it — the default 64 MB is not enough for
tensor-parallel setups.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `vLLM backend is not configured` | `<python_exe>` is empty |
| `vLLM exited during startup` | Read the log path in the message. Usually `ModuleNotFoundError: No module named 'vllm'` — wrong interpreter |
| `vLLM did not become ready within Ns` | Model larger than the timeout allows, or it is silently stuck. The log tells which. Raise `ready_timeout_sec` |
| `no free port in [N, N+64)` | 64 consecutive ports from `port_base` are all occupied |
| Loads, then OOM mid-request | `gpu-memory-utilization` too high, or the budget's estimate was low. Set `est_vram_mb` on the model |
| Garbage output on a V100 | bfloat16 on hardware that lacks it — force `float16` |

---

[← Inference Server](README.md) · [Backends](backends.md) · [Python workers](workers.md) · [Server Guide](../README.md)
