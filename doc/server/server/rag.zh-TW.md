[English](rag.md) · **繁體中文**

# 檢索

RAG 在 server 這一邊的部分：從 client 推送檔案清單，到圖節點的 prompt 前面出現相關的程式碼塊，中間發生了什麼。

使用者會碰到的那一半，寫在 [client 指南](../../client/rag.zh-TW.md)。

---

## 整條鏈

```
client pushes a file listing (paths, sizes, mtimes — not contents)
        ↓
server decides what changed and pulls those files back over the connection
        ↓
ChunkPipeline splits them            tree-sitter, with a line-window fallback
        ↓
EmbedderPool embeds each chunk       the graph's embedding config
        ↓
VectorStore                          hnswlib index, one per project, on disk
        ↓
a Send To AI node queries top-k and prepends the results to its prompt
```

這裡沒有任何東西是在 `config.xml` 裡設定的。檢索是在圖裡指定一個 embedding config 才打開的，所以同一個 server 上的專案，可以有些圖檢索、有些不檢索。

## 切塊

檔案用 tree-sitter 文法、沿著頂層節點切開：相鄰的頂層內容 —— 定義、`#include` 行、註解、設定 —— 會收集成一塊，最多 4000 位元組，而且一塊絕不會在某個節點的中間結束。一個函式或類別會完整地進來，小檔案就是一塊。

常見的語言都附了文法。沒有文法的語言的檔案，或是單一節點大到放不進一塊的，會退回成互相重疊的行視窗。某個語言的檢索效果看起來比其他語言差的時候，值得記得這個退路 —— 那多半是用視窗切的，而不是用語法解析的。

`.cage/` 永遠不會被索引。那裡放著專案的記憶 —— 規則、檔案歷史、session 紀錄 —— 一個步驟讀其中哪些，由記憶 AI 決定，而不是看它跟要求有多相似。

## Embedding

embedding 模型以一個專用、長期存在的 context 執行，跟產生文字的模型分開：embedding 模型很小，一再載入、卸載的代價，比一直留著還高。

向量都經過正規化，所以相似度就是單純的內積。比 context 還長的文字，會在句子邊界切成放得下的幾段，每一段各自做 embedding，再依 token 數加權平均 —— 所以整段文字都在向量裡，而不是只有開頭。

**建索引和查詢刻意用同一個 config。** 向量只有在同一個 embedding 空間裡才有意義；設定只有一個、而不是兩個，正是為了讓兩邊不可能漂開。

## 向量儲存

每個專案一個 hnswlib 索引，存在 `data/vectors/` 底下，啟動時延遲載入。

更新一個檔案時，會移除它的舊程式碼塊 —— 先標記為刪除，之後再壓縮 —— 並插入新的，所以重新索引不會累積改過的程式碼的過時副本。

因為存在磁碟上，重新打開一個專案不必重新做 embedding。例外是用舊版切塊程式切出來的索引：它會記錄是哪一版切的，在它的專案第一次被打開時整份重建 —— 否則沒有改過的檔案會一直留著舊的切塊。編輯器裡的 **CAGE: Rebuild Index** 會應要求對一個專案做同樣的事：刪掉它存下來的索引，把每個檔案重新做一次 embedding。刪掉 `data/vectors/`，就是一次對所有專案這樣做。

## 實際離開 client 的是什麼

這是私有部署的產品，值得說精確：

- client 送出的是**一份清單** —— 路徑、大小、修改時間、偵測到的語言，以及建置系統。
- server 只有對需要做 embedding 的檔案，才會**拉取檔案內容**。
- 工具呼叫會在需要時讀取內容。

所以索引是一張地圖，內容只在檢索或工具需要時才會經過網路。

## 檢索什麼都沒回傳時

大致依可能性排列：

1. **圖上沒有 embedding config。** 指定一個之前，檢索都是關閉的。
2. **embedding 模型沒辦法提供 embedding。** 這個池需要一個後端能以 embedding 模式執行的模型；第一次嘗試時 log 就會說明。
3. **還沒有任何東西被索引。** 第一次同步發生在送出訊息時，不是打開工作區時。
4. **相關的東西全被排除了。** 檢查 client 的排除清單。

---

[← 推論伺服器](README.zh-TW.md) · [Client 端的 RAG](../../client/rag.zh-TW.md) · [Server 指南](../README.zh-TW.md)
