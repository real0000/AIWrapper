[English](rag.md) · **繁體中文**

# RAG

檢索把專案裡跟問題有關的部分交給模型，不必把整個 repository 貼進 prompt。

整條鏈是這樣：client 為你的工作區建索引並推給 server；server 把檔案切成塊、做 embedding、存下向量；每個 [Send To AI](nodes.zh-TW.md#send-to-ai) 節點都可以查出最相近的幾塊，放在它的 prompt 前面。

**查詢用的是 chat 訊息，不是節點的 prompt。** 所以一張圖裡的每個節點，不管位在多下游，檢索時比對的都是同一段文字 —— 使用者要求的那件事。決定哪些節點該檢索時，這一點很重要：見[什麼時候該關掉](#什麼時候該關掉)。

---

## 怎麼開啟

只有一個設定，在 Logic Editor 側欄 **Memory** 區塊的 **Embedding Model**：

| 欄位 | 意思 |
|---|---|
| Embedding Model | 用來做 embedding 的 [AI Config](ai-config.zh-TW.md) —— 哪一個都可以 |

留空的話，整張圖都不檢索。設了之後，每個 Send To AI 節點預設都會檢索。

**建索引和查詢刻意用同一個 config。** 向量只有在同一個 embedding 空間裡才能比較，混用模型會默默回傳一堆不相干的東西。所以設定只有一個，不是兩個。

至少有一個 config 之前，這個區塊會顯示 *"Create an AI Config to enable RAG."*。節點只保留前 N 份檔案歷史時，也是用這個 config 來排序 —— 見[專案記憶](memory.zh-TW.md)。

## 個別節點的設定

每個 Send To AI 節點都有一個 **RAG** 設定：

| 值 | 效果 |
|---|---|
| Inherit | 用整張圖的 embedding config。預設值 |
| Off | 這個節點不檢索 |
| Custom | 改用另一個 config，在 **RAG Embedding** 裡指定 |

對只會徒增雜訊的節點就關掉 —— 例如重新排版一個回答的節點，或摘要 prompt 裡已經有的文字的節點。每一次執行，檢索都要花一次 embedding 呼叫和一些 prompt 空間。

## 什麼時候該關掉

需要在不是自己寫的程式碼裡找方向的節點，檢索會有幫助 —— 決定要改什麼的 planner、尋找既有慣例的 coder。

工作是**評判**的節點，檢索反而有害：讀一份報告或一個回答，然後給出判決的那種。原因有兩個，而且會互相加乘：

1. 查詢用的是 chat 訊息，所以拿回來的是長得像原本要求的程式碼 —— 不是正在被評判的東西。對評判者來說，這頂多是雜訊。
2. 檢索到的區塊是*節錄*，依相似度挑出來、在切塊邊界被切斷。被要求找缺陷的模型，會在切口找到缺陷。

第二點不是假設。一個 filter 節點 —— 沒有工具，整個輸入就是 verifier 的一份紀錄 —— 在開著檢索時連續四輪回傳「fail」，錯誤像是 `packer.cpp:248-341: missing code after line 341`。那些行數範圍，正好就是切塊邊界。程式從頭到尾都能編譯、執行也正確，哪裡都沒有報錯；迴圈就是結束不了。

現在注入的區塊會說明它的內容是節錄，這種情況因此少了一些。但規則不變：**負責評分、分類或做決定的節點，把 RAG 設成 Off。**[完整範例](example-graph.zh-TW.md#3-filter-的-rag_mode-off--檢索會污染判斷)在同一張圖裡把兩種設定並排列出來。

---

## 索引哪些東西

client 走過整個工作區，把檔案清單送給 server；server 再去拉它需要的內容。

| 設定 | 預設值 | 效果 |
|---|---|---|
| `cage.index.enabled` | on | 要不要建索引 |
| `cage.index.excludePatterns` | `node_modules`、`.git`、`build`、`dist` | 永遠不索引的 glob |
| `cage.index.debounceMs` | 2000 | 編輯之後要安靜多久才重新索引 |

第一次同步會全部送出；之後只送有變動的，除非一次變動太多，那時直接重建整份索引反而比較省。見[專案索引](indexing.zh-TW.md)。

切塊會看語法：用 tree-sitter 文法把相鄰的頂層內容收集成最多 4000 位元組的塊，絕不在一個定義的中間切開，所以一個函式會保持完整，小檔案就是一塊。沒有文法的語言，以及太大的定義，會退回成互相重疊的行視窗。

`.cage/` —— 專案的記憶與 session 紀錄 —— 永遠不會被索引；一個步驟讀其中哪些，由記憶 AI 決定。見[專案記憶](memory.zh-TW.md)。

向量依專案存在 server 上，重新啟動也還在，所以重新打開一個專案不必重新做 embedding。

## 實用提醒

- **本機 embedding 需要一個 embedding 後端載得起來的模型。** 如果檢索默默地什麼都沒回傳，查一下 server 的 log —— 通常是 embedding config 指向了一個後端沒辦法當 embedder 用的模型。
- **排除產生出來的目錄。** 建置輸出和 vendored 的相依套件會擠掉真正相關的結果，還要花 embedding 的時間。
- **查詢用的是 chat 訊息**，圖裡每個節點都是同一段。迴圈深處的節點，檢索時比對的不是它當下正在做的事。

---

[← Logic Editor](logic-editor.zh-TW.md) · [專案索引](indexing.zh-TW.md) · [完整範例](example-graph.zh-TW.md) · [Client 指南](README.zh-TW.md)
