[English](README.md) · **繁體中文**

# CAGE — Composable Agent Graph Engine

**自架的 AI 程式開發助手：一個 C++20 推論伺服器，加上一個 VSCode client。
模型、session、專案索引和產生出來的檔案，全部留在你自己的硬體上。**

名字就是設計本身：agent 的迴圈是一張你用節點組起來、隨時可以修改的**圖**，不是寫死在執行檔裡的固定迴圈。每個節點自己挑模型，所以同一輪可以用又小又快的模型做規劃，再交給大模型寫程式。

> **專有軟體。** Copyright (c) 2026 real0000. All Rights Reserved.
> 這個 repository 發行的是編譯好的套件與文件，不含原始碼，原始碼也不出售。

## 授權

CAGE 以**基本產品，加上另外購買的模組**的方式販售，每個產品都附**永久更新**：買一次，這個產品之後的每一個版本都包含在內。沒有維護期、不用續約，也不會到了哪個版本授權就停止。

**商業授權**以組織為單位：在同一家公司內，要裝幾台機器、跑幾份都可以，供自己內部使用。不按座位、GPU 或伺服器數量計算。

| | |
|---|---|
| 範圍 | 一個法人，以及它所控制的法人；安裝數量不限 |
| 用途 | 你自己的內部業務，包括開發你自己的產品 |
| 更新 | 永久。你買的產品之後的每一個版本，都不另外收費 |
| 模組 | 重大的新功能另外販售，各自附永久更新。模組要搭配已授權的基本產品才能使用 |
| 不包含 | 把 CAGE 的功能以代管服務、API 或代工服務的形式提供給第三方 —— 這需要另外簽約 |

**模組不會拿走你已經買到的東西。** 授權當時產品做得到的事，永遠是那個產品的一部分；模組只會往上加。

另外有免費的評估版可以測試，但不能用在正式環境。

完整條款：**[LICENSE](LICENSE)**。洽詢（包括代管服務與 OEM 條款）：<https://github.com/real0000>

---

## 下載

| 套件 | 平台 | 內容 | 位置 |
|---|---|---|---|
| `cage-server-0.2.0-linux-x64.tar.gz` | Linux x86-64 | 推論伺服器、節點代理、控制台、模型下載器 | [Releases](../../releases) |
| `cage-backend-*-0.2.0-linux-x64.tar.gz` | Linux x86-64 | **GPU 支援：依你的硬體挑一包。** 見下方 | [Releases](../../releases) |
| [`cage-0.2.0.vsix`](dist/cage-0.2.0.vsix) | VSCode ≥ 1.85 | 編輯器 client | 這個 repository 的 `dist/` |

