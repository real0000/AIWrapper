[English](mcp.md) · **繁體中文**

# MCP 程式

**MCP 程式**是你接上的一組現成工具。想讓模型擁有產品本身沒有附的能力 —— 網路搜尋、issue tracker、文件查詢、資料庫 —— 又不想改動產品，就接一支 MCP 程式。

它的工具會加進跟其他工具同一張表，設定方式也一樣。這一頁只講連線；接上之後每個工具能設定什麼，見 [Tools](tools.zh-TW.md)。

在 Tools 頁面（**CAGE: Tools**）按 **+ Tools from an MCP program** 接上一支，或在設定裡編輯 `cage.mcp.servers`。

> 頁面上不用「server」這個詞稱呼它們。那是 MCP 自己用來稱呼連線另一端的詞，聽起來像是你得自己架設、管理的東西。你接上的是一支程式；它的工具會出現在它的名字底下。

---

## 怎麼接上

| 欄位 | |
|---|---|
| **Name** | 它的工具用什麼前綴：`mcp__<name>__<tool>`。必須唯一，也不能是 `built-in` 或 `cage-server` —— 這兩個是永遠存在的兩個來源的名字 |
| **Enabled** | 停用的程式不會連線，它的工具也不會提供給模型 |
| **How to connect** | 透過 stdio 的子程序，或 Streamable HTTP |

子程序要填：**command**、**args**、**env**、**cwd**。
HTTP 要填：**URL** 和 **headers**。

**List its tools** 會真的啟動它並詢問。回來的工具會加進表裡、放在那個程式的標題底下，而且在 session 之間會一直列著 —— 所以你可以在下一次連線之前先把它們設定好。

## 在設定裡

```jsonc
"cage.mcp.servers": [
  {
    "name": "filesystem",
    "transport": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
  },
  {
    "name": "search",
    "transport": "stdio",
    "command": "/usr/local/bin/my-search-mcp",
    "env": { "API_KEY": "…" },
    "cwd": "/opt/search"
  },
  {
    "name": "docs",
    "transport": "http",
    "url": "https://example.internal/mcp",
    "headers": { "Authorization": "Bearer …" }
  }
]
```

`"disabled": true` 會保留這個項目，但不連線。

**兩種傳輸方式：`stdio` 和 `http`。** `http` 是 Streamable HTTP —— 每一則 JSON-RPC 訊息都以 POST 送到那個 URL。`sse` 會被回報為不支援，而不是默默忽略。

## 連線時會發生什麼

client 會連上每一支啟用的程式，向它要工具清單，再把合併後的清單 —— 內建的、你自己寫的，加上每支程式的 —— 宣告給 CAGE server。宣告之前，會先經過工具表的過濾：停用的工具不宣告，設了自訂說明的工具，以你的說明宣告。

MCP 連線會跨越好幾輪、重複使用。每次連線都會送出宣告，所以改了表之後，下一次往來就會生效。

**請求沒有逾時。** 一個請求在收到回覆、程式結束（stdio），或連線中斷（HTTP，由 TCP keepalive 察覺）時結束。要跑十分鐘的工具，就是要跑十分鐘。

## 核准

MCP 程式的工具跟其他工具走同樣的核准流程，也在同一張表裡設定 —— 見 [Tools](tools.zh-TW.md)。它們沒有預設的風險等級，所以照你的預設模式。不是你自己寫的程式，就是把它維持在 `ask` 的好理由。

你也可以給它**自訂行為**：保留模型看到的名字和參數，但改成執行你自己的指令列，而不是呼叫那支程式。

## 東西沒出現時

- **工具清單每次連線宣告一次。** 接上一支程式之後，要開始新的一次往來，模型才看得到它。
- **確認它是啟用的** —— 項目本身，以及表裡的那個工具。關掉的工具會出現在 *Not currently provided* 底下。
- **啟動失敗的程式**會回報在 extension 的 output channel 裡。**List its tools** 是查出原因最快的方法。
- **模型實際收到的清單**在 server 的 log 裡。

---

[← Tools](tools.zh-TW.md) · [設定](settings.zh-TW.md) · [Client 指南](README.zh-TW.md)
