[English](extension-install.md) · **繁體中文**

# 安裝 VSCode Extension

安裝 CAGE client，並把它連上 server。

套件：[`dist/cage-0.2.0.vsix`](../dist/)

---

## 1. 需求

| | 需要 |
|---|---|
| VSCode | 1.85 或更新 |
| Server | 一個連得到的 CAGE Server，見 [server-install.zh-TW.md](server-install.zh-TW.md) |

extension 裡沒有模型，也沒有推論邏輯；所有東西都在 server 上執行。

## 2. 安裝

用命令列：

```bash
code --install-extension cage-0.2.0.vsix
```

或在 VSCode 裡：**Extensions** 檢視 → **⋯** 選單（面板右上角）→ **Install from VSIX…** → 選這個檔案。

確認：

```bash
$ code --list-extensions --show-versions
real0000.cage@0.2.0
```

升級的方式就是把新的 `.vsix` 裝在舊的上面。手動安裝（side-load）的 extension 不會自動更新，不管 Marketplace 上有沒有同一個版本。

## 3. 連上 server

打開 **Settings**（`Ctrl+,`）搜尋 `cage`，或直接編輯 `settings.json`：

```jsonc
{
  // 只填主機名稱，不要加 http:// 或 ws://。用哪種協定由
  // cage.server.tls 決定。
  "cage.server.host": "cage.example.lan",
  "cage.server.port": 15963,
  "cage.server.tls": false
}
```

| 設定 | 預設值 | 意思 |
|---|---|---|
| `cage.server.host` | `localhost` | server 的主機名稱，不加協定前綴 |
| `cage.server.port` | `15963` | server 的 `<port>` |
| `cage.server.tls` | `false` | 使用 `https://`／`wss://`。server 上要設定 `<tls_cert>`／`<tls_key>` |
| `cage.server.tlsRejectUnauthorized` | `true` | 驗證 server 的憑證 |
| `cage.server.apiKey` | 空白 | Bearer 權杖。建議用 **CAGE: Login**，不要手動填 |

## 4. 自簽憑證

如果 server 用的是自簽憑證（見 [server-install.zh-TW.md](server-install.zh-TW.md) §8），要告訴 client 接受它：

```jsonc
{
  "cage.server.tls": true,
  "cage.server.tlsRejectUnauthorized": false
}
```

連線仍然是加密的，但不再能防範中間人攻擊。只要會暴露到可信任網路以外，就用正式的憑證。

## 5. 登入

如果 server 有資料庫、也設定了帳號，從 Command Palette（`Ctrl+Shift+P`）執行 **CAGE: Login**，輸入在控制台網頁介面建立的帳號。session 權杖由 VSCode 保存，不必填 `cage.server.apiKey`。

如果 server 沒有資料庫，`config.xml` 裡也沒有設定 `<api_key>`，它會接受所有請求、不做驗證，這一步可以跳過 —— 但其他連得到它的人也一樣，見[不用資料庫執行](server-install.zh-TW.md#7-不用資料庫執行)。有設定 `<api_key>` 的話，改把那個金鑰填進 `cage.server.apiKey`。

## 6. 第一次使用

點活動列上的 **CAGE** 圖示，打開 Chat panel。

**CAGE 沒有附任何邏輯圖。** 送出第一則訊息之前，先在 Logic Editor 裡建一張（或匯入一張），再到 chat panel 的 Graph 選單選它。沒有選圖就送出的訊息，會得到一個錯誤。[完整範例](client/example-graph.zh-TW.md)是一張完整的圖，附帶說明。

Command Palette 裡的指令：

| 指令 | 用途 |
|---|---|
| `CAGE: Open Chat` | Chat panel |
| `CAGE: New Session` | 開始一段新的對話 |
| `CAGE: Open Logic Editor` | 用來編輯驅動 agent 的邏輯圖的視覺化編輯器 |
| `CAGE: Rebuild Index` | 丟掉這個專案的檢索索引，每個檔案重新 embed |
| `CAGE: Tools` | 工具表：內建的、你自己的、MCP 程式、group |
| `CAGE: Open Logic Debug` | 檢視一次邏輯圖的執行過程 |
| `CAGE: Login` / `Logout` | 帳號登入狀態 |

模型發出的工具呼叫（讀寫檔案、套用 patch、執行終端機指令）都在你的編輯器裡執行，執行前會先徵求核准。核准的行為可以設定：

| 設定 | 預設值 |
|---|---|
| `cage.toolApproval.mode` | `ask` |
| `cage.toolApproval.perTool` | `run_terminal`、`run_code`、`build_project`、`run_tests` → `ask`。`write_file` 和 `apply_patch` 不在這裡：它們碰到的每個檔案都會個別核准 |
| `cage.fileAccess.scope` / `.outside` | `project` / `ask`：檔案工具只在工作區裡動作（加上 `cage.fileAccess.allowedPaths`），要碰其他地方時每次都會先問。見[檔案核准](client/file-approval.zh-TW.md#專案以外的檔案) |

## 7. 疑難排解

| 症狀 | 原因 |
|---|---|
| Connection refused | server 沒有在跑，或 `cage.server.port` 跟 `config.xml` 裡的 `<port>` 不一致 |
| 開了 TLS 之後連線一連上就斷 | server 沒有設定 `<tls_cert>`／`<tls_key>`，或憑證是自簽的、而 `tlsRejectUnauthorized` 還是 `true` |
| `401`／登入被拒 | server 和控制台指向不同的資料庫，所以 server 看不到這個帳號 |
| 模型清單是空的 | server 的 `config.xml` 裡 `<models>` 是空的，或每個 `<path>` 都掃描失敗；看 server 的 log |

## 8. 移除

```bash
code --uninstall-extension real0000.cage
```

---

下一步：**[Client 指南](client/README.zh-TW.md)**，每個面板與設定，以及邏輯圖的詳細說明。

回到 [server-install.zh-TW.md](server-install.zh-TW.md) · [文件索引](README.zh-TW.md)
