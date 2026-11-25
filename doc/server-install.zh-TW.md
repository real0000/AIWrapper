[English](server-install.md) · **繁體中文**

# 安裝 Server

有兩種裝法，用的是同一個 Linux x86-64 套件：
[`dist/cage-server-0.2.0-linux-x64.tar.gz`](../dist/)。

---

## 選哪一種

| | **Docker** | **原生安裝** |
|---|---|---|
| 主機上要裝什麼 | 只有 Docker | 執行檔；要帳號功能的話再加一個 MySQL server |
| 資料庫 | 隨附，是一個 container | 自己安裝、設定 MySQL |
| 相依套件 | Docker 以外沒有 | 執行檔，以及一個後端包 |
| 升級 | 換掉套件、重建、重新啟動 | 重新執行安裝程式 |
| 移除 | `docker compose down`，再刪掉一個資料夾 | 移除 service unit 與安裝目錄 |
| 磁碟 | 其他東西之外還多一份 image | 只有套件和一個後端包 |
| 以誰的身分執行 | container 裡的 root | 你指定的使用者帳號 |

**如果你還沒有在跑 MySQL，Docker 是比較短的路。** 資料庫隨附，主機上什麼都不留。不管哪一種，server 本身都是一個靜態連結的執行檔；自從 Python worker 環境拿掉之後，要準備的東西比以前少很多。

選擇原生安裝的理由：你已經有 MySQL、想讓 server 跟其他服務一起由 systemd 管理、需要它以特定使用者身分執行，或是這台機器不能用 Docker。

