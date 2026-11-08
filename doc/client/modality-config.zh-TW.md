[English](modality-config.md) · **繁體中文**

# Modality Configs

modality config 指向一個產生檔案、而不是文字的東西：圖片、語音、音訊、音樂、動作或 3D 網格。語音辨識和語音活動偵測方向相反，是從錄音變成文字，設定方式也一樣。

**它跟其他所有 config 放在同一份 AI CONFIGS 清單裡。** 挑模型只要做一次決定，不是兩次 —— 清單只有一個區塊，生成式的項目會標上它的類型（`image`、`tts`…），Inspector 的屬性表會依 config 指定的模型種類切換。[Send To AI](nodes.zh-TW.md#send-to-ai) 節點也是在同一個 **AI Config** 下拉選單裡選它，跟選文字 config 一樣。

模型下拉選單兩種都列出來。在文字 config 裡選了生成式模型（或反過來），config 會就地轉換、名字不變，所以已經綁定它的每個節點都還是綁著它。

節點跑的是 modality config 時，呼叫模型就變成呼叫生成：沒有工具迴圈、沒有檢索、沒有結構化輸出。節點的 `ALL` pin 帶的是產生出來的檔案路徑，型別也會跟著 modality 改變，所以編輯器只讓你把它接到接受那種檔案的地方。`asr` 和 `vad` 的結果是文字，`ALL` 就是一般的文字 pin。

---

## 類型

| 類型 | 產生 |
|---|---|
| `image` | 圖片 |
| `tts` | 從文字產生的語音 |
| `audio` | 一般音訊 |
| `music` | 音樂 |
| `mesh` | 3D 網格 |
| `motion` | 動作片段 |
| `asr` | 從錄音辨識出來的文字 |
| `vad` | 錄音裡有人說話的片段，以 JSON 片段表示 |
| `separation` | 從錄音裡分離出來的各個音軌 |

本機的 config 從模型得到它的類型。server 啟動時會判斷每個模型是什麼，你在 config 裡選了模型，類型就設好了，沒有什麼需要手動對應的。

## 本機或遠端

本機的 modality 模型，跟其他所有模型一起記在 server 的 **VRAM 帳本**上。config 可以限制只用特定的 GPU，方式跟文字 config 一樣；留空的話，server 會挑一張有空間的卡。modality 模型永遠只放在一張卡上。

**本機**的 config 指定 server `config.xml` 裡的一個 alias。server 會在第一次用到時，在行程內、用跟語言模型同一個後端載入它。所有生成式類型都是這樣運作；沒有另外的服務，也沒有 Python。

| 欄位 | 意思 |
|---|---|
| Modality Alias | server 上的 `<model alias="…">` 項目 |

**遠端**的 config 直接呼叫代管的服務。遠端只能用 `image` 和 `tts`，因為只有這兩種有標準的端點。

| 欄位 | 意思 |
|---|---|
| Provider | 用哪一種 API 形狀與驗證標頭 |
| Remote URL | 端點的基底 URL |
| API Key | 服務的憑證 |
| Model | 意思依服務而定，見下表 |

| Provider | 驗證 | Model 欄位的意思 |
|---|---|---|
| OpenAI | Bearer | 模型名稱，例如 `dall-e-3`、`tts-1` |
| Stability | Bearer | 端點變體：`core`、`sd3`、`ultra` |
| ElevenLabs | `xi-api-key` | Voice ID |
| Replicate | Token | `owner/name[:version]` |
| fal | Key | 模型路徑，例如 `fal-ai/fast-sdxl` |

## 生成參數

**Defaults** 放的是這個 config 每個請求的旋鈕：步數、guidance scale、尺寸，以及底層模型提供的任何參數。它們就是模型自己的介面提供的那些參數。

節點送出的值會覆蓋這些預設值，所以 config 可以一次設好合理的值，個別節點再調整重要的那幾個。

## 在圖裡使用

把 [Send To AI](nodes.zh-TW.md#send-to-ai) 節點的 AI Config 指向這個 modality config。prompt 範本照常運作，會變成生成的 prompt。範本沒有引用到的輸入 pin，會當作生成參數傳下去 —— 從圖的其他地方控制 seed 或步數，就是靠這個。

處理現有檔案的模型，會從一個固定名字的輸入 pin 讀取檔案：`mesh` 從名為 `image` 的 pin 拿圖片，`asr`、`vad` 和 `separation` 從名為 `audio` 的 pin 拿錄音。這個 pin 可以是 asset pin，也可以是放著 server 端路徑的文字 pin，例如前面某個節點的 `OutputFile`。

`ALL` 以逗號串接的 server 端路徑清單，給出產生的每一個檔案；如果模型產生的是文字、沒有檔案（`asr`、`vad`），就是那段文字。你命名為 `OutputFile` 的輸出 pin 會單獨帶著第一個檔案，`Asset` 輸出則以檔案的形式帶著它們，可以直接接到另一個節點的 asset 輸入。

如果一個 AI config 和一個 modality config 同名，以 AI config 為準。

## 把檔案存進你的專案

生成的檔案在 server 上產生，在這一輪剩下的時間都留在那裡，讓後面的節點可以使用。要把它們放進你的專案，就給節點一個 `out_dir` —— 一個名為 `out_dir` 的 pin，或 config 裡的 `out_dir` 預設值。它是**你專案裡**的資料夾：相對路徑是相對於工作區資料夾，所以 `out` 會把檔案放在 `<project>/out/`。server 絕不會在它自己的機器上建立這個資料夾，server 和你的編輯器也不必是同一台機器。

檔案準備好時，chat panel 會用存任何寫入的方式存它：

- 先問，一次一個檔案，核准方式跟 `write_file` 一樣 —— 如果你把寫檔設成自動允許，這些也會自動允許。卡片會寫明這個檔案是生成的，以及它會不會取代一個已經存在的檔案。
- 絕對路徑的 `out_dir`，或通往專案以外的 `out_dir`，依照 **Settings → File access** 處理：每次都問，或拒絕。
- chat 裡的一張卡片會說明檔案存到哪裡，或為什麼沒有存。

如果檔案準備好時編輯器關著或斷線了，下次那段對話連上時會再提供一次。

沒有 `out_dir` 的話，檔案只在這一輪裡使用（例如你要轉成網格的那張圖片），這一輪結束時就刪除。server 也會在一輪結束、而且從它提供出去的每個檔案都已經存好、被拒絕或失敗之後，刪除這一輪的檔案；在那之前它們放在哪裡，由 server `config.xml` 裡的 `<modality_output_dir>` 設定。

---

[← Logic Editor](logic-editor.zh-TW.md) · [AI Configs](ai-config.zh-TW.md) · [Client 指南](README.zh-TW.md)
