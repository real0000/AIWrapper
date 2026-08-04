# Server Installation

Two ways to install, both from the same package on Linux x86-64:
[`dist/aiwrapper-server-0.1.0-linux-x64.tar.gz`](../dist/).

---

## Which one

| | **Docker** | **Native** |
|---|---|---|
| Installs on the host | Nothing but Docker | The binaries, and a MySQL server if you want accounts |
| Database | Comes with it, as a container | You install and configure MySQL yourself |
| Python worker environments | Built inside the container; the image already carries every system dependency | Built on the host; some families need `apt` packages and root |
| The `music` family | Works | Needs FFmpeg development headers installed as root |
| Upgrading | Replace the package, rebuild, restart | Re-run the installer |
| Uninstalling | `docker compose down` and delete a folder | Remove the service units and the install directory |
| Disk | 13 GB image on top of the rest | Just the package and the worker environments |
| Runs as | root inside the container | A user account you choose |

**Take Docker unless you have a reason not to.** It exists because the awkward
part of this product is not the server — that is one static binary — but the
Python worker environments and their system dependencies. The image has those
solved.

Reasons to go native: you already run MySQL, you want the server under systemd
alongside other services, you need it to run as a specific user, or Docker is not
an option on the machine.

Both paths are tested, and both were used to load a 7.5 GB model and generate
through the server.

### → [Docker](server/docker.md)

```bash
cd release/docker
cp ../dist/aiwrapper-server-0.1.0-linux-x64.tar.gz .
cp .env.example .env      # models directory, state directory, passwords
docker compose up -d --build
```

