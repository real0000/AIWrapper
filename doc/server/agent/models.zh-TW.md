[English](models.md) · **繁體中文**

# 模型與下載

怎麼把模型放到一台機器上、寫進它的設定 —— 這是節點代理除了管理 server 之外的另一份工作。

---

## 新增模型

四種方式，最後都是同一個結果 —— 本機 `config.xml` 裡的一個 `<model>` 項目：

| 方式 | 什麼時候用 |
|---|---|
| 控制台的網頁介面 | 一般情況。搜尋 Hugging Face、挑一個量化群組、下載，項目就替你寫好了 |
| `cage-model-dl` | 用腳本安裝，或沒有圖形介面的安裝 |
| `cage-model-dl --scan` | 已經在磁碟上的模型 —— 註冊它們，連授權一起 |
| 編輯 `config.xml` | 以上都處理不到的路徑 |

```bash
./bin/cage-model-dl Qwen/Qwen3-Coder-Next --dir models --config config.xml
```

| 選項 | 意思 |
|---|---|
| `--dir` | 下載的根目錄（預設 `./models`）；檔案會放在 `<dir>/<repo-name>/` |
| `--rev` | 分支或 revision（預設 `main`） |
| `--config` | 要更新的 `config.xml` |
| `--alias` | 模型在各個 config 裡的名字。省略的話從 repo 名稱推出來 |
| `--list` | 列出可以下載的群組然後結束 |
| `-y` | 略過確認，但還是會問要哪一個群組 |
| `--fetch-cards` | 為每一個設定好、卻沒有 model card 的模型抓 model card —— 見下方 |

## Model card

一個模型的 context 能延伸到多長，只寫在它的 model card 裡，而 server 只讀本機的檔案。所以下載時會連同權重一起帶回 card（`README.md`）。在那之前下載的模型沒有 card：`cage-model-dl --fetch-cards --config config.xml` 會從每個項目的 `<source_repo>` 把它抓回來。沒有記錄來源 repo 的項目會被列出來，而不是用猜的 —— 從錯的 repo 抓到的 card，會讓這個模型套用另一個模型的上限 —— 所以請先在控制台確認它的來源。

授權也是從 card 來的。自訂的授權 —— `license: other` 加上 `license_name` 與 `license_link` —— 會照它自己的名稱和連結記下，認得的還會分類：Qwen Research License 是非商用，Qwen License 是有條件的商用。項目也會記下 `<source_repo>`，`--fetch-cards` 讀的就是它。

## 模型需要的其他 repo 的部分

有些模型發布時，沒有附上它執行時需要的全部東西。

- **模型自己點名的部分。** 例如 TRELLIS.2，指名要一個 DINOv3 特徵擷取器、一個去背模型，和 TRELLIS v1 的一個解碼器。下載器會連同模型一起把它們抓下來，放進 `<模型目錄>/components/<名稱>/`，載入器就在那裡找。
- **只發布擴散模型本體的生圖模型。** 生圖模型的量化 GGUF repo 常常只有 denoiser —— Qwen-Image 2.1 Turbo 的就是。repo 沒有 `model_index.json`、而它的 card 的 `base_model` 是一個 diffusers pipeline 時，下載器會另外抓那個 pipeline 的 `model_index.json`，以及它列出的每一個部分（denoiser 除外）—— 文字編碼器、VAE、scheduler —— 放進 `<模型目錄>/components/<base model 的名稱>/`。base model 不是 pipeline 的話（例如量化語言模型的原版），什麼都不抓。

這些部分不在時 —— 例如模型是手動複製過來的 —— 開機的 log 會說少了什麼、用 `cage-model-dl` 下載就會一起抓，載入這個模型也會在讀任何權重之前，用同一句話停下來。

## 已經在磁碟上的模型

經由別的途徑來的權重 —— rsync、手動下載、比這個工具還早的工具 —— 以前是看不見的：下載程式只會單向運作（repo id → API → 下載 → 寫 `config.xml`），所以唯一的辦法是手動打出整個項目，連授權也要自己填。

`--scan` 把那條路倒過來走，從檔案出發：

```bash
./bin/cage-model-dl --scan /mnt/models --config config.xml
```

| 選項 | 意思 |
|---|---|
| `--scan DIR` | 走訪這個資料夾，註冊找到的東西 |
| `--dry-run` | 回報會註冊什麼，但不做任何改動 |
| `--offline` | 完全不連網路；只用磁碟上有的東西 |

格式、量化版本和視覺 projector，來自 server 啟動時跑的同一個掃描程式 —— 不是另一份可能跟它意見不同的實作。

**授權**依序判定：GGUF 的 `general.license` 中繼資料、model card 的 YAML front matter、`.git` 的 remote，最後是上游的 Hugging Face card。判定不出來的就寫成 `commercial=""`，而不是用猜的 —— 控制台會把未知和非自由授權的項目列出來，讓你檢查。

它會處理兩個陷阱，都是在真實的檔案裡發現的：