> **GitHub 上的是評估版。** 這裡的 Releases 放的是預覽與評估用的套件，讓你試用 CAGE、回報哪裡壞了。它們不是授權產品，也不能用在正式環境，見[授權](#授權)。
>
> 購買透過 Gumroad（由它擔任登記商家），授權版本也從那裡交付。購買附帶該產品的永久更新；這個 repository 不是它的更新管道。

**server 套件裡沒有任何 GPU 程式碼。** 每個本機模型都還需要一個後端包：另一個下載檔，裡面是替你的顯示卡編譯好的 kernel。依 compute capability 挑選：

| 後端包 | 硬體 |
|---|---|
| `cage-backend-cuda-sm60_sm61` | P40、P100、P4、GTX 10xx |
| `cage-backend-cuda-sm70_sm75` | V100、Titan V、T4、RTX 20xx、GTX 16xx |
| `cage-backend-cuda-sm80_sm86` | A100、A30、A40、A10、RTX 30xx |
| `cage-backend-cuda-sm89_sm90` | L40、L40S、L4、RTX 40xx、H100、H200 |
| `cage-backend-cuda-sm120_sm121` | RTX 50xx、GB10（DGX Spark） |
| `cage-backend-hip-*` | AMD（透過 ROCm），依 ISA 世代分包（RDNA2／3／4、CDNA） |
| `cage-backend-vulkan` | 任何支援 Vulkan 1.2 的 GPU：AMD、Intel 或 NVIDIA |
| `cage-backend-cpu` | 沒有 GPU |

可以同時裝好幾包，server 會逐張卡探測每一包。一包都沒裝的話 server 照樣能跑，但只有 `remote` 模型能用。完整說明：**[後端包](doc/server/server/backend-packs.zh-TW.md)**。

安裝：先看 **[doc/server-install.zh-TW.md](doc/server-install.zh-TW.md)**（Docker 或原生安裝），再看編輯器 client 的 **[doc/extension-install.zh-TW.md](doc/extension-install.zh-TW.md)**。

---

## 概觀

```
   VSCode extension ──┐
                      ├── WebSocket + HTTP ──► CAGE Server ──► local models / GPUs
   native client    ──┘                              │
                                                     ├── backend pack (in-process):
                                                     │     text, vision, safetensors,
                                                     │     image, speech, music, motion, 3D
                                                     └── remote chat APIs
```

所有吃資源的工作都在 server：模型的載入與擺放、agent 迴圈、檢索，以及多模態的處理流程。client 只是一層薄薄的編輯器前端，負責顯示對話，並在你的電腦上執行工具呼叫。

![VSCode 裡的 CAGE chat panel](doc/images/chat-panel.png)

*chat panel 就在 VSCode 裡。圖中 DemoCoder 這張圖剛規劃好一個 texture packer，負責寫程式的 coder（四張本機 V100 上的 Qwen3.8）剛寫完 `packer.cpp`。底部的選單決定由哪一張邏輯圖來驅動這段對話。*

## 功能

### 本機推論，多種後端

模型都經過同一層 adapter，後端有兩種。一種是行程內的 **ik_llama.cpp**（來自後端包），GGUF 和 Hugging Face safetensors 都由它跑，視覺模型也是（透過 `mmproj` projector）；另一種是 **remote** 雲端端點（OpenAI、Anthropic、Gemini）。整套沒有任何 Python。模型要等到第一個用到它的請求才載入；所有本機模型共用一本 RAM／VRAM 帳本，新模型放不下時，驅逐最久沒用、而且正閒著的那一個。

模型的 `<path>` 是一個*資料夾*：裡面每個 `*.gguf` 都會變成一個可以選的量化版本；safetensors 資料夾則在載入時才量化（4bit、8bit、bf16、fp16、fp32）。模型是哪一種（聊天、embedding、圖像生成）是從權重判斷出來的，不用自己宣告。

### 多 GPU 擺放

擺放依照機器實際的拓樸來決定：NVLink 怎麼分群、每張卡還剩多少 VRAM，以及模型是 dense 還是 mixture-of-experts。layer split、tensor split、把專家層放到 CPU，都由系統自動選擇；你只要在每個 AI config 裡挑要用哪幾張 GPU。

### 用邏輯圖取代寫死的 agent 迴圈

agent 的行為是一張明確、可以執行的圖，在 VSCode 裡用視覺化的方式編輯：prompt 節點、格式檢查、dispatch、可以重新進入的迴圈，以及會暫停執行、向你提問的決策節點。每個節點都能自己選模型、量化、GPU 組合和取樣參數。同一輪裡，可以讓便宜快速的模型做規劃，大模型寫程式。

![Logic Editor](doc/images/logic-editor.png)

*Logic Editor 裡的一套 coding 工作流程。左側是節點面板、圖中節點所綁定的 AI configs，以及這張圖的變數。每個 config 各自指定自己的模型與參數。*

### 工具在你的編輯器裡執行

讀寫檔案、套用 patch、執行終端機指令、建置專案、開啟檔案，全部在 VSCode 裡執行。每個工具都可以要求核准，寫檔則是一個檔案一個檔案核准。一張 **Tools** 表收錄了模型能呼叫的所有工具：內建的、你用一行指令自己定義的，以及掛上來的 **MCP** 程式所提供的（stdio 或 Streamable HTTP）。

### 對你的專案做檢索

client 先送出完整的索引，之後隨著你編輯送出增量。切塊依 tree-sitter 的 AST 進行，不支援的語言改以行數視窗切塊；embedding 在 server 上計算，向量依專案存放在 hnswlib 裡。圖中任何一個節點，都能替自己的 prompt 取回最相關的前 k 個片段。

### 多模態

圖像生成、文字轉語音、音訊與音樂生成、動作生成，以及圖片轉 3D 網格，也都在行程內透過後端包執行，跟語言模型共用同一個 GPU context 與同一本 VRAM 帳本。

### 專案記憶

每個檔案改了什麼、為什麼改的歷史；目前這段對話每一步做了什麼的紀錄（迴圈裡再跑一次的步驟，因此看得到上一次發現了什麼）；以及你自己定下的長期規則。由一個小模型挑出每一步實際要讀哪些。

### 多使用者

帳號、個人存取權杖、每個使用者各自的 session 與 token 計量；邏輯圖可以只屬於擁有者，也可以共享；還有控制台的網頁介面，用來管理多台機器上的帳號、節點與模型下載。

---

## 需求

| | |
|---|---|
| Server（兩種裝法都需要） | Linux x86-64，加上符合你 GPU 的[後端包](doc/server/server/backend-packs.zh-TW.md)。NVIDIA 只要裝驅動程式，後端包自帶 CUDA 函式庫。AMD 用 HIP 後端包或 Vulkan，Intel 用 Vulkan。純 CPU 也能跑，只是慢 |
| …用 Docker | Docker 加 Compose v2；要用 GPU 還需要 NVIDIA Container Toolkit。主機上不必裝別的 |
| …原生安裝 | glibc 2.28 以上（RHEL／AlmaLinux／Rocky 8、Ubuntu 20.04、Debian 11、Fedora，或更新的版本）；執行安裝程式需要 PowerShell 7.4 以上；要用帳號功能的話還需要 MySQL |
| Client | VSCode 1.85 以上 |

## 文件

| 文件 | 內容 |
|---|---|
| [WHATSNEW.zh-TW.md](WHATSNEW.zh-TW.md) | **從 0.1.x 升級？** 改了什麼、哪些需要你動手處理 |
| [doc/verification-status.zh-TW.md](doc/verification-status.zh-TW.md) | **每個部分測試到什麼程度**，以及哪些回報最有幫助 |
| [doc/server-install.zh-TW.md](doc/server-install.zh-TW.md) | **從這裡開始**：選 Docker 或原生安裝，接著完整說明原生安裝的設定、資料庫、TLS 與疑難排解 |
| [doc/server/docker.zh-TW.md](doc/server/docker.zh-TW.md) | Docker 安裝：一個 `docker compose up`，模型、資料庫和設定都是主機上的資料夾 |
| [doc/extension-install.zh-TW.md](doc/extension-install.zh-TW.md) | 安裝 `.vsix`、連上 server、登入、第一次使用 |
| [doc/server/](doc/server/README.zh-TW.md) | Server 指南：節點代理、推論伺服器、控制台各自負責什麼；模型、後端、modality、檢索、帳號、多節點 |
| [doc/client/](doc/client/README.zh-TW.md) | Client 指南：兩個視窗逐一面板說明、每一種節點、每一個設定參數、RAG、工具與檔案核准、所有設定 |

## 授權條款

專有軟體 —— Copyright (c) 2026 real0000. All Rights Reserved.
以授權方式提供，不是販售；不包含、也不出售原始碼。完整條款見 [LICENSE](LICENSE)，購買涵蓋哪些內容見上方的[授權](#授權)。

CAGE 使用了一些開放原始碼元件，全部採用寬鬆授權，連同各自的著作權聲明列在 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。模型權重**不在**這兩份文件的範圍內：權重由營運者自行挑選、安裝，其中好幾個有商業使用上的限制。見[模型授權](doc/server/server/models.zh-TW.md#模型授權要自己確認)。