Everything stateful — database, config, logic graphs, worker environments — is a
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
| OS | Linux x86-64, glibc 2.38+ | Ubuntu 24.04 or newer. The binary needs `GLIBC_2.38`, so Ubuntu 22.04 (2.35) will not run it |
| GPU | NVIDIA driver + CUDA 12 runtime | `libcudart.so.12`, `libcublas.so.12`. Without them the server still starts, but everything runs on CPU. See [supported GPUs](#supported-gpus) |
| RAM | 16 GB minimum | Large models are mostly RAM-resident when they exceed VRAM |
| MySQL | optional | Needed only for accounts, sessions and usage tracking. Without it the server runs in open mode — see §8 |
| Python | 3.10+, optional | Needed for the multimodal workers, and for vLLM if you run safetensors models. A GGUF-only text deployment needs none |

Check the CUDA runtime:

```bash
nvidia-smi                       # driver + GPUs
ldconfig -p | grep libcudart     # CUDA 12 runtime
```

### Supported GPUs

The build carries compiled kernels for every architecture from Volta to Hopper,
plus PTX so anything newer still works:

| Compute capability | Examples | How |
|---|---|---|
| 7.0 | V100, Titan V | Compiled kernels |
| 7.5 | RTX 20xx, T4, Quadro RTX | Compiled kernels |
| 8.0 | A100, A30 | Compiled kernels |
| 8.6 | RTX 30xx, A40, A10 | Compiled kernels |
| 8.9 | RTX 40xx, L40, L4 | Compiled kernels |
| 9.0 and newer | H100, H200, RTX 50xx | PTX, compiled by the driver on first load — expect a delay the first time a model loads, then it is cached |
| 6.x and older | GTX 10xx, P100 | **Not supported** |

This is why the package is 194 MB: those kernels are 91% of the binary. A build
for one architecture is about a third of the size, so if you are deploying to a
fleet of identical machines and care, building for just your own is a real
saving — see `CUDA_ARCHS` in `dev.sh`.

Check what you have:

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv
```

## 2. Unpack

```bash
tar -xzf aiwrapper-server-0.1.0-linux-x64.tar.gz
cd aiwrapper-server-0.1.0-linux-x64
```

Contents:

```
bin/aiwrapper-server    the inference server
bin/aiw-launcher        node agent + control plane (web UI)
bin/aiw-model-dl        Hugging Face model downloader
python/                 workers for the multimodal families
sql/schema.sql          database schema
config.example.xml      server configuration template
control.example.xml     control-plane configuration template
install.sh              installer
setup-workers.sh        builds the Python worker environments
```

## 3. Install

```bash
./install.sh                       # to /opt/aiwrapper, with systemd services
```

| Option | Meaning |
|---|---|
| `--prefix DIR` | Install directory (default `/opt/aiwrapper`) |
| `--user NAME` | Account the services run as (default: invoking user) |
| `--no-service` | Copy files only, skip systemd |
| `--force` | Overwrite an existing `config.xml` / `control.xml` |

The installer checks the CUDA runtime and that every shared library the server
needs resolves, copies the files, creates `config.xml` and `control.xml` from
the templates (mode 600 — they hold database credentials), and creates
`data/`, `models/` and `/tmp/aiwrapper`.

`sudo` is used only when the target directory is not writable. To install
without root:

```bash
./install.sh --prefix ~/aiwrapper --no-service
```

Two systemd units are installed unless `--no-service` is given:

| Unit | Command | Role |
|---|---|---|
| `aiw-agent` | `aiw-launcher --agent` | Resident. Supervises `aiwrapper-server`, edits the model list, downloads models |
| `aiw-control` | `aiw-launcher --control` | Web UI, admin accounts, multi-node management |

The server is **not** a service of its own — the agent starts and stops it.
The units are enabled but not started, because `config.xml` still needs editing.

## 4. Configure

Edit `config.xml` in the install directory. The three fields that matter for a
first run:

```xml
<mysql>
  <host>127.0.0.1</host>
  <port>3306</port>
  <user>aiwrapper</user>
  <password>your-password</password>
  <database>aiwrapper</database>
</mysql>

<ai>
  <!-- Only needed for safetensors models. Leave empty for GGUF-only. -->
  <vllm>
    <python_exe></python_exe>
  </vllm>
</ai>

<models>
  <model alias="my-coder" backend="llama">
    <!-- A DIRECTORY, not a file. Every *.gguf inside it becomes a
         selectable quantization. A safetensors directory needs
         backend="vllm" instead, and is quantized at load time. -->
    <path>/path/to/models/Qwen3-Coder-Next</path>
  </model>
</models>
```

The file is read from the working directory. Point at another copy with
`CONFIG_FILE`:

```bash
CONFIG_FILE=/opt/aiwrapper/config.xml ./bin/aiwrapper-server
```

All relative paths inside `config.xml` resolve against the directory the file
lives in, not the process working directory.

Models are normally added through the control-plane web UI or `aiw-model-dl`,
both of which rewrite the `<models>` section for you:

```bash
./bin/aiw-model-dl Qwen/Qwen3-Coder-Next --dir models --config config.xml
```

## 5. Python environments

Two separate things, both optional:

- **Multimodal workers** (image, audio, 3D) — `setup-workers.sh`, below.
- **vLLM**, only for safetensors models — a plain `pip install vllm` in its own
  environment. See [vLLM](server/server/vllm.md); do not put it in a
  `setup-workers.sh` venv, it pins its own torch.

A GGUF-only text deployment needs neither: the `llama` backend runs inside the
server process.

```bash
cd /opt/aiwrapper
./setup-workers.sh --list          # the families and what each needs
./setup-workers.sh                 # llm only — the text/code path
./setup-workers.sh --families all  # everything, tens of GB
```

It creates one virtualenv per family and prints the `config.xml` lines to
paste.

Prerequisites it checks first: an interpreter that can create virtualenvs
(**Debian/Ubuntu need `apt install python3.x-venv` — the stock `python3` cannot,
and this is the most common first-run failure**), `nvcc` for GPU builds, and
`git` for the 3D families. The `music` family additionally needs the FFmpeg
development headers, and `tts` needs the `ffmpeg` binary at runtime.

Eight of the nine families install unattended; `mesh-trellis` needs one
interactive upstream step afterwards. Sizes, results and every failure mode are
in [Python workers](server/server/workers.md).

Full detail, including why each family gets its own environment and what to do
when a worker will not start: **[Python workers](server/server/workers.md)**.

## 6. Database (optional)

```bash
mysql -u root -p < /opt/aiwrapper/sql/schema.sql
```

`<mysql>` in `config.xml` and in `control.xml` must point at the **same**
database — the server and the control plane share the `users` / `api_keys` /
`sessions` tables. If they differ, accounts created in the web UI will not be
visible to the server and clients cannot log in.

## 7. Start

With systemd:

```bash
sudo systemctl start aiw-agent aiw-control
journalctl -u aiw-agent -f
```

In the foreground (agent + control + server in one process, Ctrl+C stops all):

```bash
cd /opt/aiwrapper && ./bin/aiw-launcher --all
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

## 8. Running without a database

Leave `<mysql>` pointing at nothing reachable and the server logs:

```
[warning] MySQL connect failed (Connection refused) — DB features disabled;
          admin login falls back to the config password
[info] [auth] auth DISABLED (dev-open) (users=0, masterKey=no)
```

The control plane says the same thing in its Accounts tab — see
[Accounts](server/control/accounts.md).

It then serves every request without authentication. That is fine for a local
single-user trial and **not** appropriate for anything reachable from another
machine.

## 9. TLS

Set both fields in `config.xml` to serve https/wss on the same port:

```xml
<tls_cert>/opt/aiwrapper/server.crt</tls_cert>
<tls_key>/opt/aiwrapper/server.key</tls_key>
```

Self-signed certificate for LAN use:

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout server.key -out server.crt -subj "/CN=aiwrapper" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:<your-lan-ip>"
```

A self-signed certificate is not trusted by the system, so the client has to be
told to accept it — see [extension-install.md](extension-install.md) §4.

Bearer tokens are sent on every request, so plaintext is only appropriate on
localhost.

## 10. Troubleshooting

| Symptom | Cause |
|---|---|
| `Fatal error: config.xml: cannot open file` | Started from a directory without `config.xml`. Use `CONFIG_FILE=…` or `cd` to the install directory first |
| `Model '…' scan failed: path does not exist` | `<path>` does not exist or the disk is not mounted. The alias is still registered but cannot load |
| `TLS disabled — traffic … is plaintext` | Expected when `<tls_cert>`/`<tls_key>` are empty |
| Server starts but no GPU is listed | Driver or CUDA 12 runtime missing; check `nvidia-smi` and `ldconfig -p | grep libcudart` |
| A safetensors model never loads | `<ai><vllm><python_exe>` is unset or has no `vllm` — see [vLLM](server/server/vllm.md) |
| A modality worker fails immediately | Its `<python_exe>` is not a venv built by `setup-workers.sh` — see [Python workers](server/server/workers.md) |
| Port already in use | Another instance is running, or `<port>` collides with `<agent_port>` |

## 11. Uninstall

```bash
sudo systemctl disable --now aiw-agent aiw-control
sudo rm /etc/systemd/system/aiw-agent.service /etc/systemd/system/aiw-control.service
sudo systemctl daemon-reload
sudo rm -rf /opt/aiwrapper
```

---

Next: [extension-install.md](extension-install.md) — install the VSCode client
and connect it. The client does not care which way the server was installed.

For how the three server-side processes fit together and how to run them day to
day, see the **[Server Guide](server/README.md)**.