- **重新打包的人嵌進去的模型名稱，是他們高興寫什麼就寫什麼。** 有一個 llava GGUF 自稱 `Downloads`，拿這個去搜尋 Hugging Face，會找到一個真實存在、毫不相干的 repository，它的授權就會被套到你的模型上。依名稱搜尋的結果，一律拿磁碟上的資料夾來驗證，絕不拿中繼資料。
- **從有限制的權重蒸餾出來的模型，標的授權是錯的。** `DeepSeek-R1-Distill-Llama-70B` 寫著 `license: mit`，權重卻仍然受 Llama 3.3 社群授權約束。這類模型會提升為真正約束它的那個授權 —— 而基底只是*可能*是 Llama 的（TinyLlama 確實是 Apache-2.0），會清空 `commercial` 並寫明原因，而不是自己選一邊。

掃描本身只拒絕一種東西：裡面沒有它認得的權重的資料夾 —— 整個資料夾裡沒有任何 `.gguf` 或 `.safetensors` 檔案。子資料夾裡的權重也算（TRELLIS.2 把它們放在 `ckpts/`），不叫 `model*` 的 safetensors 也算（`sd3.5_large.safetensors`）；只有聊天模型的載入程式會直接讀取的資料夾，才會提供量化選項。它不會試著判斷某個東西是不是語言模型，因為那不是看資料夾清單就能回答的問題。`.pt`、`.bin` 和 `.ckpt` 完全不算權重：那些是 Python pickle，server 裡沒有任何東西會讀它們。

最上層有 model card（帶 YAML front matter 的 README），或有 `config.json`、`model_index.json`、`pipeline.json` 的資料夾，就是一個模型。它的子資料夾是它的組成部分，不是各自獨立的模型。

一組權重到底*是*什麼，要到 server 啟動時才決定，而那時它還會再拒絕兩種東西，每一種都會在 log 裡寫明原因：

- **這個後端沒有對應計算圖的架構。** 圖片、音訊和 3D 模型也會以 `.gguf` 發布，並宣告自己的架構名稱 —— 一個 Hunyuan3D 檔案寫的是 `pig`。這些以前會被註冊成聊天模型，直到有人選了它才失敗。
- **元件權重。** 屬於某個更大流程的特徵擷取器或去背模型，不是可以讓 config 指向的模型。

不擋下來的話，兩者都會變成出現在清單上、第一次使用就失敗的 alias。

同樣的掃描也可以在控制台的 Models 分頁使用，在「Import models that are already on disk」底下。匯入時會在 server 上重新掃描，而不是相信瀏覽器送回來的欄位。

## 量化群組

一個 Hugging Face repo 通常放著好幾種量化版本，有時每一種還分成很多個檔案。下載程式會把檔案清單分組，讓你挑的是一種量化，而不是一堆檔案 —— 分成好幾片的 shard（`-00001-of-00005`）會當成一個單位一起下載。

正因為有這個分組，大的 repo 值得先跑一次 `--list`：它會列出這個 repo 實際提供什麼、每個選項有多大。

## 好幾顆硬碟

`<download_dir>` 可以重複：

```xml
<node>
  <download_dir>models</download_dir>
  <download_dir>/mnt/ssd2/models</download_dir>
  <download_dir>/mnt/bigdisk/models</download_dir>
</node>
```

節點代理依剩餘空間挑選目標，所以 400 GB 的模型不會因為落在錯的硬碟上而下載到一半失敗。每個資料夾的剩餘空間與總空間，在網頁介面上都看得到。

之後再加硬碟不需要搬移任何東西 —— 既有的模型保留原本的路徑，那些路徑在 `config.xml` 裡是絕對路徑。

## config.xml 怎麼被編輯

值得知道，因為它解釋了一個限制。

節點代理做的是**精準的文字編輯**：找出 `<model>` 元素所在的位元組範圍，取代或插入文字，留一份 `.bak`，事後再檢查註解的開頭和結尾有沒有成對。

它刻意*不*把檔案解析之後再重新序列化，因為那樣會丟掉所有的註解 —— 而這份檔案大部分都是註解，那些就是這次部署的說明文件。

實際的結果是：網頁介面寫入檔案時，**你的註解和格式都會保留下來**。你在某個模型項目旁邊手寫的筆記，會留在你放的位置。

## 下載之後

server 重新啟動之前，新的項目都是 `pendingRestart`。下載本身不會碰到執行中的 server，所以大型下載進行時，server 可以照常服務。

方便的時候再重新啟動；模型就會變成 `live`。

## 模型路徑

`<path>` 是一個**資料夾**，不是檔案：

- **GGUF** —— 裡面的每一個 `.gguf` 都是一種量化版本。要多一種量化，就把那個檔案放進同一個資料夾；不用改設定。
- **safetensors** —— 量化在載入時才做，所以一份權重就能選全部的量化。

server 怎麼使用那個資料夾，見[模型](../server/models.zh-TW.md)。

---

[← 節點代理](README.zh-TW.md) · [節點 API](api.zh-TW.md) · [Server 指南](../README.zh-TW.md)
