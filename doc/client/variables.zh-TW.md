[English](variables.md) · **繁體中文**

# 變數

變數是有名字的狀態，屬於整張圖，而不是任何一個節點。它們只存在於一輪執行之中：這一輪開始時，server 把每個變數初始化成它的預設值，結束時就丟掉。

變數在 Logic Editor 側欄的 **VARIABLES** 區塊宣告，由 [Variable](nodes.zh-TW.md#variable) 節點、[If](nodes.zh-TW.md#if) 的 case，以及 [Compose](nodes.zh-TW.md#compose) 範本裡的 `{{name}}` 預留位置使用。

---

## 宣告

| 欄位 | 意思 |
|---|---|
| Name | 節點怎麼稱呼它 |
| Type | `string`、`number`、`bool` 或 `enum` |
| Default Value | 每一輪開始時的值 |
| Description | 它是做什麼用的 |
| Enum Values | 型別是 `enum` 時，允許的值的清單 |

執行時，值都以字串儲存。型別決定 `add` 是什麼意思，以及 [If](nodes.zh-TW.md#if) 提供哪些比較運算子。

## 寫入

由 [Variable](nodes.zh-TW.md#variable) 節點寫入。每個 item 選一個目標、一個操作和一個來源：

| 操作 | `string` | `number` | `bool` |
|---|---|---|---|
| `set` | 取代 | 取代 | 取代 |
| `add` | 串接 | 相加 | 邏輯 OR |

來源可以是常數、節點上的一個輸入 pin，或另一個變數。寫入是不可分割的「讀取－修改－寫回」，所以兩條並行的分支同時遞增同一個計數器，也不會漏掉任何一次。

## 讀取

兩種方式。

**Getter pin。** 在 Variable 節點上加一個名字跟某個變數相同的輸出 pin。下游的節點直接從它讀，不需要 exec 線 —— 值是在讀取的節點執行時才拉過來的，所以是那一刻的值，而不是更早某個節點剛好執行時的值。把變數餵進 prompt，通常就用這個方法。

**直接讀。** [Compose](nodes.zh-TW.md#compose) 範本接受 `{{variableName}}`，[If](nodes.zh-TW.md#if) 的 case 也可以指定一個變數當作比較的來源。

## 適合拿來做什麼

- **計數器。** 在 [Check Format](nodes.zh-TW.md#check-format) 節點的 `False` 分支上遞增的重試計數器，在下一次迴圈之前由一個 [If](nodes.zh-TW.md#if) 檢查 —— 這就是限制重試迴圈次數的方法。
- **累加器。** 每跑一次就往後附加的工作紀錄，最後由一個 [Compose](nodes.zh-TW.md#compose) 節點排進最終報告。
- **模式旗標。** 一開始設好的 enum，後面的 `If` 節點依它分支，讓同一張圖同時能「只做規劃」和「規劃加建置」。
- **跨過分岔攜帶值。** 在 [Dispatch](nodes.zh-TW.md#dispatch) 子圖裡寫入的值，在它結束之後還看得到 —— 每項任務的結果就是這樣收集起來的。

---

[← Logic Editor](logic-editor.zh-TW.md) · [節點](nodes.zh-TW.md) · [Client 指南](README.zh-TW.md)
