[English](docker.md) · **繁體中文**

# Docker

把整個 server 端放進容器裡跑，用你手上的 Dockerfile 建置。沒有發布任何映像檔，也不會從私有 registry 拉任何東西 —— 唯一的外部映像檔是官方的 `mysql`。

檔案在 [`docker/`](../../docker/)。

> **0.2.0 已驗證。** 完全照下面的快速開始，用 0.2.0 的 server 套件和 `cuda-sm70_sm75` 後端包建置，環境是 Docker 29.8、Compose v5.5 和 NVIDIA Container Toolkit：MySQL 起得來、server 找得到後端包、模型在 V100 上回答了 prompt、網頁介面有回應，設定在 `down` 再 `up` 之後還在。細節見[測試過什麼](#測試過什麼)。

---

## 快速開始

```bash
cd release/docker
cp ../dist/cage-server-0.2.0-linux-x64.tar.gz .   # server，一定要

# 接著是你要映像檔涵蓋的每一個後端包 —— 一個或好幾個
cp ../dist/cage-backend-cuda-sm89_sm90-*.tar.gz .
cp ../dist/cage-backend-cuda-sm80_sm86-*.tar.gz .
cp ../dist/cage-backend-vulkan-*.tar.gz .

cp .env.example .env                              # 然後編輯它
docker compose up -d --build
```

**AMD 用另一個 compose 檔** —— `docker-compose.amd.yml`，內容完整、可以直接跑，什麼都不用改：

```bash
cp ../dist/cage-backend-hip-gfx1100_gfx1101_gfx1102-*.tar.gz .
docker compose -f docker-compose.amd.yml up -d --build
```

分成兩個檔案、而不是一個檔案加一個開關，是因為這兩者不是同一件事的變化：NVIDIA 透過 nvidia-container-toolkit 把 GPU 交給容器，ROCm 則完全沒有 runtime 外掛 —— 核心驅動的裝置節點直接對應進去，容器的使用者還必須屬於擁有那些節點的群組。AMD 的映像檔也拿掉了 CUDA 基底，因為 HIP 後端包自帶 ROCm 函式庫，CUDA 基底只會白白多出十幾 GB。

先確認主機看得到卡 —— `ls /dev/kfd /dev/dri`。沒有 `/dev/kfd` 表示 amdgpu 驅動沒有載入，容器怎麼設定都沒用。

**server 套件不含任何 GPU 程式碼**，所以映像檔還需要至少一個[後端包](server/backend-packs.zh-TW.md)。`release/docker/` 裡的**每一個** `cage-backend-*.tar.gz` 都會解開到映像檔裡 —— 跟原生安裝一樣：你想放幾個後端包到 `bin/` 都行，server 會針對每張卡逐一試過每個後端包。

機器上混用不同的卡，或一個映像檔要給好幾台機器用時，放進不只一個是很正常的做法。除了映像檔變大，沒有其他代價，也不用設定：AI config 會綁定到能驅動它所選 GPU 的那個後端。

一個都不放也建得起來、跑得起來 —— `remote` 模型能用，本機模型會載入失敗。建置時會印出一則警告說明這件事。

`.env` 裡要設定這些：

| 變數 | 意思 |
|---|---|
| `MODELS_DIR` | 主機上放模型的資料夾 —— 以唯讀方式掛載在 `/models` |
| `STATE_DIR` | 資料庫、設定和資料放的地方。**必須在 ext4／xfs 上 —— bind mount 到 exFAT 或 NTFS 會失敗**，所以它跟你解開這些檔案的地方分開 |
| `MYSQL_PASSWORD`、`MYSQL_ROOT_PASSWORD` | 任何非空的值；只有這兩個容器會用到 |
| `ADMIN_PASSWORD` | 控制台網頁介面的登入密碼。空的表示關閉驗證 |

然後：

```bash
docker compose logs -f cage       # 看它啟動
curl http://127.0.0.1:15963/health     # {"status":"ok"}
```

網頁介面在 `http://127.0.0.1:8088/`。把 VSCode extension 指向 `localhost` 的 `15963` 連接埠。

`PUID`／`PGID` 也設成你自己的 `id -u`／`id -g`，除非你喜歡編輯 root 擁有的檔案：容器以 root 執行，否則它在那些資料夾裡建立的所有東西都會屬於 root。

## 需求

| | |
|---|---|
| Docker | 要有 Compose v2（`docker compose`，不是 `docker-compose`） |
| GPU 存取 | **NVIDIA**：主機上要有 nvidia-container-toolkit（`docker-compose.yml`）。**AMD**：要有 amdgpu 驅動，讓 `/dev/kfd` 存在（`docker-compose.amd.yml`）。兩者都沒有的話，全部在 CPU 上跑 |
| 驅動 | 任何 CUDA 12.x 的驅動，525.60.13 或更新 |
| GPU | 你的[後端包](server/backend-packs.zh-TW.md)涵蓋的都行 —— CUDA 從 compute capability 6.0（Pascal）起，AMD 用 HIP 後端包，其他的用 Vulkan |
| 磁碟 | 不含後端包的映像檔，加上 CUDA 後端包解開後的 1.6–2.3 GB（Vulkan 和 CPU 後端包約 150 MB），再加上你的模型 |

基底映像檔是 `nvidia/cuda:12.6.3-runtime-ubuntu24.04`，前後兩半都有意義：

- **ubuntu24.04** —— 這套設定驗證時用的就是它。server 和後端包只需要 glibc 2.28，所以更舊的基底應該也可以；但沒有用這個 Dockerfile 試過。
- **-runtime** —— 映像檔裡什麼都不用編譯。以前是 `-devel`，用來建置 Python worker 的環境，那些已經拿掉了。CUDA 後端包自帶 CUDA 函式庫，所以單純的 `ubuntu:24.04` 基底應該也可以；這也還沒試過。

CUDA 12.x 的容器能搭配任何 12.x 的驅動，所以映像檔的 CUDA 版本不必跟主機的 toolkit 一致。

## 什麼掛載到哪裡

重要的東西全部是主機上的資料夾，所以容器隨時可以丟掉重建。

| 主機 | 容器 | 放什麼 |
|---|---|---|
| `${STATE_DIR}/config` | `/config` | `config.xml`、`control.xml` —— 第一次啟動時產生，之後歸你管 |
| `${STATE_DIR}/server` | `/opt/cage/data` | 邏輯圖、檢索用的向量、server 的 log |
| `${STATE_DIR}/mysql` | `/var/lib/mysql` | 資料庫 |
| `${MODELS_DIR}` | `/models`（唯讀） | 你的模型 |

沒有輸出資料夾。圖產生的檔案會交給 client，寫進使用者的專案；直接呼叫 `/api/generate` 的話，檔案會留在容器內 server 自己的暫存目錄（`/tmp/cage-<uid>`，只有 server 的帳號讀得到），容器沒了它也就沒了。以前的 compose 檔會把 `${STATE_DIR}/output` 掛載到 `/tmp/cage`；現在已經沒有東西寫到那裡了。

**server 的資料掛載點是 `/opt/cage/data`，不是 `/data`。** server 是以它的工作目錄為基準解析 `data/logic_graphs` 和 `data/vectors`，掛在其他地方的 volume 會被默默忽略，下次重建容器時圖就不見了。為了找出這一點，花掉了一輪測試。

## 連接埠

| 連接埠 | 預設是否對外 | 用途 |
|---|---|---|
| 15963 | 是 | AI API —— HTTP＋WebSocket。編輯器連的就是它 |
| 8088 | 是，綁在 `127.0.0.1` | 控制台的網頁介面 |
| 15972 | 否 | 節點代理的 API。只有在另一台機器上的控制台要管理這個節點時才需要 |
| 3306 | 否 | MySQL。只有 cage 容器需要它 |

網頁介面綁在 localhost，因為它能啟動、停止和重新設定 server。要讓它對更大的範圍開放，應該是刻意的決定，而且要放在處理 TLS 的 proxy 後面。

任何一個都可以在 `.env` 裡改（`API_PORT`、`WEB_PORT`、`AGENT_PORT`）—— 這些是主機端的連接埠，容器自己的連接埠維持設定預期的值。

## Safetensors 模型

什麼都不用做。進程內的後端讀取 `*.safetensors` 的 Hugging Face 資料夾，就跟讀 GGUF 資料夾一樣，並在載入時量化。讓一個 `<model>` 指向它，再在 AI config 上選量化 —— 見 [Safetensors 模型](server/safetensors.zh-TW.md)。

以前這需要在 `/venvs` 裡準備一個 Python 環境 —— vLLM，或一個把權重轉成 GGUF 的 `torch` 環境。兩者都已經拿掉了。

## 新增模型

把放模型的主機資料夾掛載進去，以 `/models` 稱呼它：

```xml
<model alias="my-coder">
  <path>/models/Qwen3-Coder-Next</path>
</model>
```

編輯 `${STATE_DIR}/config/config.xml` 再重新啟動，或從網頁介面加入。不管哪一種，server 都要重新啟動，新的項目才會載入 —— 見[重新啟動才生效](agent/README.zh-TW.md#重新啟動才生效)。

`/models` 是唯讀掛載的，所以從網頁介面下載會失敗。想讓節點代理自己下載模型，就把 compose 檔裡的 `:ro` 拿掉。

## 不用資料庫執行

把 compose 檔裡的 `mysql` 服務、`depends_on` 區塊和 `MYSQL_PASSWORD` 那幾行拿掉。第一次啟動時，entrypoint 會寫出一份沒有 `<mysql>` 區塊的 `config.xml`，server 就會以開放模式執行：沒有帳號、沒有個別使用者的 session，API 也沒有驗證。

**安全性：** 對外的 API 連接埠上的每一個請求，都會以管理員身分處理。任何連得到那個連接埠的人，都能讀取每一個 session、修改圖。這對單人試用是刻意的設計，不會改 —— 把連接埠發布成 `127.0.0.1:${API_PORT:-15963}:15963`，就能限制在這台機器上。見[帳號](control/accounts.zh-TW.md)。

已經有 `<mysql>` 區塊的 `config.xml` 會保留它 —— entrypoint 絕不會拿掉它，所以忘了設密碼，不會讓 server 悄悄變成開放的。server 接著會等那個資料庫；要不用資料庫執行，請自己拿掉那個區塊。

## 測試過什麼

0.2.0 用發布的套件、照著快速開始測試 —— 最近一次是 2026-10-31，套件在 Enterprise Linux 8 的基底上重新建置過：

| 步驟 | 結果 |
|---|---|
| 建置映像檔 | `nvidia/cuda:12.6.3-runtime-ubuntu24.04`、0.2.0 的 server 套件和 `cuda-sm70_sm75` 後端包 |
| 啟動整組服務 | MySQL 健康，接著是 server；`config.xml` 從範本產生 |
| 後端包 | 在 `/opt/cage/bin` 找到；驅動四張 V100，拒絕 RTX 4070 |
| 推論 | Qwen3-0.6B，一個放在唯讀 `/models` 底下的 safetensors 資料夾，在一張 V100 上回答：0.78 秒 138 個 token，`down`＋`up` 之後再答一次 |
| HTTPS | 在容器裡，`https://huggingface.co` 通過憑證驗證，憑證過期的網站被拒絕 |
| 網頁介面 | 在對外的連接埠上有回應 |
| 持久性 | `down`＋`up` 之後：設定還在，模型重新註冊 |

在 0.2.0 重新打包之前，有四件事讓它跑不起來。在這些檔案裡都已經修好：

| 壞掉的地方 | 原因，以及改了什麼 |
|---|---|
| `docker compose up --build` 找不到套件 | compose 檔的預設值還是 `cage-server-0.1.1-…`，Dockerfile 則是 0.1.2。現在全部是 0.2.0 |
| 建置映像檔時在 `chmod` 失敗 | Dockerfile 把 `/opt/cage/*.sh` 設成可執行。安裝程式在九月改成了 `install.ps1`，所以什麼都比對不到，`chmod` 就失敗了。現在只碰 `bin/` |
| 容器不斷重新啟動：`config.xml(77): expected <` | 範本在一個註解裡又包了註解，XML 不允許這樣 —— 第一個 `-->` 就提早結束了外層的註解。那些註解已經拿掉 |
| 本機模型無法載入 | server 在它的工作目錄 `/opt/cage` 裡找後端包，而不是在 `bin/`。現在它會先在自己的執行檔旁邊找 |

0.1.0 的第一輪測試還找到另外三個，也都修好了：

| 壞掉的地方 | 原因，以及改了什麼 |
|---|---|
| 啟動時 `chown ...: operation not permitted` | checkout 放在 exFAT 上，那裡沒有 Unix 的擁有者概念，而 Docker 會對 bind mount 的來源做 chown。現在狀態放在 `STATE_DIR`，跟 checkout 分開 |
| 邏輯圖和向量寫到一個用完即丟的路徑 | server 以它的工作目錄為基準解析 `data/…`，所以掛在 `/data` 的 volume 直接被忽略。現在掛在 `/opt/cage/data`，也就是 server 實際寫入的地方 |
| 主機上無法編輯 `config.xml` | 容器以 root 執行，所以產生出來的設定屬於 root、權限是 600，文件卻叫你去編輯它。現在 `PUID`／`PGID` 會把 bind mount 交給你的使用者 |

最後兩個是那種平常看起來沒事、等你需要時才出問題的類型：第一個會在重建容器時弄丟你的圖，第二個只有在你想改一個設定時才會咬你一口。

## 日常指令

```bash
docker compose logs -f cage          # server、節點代理和控制台一起看
docker compose exec cage bash        # 進到裡面開一個 shell
docker compose restart cage          # 套用 config.xml 的修改
docker compose down                       # 停止；volume 和資料都留著
docker compose up -d --build              # 換了新套件之後
```

容器執行的是 `cage-launcher --all`，所以節點代理、控制台和 server 共用一個程序、一條 log。重新啟動容器，三個都會重新啟動。

## 起不來的時候

entrypoint 在啟動之前，會針對每一種常見錯誤印出警告 —— 沒有資料庫密碼、沒有管理員密碼、`/models` 是空的。先看這些。

| 症狀 | 可能的原因 |
|---|---|
| 容器立刻結束 | 看 `docker compose logs cage`。出現 GLIBC 錯誤，表示基底映像檔被換成比 glibc 2.28 還舊的版本 —— 例如 Ubuntu 18.04 |
| 啟動時出現 `could not select device driver` | 沒有安裝 NVIDIA Container Toolkit，或裝好之後沒有重新啟動 daemon |
| server 啟動了，log 裡卻沒有 GPU | 同上，或 `deploy.resources` 區塊被拿掉了 |
| GGUF 模型一直載入不了 | 確認模型路徑在掛載的資料夾底下；`backend` 應該是 `llama` |
| safetensors 模型一直載入不了 | 跟任何本機模型的原因一樣 —— 沒有後端包，或 VRAM 不夠。見 [Safetensors 模型](server/safetensors.zh-TW.md) |
| client 無法登入 | `config.xml` 和 `control.xml` 的 `<mysql>` 不一樣。entrypoint 用同樣的變數填這兩個檔案，所以只有手動編輯過才會發生 |
| 從另一台機器連不到網頁介面 | 它是刻意綁在 `127.0.0.1` 的 |
| 掛載資料夾時出現 `operation not permitted` | `STATE_DIR` 在 exFAT／NTFS 上。改指向 ext4／xfs 的路徑 |
| 無法在主機上編輯 `config.xml` | 在 `.env` 裡把 `PUID`／`PGID` 設成你的 `id -u`／`id -g` |

如果以上都不符合，[手動安裝](../server-install.zh-TW.md)是另一條測試過的路。

---

[← Server 指南](README.zh-TW.md) · [手動安裝](../server-install.zh-TW.md)
