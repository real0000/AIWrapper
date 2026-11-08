[English](README.md) · **繁體中文**

# 推論伺服器

`cage-server` 是實際做事的程序：載入模型、執行邏輯圖、從專案索引檢索、把工具呼叫派給連線中的編輯器，再把回答串流回去。

它由[節點代理](../agent/README.zh-TW.md)啟動，不是獨立執行的服務。

---

## 內容

| 頁面 | 涵蓋 |
|---|---|
| [模型](models.zh-TW.md) | 模型資料夾、怎麼找出量化版本、視覺模型、授權資訊 |
| [後端](backends.zh-TW.md) | 兩種後端、RAM／VRAM 預算、驅逐，以及什麼情況會迫使模型重新載入 |
| [後端包](backend-packs.zh-TW.md) | **另外下載的 GPU 套件** —— 怎麼選、安裝、驗證、同時跑好幾個 |
| [Safetensors 模型](safetensors.zh-TW.md) | 執行 Hugging Face 的權重：不用轉檔，以及為什麼每一種量化都能選 |
| [Modality](modalities.zh-TW.md) | 圖片、語音、音訊、音樂、動作和 3D 生成，都在進程內執行 |
| [檢索](rag.zh-TW.md) | 切塊、embedding、向量儲存 |
| [API](api.zh-TW.md) | HTTP 端點與 WebSocket 訊息 |

## 執行它

一般是由節點代理啟動。要直接執行它 —— 診斷啟動問題時很有用，因為輸出會直接出現在你的終端機：

```bash
cd /opt/cage && ./bin/cage-server
```

它從工作目錄讀取 `config.xml`。要指向別的地方，用環境變數：

```bash
CONFIG_FILE=/opt/cage/config.xml ./bin/cage-server
```

沒有其他命令列參數 —— 所有東西都在設定檔裡。

## 啟動

log 會依序告訴你它做了哪些決定：

```
Config loaded from: /opt/cage/config.xml
Hardware topology [nvidia]: GPU0=…, GPU1=…; 1 nvlink link(s); RAM … GiB
CAGE Server starting on port 15963 (threads: …)
TLS disabled — traffic (including bearer tokens) is plaintext. …
[CageBackendLib] loaded /opt/cage/bin/libcage-backend-cuda-sm89_sm90.so: backend=cuda, …
[LlamaApi] selected /opt/cage/bin/libcage-backend-cuda-sm89_sm90.so (backend=cuda, drives 2/2 devices, …)
Model registered: my-coder (backend=llama, format=gguf, quants=3, …)
MySQL pool: 127.0.0.1:3306/cage (pool=4)
[auth] auth ENABLED (users=…, masterKey=no)
[BackendBudget] RAM cap=… MB, VRAM cap=… MB, eviction=lru
LlamaWorkerPool ready (lazy)
RAG VectorStore persist dir: data/vectors
Listening on port 15963
```

每次都值得看的幾行：

- **Hardware topology** —— 它看得到的 GPU，以及哪幾對之間有 NVLink。自動擺放就是依據這個決定的。
- **[LlamaApi] selected** —— 哪一個[後端包](backend-packs.zh-TW.md)驅動哪些卡。這裡出現 `No backend library found`，表示任何本機模型都跑不了。
- **Model registered** —— 每個模型一行，附上找到的量化版本。資料夾不存在、或裡面沒有 server 認得的權重的模型，會以 `Model skipped` 加上原因記在 log 裡，也不會出現在模型清單上。
- **auth** —— `dev-open` 表示沒有驗證：任何連得到那個連接埠的人，每個請求都以管理員身分處理。見[帳號](../control/accounts.zh-TW.md)。
- **Waiting for the database** —— 設定裡有 `<mysql>` 區塊，但那個資料庫還沒有回應。它回應之前什麼都不會服務；要不用資料庫執行，就拿掉那個區塊。
- **ready (lazy)** —— 啟動時不載入任何模型。第一個指定某個模型的請求才會載入它。

## 工作目錄

有幾條路徑是相對於程序的工作目錄，而不是設定檔：

| 路徑 | 放什麼 |
|---|---|
| `data/logic_graphs/` | 存下來的邏輯圖，每張圖一個 JSON |
| `data/vectors/` | 每個專案的向量索引 |

這就是 `<working_dir>` 重要的原因：讓節點代理指向建置目錄，server 就會在那裡建立一個全新、空的 `data/`，看起來就像弄丟了所有的圖。

## 連接埠

| 連接埠 | 在哪裡設定 | 用途 |
|---|---|---|
| 15963 | `<port>` | client：HTTP API 和 WebSocket，同一個連接埠 |
| 15972 | `<node><agent_port>` | 節點代理的 API —— 另一個程序 |

## 執行緒

啟動那一行的執行緒數量來自機器的核心數。它決定的是 IO 執行緒池的大小，不是推論；每個模型的推論執行緒數，在各個 AI config 裡設定。

---

[← Server 指南](../README.zh-TW.md)
