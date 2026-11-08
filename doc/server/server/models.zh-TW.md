[English](models.md) · **繁體中文**

# 模型

server 怎麼把 `config.xml` 裡的 `<models>`，變成 client 看到的清單，以及它能載入的東西。

---

## 一個項目

```xml
<model alias="my-coder">
  <path>/mnt/models/Qwen3-Coder-Next</path>
  <quant>MXFP4_MOE</quant>
  <license name="Apache-2.0" commercial="free"
           url="https://huggingface.co/Qwen/Qwen3-Coder-Next"/>
</model>
```

| 元素 | 意思 |
|---|---|
| `alias` | 在其他所有地方用的名字 —— AI config、API、log 裡都是它 |
| `backend` | 通常省略 —— 依磁碟上找到的權重推出來。`llama`（GGUF 或 safetensors，在進程內執行）或 `remote`（雲端 API）。宣告的值跟掃描結果不一致時，會發出警告並以掃描結果為準。見[後端](backends.zh-TW.md) |
| `<path>` | 一個**資料夾**。見下方 |
| `<quant>` | 這個 alias 的預設量化。可省略 |
| `<mmproj>` | 視覺 projector，給視覺模型用。放在模型資料夾裡時會自動找到 |
| `<source_repo>` | 檔案來源的 Hugging Face repo。由下載程式寫入；用來抓 model card |
| `<license>` | 上游的授權，會顯示給使用者看。可省略，但建議填 |
| `<pinned>` | 讓這個模型不被驅逐 |
| `<est_ram_mb>` / `<est_vram_mb>` | 覆寫大小的估計值 |
| `<n_parallel>` | 同時進行推論的 slot 數量。只適用於 `llama` 後端 |

## `<path>` 是資料夾

這是最值得弄懂的設計決定。

server 會在啟動時掃描這個資料夾，找出可以載入的東西：

**GGUF** —— 每一個 `*.gguf` 檔就是一種量化。分成好幾片的 shard（`-00001-of-00005`）會合併成一個項目。使用者只能選實際存在的量化；要多提供一種，就把那個檔案下載到同一個資料夾 —— 不用改設定，只要重新啟動 server。

**safetensors** —— 資料夾裡是一份沒有量化的 tensor，會在載入時才量化。所以同樣的檔案就能提供每一個選項：4bit（Q4_K_M）、8bit（Q8_0）、bf16、fp16、fp32。舊設定裡的 `4bit-fp4` 仍然接受，會以 4bit 載入。

projector 檔案會被認出來，不會被當成一種量化提供。

`<quant>` 決定預設值。省略的話會選最小的那個 —— 最有可能載入成功的那個。使用者可以在各個 AI config 裡覆寫，所以這只是起點，不是限制。

舊式的 `<path>` 直接指向某個 `.gguf` 也還能用：server 會掃描它的上層資料夾，並把那個檔案當成預設值。

## 路徑錯誤時

```
[warning] Model 'my-coder' scan failed: path does not exist: /mnt/models/… - this model cannot load (…)
[error]   Model skipped: my-coder — no weights recognised under /mnt/models/… (…)
```

這個 alias 不會被註冊，也不會出現在 `/api/models` 裡，所以不可能被選到之後才失敗。通常是硬碟沒有掛載；log 會寫出它找的是哪條路徑。

## 視覺模型

多一個元素：

```xml
<model alias="my-vision">
  <path>/mnt/models/llava-llama-3-8b-v1_1</path>
  <mmproj>/mnt/models/llava-llama-3-8b-v1_1/mmproj-f16.gguf</mmproj>
</model>
```

`<mmproj>` 是 CLIP projector —— 有了它，模型才看得見。projector 放在模型資料夾裡時，不用指名也會被找到。projector 自己的中繼資料會說明它是哪一種，所以沒有其他東西要設定；舊的 `<vision handler="…">` 會被忽略。

純文字模型絕不會收到圖片：它會收到一則簡短的說明，告訴它附加了什麼、放在哪裡，所以有檔案工具的節點還是可以打開它。

## 模型授權要自己確認

