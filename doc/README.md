# CAGE Documentation

## Install

| Document | Contents |
|---|---|
| [server-install.md](server-install.md) | **Start here** — picks between the two install paths, then covers the native one in full |
| [server/docker.md](server/docker.md) | The Docker path: Dockerfile and compose, with the database, models and config as host folders |
| [server/server/backend-packs.md](server/server/backend-packs.md) | **GPU support is a separate download.** Which pack to get and how to install it |
| [extension-install.md](extension-install.md) | Installing the `.vsix`, connecting to a server, self-signed certificates, login, first use |

Start with the server — the extension needs one to connect to. The server needs
a backend pack before it can run GGUF models on your GPU.

Upgrading from 0.1.0? See [What's New](../WHATSNEW.md) for what changed and what
needs action from you.

## Use

| Document | Contents |
|---|---|
| [server/](server/README.md) | The server guide: the three processes — node agent, inference server, control plane — and what each one owns |
| [client/](client/README.md) | The client guide: both windows, every panel, and what each setting does |

The server guide is organised by process, because which process owns a thing
decides how you change it. The client guide is split by page, and goes into
detail on the logic graph — the node types, the configurations they reference,
and the parameters inside them.

---

Proprietary — Copyright (c) 2026 real0000. All Rights Reserved. See [LICENSE](../LICENSE).
