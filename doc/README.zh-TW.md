[English](README.md) · **繁體中文**

# CAGE 文件

## 安裝

| 文件 | 內容 |
|---|---|
| [server-install.zh-TW.md](server-install.zh-TW.md) | **從這裡開始**：先在兩種安裝方式之間做選擇，再完整說明原生安裝 |
| [server/docker.zh-TW.md](server/docker.zh-TW.md) | Docker 安裝：Dockerfile 與 compose，資料庫、模型和設定都放在主機的資料夾裡 |
| [server/server/backend-packs.zh-TW.md](server/server/backend-packs.zh-TW.md) | **GPU 支援要另外下載。** 該下載哪一包、怎麼安裝 |
| [extension-install.zh-TW.md](extension-install.zh-TW.md) | 安裝 `.vsix`、連上 server、自簽憑證、登入、第一次使用 |

先裝 server，extension 要有 server 才能連。server 則要先裝好後端包，才能在你的 GPU 上跑模型。

從 0.1.x 升級？[新功能](../WHATSNEW.zh-TW.md)裡寫了改了什麼、哪些需要你處理。

## 使用

| 文件 | 內容 |
|---|---|
| [server/](server/README.zh-TW.md) | Server 指南：三個行程（節點代理、推論伺服器、控制台）各自負責什麼 |
| [client/](client/README.zh-TW.md) | Client 指南：兩個視窗、每一個面板，以及每個設定的作用 |

Server 指南依行程分章，因為一件事歸哪個行程管，決定了你要怎麼改它。Client 指南依頁面分章，並且詳細說明邏輯圖：節點有哪些種類、它們引用的設定，以及設定裡的參數。

---

專有軟體 —— Copyright (c) 2026 real0000. All Rights Reserved. 見 [LICENSE](../LICENSE)。
