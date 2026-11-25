[English](backend-packs.md) · **繁體中文**

# 後端包

每一個本機模型 —— GGUF 或 safetensors、文字或生成式 —— 都需要一個**後端包**：另外下載的套件，裝著對應你硬體、編譯好的 GPU 程式碼。server 套件裡一點都沒有。

對大部分的安裝來說，這不是可有可無的附加品。沒有後端包，server 能啟動、能執行，但只有 `remote` 後端能用；任何本機模型都會載入失敗，訊息會寫明該下載哪一個後端包。

> **後端包必須跟 server 的版本一致。** 舊版的後端包會在載入時被拒絕。訊息依它有多舊而不同 —— 0.1.1 的後端包會回報 `missing chat-template symbols […]`，0.1.2 的則是 `Missing the CAGE backend identity symbols […]` —— 不管哪一種，解法都是下載跟這個 server 相符的後端包。
>
> 這是刻意的。從 0.1.2 起，工具呼叫的格式取自每個模型自己的 chat template，而讀取它的程式碼放在**後端包裡面**。舊的後端包沒有這段程式碼，server 就只能退回去用猜的 —— 而那正是 0.1.2 消除的失敗模式。拒絕載入，比工具呼叫悄悄失效更容易診斷。升級 server，就要重新下載後端包。

---

## 為什麼分開

GPU kernel 的總量很大 —— 遠比 server 其餘的部分大 —— 而其中幾乎全部，都是給你的機器上沒有的架構用的。用一個執行檔涵蓋全部，代表要下載 1.7 GB，在任何一台機器上都有 91% 是用不到的重量；而 kernel 一超過兩種架構，它就連連結都連結不起來了。

分開之後：

- 你下載的是你的卡的 kernel，不是所有人的；
- 非 NVIDIA 的硬體也能用，透過 Vulkan 後端包；
- 新的 GPU 架構是一個新的後端包，不是一個新的 server；
- 更新 server 不必重新下載 1 GB 的 kernel。

server 是 **54 MB**，本身不依賴 CUDA。CUDA 後端包解開後是 1.2–1.6 GB —— 兩種架構的 kernel，加上它自帶的 CUDA 函式庫；Vulkan 和 CPU 後端包大約是 160 MB 和 130 MB。

## 怎麼選

| 後端包 | 硬體 | Compute capability |
|---|---|---|
| `cage-backend-cuda-sm60_sm61` | P40、P100、P4、GTX 10xx | 6.0、6.1 |
| `cage-backend-cuda-sm70_sm75` | V100、Titan V、T4、RTX 20xx、GTX 16xx、Quadro RTX | 7.0、7.5 |
| `cage-backend-cuda-sm80_sm86` | A100、A30、A40、A10、RTX 30xx | 8.0、8.6 |
| `cage-backend-cuda-sm89_sm90` | L40、L40S、L4、RTX 40xx、H100、H200 | 8.9、9.0 |
| `cage-backend-cuda-sm120_sm121` | RTX 50xx、GB10（DGX Spark） | 12.0、12.1 |
| `cage-backend-hip-*` | AMD，透過 ROCm —— 見下方 | 不適用 |
| `cage-backend-vulkan` | 任何支援 Vulkan 1.2 的 GPU —— AMD、Intel 或 NVIDIA | 不適用 |
| `cage-backend-cpu` | 完全沒有 GPU | 不適用 |

### AMD 後端包

AMD 後端包依 **ISA 世代**切分，因為 AMD 的裝置程式碼在不同世代之間不相容，不像 NVIDIA 在同一個主要 compute capability 之內可以通用：

| 後端包 | 卡 |
|---|---|
| `cage-backend-hip-gfx1100_gfx1101_gfx1102` | RDNA3 —— RX 7000 |
| `cage-backend-hip-gfx1030_gfx1031_gfx1032` | RDNA2 —— RX 6000 |
| `cage-backend-hip-gfx1200_gfx1201` | RDNA4 —— RX 9000 |
| `cage-backend-hip-gfx908_gfx90a_gfx942` | CDNA —— MI100／MI200／MI300 |
| `cage-backend-hip-gfx1103_gfx1150_gfx1151_gfx1152` | RDNA3 APU —— Phoenix／Strix／Strix Halo |

