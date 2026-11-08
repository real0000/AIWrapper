[English](graph-format.md) · **繁體中文**

# 邏輯圖檔案格式

一張邏輯圖就是一個 JSON 檔。這一頁把它完整定義清楚，讓一支程式 —— 包括被要求「做一張能做到 X 的圖」的 AI agent —— 不用打開編輯器，也能寫出一張有效的圖。

這裡的內容全部取自實作：
`server/include/logic/LogicGraph.hpp`（資料模型）、
`server/src/logic/nodes/*.cpp`（每種節點從 `config` 讀什麼），以及
`client/extension/src/logic/nodeLibrary.ts`（編輯器寫出的 pin 與預設值）。

---

## 檔案放在哪裡

| | |
|---|---|
| 路徑 | server 的邏輯圖存放區：server 工作目錄底下的 `data/logic_graphs/` |
| 檔名 | `<name>.json`。圖的 `name` 就是它的身分：唯一、比較時不分大小寫，也是它的檔名。檔名跟 `name` 不一樣的檔案，會在 server 啟動時改名成跟 `name` 一致 |
| 怎麼放進去 | 寫好檔案後重新啟動 server、用 `PUT` 送到 `/api/logic-graph`，或在 Logic Editor 裡用 **Import** |

編輯器的 **Export** 寫出來的就是這個格式，所以這一頁沒講清楚的地方，現有的圖就是最好的參考。

