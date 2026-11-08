[English](nodes.md) · **繁體中文**

# 多個節點

節點就是一台跑著[節點代理](../agent/README.zh-TW.md)、底下再跑著推論伺服器的機器。控制台保存一份節點清單，透過 HTTP 管理每一台。

---

## 加入一台

兩端的設定必須一致。

在那台機器的 `config.xml` 裡：

```xml
<node>
  <bind>0.0.0.0</bind>
  <agent_port>15972</agent_port>
  <node_token>a-shared-secret</node_token>
</node>
```

在 `control.xml` 裡：

```xml
<nodes>
  <node id="local" name="local"      url="http://127.0.0.1:15972" token=""/>
  <node id="gpu2"  name="GPU node 2" url="http://10.0.0.12:15972" token="a-shared-secret"/>
</nodes>
```

| 屬性 | 意思 |
|---|---|
| `id` | 內部識別碼，API 呼叫時使用 |
| `name` | 介面上顯示的名字 |
| `url` | 那台機器的節點代理 |
| `token` | 必須等於那台機器的 `<node_token>` |

`<bind>` 必須是控制台連得到的位址。預設的 `127.0.0.1` 只接受本機連線，對單機安裝是對的，控制台一放到別台機器就錯了。

## 哪些共用，哪些不共用

這是最讓人意外的部分。

| 所有節點共用 | 每個節點各自 |
|---|---|
| 帳號、token、session（同一個資料庫） | 模型，以及放模型的硬碟 |
| 邏輯圖，前提是它們在同一個 server 上 | `config.xml`，包括每一個模型項目 |
| | GPU，以及依 GPU 決定的擺放 |

每台機器都有**自己的**模型清單。在一個節點上新增模型，不會加到其他任何地方；兩個節點上同樣的 alias，可能指向不同的檔案、不同的量化。

圖的 AI config 用 alias 指定模型。把那張圖拿到一台沒有這個 alias 的 server 上執行，就會失敗 —— Logic Editor 的 console 會標記「references models the server does not have」。

讓各台機器的 alias 保持一致，是你得自己維護的慣例；沒有任何東西會強制它。

## client 跟哪個 server 溝通？

直接連，而且只連一個：編輯器裡的 `cage.server.host` 和 `.port`。控制台不是 proxy，也不在那條路上。

所以要把工作分散到好幾台機器，就是讓不同的編輯器指向不同的 server。節點之間沒有自動排程。

## 實際的配置方式

**一台機器。** 控制台、節點代理和 server 都在同一台；節點代理在 `127.0.0.1`；節點清單只有一筆。其他什麼都不用。

**幾台 GPU 機器，一個管理者。** 控制台放在永遠開著的那台 —— 可以是沒有 GPU 的機器。每台 GPU 機器跑一個節點代理，綁在連得到的位址上、設好 token。一個資料庫，由控制台和每個 server 共用。

**把大模型分開。** 有大卡的機器放大模型；比較小的機器放快速的輔助模型。需要哪一種的圖，就指向對應的 server。在每台機器上用同樣的 alias、背後是不同的量化，是合理的做法 —— 這樣一張圖在哪一台都能跑。

## 健康狀況

每個節點的 `/node/status` 提供程序狀態、已執行時間、健康狀況、VRAM 和已載入的模型 —— 儀表板顯示的就是這些。

節點連不到，表示控制台連不到那個節點代理。那台機器上的推論伺服器可能完全正常，它的 client 也不受影響；這是兩條各自獨立的路。

---

[← 控制台](README.zh-TW.md) · [帳號](accounts.zh-TW.md) · [Server 指南](../README.zh-TW.md)
