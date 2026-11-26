[English](example-graph.md) · **繁體中文**

# 完整範例：DemoCoder

`DemoCoder` 是一個**通用**的建置與檢查迴圈：規劃工作、寫程式、實際執行來驗證、評判報告，然後結束，或帶著錯誤把 coder 送回去重做。圖裡沒有寫任何特定的工作 —— 要做出什麼，完全由 chat 訊息決定。

**這是參考，不是下載。** 下面每一樣都是真實的檔案，一個欄位一個欄位照實記下來，沒有為了舉例而編造任何東西 —— 但指定模型、GPU 或 context 大小的部分，描述的是*某一台特定的機器*，在你的機器上是錯的。請在編輯器裡建這張圖，換成你自己的設定；這一頁的價值在於它的*形狀*：哪個節點放哪個設定，以及為什麼。

跟機器有關的欄位先列出來，讀的時候比較容易認出來：

| 欄位 | 這裡 | 在你的機器上 |
|---|---|---|
| `aiConfigs[].model` | `qwen-coder-next`、`nemotron-3-embed-1b` | 你的 server 在 `config.xml` 裡定義的 alias。AI Config 面板會列出來 |
| `aiConfigs[].cudaVisibleDevices` | 預留位置的 UUID | 你自己的卡（`nvidia-smi --query-gpu=uuid --format=csv`），或留空，用 server 看得到的每一張卡 |
| `aiConfigs[].ctxSize` | `262144` | 你的卡和模型允許多少就給多少 —— 這張圖需要餘裕，見下方 |
| `ragEmbeddingConfig` | `rag` | 有 embedding 模型才需要。留空就是關閉檢索，對這張圖的結構毫無影響 |

每個欄位的作用和可選的值，見 [AI Configs](ai-config.zh-TW.md)。剛裝好的 server 也完全沒有圖 —— server 工作目錄底下的 `data/logic_graphs/`，要等 client 上傳之後才會有東西。

