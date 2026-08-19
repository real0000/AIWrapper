# Third-Party Notices

本檔由 `./dev.sh licenses` 產生，請勿手改 —— 相依變了就重跑。
產生時間：2026-08-13 16:50 UTC

CAGE server 散布的產物（`bin/` 的執行檔、`lib/` 隨行的共享函式庫、
`share/cage/` 的轉檔腳本）內含下列第三方軟體。各元件的授權原文全文
收錄於 `licenses/`。

| 元件 | 授權 |
|---|---|
| boost-1.86.0 | BSL-1.0 |
| curl-8.11.1 | curl (MIT-like) |
| hnswlib-v0.8.0 | Apache-2.0 |
| ik_llama.cpp | MIT |
| openssl-3.4.1 | Apache-2.0 |
| tree-sitter-0.22.6 | MIT |
| tree-sitter-bash-0.21.0 | MIT |
| tree-sitter-c-0.21.4 | MIT |
| tree-sitter-cmake-0.4.1 | MIT |
| tree-sitter-cpp-0.22.0 | MIT |
| tree-sitter-c-sharp-0.21.3 | MIT |
| tree-sitter-css-0.21.0 | MIT |
| tree-sitter-dart-master | MIT |
| tree-sitter-dockerfile-0.2.0 | MIT |
| tree-sitter-go-0.21.0 | MIT |
| tree-sitter-graphql-master | MIT |
| tree-sitter-html-0.20.4 | MIT |
| tree-sitter-ini-master | Apache-2.0 |
| tree-sitter-java-0.21.0 | MIT |
| tree-sitter-javascript-0.21.4 | MIT |
| tree-sitter-json-0.21.0 | MIT |
| tree-sitter-kotlin-main | MIT |
| tree-sitter-lua-0.2.0 | MIT |
| tree-sitter-make-main | MIT |
| tree-sitter-markdown-0.1.7 | MIT |
| tree-sitter-meson-master | MIT |
| tree-sitter-ninja-main | MIT |
| tree-sitter-php-0.22.5 | MIT |
| tree-sitter-proto-main | MIT |
| tree-sitter-python-0.21.0 | MIT |
| tree-sitter-ruby-0.21.0 | MIT |
| tree-sitter-rust-0.21.2 | MIT |
| tree-sitter-sql-main-snap | MIT |
| tree-sitter-swift-main | MIT |
| tree-sitter-toml-0.5.1 | MIT |
| tree-sitter-typescript-0.21.2 | MIT |
| tree-sitter-vue-master | MIT |
| tree-sitter-xml-0.6.4 | MIT |
| tree-sitter-yaml-0.5.0 | MIT |
| Vulkan-Headers | Apache-2.0 OR MIT |
| libgomp / libquadmath（隨 `lib/` 散布） | GPL-3.0 **with GCC Runtime Library Exception** |
| libcudart / libcublas / libcublasLt（隨 `lib/` 散布） | NVIDIA CUDA Toolkit EULA（可轉散布條款） |

## 需要留意的兩項

- **libgomp / libquadmath** 是 GPL-3.0，靠 *GCC Runtime Library Exception*
  才能隨專有軟體散布。那個例外的成立條件是編譯過程沒有使用 GPL 相容性
  以外的中介表示；一般的 GCC 編譯符合。若改用其他工具鏈或做了 LTO 以外
  的特殊處理，要重新確認。
- **CUDA 的三個函式庫**依 NVIDIA EULA 的 redistributable 條款隨附，
  僅限與本軟體一起散布。

## 產物與授權的對應

- `bin/*`：靜態連入 ik_llama.cpp（含 ggml / llama.cpp 血緣）、Boost、
  OpenSSL、hnswlib、tree-sitter 與各語言文法、libcurl。
- `share/cage/convert_hf_to_gguf.py`、`share/cage/gguf-py/`：取自
  ik_llama.cpp，以**原始碼**形式散布（MIT）。

## VSCode extension（`.vsix`）

`dist/extension.js` 是 esbuild 打包的產物，內含 94 個執行期
相依（`@modelcontextprotocol/sdk` / `fast-xml-parser` / `ws` 的相依閉包）。
授權分布：BSD-2-Clause / BSD-3-Clause / ISC / MIT。建置工具（vsce 等 devDependencies）不出貨。

## Native client

| 元件 | 授權 |
|---|---|
| freetype | FTL 或 GPLv2（本產品採 FTL） |
| libpng | libpng |
| zlib | zlib |
| UniversalGraphicWindow | MIT（與本產品同一著作權人，另行發布） |

### FreeType

FreeType 是 **FTL 或 GPLv2 二選一**。本產品採用 **FTL** —— 它明文允許
並鼓勵納入商業產品，但帶一條廣告條款，要求在文件中標示。以下即為履行：

> Portions of this software are copyright © 2026 The FreeType
> Project (www.freetype.org). All rights reserved.

## 不隨本產品散布的部分

下列由使用者自己安裝到自己的機器上，CAGE 不轉散布，授權由使用者直接承擔：

- `setup-workers.sh` 以 pip 安裝的 Python 套件，以及它 clone 的上游 repo
  （InstantMesh、TRELLIS、Hunyuan3D-2）。其中部分帶 copyleft 或非商業條款
  —— 見 doc/server/server/workers.md。TRELLIS 的 AGPL/GPL 相依
  （pymeshfix / igraph / plyfile）已由 `patch_trellis_licence.py` 改為
  延遲載入，預設路徑不需要安裝它們。
- **模型權重**。本產品不含任何權重，`config.example.xml` 只有佔位路徑。
  多個常見權重帶商業限制（非商業、營收門檻、使用者數門檻、地域排除）
  —— 見 doc/server/server/models.md。
