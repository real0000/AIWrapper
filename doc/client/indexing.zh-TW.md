[English](indexing.md) · **繁體中文**

# 專案索引

client 會讓 server 一直知道你的工作區裡有什麼。[RAG](rag.zh-TW.md) 就是從這份索引檢索，模型也是靠它，才能推論沒有給它看過的檔案。

它自己會跑，不用啟動什麼 —— 但值得知道有什麼東西、在什麼時候離開你的機器。

---

## 送出了什麼

一份清單，不是你的原始碼：每個檔案的路徑、它是檔案還是目錄、大小、修改時間，以及從副檔名猜出來的語言。另外還有偵測到的建置系統，以及能辨認出專案的關鍵檔案 —— `CMakeLists.txt`、`*.uproject`、`ProjectSettings/` 等等。

檔案的**內容**只有在有東西要它時才會送出：server 拉一個檔案去做 embedding 以供檢索，或某個工具呼叫要讀它。

## 什麼時候跑

| 觸發 | 效果 |
|---|---|
| extension 啟動 | 註冊監看程式 |
| 建立、刪除或重新命名檔案 | 標記為有變動 |
| 存檔 | 等過了 debounce 時間後，標記為有變動 |
| 你送出一則訊息 | 執行開始之前，先送出還沒同步的變動 |

你打字的時候什麼都不送。索引在每次往來的開頭同步，所以模型看到的是專案在那一刻的樣子。

第一次同步會送出整份索引。之後只送有變動的部分 —— 除非變動檔案的比例超過 `cage.index.deltaFullThreshold`（40%），那時直接送整份索引，比描述差異還省。切換分支通常會超過。

## 設定

| 設定 | 預設值 | 意思 |
|---|---|---|
| `cage.index.enabled` | `true` | 完全關掉索引 |
| `cage.index.excludePatterns` | `**/node_modules/**`、`**/.git/**`、`**/build/**`、`**/dist/**` | 永遠不走訪的 glob |
| `cage.index.debounceMs` | 2000 | 存檔之後要安靜多久 |
| `cage.index.deltaFullThreshold` | 0.4 | 變動比例超過多少就送整份索引 |

**CAGE: Rebuild Index** 會讓 server 丟掉這個專案的索引，包括它存下來的那一份，再把每個檔案重新做一次 embedding —— 檢索結果看起來過時，或換了 embedding 模型之後，就試這個。一般的同步會略過修改時間沒變的檔案。

## 讓它保持有用

排除清單是主要的槓桿。產生出來的輸出、vendored 的相依套件和大型二進位資源，只會讓索引變大、不會讓它更有用，在 [RAG](rag.zh-TW.md) 底下還會主動擠掉真正相關的結果。把它們加進 `excludePatterns`，通常是改善檢索品質最有效的一個改動。

---

[← RAG](rag.zh-TW.md) · [設定](settings.zh-TW.md) · [Client 指南](README.zh-TW.md)