這一頁列出每一個參數，並說明為什麼這樣設。其中三個並不明顯，每一個都來自一次默默失敗的執行，集中寫在[三個不明顯的設定](#三個不明顯的設定)。

檔案格式本身見[邏輯圖檔案格式](graph-format.zh-TW.md)；每種節點做什麼，見[節點類型](nodes.zh-TW.md)。

---

## 執行流程

```
Start ──Exec──▶ Planner ──Exec──▶ Coder ──Exec──▶ Verifier ──Exec──▶ Filter ──Exec──▶ Shape ──True──▶ Gate ──Case 1──▶ End
  │                 ▲                ▲                                   │              │                  │
  └──PROMPT─────────┴────────────────┤                                   │              └──False───────────┤
                                     │                                   │                                 │
                                     └───────────────Errors──────────────┘                                 │
                                     ▲                                                                     │
                                     └──────────────────────────Else───────────────────────────────────────┘
```

有兩條連線從迴圈回到 coder：`Shape.False`（filter 的回覆不是有效的 JSON）和 `Gate.Else`（是有效的 JSON，而且說檢查沒過）。兩條都重新進入 `Coder`，執行器允許這樣做 —— 回頭的連線會清掉「已走過」的標記，節點再跑一次。

**沒有迭代次數上限。** filter 回報通過，迴圈才結束。要上限的話，加一個 `Variable` 計數器和第二個 `If`；這張圖刻意不加，讓一次執行要嘛收斂，要嘛由你停下來。

---

## 外層結構

```json
{
  "name": "DemoCoder",
  "projectId": "",
  "owner": "",
  "ragEmbeddingConfig": "rag",
  "memoryAiConfig": "",
  "version": 3,
  "updatedAt": 0,
  "modalityConfigs": [],
  "variableConfigs": [],
  "groups": []
}
```

`owner` 和 `updatedAt` 在這裡清空了；真正的檔案裡記著存檔的帳號和時間。

| 欄位 | 為什麼 |
|---|---|
| `ragEmbeddingConfig: "rag"` | 指定用來做 embedding 的 AI config。**空的表示 RAG 關閉，不是「用預設值」** —— 建索引和查詢兩邊讀的都是這一個欄位，所以兩邊永遠不會落在不同的向量空間 |
| `memoryAiConfig: ""` | 沒有記憶 AI。有條件的規則全部適用，也不讀任何檔案歷史或 [session 紀錄](memory.zh-TW.md#自動寫下的-session-紀錄) —— 紀錄還是照寫。這張圖改用共用記憶（下面的 `memory_mode`），在各輪之間帶著 coder 需要的東西 |
| `variableConfigs: []` | 沒有整張圖的狀態。跨過節點邊界的東西全部走 pin |

---

## AI Configs

有兩個，做的事很不一樣。**這些值是這台機器的** —— 讀它們是為了知道哪個欄位重要、為什麼，不是拿來照抄的設定。你該怎麼設，寫在[在你的機器上建立它](#在你的機器上建立它)。

```json
{
  "name": "coder",
  "model": "qwen-coder-next",
  "quantization": "",
  "isRemote": false,
  "remoteUrl": "", "remoteApiKey": "", "remoteFamily": "",
  "ctxSize": 262144,
  "nBatch": 0, "threads": 0,
  "flashAttn": true,
  "nGpuLayers": -1,
  "kvCacheType": "f16",
  "splitMode": "layer",
  "nCpuMoe": 0,
  "autoFit": false,
  "lookahead": false,
  "mtp": false,
  "cudaVisibleDevices": "GPU-<uuid-1>,GPU-<uuid-2>,GPU-<uuid-3>,GPU-<uuid-4>",
  "temperature": 0.7, "topK": 40, "topP": 0.9,
  "reasoningBudget": -1, "presencePenalty": 0
}
```

| 欄位 | 為什麼是這個值 |
|---|---|
| `ctxSize: 262144` | 每個節點共用一段對話（見下面的 `memory_mode`），所以 context 每一輪都會變長。先試過 16K 和 80K，兩個都爆了 —— 爆的時候會明確報出 `Input tokens (…) exceed` 錯誤，不會默默截斷 |
| `cudaVisibleDevices` | **你自己的卡的 UUID** —— `nvidia-smi --query-gpu=uuid --format=csv`。上面的是預留位置，不是真的：載入這張圖的機器上，列出的卡一張都不在的話，請求會失敗並說明原因 —— 絕不會改用其他卡。這個範例取自的那張圖列了四張運算卡，刻意排除顯示卡，這通常也是會去設這個欄位的原因 |
| `autoFit: false` | 這裡的擺放是手動設定的：在列出的四張卡上依層切分。開著 Auto Fit（預設值）的話，卡片清單一樣有效，切分方式則由 server 自己選 |
| `splitMode: "layer"` | 在四張卡之間依層切分。卡片之間全部有 NVLink 相連時，Auto Fit 會選 `graph`（tensor parallelism） |
| `lookahead: false` | 在 Volta 上，試過的每一組參數都比一般解碼慢 |

```json
{
  "name": "rag",
  "model": "nemotron-3-embed-1b",
  "quantization": "fp16",
  "ctxSize": 65536,
  "autoFit": true,
  "nGpuLayers": -1,
  "cudaVisibleDevices": "GPU-<uuid-1>,GPU-<uuid-2>,GPU-<uuid-3>,GPU-<uuid-4>",
  "…": "remaining fields as above"
}
```

embedder 自成一個 config，只是因為它是另一個模型；指定它的是 `ragEmbeddingConfig`，不是任何節點。它跟其他模型一樣遵守 `cudaVisibleDevices` —— 要設，不然 embedder 會載入在排第一的那張卡上，而在混用不同卡的機器上，那通常是顯示卡。

`nemotron-3-embed-1b` 以 safetensors 發布，進程內的後端直接讀它 —— 沒有轉檔這一步，量化在載入時做。

---

## Format Config

一個，由兩個節點引用。

```json
{
  "name": "verdict",
  "type": "json_keys",
  "pattern": "",
  "fields": [
    { "key": "Pass",
      "description": "true if every check passed, otherwise false",
      "required": true },
    { "key": "Errors",
      "description": "on failure, only the real error lines with file and line; none on success",
      "required": true }
  ]
}
```

`json_keys` 格式一次做兩件事。在 `Filter` 節點上，它是結構化輸出的 schema —— 欄位說明會交給模型，鍵則變成輸出 pin。在 `Shape` 節點上，它是驗證規則。這就是兩邊引用同一個名字的原因：產生 JSON 的一方和檢查它的一方，從一開始就講好了同一件事。

---

## 節點

### Start

```json
{ "start_name": "Default" }
```

`out[Exec, PROMPT, ASSET]`。`PROMPT` 就是 chat 訊息，一字不改。這張圖把它餵給兩個節點。

### Planner（`SendToAi`）

`in[Exec, Asset, Request]` → `out[Exec, ALL, Asset]`

```json
{
  "ai_config": "coder",
  "format_config": "",
  "prompt_template": "…{{Request}}…",
  "tools_enabled": false,
  "allowed_tools": "*",
  "max_tool_iters": 5,
  "rag_mode": "inherit",
  "rag_embedding_config": "",
  "memory_context": true,
  "memory_history_top_k": 0,
  "memory_mode": "shared",
  "chunking": false,
  "chunk_desc": ""
}
```

`Request` 是一個有名字的輸入 pin，範本以 `{{Request}}` 引用它。**有名字的 pin 只有在範本提到它時，才會送到模型那裡** —— 光接線沒有用。早期有一次失敗就是這樣，planner 自己編了一個工作出來：pin 接上了、預留位置沒寫，planner 從頭到尾沒看到使用者的要求。

`tools_enabled: false`，因為規劃不是工具的工作；planner 有工具的話，會把預算花在讀工作區，而不是寫計畫。

prompt 要求三份清單 —— WORK、DELIVERABLES、CHECKS。會有 DELIVERABLES，是因為早期有一次產生的測試腳本，把它剛做出來的 atlas 刪掉了：沒有任何東西告訴任何人，程式的輸出才是重點，而不是暫存檔。CHECKS 那一段堅持檢查內容而不是檢查存在，是因為有一次只斷言「檔案在、能解析成 JSON」，結果放行了一份每個座標都是 `-1` 的 manifest。

### Coder（`SendToAi`）

`in[Exec, Asset, Request, Errors]` → `out[Exec, ALL, Asset]`

設定的形狀一樣，差在：

| 欄位 | 值 | 為什麼 |
|---|---|---|
| `tools_enabled` | `true` | 它要寫檔 |
| `max_tool_iters` | `20` | 當時的預設值是 5，不夠寫完一支小程式：迴圈提早結束，節點什麼都沒回傳。現在的預設值是 `0`，沒有上限 |
| `memory_mode` | `"shared"` | 第二輪以後，它需要知道自己已經寫了什麼 |

兩個有名字的輸入 pin，範本都有引用：`{{Request}}`（原本的要求，讓後面幾輪不會偏掉）和 `{{Errors}}`（filter 抽出來的錯誤）。第一輪時 `Errors` 沒有值，會展開成空字串 —— 這是刻意的放行，見[三個不明顯的設定](#三個不明顯的設定)裡的說明。

prompt 裡的每一條規則，都是某一次失敗留下來的：*一件工作一個檔案*和*就地修改*，來自一輪產生了三十個檔案、裡面有兩份實作和三支測試腳本的經驗；*程式的輸出是交付物*，來自那支會刪掉自己成果的測試腳本；*不要建置或執行任何東西*，是為了讓角色分開，因為兼做驗證的 coder 會把自己的成果報成通過。

最後一條規則 —— *DELIVERABLES 會在之後產生，由 verifier 建置並執行你寫的東西時做出來* —— 是前面兩條互相衝突的結果。coder 讀計畫，DELIVERABLES 寫著「執行程式產生」，同時又被告知不准執行任何東西；沒有任何一條說交付物由誰產生。停下來想調和這兩條的 coder，花了一次 20,000 token 的生成 —— 四十分鐘 —— 在推理裡反覆考慮要不要手寫一張二進位圖片、用暫時寫的小工具算不算執行，還把整支程式在推理裡重寫了一遍，然後才做出第一個工具呼叫。在同一個 context 裡，四次有三次這樣；加上這條規則後，試的兩次都立刻開始動手。

### Verifier（`SendToAi`）

`in[Exec, Asset]` → `out[Exec, ALL, Asset]`

`tools_enabled: true`、`max_tool_iters: 20`、`memory_mode: "shared"`，沒有有名字的輸入 pin —— 它直接讀工作區，不靠別人遞東西給它。

它的 prompt 是整張圖裡最長的，每一條都是某次執行打破過的規則：

- 每一輪都從原始碼建置，並且自己執行程式。不要假設上一輪的建置結果或產物還在。
- 所有東西留在原地，不要清理。
- coder 寫的東西如果會刪掉交付物，那就是缺陷 —— 要報成程式碼的錯，而不是檔案不見了。少了這一條，迴圈沒辦法收斂：產物每一輪都不見，卻沒有任何東西指出原因。
- 評判結果，不是評判執行。結束碼 0 和一行成功訊息都只是說法。該放真實結果的地方放著哨兵值，就是失敗。
- 追一個值從頭到尾：在輸入那邊找一個認得出來的東西，在輸出那邊找到它，確認它完好地留了下來。形狀對、內容錯的輸出，一樣是失敗。

### Filter（`SendToAi`）

`in[Exec, Asset, Transcript]` → `out[Exec, ALL, Asset, Pass, Errors]`

```json
{
  "ai_config": "coder",
  "format_config": "verdict",
  "prompt_template": "…{{Transcript}}…",
  "tools_enabled": false,
  "max_tool_iters": 5,
  "rag_mode": "off",
  "memory_context": true,
  "memory_history_top_k": 0,
  "chunking": false
}
```

`Pass` 和 `Errors` 是以格式的鍵命名的**輸出** pin，所以結構化的回覆會替你拆好，兩半可以各自接到不同的地方。

沒有工具，也沒有共用記憶：它的輸入就只有 `{{Transcript}}`，它的工作就只是把 verifier 寫的一整頁文字，變成一個布林值和一份簡短的錯誤清單。`rag_mode` 是 `off`，這是下面三個不明顯的設定裡的第三個。

### Shape（`CheckFormat`）

`in[Exec, Input]` → `out[True, False, Output]`

```json
{ "format_config": "verdict", "error_message": "" }
```

拿 filter 拿到的同一份 schema，來驗證 filter 的回覆。`True` 繼續走到 gate；`False` 回到 coder —— 解析不了的判決，就當作這一輪要重做。

### Gate（`If`）

`in[Exec, Input, IfPass]` → `out[Case 1, Else]`

```json
{
  "cases": [{
    "name": "Case 1",
    "value_type": "bool",
    "operator": "is_true",
    "compare_value": "",
    "json_path": "",
    "source_type": "input",
    "source_key": "IfPass",
    "source_variable": "",
    "case_sensitive": true
  }]
}
```

`source_type: "input"` 加上 `source_key: "IfPass"`，就是讀那個有名字的輸入 pin。內建的 `Input` pin 這個節點沒用到 —— 這對 `If` 來說很正常，它是用名字指定來源的。

### End

```json
{ "result_keys": [] }
```

---

## 連線

十五條。四條是資料，其餘是控制流程。

| 從 | 到 | 種類 | 為什麼 |
|---|---|---|---|
| `Start.Exec` | `Planner.Exec` | exec | 入口 |
| `Start.PROMPT` | `Planner.Request` | 資料 | 使用者的要求 |
| `Start.PROMPT` | `Coder.Request` | 資料 | 同一個要求，讓後面幾輪不會偏掉 |
| `Planner.Exec` | `Coder.Exec` | exec | |
| `Coder.Exec` | `Verifier.Exec` | exec | |
| `Verifier.Exec` | `Filter.Exec` | exec | |
| `Verifier.ALL` | `Filter.Transcript` | 資料 | verifier 的整份回覆，成為 filter 的輸入 |
| `Filter.Exec` | `Shape.Exec` | exec | |
| **`Filter.ALL`** | **`Shape.Input`** | **資料** | **必要 —— 見下方** |
| `Filter.Pass` | `Gate.IfPass` | 資料 | gate 依它分支的判決 |
| `Filter.Errors` | `Coder.Errors` | 資料 | 下一輪據以修改的回饋 |
| `Shape.True` | `Gate.Exec` | exec | JSON 有效 → 做判斷 |
| `Shape.False` | `Coder.Exec` | exec | JSON 無效 → 這一輪重做 |
| `Gate.Case 1` | `End.Exec` | exec | 通過 → 結束 |
| `Gate.Else` | `Coder.Exec` | exec | 沒通過 → 帶著錯誤重做 |

注意 `Start.PROMPT` 接到兩個節點。exec 輸出只有一個目標；**資料輸出可以分給好幾個。**

---

## 三個不明顯的設定

### 1. `Filter.ALL → Shape.Input` —— `CheckFormat` 需要它的資料連線

只接 `Filter.Exec → Shape.Exec`，在畫布上看起來是完整的，結構上也有效，但是不夠。`CheckFormat` 驗證的是 `Input` 收到的東西；那裡沒有連線，它就驗證空字串，失敗，然後每一輪都走 `False`。

症狀是迴圈永遠不收斂，**而且 `If` 節點一次都沒執行過** —— `Shape.False` 直接回到 coder，gate 根本到不了。哪裡都沒有錯誤訊息，因為資料連線就是 `ctx.set(toPort, ctx.get(fromPort))`，而解析不到的鍵刻意當成空字串。這種放行在別的地方是需要的（第一輪時 `{{Errors}}` 沒有值，不該把預留位置原樣印給模型看），也正是它讓這個錯誤變得無聲無息。

**迴圈不收斂時，數一數每個節點跑了幾次。** 執行次數是零的節點，是接線的問題，不是模型的問題。

### 2. `memory_mode` —— 執行者共用，評判者隔離

Planner、Coder 和 Verifier 用 `"shared"`。每一個的最終回答都會附加到 session 層級的同一段對話裡，每一個在自己的 prompt 之前都會看到這段對話的投影。所以重新進入的 `Coder` 知道自己上一輪寫了什麼、verifier 怎麼說，這些都不用經過 pin 傳遞。

`Filter` 維持 `"isolated"`（預設值）。它的輸入是一份紀錄，輸出是一個判決；把對話給它，等於讓它兩輪前做的判決影響現在這一個 —— 跟評判者該做的事正好相反。

從 log 看得到效果：`memory=shared: seeded N messages`，N 每一輪每個節點加一。

兩個編輯器都沒有 `memory_mode` 的欄位。要在檔案裡節點的 `config` 設定它 —— **Export**、修改、再 **Import** —— 或照 [graph-format.zh-TW.md](graph-format.zh-TW.md) 整張手寫；這一頁其他的設定都能在編輯器裡設。

你的訊息一送達就加入那段對話。如果這次執行結束時，沒有任何共用節點回答過它 —— 執行被停下、失敗、根本沒開始，或只由隔離的節點回答 —— server 會自己補上回答：這次執行的最終結果，或一行說明它發生了什麼事。下一則訊息的節點，絕不會看到你連續兩則訊息中間什麼都沒有。

### 3. Filter 的 `rag_mode: "off"` —— 檢索會污染判斷

檢索到的 context 會以 `### file (lines A-B)` 區塊的形式加在 prompt 前面，內容是依相似度挑出來的程式碼。對要處理程式碼庫的節點，這是幫助；對工作是評判一個回答的節點，這是錯誤種類的證據，而模型會從片段裡得出片段根本撐不起來的結論。

用 `rag_mode: "inherit"` 時，這個 filter 連續四輪回傳 `Pass=false`，錯誤像這樣：

```
packer.cpp:169-173: incomplete code block: missing closing brace
packer.cpp:248-341: missing code after line 341
```

這些行數範圍，一個對一個，正是同一次除錯輸出裡印出來的 RAG 切塊邊界。程式從頭到尾都能編譯、執行也正確。沒有任何東西報錯；迴圈就是結束不了。

**評判一段文字、而不是評判程式碼庫的節點，應該關掉 RAG。** 檢索查詢用的是 `PROMPT` —— 原本的 chat 訊息 —— 所以評判者拿回來的是「長得像原本要求的程式碼」，而這些它本來就能用工具直接讀。`Planner` 和 `Coder` 維持 `"inherit"`，因為在既有的程式碼裡找方向，正是檢索的用途。

---

## 它做出了什麼

實際量過的一次執行，數字才有意義：

| | |
|---|---|
| Chat 訊息 | *"A C++17 texture packer: pack a folder of TGA files into one atlas image plus a JSON manifest. Standard library only."* |
| 硬體 | 4 × Tesla V100-SXM2-32GB，`qwen-coder-next`，context 262144 |
| 結果 | **第一輪**就收斂，`Pass=true` → `End` |
| 實際耗時 | 15 分 23 秒 —— planner 12.7 秒、coder 8 分 41 秒、verifier 6 分 28 秒、filter 1.0 秒 |
| 產出 | 三種尺寸、兩種位元深度的 7 張 TGA，打包成一張 720×256 的 atlas，加上一份 JSON manifest |
| 事後檢查 | 像素資料跟來源逐位元組相同；manifest 的座標正確 |
| 這條流程沒抓到的 | 輸出的 TGA 的 descriptor 位元組，原點旗標跟輸入相反，所以看圖程式會把 atlas 上下顛倒顯示。像素是對的，標頭不是 |

最後一列就是這種安排的誠實極限。planner 寫的檢查、verifier 跑的檢查，都是關於幾何和內容，兩者也都滿足了。標頭裡一個位元組的旗標，在任何人想到要檢查的範圍之外。

---

## 在你的機器上建立它

結構可以照搬，AI config 不行。依序：

1. **一開始一個 AI config 就夠了。** 取個名字，選一個你的 server 真的有的模型，四個 `SendToAi` 節點都指向它。每個角色用不同的模型是之後的改進，不是必要條件。
2. **context 盡量給大。** 用 `memory_mode: "shared"` 時，對話每一輪每個節點多一則訊息，所以會跑好幾輪的迴圈需要餘裕。你的卡挪不出來的話，把三個執行者設成 `"isolated"`，改用 pin 傳遞它們需要的東西 —— 圖一樣能用，只是各輪之間記得的比較少。溢出時會明確報出 `Input tokens (…) exceed` 錯誤，不會默默截斷，所以你會知道。
3. **檢索可有可無。** 沒有 embedding 模型，或不想建索引 —— `ragEmbeddingConfig` 留空，每個 `rag_mode: "inherit"` 就什麼都不做。結構上沒有任何東西依賴它。如果要開，Filter 維持 `"off"`。
4. **選 GPU 也可有可無。** `cudaVisibleDevices` 留空，模型就用 server 看得到的每一張卡，連顯示卡也算在內。機器裡有某張卡不該碰時才設 —— 顯示卡，或另一個工作正在用的卡。

然後，工作寫在 chat 訊息裡，不是寫在圖裡。

## 改變它的行為

| 想要 | 改法 |
|---|---|
| 每個角色用不同的模型 | 加幾個 AI config，讓每個節點的 `ai_config` 各指向一個。其他都不用改 |
| 迭代次數上限 | 在回頭的連線上遞增一個 `Variable` 計數器，再在 `Coder` 前面加一個 `If` |
| 便宜一點的評判者 | 把 `Filter.ai_config` 指向小模型。它只負責分類文字 |
| 少跑幾輪 | 加強 planner 裡 CHECKS 那一段。多出來的輪數，大多來自第一次弱到不會失敗的檢查 |
| 不同形狀的流程 | 四個 prompt 跟接線無關。把「verifier」換成「test runner」或「security reviewer」，是改 prompt，不是改圖 |

---

[← 邏輯圖檔案格式](graph-format.zh-TW.md) · [節點類型](nodes.zh-TW.md) · [AI Configs](ai-config.zh-TW.md) · [RAG](rag.zh-TW.md) · [Client 指南](README.zh-TW.md)