**CAGE 不附任何模型權重。** `config.example.xml` 裡只有預留位置的路徑，你沒有要求之前什麼都不會下載。機器上的每一份權重，都是因為管理者選了它才出現的，所以閱讀並遵守它的授權，是管理者的責任 —— CAGE 自己的授權，對你讓它使用的模型完全沒有規定，不管是允許還是禁止。

這比聽起來重要。模型授權不是軟體授權，好幾個最熱門的權重都帶著限制，會讓以為「開放權重」就等於「想怎麼用就怎麼用」的人嚇一跳：

| 限制類型 | 出現在 | 實際上的意思 |
|---|---|---|
| **不得商用** | MusicGen、好幾個 TTS 和音訊 checkpoint | 完全不能用在商業產品裡，不管怎麼部署 |
| **營收門檻** | Stable Diffusion 3.5、Stable Audio Open（Stability AI Community License） | 年營收在規定的數字以下可以免費商用；超過的話需要企業授權 |
| **使用者數門檻** | Llama 3/4 Community Licence | 月活躍使用者數到達一定數量之前可以免費商用，之後要另外取得 Meta 的授權 |
| **地區排除** | Hunyuan3D-2（Tencent Community Licence） | 排除歐盟、英國和南韓 —— *連輸出也包括在內*，不只是模型本身 |
| **輸出的限制** | 各種模型 | 限制拿輸出去訓練其他模型，或限制輸出本身的用途 |
| **必須標示出處** | Llama 3/4 Community Licence | 用這份權重建立的服務，必須在介面、關於頁面或產品文件上顯示一段指定的字串 ——「Built with Llama」。不用花錢，但約束的是*經營這個服務的管理者*，不是軟體，所以很容易完全漏掉 |
| **條款會在你不知情時改變** | DINOv3（Meta） | 授權方可以隨時修改協議、立即生效，繼續使用就視為接受。你審查過的版本，不一定就是下一季約束你的版本 —— 把你實際接受的授權文字跟權重放在一起保存 |
| **不得逆向工程** | DINOv3（Meta） | 禁止探究權重的底層組成。要寫檢查或擷取權重內容的工具之前，值得先讀一讀 |

地區排除最出人意料，也最容易在不知不覺中違反：光是不在那些地區散布模型還不夠，因為授權也不允許在那裡使用它的輸出。

商業使用的人因此要注意兩件事：

1. **每個模型都在放進工作流程之前檢查**，而不是之後。一張圖悄悄把某個節點導向不得商用的模型，那條流程產出的所有東西都會受到影響。
2. **用下面的 `<license>` 元素記下你查到的結果。** 這是唯一能把這些知識保留下來的地方；不記的話，就只能在盡職調查時重新查一遍。

同樣的道理也適用於生成式模型，其中有些帶著自己的不得商用或營收上限條款 —— 見 [Modality](modalities.zh-TW.md)。

## 授權資訊

```xml
<license name="Llama 4 Community License" commercial="restricted"
         url="https://huggingface.co/…">可以商用，但月活躍使用者超過
7 億需要另外取得 Meta 的授權。</license>
```

| 屬性 | 值 |
|---|---|
| `commercial` | `free` —— 寬鬆授權 · `restricted` —— 附條件允許 · `noncommercial` —— 沒有另外取得授權就不允許 |
| `name` | 顯示名稱 |
| `url` | model card |
| 元素的文字內容 | 限制內容，用你自己的話寫 |

Logic Editor 的 console 會列出每一個 `commercial` 不是 `free` 的模型，附上你寫的說明。這只是提醒 —— 不會擋下任何東西 —— 但它會把限制擺在為工作流程挑模型的人面前，而決定實際上就是在那裡做的。

## client 看到什麼

`GET /api/models` 會同時回傳 LLM 和 modality 的項目，每一項附上它的種類、context 大小、後端、可用的量化和授權。Logic Editor 的下拉選單就是完全依照這個建出來的。

---

[← 推論伺服器](README.zh-TW.md) · [後端](backends.zh-TW.md) · [Server 指南](../README.zh-TW.md)
