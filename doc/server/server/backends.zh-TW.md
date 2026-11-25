[English](backends.md) · **繁體中文**

# 後端

每個模型都透過同一個轉接介面執行。一個模型用哪一種實作，取決於磁碟上的權重；這條線以上的一切 —— 邏輯圖、工具、檢索 —— 不管哪一種都完全一樣。

---

server 的執行檔**完全不含 GPU 程式碼**。要在本機跑任何東西，都需要一個[後端包](backend-packs.zh-TW.md) —— 一個依你的硬體另外下載的套件。沒有後端包，server 照樣能啟動，`remote` 模型也照樣能用。

## 兩種後端

| | `llama` | `remote` |
|---|---|---|
| 是什麼 | ik_llama.cpp，在 server 的程序裡執行 | 別人的端點 |
| 格式 | GGUF **以及** Hugging Face 的 safetensors 資料夾 | 不適用 |
| 多模態 | 有 —— 文字、視覺和各種生成式類型都在這裡跑 | 看服務商 |
| 需要 | 一個對應你 GPU 的[後端包](backend-packs.zh-TW.md) | 網路＋一把 API key |

```xml
<model alias="a"><path>/models/…</path></model>          <!-- 本機的權重 -->
<model alias="c"><remote_url>https://…</remote_url></model>   <!-- 別人的端點 -->
```

**沒有東西要選。** `<path>` 指向權重就是本機；`<remote_url>` 就是遠端。跑哪一個轉接程式，由這一點以及掃描在資料夾裡找到什麼決定。

safetensors 由進程內的後端**直接讀取**；沒有轉檔這一步，也沒有第二個引擎。因為權重是以沒有量化的形式進來的，載入時每一種量化都能選 —— 見 [Safetensors 模型](safetensors.zh-TW.md)。

視覺和各種生成式類型也在同一邊：有 `<mmproj>` projector 的模型會連同權重一起載入它，圖片／音訊／音樂／3D 模型則透過進程內的轉接程式執行，跟這個後端共用 ggml、CUDA context 和 VRAM 帳。沒有另外的服務，也沒有 Python。見 [Modality](modalities.zh-TW.md)。

> **從舊版升級。** `vllm` 和 `unsloth` 兩個後端都已經拿掉了，連同 GGUF 轉檔的退路和所有 Python worker 環境。仍然帶著 `backend` 屬性的項目照樣能用：這個屬性會被忽略，而它跟權重顯示的不一致時，server 會在啟動時記在 log 裡，請你把它刪掉。`<ai><vllm>`、`<ai><convert>` 和 `<ai><unsloth>` 區塊都不再被讀取。只有 `<modalities>` 區塊例外：server 會**拒絕啟動**，並告訴你怎麼把那些項目搬進 `<models>`，因為讀了它卻不理會，看起來就會是「設定還在，模型卻不見了」。

## Remote

`<remote_url>` 指向一個雲端的聊天 API。本機不載入任何東西，所有載入時的參數都會被忽略。

```xml
<model alias="c">
  <remote_family>anthropic</remote_family>   <!-- openai | anthropic | gemini -->
  <remote_url>https://api.anthropic.com</remote_url>
  <remote_model>claude-sonnet-4-5</remote_model>
  <remote_api_key></remote_api_key>          <!-- 空的＝在 AI config 裡提供 -->
</model>
```

這三個系列不只是 URL 不同 —— 訊息的形狀、工具呼叫的編碼和串流事件全都不一樣 —— 但這些都在 server 裡處理掉了。如果你不想把 key 放在受版本控制的檔案裡，就讓 `<remote_api_key>` 留空，改在 AI config 裡設定。

AI config 也可以不經過任何 `config.xml` 項目、直接指向一個端點，這是連到本機架設的 OpenAI 相容 server 的常見做法。

## 延遲載入

不管用哪一種後端，啟動時都不載入任何模型。指定某個模型的第一個請求進來時，才開始載入它。

所以對大模型的第一個請求，要花上整個載入的時間 —— 很大的模型要好幾分鐘。`remote` 模型則完全沒有載入這一步。

