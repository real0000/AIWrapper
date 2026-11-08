[English](safetensors.md) · **繁體中文**

# Safetensors 模型

放著 `*.safetensors` 的 Hugging Face 資料夾，跑法跟 GGUF 檔案一樣：在 server 的程序裡，用你 GPU 對應的[後端包](backend-packs.zh-TW.md)執行。沒有東西要安裝，也沒有東西要轉檔。

```xml
<model alias="some-hf-model">
  <path>/mnt/models/Some-Model-HF</path>
</model>
```

---

## 量化在載入模型時才決定

這是兩種格式真正的差別。

| | GGUF | Safetensors |
|---|---|---|
| 磁碟上有什麼 | 每種量化一個檔案，已經量化好了 | 原始、沒有量化的 tensor |
| 能選什麼 | **只有資料夾裡已經有的量化版本** | **全部都能選** —— `4bit`（Q4_K_M）、`8bit`（Q8_0）、`bf16`、`fp16`、`fp32`。舊設定裡的 `4bit-fp4` 仍然接受，會以 `4bit` 載入 |
| 什麼時候量化 | 不會；製作檔案時就做完了 | 載入時，每一次 |
| 磁碟成本 | 留幾種量化，就有幾份 | 一份，不管你用哪種量化載入 |

在 AI config 上選量化，跟 GGUF 模型在同一個地方。每個 tensor 怎麼量化的規則，跟離線量化共用同一套，所以用 `4bit` 載入，產生的 tensor 跟同一份權重做成的 `4bit` GGUF 逐位元組相同。

這是拿時間換磁碟：safetensors 模型每次載入都要量化，GGUF 檔案則是照原樣讀進來。永遠只用一種方式跑的模型，GGUF 每次載入的工作比較少；還在挑量化的模型，safetensors 讓你全部試一遍，不必重新下載任何東西。

## 大小怎麼回報

safetensors 的項目列出來的是**估計值** —— 磁碟上的 tensor 大小，依你選的量化換算 —— 而不是量出來的檔案大小，因為那種量化的檔案根本不存在。GGUF 的項目回報的則是真實檔案的真實大小。

## 它不會改變什麼

下游的一切都一樣：跨 GPU 的擺放、VRAM 帳本、context 大小、延遲載入與驅逐、工具呼叫與 chat template。safetensors 模型不是另一類有自己一套規則的模型；它是同一個 slot，只是前面換了一個讀取程式。

視覺 projector 是例外。projector 是 GGUF 檔案，而把它跟 safetensors 模型搭配使用還沒試過，所以控制台只在 GGUF 量化旁邊提供 projector。

---

> **如果你是從舊版升級上來的。** 以前這需要在兩個 Python 環境之間做選擇 —— 用 vLLM 透過 HTTP 提供權重，或用 `torch` 環境在第一次使用時於記憶體中轉成 GGUF，由 server 挑能用的那一個。兩條路和兩個環境都已經拿掉了：後端會自己讀取那個資料夾。仍然帶著 `backend` 屬性的項目照樣能用 —— 這個屬性會被忽略 —— 而 `<ai><vllm>` 和 `<ai><convert>` 區塊也不再被讀取，整理的方法就是把它們刪掉。

---

[← 後端](backends.zh-TW.md) · [模型](models.zh-TW.md) · [後端包](backend-packs.zh-TW.md) · [Server 指南](../README.zh-TW.md)
