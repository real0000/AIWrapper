# Docker

Run the whole server side in containers, built from a Dockerfile you have. No
image is published and nothing is pulled from a private registry — the only
outside image is the official `mysql`.

Files are in [`docker/`](../../docker/).

> **Verified.** Built and run on Docker 29.6 with Compose v5.3 and the NVIDIA
> Container Toolkit: the stack comes up, MySQL-backed accounts work, all five
> GPUs are visible inside the container, and a 7.5 GB Q8_0 GGUF loads and
> generates in 2.9 s through the containerised server. Details in
> [What was tested](#what-was-tested).

---

## Quick start

```bash
cd release/docker
cp ../dist/cage-server-0.1.1-linux-x64.tar.gz .   # the package
cp .env.example .env                                    # then edit it
docker compose up -d --build
```

Three things must be set in `.env`:

| Variable | Meaning |
|---|---|
| `MODELS_DIR` | Host directory holding your models — mounted read-only at `/models` |
| `STATE_DIR` | Where the database, config, data and worker environments live. **Must be on ext4/xfs — a bind mount onto exFAT or NTFS fails**, so it is kept separate from wherever you unpacked this |
| `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD` | Any non-empty values; only these two containers use them |
| `ADMIN_PASSWORD` | Control-plane web UI login. Empty disables authentication |

Then:

```bash
docker compose logs -f cage       # watch it come up
curl http://127.0.0.1:15963/health     # {"status":"ok"}
```

The web UI is at `http://127.0.0.1:8088/`. Point the VSCode extension at
`localhost` port `15963`.

Set `PUID`/`PGID` to your own `id -u` / `id -g` as well, unless you like editing
root-owned files: the container runs as root and everything it creates in those
folders would otherwise belong to root.

## Requirements

| | |
|---|---|
| Docker | With Compose v2 (`docker compose`, not `docker-compose`) |
| NVIDIA Container Toolkit | For GPU access. Without it, drop the `deploy.resources` block and everything runs on CPU |
| Driver | Any CUDA 12.x driver, 525.60.13 or newer |
| GPU | Compute capability 7.0 or newer — see [supported GPUs](../server-install.md#supported-gpus) |
| Disk | 13.1 GB image, plus the worker environments (1.9 GB for `llm`) and your models |

The base image is `nvidia/cuda:12.6.3-devel-ubuntu24.04`, and both halves of that
matter:

- **ubuntu24.04** — the server binary needs `GLIBC_2.38`. Ubuntu 22.04 ships 2.35
  and the binary will not start on it.
- **-devel** — `nvcc` is needed to build the Python worker environments inside
  the container, which is the normal way to use this. If you build them
  elsewhere and mount `/venvs`, `-runtime` gives a much smaller image.

CUDA 12.x containers work with any 12.x driver, so the image's CUDA version does
not have to match your host toolkit.

## What is mounted where

Everything that matters is a host folder, so containers stay disposable.

| Host | Container | Holds |
|---|---|---|
| `${STATE_DIR}/config` | `/config` | `config.xml`, `control.xml` — seeded on first start, then yours |
| `${STATE_DIR}/server` | `/opt/cage/data` | Logic graphs, workflows, retrieval vectors, the server log |
| `${STATE_DIR}/mysql` | `/var/lib/mysql` | The database |
| `${STATE_DIR}/output` | `/tmp/cage` | Generated images, audio, meshes |
| `${STATE_DIR}/venvs` | `/venvs` | Python environments: multimodal workers, and vLLM if you use it |
| `${MODELS_DIR}` | `/models` (read-only) | Your models |

**The server data mount is `/opt/cage/data`, not `/data`.** The server
resolves `data/logic_graphs`, `data/workflows` and `data/vectors` against its
working directory, so a volume anywhere else is silently ignored and the graphs
disappear the next time the container is recreated. This cost one round of
testing to find.

**`/venvs` is a volume for a reason.** Building every worker family is about
46 GB and recompiles CUDA extensions; keeping it outside the image means a
rebuild does not repeat that.

## Ports

| Port | Published by default | Purpose |
|---|---|---|
| 15963 | yes | AI API — HTTP + WebSocket. What the editor connects to |
| 8088 | yes, bound to `127.0.0.1` | Control-plane web UI |
| 15972 | no | Node agent API. Only needed if a control plane on another machine drives this node |
| 3306 | no | MySQL. Only the cage container needs it |

The web UI is bound to localhost because it can start, stop and reconfigure the
server. Publishing it more widely is a decision to make deliberately, behind a
TLS-terminating proxy.

Change any of them in `.env` (`API_PORT`, `WEB_PORT`, `AGENT_PORT`) — those are
host-side, so the container's own ports stay as the config expects.

## Safetensors models

The image ships neither engine for unquantized Hugging Face weights. GGUF
models use the in-process backend and need nothing installed; safetensors need
one of two environments, built into the `/venvs` volume so they survive image
upgrades.

**vLLM** — several GB of wheels on top of a pinned torch build:

```bash
docker compose exec cage python3 -m venv /venvs/vllm
docker compose exec cage /venvs/vllm/bin/pip install vllm
```

```
VLLM_PYTHON=/venvs/vllm/bin/python
```

**Or the conversion fallback** — a CPU torch wheel, no CUDA matching. The model
is converted to GGUF in memory on first use and served by the in-process
backend:

```bash
docker compose exec cage python3 -m venv /venvs/convert
docker compose exec cage /venvs/convert/bin/pip install torch \
    --index-url https://download.pytorch.org/whl/cpu
docker compose exec cage /venvs/convert/bin/pip install numpy \
    transformers sentencepiece protobuf
```

Set `<ai><convert><python_exe>` to `/venvs/convert/bin/python`. If both are
configured, vLLM is tried first and conversion is the fallback.

The entrypoint substitutes `VLLM_PYTHON` into `config.xml` — but **only when
generating it for the first time**. If `${STATE_DIR}/config.xml` already exists,
edit `<ai><vllm><python_exe>` (or `<ai><convert><python_exe>`) in it directly.

Container specifics: the **`-devel`** image variant is required if you build
vLLM (some dependencies compile against `nvcc`; the conversion environment does
not need it), and `/venvs` must be on **ext4/xfs** like the rest of `STATE_DIR`
— pip installs fail on symlinks over exFAT or NTFS. `shm_size` is already set in
the bundled compose file: tensor-parallel vLLM needs it, and conversion writes
its GGUF to `/dev/shm`.

Full details, including the Volta bfloat16 trap and what conversion costs, are
in [Safetensors models](server/vllm.md).

## Building the worker environments

The image has no worker environments; they are too large and too
hardware-specific to bake in. Build them once into the volume:

```bash
docker compose exec cage ./setup-workers.sh --list
docker compose exec cage ./setup-workers.sh --prefix /venvs
docker compose exec cage ./setup-workers.sh --prefix /venvs --families all
```

The default (`llm`) is the text and code path and is what most deployments need.
See [Python workers](server/workers.md) for what each family needs and what has
been tested.

`config.xml` already points at `/venvs/llm/bin/python`, so the `llm` family works
with no config change. Other families need their `<python_exe>` set per modality.

**The image includes the FFmpeg development headers**, so the `music` family —
which cannot be installed on a stock host without them — builds here without
extra steps.

## Adding models

Mount the host directory holding them and refer to it as `/models`:

```xml
<model alias="my-coder" backend="llama">
  <path>/models/Qwen3-Coder-Next</path>
</model>
```

Edit `${STATE_DIR}/config/config.xml` and restart, or add it through the web UI. Either way
the server must restart before a new entry loads — see
[Restart to apply](agent/README.md#restart-to-apply).

`/models` is mounted read-only, so downloads through the web UI will fail. Drop
the `:ro` in the compose file if you want the agent to download models itself.

## Running without a database

Leave `MYSQL_PASSWORD` empty and remove the `mysql` service and the `depends_on`
block. The server then runs in open mode: no accounts, no per-user sessions, and
no authentication on the API. Reasonable for a single-user trial on a machine
only you can reach; not otherwise. See [Accounts](control/accounts.md).

## What was tested

| Step | Result |
|---|---|
| GPU passthrough | All 5 GPUs visible via `--gpus all`, correct compute capabilities |
| Image build | 13.1 GB, from the CUDA 12.6.3 devel base |
| Stack start | MySQL healthy, then the server; bootstrap admin seeded, `auth ENABLED` |
| Model scan | GGUF found through the read-only `/models` mount |
| Web UI | Serves on 8088 |
| Worker build in-container | `setup-workers.sh --prefix /venvs` built `llm` against nvcc 12.6 |
| Inference | 7.5 GB Q8_0 loaded on one V100, generated in **2.9 s** |
| Persistence | After `down` + `up`: config, vectors and the worker venv all survived — no CUDA recompile |

Three things broke while testing, and are fixed in these files:

| What broke | Why, and what changed |
|---|---|
| `chown ...: operation not permitted` on startup | The checkout was on exFAT, which has no Unix ownership, and Docker chowns bind-mount sources. State now lives at `STATE_DIR`, separate from the checkout |
| Logic graphs and vectors written to a throwaway path | The server resolves `data/…` against its working directory, so a volume at `/data` was simply ignored. It is now mounted at `/opt/cage/data`, which is where the server actually writes |
| `config.xml` not editable from the host | The container runs as root, so the seeded config was root-owned and mode 600 while the docs told you to edit it. `PUID`/`PGID` now hand the bind mounts to your user |

The last two are the kind that look fine until the day you need them: the first
loses your graphs on a container recreate, the second only bites when you try to
change a setting.

## Everyday commands

```bash
docker compose logs -f cage          # server, agent and control together
docker compose exec cage bash        # a shell inside
docker compose restart cage          # apply config.xml changes
docker compose down                       # stop; volumes and data stay
docker compose up -d --build              # after a new package
```

The container runs `cage-launcher --all`, so the agent, control plane and server
share one process and one log stream. Restarting the container restarts all
three.

## If something does not come up

The entrypoint prints a warning for each of the common mistakes before starting
— no database password, no admin password, no worker environment, empty
`/models`. Read those first.

| Symptom | Likely cause |
|---|---|
| Container exits immediately | Check `docker compose logs cage`. A GLIBC error means the base image was changed to 22.04 |
| `could not select device driver` at start | NVIDIA Container Toolkit is not installed, or the daemon was not restarted after installing it |
| Server starts, no GPU in the log | Same, or the `deploy.resources` block was removed |
| GGUF models never load | Check the model path is under a mounted directory; `backend` should be `llama` |
| safetensors models never load | Neither `VLLM_PYTHON` nor `<ai><convert><python_exe>` is usable — see [Safetensors models](server/vllm.md) |
| Worker dies with no error while loading | Raise `SHM_SIZE`; the 64 MB Docker default is far too small |
| Clients cannot log in | `<mysql>` differs between `config.xml` and `control.xml`. The entrypoint fills both from the same variables, so this only happens after hand-editing |
| Web UI unreachable from another machine | It is bound to `127.0.0.1` on purpose |
| `operation not permitted` mounting a folder | `STATE_DIR` is on exFAT/NTFS. Point it at an ext4/xfs path |
| Cannot edit `config.xml` from the host | Set `PUID`/`PGID` in `.env` to your `id -u` / `id -g` |

If none of that fits, the [manual install](../server-install.md) is the other
tested route.

---

[← Server Guide](README.md) · [Python workers](server/workers.md) · [Manual install](../server-install.md)