載入之後，模型會一直留著，直到被驅逐。

## 預算

本機的各個後端共用一本帳，限制同時能留著多少東西。`remote` 模型不在帳上 —— 它們在這裡什麼都不占用。

```xml
<budget>
  <ram_mb>0</ram_mb>          <!-- 0 = 自動偵測 -->
  <vram_mb>0</vram_mb>        <!-- 0 = 偵測到的每一張卡加總 -->
  <ram_ratio>0.8</ram_ratio>
  <vram_ratio>0.9</vram_ratio>
  <eviction>lru</eviction>    <!-- lru | reject -->
</budget>
```

語言模型規劃時，會把它的卡當成閒著的：放得掉的模型 —— 不管閒著還是正在用 —— 佔的記憶體都算成空的，只有釘住的模型、embedding 模型，以及 CAGE 以外的程式用掉的，才算佔用。所以模型的層放在哪裡，絕不取決於當下剛好有什麼在卡上。見 [AI config → GPU 擺放](../../client/ai-config.zh-TW.md#gpu-擺放)。

有新模型要載入時，預算會一張卡一張卡檢查，它跟已經留著的東西放不放得下。放不下的話：

- `lru` —— 從它需要的卡上驅逐閒著、沒有釘住的模型，最久沒用的先走，並**等**那些卡上正在使用的模型做完 —— 包括比它早開始載入的。還得等的請求不會先驅逐任何東西：它等的時候手上什麼都沒有，放得下的那一刻才驅逐，所以閒著的模型絕不會為了一塊還用不到的空間被丟掉。能部分在 CPU 上跑的模型，只有在卡上已經沒有東西可以驅逐時，才會把一部分移到 CPU。只有在主機 RAM 不夠、又沒有任何正在使用的東西能騰出空間時才會失敗 —— 那種情況等再久也沒用。
- `reject` —— 絕不驅逐，也絕不等待。能移到 CPU 的就移過去；還是放不下的話，請求立刻失敗。

模型上的 `<pinned>true</pinned>` 會讓它不被驅逐。對很多圖節點都會用到的小模型來說值得這樣做 —— 一個快速的輔助模型為了騰出空間給大模型而被驅逐，然後重新載入，然後又被驅逐，全是白做工。

模型沒有明確的 `est_ram_mb`／`est_vram_mb` 時，大小會從檔案大小加上一些餘裕來估計，載入之後再用真實的數字修正。

有些 GPU 保留給其他工作時，請明確設定 `vram_mb` —— 自動偵測會把它看得到的每一張卡都加進去，包括你沒打算用的那些。

偵測不只支援 NVIDIA：會依序嘗試 `nvidia-smi`、AMD 的 KFD 介面、Apple 的 `sysctl`，最後是 Vulkan，`CAGE_GPU_PROBE` 可以強制指定其中一種。modality 模型也記在同一本帳上。

在這裡找到的高速連線 —— NVLink、AMD 的 XGMI —— 也決定哪些卡可以直接讀彼此的記憶體。只有這些配對可以；其他配對經主機記憶體中轉，比較慢，但結果正確。CUDA 對只經過 CPU、走 PCIe 相連的卡也說可以直接存取，而在發現這個問題的那台機器上，這種複製送到的是 0、而且沒有任何錯誤，所以切在兩個 NVLink 群組上的模型，回答的全是 token 0。

### 運算途中卡不夠時

估計值可能偏低，CAGE 以外的程式也可能在模型擺好之後占用記憶體。這時如果一次運算用完了 VRAM，請求不會失敗。它會交還手上的東西，跟其他所有擺放一起**排隊**：

- 它的 context（KV cache 和 compute buffer）會被釋放，請求照新請求的同一套規則重新擺放。卡上閒著的模型會被驅逐，正在使用的模型則等它們做完。排隊中的請求手上什麼都沒有，所以兩個排同一張卡的請求，絕不會互相等待。
- 卡上沒有任何東西能騰出空間時 —— 剩下的是釘住的，或被 CAGE 以外的程式占用 —— 模型會重新擺放，把幾層放到 CPU 上。請求會繼續，只是變慢，而不是等那個程式離開。
- 因為空間不夠而部分擺到卡外的模型，每次閒下來都會再檢查一次：量一次它的卡，如果空間回來了，就趁沒人在用時重新把它載入回卡上。單純比它的卡還大的模型不會被檢查。
- 擺好之後，它會重新計算 prompt 和已經產生的 token，然後接著做。已經產生的東西不會遺失，也不會送兩次。

context 實際需要的比量到的多了多少，會被記下來，所以之後同樣設定的擺放會預留那些空間。生成式模型也一樣，會卸載後排隊。它沒有 CPU 可以退，所以 CAGE 裡沒有任何東西能騰出空間時，它會回報錯誤。embedding 模型也同樣會釋放 context、排隊。

沒有時間限制：排隊的請求會一直等到被擺好或被取消。等待時不會去查詢驅動。

## 不載入就問模型會放在哪裡

`cage-llama-fit` 跑的是 server 用的同一套擺放邏輯，並把它的決定以一行 JSON 印出來。什麼都不載入，所以幾秒鐘就有答案，而不是好幾分鐘。

```bash
bin/cage-llama-fit --model /models/Qwen3-Coder-Next --ctx 32768
```

| 選項 | |
|---|---|
| `--model PATH` | 模型的資料夾或檔案。必要 |
| `--quant 4bit\|8bit\|bf16\|fp16\|fp32` | 模型是 safetensors 資料夾時，用哪一種量化 |
| `--ctx N` | context 大小。**必要，而且必須 > 0** |
| `--batch N` | prompt 的批次大小 |
| `--kv f16\|q8_0\|q4_0` | KV cache 的類型 |
| `--flash on\|off` | Flash attention |
| `--rpc host:port[,…]` | 把遠端節點也納入擺放 |
| `--gpus GPU-…[,…]` | 只用這些卡，以 UUID 指定 —— 也就是 AI config 的 GPU Visibility 存的內容 |

它會回報島的切分、裝置順序、`split_mode`、`max_gpu`，以及需不需要把專家層放到 CPU。用 `--gpus` 傳入某個 AI config 選的 UUID，就能專門回答那個 config 的情況。

它旁邊需要一個[後端包](backend-packs.zh-TW.md)，原因跟 server 一樣 —— 擺放邏輯要問後端這些卡是什麼。

**長時間載入之前先用它。** 叫一個 400 GB 的模型載入，看它在八分鐘後失敗，告訴你的東西跟這個工具立刻告訴你的一樣。

## 兩個 AI config、一個模型、不同的參數

要看不同的是哪些參數。

**context 大小和批次大小**完全不用代價。context 參數跟已載入 slot 不一致的請求，會為這個請求拿到一個自己的 context，用完就釋放。模型不動。

**量化、用哪些 GPU、切分方式、GPU 層數、lookahead、MTP** 在載入時就固定了。想要不同值的請求，會等模型閒下來、卸載，再照它的方式重新載入。大模型要好幾分鐘。

已經在跑的那一輪，會用它開始時的設定跑完 —— 切換發生在兩輪之間，不會在一輪進行中發生。

> 以前的行為不一樣，也比較糟：不一致的地方會被記成 *ignored (release + reload to apply)*，然後照樣用已經載入的模型。因為哪裡都沒有 `release` 的按鈕，編輯一個 AI config —— 換量化、換卡、打開 MTP —— 都要重新啟動 server 才會生效，在那之前，執行時都默默用著舊的設定。**現在編輯圖就夠了。**

如果你需要同一個模型的兩種量化同時存在，就給它們兩個指向同一個資料夾的 alias。它們會載入成兩個獨立的 slot，兩個都留著，代價是兩份的 VRAM。

---

[← 推論伺服器](README.zh-TW.md) · [後端包](backend-packs.zh-TW.md) · [模型](models.zh-TW.md) · [Safetensors 模型](safetensors.zh-TW.md) · [Server 指南](../README.zh-TW.md)