> 下面有些範例用 `//` 註解來說明欄位。**JSON 沒有註解** —— 寫檔之前要先刪掉。最後那張[完整的最小圖](#一張完整的最小圖)沒有註解，可以直接複製使用。

---

## 外層結構

```json
{
  "name":               "SimpleCoder",
  "projectId":          "",
  "owner":              "",
  "ragEmbeddingConfig": "",
  "memoryAiConfig":     "",
  "version":            1,
  "updatedAt":          0,
  "nodes":              [],
  "connections":        [],
  "aiConfigs":          [],
  "modalityConfigs":    [],
  "formatConfigs":      [],
  "variableConfigs":    [],
  "groups":             []
}
```

| 欄位 | 意思 |
|---|---|
| `name` | 圖的身分與檔名，顯示在 graph 選單裡。不分大小寫的唯一值。不能有 `/`、`..`，結尾不能是空格或句點。改名是另一個獨立的操作（`POST /api/logic-graph/rename`）：用新名字存檔會變成第二張圖 |
| `projectId` | 這張圖所屬的專案資料夾。空的也可以 |
| `owner` | 擁有者的使用者 id。**空的表示沒有擁有者 —— 任何人都能讀寫。** server 有帳號的話就要設定 |
| `ragEmbeddingConfig` | `aiConfigs` 裡某個項目的名字，用於自動檢索。空的表示關閉 |
| `memoryAiConfig` | `aiConfigs` 裡某個項目的名字：記憶 AI，負責挑選每一步要讀哪些記憶、濃縮 session 紀錄、決定要寫回什麼。空的話，每一條有條件的規則都視為適用，也不讀任何檔案歷史或 session 紀錄，見[專案記憶](memory.zh-TW.md) |
| `version` | 編輯器每次存檔都會加一；server 會拒絕版本比它自己那份舊的更新。**從 1 開始** |
| `updatedAt` | Unix 毫秒。`0` 也接受 |
| `groups` | 視覺上的分組。除非你要重現編輯器的版面，否則填 `[]` |

八個清單欄位都必須存在，即使是空的。

---

## 節點

```json
{
  "id":       "5b0c1f2e-8d4a-4f7b-9c3e-2a6d8e1f4b70",
  "type":     "Start",
  "title":    "Start",
  "category": "start",
  "position": { "x": -420, "y": 400 },
  "inputs":   [],
  "outputs":  [ { "name": "Exec", "type": "exec", "direction": "output", "id": "…" } ],
  "config":   { "start_name": "Default" },
  "singleton": true
}
```

| 欄位 | 必要 | 說明 |
|---|---|---|
| `id` | 是 | UUID，在這張圖裡唯一。連線會引用它 |
| `type` | 是 | 下面十二種類型之一 |
| `title` | 是 | 自由文字，顯示在節點上 |
| `category` | 是 | 用來上色：`start`、`ai`（Send To AI、Dispatch、Send Prompt、Ask User）、`check`、`logic`、`variable`、`compose`、`memory`、`end`（Return、End） |
| `position` | 是 | 編輯器座標。什麼數字都可以；圖由左往右排、間隔約 250 px，不然會疊在一起 |
| `inputs` / `outputs` | 是 | pin 陣列，見各類型。每個 pin 需要 `name`、`type`、`direction`；`id` 可以省略 |
| `config` | 是 | 各類型的設定。這種類型沒有設定的話就填 `{}` |
| `singleton` | 否 | `Start` 和 `End` 上是 `true`。只是給編輯器的提示 |
| `groupId` | 否 | 只有節點在群組裡時才有 |

### Pin 型別

`exec` 是控制流程。其他都是資料：`string` 最常見，`asset`／`image`／`audio`／`tts`／`music`／`mesh`／`motion` 帶的是一個產生出來的檔案的參照，而不是文字。

**這個區別很重要。** `exec` 連線會轉移控制權 —— 它會把下游節點排進執行佇列。資料連線只會把一個值複製到下游的輸入欄位，**不會**讓它執行。沒有任何 `exec` 連線進來的節點，不管有多少資料連線，都永遠不會執行。

---

## 連線

```json
{
  "id":         "9e4a7c21-3b5d-4e8f-a1c6-7d2b0f9e3a58",
  "fromNodeId": "5b0c1f2e-…",
  "fromPinId":  "Exec",
  "toNodeId":   "c3f81a96-…",
  "toPinId":    "Exec"
}
```

`fromPinId` 和 `toPinId` **用 pin 的 `name` 或它的 `id` 都可以** —— server 會把 id 解析成它所屬的名字，解析不了的就當作名字。名字比較好寫，這一頁用的也是名字；編輯器寫出的是 id。隨附的圖兩種都有。

請用標準的 `connections` 陣列。`edges` 是舊的載入路徑，會假設每一條連線都是控制流程。

---

## 節點類型

**下面列的 pin，是編輯器建立新節點時會建的那些，不是最低需求。** pin 只有在有東西接它時才必須存在，實際的圖常常省略用不到的 pin —— 沒有接任何多模態東西時，`SendToAi` 沒有 `Asset`；`Start` 沒有 `ASSET`；`If` 的 case 改從變數讀取時，沒有 `Input`。

實際上一定要有的 pin 只有 `Exec`：沒有 `exec` 連線進來，節點就永遠不會執行。可以自己加 pin 的類型，下面都會寫明。

### `Start`：入口
`in[]` → `out[Exec, PROMPT, ASSET]`

`PROMPT` 帶著使用者的訊息；`ASSET` 帶著任何附加檔案。

```json
"config": { "start_name": "Default" }
```

一張圖可以有好幾個 `start_name` 不同的 `Start` 節點；chat panel 的 Start 選單在它們之間選擇。其中一個必須命名為 `Default`。

### `SendToAi`：呼叫模型
`in[Exec, Asset]` → `out[Exec, ALL, Asset]`

**每個 prompt 變數加一個 `string` 輸入 pin**，再在範本裡以 `{{pinName}}` 引用。`ALL` 是完整的回覆。加上以結構化輸出的鍵命名的 `string` 輸出 pin，它們就會替你拆出來。

```json
"config": {
  "ai_config": "planner",          // aiConfigs 裡的名字 —— 必要
  "format_config": "",             // formatConfigs 裡的名字；會開啟結構化輸出
  "prompt_template": "Plan: {{Task}}",
  "tools_enabled": true,
  "allowed_tools": "*",            // "*" 或以逗號分隔的清單
  "max_tool_iters": 0,             // 0 = 沒有上限
  "rag_mode": "inherit",           // inherit | off | custom
  "rag_embedding_config": "",      // rag_mode="custom" 時使用
  "memory_context": true,
  "memory_history_top_k": 0,       // 0 = 保留每一份檔案歷史
  "memory_filter_config": "",
  "chunking": false,
  "chunk_desc": ""
}
```

載入與取樣參數可以在個別節點上用這些鍵覆寫：`ai_model`、`ai_ctx_size`、`ai_quantization`、`ai_n_gpu_layers`、`ai_split_mode`、`ai_kv_cache_type`、`ai_flash_attn`、`ai_auto_fit`、`ai_n_cpu_moe`、`ai_n_batch`、`ai_threads`、`ai_lookahead`、`ai_mtp`、`ai_cuda_visible_devices`、`temperature`、`top_k`、`top_p`、`reasoning_budget`。省略就用 AI config 的值。

> 把 `ai_config` 改指向 `modalityConfigs` 裡的名字，節點就會變成生成呼叫 —— 圖片、語音等等。回覆是 `Asset` pin 上的檔案參照，不是文字。

### `CheckFormat`：驗證字串
`in[Exec, Input]` → `out[True, False, Output]`

```json
"config": { "format_config": "plan_json", "error_message": "" }
```

### `If`：分支
`in[Exec, Input]` → `out[Case 1, Else]`

每個 case 加一個輸出 pin；pin 的名字必須依序跟 case 的 `name` 一致。只有某個 case 是 `source_type: "input"` 時才需要 `Input` —— 從變數讀取的 case 不需要它。

```json
"config": {
  "cases": [
    {
      "name": "Case 1",
      "source_type": "input",       // input | variable
      "source_key": "Input",        // source_type=input 時，用哪個輸入 pin
      "source_variable": "",        // source_type=variable 時，用哪個變數
      "value_type": "string",       // string | number | bool | json | enum
      "operator": "is_not_empty",
      "compare_value": "",
      "json_path": "",              // value_type=json 時使用
      "case_sensitive": true
    }
  ]
}
```

各 `value_type` 的運算子：

| `value_type` | 運算子 |
|---|---|
| `string`（預設） | `equals`、`not_equals`、`contains`、`not_contains`、`starts_with`、`ends_with`、`regex`、`is_empty`、`is_not_empty` |
| `number` | `equals`、`not_equals`、`less_than`、`less_or_equal`、`greater_than`、`greater_or_equal`、`is_empty`、`is_not_empty` |
| `bool` | `is_true`、`is_false`、`is_empty`、`is_not_empty` |
| `json` | `has_key`、`path_equals`、`is_valid`、`is_empty`、`is_not_empty` |
| `enum` | `equals`、`not_equals`、`is_empty`、`is_not_empty` —— 永遠區分大小寫 |

case 依序嘗試；第一個符合的勝出，都不符合就走 `Else`。

### `Variable`：讀寫整張圖的狀態
`in[Exec]` → `out[Exec]`

```json
"config": {
  "items": [
    { "variable": "counter", "op": "set",   // set | add
      "source_type": "constant",            // constant | node | variable
      "source_value": "0" }
  ]
}
```

`add` 依變數宣告的 `type`，分別是數字相加、字串串接或邏輯 OR。

### `Compose`：組出一個字串
`in[Exec]` → `out[Exec, Output]`

每個值加一個 `string` 輸入 pin。範本用同樣的 `{{name}}` 語法引用輸入 pin **和**整張圖的變數。

```json
"config": { "template": "Task: {{Task}}\nGoal: {{goal}}" }
```

### `Memory`：以文字形式提供專案記憶
`in[Exec, Input]` → `out[Exec, Memory]`

```json
"config": { "ai_config": "", "token_budget": 0, "history_top_k": 0 }
```

一個 `Memory` 節點可以餵好幾個 `SendToAi` 節點，這正是它存在的意義。

### `Dispatch`：拆分工作，一項一項執行
`in[Exec, Input]` → `out[Step, Task, Index, Plan, End]`

由一個 splitter 模型把輸入變成一份清單；每一項觸發一次 `Step`，同時設好 `Task` 和 `Index`，全部結束後 `End` 觸發一次。

```json
"config": {
  "splitter_ai_config": "planner",
  "parallel_enabled": false,
  "max_parallel": 0               // 0 = 沒有上限
}
```

**每一條 `Step` 分支都要以 `Return` 結束，不是 `End`。**

### `SendPrompt`：把工作交給另一張圖
`in[Exec, Prompt, Asset]` → `out[Exec, Result, Asset]`

在同一個 session 裡執行另一張圖一次，再把它的結果拿回來。

```json
"config": {
  "graph_name": "Coder",          // 另一張圖的名字 —— 必要
  "entry": "",                    // 它的 Start 的 start_name；空的 = 它的第一個 Start
  "max_depth": 0                  // SendPrompt 呼叫最多能巢狀幾層；0 = 沒有上限
}
```

### `AskUser`：詢問操作者
`in[Exec, Input]` → `out[Exec, Answers, Asked]`

```json
"config": {
  "ai_config": "",         // 判斷是否值得詢問
  "criteria": "",
  "max_questions": 0,      // 0 = 沒有上限
  "allow_free_text": true
}
```

### `Return`：結束一條分支
`in[Exec]` → `out[]`

```json
"config": { "note": "" }
```

宣告這條路刻意在這裡停下。它不回傳結果，也不會結束這一輪。

### `End`：結束這一輪
`in[Exec, Result]` → `out[]`

```json
"config": { "result_keys": [] }
```

把結果回傳給使用者，並結束這一輪。**只能從主路徑走到** —— 絕不能從 `Dispatch` 的分支走到。

---

## 四份設定清單

### `aiConfigs`

```json
{
  "name": "planner",
  "model": "Qwen3-Coder-Next",
  "isRemote": false,
  "quantization": "",
  "ctxSize": 0,          // 0 = 預設值：32K，模型的上限比較短的話就用上限
  "nBatch": 0,
  "threads": 0,
  "flashAttn": true,
  "nGpuLayers": -1,      // -1 = 自動
  "kvCacheType": "f16",
  "splitMode": "layer",  // layer | row | tensor | none —— 只在 autoFit 關閉時使用
  "nCpuMoe": 0,
  "autoFit": true,
  "lookahead": false,
  "mtp": false,
  "cudaVisibleDevices": "",   // GPU UUID，以逗號分隔；空的 = 每一張 GPU
  "temperature": 0.7,
  "topK": 40,
  "topP": 0.9,
  "reasoningBudget": -1,      // -1 = 不限制
  "presencePenalty": 0        // 0 = 關閉
}
```

代管的端點則設 `"isRemote": true`，加上 `remoteUrl`、`remoteApiKey` 和 `remoteFamily`（`openai` | `anthropic` | `gemini`）；這時載入參數會被忽略，取樣參數仍然有效。

`autoFit: true` 是預設值，會依機器實際的拓樸決定切分方式、裝置順序與專家層放到 CPU 的方式。

### `variableConfigs`

```json
{ "name": "counter", "type": "number", "defaultValue": "0",
  "description": "", "enumValues": [] }
```

`type` 是 `string` | `number` | `bool` | `enum`。變數只存在於一輪執行之中。

### `formatConfigs`

```json
{ "name": "plan_json", "type": "json",   // json | json_keys | regex | non_empty
  "pattern": "",
  "fields": [ { "key": "steps", "description": "…", "required": true } ] }
```

在 `SendToAi` 節點的 `format_config` 裡指定它，也會開啟結構化輸出，所以 `fields` 值得填好。

### `modalityConfigs`

```json
{ "name": "sd35", "type": "image",      // image | tts | audio | music | mesh
  "isRemote": false,
  "modalityAlias": "sd35",              // server 設定裡的 <model alias>
  "cudaVisibleDevices": "",
  "defaults": {} }
```

---

## 決定一張圖能不能執行的規則

1. **每個入口剛好一個 `Start`**，其中一個命名為 `Default`。
2. **每個節點都需要有 `exec` 連線進來**，直接或經過一連串節點都可以。只有資料連線，永遠不會讓節點執行。
3. **`End` 結束整輪。** 從 `Dispatch` 分出去的分支以 `Return` 結束。
4. **名字就是參照。** 節點 `config` 裡的每一個 `ai_config`、`format_config`、變數與 modality 名字，都必須存在於對應的清單裡。拼錯會在執行時才失敗，不是載入時。
5. **連線裡的 pin 名字必須存在**於兩端的節點上，拼法完全一致。
6. **回頭的連線會重新執行它的目標** —— 「已走過」的集合會被清掉，迴圈就是這樣運作的。確定有東西能結束這個迴圈。
7. **節點與連線的 `id` 必須唯一。** 圖本身的身分是它的 `name`，也是它的檔名。

---

## 一張完整的最小圖

接收使用者的訊息，送給一個模型，回傳回覆。

複製它、改一個地方，它就能跑：**`aiConfigs[0].model` 必須是你的 server 真的有的模型。** 下面的名字只是預留位置。一張圖指定了沒有設定的模型，載入時沒問題，要到節點執行時才失敗，這樣才發現會讓人很困惑。

也因為這樣，CAGE 不會替你裝任何範例圖 —— 入門用的圖會指定一個你可能沒有的模型，而壞掉的範例比沒有範例更糟。這一張就是範例。

它同時也是測試：這張圖是照這一頁寫出來的，不是在編輯器裡畫的。0.2.0 時，下面這一段直接從這一頁讀出來，用 `PUT /api/logic-graph` 送到 server 並執行：它回答了，一個 `done`，沒有錯誤。這是證明這一頁完整的最短方法。

```json
{
  "name": "Minimal",
  "projectId": "", "owner": "",
  "ragEmbeddingConfig": "", "memoryAiConfig": "",
  "version": 1, "updatedAt": 0,
  "groups": [], "modalityConfigs": [], "formatConfigs": [], "variableConfigs": [],
  "aiConfigs": [
    { "name": "main", "model": "Qwen3-Coder-Next", "isRemote": false,
      "ctxSize": 0, "nGpuLayers": -1, "autoFit": true,
      "temperature": 0.7, "topK": 40, "topP": 0.9 }
  ],
  "nodes": [
    { "id": "aaaaaaaa-0000-0000-0000-000000000001",
      "type": "Start", "title": "Start", "category": "start",
      "position": { "x": 0, "y": 0 },
      "inputs": [],
      "outputs": [
        { "name": "Exec",   "type": "exec",   "direction": "output" },
        { "name": "PROMPT", "type": "string", "direction": "output" },
        { "name": "ASSET",  "type": "asset",  "direction": "output" }
      ],
      "config": { "start_name": "Default" }, "singleton": true },

    { "id": "aaaaaaaa-0000-0000-0000-000000000002",
      "type": "SendToAi", "title": "Answer", "category": "ai",
      "position": { "x": 300, "y": 0 },
      "inputs": [
        { "name": "Exec",  "type": "exec",   "direction": "input" },
        { "name": "Asset", "type": "asset",  "direction": "input" },
        { "name": "Task",  "type": "string", "direction": "input" }
      ],
      "outputs": [
        { "name": "Exec",  "type": "exec",   "direction": "output" },
        { "name": "ALL",   "type": "string", "direction": "output" },
        { "name": "Asset", "type": "asset",  "direction": "output" }
      ],
      "config": {
        "ai_config": "main",
        "prompt_template": "{{Task}}",
        "tools_enabled": true, "allowed_tools": "*", "max_tool_iters": 0,
        "rag_mode": "inherit", "memory_context": true
      } },

    { "id": "aaaaaaaa-0000-0000-0000-000000000003",
      "type": "End", "title": "End", "category": "end",
      "position": { "x": 600, "y": 0 },
      "inputs": [
        { "name": "Exec",   "type": "exec",   "direction": "input" },
        { "name": "Result", "type": "string", "direction": "input" }
      ],
      "outputs": [],
      "config": { "result_keys": [] }, "singleton": true }
  ],
  "connections": [
    { "id": "c1", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000001", "fromPinId": "Exec",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000002", "toPinId": "Exec" },
    { "id": "c2", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000001", "fromPinId": "PROMPT",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000002", "toPinId": "Task" },
    { "id": "c3", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000002", "fromPinId": "Exec",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000003", "toPinId": "Exec" },
    { "id": "c4", "fromNodeId": "aaaaaaaa-0000-0000-0000-000000000002", "fromPinId": "ALL",
                  "toNodeId":   "aaaaaaaa-0000-0000-0000-000000000003", "toPinId": "Result" }
  ]
}
```

注意它的形狀：`Exec` 把控制權從 Start 傳到 SendToAi 再傳到 End，`PROMPT` 和 `ALL` 則在旁邊帶著資料。兩者都需要 —— 有控制沒資料，prompt 是空的；有資料沒控制，永遠不會執行。

---

## 檢查你的成果

上面大部分的規則讀檔案就能檢查，而以下這些錯誤，否則會表現成一張載入正常、然後默默什麼都不做的圖：

- **存在一個命名為 `Default` 的 `Start`。**
- **每一條連線的節點和 pin 都存在** —— `fromNodeId`／`toNodeId` 指的是檔案裡的節點，`fromPinId`／`toPinId` 指的是那個節點的某個 pin（用 `name` 或 `id`）。編輯時留下來、指向已經不存在的節點或 pin 的連線，執行時不會有任何訊息：值就是永遠不會送到。
- **每一個 `ai_config`、`splitter_ai_config` 和 `format_config` 都指向**存在於 `aiConfigs`（或 `modalityConfigs`）與 `formatConfigs` 的項目。
- **除了 `Start` 以外的每個節點，都有一條從 `exec` pin 進來的連線。** 沒有的話它永遠不會執行。

有一類默默失敗的錯誤能通過上面每一項檢查，因為它在結構上是有效的：一個存在、只是從來沒接上的 pin。`Input` 沒有接任何連線的 `CheckFormat` 會驗證空字串，每次都失敗；沒有任何東西產生值的 `{{placeholder}}` 會展開成空的。從外面看起來是什麼樣子，見[完整範例](example-graph.zh-TW.md#三個不明顯的設定)。

---

[← Logic Editor](logic-editor.zh-TW.md) · [節點類型](nodes.zh-TW.md) · [完整範例](example-graph.zh-TW.md) · [AI Configs](ai-config.zh-TW.md) · [Client 指南](README.zh-TW.md)