0.2.0 的兩種裝法都從頭到尾實際跑過，用的是發行套件，步驟完全照這一頁和 Docker 那一頁的寫法，兩種都在 GPU 上回答了提問。見[驗證到什麼程度](verification-status.zh-TW.md#安裝)。

### → [Docker](server/docker.zh-TW.md)

```bash
cd release/docker
cp ../dist/cage-server-0.2.0-linux-x64.tar.gz .
cp .env.example .env      # 模型資料夾、狀態資料夾、密碼
docker compose up -d --build
```

所有有狀態的東西（資料庫、設定、邏輯圖、模型）都是你自己選的主機資料夾，port 也由你對應。完整那一頁說明了什麼掛在哪裡、GPU 的需求，以及容易踩到的陷阱。

### → 原生安裝

就是這一頁接下來的內容。

---

## 1. 需求

從這裡開始，這一頁講的都是**原生**安裝。container 的裝法見 [Docker](server/docker.zh-TW.md)。

| | 需要 | 說明 |
|---|---|---|
| 作業系統 | Linux x86-64，glibc 2.28 以上 | RHEL／AlmaLinux／Rocky 8、Ubuntu 20.04、Debian 11、Fedora，或任何更新的版本。套件是在 Enterprise Linux 8 的基底上建的，所以要求的不會比 glibc 2.28 與 GCC 8 的 `libstdc++` 更新 |
| GPU | 驅動程式，加上一個[後端包](server/server/backend-packs.zh-TW.md) | NVIDIA 只要驅動程式：CUDA 後端包自帶 `libcudart`、`libcublas` 和 `libcufft`，不必安裝 CUDA toolkit。見[支援的 GPU](#支援的-gpu) |
| RAM | 至少 16 GB | 大模型超過 VRAM 時，大部分會放在 RAM 裡 |
| MySQL | 選用 | 只有帳號、session 和用量紀錄需要。沒有的話 server 以開放模式執行，見 §7 |
| PowerShell | 7.4 或更新（`pwsh`） | 只用來執行安裝程式 `install.ps1`。Microsoft 有替 Ubuntu 和 Debian 發行 `powershell` 套件；`snap install powershell --classic` 也可以 |

確認驅動程式：

```bash
nvidia-smi                       # 驅動程式與 GPU
```

### 支援的 GPU

GPU 支援要**另外下載**。server 套件裡完全沒有 GPU 程式碼，你還要另外下載符合自己硬體的後端包。完整說明在[後端包](server/server/backend-packs.zh-TW.md)，簡短版如下：

| 後端包 | 硬體 | Compute capability |
|---|---|---|
| `cage-backend-cuda-sm60_sm61` | P40、P100、P4、GTX 10xx | 6.0、6.1 |
| `cage-backend-cuda-sm70_sm75` | V100、Titan V、T4、RTX 20xx、GTX 16xx | 7.0、7.5 |
| `cage-backend-cuda-sm80_sm86` | A100、A30、A40、A10、RTX 30xx | 8.0、8.6 |
| `cage-backend-cuda-sm89_sm90` | L40、L40S、L4、RTX 40xx、H100、H200 | 8.9、9.0 |
| `cage-backend-cuda-sm120_sm121` | RTX 50xx、GB10（DGX Spark） | 12.0、12.1 |
| `cage-backend-hip-*` | AMD（透過 ROCm），依 ISA 世代分包。需要 `libdrm2 libdrm-amdgpu1 libnuma1 libelf1` | 不適用 |
| `cage-backend-vulkan` | 任何支援 Vulkan 1.2 的 GPU：AMD、Intel 或 NVIDIA | 不適用 |
| `cage-backend-cpu` | 沒有 GPU | 不適用 |

NVIDIA compute capability **5.x 以前**（Maxwell：GTX 9xx、M40）沒有任何 CUDA 後端包涵蓋；Vulkan 後端包可能還是驅動得了這些卡。

後端包可以裝不只一個，常見的情況是 P40 跟 V100 插在同一台。每個後端包的函式庫以後端包命名，所以可以並排放在 `bin/` 裡；server 會逐個裝置探測每一包，AI config 則綁定能驅動它所選 GPU 的那個後端。唯一的順序規則見[裝不只一個後端包](server/server/backend-packs.zh-TW.md#裝不只一個後端包)。

查看你的硬體：

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv   # NVIDIA
vulkaninfo --summary | head -30                        # 其他廠牌
```

沒有後端包的話 server 照樣啟動，`remote` 模型也照樣能用；但本機模型會在載入時失敗，訊息裡會寫出該下載哪一包。

## 2. 解壓縮

```bash
tar -xzf cage-server-0.2.0-linux-x64.tar.gz
cd cage-server-0.2.0-linux-x64
```

內容：

```
bin/cage-server         推論伺服器
bin/cage-launcher       節點代理＋控制台（網頁介面）
bin/cage-model-dl       Hugging Face 模型下載器；--scan 找出磁碟上已經有的模型
bin/cage-backend-probe  回報你裝了哪個後端包，以及它驅動得了你的哪幾張卡
bin/cage-llama-fit      不載入模型，先問它會被放在哪裡
                        （見 server/server/backends.zh-TW.md）
lib/                    server 執行時需要的函式庫
sql/schema.sql          資料庫 schema
sql/migrate-aiwrapper-to-cage.sql
                        把 AIWrapper 0.1.0 的資料庫改名（見 WHATSNEW）
config.example.xml      server 設定範本
control.example.xml     控制台設定範本
install.ps1             安裝程式（PowerShell）
LICENSE                 最終使用者授權合約
THIRD-PARTY-NOTICES.md  開放原始碼元件與它們的授權
licenses/               那些聲明提到的授權全文
```

**這裡面沒有 GPU 程式碼。** 安裝之前，先把你的[後端包](server/server/backend-packs.zh-TW.md)解壓到同一個目錄，安裝程式才會一起裝進去：

```bash
tar -xzf cage-backend-cuda-sm89_sm90-0.2.0-linux-x64.tar.gz
cp cage-backend-cuda-sm89_sm90-0.2.0-linux-x64/bin/* bin/
cp -r cage-backend-cuda-sm89_sm90-0.2.0-linux-x64/lib/* lib/
```

`-r` 不能省：AMD 後端包的 `lib/` 裡有一個裝著 GPU kernel 的 `rocblas/library/` 資料夾，少了它，第一個矩陣乘法就會失敗。

可以加不只一個後端包。安裝程式會列出它找到的後端包，一個都沒有的話會警告。

**後端包的版本要跟 server 一樣。** server 遇到舊版本的後端包會直接拒絕，而不是默默地讓工具呼叫失效，見[後端包](server/server/backend-packs.zh-TW.md)。升級 server 就要重新下載後端包。

## 3. 安裝

```bash
pwsh ./install.ps1                 # 裝到 /opt/cage，附 systemd 服務
```

| 選項 | 意思 |
|---|---|
| `--prefix DIR` | 安裝目錄（預設 `/opt/cage`） |
| `--user NAME` | 服務以哪個帳號執行（預設：執行安裝程式的使用者） |
| `--no-service` | 只複製檔案，不設定 systemd |
| `--force` | 覆寫已經存在的 `config.xml`／`control.xml` |

安裝程式會：回報它找到哪些後端包，確認 server 需要的每個共用函式庫都找得到；複製 `bin/`、`lib/` 和 `sql/`；從範本建立 `config.xml` 和 `control.xml`（權限 600，因為裡面有資料庫帳密）；建立 `data/` 和 `models/`。現在已經沒有共用的 `/tmp/cage`：server 和 launcher 各自建立自己的暫存目錄 `/tmp/cage-<uid>`（權限 700），所以 systemd unit 允許它們在 `/tmp` 底下寫入。

只有目標目錄不能寫入時才會用到 `sudo`。不用 root 安裝：

```bash
pwsh ./install.ps1 --prefix ~/cage --no-service
```

沒有加 `--no-service` 的話，會裝兩個 systemd unit：

| Unit | 指令 | 角色 |
|---|---|---|
| `cage-agent` | `cage-launcher --agent` | 常駐。看管 `cage-server`、編輯模型清單、下載模型 |
| `cage-control` | `cage-launcher --control` | 網頁介面、管理員帳號、多節點管理 |

server **不是**獨立的服務，由節點代理負責啟動和停止它。這兩個 unit 會設成開機啟用，但不會馬上啟動，因為 `config.xml` 還要先編輯。

## 4. 設定

編輯安裝目錄裡的 `config.xml`。第一次執行時重要的是這三個欄位：

```xml
<mysql>
  <host>127.0.0.1</host>
  <port>3306</port>
  <user>cage</user>
  <password>your-password</password>
  <database>cage</database>
</mysql>

<ai>
  <!-- 選用。整個區塊省略就用預設值。 -->
  <default_model>my-coder</default_model>
</ai>

<models>
  <model alias="my-coder">
    <!-- 是一個「資料夾」，不是檔案。裡面每個 *.gguf 都會變成一個可以選的
         量化版本。Hugging Face 的 safetensors 資料夾也可以放在這裡，載入時
         才量化。不必寫 backend=：掃描結果會決定。 -->
    <path>/path/to/models/Qwen3-Coder-Next</path>
  </model>
</models>
```

這個檔案從工作目錄讀取。要用另一份，用 `CONFIG_FILE` 指定：

```bash
CONFIG_FILE=/opt/cage/config.xml ./bin/cage-server
```

`config.xml` 裡所有的相對路徑，都相對於這個檔案所在的目錄，而不是行程的工作目錄。

旁邊的 **`control.xml`** 也要改 —— 那是控制台的設定。它的 `<mysql>` 填一樣的值，`<admin>` 設一個你自己的密碼：

```xml
<admin>
  <username>admin</username>
  <password>a-real-password</password>
</admin>
```

範例值 `CHANGE_ME` 會被拒絕登入。第一次啟動時，控制台會在資料庫裡建立這個帳號；你用它登入網頁介面，使用者帳號也是在那裡建立的 —— 見[帳號](server/control/accounts.zh-TW.md)。

模型通常透過控制台的網頁介面或 `cage-model-dl` 加入，兩者都會替你改寫 `<models>` 這一段：

```bash
./bin/cage-model-dl Qwen/Qwen3-Coder-Next --dir models --config config.xml
```

## 5. 資料庫（選用）

```bash
mysql -u root -p < /opt/cage/sql/schema.sql
mysql -u root -p -e "CREATE USER 'cage'@'127.0.0.1' IDENTIFIED BY 'your-password';
                     GRANT ALL PRIVILEGES ON cage.* TO 'cage'@'127.0.0.1';"
```

schema 會建立 `cage` 資料庫和它的表。server 和控制台用來連線的帳號要你自己建 —— 就是它們 `<mysql>` 裡的 `<user>` 和 `<password>`。這個帳號建好之前，server 只會在 log 裡寫 `Waiting for the database`，什麼都不服務（§7）。MySQL 在另一台機器上的話，把 `127.0.0.1` 換成 CAGE 那台機器的位址。

`config.xml` 和 `control.xml` 裡的 `<mysql>` 必須指向**同一個**資料庫：server 和控制台共用 `users`／`api_keys`／`sessions` 這幾張表。兩邊不一樣的話，在網頁介面建立的帳號 server 會看不到，client 就無法登入。

## 6. 啟動

用 systemd：

```bash
sudo systemctl start cage-agent cage-control
journalctl -u cage-agent -f
```

在前景執行（節點代理和控制台在同一個行程裡，server 是它的子行程；按 Ctrl+C 三個一起停）：

```bash
cd /opt/cage && ./bin/cage-launcher --all
```

確認：

```bash
$ curl -s http://127.0.0.1:15963/health
{"status":"ok"}
```

有資料庫時，API 的其他部分要帶 token。用 `control.xml` 裡的 admin 登入 —— 帳密放在 `Authorization: Basic` header 裡，也就是 `curl -u` 送的那個：

```bash
$ curl -s -X POST -u admin:a-real-password http://127.0.0.1:15963/api/auth/login
{"ok":true,"token":"…","user_id":"admin","role":"admin"}

$ curl -s -H "Authorization: Bearer <token>" http://127.0.0.1:15963/api/models
{"models":[{"id":"my-coder","name":"my-coder","kind":"llm","type":"chat", ...
"backend":"llama", ...}]}
```

沒有資料庫時（§7）不需要 token。

網頁介面在 `http://127.0.0.1:8088/`，只有那台機器連得到：`control.xml` 把它綁在 `127.0.0.1`，因為它能啟動、停止、重新設定 server。要從別的地方連，改那裡的 `<bind>`，並放在 TLS proxy 後面。

| Port | 在哪裡設定 | 用途 |
|---|---|---|
| 15963 | `config.xml` 的 `<port>` | AI API（HTTP＋WebSocket）。client 連的就是這個 |
| 15972 | `config.xml` 的 `<node><agent_port>` | 節點代理的 API，由控制台呼叫 |
| 8088 | `control.xml` 的 `<web_port>` | 控制台的網頁介面 |

## 7. 不用資料庫執行

把 `config.xml` 裡整個 `<mysql>` 區塊拿掉。server 會記下：

```
[info] MySQL: no <mysql> block - running without a database (no accounts; ...)
[warning] [auth] auth DISABLED (dev-open) (users=0, masterKey=no, database=none): every request is served as admin, ...
```

如果也沒有設定 `<api_key>`，這就是**開放模式**。它的安全問題是刻意的，不是之後會修掉的 bug：

- 每個請求都以管理員身分處理，不用登入。
- 任何連得到這個 port 的人，都能讀取每一個 session（對話內容，裡面有你的程式碼），也能修改或刪除邏輯圖。`<bind>127.0.0.1</bind>` 可以把範圍限制在這台機器。

網頁不能使用它，不管在這個模式還是其他模式：瀏覽器裡的網頁送來的請求，server 一律拒絕（見 [API](server/server/api.zh-TW.md)）。

只在單人試用時這樣做。設定 `<api_key>` 就會關閉開放模式：一個共用的權杖，一樣不需要資料庫。

**`<mysql>` 區塊指向一個連不上的資料庫，不等於「沒有資料庫」。** server 會先等它，等到之前什麼請求都不處理：先記一行 `Waiting for the database at …`，之後每 30 秒一行，資料庫一回應就啟動。它絕不會把「資料庫還沒起來」當成「沒有任何帳號」，因為那樣會以開放模式啟動。資料庫有回應、但讀不到帳號時，它也一樣會等。server 執行期間建立的帳號（例如控制台建立它的管理員帳號）會立刻結束開放模式，不必重新啟動。

## 8. TLS

在 `config.xml` 裡設定這兩個欄位，就會在同一個 port 上提供 https／wss：

```xml
<tls_cert>/opt/cage/server.crt</tls_cert>
<tls_key>/opt/cage/server.key</tls_key>
```

區域網路用的自簽憑證：

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout server.key -out server.crt -subj "/CN=cage" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:<your-lan-ip>"
```

系統不信任自簽憑證，所以要告訴 client 接受它，見 [extension-install.zh-TW.md](extension-install.zh-TW.md) §4。

每個請求都會帶上 Bearer 權杖，所以只有在 localhost 上才適合用明文。

## 9. 疑難排解

| 症狀 | 原因 |
|---|---|
| `Fatal error: config.xml: cannot open file` | 從沒有 `config.xml` 的目錄啟動。用 `CONFIG_FILE=…`，或先 `cd` 到安裝目錄 |
| `Waiting for the database at …: Access denied for user 'cage'` | `<mysql>` 裡的帳號在 MySQL 裡不存在，或密碼不同 —— 見 §5。連得上之前什麼都不服務 |
| 網頁介面不接受 admin 密碼；控制台的 log 說密碼「is still the example value」 | `control.xml` 還是 `CHANGE_ME` —— 設一個真正的 `<admin><password>`（§4），再重啟 `cage-control` |
| `Model '…' scan failed: path does not exist` | `<path>` 不存在，或磁碟沒有掛載。這個模型會被略過（`Model skipped: …`），不會出現在清單上 |
| `TLS disabled — traffic … is plaintext` | `<tls_cert>`／`<tls_key>` 是空的時候本來就會這樣 |
| 本機模型載入失敗 | 沒有裝後端包，或裝錯了。執行 `bin/cage-backend-probe`：它會說出是哪個後端，以及它驅動得了你的哪幾張卡 |
| server 啟動了，但清單上沒有 GPU | 沒有驅動程式，或後端包看不到這些卡；檢查 `nvidia-smi` 和 `bin/cage-backend-probe` |
| safetensors 模型一直載入不了 | 原因跟任何本機模型一樣：沒有[後端包](server/server/backend-packs.zh-TW.md)，或 VRAM 不夠放你選的量化，見 [Safetensors 模型](server/server/safetensors.zh-TW.md) |
| 生成式模型一開始就失敗 | 它跟其他本機模型一樣需要[後端包](server/server/backend-packs.zh-TW.md)，也跟它們搶同一份 VRAM，見 [Modality](server/server/modalities.zh-TW.md) |
| Port 已經被占用 | 已經有另一個實例在跑，或 `<port>` 跟 `<agent_port>` 撞號 |

## 10. 移除

```bash
sudo systemctl disable --now cage-agent cage-control
sudo rm /etc/systemd/system/cage-agent.service /etc/systemd/system/cage-control.service
sudo systemctl daemon-reload
sudo rm -rf /opt/cage
```

---

下一步：[extension-install.zh-TW.md](extension-install.zh-TW.md)，安裝 VSCode client 並連上 server。server 是用哪種方式裝的，client 不在乎。

server 端的三個行程怎麼配合、平常怎麼操作，見 **[Server 指南](server/README.zh-TW.md)**。
