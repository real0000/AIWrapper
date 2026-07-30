# Docker

Run the whole server side in containers, built from a Dockerfile you have. No
image is published and nothing is pulled from a private registry — the only
outside image is the official `mysql`.

Files are in [`docker/`](../../docker/).

> **Not yet verified.** The Dockerfile, compose file and entrypoint were written
> against the packaged binaries and validated as far as possible without Docker
> installed — shell and YAML parse, the config templates produce valid XML, every
> placeholder the entrypoint substitutes exists. They have **not been built or
> run**. Treat the first `docker compose up` as the real test, and see
> [If something does not come up](#if-something-does-not-come-up).

---

## Quick start

```bash
cd release/docker
cp ../dist/aiwrapper-server-0.1.0-linux-x64.tar.gz .   # the package
cp .env.example .env                                    # then edit it
docker compose up -d --build
```

Three things must be set in `.env`:

| Variable | Meaning |
|---|---|
| `MODELS_DIR` | Host directory holding your models — mounted read-only at `/models` |
| `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD` | Any non-empty values; only these two containers use them |
| `ADMIN_PASSWORD` | Control-plane web UI login. Empty disables authentication |

Then:

```bash
docker compose logs -f aiwrapper       # watch it come up
curl http://127.0.0.1:15963/health     # {"status":"ok"}
```

The web UI is at `http://127.0.0.1:8088/`. Point the VSCode extension at
`localhost` port `15963`.

## Requirements

| | |
|---|---|
| Docker | With Compose v2 (`docker compose`, not `docker-compose`) |
| NVIDIA Container Toolkit | For GPU access. Without it, drop the `deploy.resources` block and everything runs on CPU |
| Driver | Any CUDA 12.x driver, 525.60.13 or newer |
| Disk | ~8 GB image, plus the worker environments and your models |

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
| `./config` | `/config` | `config.xml`, `control.xml` — seeded on first start, then yours |
| `./data/server` | `/data` | Logic graphs, workflows, retrieval vectors, the server log |
| `./data/mysql` | `/var/lib/mysql` | The database |
| `./data/output` | `/tmp/aiwrapper` | Generated images, audio, meshes |
| `./venvs` | `/venvs` | Python worker environments |
| `${MODELS_DIR}` | `/models` (read-only) | Your models |

**`/venvs` is a volume for a reason.** Building every worker family is about
46 GB and recompiles CUDA extensions; keeping it outside the image means a
rebuild does not repeat that.

## Ports

| Port | Published by default | Purpose |
|---|---|---|
| 15963 | yes | AI API — HTTP + WebSocket. What the editor connects to |
| 8088 | yes, bound to `127.0.0.1` | Control-plane web UI |
| 15972 | no | Node agent API. Only needed if a control plane on another machine drives this node |
| 3306 | no | MySQL. Only the aiwrapper container needs it |

The web UI is bound to localhost because it can start, stop and reconfigure the
server. Publishing it more widely is a decision to make deliberately, behind a
TLS-terminating proxy.

Change any of them in `.env` (`API_PORT`, `WEB_PORT`, `AGENT_PORT`) — those are
host-side, so the container's own ports stay as the config expects.

## Building the worker environments

The image has no worker environments; they are too large and too
hardware-specific to bake in. Build them once into the volume:

```bash
docker compose exec aiwrapper ./setup-workers.sh --list
docker compose exec aiwrapper ./setup-workers.sh --prefix /venvs
docker compose exec aiwrapper ./setup-workers.sh --prefix /venvs --families all
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
<model alias="my-coder" backend="unsloth">
  <path>/models/Qwen3-Coder-Next</path>
</model>
```

Edit `./config/config.xml` and restart, or add it through the web UI. Either way
the server must restart before a new entry loads — see
[Restart to apply](agent/README.md#restart-to-apply).

`/models` is mounted read-only, so downloads through the web UI will fail. Drop
the `:ro` in the compose file if you want the agent to download models itself.

## Running without a database

Leave `MYSQL_PASSWORD` empty and remove the `mysql` service and the `depends_on`
block. The server then runs in open mode: no accounts, no per-user sessions, and
no authentication on the API. Reasonable for a single-user trial on a machine
only you can reach; not otherwise. See [Accounts](control/accounts.md).

## Everyday commands

```bash
docker compose logs -f aiwrapper          # server, agent and control together
docker compose exec aiwrapper bash        # a shell inside
docker compose restart aiwrapper          # apply config.xml changes
docker compose down                       # stop; volumes and data stay
docker compose up -d --build              # after a new package
```

The container runs `aiw-launcher --all`, so the agent, control plane and server
share one process and one log stream. Restarting the container restarts all
three.

## If something does not come up

The entrypoint prints a warning for each of the common mistakes before starting
— no database password, no admin password, no worker environment, empty
`/models`. Read those first.

| Symptom | Likely cause |
|---|---|
| Container exits immediately | Check `docker compose logs aiwrapper`. A GLIBC error means the base image was changed to 22.04 |
| `could not select device driver` at start | NVIDIA Container Toolkit is not installed, or the daemon was not restarted after installing it |
| Server starts, no GPU in the log | Same, or the `deploy.resources` block was removed |
| Models never load | No worker environment yet — build one as above |
| Worker dies with no error while loading | Raise `SHM_SIZE`; the 64 MB Docker default is far too small |
| Clients cannot log in | `<mysql>` differs between `config.xml` and `control.xml`. The entrypoint fills both from the same variables, so this only happens after hand-editing |
| Web UI unreachable from another machine | It is bound to `127.0.0.1` on purpose |

Because this path is unverified, a failure here is as likely to be a bug in
these files as a mistake in your setup. The [manual install](../server-install.md)
is the tested route if you need something working now.

---

[← Server Guide](README.md) · [Python workers](server/workers.md) · [Manual install](../server-install.md)
