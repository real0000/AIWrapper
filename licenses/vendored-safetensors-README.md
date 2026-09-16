# cage_safetensors — safetensors 容器讀取 + 非 GGUF 的反量化

**這是 vendored 的第三方程式碼，不是 submodule。** 來源、授權與我們的改動全部
記在這裡；`dev.sh licenses` 會把它列進聲明。

| | |
|---|---|
| 上游 | https://github.com/mudler/vllm.cpp |
| 版本 | `96c5e4719dcb1f859cb9e59573309f16c026b523`（2026-09-09） |
| 授權 | Apache License 2.0（見 `LICENSE`；上游的 `NOTICE` 一併保留） |
| 著作權 | Copyright 2026 Ettore Di Giacinto |

## 為什麼 vendored 而不是 submodule

只需要它十一個檔案裡的容器讀取與幾支反量化，而 vllm.cpp 本體是一整個推論引擎
（自己的 `vt::` runtime、排程器、CUDA/ROCm kernel）。整包拉進來只為了讀一個檔案
格式，換來的是一份跟我們毫無關係的建置相依。

挑出來的這幾支**對外相依是零**：只用 C++ 標準函式庫 + POSIX/Win32，不碰 ggml、
不碰 torch、不碰 vllm.cpp 自己的型別。

## 拿了什麼

```
include/cage_safetensors/
  safetensors_reader.h        容器讀取（單檔 + model.safetensors.index.json 分片）
  read_only_file_mapping.h    唯讀 mmap（跨平台）
  platform_compat.h           page size 等平台差異
  awq_gptq_dequant.h          AWQ / GPTQ 反量化
  mxfp4_dequant.h             MXFP4 反量化
  nvfp4_dequant.h             NVFP4 反量化
include/vt/
  dtype.h                     上游的 dtype 描述子
src/  對應的實作
```

`vt/dtype.h` 是上游 `vt::` runtime 的一個標頭。三支反量化只用到它裡面的兩個純量
轉換（`F32ToBF16` / `BF16ToF32`），但整份原樣搬進來 —— 把那兩個函式挖出來會變成
對上游程式碼的功能性修改，之後每次同步都要重做一次。它自己只依賴標準函式庫。

它裡面確實也有一份鏡像自 llama.cpp 的 GGUF dtype id 與區塊幾何。**我們不呼叫那
部分**（GGUF 一律走 ggml，理由見下），留著只是為了讓這幾個檔案保持未修改。

## **沒有**拿什麼，以及為什麼

`model_loader/gguf_dequant.{h,cpp}` —— 那是 GGUF 量化區塊的反量化，而上游自己的
檔頭就寫明它是「ported byte-for-byte from llama.cpp @ 237ad9b」。我們樹上已經有
`third_party/ik_llama.cpp/ggml/src/ggml-quants.c` 的原版。搬進來會變成同一份知識
的第三份副本，而副本就是遲早會漂掉的東西。GGUF 的反量化一律走 ggml。

同理沒有拿 `gguf_reader`：ik 的 `gguf_init_from_file` 就是。

## 我們改了什麼（Apache-2.0 §4(b) 要求列出）

見 `MODIFICATIONS.txt`。
