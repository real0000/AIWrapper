[English](modalities.md) · **繁體中文**

# Modality

圖片、語音、音訊、音樂、3D 和動作的生成。每一種都跟其他模型一樣是一個 `<model>` 項目，並且**在 server 的程序裡**、用語言模型同一個[後端包](backend-packs.zh-TW.md)執行。

沒有另外的服務，沒有子程序，也沒有 Python。

只用文字的話，這些都不需要。不宣告這類模型，就什麼都不會載入。

---

## 一個項目

```xml
<model alias="sd3.5-large">
  <path>/mnt/models/stable-diffusion-3.5-large</path>
  <defaults>
    <steps>28</steps>
    <cfg_scale>7.0</cfg_scale>
    <width>1024</width>
    <height>1024</height>
  </defaults>
  <license name="Stability AI Community License" commercial="restricted" url="…"/>
</model>
```

| 欄位 | 意思 |
|---|---|
| `alias` | 圖裡的 modality config 引用的名字 |
| `<path>` | 權重 —— 檔案或資料夾，看那個系列預期哪一種 |
| `<dtype>` | 權重的型別。只有圖片的轉接程式會讀 |
| `<defaults>` | 生成參數，會被圖節點送來的值覆寫 |
| `<extra>` | 給那個系列的載入程式的額外設定 |
| `auto_start` | 開機時就載入，而不是第一次使用時。從啟動起就占用 VRAM |
| `<license>` | 意思跟[模型](models.zh-TW.md#授權資訊)的一樣 |

**你不用說它是哪一種模型。** 沒有 `<type>`，也沒有 `<family>` 欄位 —— 寫了也沒有作用。server 啟動時會問每個模型它是什麼：後端包裡的每一個轉接程式都會拿到路徑，回答那些權重是不是它的、它能拿它們做什麼。判斷寫在看得懂那種格式的程式碼裡，所以這裡沒有一張會過時的表。

**語言模型先回答。** 在問任何轉接程式之前，先問語言模型的載入器：架構是它認得的 GGUF，或 `config.json` 寫著它認得的架構的 Hugging Face 資料夾，就成為對話模型，不再往下問。一個 `config.json` 加一個 `model.safetensors` 的資料夾，幾十種語音模型也長得一模一樣；分得出來的只有架構，而架構只有語言模型的載入器知道。語音的轉接程式這一邊，只有在它的模型規格點名的每一個檔案都在時，才接下一個資料夾。有三種資料夾因此認不出來：權重的檔名跟規格寫的不一樣的；語音程式直接讀的第三方 GGUF（例如 `nemotron_transcribe`）；以及架構是語言模型的 any-to-any GGUF（例如 LFM2.5-Audio），它會成為對話模型。

大部分的項目，只要 `<path>` 和 `<license>` 就夠了。

這就是那些欄位被拿掉、而不是改成可省略的原因。宣告錯的種類，沒有任何東西能反駁它；宣告*對*的更糟：有一個 SD 3.5 的項目帶著 `<family>sd</family>` 好幾個月，它悄悄掩護了一個從來沒有認出過那個模型的探測。一切看起來都沒事，直到那一行被刪掉。如果你想讓一個多工模型的某個 alias 固定在特定的工作上，那是執行時的偏好，應該放在 modality config 裡，不是這裡。

## 共用一個程序、一個 context、一本帳

這些轉接程式編譯在後端包裡，跟語言模型共用 ggml —— 同一個 CUDA context，同一套 VRAM 帳。

預算之所以誠實，就是因為這樣。一個占著 8 GB 的圖片模型，負責判斷語言模型放不放得下的載入程式看得到它，也能驅逐它，因為帳只有一本，而不是每個程序各一本。見[後端 → 預算](backends.zh-TW.md#預算)。

這也代表生成式模型跟其他所有東西一樣，適用延遲載入和驅逐：第一次使用時載入，別的東西需要空間時卸載。

## 可以用哪些 GPU

在圖裡、在 [modality config](../../client/modality-config.zh-TW.md) 上選擇，方式跟 AI config 選卡一樣：用 GPU UUID。模型就跑在選的那幾張卡上 —— 全部都用，就算一張就放得下也一樣。留空的話，用後端驅動得動的每一張卡，跟 AI config 同一條規則。選的卡一張都不在這台機器上時，請求會失敗，而不是悄悄落在別的地方。

不只一張卡時，server 按層切分模型，串成 pipeline。tensor parallelism 每做一次矩陣乘法都要在卡之間搬 activation，而這類模型一次算幾百到幾千個位置，對它們來說通常得不償失：SD 3.5 Large 實測按層切比單卡慢 10%、按列切慢 40%。所以一張卡就放得下的模型，攤在好幾張卡上會慢一點 —— 要不要這樣選，由你決定。

- 選的卡加起來也放不下這個模型時，請求立刻失敗，並請你多選幾張。
- 已經載入的模型，只有在這次選的卡完全相同時才直接沿用；不同的話就卸載，照新的選擇重新擺放。

設定它，可以讓生成避開你想保留的卡 —— 顯示卡，或放著大型語言模型一部分的卡。

這個設定沒有全 server 共用的版本。`<ai><cuda_visible_devices>` 以前就是，後來拿掉了：它只能替整台機器做決定，而「這個模型不准碰那張卡」本質上是針對個別模型的。

## 生成參數

`<defaults>` 就是上游專案自己的介面提供的那些參數 —— 步數、guidance scale、尺寸、取樣器設定。它們墊在圖節點傳來的值底下，所以 config 可以一次設好合理的值，個別節點再調整重要的那幾個。

## 怎麼使用

在圖這一邊，[modality config](../../client/modality-config.zh-TW.md) 指定 alias，Send To AI 節點再選那個 config。節點就會產生檔案而不是文字 —— 語音辨識和語音活動偵測則是模型回傳的文字。

`POST /api/generate` 會直接呼叫它；Logic Editor 的預覽用的就是這個。

## 載入不了時

1. **檢查後端包。** 這些轉接程式就在裡面。沒有後端包，任何種類的本機推論都不能用，不只是文字。
2. **檢查 VRAM。** 它跟語言模型搶同樣的卡，server 的 log 會寫出它想保留多少，以及是什麼拒絕了它。
3. **檢查探測結果。** 啟動 log 會記下每個模型被判定成什麼；一個被探測成意料之外種類的模型，就能解釋為什麼某個 alias 沒有出現在你預期的地方。

---

> **如果你是從舊版升級上來的。** modality 模型以前是 Python worker，每個系列各啟動一個，宣告在獨立的 `<modalities>` 區塊裡，帶著 `python_exe`、`script_dir` 和 `timeout_sec`，再用一個腳本為每個系列各建一個虛擬環境。這些全部拿掉了 —— 生成的程式碼現在在後端包裡。
>
> `<modalities>` **不會**被默默轉移：config.xml 裡還留著這個區塊的話，server 會**拒絕啟動**，並以訊息說明怎麼把項目搬進 `<models>`。讀了它卻不理會，看起來就會是「設定還在，模型卻消失了」，那比直接拒絕難診斷得多。
>
> 搬一個項目大多是刪東西：`<modality>` → `<model>`、`<model_path>` → `<path>`，再拿掉 `<python_exe>`、`<device>` 和 `<timeout_sec>`。生成不再受每個請求的計時器限制。

---

[← 推論伺服器](README.zh-TW.md) · [後端](backends.zh-TW.md) · [模型](models.zh-TW.md) · [Server 指南](../README.zh-TW.md)
