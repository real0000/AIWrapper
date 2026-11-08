[English](format-config.md) · **繁體中文**

# Format Configs

format config 描述一個字串應該長成什麼形狀。它有兩個用途，最好分開來看：

- 用在 [Send To AI](nodes.zh-TW.md#send-to-ai) 節點上，它是**結構化輸出**：模型被限制只能以這個形狀回答。
- 用在 [Check Format](nodes.zh-TW.md#check-format) 節點上，它是**驗證**：拿一個字串跟這個形狀比對，圖依結果分支。

同一個 config 可以兩件事都做，這也是常見的用法：先要求一個形狀，再確認拿到的就是它。

---

## 類型

| 類型 | 什麼情況下通過 |
|---|---|
| `json` | 字串能解析成有效的 JSON |
| `json_keys` | 能解析成 JSON 物件，而且包含每一個必要的欄位 |
| `regex` | 符合這個 pattern |
| `non_empty` | 不是空白 |

## 欄位（`json_keys`）

`json_keys` 要列出這個物件應該有哪些欄位：

| 欄位屬性 | 用途 |
|---|---|
| Key | JSON 物件裡的屬性名稱 |
| Description | 這個 config 用在結構化輸出時，會告訴模型 |
| Required | 少了它時，[Check Format](nodes.zh-TW.md#check-format) 要不要判定失敗 |

Description 比看起來重要。在結構化輸出底下，它是模型對每個鍵代表什麼唯一能拿到的說明，所以「一句話總結改了什麼」跟「總結」產生出來的東西會很不一樣。

## 拆開的輸出

Send To AI 節點設定了 `json_keys` config 時，你可以加上以這些鍵命名的輸出 pin。回答進來時就已經拆好了 —— 每個鍵在自己的 pin 上 —— 而不是一整塊 JSON，還得在下游自己拆開。

沒有設定 Format 的 Send To AI 節點，對你加上的輸出 pin 也是這樣處理：每一個都變成模型必須填寫的必要鍵。

## 驗證並重試

標準的接法：

```
Send To AI ──► Check Format ──True──► 繼續往下
                    │
                    └──False──► 回到 Send To AI
```

`False` 分支再一次餵給呼叫模型的節點，所以格式錯誤的回答只會多花一次重試，而不會讓整輪中斷。預設的訊息不夠具體、不足以幫模型改正時，就給節點一個 **custom error message**。

留意重試的那條路：如果你要的是有上限的嘗試次數，而不是可能一直空轉的迴圈，就讓它經過一個 [Variable](variables.zh-TW.md) 計數器和一個 [If](nodes.zh-TW.md#if) 節點再接回去。

---

[← Logic Editor](logic-editor.zh-TW.md) · [節點](nodes.zh-TW.md) · [Client 指南](README.zh-TW.md)
