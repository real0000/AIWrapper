# Safetensors models

A Hugging Face directory of `*.safetensors` runs the same way a GGUF file does:
in the server process, on the [backend pack](backend-packs.md) for your GPU.
There is nothing to install and nothing to convert.

```xml
<model alias="some-hf-model">
  <path>/mnt/models/Some-Model-HF</path>
</model>
```

---

## Quantization is chosen when the model loads

This is the real difference between the two formats.

| | GGUF | Safetensors |
|---|---|---|
| What is on disk | One file per quantization, already quantized | The original unquantized tensors |
| What you can pick | **Only the quantizations that exist in the directory** | **Any of them** — `4bit`, `4bit-fp4`, `8bit`, `bf16`, `fp16`, `fp32` |
| When it happens | Never; it was done when the file was made | At load time, every time |
| Disk cost | One copy per quantization you keep | One copy, whatever you load it as |

Pick the quantization on the AI config, the same place as for a GGUF model. The
per-tensor rules are shared with offline quantization, so loading at `4bit`
produces the same tensors as a `4bit` GGUF of the same weights, byte for byte.

The trade is time against disk: a safetensors model quantizes on every load,
where a GGUF file is read as-is. For a model you always run one way, a GGUF is
less work per load; for one you are still choosing a quantization for,
safetensors lets you try all of them without re-downloading anything.

## Size reporting

A safetensors entry is listed with an **estimate** — the on-disk tensor size
scaled by the quantization you picked — not a measured file size, because the
file for that quantization does not exist. GGUF entries report the real size of
the real file.

## What it does not change

Everything downstream is identical: placement across GPUs, the VRAM ledger,
context sizing, lazy loading and eviction, vision projectors, tool calling and
chat templates. A safetensors model is not a second class of model with its own
rules; it is the same slot with a different reader in front of it.

---

> **If you are coming from an older release.** This used to need a choice between
> two Python environments — vLLM serving the weights over HTTP, or a `torch`
> environment converting them to GGUF in memory on first use, with the server
> picking whichever worked. Both paths and both environments are gone: the
> backend reads the directory itself. Entries that still carry a `backend`
> attribute keep working — it is ignored — and the `<ai><vllm>` and
> `<ai><convert>` blocks are no longer read, so the tidy-up is to delete them.

---

[← Backends](backends.md) · [Models](models.md) · [Backend Packs](backend-packs.md) · [Server Guide](../README.md)