Vega 和更舊的（gfx900、gfx906 —— Vega 64、Radeon VII、MI50/60）**不在涵蓋範圍內**：ROCm 沒有為它們提供 rocBLAS kernel。MI350（gfx950）也不在範圍內，原因正好相反 —— 它比我們建置時用的 ROCm 裡的 rocPRIM 還新，那個版本沒有它的 128 位元 atomic 操作。Vulkan 後端包也許還是能驅動這些卡。

> **能驗證的都驗證了，但也就只到這裡。** 這些後端包能編譯、能載入、每個符號都解析得到，也能正確回報自己的身分 —— 這是在一台沒有 AMD 硬體的機器上、用乾淨的容器檢查的。Linux 的後端包*算得對不對*、有多快，還沒有在 AMD 上測過。gfx1150 後端包的 Windows 版曾在 Radeon 890M 上跑過 —— 見[驗證過什麼](../../verification-status.zh-TW.md)。請把它們當成徵求實地回報，而不是正式支援的組態。

**AMD 主機的前置需求。** CUDA 後端包只需要 NVIDIA 驅動，HIP 後端包則還需要幾個不該由它們附帶的函式庫：

```bash
sudo apt install libdrm2 libdrm-amdgpu1 libnuma1 libelf1      # Debian、Ubuntu
sudo dnf install libdrm numactl-libs elfutils-libelf          # RHEL、AlmaLinux、Rocky、Fedora
```

`libdrm*` 隨 amdgpu 驅動一起提供 —— 相當於 AMD 版的 `libcuda.so.1`，那是驅動該提供的，不是我們。`libnuma1` 和 `libelf1` 是一般的發行版套件；少了的話會清楚地顯示「cannot open shared object file」，而不是什麼更難察覺的錯誤，所以沒有把它們打包進去。

AMD 後端包除了共享函式庫，還附帶 rocBLAS 的 Tensile kernel 檔案。這些 kernel 放在獨立的檔案裡，而不是在 `librocblas.so` 裡面，所以少了它們的後端包能載入，卻會在第一次矩陣乘法時失敗。它們占了下載量的大部分 —— 每個 GPU 世代大約 290 MB —— 這也是後端包分開、而不是合在一起的原因。

