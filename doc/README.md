# AIWrapper Documentation

## Install

| Document | Contents |
|---|---|
| [server-install.md](server-install.md) | Server requirements, unpacking, `install.sh`, `config.xml`, database, first start, TLS, troubleshooting, uninstall |
| [server/docker.md](server/docker.md) | Running the server side in containers instead — Dockerfile and compose, with volumes for models, database and config |
| [extension-install.md](extension-install.md) | Installing the `.vsix`, connecting to a server, self-signed certificates, login, first use |

Start with the server — the extension needs one to connect to.

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
