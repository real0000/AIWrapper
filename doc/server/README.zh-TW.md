[English](README.md) · **繁體中文**

# Server 指南

server 這一端是三個程序，不是一個。弄清楚誰負責什麼，之後可以省掉很多困惑 —— 尤其是「改了模型清單，要等某個東西重新啟動才生效」這一點。

安裝另外寫在[安裝 server](../server-install.zh-TW.md)。

---

## 三個部分

```
[browser] ──HTTP──> cage-launcher --control          one per deployment
                      │  accounts · web UI · the list of machines
                      │
                      └──HTTP /node/*──> cage-launcher --agent      one per machine
                                           │  supervises the server on this box
                                           │  edits this box's config.xml
                                           │  downloads models to this box's disks
                                           │
                                           └──spawns──> cage-server
                                                          the actual inference
```

在容器裡跑？**[Docker](docker.zh-TW.md)** 用一個映像檔跑全部三個，模型、資料庫和設定都是主機上的資料夾。安裝頁面有[兩種方式的比較](../server-install.zh-TW.md#選哪一種)。

| 程序 | 執行檔 | 每個…一個 | 工作 |
|---|---|---|---|
| [節點代理](agent/README.zh-TW.md) | `cage-launcher --agent` | 機器 | 啟動、停止、重新啟動本機的 server；編輯它的設定；下載模型 |
| [推論伺服器](server/README.zh-TW.md) | `cage-server` | 機器 | 執行模型、執行邏輯圖、服務 client |
| [控制台](control/README.zh-TW.md) | `cage-launcher --control` | 部署 | 網頁介面、帳號，以及它管理的機器清單 |

server **不是**獨立的服務。它是由節點代理啟動的，所以停掉 server 時，節點代理還在跑，也能再把它帶起來。

控制台用一般的 HTTP 跟節點代理溝通，所以不必跟任何一個節點代理在同一台機器上。單機安裝就是三個都在同一台，節點代理位在 `127.0.0.1`。

---

## 該看哪裡

### [節點代理 →](agent/README.zh-TW.md)

常駐在每台機器上的管理程式。

| 頁面 | 內容 |
|---|---|
| [概覽](agent/README.zh-TW.md) | 它管理什麼、自動啟動、重新啟動才生效、為什麼改設定不會即時生效 |
| [模型與下載](agent/models.zh-TW.md) | 新增模型、從 Hugging Face 下載、分散到多顆硬碟、config.xml 怎麼被編輯 |
| [節點 API](agent/api.zh-TW.md) | `/node/*` 端點，以及保護它們的 token |

### [推論伺服器 →](server/README.zh-TW.md)

真正載入模型、回應 client 的程序。

| 頁面 | 內容 |
|---|---|
| [概覽](server/README.zh-TW.md) | 連接埠、啟動順序、工作目錄、log |
| [Safetensors 模型](server/safetensors.zh-TW.md) | 執行 Hugging Face 的權重：不用轉檔，以及為什麼每一種量化都能選 |
| [模型](server/models.zh-TW.md) | 模型資料夾、量化版本的探索、視覺模型、授權資訊 |
| [後端](server/backends.zh-TW.md) | 兩種後端、RAM／VRAM 預算、驅逐，以及什麼情況會迫使模型重新載入 |
| [後端包](server/backend-packs.zh-TW.md) | **另外下載的 GPU 套件** —— 怎麼選、安裝、驗證、同時跑好幾個 |
| [Modality](server/modalities.zh-TW.md) | 圖片、語音、音訊、音樂、動作和 3D 模型，都在進程內執行 |
| [檢索](server/rag.zh-TW.md) | 切塊、embedding、向量儲存 |
| [API](server/api.zh-TW.md) | HTTP 端點與 WebSocket 訊息 |

### [控制台 →](control/README.zh-TW.md)

網頁介面，也是唯一知道不只一台機器的部分。

| 頁面 | 內容 |
|---|---|
| [概覽](control/README.zh-TW.md) | 網頁介面、它能管理什麼、它需要什麼 |
| [帳號](control/accounts.zh-TW.md) | 管理員帳號、使用者帳號、token、初始帳號 |
| [多個節點](control/nodes.zh-TW.md) | 加入機器、token、哪些共用、哪些不共用 |

---

## 每個人都會踩到的那一件事

**編輯模型清單不會影響正在執行的 server。** 節點代理寫的是 `config.xml`；server 仍然用它啟動時讀到的內容在跑。模型清單會把每個項目標成 `live`（已載入）或 `pendingRestart`（在檔案裡，不在 server 裡）。從網頁介面重新啟動 server，才會套用。

這是刻意的：重新啟動一個程序，比試圖就地修改一組已經載入的模型更可預期。

---

專有軟體 —— Copyright (c) 2026 real0000. All Rights Reserved. 見 [LICENSE](../../LICENSE)。