看看你有什麼：

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv   # NVIDIA
vulkaninfo --summary | head -30                        # 其他的
```

compute capability **5.x 和更舊**的 NVIDIA 卡（Maxwell：GTX 9xx、M40），任何 CUDA 後端包都不支援。Vulkan 後端包也許還是能驅動它們。

### Pascal，尤其是 P40

Tesla P40 花很少的錢就有 24 GB，它在這裡最適合的工作是**檢索背後的 embedding 模型，或摘要共用記憶的模型** —— 而不是聊天模型。這是由這張卡的兩個特性決定的：

- **FP16 只有 FP32 的 1/64 速度。** kernel 知道這一點，會讓 P40 走 FP32 和 INT8 的路徑，所以什麼都不會壞；但這也排除了讓新卡跑大模型很快的那些半精度技巧。
- **沒有 tensor core。** 後果一樣，處理方式也一樣。

embedding 模型很小，每一塊只跑一次 forward，而且有沒有自己的記憶體，比原始速度重要得多 —— 而 P40 有的正是記憶體。

P40 通常是插在新卡旁邊的**第二張**卡，所以通常代表要並排裝兩個後端包：這一個，加上你主要那些卡用的那一個。這是支援的。每個 AI config 由能驅動它所選 GPU 的那個已安裝後端包提供服務；除了在該用 P40 的 AI config 上選 P40，沒有其他東西要設定。

**刻意不提供什麼都包的後端包。** 一個為「所有更新的架構」帶著 PTX 的版本，會在第一次載入時由驅動編譯，又慢、又難以預測，而且在 Windows WDDM 底下還會碰上顯示驅動的逾時監視機制。跟你的卡不合的後端包，會立刻告訴你，而不是那樣拖著。

## 安裝

後端包的目錄結構跟 server 套件一樣，所以直接合併進去：

```bash
tar -xzf cage-backend-cuda-sm89_sm90-0.2.0-linux-x64.tar.gz
cd cage-backend-cuda-sm89_sm90-0.2.0-linux-x64
cp bin/libcage-backend-*.so  /opt/cage/bin/
cp -r lib/*                /opt/cage/lib/
```

### 裝不只一個後端包

機器需要幾個就裝幾個 —— P40 旁邊有 V100、兩個世代的 AMD、CUDA 後端包旁邊再加 Vulkan 的。**每個後端包的函式庫都以後端包命名**（`libcage-backend-cuda-sm60_sm61.so`、`libcage-backend-cuda-sm70_sm75.so`…），所以它們可以並排放在 `bin/` 裡。server 會全部載入，並用能驅動某個 AI config 所選 GPU 的那一個，為那個 config 服務。

各個後端包的 `lib/` 目錄裡有同名的檔案。除了 Blackwell 那一個，每個 CUDA 後端包都是用同一版 CUDA runtime 建置的，所以那些檔案完全相同，順序沒有關係。**如果其中一個是 `cuda-sm120_sm121`，最後再複製它的 `lib/`**：它帶的是比較新的 CUDA 12 runtime，舊的後端包也能用；反過來，舊的那份沒有 Blackwell 的 kernel。

**從 0.1.x 升級：** 如果 `bin/libcage-backend-cuda.so` 和 `bin/libcage-backend-hip.so` 還在，把它們刪掉。0.1.x 的每個 CUDA 後端包都用同一個名字，所以 0.2.0 的後端包不會再取代那個檔案。server 自己會拒絕它 —— 它比目前的後端介面還舊 —— 但在你刪掉它之前，它會一直出現在探測的報告裡。

**`lib/` 和 `bin/` 都要複製。** CUDA 後端包自帶 `libcudart.so.12`、`libcublas.so.12`、`libcublasLt.so.12` 和 `libcufft.so.11`，AMD 後端包則帶著對應的 ROCm 函式庫加上 `lib/rocblas/library/`，全部透過 `$ORIGIN/../lib` 這個 `RUNPATH` 找到。這就是機器上不必安裝 CUDA toolkit 的原因 —— 但前提是這些函式庫要放在 `.so` 旁邊、照它預期的結構擺好。

要把後端包放在別的地方，就讓 server 指向那個資料夾：

```bash
export CAGE_LLAMA_BACKEND_DIR=/opt/cage/backends
```

這個變數是**排他的**：它會取代搜尋路徑，而不是加進去，所以設定它的期間，`bin/` 裡的後端包會被忽略。

## 驗證

`cage-backend-probe` 附在 server 套件裡，跑的是 server 用的完全相同的載入路徑 —— 它回報什麼，server 就會怎麼做。

```bash
/opt/cage/bin/cage-backend-probe
```

不加參數時，它會在自己所在的資料夾（也就是後端包安裝進去的 `bin/`）和目前的資料夾裡找；給它某個後端包的 `.so` 路徑，就只檢查那一個。它會為每一個 `.so` 回報：

| | |
|---|---|
| ABI 指紋 | 這個後端包跟這個 server 版本合不合。不合的話會被拒絕，而不是載入 |
| 後端 | 它是哪一種後端 —— 從它匯出的符號判斷，不是從檔名 |
| Build id | 它來自哪一次建置 |
| Tensor parallelism | 能不能用 `graph` 切分，還是只能依層切分 |
| 裝置 | 它看得到幾張卡、實際能驅動幾張，以及每張的剩餘／總 VRAM |

被標成不能用的卡，會回報成 *this `.so` has no device code for this card* —— 這就是「我下載錯後端包了」的答案，在你花時間載入模型之前就告訴你。

## 同時使用好幾個後端包

你可以裝好幾個。server 會針對每個裝置探測它找到的每個後端包，並記錄哪個後端能驅動哪張卡。AI config 再綁定到適合它所選 GPU 的那個後端 —— 所以一台同時有 NVIDIA 卡和 AMD 卡的機器，可以在同一個 server 裡，用正確的後端驅動各自的卡。

探測在子程序裡進行，所以壞掉或不相容的後端包，沒辦法把 server 一起拖垮。

**有一個限制，明白說清楚：一個 AI config 不能橫跨兩種架構。** 沒有任何後端支援跨不同 GPU 架構的 tensor parallelism；混在一起會又慢*又*錯。每個 config 只選同一種架構的 GPU。

## 沒有後端包時

server 照常啟動。`remote` 模型照常運作。在本機執行的模型會在載入時失敗，訊息會寫明該下載哪一個後端包 —— 它不會默默失敗，也不會不告訴你就退回 CPU。

如果你真的想用 CPU 推論，就安裝 `cage-backend-cpu`。這是正式支援的組態，不是降級的狀態 —— 只是慢。

---

[← 推論伺服器](README.zh-TW.md) · [後端](backends.zh-TW.md) · [模型](models.zh-TW.md) · [Server 指南](../README.zh-TW.md)
