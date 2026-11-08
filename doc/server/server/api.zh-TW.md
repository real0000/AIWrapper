[English](api.md) · **繁體中文**

# Server API

server 對 client 提供的介面。HTTP API 和 WebSocket 共用 `<port>`。

使用這個產品不需要懂這些 —— client 會替你處理。要寫腳本操作 server，或要弄清楚失敗發生在哪裡時，才用得到。

---

## 驗證

`/api/*` 需要 Bearer token；`/health` 不需要。

token 可以是透過[控制台](../control/accounts.zh-TW.md)發出的個人存取 token、登入後拿到的 session token，或 `config.xml` 裡固定的 `<api_key>`。

沒有資料庫（沒有 `<mysql>` 區塊）、也沒有 `<api_key>` 時，server 以開放模式執行，把所有請求都當成管理員 —— 也就是啟動時那則 `auth DISABLED (dev-open)` 警告。這時這裡的每一個端點，包括 WebSocket，都會回應任何連得到那個連接埠的人。這對單人試用是刻意的設計，不會改；見[不用資料庫執行](../../server-install.zh-TW.md#7-不用資料庫執行)。設定了資料庫、但連不到的話，server 會等它，而不是以開放模式執行。

**來自網頁的請求會被拒絕**，回傳 `403`，在查看 token 之前、也不讀取 body —— WebSocket 交握和 CORS preflight 也一樣，而且不會送出任何 CORS 標頭。這個 API 是給程式用的：CAGE 的 client、控制台、腳本。請求帶有 `Origin`，或帶有值不是 `none` 的 `Sec-Fetch-Site`（`none` 是在瀏覽器網址列直接輸入的位址），就算是網頁發出的。Node 內建的 `fetch` 和 `WebSocket`、curl，以及各個 client，兩者都不會送。不這樣做的話，你造訪的任何網頁，都能讓你的瀏覽器去呼叫只有你的網路連得到的 server —— 例如嘗試登入密碼，再把 token 讀回去。

主要的連接埠在 `<bind>` 上監聽（預設 `0.0.0.0`，所有網路介面）。如果前面在同一台機器上放了處理 TLS 的反向 proxy，就設 `<bind>127.0.0.1</bind>`，讓沒加密的連接埠從外面連不到。

請求的 body 要在 Bearer token 驗證通過之後才會讀取。沒有有效 token 的話，body 會被一小段一小段地讀掉丟棄 —— 絕不會整份放在記憶體裡 —— 然後回應 `401`。通過驗證的請求，body 沒有大小限制。

## HTTP

| 方法 | 路徑 | 用途 |
|---|---|---|
| `GET` | `/health` | 是否還活著。不需要驗證 |
| `POST` | `/api/auth/login` | 帳號密碼放在 `Authorization: Basic base64(username:password)` 標頭 → 換一個 session token。不讀 body：這是唯一在驗證之前處理的 POST |
| `POST` | `/api/auth/logout` | 撤銷出示的這個 token |
| `GET` | `/api/auth/me` | 這個 token 屬於誰 |
| `POST` | `/api/session` | 建立一個 session，回傳 `{session_id}` |
| `POST` | `/api/session/resume` | 重新接上一個 session。只有在 server 確定沒有這個 session 時才回 `404` |
| `GET` | `/api/session?id=` | 一個 session 的訊息（它的擁有者或管理員） |
| `GET` | `/api/sessions` | 你的 session；管理員拿到的是所有人的 |
| `GET` | `/api/session/interrupted?session_id=` | 那個 session 裡做到一半停下的執行（如果有的話）—— 也就是接續時會繼續的那一個 |
| `GET` | `/api/models` | 模型和 modality，附上量化版本和授權 |
| `GET` | `/api/hardware` | GPU、NVLink 拓樸、RAM —— GPU 選擇器畫的就是這些 |
| `GET` | `/api/modalities` | 已註冊的 modality alias |
| `POST` | `/api/generate` | 直接呼叫一個 modality。Logic Editor 的預覽用的就是它 |
| `GET` | `/api/delivery?session_id=&id=` | 下載圖為那個 session 產生的檔案（client 會把它存進專案）。限 session 的擁有者或管理員 |
| `POST` | `/api/delivery/result` | `{session_id, delivery_id, status}` —— `written`、`rejected` 或 `failed`。執行結束、每個檔案都處理完之後，server 會刪掉自己那一份 |
| `POST` | `/api/ai-config/test` | 驗證一個 AI config，然後實際載入並生成 |
| `POST` | `/api/ai-config/placement` | 一個 AI config 會被擺在哪裡，不實際載入 |
| `POST` | `/api/ai-config/budget` | 實際載入時會規劃的每張卡記憶體用量，不載入就量出來 |
| `POST` | `/api/modality-config/test` | modality config 的同一種測試 |
| `POST` | `/api/files/upload` | 上傳一個檔案 —— chat 的附件。回傳訊息要引用的 `file_id` |
| `GET` | `/api/logic-graphs` | 你看得到的圖 |
| `GET` | `/api/logic-graph?name=` | 取得一張圖 |
| `PUT` | `/api/logic-graph` | 儲存一張圖 |
| `DELETE` | `/api/logic-graph` | 刪除一張圖 |
| `POST` | `/api/logic-graph/rename` | `{from, to}`。圖的名字就是它的身分，所以改名是獨立的操作 |
| `GET` / `POST` / `DELETE` | `/api/logic-graph/share` | 列出、授予（`read` 或 `write`）和撤銷分享 —— 限擁有者或管理員 |
| `GET` | `/ws?session_id=` | 升級成 WebSocket |

有兩個值得特別一提：

**`/api/hardware`** 讓 GPU 選擇器能顯示真實的卡和真實的 NVLink 連線，而不是一個文字欄位。它也是確認 server 看到的 GPU 是不是你以為的那些最快的方法。

**`/api/ai-config/test`** 分兩個階段跑 —— 先驗證，再載入並生成。第二個階段才是有用的：它在真正的執行依賴這個答案之前，就回答「這種擺放放不放得進 VRAM」。

## WebSocket

一條連線承載一整次往來：prompt、串流輸出、雙向的工具呼叫、server 要的檔案，以及索引更新。

client 送給 server：

| 訊息 | 用途 |
|---|---|
| `message` | 一則使用者訊息。帶著 `logic_graph_name` 和 `start_name`，指定要執行的圖和入口，以及任何附件的 `file_id` |
| `tool_result` | server 要求的某個工具的結果：`content`、`is_error`，以及工具因為使用者或其設定拒絕而沒有執行時的 `denied: true` |
| `tool_stream_chunk` | 還在執行中的工具的輸出 |
| `cancel` | 中止這次執行 |
| `run.resume` / `run.discard` | 繼續被中斷的執行，或放棄它 |
| `project_index.full` / `.delta` | 同步索引 |
| `memory.sync` | 專案記憶的路由表和規則檔 |
| `logic_graph.update` | 儲存一張圖 |
| `logic.execute` | 明確地執行一張圖 |
| `mcp_tools_register` / `_update` | 宣告這個 client 執行的工具。提供給模型的就正好是這些；server 自己一個都沒有 |
| `file_response` | server 要的某個檔案 |
| `conn_step.sync` / `.update` | 連線狀態的記錄 |
| `file_transfer.init`、二進位 frame | 分段上傳。**不支援** —— 改用 `POST /api/files/upload` |

server 送給 client：

| 訊息 | 用途 |
|---|---|
| `chunk` | 串流輸出 |
| `reasoning` | 串流的思考過程，跟回答分開顯示 |
| `tool_call` | 執行這個工具 |
| `interim_commit` / `interim_text` | 中間步驟，在介面裡收合顯示 |
| `branch_begin` / `branch_end` | Dispatch 節點的一條平行分支開始與結束 |
| `logic_result` | End 節點的結果 |
| `logic_debug` | 每個節點的執行前／執行後／錯誤事件 |
| `file_request` | 把這個檔案送給我 |
| `project_index.request` / `.ack` | 要求專案索引，以及確認收到 |
| `rag_index.progress` | 專案的 embedding 做到哪裡了 |
| `memory.ack` | 路由表已收到 |
| `logic_graph.ack` / `.diverged` | 圖已儲存，或版本衝突 |
| `run_interrupted` / `run_resumed` / `run_discarded` | 做到一半停下的執行的狀態 |
| `cancelled` | 執行被停止了 |
| `done` / `error` | 這次往來結束 |

**工具清單完全由 client 宣告。** server 沒有固定的工具集 —— 它是透過 `mcp_tools_register` 得知這個 client 能做什麼，而提供給模型的就正好是那些。從來不註冊工具的 client，拿到的就是沒有工具的模型。

## 寫腳本時要注意的

- 先透過 HTTP 建立 session，再用它打開 WebSocket。
- client 需要時才連線，一次往來結束就斷線。沒有需要保持連線的長期 socket。
- 模型管理**不在**這裡 —— 那是[節點代理](../agent/api.zh-TW.md)的事。這個 server 沒有 `/admin` 路由。

---

[← 推論伺服器](README.zh-TW.md) · [Server 指南](../README.zh-TW.md)
