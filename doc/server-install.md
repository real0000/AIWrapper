**English** · [繁體中文](server-install.zh-TW.md)

# Server Installation

Two ways to install, both from the same package on Linux x86-64:
[`dist/cage-server-0.2.0-linux-x64.tar.gz`](../dist/).

---

## Which one

| | **Docker** | **Native** |
|---|---|---|
| Installs on the host | Nothing but Docker | The binaries, and a MySQL server if you want accounts |
| Database | Comes with it, as a container | You install and configure MySQL yourself |
| Dependencies | None beyond Docker | The binaries, and a backend pack |
| Upgrading | Replace the package, rebuild, restart | Re-run the installer |
| Uninstalling | `docker compose down` and delete a folder | Remove the service units and the install directory |
| Disk | The image on top of the rest | Just the package and a backend pack |
| Runs as | root inside the container | A user account you choose |

**Docker is the shorter path if you do not already run MySQL.** It brings the
database with it and leaves nothing on the host. The server itself is one
static binary either way; since the Python worker environments were removed
there is much less to provision than there used to be.

Reasons to go native: you already run MySQL, you want the server under systemd
alongside other services, you need it to run as a specific user, or Docker is not
an option on the machine.

Both paths were run end to end for 0.2.0, from the release packages and exactly
as written here and in the Docker page, and both answered a prompt on a GPU — see
[What has been verified](verification-status.md#installing).

### → [Docker](server/docker.md)

```bash
cd release/docker
cp ../dist/cage-server-0.2.0-linux-x64.tar.gz .
cp .env.example .env      # models directory, state directory, passwords
docker compose up -d --build
```

Everything stateful — database, config, logic graphs, models — is a
host folder you choose, and the ports are yours to map. The full page covers
what is mounted where, GPU requirements and the traps.

### → Native

The rest of this page.

---

## 1. Requirements

From here on this page is the **native** install. For containers see
[Docker](server/docker.md).

| | Required | Notes |
|---|---|---|
| OS | Linux x86-64, glibc 2.28+ | RHEL / AlmaLinux / Rocky 8, Ubuntu 20.04, Debian 11, Fedora, or anything newer. The packages are built on an Enterprise Linux 8 base, so they ask for nothing newer than glibc 2.28 and GCC 8's `libstdc++` |
| GPU | A driver, plus a [backend pack](server/server/backend-packs.md) | NVIDIA needs only the driver — the CUDA packs carry their own `libcudart`, `libcublas` and `libcufft`. No CUDA toolkit to install. See [supported GPUs](#supported-gpus) |
| RAM | 16 GB minimum | Large models are mostly RAM-resident when they exceed VRAM |
| MySQL | optional | Needed only for accounts, sessions and usage tracking. Without it the server runs in open mode — see §7 |
| PowerShell | 7.4 or newer (`pwsh`) | Only to run the installer, `install.ps1`. Microsoft publishes a `powershell` package for Ubuntu and Debian; `snap install powershell --classic` also works |

Check the driver:

```bash
nvidia-smi                       # driver + GPUs
```

### Supported GPUs

GPU support is a **separate download**. The server package contains no GPU code
at all; you also fetch the backend pack matching your hardware. Full detail in
[Backend Packs](server/server/backend-packs.md) — the short version:

| Pack | Hardware | Compute capability |
|---|---|---|
| `cage-backend-cuda-sm60_sm61` | P40, P100, P4, GTX 10xx | 6.0, 6.1 |
| `cage-backend-cuda-sm70_sm75` | V100, Titan V, T4, RTX 20xx, GTX 16xx | 7.0, 7.5 |
| `cage-backend-cuda-sm80_sm86` | A100, A30, A40, A10, RTX 30xx | 8.0, 8.6 |
| `cage-backend-cuda-sm89_sm90` | L40, L40S, L4, RTX 40xx, H100, H200 | 8.9, 9.0 |
| `cage-backend-cuda-sm120_sm121` | RTX 50xx, GB10 (DGX Spark) | 12.0, 12.1 |
| `cage-backend-hip-*` | AMD via ROCm, split by ISA generation. Needs `libdrm2 libdrm-amdgpu1 libnuma1 libelf1` | n/a |
| `cage-backend-vulkan` | Any Vulkan 1.2 GPU — AMD, Intel, or NVIDIA | n/a |
| `cage-backend-cpu` | No GPU | n/a |

NVIDIA compute capability **5.x and older** (Maxwell: GTX 9xx, M40) is not
covered by any CUDA pack; the Vulkan pack may still drive those cards.

You can install more than one pack — a P40 next to a V100 is the usual case.
Each pack's library is named after the pack, so they sit side by side in `bin/`;
the server probes each one per device and an AI config binds to whichever
backend can drive the GPUs it selected. See
[more than one pack](server/server/backend-packs.md#more-than-one-pack) for the
one ordering rule.

Check what you have:

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv   # NVIDIA
vulkaninfo --summary | head -30                        # anything else
```

Without a pack the server still starts, and `remote` models still
work — but a local model fails at load with a message naming the
pack to download.

## 2. Unpack

```bash
tar -xzf cage-server-0.2.0-linux-x64.tar.gz
cd cage-server-0.2.0-linux-x64
```

Contents:

```
bin/cage-server         the inference server
bin/cage-launcher       node agent + control plane (web UI)
bin/cage-model-dl       Hugging Face model downloader, and --scan for models
                        already on disk
bin/cage-backend-probe  reports which backend pack you have and which of your
                        cards it can drive
bin/cage-llama-fit      asks where a model would go, without loading it
                        (see server/server/backends.md)
lib/                    runtime libraries the server needs
sql/schema.sql          database schema
config.example.xml      server configuration template
control.example.xml     control-plane configuration template
install.ps1             installer (PowerShell)
LICENSE                 end user licence agreement
THIRD-PARTY-NOTICES.md  open-source components and their licences
```

**No GPU code is in here.** Unpack your [backend pack](server/server/backend-packs.md)
over the same directory before installing, so the installer picks it up:

```bash
tar -xzf cage-backend-cuda-sm89_sm90-0.2.0-linux-x64.tar.gz
cp cage-backend-cuda-sm89_sm90-0.2.0-linux-x64/bin/* bin/
cp -r cage-backend-cuda-sm89_sm90-0.2.0-linux-x64/lib/* lib/
```

Keep the `-r`: an AMD pack's `lib/` has a `rocblas/library/` folder of GPU
kernels, and without it the first matrix multiplication fails.

You can add more than one pack. The installer lists the packs it found, and
warns if there are none.

**Use a pack of the same version as the server.** The server refuses a pack
from an earlier release rather than silently losing tool calls — see
[backend packs](server/server/backend-packs.md). Upgrading the server means
re-downloading the pack.

## 3. Install

```bash
pwsh ./install.ps1                 # to /opt/cage, with systemd services
```

| Option | Meaning |
|---|---|
| `--prefix DIR` | Install directory (default `/opt/cage`) |
| `--user NAME` | Account the services run as (default: invoking user) |
| `--no-service` | Copy files only, skip systemd |
| `--force` | Overwrite an existing `config.xml` / `control.xml` |

The installer reports which backend packs it found and checks that every shared
library the server needs resolves, copies `bin/`, `lib/` and `sql/`, creates `config.xml` and `control.xml` from
the templates (mode 600 — they hold database credentials), and creates
`data/` and `models/`. There is no shared `/tmp/cage` any more: the server and
the launcher each make their own temporary directory, `/tmp/cage-<uid>`, mode
700, which is why the systemd units let them write under `/tmp`.

`sudo` is used only when the target directory is not writable. To install
without root:

```bash
pwsh ./install.ps1 --prefix ~/cage --no-service
```

Two systemd units are installed unless `--no-service` is given:

| Unit | Command | Role |
|---|---|---|
| `cage-agent` | `cage-launcher --agent` | Resident. Supervises `cage-server`, edits the model list, downloads models |
| `cage-control` | `cage-launcher --control` | Web UI, admin accounts, multi-node management |

The server is **not** a service of its own — the agent starts and stops it.
The units are enabled but not started, because `config.xml` still needs editing.

## 4. Configure

Edit `config.xml` in the install directory. The three fields that matter for a
first run:

```xml
<mysql>
  <host>127.0.0.1</host>
  <port>3306</port>
  <user>cage</user>
  <password>your-password</password>
  <database>cage</database>
</mysql>

<ai>
  <!-- Optional. Leave the whole block out and the defaults apply. -->
  <default_model>my-coder</default_model>
</ai>

<models>
  <model alias="my-coder">
    <!-- A DIRECTORY, not a file. Every *.gguf inside it becomes a
         selectable quantization. A Hugging Face safetensors directory
         works here too, and is quantized when it loads. No backend= needed:
         the scan decides. -->
    <path>/path/to/models/Qwen3-Coder-Next</path>
  </model>
</models>
```

The file is read from the working directory. Point at another copy with
`CONFIG_FILE`:

```bash
CONFIG_FILE=/opt/cage/config.xml ./bin/cage-server
```

All relative paths inside `config.xml` resolve against the directory the file
lives in, not the process working directory.

Models are normally added through the control-plane web UI or `cage-model-dl`,
both of which rewrite the `<models>` section for you:

```bash
./bin/cage-model-dl Qwen/Qwen3-Coder-Next --dir models --config config.xml
```

## 5. Database (optional)

```bash
mysql -u root -p < /opt/cage/sql/schema.sql
```

`<mysql>` in `config.xml` and in `control.xml` must point at the **same**
database — the server and the control plane share the `users` / `api_keys` /
`sessions` tables. If they differ, accounts created in the web UI will not be
visible to the server and clients cannot log in.

## 6. Start

With systemd:

```bash
sudo systemctl start cage-agent cage-control
journalctl -u cage-agent -f
```

In the foreground (agent and control in one process, the server as its child;
Ctrl+C stops all three):

```bash
cd /opt/cage && ./bin/cage-launcher --all
```

Verify:

```bash
$ curl -s http://127.0.0.1:15963/health
{"status":"ok"}

$ curl -s http://127.0.0.1:15963/api/models
{"models":[{"id":"my-coder","name":"my-coder","kind":"llm","type":"chat",
"ctx_size":8192,"backend":"llama", ...}]}
```

The web UI is at `http://<host>:8088/`.

| Port | Set in | Purpose |
|---|---|---|
| 15963 | `config.xml` `<port>` | AI API — HTTP + WebSocket. This is what clients connect to |
| 15972 | `config.xml` `<node><agent_port>` | Node agent API, called by the control plane |
| 8088 | `control.xml` `<web_port>` | Control-plane web UI |

## 7. Running without a database

Remove the whole `<mysql>` block from `config.xml`. The server logs:

```
[info] MySQL: no <mysql> block - running without a database (no accounts; ...)
[warning] [auth] auth DISABLED (dev-open) (users=0, masterKey=no, database=none): every request is served as admin, ...
```

With no `<api_key>` set either, this is **open mode**, and its security problem
is deliberate, not a bug that will be fixed:

- Every request is served as admin, with no sign-in.
- Anyone who can reach the port can read every session (conversations, with
  your code in them) and change or delete graphs. `<bind>127.0.0.1</bind>`
  limits that to this machine.

Web pages cannot use it, in this mode or any other: the server refuses every
request a browser page makes (see [API](server/server/api.md)).

Use it only for a single-user trial. Setting `<api_key>` closes it: one shared
token, still no database.

**A `<mysql>` block that points at a database the server cannot reach does not
mean "no database".** The server waits for it before serving anything —
`Waiting for the database at …`, then a line every 30 seconds — and starts once
it answers. It never takes "the database is not up yet" for "there are no
accounts", because that would start it open. It also waits if the database
answers but the accounts cannot be read. An account created while the server is
running (for example the control plane seeding its admin) ends open mode
immediately, without a restart.

## 8. TLS

Set both fields in `config.xml` to serve https/wss on the same port:

```xml
<tls_cert>/opt/cage/server.crt</tls_cert>
<tls_key>/opt/cage/server.key</tls_key>
```

Self-signed certificate for LAN use:

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout server.key -out server.crt -subj "/CN=cage" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:<your-lan-ip>"
```

A self-signed certificate is not trusted by the system, so the client has to be
told to accept it — see [extension-install.md](extension-install.md) §4.

Bearer tokens are sent on every request, so plaintext is only appropriate on
localhost.

## 9. Troubleshooting

| Symptom | Cause |
|---|---|
| `Fatal error: config.xml: cannot open file` | Started from a directory without `config.xml`. Use `CONFIG_FILE=…` or `cd` to the install directory first |
| `Model '…' scan failed: path does not exist` | `<path>` does not exist or the disk is not mounted. The model is skipped (`Model skipped: …`) and does not appear in the list |
| `TLS disabled — traffic … is plaintext` | Expected when `<tls_cert>`/`<tls_key>` are empty |
| A local model fails to load | No backend pack installed, or the wrong one. Run `bin/cage-backend-probe` — it names the backend and says which of your cards it can drive |
| Server starts but no GPU is listed | Driver missing, or the pack cannot see the cards; check `nvidia-smi` and `bin/cage-backend-probe` |
| A safetensors model never loads | Same causes as any local model: no [backend pack](server/server/backend-packs.md), or not enough VRAM for the quantization you picked — see [Safetensors models](server/server/safetensors.md) |
| A generative model fails immediately | It needs a [backend pack](server/server/backend-packs.md) like every other local model, and competes for the same VRAM — see [Modalities](server/server/modalities.md) |
| Port already in use | Another instance is running, or `<port>` collides with `<agent_port>` |

## 10. Uninstall

```bash
sudo systemctl disable --now cage-agent cage-control
sudo rm /etc/systemd/system/cage-agent.service /etc/systemd/system/cage-control.service
sudo systemctl daemon-reload
sudo rm -rf /opt/cage
```

---

Next: [extension-install.md](extension-install.md) — install the VSCode client
and connect it. The client does not care which way the server was installed.

For how the three server-side processes fit together and how to run them day to
day, see the **[Server Guide](server/README.md)**.
