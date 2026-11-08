[English](api.md) · **繁體中文**

# 節點 API

節點代理對外提供的 HTTP 介面。預定的呼叫者只有控制台，但它是一般的 HTTP API —— 拿來寫部署腳本很方便，而在把連接埠開放出去之前，也值得先弄懂它。

基底 URL：`http://<bind>:<agent_port>` —— 預設是 `127.0.0.1:15972`。

---

## 驗證

每一條 `/node/*` 路由都需要設定在 `<node_token>` 的 Bearer：

```bash
curl -H "Authorization: Bearer $NODE_TOKEN" http://127.0.0.1:15972/node/status
```

`/health` 不需要。

`<node_token>` 是空的，就完全不檢查。節點代理綁在 `127.0.0.1`、只從同一台機器連線時，這沒問題。在任何別台機器連得到的位址上就不行：這些端點能啟動、停止程序，還能改寫設定。

## 狀態

| 方法 | 路徑 | 用途 |
|---|---|---|
| `GET` | `/health` | 是否還活著。不需要驗證 |
| `GET` | `/node/status` | 儀表板上顯示的所有東西 |

`/node/status` 把節點代理對子程序的了解 —— 狀態、pid、已執行時間 —— 跟它向本機 server 查詢 `/health`、`/api/hardware` 和 `/api/models` 得到的結果合在一起。所以它同時回報「程序在跑」和「載入了這些模型、用了這麼多 VRAM」。

server 停了的話，程序相關的欄位照樣回傳，即時的欄位則不會出現。這個區別正是重點：它告訴你 server 是當掉了，還是根本沒啟動過。

## 控制 server

| 方法 | 路徑 | 用途 |
|---|---|---|
| `POST` | `/node/server/start` | 啟動 server |
| `POST` | `/node/server/stop` | 送 SIGTERM，不結束的話再送 SIGKILL |
| `POST` | `/node/server/restart` | 先停再啟動 —— 套用設定修改的方式 |

## 模型

| 方法 | 路徑 | 用途 |
|---|---|---|
| `GET` | `/node/models` | 設定裡的模型清單，每一項標成 `live` 或 `pendingRestart` |
| `POST` | `/node/models/edit` | 新增或修改一個項目 |
| `POST` | `/node/models/remove` | 移除一個項目；加上 `deleteFiles` 會連模型的資料夾一起刪除 |
| `POST` | `/node/models/scan` | 檢查一個已經在磁碟上的資料夾：裡面有哪些模型、它們的授權，以及有沒有不該匯入的理由。只讀不寫 |
| `POST` | `/node/models/import` | 把掃描過的資料夾加進 `config.xml`。會重新掃描一次，而不是相信請求的內容 |
| `GET` | `/node/models/identify-sources` | 對沒有 `<source_repo>` 的項目，列出它們可能來自哪些 Hugging Face repo，附上依據。不寫入任何東西 |
| `POST` | `/node/models/source-repo` | 你確認之後，記錄一個項目的來源 repo |
| `POST` | `/node/models/projector-probe` | 在給定的 repo 裡，哪些有提供視覺 projector |
| `POST` | `/node/models/mmproj` | 為既有的項目下載 projector。回傳一個 job id，追蹤方式跟其他下載一樣 |

這些只編輯 `config.xml`。見[重新啟動才生效](README.zh-TW.md#重新啟動才生效)。

## 下載

| 方法 | 路徑 | 用途 |
|---|---|---|
| `GET` | `/node/dirs` | 下載資料夾，附剩餘空間和總空間 |
| `POST` | `/node/dirs/add` | 加入一個下載資料夾 |
| `POST` | `/node/dirs/remove` | 移除一個 |
| `POST` | `/node/hf/list` | 列出一個 Hugging Face repo 裡可以下載的群組 |
| `POST` | `/node/download` | 開始一個下載；回傳一個 job id |
| `GET` | `/node/download?id=` | 那個下載的進度 |
| `GET` | `/node/downloads` | 每一個下載 job |
| `POST` | `/node/download/pause` | 依 id 暫停一個 job |
| `POST` | `/node/download/resume` | 繼續它 |
| `POST` | `/node/download/cancel` | 取消它 |

下載是非同步的：開始一個，再去查詢它。大模型要多久就是多久，這段期間節點代理一直都能回應。

## 用腳本部署

只靠這組 API，不用網頁介面也能管理一台機器 —— 加一個模型、重新啟動、確認它起來了：

```bash
AUTH="Authorization: Bearer $NODE_TOKEN"
N=http://127.0.0.1:15972

curl -s -H "$AUTH" $N/node/dirs
curl -s -H "$AUTH" -X POST $N/node/download -d '{"repo":"Qwen/Qwen3-Coder-Next", ...}'
curl -s -H "$AUTH" "$N/node/download?id=<id>"      # 一直查到完成
curl -s -H "$AUTH" -X POST $N/node/server/restart
curl -s -H "$AUTH" $N/node/status
```

---

[← 節點代理](README.zh-TW.md) · [模型與下載](models.zh-TW.md) · [Server 指南](../README.zh-TW.md)
