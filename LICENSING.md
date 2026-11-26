**English** · [繁體中文](LICENSING.zh-TW.md)

# Licensing

> **Proprietary software.** Copyright (c) 2026 real0000. All Rights Reserved.
> Licensed, not sold. This repository distributes compiled packages and
> documentation; it does not contain the source code, and the source code is not
> for sale.

CAGE is sold as a **base product plus separately purchased modules**, and every
product carries **perpetual updates** — buy it once and every future release of
that product is included. No maintenance period, no renewal, no version at which
your licence stops.

## Commercial Licence

A **Commercial Licence** is organisation-wide: install and run it on as many
machines as you like within one company, for your own internal use. No per-seat,
per-GPU or per-server counting.

| | |
|---|---|
| Scope | One legal entity and the entities it controls; unlimited installations |
| Use | Your own internal business purposes, including building your own products |
| Updates | Perpetual. Every future release of what you bought, at no further charge |
| Modules | Major new capabilities are sold separately, each with its own perpetual updates. A module needs a licensed base product to run |
| Not included | Offering CAGE's functionality to third parties as a hosted service, API, or service bureau — that needs a separate agreement |

**A module never takes away what you already bought.** Whatever a product could
do when you licensed it stays part of that product; modules only ever add to it.

## Evaluation builds

Free evaluation builds are available for testing, and may not be used in
production.

What is on GitHub is the evaluation build. Releases here carry preview and
evaluation packages, for trying CAGE out and reporting what breaks. They are not
the licensed product and are not for production use.

## Buying

Purchases go through Gumroad, which acts as merchant of record, and a licensed
copy is delivered from there: **<https://howler43274.gumroad.com/l/ckljoo>**. A purchase carries perpetual updates
for that product; this repository is not the update channel for it.

Full terms: **[LICENSE](LICENSE)**. Enquiries, including hosted-service and OEM
terms: <https://github.com/real0000>

## Open-source components

CAGE incorporates open-source components, all under permissive licences; they
are listed with their copyright notices in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Each backend pack also
carries its own `THIRD-PARTY-NOTICES.md` and `licenses/` for what is compiled
into it — ik_llama.cpp, the safetensors reader, and the image, 3D, speech and
motion engines (sd.cpp, trellis.cpp, audio.cpp, kimodo.cpp) — with the list of
files CAGE changed in each, as Apache-2.0 requires.

## Model weights

Model weights are **not** covered by LICENSE or THIRD-PARTY-NOTICES — they are
chosen and installed by the operator, and several carry commercial restrictions.
See [model licences](doc/server/server/models.md#model-licences-are-yours-to-check).

---

[← CAGE](README.md)
