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
cp ../dist/cage-server-0.2.0-linux-x64.tar.gz .   # the server, always

# then every backend pack you want the image to cover — one, or several
cp ../dist/cage-backend-cuda-sm89_sm90-*.tar.gz .
cp ../dist/cage-backend-cuda-sm80_sm86-*.tar.gz .
cp ../dist/cage-backend-vulkan-*.tar.gz .

cp .env.example .env                              # then edit it
docker compose up -d --build
```

**On AMD, use the other compose file** — `docker-compose.amd.yml`, complete and
ready to run, nothing to edit:

```bash
cp ../dist/cage-backend-hip-gfx1100_gfx1101_gfx1102-*.tar.gz .
docker compose -f docker-compose.amd.yml up -d --build
```

Two files rather than one with a switch, because the two are not variations of
the same thing: NVIDIA hands GPUs to a container through
nvidia-container-toolkit, while ROCm has no runtime plugin at all — the kernel
driver's device nodes are mapped in directly and the container user has to be in
the groups that own them. The AMD image also drops the CUDA base, since a HIP
pack carries its own ROCm libraries and the CUDA base would be a dozen wasted
gigabytes.

Check the host can see the cards first — `ls /dev/kfd /dev/dri`. No `/dev/kfd`
means the amdgpu driver is not loaded, and no amount of container configuration
will help.

**The server package carries no GPU code**, so the image needs at least one
[backend pack](server/backend-packs.md) as well. **Every**
`cage-backend-*.tar.gz` in `release/docker/` is unpacked into the image — the
same as a native install, where you drop as many packs as you like into `bin/`
and the server probes each one per card.

Copying in more than one is the normal thing to do when a machine has mixed
cards, or when one image serves several machines. There is no cost beyond image
size, and no configuration: an AI config binds to whichever backend can drive
the GPUs it selected.

Build with none and the image still runs — `remote` models work,
local ones fail to load. The build prints a warning saying so.

Three things must be set in `.env`:

| Variable | Meaning |
|---|---|
| `MODELS_DIR` | Host directory holding your models — mounted read-only at `/models` |
| `STATE_DIR` | Where the database, config and data live. **Must be on ext4/xfs — a bind mount onto exFAT or NTFS fails**, so it is kept separate from wherever you unpacked this |
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
| GPU access | **NVIDIA**: nvidia-container-toolkit on the host (`docker-compose.yml`). **AMD**: the amdgpu driver, so that `/dev/kfd` exists (`docker-compose.amd.yml`). With neither, everything runs on CPU |
| Driver | Any CUDA 12.x driver, 525.60.13 or newer |
| GPU | Whatever your [backend pack](server/backend-packs.md) covers — CUDA from compute capability 7.0, AMD through the HIP packs, anything else through Vulkan |
| Disk | The image before the backend pack, plus ~1.6 GB unpacked for a CUDA pack (Vulkan and CPU packs, ~50 MB), plus your models |

The base image is `nvidia/cuda:12.6.3-devel-ubuntu24.04`, and both halves of that
matter:

- **ubuntu24.04** — the server binary needs `GLIBC_2.38`. Ubuntu 22.04 ships 2.35
  and the binary will not start on it.
- **-devel** — a leftover. It was chosen because `nvcc` was needed to build the
  Python worker environments inside the container. Nothing in the image needs
  `nvcc` any more, so `-runtime` should give a much smaller image; that swap has
  not been tested yet.

CUDA 12.x containers work with any 12.x driver, so the image's CUDA version does
not have to match your host toolkit.

## What is mounted where

Everything that matters is a host folder, so containers stay disposable.

| Host | Container | Holds |
|---|---|---|
| `${STATE_DIR}/config` | `/config` | `config.xml`, `control.xml` — seeded on first start, then yours |
| `${STATE_DIR}/server` | `/opt/cage/data` | Logic graphs, retrieval vectors, the server log |
| `${STATE_DIR}/mysql` | `/var/lib/mysql` | The database |
| `${STATE_DIR}/output` | `/tmp/cage` | Generated images, audio, meshes |
| `${MODELS_DIR}` | `/models` (read-only) | Your models |

**The server data mount is `/opt/cage/data`, not `/data`.** The server
resolves `data/logic_graphs` and `data/vectors` against its
working directory, so a volume anywhere else is silently ignored and the graphs
disappear the next time the container is recreated. This cost one round of
testing to find.

> The image still declares a `/venvs` volume and installs `python3-venv` and
> `ffmpeg`. Nothing uses them any more — they provisioned the Python worker
> environments, which were removed. They are harmless, and are on the list to
> drop from the image.

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

Nothing to do. A Hugging Face directory of `*.safetensors` is read by the
in-process backend exactly as a GGUF directory is, and quantized when it loads.
Point a `<model>` at it and pick the quantization on the AI config — see
[Safetensors models](server/safetensors.md).

This used to need a Python environment in `/venvs` — either vLLM or a `torch`
build that converted the weights to GGUF. Both are gone.

## Adding models

Mount the host directory holding them and refer to it as `/models`:

```xml
<model alias="my-coder">
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
| Image build | 13.1 GB from the CUDA 12.6.3 devel base, before any backend pack |
| Stack start | MySQL healthy, then the server; bootstrap admin seeded, `auth ENABLED` |
| Model scan | GGUF found through the read-only `/models` mount |
| Web UI | Serves on 8088 |
| Inference | 7.5 GB Q8_0 loaded on one V100, generated in **2.9 s** |
| Persistence | After `down` + `up`: config and vectors survived |

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
— no database password, no admin password, empty
`/models`. Read those first.

| Symptom | Likely cause |
|---|---|
| Container exits immediately | Check `docker compose logs cage`. A GLIBC error means the base image was changed to 22.04 |
| `could not select device driver` at start | NVIDIA Container Toolkit is not installed, or the daemon was not restarted after installing it |
| Server starts, no GPU in the log | Same, or the `deploy.resources` block was removed |
| GGUF models never load | Check the model path is under a mounted directory; `backend` should be `llama` |
| safetensors models never load | Same causes as any local model — no backend pack, or not enough VRAM. See [Safetensors models](server/safetensors.md) |
| Worker dies with no error while loading | Raise `SHM_SIZE`; the 64 MB Docker default is far too small |
| Clients cannot log in | `<mysql>` differs between `config.xml` and `control.xml`. The entrypoint fills both from the same variables, so this only happens after hand-editing |
| Web UI unreachable from another machine | It is bound to `127.0.0.1` on purpose |
| `operation not permitted` mounting a folder | `STATE_DIR` is on exFAT/NTFS. Point it at an ext4/xfs path |
| Cannot edit `config.xml` from the host | Set `PUID`/`PGID` in `.env` to your `id -u` / `id -g` |

If none of that fits, the [manual install](../server-install.md) is the other
tested route.

---

[← Server Guide](README.md) · [Manual install](../server-install.md)
